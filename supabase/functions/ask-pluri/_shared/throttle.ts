import {
  THROTTLE_MAX_REQUESTS,
  THROTTLE_WINDOW_MS,
} from "./constants.ts";

type Bucket = { windowStart: number; count: number };

const buckets = new Map<string, Bucket>();

/** Simple per-isolate sliding window throttle. Returns true if allowed. */
export function tryConsumeThrottle(
  userId: string,
  now = Date.now(),
  max = THROTTLE_MAX_REQUESTS,
  windowMs = THROTTLE_WINDOW_MS,
): boolean {
  const existing = buckets.get(userId);
  if (!existing || now - existing.windowStart >= windowMs) {
    buckets.set(userId, { windowStart: now, count: 1 });
    return true;
  }
  if (existing.count >= max) {
    return false;
  }
  existing.count += 1;
  return true;
}

/** Test helper — clear in-memory buckets. */
export function resetThrottleForTests(): void {
  buckets.clear();
}
