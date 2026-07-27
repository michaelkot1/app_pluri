# API Ninjas Nutrition — spike notes (M7-03)

Findings from hitting the live API Ninjas Nutrition endpoint with the key in
`.env` (`NUTRITION_API_KEY`). **No key material is recorded here** — see
`AGENTS.md` §2. Client injection path (confirmed):

`.env` → `Scripts/generate_secrets.sh` → `Config/Secrets.xcconfig`
(`PLURI_NUTRITION_API_KEY`) → `Config/Info.plist` (`NUTRITION_API_KEY`) →
`Secrets.nutritionAPIKey` → `LiveNutritionClient` `X-Api-Key` header.

## Auth

- Header: **`X-Api-Key: <key>`** (API Ninjas standard).
- Invalid / missing key → HTTP **400** with
  `{"error":"Invalid API Key."}` (not 401). `LiveNutritionClient` maps
  400/401/403 → `.unauthorized`.
- Base URL (hardcoded in client unless a future spike proves otherwise):
  **`https://api.api-ninjas.com/v1`**.

## Endpoint (confirmed live, 2026-07-27)

| Endpoint | Notes |
|---|---|
| `GET /nutrition?query={text}` | Natural-language serving query. Empty query → `[]` (HTTP 200). |

Example queries exercised: `1 lb brisket`, `1 apple`, `100g chicken breast`.

## Response shape

Top-level JSON **array** (not an envelope):

```json
[
  {
    "name": "apple",
    "calories": "Only available for premium subscribers.",
    "serving_size_g": 182.0,
    "fat_total_g": 0.3,
    "fat_saturated_g": 0.1,
    "protein_g": "Only available for premium subscribers.",
    "sodium_mg": 1,
    "potassium_mg": 20,
    "cholesterol_mg": 0,
    "carbohydrates_total_g": 25.6,
    "fiber_g": 4.3,
    "sugar_g": 0
  }
]
```

On a **premium** key the same fields are numeric (e.g. `"calories": 95`).
The DTO accepts either a number or a non-numeric string and maps gated
strings → `nil` on the domain model.

## Free-tier field availability (honest)

Observed on the project’s free-tier key (2026-07-27):

| Field | Free tier | Notes |
|---|---|---|
| `name` | ✅ | |
| `serving_size_g` | ✅ | Grams for the parsed serving. |
| `fat_total_g` / `fat_saturated_g` | ✅ | Numeric. |
| `carbohydrates_total_g` / `fiber_g` / `sugar_g` | ✅ | Numeric. |
| `sodium_mg` / `potassium_mg` / `cholesterol_mg` | ✅ | Numeric. |
| **`calories`** | ❌ gated | String: `"Only available for premium subscribers."` |
| **`protein_g`** | ❌ gated | Same premium string. |

**Implication for Log (SPEC §12 / #67):** day calorie totals vs
`maintenance_calories` **cannot** be computed from free-tier Nutrition
responses alone. Domain `NutritionFood.calories` / `.proteinGrams` are
optional; Log UI must stay honest when `nil` (or the owner upgrades to a
premium API Ninjas key / proxies a paid tier). Recorded as SPEC §14 **#68**.

## Rate limits

- No `X-RateLimit-*` headers observed on successful free-tier responses in
  this spike.
- API Ninjas documents plan-based monthly quotas on their dashboard (not
  returned in headers here). Surface `.rateLimited` for HTTP 429 if/when
  encountered.
- Prefer caching / debouncing Log search keystrokes to conserve quota.

## Domain notes

- No durable food id from the API — `NutritionFood.id` is synthetic
  (`name|serving_g`) for list identity; optional `food_logs.nutrition_food_id`
  may store it.
- Serving label for UI (e.g. `"1 cup"`) is the **user query text**, not a
  separate API field — persist `serving` on `food_logs` from the query /
  picker (M7-11).
