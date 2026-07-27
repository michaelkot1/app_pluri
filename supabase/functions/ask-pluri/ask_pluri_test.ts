/**
 * M6-04 unit tests for ask-pluri (mocked Gemini; no real API key required).
 *
 * Run from repo root:
 *   deno test --allow-read --allow-env supabase/functions/ask-pluri/ask_pluri_test.ts
 */

import {
  assert,
  assertEquals,
  assertFalse,
} from "jsr:@std/assert@1";
import { parseCoachActions, parseGeminiCoachPayload } from "./_shared/actions.ts";
import {
  contextContainsForbiddenKeys,
  FORBIDDEN_CONTEXT_KEYS,
} from "./_shared/context.ts";
import {
  busyErrorBody,
  geminiStatusToErrorBody,
  throttledErrorBody,
} from "./_shared/errors.ts";
import { handleAskPluriRequest } from "./_shared/handler.ts";
import { ASK_PLURI_SYSTEM_PROMPT } from "./_shared/prompt.ts";
import { resetThrottleForTests } from "./_shared/throttle.ts";
import { tryConsumeThrottle } from "./_shared/throttle.ts";

/** Assert client JSON never leaks provider/quota/detail fields (#66f). */
function assertNoRawErrorLeakage(body: unknown) {
  const serialized = JSON.stringify(body);
  assertFalse("detail" in (body as Record<string, unknown>));
  assertFalse(serialized.includes("quota"));
  assertFalse(serialized.includes("RESOURCE_EXHAUSTED"));
  assertFalse(serialized.includes("HTTP "));
  assertFalse(/AIza[0-9A-Za-z_-]{10,}/.test(serialized));
}

const FIXTURE_CONTEXT_PATH = new URL(
  "./fixtures/sample_context.json",
  import.meta.url,
);
const FIXTURE_REPLY_PATH = new URL(
  "./fixtures/gemini_reply_with_actions.json",
  import.meta.url,
);

Deno.test("parseCoachActions keeps add/remove and ignores unknown types", async () => {
  const fixture = JSON.parse(await Deno.readTextFile(FIXTURE_REPLY_PATH));
  const actions = parseCoachActions(fixture.actions);
  assertEquals(actions.length, 2);
  assertEquals(actions[0], {
    type: "add_workout",
    sourceWorkoutId: "22222222-2222-4222-8222-222222222222",
    date: "2026-07-30",
  });
  assertEquals(actions[1], {
    type: "remove_workout",
    planWorkoutId: "55555555-5555-4555-8555-555555555555",
  });
});

Deno.test("parseCoachActions drops invalid uuids/dates", () => {
  const actions = parseCoachActions([
    { type: "add_workout", sourceWorkoutId: "not-a-uuid", date: "2026-07-30" },
    {
      type: "add_workout",
      sourceWorkoutId: "22222222-2222-4222-8222-222222222222",
      date: "07/30/2026",
    },
    { type: "remove_workout", planWorkoutId: "nope" },
  ]);
  assertEquals(actions, []);
});

Deno.test("parseGeminiCoachPayload reads reply + actions", async () => {
  const text = await Deno.readTextFile(FIXTURE_REPLY_PATH);
  const parsed = parseGeminiCoachPayload(text);
  assert(parsed.reply.includes("Push day"));
  assertEquals(parsed.actions.length, 2);
});

