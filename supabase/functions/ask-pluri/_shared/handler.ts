import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import {
  CHAT_HISTORY_LIMIT,
} from "./constants.ts";
import type { CoachAction } from "./actions.ts";
import {
  contextContainsForbiddenKeys,
  loadCoachContext,
} from "./context.ts";
import { busyErrorBody, throttledErrorBody } from "./errors.ts";
import {
  ASK_PLURI_SYSTEM_PROMPT,
  buildGeminiUserPrompt,
  callGeminiGenerateContent,
  resolveGeminiModel,
  type GeminiGenerateFn,
} from "./gemini.ts";
import { tryConsumeThrottle } from "./throttle.ts";

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export type AskPluriRequestBody = {
  message?: unknown;
  conversationId?: unknown;
  currentPlanWorkoutId?: unknown;
};

export type AskPluriHandlerDeps = {
  createUserClient?: (
    supabaseUrl: string,
    anonKey: string,
    authHeader: string,
  ) => SupabaseClient;
  geminiGenerate?: GeminiGenerateFn;
  env?: {
    supabaseUrl?: string;
    anonKey?: string;
    geminiApiKey?: string;
    geminiModel?: string;
  };
};

export function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function asOptionalString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function defaultUserClient(
  supabaseUrl: string,
  anonKey: string,
  authHeader: string,
): SupabaseClient {
  return createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
}

/**
 * ask-pluri core handler (M6-03).
 * - JWT via user-scoped client
 * - Loads plan/history context (never HealthKit / Pluri Score)
 * - Calls Gemini with server-side secret
 * - Persists user + assistant chat_messages
 * - Returns structured actions only — does NOT mutate plan_workouts
 */
