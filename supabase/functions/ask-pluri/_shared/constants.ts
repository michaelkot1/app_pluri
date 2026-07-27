/** M6-03 Ask Pluri constants (SPEC §14 #66). Recorded in TASKS Learned. */

/** Look back window for completed sessions fed to Gemini. */
export const RECENT_SESSION_DAYS = 28;

/** Cap on completed sessions in the grounding payload. */
export const RECENT_SESSION_LIMIT = 20;

/** Cap on set_logs per session in the compact summary. */
export const MAX_SET_LOGS_PER_SESSION = 40;

/** Prior chat turns loaded for the open conversation. */
export const CHAT_HISTORY_LIMIT = 40;

/** App-side throttle window (ms). */
export const THROTTLE_WINDOW_MS = 60_000;

/** Max asks per user per throttle window. */
export const THROTTLE_MAX_REQUESTS = 8;

/** Interim Gemini model; override with GEMINI_MODEL secret/env. */
export const DEFAULT_GEMINI_MODEL = "gemini-flash-latest";

/** Distinct busy/throttle error codes for client UI (never raw quota dumps). */
export type AskPluriErrorCode = "busy" | "throttled";

export const BUSY_USER_MESSAGE =
  "Your coach is busy — try again shortly.";
export const THROTTLED_USER_MESSAGE =
  "Your coach is busy — try again shortly.";
