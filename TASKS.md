# TASKS.md — Pluri Work Items

Tasks are generated **incrementally, one milestone at a time** (see `[PLAN.md](PLAN.md)` for milestone definitions). Early implementation surfaces details that change later work, so milestones M2+ get detailed tasks only when the preceding milestone is nearly done.

**Conventions**

- Task IDs: `M<milestone>-<number>` (e.g., `M1-04`). Reference them in commits.
- `[ ]` todo · `[x]` done · `[~]` in progress · `[!]` blocked (add a note why).
- When a milestone completes: check everything off, add a short "learned/changed" note, then generate the next milestone's tasks from PLAN.md + those learnings.
- Found a bug or adjacent problem mid-task? Add it to **Backlog** at the bottom instead of expanding your current task.

---

## M0 — Foundation

### Project scaffolding

- [x] **M0-01** Create Xcode project `Pluri` (SwiftUI app, iOS 18 min target, Swift latest), organized per PLAN §1.2: `App/`, `Core/` (`DesignSystem/`, `Networking/`, `Persistence/`, `Extensions/`), `Features/` (one folder per feature, empty for now).
- [x] **M0-02** Initialize git repo; verify `.gitignore` excludes `.env`, DerivedData, xcuserdata. First commit = docs + empty project.
- [x] **M0-03** Secret injection: script that generates `Secrets.xcconfig` from `.env` (gitignored) + a `Secrets` Swift enum reading values from Info.plist keys. Fail the build loudly if required keys are missing.
- [x] **M0-04** Add SPM dependencies: `supabase-swift`. (Nothing else yet — AGENTS.md §3 minimal-deps rule.)

### Design system (from design.md)

- [x] **M0-05** `PluriColor`: asset-catalog colors for every token in design.md §2 (brand, sunrise, status, zones, accents, neutrals) with dark-mode variants (initial dark values = sensible inversions; refine later).
- [x] **M0-06** `PluriFont` (SF Pro Rounded hierarchy per design.md §3), `PluriSpacing` (4/8/16/24/32/48), `PluriRadius` (8/16/20/28/999) as Swift constants.
- [x] **M0-07** Core components: `PluriCard` (elevation-1 shadow), `PluriPillButton` (primary/secondary), `PluriProgressBar`, `PluriBottomSheet` wrapper, `PluriChip` (selectable, for questionnaire options).
- [x] **M0-08** Component gallery debug screen rendering all tokens/components (doubles as the M0 exit-criteria "themed placeholder screen"); verify Dynamic Type + dark mode in previews.

### Backend foundation

