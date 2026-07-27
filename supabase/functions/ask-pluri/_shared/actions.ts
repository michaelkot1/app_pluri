/**
 * Structured coach tool actions (SPEC §14 #66g).
 * Returned to the client only — never applied by the Edge Function (#66h).
 */

export type AddWorkoutAction = {
  type: "add_workout";
  sourceWorkoutId: string;
  date: string;
};

export type RemoveWorkoutAction = {
  type: "remove_workout";
  planWorkoutId: string;
};

export type CoachAction = AddWorkoutAction | RemoveWorkoutAction;

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

function asRecord(value: unknown): Record<string, unknown> | null {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function readString(
  record: Record<string, unknown>,
  ...keys: string[]
): string | null {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "string" && value.trim().length > 0) {
      return value.trim();
    }
  }
  return null;
}

/** Parse and sanitize Gemini/tool JSON; unknown types are ignored safely. */
export function parseCoachActions(raw: unknown): CoachAction[] {
  if (!Array.isArray(raw)) return [];

  const actions: CoachAction[] = [];
  for (const item of raw) {
    const record = asRecord(item);
    if (!record) continue;

    const type = readString(record, "type");
    if (type === "add_workout") {
      const sourceWorkoutId = readString(
        record,
        "sourceWorkoutId",
        "source_workout_id",
      );
      const date = readString(record, "date");
      if (
        sourceWorkoutId &&
        UUID_RE.test(sourceWorkoutId) &&
        date &&
        DATE_RE.test(date)
      ) {
        actions.push({ type: "add_workout", sourceWorkoutId, date });
      }
      continue;
    }

    if (type === "remove_workout") {
      const planWorkoutId = readString(
        record,
        "planWorkoutId",
        "plan_workout_id",
      );
      if (planWorkoutId && UUID_RE.test(planWorkoutId)) {
        actions.push({ type: "remove_workout", planWorkoutId });
      }
    }
    // Unknown types intentionally ignored.
  }
  return actions;
}

/** Parse model JSON body `{ reply, actions? }` with safe defaults. */
export function parseGeminiCoachPayload(text: string): {
  reply: string;
  actions: CoachAction[];
} {
  try {
    const parsed = JSON.parse(text) as unknown;
    const record = asRecord(parsed);
    if (!record) {
      return { reply: text.trim(), actions: [] };
    }
    const reply =
      typeof record.reply === "string" && record.reply.trim().length > 0
        ? record.reply.trim()
        : text.trim();
    return {
      reply,
      actions: parseCoachActions(record.actions),
    };
  } catch {
    return { reply: text.trim(), actions: [] };
  }
}