export async function handleAskPluriRequest(
  req: Request,
  deps: AskPluriHandlerDeps = {},
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const supabaseUrl =
      deps.env?.supabaseUrl ?? Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = deps.env?.anonKey ??
      Deno.env.get("SUPABASE_ANON_KEY") ??
      Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
      "";
    const geminiApiKey = deps.env?.geminiApiKey ??
      Deno.env.get("GEMINI_API_KEY") ??
      "";

    if (!supabaseUrl || !anonKey) {
      console.error("ask-pluri: missing Supabase URL/anon env");
      return jsonResponse({ error: "Server misconfigured" }, 500);
    }

    if (!geminiApiKey) {
      console.error(
        "ask-pluri: missing GEMINI_API_KEY — set via supabase secrets set GEMINI_API_KEY=...",
      );
      return jsonResponse(
        {
          error:
            "Server misconfigured. Set GEMINI_API_KEY via supabase secrets (never in the iOS bundle).",
        },
        500,
      );
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing Authorization header" }, 401);
    }

    const createUserClient = deps.createUserClient ?? defaultUserClient;
    const userClient = createUserClient(supabaseUrl, anonKey, authHeader);

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return jsonResponse(
        { error: userError?.message ?? "Unauthorized" },
        401,
      );
    }

    if (!tryConsumeThrottle(user.id)) {
      return jsonResponse(throttledErrorBody(), 429);
    }

    let body: AskPluriRequestBody;
    try {
      body = (await req.json()) as AskPluriRequestBody;
    } catch {
      return jsonResponse({ error: "Invalid JSON body" }, 400);
    }

    const message = asOptionalString(body.message);
    if (!message) {
      return jsonResponse({ error: "message is required" }, 400);
    }

    const requestedConversationId = asOptionalString(body.conversationId);
    const currentPlanWorkoutId = asOptionalString(body.currentPlanWorkoutId);

    let conversationId = requestedConversationId;
    if (!conversationId) {
      const latest = await userClient
        .from("chat_messages")
        .select("conversation_id")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (latest.error) {
        console.error("ask-pluri: conversation lookup failed", latest.error);
        return jsonResponse(
          { error: "Failed to load conversation", detail: latest.error.message },
          500,
        );
      }

      const row = latest.data as { conversation_id?: string } | null;
      conversationId = row?.conversation_id ?? crypto.randomUUID();
    }

    const context = await loadCoachContext(
      userClient,
      user.id,
      currentPlanWorkoutId,
    );

    const forbidden = contextContainsForbiddenKeys(context);
    if (forbidden.length > 0) {
      console.error("ask-pluri: forbidden context keys", forbidden);
      return jsonResponse(
        { error: "Context grounding failed safety check" },
        500,
      );
    }

    const historyResult = await userClient
      .from("chat_messages")
      .select("role, content")
      .eq("user_id", user.id)
      .eq("conversation_id", conversationId)
      .order("created_at", { ascending: true })
      .limit(CHAT_HISTORY_LIMIT);

    if (historyResult.error) {
      console.error("ask-pluri: history load failed", historyResult.error);
      return jsonResponse(
        {
          error: "Failed to load chat history",
          detail: historyResult.error.message,
        },
        500,
      );
    }

    const chatHistory = ((historyResult.data ?? []) as Array<{
      role: string;
      content: string;
    }>).filter((row) => row.role === "user" || row.role === "assistant");

    const userInsert = await userClient
      .from("chat_messages")
      .insert({
        user_id: user.id,
        conversation_id: conversationId,
        role: "user",
        content: message,
      })
      .select("id")
      .single();

    if (userInsert.error || !userInsert.data) {
      console.error("ask-pluri: user message persist failed", userInsert.error);
      return jsonResponse(
        {
          error: "Failed to save message",
          detail: userInsert.error?.message,
        },
        500,
      );
    }

    const userMessageId = (userInsert.data as { id: string }).id;

    const geminiGenerate = deps.geminiGenerate ?? callGeminiGenerateContent;
    const model = resolveGeminiModel(
      deps.env?.geminiModel ?? Deno.env.get("GEMINI_MODEL") ?? undefined,
    );

    const geminiResult = await geminiGenerate({
      apiKey: geminiApiKey,
      model,
      systemPrompt: ASK_PLURI_SYSTEM_PROMPT,
      userPrompt: buildGeminiUserPrompt({
        contextJson: JSON.stringify(context),
        chatHistory,
        userMessage: message,
      }),
    });

    if (!geminiResult.ok) {
      // Soft-delete path: keep the user message (audit) but surface busy shape.
      const status = geminiResult.status === 429
        ? 429
        : geminiResult.status >= 500
        ? 503
        : 502;
      const body = "error" in geminiResult.errorBody &&
          (geminiResult.errorBody.error === "busy" ||
            geminiResult.errorBody.error === "throttled")
        ? geminiResult.errorBody
        : busyErrorBody();
      return jsonResponse(body as Record<string, unknown>, status);
    }

    const actions: CoachAction[] = geminiResult.actions;

    const assistantInsert = await userClient
      .from("chat_messages")
      .insert({
        user_id: user.id,
        conversation_id: conversationId,
        role: "assistant",
        content: geminiResult.reply,
        actions: actions.length > 0 ? actions : null,
      })
      .select("id")
      .single();

    if (assistantInsert.error || !assistantInsert.data) {
      console.error(
        "ask-pluri: assistant message persist failed",
        assistantInsert.error,
      );
      return jsonResponse(
        {
          error: "Failed to save assistant reply",
          detail: assistantInsert.error?.message,
        },
        500,
      );
    }

    const assistantMessageId = (assistantInsert.data as { id: string }).id;

    // Intentionally no plan_workouts insert/update/delete — client confirms (M6-09/10).
    return jsonResponse({
      reply: geminiResult.reply,
      conversationId,
      actions,
      messageIds: {
        user: userMessageId,
        assistant: assistantMessageId,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("ask-pluri: unexpected error", message);
    return jsonResponse({ error: "Unexpected error", detail: message }, 500);
  }
}
