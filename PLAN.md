# PLAN.md — Pluri Architecture & Milestones

Derived from [`SPEC.md`](SPEC.md). Ground rules in [`AGENTS.md`](AGENTS.md). Work items in [`TASKS.md`](TASKS.md).

---

## 1. Architecture

### 1.1 System overview

```
┌─────────────────────────── iOS App (Swift / SwiftUI) ───────────────────────────┐
│  Features (MVVM):  Onboarding · Paywall · Home · Plan · Workout · Insights ·    │
│                    Community · Recipe · AskPluri · Profile                      │
│  Services (protocol-based, injected):                                           │
│    SupabaseService · WorkoutXClient · HealthKitService · StoreKitService ·      │
│    NutritionClient · MealDBClient · AskPluriClient · PlanEngine · ScoreEngine   │
│  Persistence: SwiftData (offline-first workout logs, cached exercises) + Sync   │
└──────────┬──────────────────────────────┬───────────────────────────────────────┘
           │ anon key + RLS               │ HTTPS
   ┌───────▼────────────┐        ┌────────▼─────────┐
   │  Supabase          │        │  External APIs   │
   │  Auth · Postgres   │        │  WorkoutX        │
   │  Storage (images)  │        │  TheMealDB       │
   │  Edge Functions ───┼──────► │  API Ninjas      │
   │   └─ ask-pluri ────┼──────► │  Gemini (key     │
   │      (service key) │        │   server-side)   │
   └────────────────────┘        └──────────────────┘
                                  HealthKit / StoreKit are on-device Apple frameworks.
```

### 1.2 iOS app structure

