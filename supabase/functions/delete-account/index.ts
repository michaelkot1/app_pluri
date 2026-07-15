// delete-account Edge Function (M2-05).
//
// Verifies the caller's JWT, deletes owned Postgres rows (profiles CASCADE covers
// plans / plan_workouts / workout_exercises / workout_sessions / set_logs), then
// removes the auth user via the Admin API.
//
// Requires a real SUPABASE_SERVICE_ROLE_KEY in Edge Function secrets (M0-11).
// Never ship the service-role key in the iOS bundle — set via:
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=...
// Deploy:
//   supabase functions deploy delete-account

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey =
      Deno.env.get("SUPABASE_ANON_KEY") ??
      Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
      "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      console.error("delete-account: missing Supabase env (M0-11 service_role?)");
      return jsonResponse(
        {
          error:
            "Server misconfigured. Set SUPABASE_SERVICE_ROLE_KEY via supabase secrets (M0-11).",
        },
        500,
      );
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing Authorization header" }, 401);
    }

    // User-scoped client: verify the JWT before using the service role.
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

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

    const admin = createClient(supabaseUrl, serviceRoleKey);

    // Explicit profile delete first: ON DELETE CASCADE removes plans,
    // plan_workouts, workout_exercises, workout_sessions, set_logs (0001 migration).
    const { error: profileError } = await admin
      .from("profiles")
      .delete()
      .eq("id", user.id);

    if (profileError) {
      console.error("delete-account: profile delete failed", profileError);
      return jsonResponse(
        { error: "Failed to delete profile data", detail: profileError.message },
        500,
      );
    }

    const { error: deleteUserError } = await admin.auth.admin.deleteUser(
      user.id,
    );

    if (deleteUserError) {
      console.error("delete-account: auth delete failed", deleteUserError);
      return jsonResponse(
        {
          error: "Failed to delete auth user",
          detail: deleteUserError.message,
        },
        500,
      );
    }

    return jsonResponse({ success: true, deletedUserId: user.id });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("delete-account: unexpected error", message);
    return jsonResponse({ error: "Unexpected error", detail: message }, 500);
  }
});
