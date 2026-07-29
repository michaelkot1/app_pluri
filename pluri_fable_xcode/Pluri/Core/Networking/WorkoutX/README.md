# WorkoutX API — spike notes (M1-01)

Findings from hitting the real WorkoutX API with the key in `.env`
(`WORKOUTX_ENDPOINT` = `https://api.workoutxapp.com/v1`). No key material is
recorded here — see `AGENTS.md §2`.

## Auth

- **Not** the documented-by-omission bearer scheme. A plain
  `Authorization: Bearer <key>` request returns `401 Unauthorized` with:
  `"API key required. Pass via X-WorkoutX-Key header or ?api-key= query param."`
- Correct mechanism: custom header **`X-WorkoutX-Key: <key>`** (a `?api-key=`
  query param is also accepted per the error message; header is what we use).
- Invalid/malformed key → `401` with `{"error":"Unauthorized","message":"Invalid API key format."}`.
- The service fronts itself as a RapidAPI product — 404 error bodies link to
  `https://rapidapi.com/workoutx-workoutx-default/api/workoutx-fitness-exercises`.
  The `docs.workoutx.io` domain referenced in the 401 body does not resolve.

## Endpoints (confirmed live)

| Endpoint | Notes |
|---|---|
| `GET /exercises` | Paginated list. Query params: `limit`, `offset` (both optional; observed defaults return the full unpaginated set when omitted — always pass an explicit `limit`). |
| `GET /exercises/{id}` | Single exercise by id (zero-padded string, e.g. `"0001"`). Unknown id → `404` `{"error":"Not Found","message":"Exercise '<id>' not found. Exercise IDs are not sequential — there are gaps in the ID range.", "tip":"Fetch all exercises first with GET /v1/exercises to get valid IDs..."}`. |
| `GET /exercises/equipmentList` | `["Assisted", "Assisted (towel)", ... "Wheel Roller"]` — 32 strings. Matches SPEC.md §3.2 Q6 equipment list (minor punctuation differences, e.g. `"Dumbbell (used As Handles For Deeper Range)"` vs SPEC's `"Dumbbell (used as Handles for Deeper Range)"`, and `"Dumbbell, Exercise Ball"` vs SPEC's `"Dumbbell + Exercise Ball"` — cosmetic only). |
| `GET /exercises/bodyPartList` | `["Back","Cardio","Chest","Lower Arms","Lower Legs","Neck","Shoulders","Upper Arms","Upper Legs","Waist"]` — exact match for SPEC §3.2 Q7 injury areas. |
| `GET /exercises/targetList` | `["Abductors","Abs","Adductors","Biceps","Calves","Cardiovascular System","Delts","Forearms","Glutes","Hamstrings","Lats","Levator Scapulae","Pectorals","Quads","Serratus Anterior","Spine","Traps","Triceps","Upper Back"]` — target-muscle taxonomy (finer-grained than `bodyPart`). |

No separate `/equipment` or `/muscles` endpoints exist (404) — the list
endpoints above are namespaced under `/exercises/...`.

## Response shape — exercise list (`GET /exercises?limit=&offset=`)

```json
{
  "total": 1327,
  "count": 2,
  "data": [
    {
      "id": "0001",
      "name": "3/4 Sit-up",
      "bodyPart": "Waist",
      "equipment": "Body Weight",
      "target": "Abs",
      "secondaryMuscles": ["Hip Flexors", "Lower Back"],
      "instructions": ["Lie flat on your back...", "..."],
      "gifUrl": "https://api.workoutxapp.com/v1/gifs/0001.gif",
      "category": "strength",
      "difficulty": "beginner",
      "mechanic": "isolation",
      "force": "push",
      "met": 3.5,
      "caloriesPerMinute": 4.3,
      "description": "3/4 Sit-up is a beginner single-joint isolation pushing exercise...",
      "isUnilateral": false,
      "popularityRank": 5,
      "recommendedSets": "3",
      "recommendedReps": "10-15",
      "joint_focus": "lumbar_spine",
      "intensity_level": "gentle",
      "movement_tags": ["beginner-friendly", "controlled-movement", "minimal-equipment", "low-intensity", "joint-friendly"]
    }
  ]
}
```

`GET /exercises/{id}` returns the same object shape unwrapped (no envelope).

Fields actually observed across a 50-item sample (superset): `id`, `name`,
`bodyPart`, `equipment`, `target`, `secondaryMuscles`, `instructions`,
`gifUrl`, `category`, `difficulty`, `mechanic`, `force`, `met`,
`caloriesPerMinute`, `description`, `isUnilateral`, `popularityRank`,
`recommendedSets`, `recommendedReps`, `joint_focus`, `intensity_level`,
`movement_tags`. No field beyond this set appeared.

### Media / video (deviation from TASKS.md M1-02 wording)

- **Image/animation:** `gifUrl` — an animated GIF, e.g.
  `https://api.workoutxapp.com/v1/gifs/{id}.gif`. This is the only visual
  media the live API provides.
- **The GIF URL needs auth.** An unauthenticated `GET` returns **401** — the
  same `X-WorkoutX-Key` header the JSON endpoints want. That header can never
  ship in the iOS bundle (AGENTS §2), and with a ~500/month quota, users
  scrolling a workout would burn it. So no Pluri screen ever loads `gifUrl`.
