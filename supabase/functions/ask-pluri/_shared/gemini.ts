import { DEFAULT_GEMINI_MODEL } from "./constants.ts";
import { parseGeminiCoachPayload, type CoachAction } from "./actions.ts";
import { geminiStatusToErrorBody, type AskPluriErrorBody } from "./errors.ts";
import { ASK_PLURI_SYSTEM_PROMPT } from "./prompt.ts";

export type GeminiSuccess = {
  ok: true;
  reply: string;
  actions: CoachAction[];
};

export type GeminiFailure = {
  ok: false;
  status: number;
  errorBody: AskPluriErrorBody | { error: string; detail?: string };
};

export type GeminiResult = GeminiSuccess | GeminiFailure;

export type GeminiGenerateFn = (args: {
  apiKey: string;
  model: string;
  systemPrompt: string;
  userPrompt: string;
}) => Promise<GeminiResult>;

function extractTextFromGeminiResponse(payload: unknown): string {
  const root = payload as {
    candidates?: Array<{
      content?: { parts?: Array<{ text?: string }> };
    }>;
  };
  const parts = root.candidates?.[0]?.content?.parts ?? [];
  return parts
    .map((part) => (typeof part.text === "string" ? part.text : ""))
    .join("")
    .trim();
}

/** Live Gemini REST call (generateContent). Injected in tests via mock. */
export const callGeminiGenerateContent: GeminiGenerateFn = async ({
  apiKey,
  model,
  systemPrompt,
  userPrompt,
}) => {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${
      encodeURIComponent(model)
    }:generateContent?key=${encodeURIComponent(apiKey)}`;

  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      systemInstruction: {
        parts: [{ text: systemPrompt }],
      },
      contents: [
        {
          role: "user",
          parts: [{ text: userPrompt }],
        },
      ],
      generationConfig: {
        temperature: 0.6,
        responseMimeType: "application/json",
      },
    }),
  });

  if (!response.ok) {
    const mapped = geminiStatusToErrorBody(response.status);
    if (mapped) {
      return { ok: false, status: response.status, errorBody: mapped };
    }
    return {
      ok: false,
      status: response.status,
      errorBody: {
        error: "Gemini request failed",
        detail: `HTTP ${response.status}`,
      },
    };
  }

  const json = await response.json();
  const text = extractTextFromGeminiResponse(json);
  if (!text) {
    return {
      ok: false,
      status: 502,
      errorBody: busyOrGenericEmpty(),
    };
  }

  const parsed = parseGeminiCoachPayload(text);
  return { ok: true, reply: parsed.reply, actions: parsed.actions };
};

function busyOrGenericEmpty(): AskPluriErrorBody {
  return {
    error: "busy",
    message: "Your coach is busy — try again shortly.",
  };
}

export function resolveGeminiModel(
  envModel = Deno.env.get("GEMINI_MODEL"),
): string {
  const trimmed = envModel?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : DEFAULT_GEMINI_MODEL;
}

export function buildGeminiUserPrompt(args: {
  contextJson: string;
  chatHistory: Array<{ role: string; content: string }>;
  userMessage: string;
}): string {
  const historyBlock = args.chatHistory
    .map((turn) => `${turn.role}: ${turn.content}`)
    .join("\n");

  return [
    "User context (Postgres plan/history only — no HealthKit / Pluri Score):",
    args.contextJson,
    "",
    "Recent chat (same conversation):",
    historyBlock || "(none)",
    "",
    "User message:",
    args.userMessage,
    "",
    "Respond with the strict JSON object described in the system instructions.",
  ].join("\n");
}

export { ASK_PLURI_SYSTEM_PROMPT };
