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

- [ ] **M0-01** Create Xcode project `Pluri` (SwiftUI app, iOS 18 min target, Swift latest), organized per PLAN §1.2: `App/`, `Core/` (`DesignSystem/`, `Networking/`, `Persistence/`, `Extensions/`), `Features/` (one folder per feature, empty for now).
- [ ] **M0-02** Initialize git repo; verify `.gitignore` excludes `.env`, DerivedData, xcuserdata. First commit = docs + empty project.
- [ ] **M0-03** Secret injection: script that generates `Secrets.xcconfig` from `.env` (gitignored) + a `Secrets` Swift enum reading values from Info.plist keys. Fail the build loudly if required keys are missing.
- [ ] **M0-04** Add SPM dependencies: `supabase-swift`. (Nothing else yet — AGENTS.md §3 minimal-deps rule.)

### Design system (from design.md)

- [ ] **M0-05** `PluriColor`: asset-catalog colors for every token in design.md §2 (brand, sunrise, status, zones, accents, neutrals) with dark-mode variants (initial dark values = sensible inversions; refine later).
- [ ] **M0-06** `PluriFont` (SF Pro Rounded hierarchy per design.md §3), `PluriSpacing` (4/8/16/24/32/48), `PluriRadius` (8/16/20/28/999) as Swift constants.
- [ ] **M0-07** Core components: `PluriCard` (elevation-1 shadow), `PluriPillButton` (primary/secondary), `PluriProgressBar`, `PluriBottomSheet` wrapper, `PluriChip` (selectable, for questionnaire options).
- [ ] **M0-08** Component gallery debug screen rendering all tokens/components (doubles as the M0 exit-criteria "themed placeholder screen"); verify Dynamic Type + dark mode in previews.

### Backend foundation

- [ ] **M0-09** Supabase schema v1 migration: `profiles`, `plans`, `plan_workouts`, `workout_exercises`, `workout_sessions`, `set_logs` per PLAN §1.3, all with owner-only RLS policies. (Community/nutrition tables deferred to their milestones.)
- [ ] **M0-10** `SupabaseService` wrapper in app: client setup from Secrets, health-check call; confirm connectivity from simulator.
- [ ] **M0-11** ⚠️ Rotate the Supabase keys and fetch the real `service_role` key (the one provided is a duplicate of the anon key — see `.env` note). Also rotate any keys that were previously pasted into docs.

**M0 exit check:** app builds & runs showing the component gallery; Supabase reachable; secrets load from `.env`; no key material in the repo.

---

## M1 — Onboarding & Plan Generation

### WorkoutX integration (do first — highest unknown, PLAN §3 risk)

- [ ] **M1-01** API spike: hit WorkoutX endpoints with the real key; document (in a comment or `Core/Networking/WorkoutX/README`) the actual response shapes for exercise list, equipment, muscles, media/video URLs, rate limits.
- [ ] **M1-02** `WorkoutXClient` (protocol + live implementation): fetch exercise catalog with typed `Exercise` model (id, name, equipment, target muscle, secondary muscles, instructions, image/animation URL, video URL).
- [ ] **M1-03** SwiftData cache for the exercise catalog with staleness-based refresh; mock client for previews/tests.

### Onboarding flow

- [ ] **M1-04** `OnboardingRouter` + state container holding all answers locally (SPEC §2 — nothing persists remotely until the paywall milestone).
- [ ] **M1-05** Splash screen with sunrise-glow branding (design.md sunrise gradient tokens).
- [ ] **M1-06** Name entry screen (no progress bar).
- [ ] **M1-07** Progress bar behavior per SPEC §3.1: appears at Q1, starts at the step's actual completion percentage (name = step 1 of 14), animates forward, supports back navigation.
- [ ] **M1-08** Q1 fitness type — Workout selectable; Cardio/Flexibility visible but disabled with "coming soon".
- [ ] **M1-09** Q2 goal + Q3 experience + Q4 regularity screens (single-select chip lists).
- [ ] **M1-10** Q5 workout location + Q6 equipment multi-select. Define the auto-select mapping: Commercial = all; propose Home/Small/Bodyweight subsets from the WorkoutX list and record the chosen defaults in SPEC §15 → resolved.
- [ ] **M1-11** Q7 injuries: multi-select body areas, per-area pain level 1–5 stepper.
- [ ] **M1-12** Q8 training days (weekday picker, default M/W/F, enforce 2–6) + Q9 scheduled/flexible + plan length slider (3–12, suggest 6).
- [ ] **M1-13** Q10 session duration + Q11 age/gender/height/weight (locale-aware units).
- [ ] **M1-14** Q12 maintenance calories (Mifflin-St Jeor in a unit-tested `CalorieCalculator`) + allergy chips with search.
- [ ] **M1-15** Q13 start date (Today / Tomorrow / date picker).

### Plan generation

- [ ] **M1-16** `PlanEngine` v1 (client-side for now; port to Edge Function in M2+ per PLAN §1.3): filter catalog by equipment ∩ injury exclusions, build sessions fitting the chosen duration, distribute across days × weeks with simple progression. Deterministic with a seed.
- [ ] **M1-17** Unit tests: representative personas (beginner/bodyweight/injured/commercial-gym) produce plans with no excluded equipment, no injured-area exercises, sane session lengths.
- [ ] **M1-18** "Generating Plan…" screen (progress animation, silent retry, gentle failure state) → "Your plan is ready" screen with plan summary teaser (paywall itself is M2 — stub the transition).

**M1 exit check:** fresh install → full questionnaire → real generated plan visible in a debug plan-dump view; engine tests green.

---

## M2+ — not yet generated

Tasks for M2 (Auth, Paywall & Accounts) will be generated when M1 is near completion, incorporating what M0/M1 taught us (WorkoutX realities, plan-engine shape, onboarding data model).

---

## Backlog / surfaced items

- (empty — add discoveries here instead of expanding current tasks)