- **Pattern:** MVVM. One feature module per tab/flow; each has `Views/`, `ViewModels/` (`@Observable`), and feature-local models. Shared code in `Core/` (networking, persistence, design system, extensions).
- **Navigation:** a root `AppRouter` switches between phases — Splash → Onboarding → Paywall → Main (TabView). `NavigationStack` per tab; deep links (Today's Health tile → Insights section) via router.
- **Design system:** `Core/DesignSystem/` — `PluriColor`, `PluriFont`, `PluriSpacing`, `PluriRadius` mirroring `design.md` tokens 1:1, plus shared components (cards, pill buttons, progress bar, bottom sheets, rings/charts via Swift Charts).
- **Persistence & sync:** SwiftData models for plan, workouts, sets, logs, recipes-favorites, cached WorkoutX exercises. A `SyncEngine` pushes local changes to Supabase (last-write-wins per record, queued while offline). Onboarding answers stay in-memory/local until account creation at the paywall, then flush to Supabase.
- **Minimum iOS:** **iOS 17** (needed for `@Observable` + mature SwiftData; raise to 18 only if a required API demands it).

### 1.3 Backend (Supabase)

- **Auth:** Sign in with Apple + email/password.
- **Core tables** (all with RLS = owner-only unless noted):
  - `profiles` — name, demographics, units, goal, maintenance calories, allergies, injuries (jsonb: area + pain level), equipment (text[]), schedule prefs.
  - `plans` — goal, start/end dates, weeks, schedule type, status.
  - `plan_workouts` — plan_id, week #, scheduled date/day, name, type, color, duration, status (scheduled/completed/skipped).
  - `workout_exercises` — plan_workout_id, workoutx exercise id + cached metadata, sets/reps or duration targets, order.
  - `workout_sessions` — actual performances: started/ended, duration, notes, synced-to-health flag; plus manual logs (§9.3).
  - `set_logs` — session_id, exercise, set #, reps, weight (or time).
  - `pluri_scores` — daily score snapshots.
  - `posts`, `post_likes`, `post_comments`, `post_polls`, `poll_votes`, `saved_posts` — community (posts publicly readable; writes owner-only; moderation columns from day one: reported/hidden).
  - `food_logs` — nutrition entries (food, serving, calories, macros, meal, date).
  - `recipe_favorites` — user ↔ MealDB recipe ids.
  - `chat_messages` — Ask Pluri history.
- **Edge Functions:**
  - `ask-pluri` — receives the user's message + auth JWT, loads plan/history context from Postgres, calls Gemini, returns reply; handles "add/remove workout" as structured tool-style actions that mutate `plan_workouts`.
  - `generate-plan` — plan-generation endpoint so the algorithm can evolve server-side without app releases. Calls WorkoutX, applies equipment/injury/goal/duration filters, writes plan rows. (Client keeps a thin fallback only if latency demands it.)
- **HealthKit data stays on-device** (SPEC §13); only user-initiated workout syncs write to Apple Health, and Pluri Score inputs are computed on-device.

### 1.4 Key algorithms (owned by `PlanEngine` / `ScoreEngine`)

- **Plan generation:** filter WorkoutX catalog by equipment ∩ not-injured, bucket by muscle group, build balanced sessions fitting the chosen duration (est. time per set), distribute across chosen days for N weeks with simple progression (reps→weight ramp). Deterministic given a seed, so it's testable.
- **Pluri Score:** start simple — 70% consistency (completed ÷ scheduled over trailing 4 weeks, with streak bonus and gentle decay) + 30% health trend vs. the user's own 30-day baseline. Clamped daily delta (e.g., ±3) so it "moves slowly and kindly." Tune later; formula lives in one tested module.
- **Maintenance calories:** Mifflin-St Jeor + activity multiplier from training frequency.

### 1.5 Cross-cutting decisions

- WorkoutX responses cached in SwiftData (exercise catalog rarely changes); media cached on disk.
- StoreKit 2 subscription group: monthly $7.99 / yearly $29.99, 10-day intro trial; entitlement checked at launch, lapse → locked paywall state.
- All screens support Dynamic Type + VoiceOver from first implementation (per AGENTS.md), not retrofitted.

---

## 2. Milestones

Sequenced so each ships a usable, testable increment; risky integrations (StoreKit, HealthKit, plan generation) are validated early.

### M0 — Foundation
Project scaffolding: Xcode project, SPM setup, folder structure, design-system tokens & core components, `.xcconfig` secret injection from `.env`, Supabase project schema v1 + RLS, CI-less build/test discipline.
**Exit:** app builds and shows a themed placeholder screen; design tokens render; Supabase reachable.

### M1 — Onboarding & Plan Generation
Splash → name → 13-question flow with progress bar, WorkoutX integration, `generate-plan` (equipment/injury/goal filtering, week distribution), "Generating Plan" → "Plan Ready" screens. Answers held locally.
**Exit:** a new user can answer everything and get a real, sensible multi-week plan generated from WorkoutX data.

### M2 — Auth, Paywall & Accounts
Supabase Auth (Apple + email), StoreKit 2 subscriptions with trial, restore purchases, profile page (settings, theme, sign out, delete account), onboarding data flush to Supabase on account creation.
**Exit:** full funnel works end-to-end: onboard → pay (sandbox) → account created → plan persisted remotely.

### M3 — Home, Plan & Calendar
Home page (calendar dots, Pluri Score card *displaying a stub score*, Today's Health placeholders, record-workout button), tab bar, Plan page (plan card, week cards, Week Overview), Calendar/Rearrange page, Manage Plan, Plan Overview info page, notifications page shell + workout reminders.
**Exit:** user can browse and rearrange their entire plan; navigation skeleton complete.

### M4 — Workout Experience (core of the app)
Workout Detail page, live Workout Screen (exercise cards, expanded sheets with video toggle, timers, set/rep/weight logging, pause/stop, hold-to-finish), completion summary, offline-first `SyncEngine`, Apple Health workout sync, late-day reschedule nudge.
**Exit:** user completes a real workout start-to-finish, offline, with data synced and checked off.

### M5 — HealthKit Insights & Pluri Score
Full HealthKit read integration (steps, sleep, heart rate, calories), Today's Health live tiles, Insights page (Performance + Workouts tabs, weekly filters, all-time stats, Bevel-style health insights), manual "+" activity logging, real Pluri Score engine.
**Exit:** Insights reflect real logged + health data; score updates daily.

### M6 — Ask Pluri (AI Coach)
`ask-pluri` Edge Function with Gemini, context grounding from user data, chat UI on Workout Screen, add/remove-workout actions, coach persona & safety rails.
**Exit:** mid-workout questions answered with user-specific context; plan edits via chat work.

### M7 — Recipes & Nutrition
Recipe page (day view, ~3 auto-suggestions per meal filtered by allergies/calories), Explore filters, favorites + similarity-biased suggestions, food logging via Nutrition API (serving sizes, calorie tracking vs. maintenance).
**Exit:** user gets daily recipe suggestions and can log foods with calorie totals.

### M8 — Community
Feed (posts, likes, comments, polls), create-post flow with type/image/poll and the 3-word rule, search, saved posts, Explore Spaces directory, **moderation (report/block/hide)** — App Review blocker.
**Exit:** users can post, interact, search, save; UGC moderation in place.

### M9 — Polish & Launch
Outdoor Run stub screen, notification settings & full notification types, localization pass, accessibility audit, performance pass (media caching, <100 ms logging), App Store assets, privacy nutrition labels, TestFlight beta → submission.
**Exit:** App Store submission.

### Dependency notes

- M1 needs M0's design system and WorkoutX client. M2 needs M1's data to persist. M3–M4 need M2's auth.
- M5 depends on M4 (sessions to analyze). M6 depends on M3/M4 (plan mutations, workout context). M7 and M8 are independent of each other and can be reordered or parallelized.
- Pluri Score appears as UI in M3 but gets its real engine in M5 — deliberate, so Home ships early.

---

## 3. Risks

| Risk | Mitigation |
|---|---|
| WorkoutX API shape/limits unknown | M1 starts with an API spike task; cache aggressively; keep an adapter layer so a different exercise DB could swap in |
| Plan quality (garbage plans kill trust) | Deterministic, unit-tested `PlanEngine`; seed-based snapshot tests; manual review of generated plans for representative personas |
| StoreKit review rejections | Follow trial-disclosure rules early (M2), test with sandbox + TestFlight |
| Gemini free-tier rate limits | Edge Function queues/throttles; graceful "coach is busy" state |
| UGC moderation scope creep | Minimal viable moderation (report + hide + block) built into schema from M0 |
