# TheMealDB API — spike notes (M7-03)

Findings from hitting the live free TheMealDB API with the documented test
key path segment `1` (`https://www.themealdb.com/api/json/v1/1/...`). No paid
key is required for v1 Pluri. No key material is recorded here — see
`AGENTS.md` §2.

## Auth

- **Keyless for Pluri.** The public demo key is the URL path segment `/v1/1/`
  (not a header, not a query secret). Paid Premium keys use a different path
  segment when subscribed — Pluri stays on `1` unless quota forces an upgrade.
- No `Authorization` / `X-Api-Key` header is accepted or required on the free
  endpoint.
- CORS is open (`access-control-allow-origin: *`) — irrelevant for native iOS
  `URLSession` but confirms the API is intended for public client use.

## Endpoints (confirmed live, 2026-07-27)

| Endpoint | Notes |
|---|---|
| `GET /search.php?s={name}` | Full meal objects matching name. Empty → `{"meals":null}`. |
| `GET /lookup.php?i={idMeal}` | Full meal by id. Unknown → `{"meals":null}`. |
| `GET /filter.php?a={area}` | Summary rows for cuisine / `strArea`. |
| `GET /filter.php?i={ingredient}` | Summary rows for main ingredient (spaces often as `_` or encoded). |
| `GET /filter.php?c={category}` | Summary rows for category. |
| `GET /list.php?a=list` | Area / nationality labels (`strArea`, plus `strCountry` on current free API). |
| `GET /list.php?c=list` | Categories (`strCategory`). |
| `GET /list.php?i=list` | Ingredients (`idIngredient`, `strIngredient`, optional description). |

## Response shape — full meal (`search` / `lookup`)

```json
{
  "meals": [
    {
      "idMeal": "52772",
      "strMeal": "Teriyaki Chicken Casserole",
      "strMealAlternate": null,
      "strCategory": "Chicken",
      "strArea": "Japanese",
      "strCountry": "Japan",
      "strInstructions": "Preheat oven to 350° F. …",
      "strMealThumb": "https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg",
      "strTags": "Meat,Casserole",
      "strYoutube": "https://www.youtube.com/watch?v=4aZr5hZXP_s",
      "strIngredient1": "soy sauce",
      "strMeasure1": "3/4 cup",
      "strIngredient2": "…",
      "strMeasure2": "…",
      "strIngredient16": null,
      "strSource": null,
      "strImageSource": null,
      "strCreativeCommonsConfirmed": null,
      "dateModified": null
    }
  ]
}
```

Ingredients are flattened as `strIngredient1…20` + `strMeasure1…20` (empty
string or `null` when unused). Pluri packs non-empty pairs into
`MealDBIngredient`.

## Response shape — filter summary

```json
{
  "meals": [
    {
      "strMeal": "Chicken Alfredo Primavera",
      "strMealThumb": "https://www.themealdb.com/images/media/meals/….jpg",
      "idMeal": "52796",
      "strArea": "Italian",
      "strCountry": "Italy"
    }
  ]
}
```

`strArea` / `strCountry` may be present or `null` on filter rows depending on
the meal. Always call `lookup.php` when instructions / ingredients are needed.

## Categories (Protein Explore mapping)

Confirmed `list.php?c=list` (and usable with `filter.php?c=`):

`Beef`, `Breakfast`, `Chicken`, `Dessert`, `Goat`, `Lamb`, `Miscellaneous`,
`Pasta`, `Pork`, `Seafood`, `Side`, `Starter`, `Vegan`, `Vegetarian`.

| Explore Protein (#67e) | MealDB mapping |
|---|---|
| Chicken | `filter.php?c=Chicken` (and/or ingredient filter) |
| Beef | `filter.php?c=Beef` |
| Pork | `filter.php?c=Pork` |
| Seafood | `filter.php?c=Seafood` |
| Vegetarian | `filter.php?c=Vegetarian` |
| Vegan | `filter.php?c=Vegan` |
| Any | no category filter |

## Cuisine Explore mapping (`strArea`)

- **Source of truth for a meal's cuisine:** `strArea` on full meal objects
  (and often on filter rows).
- **Filter:** `filter.php?a={strArea}`.
- **List caveat (2026-07-27):** `list.php?a=list` now returns a large
  nationality-style catalog (`Afghan`, `Albanian`, …) that does **not** 1:1
  match filterable recipe areas. Prefer areas observed on meals, or validate
  with `filter.php` before showing empty Explore results.
- **Naming drift vs older docs:** several classic labels no longer filter:

| Classic label | Live filterable `strArea` (spike) | Notes |
|---|---|---|
| American | `United States` | `a=American` → 0 |
| French | `France` | `a=French` → 0 |
| Indian | `India` | `a=Indian` → 0 |
| Dutch | `Netherlands` | `a=Dutch` → 0 |
| British / Italian / Japanese / … | same string | still works |

Explore UI (M7-10) should present live `strArea` values (or a curated subset
validated against `filter.php`), not the raw unvalidated `list.php?a=list`.

## Duration & Portion (no API fields)

MealDB has **no** cook-time or servings/yield field on the free response.

| Explore filter (#67e) | Strategy |
|---|---|
| Duration ≤20 / 20–45 / 45+ | **Client heuristic** — e.g. parse minute mentions in `strInstructions`, else treat as unknown / exclude from duration-filtered views. Not server-side. |
| Portion Single vs Meal-prep | **Client heuristic** — e.g. large batch language / multi-pound measures / casserole tags → meal-prep; else single. Not server-side. |

## Empty / error behavior

- No matches → HTTP 200 with `"meals": null` (not `[]`). Clients must treat
  `null` as empty list; `lookup` maps empty → `.notFound`.
- Rapid fire of 20 searches in this spike all returned HTTP 200 — **no
  `429` / rate-limit headers observed** on the free key. Still expose
  `.rateLimited` for defensive handling. Free-tier fair-use is undocumented;
  cache favorites / day suggestions locally (#67g) rather than re-hitting
  Explore on every launch.

## Domain id

`idMeal` (string) is the stable id stored as `mealdb_recipe_id` in
`recipe_favorites` / optional `food_logs` (M7-02).
