import {
  BUSY_USER_MESSAGE,
  THROTTLED_USER_MESSAGE,
  type AskPluriErrorCode,
} from "./constants.ts";

export type AskPluriErrorBody = {
  error: AskPluriErrorCode;
  message: string;
};

/** Client-facing errors never include provider/Supabase `detail` fields (#66f). */
export type SafeClientErrorBody = {
  error: string;
  message?: string;
};

export function busyErrorBody(
  message = BUSY_USER_MESSAGE,
): AskPluriErrorBody {
  return { error: "busy", message };
}

export function throttledErrorBody(
  message = THROTTLED_USER_MESSAGE,
): AskPluriErrorBody {
  return { error: "throttled", message };
}

/** Stable unauthorized shape — never echo Auth/JWT provider messages. */
export function unauthorizedErrorBody(): SafeClientErrorBody {
  return { error: "Unauthorized" };
}

/** Generic server failure without raw exception / PostgREST leakage. */
export function safeServerErrorBody(error: string): SafeClientErrorBody {
  return { error };
}

/** Map Gemini HTTP status to busy vs throttled (no raw quota dumps). */
export function geminiStatusToErrorBody(
  status: number,
): AskPluriErrorBody | null {
  if (status === 429) return throttledErrorBody();
  if (status === 503 || status === 500) return busyErrorBody();
  return null;
}