Deno.test("sample grounding fixture excludes HealthKit / Pluri Score keys", async () => {
  const context = JSON.parse(await Deno.readTextFile(FIXTURE_CONTEXT_PATH));
  const hits = contextContainsForbiddenKeys(context);
  assertEquals(hits, []);
  const serialized = JSON.stringify(context);
  assertFalse(serialized.includes("synced_to_health"));
  assertFalse(serialized.includes("pluriScore"));
  assertFalse(serialized.includes("pluri_score"));
  assertFalse(serialized.includes("heartRate"));
  assertFalse(serialized.toLowerCase().includes("healthkit"));
  assertEquals(FORBIDDEN_CONTEXT_KEYS.length > 0, true);
});
Deno.test("system prompt encodes #66f safety rails", () => {
  const prompt = ASK_PLURI_SYSTEM_PROMPT.toLowerCase();
  assert(prompt.includes("kind"));
  assert(prompt.includes("informative") || prompt.includes("encouraging"));
  assert(
    prompt.includes("not a doctor") || prompt.includes("medical"),
    "medical / injury disclaimer missing",
  );
  assert(
    prompt.includes("refuse") || prompt.includes("gently refuse"),
    "harmful-advice refusal missing",
  );
  assert(
    prompt.includes("other users") || prompt.includes("other user's"),
    "cross-user data ban missing",
  );
  assert(
    prompt.includes("api key") || prompt.includes("raw provider"),
    "API / provider leakage ban missing",
  );
  assertFalse(prompt.includes("aiza"));
});

Deno.test("busy and throttled error shapes are distinct UI codes", () => {
  assertEquals(busyErrorBody().error, "busy");
  assertEquals(throttledErrorBody().error, "throttled");
  assert(busyErrorBody().message.toLowerCase().includes("busy"));
  assertNoRawErrorLeakage(busyErrorBody());
  assertNoRawErrorLeakage(throttledErrorBody());
  // Non-mapped Gemini statuses fall through to busy at the call site;
  // mapped ones never carry HTTP detail.
  assertEquals(geminiStatusToErrorBody(429)?.error, "throttled");
  assertEquals(geminiStatusToErrorBody(503)?.error, "busy");
  assertEquals(geminiStatusToErrorBody(400), null);
});

Deno.test("throttle rejects after max requests in window", () => {
  resetThrottleForTests();
  const userId = "throttle-user";
  for (let i = 0; i < 8; i++) {
    assert(tryConsumeThrottle(userId, 1_000));
  }
  assertFalse(tryConsumeThrottle(userId, 1_000));
  assert(tryConsumeThrottle(userId, 1_000 + 60_000));
});

Deno.test("missing Authorization returns 401", async () => {
  resetThrottleForTests();
  const response = await handleAskPluriRequest(
    new Request("http://local/ask-pluri", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: "hi" }),
    }),
    {
      env: {
        supabaseUrl: "https://example.supabase.co",
        anonKey: "anon-test",
        geminiApiKey: "test-key-not-real",
      },
    },
  );
  assertEquals(response.status, 401);
  const body = await response.json();
  assertEquals(body.error, "Unauthorized");
  assertNoRawErrorLeakage(body);
});

Deno.test("invalid JWT returns stable 401 without Auth message leakage", async () => {
  resetThrottleForTests();
  const response = await handleAskPluriRequest(
    new Request("http://local/ask-pluri", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer bad-token",
      },
      body: JSON.stringify({ message: "hi" }),
    }),
    {
      env: {
        supabaseUrl: "https://example.supabase.co",
        anonKey: "anon-test",
        geminiApiKey: "test-key-not-real",
      },
      createUserClient: () =>
        ({
          auth: {
            getUser: async () => ({
              data: { user: null },
              error: { message: "Invalid JWT" },
            }),
          },
        }) as never,
    },
  );
  assertEquals(response.status, 401);
  const body = await response.json();
  assertEquals(body.error, "Unauthorized");
  assertFalse(JSON.stringify(body).includes("Invalid JWT"));
  assertNoRawErrorLeakage(body);
});

