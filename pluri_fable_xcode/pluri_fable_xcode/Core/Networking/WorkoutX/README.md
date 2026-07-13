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
- **Video URL:** **no such field or endpoint exists.** Tried
  `GET /exercises/{id}/video`, `GET /videos/{id}.mp4`, and
  `GET /exercises?media=video` — all either `404` or ignored (no effect on
  response shape). SPEC §8 ("image/animation ↔ video toggle... video = real
  person performing the exercise") assumes a video URL the real API doesn't
  supply.
- **Decision (recorded in SPEC.md §14):** the domain `Exercise` model keeps
  an optional `videoURL: URL?` so the adapter layer and any future UI toggle
  have a place to plug in a video source (e.g. a different provider, or a
  future WorkoutX tier), but the current DTO→domain mapping always sets it to
  `nil`. This keeps M1-02/M1-03 unblocked without inventing data.

## Pagination

- `limit` / `offset` query params, both integers, both optional.
- Response envelope always reports `total` (total catalog size, 1327) and
  `count` (size of `data` in this response) alongside `data`.
- No `next`/cursor links — pagination is purely offset-based.

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
