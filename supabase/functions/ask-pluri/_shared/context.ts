/**
 * Coach grounding context from Postgres-owned plan/history only (SPEC §14 #66a).
 * Never includes HealthKit samples or on-device Pluri Score inputs.
 */

import {
  MAX_SET_LOGS_PER_SESSION,
  RECENT_SESSION_DAYS,
  RECENT_SESSION_LIMIT,
} from "./constants.ts";

/** Keys that must never appear in the Gemini grounding payload. */
export const FORBIDDEN_CONTEXT_KEYS = [
  "healthkit",
  "healthKit",
  "hk_",
  "pluriScore",
  "pluri_score",
  "pluriScoreInputs",
  "heartRate",
  "heart_rate",
  "hkSample",
  "health_samples",
] as const;

export type CoachContextPayload = {
  profile: {
    goal: string | null;
    trainingExperience: string | null;
    injuries: unknown;
    equipment: string[];
  };
  activePlan: {
    id: string;
    goal: string;
    name: string | null;
    startDate: string;
    endDate: string;
    weeks: number;
    scheduleType: string;
    status: string;
  } | null;
  upcomingWorkouts: Array<{
    id: string;
    name: string;
    scheduledDate: string | null;
    scheduledDay: string | null;
    status: string;
    focus: string | null;
    durationMinutes: number;
    workoutType: string;
  }>;
  recentSessions: Array<{
    id: string;
    planWorkoutId: string | null;
    activityType: string;
    startedAt: string;
    endedAt: string | null;
    durationSeconds: number | null;
    notes: string | null;
    setLogs: Array<{
      exerciseName: string;
      setNumber: number;
      reps: number | null;
      weightKg: number | null;
      durationSeconds: number | null;
    }>;
  }>;
  currentPlanWorkout: {
    id: string;
    name: string;
    scheduledDate: string | null;
    status: string;
    focus: string | null;
    durationMinutes: number;
    exercises: Array<{
      id: string;
      name: string;
      targetSets: number | null;
      targetReps: string | null;
      orderIndex: number;
    }>;
  } | null;
};

export function recentSessionCutoffIso(
  now = new Date(),
  days = RECENT_SESSION_DAYS,
): string {
  const cutoff = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
  return cutoff.toISOString();
}

/** Deep-scan grounding JSON for forbidden HealthKit / Pluri Score keys. */
export function contextContainsForbiddenKeys(
  value: unknown,
  path = "",
): string[] {
  const hits: string[] = [];
  if (Array.isArray(value)) {
    value.forEach((item, index) => {
      hits.push(...contextContainsForbiddenKeys(item, `${path}[${index}]`));
    });
    return hits;
  }
  if (value !== null && typeof value === "object") {
    for (const [key, child] of Object.entries(
      value as Record<string, unknown>,
    )) {
      const lower = key.toLowerCase();
      for (const forbidden of FORBIDDEN_CONTEXT_KEYS) {
        if (lower.includes(forbidden.toLowerCase())) {
          hits.push(path ? `${path}.${key}` : key);
        }
      }
      hits.push(
        ...contextContainsForbiddenKeys(child, path ? `${path}.${key}` : key),
      );
    }
  }
  return hits;
}

/** Minimal structural type — runtime client is `@supabase/supabase-js`. */
// deno-lint-ignore no-explicit-any
type SupabaseLike = any;

function exerciseDisplayName(cached: unknown, fallbackId: string): string {
  if (cached && typeof cached === "object" && !Array.isArray(cached)) {
    const name = (cached as Record<string, unknown>).name;
    if (typeof name === "string" && name.trim()) return name.trim();
  }
  return fallbackId;
}

/**
 * Load owner plan/history context via the user-scoped Supabase client (RLS).
 * Does not read HealthKit or Pluri Score tables/fields into the payload.
 */