Deno.test("happy path returns reply + actions and never touches plan_workouts writes", async () => {
  resetThrottleForTests();
  const fixtureReply = JSON.parse(await Deno.readTextFile(FIXTURE_REPLY_PATH));
  const fixtureContext = JSON.parse(
    await Deno.readTextFile(FIXTURE_CONTEXT_PATH),
  );

  const mutatedTables: string[] = [];
  const writeOps: string[] = [];

  const response = await handleAskPluriRequest(
    new Request("http://local/ask-pluri", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer test-jwt",
      },
      body: JSON.stringify({
        message: "Can you add another push day?",
        conversationId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        currentPlanWorkoutId: "22222222-2222-4222-8222-222222222222",
      }),
    }),
    {
      env: {
        supabaseUrl: "https://example.supabase.co",
        anonKey: "anon-test",
        geminiApiKey: "test-key-not-real",
        geminiModel: "gemini-flash-latest",
      },
      geminiGenerate: async () => ({
        ok: true,
        reply: fixtureReply.reply,
        actions: parseCoachActions(fixtureReply.actions),
      }),
      createUserClient: () => mockSupabaseClient({
        mutatedTables,
        writeOps,
        fixtureContext,
      }) as never,
    },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.reply, fixtureReply.reply);
  assertEquals(body.conversationId, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa");
  assertEquals(body.actions.length, 2);
  assert(body.messageIds?.user);
  assert(body.messageIds?.assistant);

  assertFalse(writeOps.some((op) => op.startsWith("plan_workouts:")));
  assert(
    mutatedTables.every((table) => table === "chat_messages"),
    `unexpected mutated tables: ${mutatedTables.join(",")}`,
  );
});

Deno.test("Gemini 429 maps to throttled shape", async () => {
  resetThrottleForTests();
  const fixtureContext = JSON.parse(
    await Deno.readTextFile(FIXTURE_CONTEXT_PATH),
  );
  const response = await handleAskPluriRequest(
    new Request("http://local/ask-pluri", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer test-jwt",
      },
      body: JSON.stringify({ message: "hello" }),
    }),
    {
      env: {
        supabaseUrl: "https://example.supabase.co",
        anonKey: "anon-test",
        geminiApiKey: "test-key-not-real",
      },
      geminiGenerate: async () => ({
        ok: false,
        status: 429,
        errorBody: throttledErrorBody(),
      }),
      createUserClient: () =>
        mockSupabaseClient({
          mutatedTables: [],
          writeOps: [],
          fixtureContext,
        }) as never,
    },
  );
  assertEquals(response.status, 429);
  const body = await response.json();
  assertEquals(body.error, "throttled");
  assertNoRawErrorLeakage(body);
});

Deno.test("non-busy Gemini failure returns busy shape without detail", async () => {
  resetThrottleForTests();
  const fixtureContext = JSON.parse(
    await Deno.readTextFile(FIXTURE_CONTEXT_PATH),
  );
  const response = await handleAskPluriRequest(
    new Request("http://local/ask-pluri", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer test-jwt",
      },
      body: JSON.stringify({ message: "hello" }),
    }),
    {
      env: {
        supabaseUrl: "https://example.supabase.co",
        anonKey: "anon-test",
        geminiApiKey: "test-key-not-real",
      },
      geminiGenerate: async () => ({
        ok: false,
        status: 400,
        // Legacy-shaped body with detail — handler must not pass it through.
        errorBody: {
          error: "Gemini request failed",
          detail: "HTTP 400 RESOURCE_EXHAUSTED quota",
        } as never,
      }),
      createUserClient: () =>
        mockSupabaseClient({
          mutatedTables: [],
          writeOps: [],
          fixtureContext,
        }) as never,
    },
  );
  assertEquals(response.status, 502);
  const body = await response.json();
  assertEquals(body.error, "busy");
  assert(body.message.toLowerCase().includes("busy"));
  assertNoRawErrorLeakage(body);
});

