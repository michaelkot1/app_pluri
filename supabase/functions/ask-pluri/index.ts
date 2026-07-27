// ask-pluri Edge Function (M6-03).
//
// Verifies the caller's JWT, loads owner plan/history context from Postgres
// (never HealthKit / on-device Pluri Score), calls Gemini with the server-side
// GEMINI_API_KEY, persists chat_messages, and returns the reply plus structured
// add/remove tool actions for the client to confirm (SPEC §14 #66h).
//
// Does NOT mutate plan_workouts.
//
// Secrets (never in the iOS bundle):
//   supabase secrets set GEMINI_API_KEY=...
// Optional model override:
//   supabase secrets set GEMINI_MODEL=gemini-flash-latest
// Deploy:
//   supabase functions deploy ask-pluri
//
// Soft blocker: production deploy also depends on project secrets being set
// (M0-11 may still block related service-role secrets for other functions).

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { handleAskPluriRequest } from "./_shared/handler.ts";

Deno.serve((req: Request) => handleAskPluriRequest(req));