- [x] **M0-09** Supabase schema v1 migration: `profiles`, `plans`, `plan_workouts`, `workout_exercises`, `workout_sessions`, `set_logs` per PLAN §1.3, all with owner-only RLS policies. (Community/nutrition tables deferred to their milestones.)
- [x] **M0-10** `SupabaseService` wrapper in app: client setup from Secrets, health-check call; confirm connectivity from simulator.
- [!] **M0-11** ⚠️ Rotate the Supabase keys and fetch the real `service_role` key (the one provided is a duplicate of the anon key — see `.env` note). Also rotate any keys that were previously pasted into docs. *(Blocked: requires owner dashboard access — key rotation isn't exposed via API/MCP. Owner: Supabase Dashboard → Settings → API → rotate anon/service_role JWT secret and the `sb_secret_` key, fetch the real `service_role` key, update `.env`. The app itself only ships the `sb_publishable_` key, so client code is unaffected.)*

**M0 exit check:** app builds & runs showing the component gallery; Supabase reachable; secrets load from `.env`; no key material in the repo. ✅ verified 2026-07-12 (iPhone 17 Pro sim, light + dark).

**M0 learned/changed:**

- The Supabase project already contained prototype tables (`workout_plans`, `plan_days`, `plan_day_exercises`, `user_equipment`, `exercises` with 1,327 rows) and 3 profile rows. Schema v1 was applied **non-destructively**: `profiles` was extended in place; the PLAN §1.3 tables were added alongside. Dropping the legacy tables needs owner approval (AGENTS §6) — see Backlog.
- The Xcode project/target is named `pluri_fable_xcode` (created by owner before M0); display name is set to "Pluri". Renaming the target/bundle id is deferred — see Backlog.
- xcconfig treats `//` inside values as a comment; `generate_secrets.sh` escapes URLs as `https:/$()/…` (caught by a launch crash: "supabaseURL must have a valid host").
- `.gitkeep` placeholders in the synchronized folder group needed target-membership exceptions in the pbxproj, or Xcode copies them all into the bundle and the build fails.
- No text style is as large as design.md's ~60pt hero numeral; `PluriHeroNumeral` uses `@ScaledMetric` anchored to `.largeTitle` to keep Dynamic Type scaling.

---

## M1 — Onboarding & Plan Generation

### WorkoutX integration (do first — highest unknown, PLAN §3 risk)

- [x] **M1-01** API spike: hit WorkoutX endpoints with the real key; document (in a comment or `Core/Networking/WorkoutX/README`) the actual response shapes for exercise list, equipment, muscles, media/video URLs, rate limits.
- [x] **M1-02** `WorkoutXClient` (protocol + live implementation): fetch exercise catalog with typed `Exercise` model (id, name, equipment, target muscle, secondary muscles, instructions, image/animation URL, video URL).
- [x] **M1-03** SwiftData cache for the exercise catalog with staleness-based refresh; mock client for previews/tests.

### Onboarding flow

- [x] **M1-04** `OnboardingRouter` + state container holding all answers locally (SPEC §2 — nothing persists remotely until the paywall milestone).
- [x] **M1-05** Splash screen with sunrise-glow branding (design.md sunrise gradient tokens).
- [x] **M1-06** Name entry screen (no progress bar).
- [x] **M1-07** Progress bar behavior per SPEC §3.1: appears at Q1, starts at the step's actual completion percentage (name = step 1 of 14), animates forward, supports back navigation.
- [x] **M1-08** Q1 fitness type — Workout selectable; Cardio/Flexibility visible but disabled with "coming soon".
- [x] **M1-09** Q2 goal + Q3 experience + Q4 regularity screens (single-select chip lists).
- [x] **M1-10** Q5 workout location + Q6 equipment multi-select. Define the auto-select mapping: Commercial = all; propose Home/Small/Bodyweight subsets from the WorkoutX list and record the chosen defaults in SPEC §15 → resolved.
- [x] **M1-11** Q7 injuries: multi-select body areas, per-area pain level 1–5 stepper.
- [x] **M1-12** Q8 training days (weekday picker, default M/W/F, enforce 2–6) + Q9 scheduled/flexible + plan length slider (3–12, suggest 6).
- [x] **M1-13** Q10 session duration + Q11 age/gender/height/weight (locale-aware units).
- [x] **M1-14** Q12 maintenance calories (Mifflin-St Jeor in a unit-tested `CalorieCalculator`) + allergy chips with search.
- [x] **M1-15** Q13 start date (Today / Tomorrow / date picker).

### Plan generation

- [ ] **M1-16** `PlanEngine` v1 (client-side for now; port to Edge Function in M2+ per PLAN §1.3): filter catalog by equipment ∩ injury exclusions, build sessions fitting the chosen duration, distribute across days × weeks with simple progression. Deterministic with a seed.
- [ ] **M1-17** Unit tests: representative personas (beginner/bodyweight/injured/commercial-gym) produce plans with no excluded equipment, no injured-area exercises, sane session lengths.
- [ ] **M1-18** "Generating Plan…" screen (progress animation, silent retry, gentle failure state) → "Your plan is ready" screen with plan summary teaser (paywall itself is M2 — stub the transition).

**M1 exit check:** fresh install → full questionnaire → real generated plan visible in a debug plan-dump view; engine tests green.

**M1-04..M1-15 learned/changed:**

- Onboarding lives under `Features/Onboarding/` (`Models/`, `Views/`, `Views/Components/`). `OnboardingAnswers` is the single in-memory `@Observable @MainActor` state container (no persistence); `OnboardingRouter` owns the `NavigationStack` path as `[OnboardingDestination]` — both a Continue tap and an edge swipe-back mutate the same path, so the progress bar derives from one source of truth and recedes correctly on back navigation.
- `AppRootView` now shows `OnboardingRootView()` instead of `ComponentGalleryView()`. The gallery stays reachable in `DEBUG` builds only, via a small palette-icon button that presents it in a sheet — no scope expansion beyond "keep it trivially reachable."
- Q13 → `PlanGenerationStubView`, a dead-end "You're all set!" screen — intentional per task scope; M1-16/17/18 (`PlanEngine`, its tests, "Generating Plan" screen) are **not implemented** and remain `[ ]` below.
- `CalorieCalculator` (Q12) is a pure `nonisolated enum` with static functions, written to be trivially testable. Since no Swift Testing target exists yet (see Backlog), its tests live at `pluri_fable_xcode/PluriTests/CalorieCalculatorTests.swift` — a sibling of the synchronized target folder, so it is **not** compiled into the app target; ready to move into a real test target once one is added.
- Decisions recorded in `SPEC.md` §14 (#13–#18): progress-bar denominator confirmed, Q6 equipment subsets defined (resolves the old §15 open question), Q7 excludes "Cardio" as a non-physical injury area, `CalorieCalculator`'s "Other" gender offset, Q12's allergy search/custom-entry behavior, and the M1-16/17/18 deferral.
- Verified: builds clean (no warnings) for iPhone 17 Pro simulator via `build_sim`/`build_run_sim`; ran the app and confirmed Splash auto-advances into Name entry (screenshot-verified). Deeper click-through of Q1–Q13 wasn't automated — this session's XcodeBuildMCP config only exposed `screenshot`/`snapshot_ui`, not tap/type UI-automation tools.

---

## M2+ — not yet generated

Tasks for M2 (Auth, Paywall & Accounts) will be generated when M1 is near completion, incorporating what M0/M1 taught us (WorkoutX realities, plan-engine shape, onboarding data model).

---

## Backlog / surfaced items

- Decide the fate of the legacy Supabase prototype tables (`workout_plans`, `plan_days`, `plan_day_exercises`, `user_equipment`, plus the 3 seeded profile rows). Dropping them is destructive → owner approval required (AGENTS §6). The seeded `exercises` catalog (1,327 rows) is confirmed reusable as an offline/fallback seed for the WorkoutX cache (M1-01: it's a 1:1 snapshot of the live API's fields, right down to a `synced_at` column) — not wired up in M1-03, since that was scoped to evaluation only.
- No test target exists yet; M1-03's cache-staleness logic was deliberately written as a pure `nonisolated static func` (`ExerciseCatalogStore.isStale`) so it's trivially testable once a Swift Testing target is added — creating that target by hand-editing the synchronized-group `project.pbxproj` was judged too risky to do as a drive-by part of M1-01/02/03. Consider adding the test target as its own task before or alongside M1-17. M1-14's `CalorieCalculator` tests hit the same wall — they're written and waiting at `pluri_fable_xcode/PluriTests/CalorieCalculatorTests.swift` (outside the synchronized app-target folder, so not compiled in) for whenever the test target lands.
- `PluriPillButtonStyle` (M0) has no visual disabled state — it ignores `\.isEnabled`, so onboarding's disabled Continue buttons (empty name, no location picked, <2 training days, …) still render full brand orange and look tappable. Add an `@Environment(\.isEnabled)` dim/desaturate to the style. (Surfaced during M1-04..15 QA — pre-existing component, not fixed inline per AGENTS §7.)
- Q6 equipment strings come from SPEC §3.2's 34-item list (mirrored in `EquipmentCatalog.all`), but the live WorkoutX `equipmentList` endpoint reportedly returns 32 strings with punctuation/casing differences (see `Core/Networking/WorkoutX/README.md`, e.g. `"Dumbbell, Exercise Ball"` vs SPEC's `"Dumbbell + Exercise Ball"`). Before M1-16's equipment filtering, reconcile the two (normalize on the API's exact strings or add a mapping) so Q6 selections actually match catalog `equipment` values.
- Consider renaming the Xcode target/product from `pluri_fable_xcode` to `Pluri` (display name already "Pluri"; bundle id `com.codewithmikey.pluri-fable-xcode`). Do it before M2 auth/StoreKit setup, since the bundle id feeds App Store Connect.
- Security advisor flags: `public.rls_auto_enable()` (SECURITY DEFINER, pre-existing) is executable by anon/authenticated — revoke EXECUTE or move it; leaked-password protection is disabled in Auth settings.
- Supabase Auth leaked-password protection and the M0-11 key rotation both need the owner in the dashboard — bundle them into one session.

