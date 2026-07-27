import {
  BUSY_USER_MESSAGE,
  THROTTLED_USER_MESSAGE,
  type AskPluriErrorCode,
} from "./constants.ts";

export type AskPluriErrorBody = {
  error: AskPluriErrorCode;
  message: string;
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

/** Map Gemini HTTP status to busy vs throttled (no raw quota dumps). */
export function geminiStatusToErrorBody(
  status: number,
): AskPluriErrorBody | null {
  if (status === 429) return throttledErrorBody();
  if (status === 503 || status === 500) return busyErrorBody();
  return null;
}