Deno.test("DB failure responses omit PostgREST detail", async () => {
  resetThrottleForTests();
  const response = await handleAskPluriRequest(
    new Request("http://local/ask-pluri", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer test-jwt",
      },
      body: JSON.stringify({ message: "hello" }),
    }),
    {
      env: {
        supabaseUrl: "https://example.supabase.co",
        anonKey: "anon-test",
        geminiApiKey: "test-key-not-real",
      },
      createUserClient: () =>
        ({
          auth: {
            getUser: async () => ({
              data: {
                user: { id: "99999999-9999-4999-8999-999999999999" },
              },
              error: null,
            }),
          },
          from(table: string) {
            const builder: Record<string, unknown> = {
              select() {
                return builder;
              },
              eq() {
                return builder;
              },
              order() {
                return builder;
              },
              limit() {
                return builder;
              },
              maybeSingle: async () => ({
                data: null,
                error: {
                  message:
                    'relation "chat_messages" does not exist — permission denied for schema public',
                },
              }),
            };
            assertEquals(table, "chat_messages");
            return builder;
          },
        }) as never,
    },
  );
  assertEquals(response.status, 500);
  const body = await response.json();
  assertEquals(body.error, "Failed to load conversation");
  assertFalse(JSON.stringify(body).includes("permission denied"));
  assertFalse(JSON.stringify(body).includes("does not exist"));
  assertNoRawErrorLeakage(body);
});