- **Video URL:** **no such field or endpoint exists upstream.** Tried
  `GET /exercises/{id}/video`, `GET /videos/{id}.mp4`, and
  `GET /exercises?media=video` — all either `404` or ignored (no effect on
  response shape). SPEC §8 ("image/animation ↔ video toggle... video = real
  person performing the exercise") assumes a video the real API doesn't supply.
- **Decision (SPEC §14 #79, supersedes the always-`nil` interim of #11):**
  Pluri mirrors its own media. Each GIF is fetched **exactly once**, server-side,
  transcoded to a small looping MP4, and uploaded to the public-read
  `exercise-media` Storage bucket; `exercises.video_url` holds the resulting CDN
  URL and `Exercise.videoURL` is populated from it. `gif_url` keeps its original
  WorkoutX value as provenance. Exercises the job hasn't covered yet have
  `video_url = nil` and show a placeholder — never a broken frame.

## Mirroring exercise media (owner-run)

`Scripts/mirror_exercise_media.mjs` is the only path that produces MP4s: it
needs local **ffmpeg**, which Supabase Edge Functions (Deno) don't have. Node
≥ 20, no npm dependencies. Secrets come from the gitignored repo-root `.env`
(`WORKOUTX_API_KEY` plus `SUPABASE_URL` and `SUPABASE_SECRET_KEY` — the
`SUPABASE_SERVICE_ROLE_KEY` slot currently holds an anon JWT, which cannot
write Storage).

```bash
brew install ffmpeg

# See what a run would touch, without spending any quota.
node Scripts/mirror_exercise_media.mjs --hot-set --dry-run

# Cover the ~89 exercises real plans reference, 25 at a time.
node Scripts/mirror_exercise_media.mjs --hot-set --limit=25

# Then backfill the catalog tail (ordered by popularity_rank).
node Scripts/mirror_exercise_media.mjs --limit=25

# One-offs / re-encodes.
node Scripts/mirror_exercise_media.mjs --ids=0001,0031 --force
```

Each line logs the GIF → MP4 size and WorkoutX's remaining quota headers; the
run aborts on `401`/`429` rather than draining the monthly budget. Already
mirrored rows are skipped unless `--force`. Typical output is ~30 KB of MP4 per
exercise from a ~400 KB GIF.

## Pagination

- `limit` / `offset` query params, both integers, both optional.
- Response envelope always reports `total` (total catalog size, 1327) and
  `count` (size of `data` in this response) alongside `data`.
- No `next`/cursor links — pagination is purely offset-based.
- **⚠️ Behavior change observed 2026-07-13 (root cause of the M1-18 device
  bug):** the free plan now caps every response at **10 rows** regardless of
  the requested `limit` (verified with `limit=2/10/11/25/50/100` and with no
  `limit` at all — `count` never exceeds 10). The M1-01 note above about the
  full unpaginated set being returned no longer holds. Consequence: a full
  catalog fetch needs ⌈1327 ÷ 10⌉ = 133 requests, which slams into the
  30-requests/window burst limit (429) before finishing and burns ~a quarter
  of the monthly quota per attempt. **The app therefore no longer fetches the
  catalog from this API** — catalog reads come from the Supabase-seeded
  `exercises` snapshot via `SupabaseExerciseCatalogClient` (SPEC §14 #25).
  `LiveWorkoutXClient` remains for single-exercise lookups and a future
  paid-tier/full-fetch path.

## Rate limits (from response headers)

Observed on a `free` plan key (`X-WorkoutX-Plan: free`):

| Header | Observed value | Meaning |
|---|---|---|
| `X-RateLimit-Limit` | `30` | Requests allowed per short window (burst). |
| `X-RateLimit-Remaining` | decremented by 1 per request | Remaining in the current window. |
| `X-Quota-Limit` | `500` | Longer-window/monthly quota. |
| `X-Quota-Remaining` | decremented per request (not always by 1 — larger `limit` list requests appear to cost more) | Remaining quota. |
| `X-Quota-Reset` | `null` (observed) | Not populated for this plan/window. |
| `X-Unique-GIF-Limit` / `X-Unique-GIF-Used` / `X-Unique-GIF-Remaining` | advertised in `Access-Control-Expose-Headers` but not observed populated on `/exercises` responses | Likely only relevant when actually fetching `/gifs/{id}.gif`; not exercised in this spike to conserve quota. |

No documented backoff/retry guidance was reachable (docs domain unreachable —
see Auth section). `WorkoutXClient`'s error type surfaces a `.rateLimited`
case so callers can react to `429`s if/when the quota is exhausted; this spike
did not intentionally exhaust the quota.

Caching implication: with a 500/month quota and a rarely-changing catalog,
the SwiftData cache (M1-03) is not optional polish — it's required to avoid
burning quota on every app launch. See the staleness-window decision in
`Core/Persistence/`.

## Legacy Supabase `exercises` table — reusability as a fallback catalog

Inspected read-only via the Supabase MCP (`list_tables`, project
`pluri_health_db`). The `public.exercises` table (1,327 rows — matching the
live API's `total` exactly) has columns `id, name, body_part, target,
equipment, secondary_muscles (jsonb), instructions (jsonb), gif_url,
category, difficulty, mechanic, force, met, calories_per_minute, description,
is_unilateral, popularity_rank, recommended_sets, recommended_reps,
joint_focus, intensity_level, movement_tags (jsonb), synced_at`.

This is a 1:1 snapshot of the live WorkoutX response shape (snake_case
columns mirroring the camelCase JSON fields, plus a `synced_at` timestamp
confirming it was populated by syncing the API). **Verdict: reusable** as an
offline/fallback seed — it could backfill the SwiftData cache before the
network round-trip, or serve as a last-resort source if WorkoutX is
unreachable. Not wired up in M1-03 (out of scope — TASKS only asked to
evaluate it), but the `ExerciseCatalogStore` refresh path is isolated enough
that a Supabase-backed fallback could be added later without touching
`WorkoutXClient` call sites.
