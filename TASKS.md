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

- [x] **M1-16** `PlanEngine` v1 (client-side for now; port to Edge Function in M2+ per PLAN §1.3): filter catalog by equipment ∩ injury exclusions, build sessions fitting the chosen duration, distribute across days × weeks with simple progression. Deterministic with a seed.
- [x] **M1-17** Unit tests: representative personas (beginner/bodyweight/injured/commercial-gym) produce plans with no excluded equipment, no injured-area exercises, sane session lengths.
- [x] **M1-18** "Generating Plan…" screen (progress animation, silent retry, gentle failure state) → "Your plan is ready" screen with plan summary teaser (paywall itself is M2 — stub the transition).

**M1 exit check:** fresh install → full questionnaire → real generated plan visible in a debug plan-dump view; engine tests green. ✅ engine tests green (27 tests, iPhone 17 Pro sim); plan-dump view (`PlanDumpView`, DEBUG-only) reachable from the "plan ready" screen. ✅ owner device click-through confirmed after the catalog-source fix below.

**M1-16..M1-18 learned/changed:**

- **Issue (owner device, 2026-07-13):** after finishing the questionnaire, the "Building your plan…" screen always fell through to "Let's try that again." A Supabase Auth console warning about `emitLocalSessionAsInitialSession` appeared in the logs at the same time, but that was a **red herring** (informational SDK notice, not the failure).
- **Root cause:** the live WorkoutX free tier now caps every `/exercises` response at **10 rows** regardless of `limit` (verified by direct probing; contradicts the M1-01 spike notes that said the full set came back unpaginated). A full 1,327-row catalog fetch therefore needed ~133 requests and 429'd against the 30-requests/window burst limit — `ExerciseCatalogStore.refresh()` left the SwiftData cache empty → `PlanEngineError.emptyCatalog` on all 3 silent retries (and each failed attempt burned ~¼ of the 500/month free-tier quota).
- **Fix:** catalog reads now come from the Supabase-seeded `exercises` snapshot (1,327 rows, 1:1 WorkoutX fields) via the new `SupabaseExerciseCatalogClient`, finally wiring up the backlog's "reusable fallback seed." Since onboarding runs pre-auth, migration `allow_anon_read_exercises` added an anon `SELECT` RLS policy (public, non-sensitive reference data). `LiveWorkoutXClient` is retained for single-exercise lookups / a future paid-tier path, but is no longer used for full-catalog refresh. Pinned by `ExerciseCatalogSourceTests` (page-cap paging, rate-limit repro, and a live end-to-end Supabase→cache→engine generation test). Owner re-tested on device and confirmed plan generation succeeds. See SPEC §14 #25 and the WorkoutX README's pagination section.
- **A real Swift Testing target now exists.** `PluriTests` was added to `project.pbxproj` by hand (unit-test bundle, host = app, `TEST_HOST`/`BUNDLE_LOADER` + `@testable import pluri_fable_xcode`, target dependency + `TestTargetID` so the autogenerated app scheme runs it). The orphan `CalorieCalculatorTests.swift` (M1-14) was adopted into it — it just needed `@testable import`. Verified with XcodeBuildMCP `test_sim`: **24 tests pass** (6 CalorieCalculator + 18 PlanEngine). This resolves the long-standing "no test target" backlog item.
- **Default actor isolation gotcha:** the project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so a plain `enum`/`struct` is implicitly `@MainActor`. The pure engine (`PlanEngine`, `EquipmentMatcher`, `SeededGenerator`) and the plan value models are marked `nonisolated` so they can run off the main actor (via `Task.detached`) and be tested without actor hops. (Types that already declare explicit `Sendable` conformance are effectively nonisolated, but their explicit initializers still needed the `nonisolated` type annotation.)
- **Equipment reconciliation solved by normalization, not a mapping table** (SPEC §14 #19): both sides are lowercased and stripped of non-alphanumerics before comparison, collapsing `+`/`,`/spacing/casing differences (`"Dumbbell + Exercise Ball"` ⇄ `"Dumbbell, Exercise Ball"`). Resolves the Q6↔WorkoutX backlog item.
- `PlanEngine` is a pure `(PlanInput, [Exercise], seed) -> GeneratedPlan` mirroring `CalorieCalculator`'s testable shape; `PlanGenerationService` is the thin `@MainActor` wrapper that loads the catalog from `ExerciseCatalogStore` and runs the engine off-main. New Plan feature module lives under `Features/Plan/` (`Models/`, `Engine/`, `Services/`, `Views/`).
- Q13 now advances to `PlanGeneratingView` (was the dead-end `PlanGenerationStubView`, now deleted). It runs the engine with a deliberate ≥2.5s progress animation, silently retries twice, then shows a gentle "Try again" state; on success it swaps to `PlanReadyView` (teaser + stubbed "Unlock my plan" → `PlanReadyPaywallStubView`, since the paywall is M2).
- Algorithm decisions recorded in `SPEC.md` §14 (#19–#24) and the plan-generation §15 open question resolved.

**M1-04..M1-15 learned/changed:**

- Onboarding lives under `Features/Onboarding/` (`Models/`, `Views/`, `Views/Components/`). `OnboardingAnswers` is the single in-memory `@Observable @MainActor` state container (no persistence); `OnboardingRouter` owns the `NavigationStack` path as `[OnboardingDestination]` — both a Continue tap and an edge swipe-back mutate the same path, so the progress bar derives from one source of truth and recedes correctly on back navigation.
- `AppRootView` now shows `OnboardingRootView()` instead of `ComponentGalleryView()`. The gallery stays reachable in `DEBUG` builds only, via a small palette-icon button that presents it in a sheet — no scope expansion beyond "keep it trivially reachable."
- Q13 → `PlanGenerationStubView`, a dead-end "You're all set!" screen — intentional per task scope; M1-16/17/18 (`PlanEngine`, its tests, "Generating Plan" screen) are **not implemented** and remain `[ ]` below.
- `CalorieCalculator` (Q12) is a pure `nonisolated enum` with static functions, written to be trivially testable. Since no Swift Testing target exists yet (see Backlog), its tests live at `pluri_fable_xcode/PluriTests/CalorieCalculatorTests.swift` — a sibling of the synchronized target folder, so it is **not** compiled into the app target; ready to move into a real test target once one is added.
- Decisions recorded in `SPEC.md` §14 (#13–#18): progress-bar denominator confirmed, Q6 equipment subsets defined (resolves the old §15 open question), Q7 excludes "Cardio" as a non-physical injury area, `CalorieCalculator`'s "Other" gender offset, Q12's allergy search/custom-entry behavior, and the M1-16/17/18 deferral.
- Verified: builds clean (no warnings) for iPhone 17 Pro simulator via `build_sim`/`build_run_sim`; ran the app and confirmed Splash auto-advances into Name entry (screenshot-verified). Deeper click-through of Q1–Q13 wasn't automated — this session's XcodeBuildMCP config only exposed `screenshot`/`snapshot_ui`, not tap/type UI-automation tools.

---

## M2 — Auth, Paywall & Accounts

### App Store Connect & project prep (do first — owner-dependent, unblocks RevenueCat & auth)

- [x] **M2-01** Rename the Xcode target/product from `pluri_fable_xcode` to `Pluri` and settle the final bundle id (Backlog item — must land before App Store Connect setup, since the bundle id feeds ASC). Keep display name "Pluri"; fix `TEST_HOST`/`BUNDLE_LOADER`, `@testable import`, and scheme references so `PluriTests` still runs. ✅ Target/module `Pluri`, bundle id `com.codewithmikey.Pluri`, source folder `pluri_fable_xcode/Pluri/`. Outer project dir + `.xcodeproj` name intentionally kept as `pluri_fable_xcode`.
- [!] **M2-02** App Store Connect + RevenueCat configuration *(requires owner action — no ASC/RC access via agent tools)*. Owner must: (a) create the ASC app record for `com.codewithmikey.Pluri`, one subscription group with **$7.99/month** + **$29.99/year** auto-renewable products, each with a **1-month free trial** introductory offer (SPEC §4 / §14 #7), Paid Apps agreement signed, sandbox tester created; (b) create a RevenueCat project, connect the ASC app, link products `monthly`/`yearly` + entitlement `Pluri Pro` + Paywall, and set the production iOS SDK key (`appl_...`) in `.env` / `REVENUECAT_API_KEY` for release builds (Test Store `test_…` keys must not ship — see RC launch checklist). Trial length is decided — ASC intro Free / 1 Month. Blocked on owner.
- [x] **M2-03** Enable Sign in with Apple: capability + entitlement on the app target (`Config/Pluri.entitlements` + `CODE_SIGN_ENTITLEMENTS`). ⚠️ Apple Developer portal App ID capability + Supabase Auth Apple provider still require owner action.

**M2-01..M2-03 learned/changed:**

- Target rename: module/`@testable import` is now `Pluri`; `TEST_HOST` → `Pluri.app/Pluri`; color-asset script path updated. `generate_secrets.sh` still writes to `pluri_fable_xcode/Config/` (outer project dir unchanged).
- RevenueCat is approved (SPEC §14 #27) but SDK addition is deferred to M2-06/07.
- Sign in with Apple entitlement is app-side only until the portal + Supabase provider are configured.
- ✅ Verified via XcodeBuildMCP (iPhone 17 Pro sim) after the rename: `build_sim` succeeds clean, `test_sim` **27/27 passing** (unchanged count from M1-17/18 — no test logic touched).

### Supabase Auth service & session

- [x] **M2-04** `SupabaseAuthService` (protocol + live implementation composing `SupabaseService`, + mock for previews/tests): Sign in with Apple (`signInWithIdToken`), email/password sign-up & sign-in, sign-out, session restore at launch, and observable auth state (`session` / `user` / `isSignedIn` / `hasResolvedSession`) the router can drive from (SPEC §2, PLAN §1.3). Thin `SignInWithAppleTokenExtractor` only — account UI is M2-11. ⚠️ SIWA end-to-end still needs Apple Developer + Supabase Apple provider (SPEC §15).
- [x] **M2-05** `delete-account` Edge Function: verifies JWT, deletes `profiles` (CASCADE covers plan/session tables), then `auth.admin.deleteUser`; client `SupabaseAuthService.deleteAccount()` invokes with the user JWT. Full remote data deletion is an App Review requirement (SPEC §2). ⚠️ Live delete blocked on M0-11 — set real `SUPABASE_SERVICE_ROLE_KEY` via `supabase secrets set` (never in the iOS bundle). Confirmation UI / local wipe remains M2-17.

### RevenueCat subscription service

- [x] **M2-06** Configure RevenueCat Dashboard as the primary subscription source of truth (not a local `.storekit` file): default offering with **`monthly`** + **`yearly`** packages, entitlement **`Pluri Pro`**, and a dashboard Paywall (V2). Simulator testing uses the RC test/public Apple key + Apple sandbox once ASC products exist (M2-02 still required for real purchases). A StoreKit Configuration file is **not** required — Purchases abstracts StoreKit. ⚠️ Owner must finish dashboard + ASC product linking in M2-02; client wiring + secrets injection landed with M2-07/09.
- [x] **M2-07** `SubscriptionService` (protocol + live RevenueCat + mock): configure `Purchases`, fetch offerings, purchase package, listen to `CustomerInfo` updates, resolve `Pluri Pro` entitlement / trial-ish state via RC entitlement info, restore purchases (SPEC §4, PLAN §1.5). No raw `Transaction.updates` / app-authored StoreKit service.
- [x] **M2-08** Entitlement hydration at launch: `hasResolvedCustomerInfo` after first `CustomerInfo` / refresh so M2-18 can avoid flash; lapse → locked paywall later with content preserved (SPEC §4). Full `AppRouter` / Main TabView / signed-in+lapsed navigation tree remains M2-18.

**M2-04 / M2-05 / M2-08 learned:**

- Auth composes the existing `SupabaseService` client (no second naked client). `delete-account` lives under `supabase/functions/`; deploy + `supabase secrets set SUPABASE_SERVICE_ROLE_KEY` after M0-11.
- Entitlement hydration is a flag on `SubscriptionService`, not a router — M2-18 still owns launch phases / lapsed navigation.
- SIWA portal + Apple provider and M0-11 service_role remain owner blockers (SPEC §15).

### Paywall UI & purchase flow

- [x] **M2-09** `Features/Paywall/` module + `PluriPaywallView` wrapping RevenueCatUI `PaywallView` (dashboard-designed paywall), replacing `PlanReadyPaywallStubView`. App Review must-haves (restore, terms, trial disclosure) come from the RC paywall template when configured — **owner must enable them in the RC Paywall editor**. Gentle offerings-failure fallback (Retry + Restore) only; no parallel custom monthly/yearly chip UI unless fallback.
- [x] **M2-10** Purchase flow: RevenueCat Paywall / `purchase(package:)` → on success dismiss paywall + unlock callback; temporary post-unlock placeholder until Main (M2-18). Gentle typed-error handling for cancelled / failed / pending purchases. *(Copy updated with M2-11 — unlock ≠ account creation.)*

### Account creation & sign-in after name entry

- [x] **M2-11** Post-name account screen (`AccountAuthView`): Sign in with Apple (primary) + email/password sign-up (secondary) per SPEC §2 / §3.1, with validation and gentle `PluriAuthError` surfaces; on new / incomplete success → advance to Q1 (not flush/Main). Auth is blocking; progress bar still name + Q1–Q13 only. RevenueCat `logIn(supabaseUserId)` after successful auth.
- [x] **M2-12** Returning-user path: "Already have an account?" toggles sign-in mode on the same post-name auth screen; on entitled returning sign-in, interim welcome-back stub (full RevenueCat restore + M2-15 remote plan hydrate → Main is M2-15 / M2-18). Non-entitled returning users continue into Q1.

### Persist onboarding data & plan to Supabase

- [x] **M2-13** Mapping layer (pure, unit-testable): `OnboardingAnswers` → `profiles` row (display name, demographics, units, goal, maintenance calories, allergies, injuries jsonb, equipment, schedule prefs) and `GeneratedPlan` → `plans` + `plan_workouts` + `workout_exercises` rows (PLAN §1.3 — schema already fits, no migration expected).
- [x] **M2-14** Flush after unlock while signed in: after paywall unlock (user already authenticated from M2-11), write profile + plan through the authed session (verifying owner-only RLS from M0-09 works end-to-end), with retry on transient failure; answers/plan stay local until the flush is confirmed so nothing is lost if the app dies mid-write.
- [x] **M2-15** Remote restore: on sign-in with an existing account, fetch profile + active plan (`plans`/`plan_workouts`/`workout_exercises`) from Supabase and hydrate local state, so the returning user skips onboarding and lands on Main (SPEC §2). *Note: hydrate + welcome-back “plan restored” stub ship here; **Main TabView landing is M2-18** (SPEC §14 #32). Launch gate also skips questionnaire on cold launch when `onboarding_completed` or an active plan exists (SPEC §14 #33).*

### Profile screen

- [x] **M2-16** `Features/Profile/` module + profile screen per SPEC §5.2: basic plan info (goal, dates, schedule), connected apps (Apple Health row — display-only until M5), notification settings (stub until M3), language, theme light/dark, terms & conditions link. *(Reusable `PluriCustomerCenterView` RevenueCatUI wrapper added now so Profile can present Customer Center later.)* *Interim choices (theme Auto default, Apple-EULA terms link, device-language row) logged as SPEC §14 #35; Profile reachable from the welcome-back stub toolbar until M2-18's Main shell.*
- [x] **M2-17** Sign out (end session, clear local user state, return to the sign-in/paywall entry) and Delete account (confirmation dialog → `delete-account` Edge Function (M2-05) → wipe local data → return to onboarding start) (SPEC §2, §5.2). *Adds RevenueCat `logOut()` to `SubscriptionServicing` and user-scoped `FlushCheckpointStore.clear(userID:)`; reroute via `AppLaunchGate.resetToOnboarding()`. Live remote deletion still gated on M0-11's real service-role key (SPEC §15).*

### App routing

- [x] **M2-18** Root `AppRouter` phase switching per PLAN §1.2: Splash → Onboarding → Paywall → Main; the paywall phase receives the generated plan + onboarding answers; Main is a minimal `TabView` shell (Home · Plan · Insights · Community · Recipe with placeholder screens — real tabs are M3+). Launch routing derives from auth session + entitlement state: fresh install → Onboarding; signed-in + entitled → Main; signed-in + lapsed → locked Paywall (SPEC §4). *Shipped: `AppRouter` replaces `AppLaunchGate`; splash gates the first transition (no onboarding/paywall flash); locked lapsed paywall is non-dismissible with restored content preserved; flush success → Main; `WelcomeBackStubView` deleted — returning entitled sign-in reclassifies through the router; Profile reachable from Home's top bar (SPEC §14 #36).*

### Tests

- [x] **M2-19** Unit tests (Swift Testing, in `PluriTests`, mocks for auth/**RevenueCat**): launch-routing state machine (fresh / signed-in+entitled / signed-in+lapsed / signed-out), entitlement + trial-state resolution logic, and the M2-13 mapping layer (representative personas round-trip answers/plan → rows). *Shipped: `AppRouterTests` cover the full routing matrix + splash gating + funnel transitions; pure `EntitlementResolver` (extracted from `SubscriptionService.isInTrialPeriod`) tested for inactive / active-regular / active-trial / active-introductory without constructing RC `CustomerInfo`; `OnboardingSyncMapperTests` expanded to three personas (commercial-gym scheduled, bodyweight+injured flexible, home-gym single-day returner) with strong assertions on ids, ordering, dates, enums, injuries, equipment, and hydrated plan structure. 95/95 tests pass on iPhone 17 Pro sim.*

**M2 exit check** (PLAN M2): full funnel end-to-end — fresh install → name → auth → questionnaire → paywall → RevenueCat sandbox / test-key purchase with trial → flush profile + plan rows visible in Supabase under the signed-in user → relaunch restores session and entitlement. Sign out and delete account both verified. *Status 2026-07-16: M2-01..19 code-complete (95/95 tests, iPhone 17 Pro sim); the end-to-end exit run remains blocked on owner-controlled setup — M2-02 ASC/RC products, Apple Developer SIWA + Supabase Apple provider, and the M0-11 service-role key (SPEC §15).*

**M2-06..10 learned/changed:**

- DEBUG long-press on "Unlock my plan" sets `debug.bypassPaywall` and skips the paywall for local testing (`#if DEBUG` only).
- No direct StoreKit client code; SPM products are **RevenueCat** + **RevenueCatUI** (`purchases-ios-spm`).
- `REVENUECAT_API_KEY` flows `.env` → `generate_secrets.sh` → `Secrets.xcconfig` → Info.plist → `Secrets.revenueCatAPIKey` (never hardcode / never commit the key).
- Owner checklist: RC entitlement `Pluri Pro`, products `monthly`/`yearly`, default offering + Paywall (V2) with restore/terms/trial disclosure enabled; ASC products with **1-month free trial** intro offers on both (SPEC §14 #7); real IAP still requires M2-02.
- Trial open question closed: **1-month ASC introductory offer** (not 10-day / not RC granted entitlement) — SPEC §4, §14 #7, §15 updated 2026-07-15.

**M2-11 / M2-12 learned/changed:**

- Owner product decision: auth is **after name**, blocking, not counted in the 14-step progress bar (SPEC §14 #29). Flush stays post-unlock (M2-14).
- `OnboardingDestination.account` sits between `.name` and `.q1FitnessType`; already-signed-in users skip to Q1 from name.
- Returning entitled sign-in → `WelcomeBackStubView` interim until M2-15/18; non-entitled continue questionnaire.
- `Purchases.shared.logIn(supabaseUserId)` hosted on `SubscriptionService` after successful auth (non-blocking on failure).
- SIWA still blocked on Apple Developer portal + Supabase Apple provider (SPEC §15).
- **OTP UX (extends M2-11):** when email sign-up leaves session nil, show 6-digit OTP → `verifyOTP` → continue onboarding (SPEC §14 #30). Resend + gentle errors included.

**M2-13 / M2-14 / M2-15 learned/changed:**

- Pure mappers live under `Core/Sync/` (`DatabaseCodeMappings`, `OnboardingSyncMapper`, DTOs). Goal / injuries encoding in SPEC §14 #31.
- Flush runs from `PaywallUnlockedPlaceholderView` with retries + UserDefaults checkpoint; local answers/plan retained on failure.
- Remote restore hydrates welcome-back stub; Main routing still M2-18 (SPEC §14 #32).

**M2-15 / M2-18 launch skip (interim, 2026-07-15):**

- Cold launch now waits for `hasResolvedSession` + `hasResolvedCustomerInfo`, retries flush checkpoint, re-aliases RevenueCat, then restores remote profile/plan.
- Skip criterion (owner): signed-in **and** (`onboarding_completed` **or** active plan) → `WelcomeBackStubView` (no Splash→Qs stack). Incomplete signed-in users still go through Qs (M2-12).
- Lapsed entitlement still skips the questionnaire; locked Paywall Main remains M2-18 (SPEC §14 #33).
- Optional UserDefaults completion hint (keyed by userID) for offline relaunch; cleared on sign-out; remote wins when online.
- Full `AppRouter` / Main TabView still M2-18; M2-19 expands when that router lands.

---

## M3 — Home, Plan & Calendar

### Scope & plan data foundation (do first — decisions + data shape unblock every screen)

- [ ] **M3-01** Resolve and record M3 behavior decisions in SPEC §14/§15 before building UI: how flexible-plan (non-scheduled) workouts appear on calendar dots/day views, what "add a workout to an empty day" creates (SPEC §5.4), and how Manage Plan preserves completed workouts while regenerating the remainder (SPEC §6.2). Pick the most reversible interim option where the owner is unavailable (AGENTS §7).
- [ ] **M3-02** Fix `PlanEngine.scheduledDate` for plans starting mid-week (known Backlog defect): session order and concrete dates must stay chronological across week boundaries (e.g. start Wed with M/W/F must not put "Workout 1" after "Workout 2"). Regression tests covering all seven start weekdays.
- [ ] **M3-03** Extend the restored-plan domain/mapping (M2-15) to preserve workout status, type, color, stable ordering, and IDs — currently discarded on hydrate — as required by Home, Plan, Calendar, and future M4 workout navigation (PLAN §1.3).
- [ ] **M3-04** Shared `@Observable` plan store/view model initialized from `AppRouter`'s restored state, with derived day/week/today/completion data and explicit loading, empty (no plan), and failure states for the Main tabs to consume.
- [ ] **M3-05** Protocol-based authenticated plan mutation services (+ mocks for previews/tests): move/add workouts, update plan/profile settings, replace only-remaining workouts. Verify owner-only RLS (M0-09) end-to-end and that mutations survive relaunch restore.

### Main navigation & Home

- [ ] **M3-06** Evolve `MainTabView` from the M2-18 placeholder shell into the real M3 navigation skeleton: one `NavigationStack` per tab, typed `navigationDestination(for:)` routing, programmatic tab selection for cross-tab jumps, and Home health-tile deep links into the Insights placeholder (PLAN §1.2).
- [ ] **M3-07** Replace `HomePlaceholderView` with the Home top bar + calendar strip/month summary per SPEC §5: one workout dot per day (v1), selected-day workout content, and navigation to Profile, Notifications (M3-15), and the full Calendar page (M3-13).
- [ ] **M3-08** Home Pluri Score card *displaying a clearly-identified stub score* (SPEC §5.1 — real engine is M5) + Today's Health placeholder tiles for steps, sleep, and active heart rate (no HealthKit reads — live tiles are M5).
- [ ] **M3-09** Floating Record Workout action menu (SPEC §5) offering today's scheduled workout + Outdoor Run; both route to honest M4/stub destinations — no workout execution in M3.

### Plan page & Calendar

- [ ] **M3-10** Replace the Plan tab placeholder with the Plan page per SPEC §6: plan card (goal, end date, weeks-completed tracker), action buttons, and accessible week cards showing workout count, day, duration, type color, and completion checkmarks (design.md tokens).
- [ ] **M3-11** Week Overview (SPEC §6.3): the selected week's complete schedule with workout selection; taps route to an honest Workout Detail placeholder owned by M4 (SPEC §7 — do not build ahead).
- [ ] **M3-12** Plan Overview info page (SPEC §6.1) + Connected Apps shell: explain workout colors, the stub Pluri Score, Ask Pluri's future role, and current Apple Health/device status (display-only until M5).
- [ ] **M3-13** Reusable Calendar/Rearrange page (SPEC §5.4), reachable from Home and Plan: week-by-week navigation, empty-day affordances, move-workout and add-workout flows, conflict validation, optimistic UI with gentle rollback on failure, remote persistence via M3-05, and reminder reconciliation (M3-15).
- [ ] **M3-14** Manage Plan (SPEC §6.2): edit goal, dates/length, training days, session duration, and units; regenerate **only unfinished workouts**, preserving completed/skipped history and exercise-row integrity per the M3-01 decision; persist atomically enough that a failure never leaves a partially replaced remote plan.

### Notifications & verification

- [ ] **M3-15** Replace Profile's notification stub (M2-16) with the Notifications page shell (SPEC §5.3) + protocol-based local notification service: request permission only after explicit opt-in, then schedule/update/cancel upcoming-workout reminders whenever the plan changes. (Community notification rows stay placeholders until M8; the late-day reschedule nudge is M4.)
- [ ] **M3-16** Unit/integration tests (Swift Testing, `PluriTests`): date grouping, completion calculations, calendar dots, move/add flows, remaining-plan regeneration, reminder reconciliation, mutation-failure rollback, and restoration round trips (extends M2-19 fixtures).
- [ ] **M3-17** M3 UI QA: previews for populated/empty/error states of every new view, Dynamic Type, VoiceOver, dark mode, 44pt targets, scheduled + flexible personas, relaunch persistence, and full Home → Plan → Calendar → Manage Plan navigation click-through.

**Dependencies:** M3-01 → 02/03 → 04/05 → UI tasks (06–12); 02/04/05 → 13/14; 13/14 → 15; everything → 16/17.

**M3 exit check** (PLAN M3): user can browse and rearrange their entire plan; navigation skeleton complete. Specifically: the M2 routing matrix stays green; mid-week scheduled plans are chronological; flexible-plan behavior matches the M3-01 decision; calendar moves/additions survive relaunch under owner-only RLS; Manage Plan preserves completed/skipped and replaces only the remaining range with no partial remote state; week cards reflect persisted status/type/color; Home/Plan handle no-plan, offline-restore, and mutation failures gently; reminder opt-in/denial/reschedule/cancel is deterministic and tested; stub Score/Health/Workout Detail/Outdoor Run can't be mistaken for live functionality; build + Swift Testing suite pass with no new warnings; Dynamic Type/VoiceOver/dark mode/contrast/44pt targets manually checked.

**Deferred out of M3 (don't build ahead):** real Workout Detail + live workout and the late-day reschedule nudge (M4); real HealthKit reads + Pluri Score engine (M5); Outdoor Run stays a stub; Community notification rows stay placeholders until M8.

---

## M4+ — not yet generated

Tasks for M4 (Workout Experience) will be generated when M3 is near completion, incorporating what M3 taught us (plan store shape, mutation services, calendar/reminder behavior).

---

## Backlog / surfaced items

- Decide the fate of the legacy Supabase prototype tables (`workout_plans`, `plan_days`, `plan_day_exercises`, `user_equipment`, plus the 3 seeded profile rows). Dropping them is destructive → owner approval required (AGENTS §6). **Update (2026-07-13):** the seeded `exercises` catalog (1,327 rows) is no longer just a candidate fallback — it is now the app's **primary catalog source** (`SupabaseExerciseCatalogClient`, SPEC §14 #25), so `exercises` must be kept (and eventually kept in sync with WorkoutX server-side, e.g. from the M2+ `generate-plan` Edge Function). The other legacy tables are still pending an owner decision.
- ~~No test target exists yet~~ **Resolved (M1-17):** the `PluriTests` Swift Testing target was added to `project.pbxproj` and now compiles `CalorieCalculatorTests.swift` + `PlanEngineTests.swift` (24 tests passing). `ExerciseCatalogStore.isStale` (M1-03) is still uncovered but now trivially testable in the same target — a candidate follow-up test.
- `PlanEngine.scheduledDate` (M1-16) anchors each week's window at `startDate + 7×(week−1)` and maps sessions onto training days sorted Sunday-first, so when the start date falls mid-week, week 1's session dates can be out of order relative to `indexInWeek` (e.g. start Wed with Mon/Wed/Fri → "Workout 1" lands on the *following* Monday, after "Workout 2"'s date). Harmless for the M1 teaser/dump, but fix before the calendar/home screens render week 1 (surfaced during M1-16..18 QA). **Update (2026-07-16):** scheduled as **M3-02**.
- `PluriPillButtonStyle` (M0) has no visual disabled state — it ignores `\.isEnabled`, so onboarding's disabled Continue buttons (empty name, no location picked, <2 training days, …) still render full brand orange and look tappable. Add an `@Environment(\.isEnabled)` dim/desaturate to the style. (Surfaced during M1-04..15 QA — pre-existing component, not fixed inline per AGENTS §7.)
- ~~Q6 equipment strings vs live WorkoutX punctuation/casing differences~~ **Resolved (M1-16):** `EquipmentMatcher` normalizes both sides (lowercase + strip non-alphanumerics) before comparison, so `"Dumbbell + Exercise Ball"` matches `"Dumbbell, Exercise Ball"` etc., with no brittle mapping table. Covered by `PlanEngineTests`. See SPEC §14 #19.
- ~~Consider renaming the Xcode target/product from `pluri_fable_xcode` to `Pluri`~~ **Resolved (M2-01):** target/module renamed to `Pluri`, bundle id `com.codewithmikey.Pluri`.
- Security advisor flags: `public.rls_auto_enable()` (SECURITY DEFINER, pre-existing) is executable by anon/authenticated — revoke EXECUTE or move it; leaked-password protection is disabled in Auth settings.
- Supabase Auth leaked-password protection and the M0-11 key rotation both need the owner in the dashboard — bundle them into one session.