Deno.test("repo sources do not embed a Gemini API key", async () => {
  const root = new URL(".", import.meta.url);
  // Production sources + fixtures only (exclude this test file's needle strings).
  const files = [
    "index.ts",
    "_shared/handler.ts",
    "_shared/gemini.ts",
    "_shared/constants.ts",
    "_shared/actions.ts",
    "_shared/context.ts",
    "_shared/errors.ts",
    "_shared/prompt.ts",
    "_shared/throttle.ts",
    "fixtures/sample_context.json",
    "fixtures/gemini_reply_with_actions.json",
  ];
  for (const relative of files) {
    const text = await Deno.readTextFile(new URL(relative, root));
    assertFalse(/AIza[0-9A-Za-z_-]{20,}/.test(text));
    assertFalse(/GEMINI_API_KEY\s*=\s*["']?AIza/.test(text));
  }
});

function mockSupabaseClient(args: {
  mutatedTables: string[];
  writeOps: string[];
  fixtureContext: {
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
    upcomingWorkouts: Array<Record<string, unknown>>;
    recentSessions: Array<Record<string, unknown>>;
    currentPlanWorkout: {
      id: string;
      name: string;
      scheduledDate: string | null;
      status: string;
      focus: string | null;
      durationMinutes: number;
      exercises: Array<Record<string, unknown>>;
    } | null;
  };
}) {
  const userId = "99999999-9999-4999-8999-999999999999";
  let insertCount = 0;

  function makeBuilder(table: string) {
    const state: {
      filters: Record<string, unknown>;
      op: "select" | "insert";
      payload?: unknown;
    } = { filters: {}, op: "select" };

    const builder: Record<string, unknown> = {
      select(_columns: string) {
        return builder;
      },
      insert(payload: unknown) {
        state.op = "insert";
        state.payload = payload;
        args.mutatedTables.push(table);
        args.writeOps.push(`${table}:insert`);
        return builder;
      },
      update() {
        args.writeOps.push(`${table}:update`);
        throw new Error(`unexpected update on ${table}`);
      },
      delete() {
        args.writeOps.push(`${table}:delete`);
        throw new Error(`unexpected delete on ${table}`);
      },
      eq(column: string, value: unknown) {
        state.filters[column] = value;
        return builder;
      },
      in(column: string, values: unknown[]) {
        state.filters[column] = values;
        return builder;
      },
      gte(column: string, value: unknown) {
        state.filters[column] = value;
        return builder;
      },
      not() {
        return builder;
      },
      order() {
        return builder;
      },
      limit() {
        return builder;
      },
      maybeSingle: async () => resolveQuery(table, state, true),
      single: async () => resolveQuery(table, state, false),
      then(
        resolve: (value: unknown) => unknown,
        reject?: (reason: unknown) => unknown,
      ) {
        return Promise.resolve(resolveQuery(table, state, false)).then(
          resolve,
          reject,
        );
      },
    };

    async function resolveQuery(
      tableName: string,
      current: typeof state,
      maybeSingle: boolean,
    ) {
      if (current.op === "insert" && tableName === "chat_messages") {
        insertCount += 1;
        const id = insertCount === 1
          ? "b1111111-1111-4111-8111-111111111111"
          : "b2222222-2222-4222-8222-222222222222";
        return { data: { id }, error: null };
      }

      if (tableName === "profiles") {
        return {
          data: {
            goal: args.fixtureContext.profile.goal,
            training_experience: args.fixtureContext.profile.trainingExperience,
            injuries: args.fixtureContext.profile.injuries,
            equipment: args.fixtureContext.profile.equipment,
          },
          error: null,
        };
      }

      if (tableName === "plans") {
        const plan = args.fixtureContext.activePlan;
        return {
          data: plan
            ? {
              id: plan.id,
              goal: plan.goal,
              name: plan.name,
              start_date: plan.startDate,
              end_date: plan.endDate,
              weeks: plan.weeks,
              schedule_type: plan.scheduleType,
              status: plan.status,
            }
            : null,
          error: null,
        };
      }

      if (tableName === "plan_workouts") {
        if (current.filters.id) {
          const currentPw = args.fixtureContext.currentPlanWorkout;
          return {
            data: currentPw
              ? {
                id: currentPw.id,
                name: currentPw.name,
                scheduled_date: currentPw.scheduledDate,
                status: currentPw.status,
                focus: currentPw.focus,
                duration_minutes: currentPw.durationMinutes,
                plan_id: args.fixtureContext.activePlan?.id,
              }
              : null,
            error: null,
          };
        }
        return {
          data: args.fixtureContext.upcomingWorkouts.map((w) => ({
            id: w.id,
            name: w.name,
            scheduled_date: w.scheduledDate,
            scheduled_day: w.scheduledDay,
            status: w.status,
            focus: w.focus,
            duration_minutes: w.durationMinutes,
            workout_type: w.workoutType,
          })),
          error: null,
        };
      }

      if (tableName === "workout_exercises") {
        return {
          data: (args.fixtureContext.currentPlanWorkout?.exercises ?? []).map(
            (ex) => ({
              id: ex.id,
              workoutx_exercise_id: "ex1",
              cached_metadata: { name: ex.name },
              target_sets: ex.targetSets,
              target_reps: ex.targetReps,
              order_index: ex.orderIndex,
            }),
          ),
          error: null,
        };
      }

      if (tableName === "workout_sessions") {
        return {
          data: args.fixtureContext.recentSessions.map((s) => ({
            id: s.id,
            plan_workout_id: s.planWorkoutId,
            activity_type: s.activityType,
            started_at: s.startedAt,
            ended_at: s.endedAt,
            duration_seconds: s.durationSeconds,
            notes: s.notes,
          })),
          error: null,
        };
      }

      if (tableName === "set_logs") {
        const logs = args.fixtureContext.recentSessions.flatMap((s) =>
          ((s.setLogs as Array<Record<string, unknown>>) ?? []).map((log) => ({
            session_id: s.id,
            exercise_name: log.exerciseName,
            set_number: log.setNumber,
            reps: log.reps,
            weight_kg: log.weightKg,
            duration_seconds: log.durationSeconds,
          }))
        );
        return { data: logs, error: null };
      }

      if (tableName === "chat_messages") {
        if (maybeSingle) {
          return { data: null, error: null };
        }
        return { data: [], error: null };
      }

      return { data: maybeSingle ? null : [], error: null };
    }

    return builder;
  }

  return {
    auth: {
      getUser: async () => ({
        data: { user: { id: userId } },
        error: null,
      }),
    },
    from(table: string) {
      return makeBuilder(table);
    },
  };
}