export async function loadCoachContext(
  client: SupabaseLike,
  userId: string,
  currentPlanWorkoutId?: string | null,
): Promise<CoachContextPayload> {
  const profileResult = await client
    .from("profiles")
    .select("goal, training_experience, injuries, equipment")
    .eq("id", userId)
    .maybeSingle();

  if (profileResult.error) {
    throw new Error(`profile load failed: ${profileResult.error.message}`);
  }

  const profileRow = (profileResult.data ?? null) as {
    goal?: string | null;
    training_experience?: string | null;
    injuries?: unknown;
    equipment?: string[] | null;
  } | null;

  const planResult = await client
    .from("plans")
    .select(
      "id, goal, name, start_date, end_date, weeks, schedule_type, status",
    )
    .eq("user_id", userId)
    .eq("status", "active")
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (planResult.error) {
    throw new Error(`plan load failed: ${planResult.error.message}`);
  }

  const planRow = (planResult.data ?? null) as {
    id: string;
    goal: string;
    name: string | null;
    start_date: string;
    end_date: string;
    weeks: number;
    schedule_type: string;
    status: string;
  } | null;

  let upcomingWorkouts: CoachContextPayload["upcomingWorkouts"] = [];
  if (planRow) {
    const workoutsResult = await client
      .from("plan_workouts")
      .select(
        "id, name, scheduled_date, scheduled_day, status, focus, duration_minutes, workout_type",
      )
      .eq("plan_id", planRow.id)
      .eq("status", "scheduled")
      .order("scheduled_date", { ascending: true })
      .limit(60);

    if (workoutsResult.error) {
      throw new Error(
        `plan_workouts load failed: ${workoutsResult.error.message}`,
      );
    }

    const rows = (workoutsResult.data ?? []) as Array<{
      id: string;
      name: string;
      scheduled_date: string | null;
      scheduled_day: string | null;
      status: string;
      focus: string | null;
      duration_minutes: number;
      workout_type: string;
    }>;

    upcomingWorkouts = rows.map((row) => ({
      id: row.id,
      name: row.name,
      scheduledDate: row.scheduled_date,
      scheduledDay: row.scheduled_day,
      status: row.status,
      focus: row.focus,
      durationMinutes: row.duration_minutes,
      workoutType: row.workout_type,
    }));
  }

  const cutoff = recentSessionCutoffIso();
  const sessionsResult = await client
    .from("workout_sessions")
    .select(
      "id, plan_workout_id, activity_type, started_at, ended_at, duration_seconds, notes",
    )
    .eq("user_id", userId)
    .not("ended_at", "is", null)
    .gte("ended_at", cutoff)
    .order("ended_at", { ascending: false })
    .limit(RECENT_SESSION_LIMIT);

  if (sessionsResult.error) {
    throw new Error(
      `workout_sessions load failed: ${sessionsResult.error.message}`,
    );
  }

  const sessionRows = (sessionsResult.data ?? []) as Array<{
    id: string;
    plan_workout_id: string | null;
    activity_type: string;
    started_at: string;
    ended_at: string | null;
    duration_seconds: number | null;
    notes: string | null;
  }>;

  const sessionIds = sessionRows.map((s) => s.id);
  const setLogsBySession = new Map<
    string,
    CoachContextPayload["recentSessions"][number]["setLogs"]
  >();

  if (sessionIds.length > 0) {
    const setLogsResult = await client
      .from("set_logs")
      .select(
        "session_id, exercise_name, set_number, reps, weight_kg, duration_seconds",
      )
      .in("session_id", sessionIds)
      .order("set_number", { ascending: true });

    if (setLogsResult.error) {
      throw new Error(`set_logs load failed: ${setLogsResult.error.message}`);
    }

    const setRows = (setLogsResult.data ?? []) as Array<{
      session_id: string;
      exercise_name: string;
      set_number: number;
      reps: number | null;
      weight_kg: number | null;
      duration_seconds: number | null;
    }>;

    for (const row of setRows) {
      const list = setLogsBySession.get(row.session_id) ?? [];
      if (list.length >= MAX_SET_LOGS_PER_SESSION) continue;
      list.push({
        exerciseName: row.exercise_name,
        setNumber: row.set_number,
        reps: row.reps,
        weightKg: row.weight_kg,
        durationSeconds: row.duration_seconds,
      });
      setLogsBySession.set(row.session_id, list);
    }
  }

  const recentSessions: CoachContextPayload["recentSessions"] = sessionRows.map(
    (row) => ({
      id: row.id,
      planWorkoutId: row.plan_workout_id,
      activityType: row.activity_type,
      startedAt: row.started_at,
      endedAt: row.ended_at,
      durationSeconds: row.duration_seconds,
      notes: row.notes,
      setLogs: setLogsBySession.get(row.id) ?? [],
    }),
  );

  let currentPlanWorkout: CoachContextPayload["currentPlanWorkout"] = null;
  if (currentPlanWorkoutId) {
    const pwResult = await client
      .from("plan_workouts")
      .select(
        "id, name, scheduled_date, status, focus, duration_minutes, plan_id",
      )
      .eq("id", currentPlanWorkoutId)
      .maybeSingle();

    if (pwResult.error) {
      throw new Error(
        `current plan_workout load failed: ${pwResult.error.message}`,
      );
    }

    const pw = pwResult.data as {
      id: string;
      name: string;
      scheduled_date: string | null;
      status: string;
      focus: string | null;
      duration_minutes: number;
      plan_id: string;
    } | null;

    if (pw) {
      // Ownership via active plan when present; otherwise still RLS-gated.
      if (!planRow || pw.plan_id === planRow.id) {
        const exResult = await client
          .from("workout_exercises")
          .select(
            "id, workoutx_exercise_id, cached_metadata, target_sets, target_reps, order_index",
          )
          .eq("plan_workout_id", pw.id)
          .order("order_index", { ascending: true })
          .limit(40);

        if (exResult.error) {
          throw new Error(
            `workout_exercises load failed: ${exResult.error.message}`,
          );
        }

        const exercises = ((exResult.data ?? []) as Array<{
          id: string;
          workoutx_exercise_id: string;
          cached_metadata: unknown;
          target_sets: number | null;
          target_reps: string | null;
          order_index: number;
        }>).map((ex) => ({
          id: ex.id,
          name: exerciseDisplayName(
            ex.cached_metadata,
            ex.workoutx_exercise_id,
          ),
          targetSets: ex.target_sets,
          targetReps: ex.target_reps,
          orderIndex: ex.order_index,
        }));

        currentPlanWorkout = {
          id: pw.id,
          name: pw.name,
          scheduledDate: pw.scheduled_date,
          status: pw.status,
          focus: pw.focus,
          durationMinutes: pw.duration_minutes,
          exercises,
        };
      }
    }
  }

  return {
    profile: {
      goal: profileRow?.goal ?? null,
      trainingExperience: profileRow?.training_experience ?? null,
      injuries: profileRow?.injuries ?? [],
      equipment: profileRow?.equipment ?? [],
    },
    activePlan: planRow
      ? {
        id: planRow.id,
        goal: planRow.goal,
        name: planRow.name,
        startDate: planRow.start_date,
        endDate: planRow.end_date,
        weeks: planRow.weeks,
        scheduleType: planRow.schedule_type,
        status: planRow.status,
      }
      : null,
    upcomingWorkouts,
    recentSessions,
    currentPlanWorkout,
  };
}
