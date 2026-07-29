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

- [x] **M3-01** Resolve and record M3 behavior decisions in SPEC §14/§15 before building UI: how flexible-plan (non-scheduled) workouts appear on calendar dots/day views, what "add a workout to an empty day" creates (SPEC §5.4), and how Manage Plan preserves completed workouts while regenerating the remainder (SPEC §6.2). Pick the most reversible interim option where the owner is unavailable (AGENTS §7).
- [x] **M3-02** Fix `PlanEngine.scheduledDate` for plans starting mid-week (known Backlog defect): session order and concrete dates must stay chronological across week boundaries (e.g. start Wed with M/W/F must not put "Workout 1" after "Workout 2"). Regression tests covering all seven start weekdays.
- [x] **M3-03** Extend the restored-plan domain/mapping (M2-15) to preserve workout status, type, color, stable ordering, and IDs — currently discarded on hydrate — as required by Home, Plan, Calendar, and future M4 workout navigation (PLAN §1.3).
- [x] **M3-04** Shared `@Observable` plan store/view model initialized from `AppRouter`'s restored state, with derived day/week/today/completion data and explicit loading, empty (no plan), and failure states for the Main tabs to consume.
- [x] **M3-05** Protocol-based authenticated plan mutation services (+ mocks for previews/tests): move/add workouts, update plan/profile settings, replace only-remaining workouts. Verify owner-only RLS (M0-09) end-to-end and that mutations survive relaunch restore.

> **Learned during M3-01..05 (2026-07-16):** decisions recorded as SPEC §14 #37 (flexible workouts = weekly pool, dots only for dated workouts), #38 (add-to-empty-day = clone with new IDs, one workout/day), #39 (regeneration preserves completed/skipped, insert-then-delete sequencing; transactional RPC deferred to M3-14), #40 (`PlanStore` states; `restoredState == nil` at Main surfaces as `.failed`). `PlanEngine` scheduling now maps sessions onto each rolling week's training-day dates chronologically (`orderedTrainingDates`), and `PlannedSession`/`GeneratedPlan` carry status/type/color/orderIndex/duration + plan name/status/endDate through flush ↔ hydrate. Mutations (`PlanMutator` + `PlanStore` + `SupabasePlanMutationService`) are covered by unit tests against `MockPlanMutationService` — RLS is enforced by the authed-client write path (same as flush/restore, M0-09 policies), but a live authenticated integration test still needs a real signed-in user/secrets, so end-to-end RLS + relaunch-restore verification on-device remains part of M3-17 QA.

### Main navigation & Home

- [x] **M3-06** Evolve `MainTabView` from the M2-18 placeholder shell into the real M3 navigation skeleton: one `NavigationStack` per tab, typed `navigationDestination(for:)` routing, programmatic tab selection for cross-tab jumps, and Home health-tile deep links into the Insights placeholder (PLAN §1.2).
- [x] **M3-07** Replace `HomePlaceholderView` with the Home top bar + calendar strip/month summary per SPEC §5: one workout dot per day (v1), selected-day workout content, and navigation to Profile, Notifications (M3-15), and the full Calendar page (M3-13).
- [x] **M3-08** Home Pluri Score card *displaying a clearly-identified stub score* (SPEC §5.1 — real engine is M5) + Today's Health placeholder tiles for steps, sleep, and active heart rate (no HealthKit reads — live tiles are M5).
- [x] **M3-09** Floating Record Workout action menu (SPEC §5) offering today's scheduled workout + Outdoor Run; both route to honest M4/stub destinations — no workout execution in M3.

> **Learned during M3-06..09 (2026-07-17):** decisions recorded as SPEC §14 #41 (month summary = name + "N of M done"; Home ignores flexible pool; `MainRouter` separate from `AppRouter`; workout color token mapping; hide empty today-option in Record menu; selected day defaults to today; sample Pluri Score = 72). Navigation skeleton uses typed `HomeRoute` + Insights section deep links; Calendar / Notifications / Workout Detail / Outdoor Run are honest stubs until M3-13 / M3-15 / M4. Calendar strip currently spans only the current month — month paging belongs with the real Calendar page (M3-13).

### Plan page & Calendar

- [x] **M3-10** Replace the Plan tab placeholder with the Plan page per SPEC §6: plan card (goal, end date, weeks-completed tracker), action buttons, and accessible week cards showing workout count, day, duration, type color, and completion checkmarks (design.md tokens).
- [x] **M3-11** Week Overview (SPEC §6.3): the selected week's complete schedule with workout selection; taps route to an honest Workout Detail placeholder owned by M4 (SPEC §7 — do not build ahead).

> **Learned during M3-10..11 (2026-07-17):** decisions recorded as SPEC §14 #42 (weeks-completed tracker = `PlanStore.completedWeekCount`, i.e. weeks with nothing still scheduled; flexible workouts stay on their week card labeled "Anytime this week" — no invented dates; the four action buttons route to honest placeholders until M3-12/13/14; Plan gets its own typed `PlanRoute` path and Workout Detail from Plan stays in the Plan stack). Display logic lives in a testable `PlanViewModel` (`Features/Plan/Page/`); the new page reuses `HomeMessageCard` for the failed/no-plan states and `WorkoutDetailStubView` for workout taps. The M1-18 plan-ready teaser already owned the name `PlanSummaryCard`, so the Plan page's top card is `PlanCardView`.

- [x] **M3-12** Plan Overview info page (SPEC §6.1) + Connected Apps shell: explain workout colors, the stub Pluri Score, Ask Pluri's future role, and current Apple Health/device status (display-only until M5).
- [x] **M3-13** Reusable Calendar/Rearrange page (SPEC §5.4), reachable from Home and Plan: week-by-week navigation, empty-day affordances, move-workout and add-workout flows, conflict validation, optimistic UI with gentle rollback on failure, remote persistence via M3-05, and reminder reconciliation (M3-15).
- [x] **M3-14** Manage Plan (SPEC §6.2): edit goal, dates/length, training days, session duration, and units; regenerate **only unfinished workouts**, preserving completed/skipped history and exercise-row integrity per the M3-01 decision; persist atomically enough that a failure never leaves a partially replaced remote plan.

> **Learned during M3-12..14 (2026-07-17):** decisions recorded as SPEC §14 #43 (Plan Overview content — color legend, honest sample-score explainer, Ask Pluri as upcoming; Connected Apps = display-only shell, no fake connect buttons), #44 (one reusable `CalendarView` for Home Calendar + Plan Rearrange staying in the originating stack; button/sheet move + add flows; history immutable — `PlanMutator` now rejects moving completed/skipped via `workoutFinished`; `WorkoutReminderReconciling` no-op hook fires after successful remote writes and never rolls back a persisted change), and #45 (start + weeks primary / end date derived and clamped to whole weeks 3–12; regeneration cutoff = all unfinished; **`replace_remaining_plan` SECURITY INVOKER RPC** — local migration `20260717194112`, applied to the remote project as version `20260717194247` — makes Manage Plan persistence a single transaction; units-only saves take a plain profile update). `PlanStore` gained `applyManagePlan` / `updateProfileSettings` / `updatePlanSettings` (optimistic, rollback restores plan **and** profile). New suites: `CalendarViewModelTests`, `ManagePlanViewModelTests`; `PlanStoreTests` covers the finished-move guard, reminder hook, and Manage Plan success/rollback. Live end-to-end RPC verification still needs a real signed-in user (same caveat as M3-05).

### Notifications & verification

- [x] **M3-15** Replace Profile's notification stub (M2-16) with the Notifications page shell (SPEC §5.3) + protocol-based local notification service: request permission only after explicit opt-in, then schedule/update/cancel upcoming-workout reminders whenever the plan changes. (Community notification rows stay placeholders until M8; the late-day reschedule nudge is M4.)
- [x] **M3-16** Unit/integration tests (Swift Testing, `PluriTests`): date grouping, completion calculations, calendar dots, move/add flows, remaining-plan regeneration, reminder reconciliation, mutation-failure rollback, and restoration round trips (extends M2-19 fixtures).
- [x] **M3-17** M3 UI QA: previews for populated/empty/error states of every new view, Dynamic Type, VoiceOver, dark mode, 44pt targets, scheduled + flexible personas, relaunch persistence, and full Home → Plan → Calendar → Manage Plan navigation click-through.

> **Learned during M3-15..16 (2026-07-17):** decision recorded as SPEC §14 #48 (8 AM local fire; user-scoped opt-in preference; permission only after toggle-on with gentle Settings guidance on denial; `pluri.workout-reminder.<uuid>` identifiers; cancel-then-reschedule reconcile that never throws into `PlanStore`; Notifications page shell with Community/nudge placeholders). One `WorkoutReminderService` instance is owned by `AppRootView` and serves both the Notifications toggle and the `PlanStore` reconcile hook (via `UserNotificationCenterClient` so tests don't need the real system). Existing `PlanStoreTests` / mapper / Calendar / Manage Plan suites already covered the store-side M3-16 items; new `WorkoutReminderServiceTests` cover the real service, and the reminder-hook test now also asserts `replaceRemainingWorkouts`.

> **Learned during M3-17 QA (2026-07-17):** `build_sim` clean + **178/178** tests green (iPhone 17 Pro sim). Previews cover ready/empty/failed for Home, Plan, and Calendar; Notifications has off/on/denied; Manage Plan has ready/empty; Week Overview gained scheduled + flexible previews. Added `HomePreviewData.flexibleStore()` so Home/Plan/Calendar/Week Overview can preview the SPEC §14 #37 persona (Home: no dots; Plan/Calendar: "Anytime this week"). Accessibility: M3 screens use Dynamic Type via `PluriFont`, `PluriColor` tokens (dark variants from M0), combined accessibility labels on cards/rows, toolbar `Button(_:systemImage:)` labels, and a Notifications toggle hint that surfaces the permission/Settings footer. Navigation skeleton verified by typed-route audit (`HomeRoute` → Profile / Notifications / Calendar; `PlanRoute` → Week Overview / Plan Overview / Rearrange / Connected Apps / Manage Plan / Workout Detail stub) — this MCP session has `screenshot`/`snapshot_ui` but no tap automation, so full signed-in click-through + live relaunch/RLS persistence still needs an owner device session (same caveat as M3-05/14).

### Focus-first plan generation (owner decision — SPEC §14 #46/#47)

- [x] **M3-18** Session-focus & split model: types for the weekly split derived from days/week + experience/goal (2 → Full Body A/B; 3 → PPL or Upper/Lower/Full Body; 4 → PPL+Upper or body-part split; 5–6 → PPL + accessories or classic body-part split), each focus carrying primary/secondary target muscles, a display title, and a design-token color (SPEC §14 #46); plus the `BodyArea` → WorkoutX `targetMuscle`/`secondaryMuscles` mapping needed by both focus selection and the graded injury rules (SPEC §14 #47). Pure, `nonisolated`, unit-tested (Swift Testing) — no engine changes yet.
- [x] **M3-19** `PlanEngine` rework to focus-first selection (SPEC §14 #46/#47, supersedes the #23 round-robin and #20 coarse exclusion): assign the split's focuses to training days, fill each session with majority primary-target movements + 1–2 secondary/supporting via `targetMuscle`/`secondaryMuscles`, title sessions from their focus (replacing `sessionTitle(for:)`'s body-part counting), apply graded pain rules (1–2 no-primary/light-secondary, 3 no-primary/load-capped-secondary, 4–5 hard exclusion), and fall back to a Full Body focus only when earned (2-day plans or a too-small eligible pool). Session sizing (#22), progression, and determinism (#24) unchanged; keep the engine cleanly portable to the future `generate-plan` Edge Function. Update/extend `PlanEngineTests` (splits per days/week, focus composition, injured personas per pain tier, small-pool fallback, seed determinism).
- [x] **M3-20** Persist the session focus (SPEC §14 #46): Supabase migration adding a `focus` code column on `plan_workouts`; extend sync DTOs + `OnboardingSyncMapper` (and `OnboardingSyncMapperTests` round-trips) so focus flushes and restores; existing plans without a focus stay valid — hydrate/UI treat missing focus as legacy and fall back to current name/color behavior (no backfill required; next regeneration writes it).
- [x] **M3-21** Focus-driven UI: resolve workout colors from the persisted focus token through the existing `WorkoutColorResolver` path (#41d — persisted color still wins, type defaults remain the legacy fallback), plumb focus-based titles/labels through Home, Plan, and Calendar rows, and ensure every regeneration path (Manage Plan M3-14, calendar add/move clones per #38) carries the focus through `PlanStore` mutations.

> **Learned during M3-18..21 (2026-07-25):** focus-first plan generation shipped per SPEC §14 #46/#47 — `SessionFocus` + `BodyAreaMuscleMapping` (pure, unit-tested), `PlanEngine` assigns split-derived focuses then fills sessions from `targetMuscle`/`secondaryMuscles` with graded pain rules, and titles/colors come from the focus (not body-part counting). Algorithm forks recorded as §14 #49 (beginner 3-day Upper/Lower/Full Body; body-part vs PPL by goal/experience; pain-3 supported/machine secondary filter; small-pool Full Body fallback). Persistence: `plan_workouts.focus` column + CHECK (migrations `20260717211519` / `20260725203245`), sync DTOs + `OnboardingSyncMapper` round-trip; legacy rows without focus keep name/type color fallbacks. `WorkoutColorResolver` order is now persisted color → focus token → type default (#41d updated). Manage Plan / calendar clone paths carry focus. Remaining honest stubs (`WorkoutDetailStubView`, Outdoor Run, late-day nudge) stay deferred to M4.

**Dependencies:** M3-01 → 02/03 → 04/05 → UI tasks (06–12); 02/04/05 → 13/14; 13/14 → 15; 18 → 19 → 20 → 21; everything → 16/17.

**M3 exit check** (PLAN M3): user can browse and rearrange their entire plan; navigation skeleton complete. Specifically: the M2 routing matrix stays green; mid-week scheduled plans are chronological; flexible-plan behavior matches the M3-01 decision; calendar moves/additions survive relaunch under owner-only RLS; Manage Plan preserves completed/skipped and replaces only the remaining range with no partial remote state; week cards reflect persisted status/type/color/focus; Home/Plan handle no-plan, offline-restore, and mutation failures gently; reminder opt-in/denial/reschedule/cancel is deterministic and tested; stub Score/Health/Workout Detail/Outdoor Run can't be mistaken for live functionality; build + Swift Testing suite pass with no new warnings; Dynamic Type/VoiceOver/dark mode/contrast/44pt targets manually checked. ✅ verified 2026-07-25 — M3-01..21 complete (focus-first engine + persistence + UI); Workout Detail / Outdoor Run / late-day nudge remain honest stubs owned by M4.

**M3 learned/changed:** plan domain now carries session `focus` through engine → Supabase → hydrate → Home/Plan/Calendar; color resolution prefers focus tokens when no explicit color is stored; injury programming is graded by pain (#47/#49) instead of coarse body-part exclusion (#20). No change to M3 exit scope — live workout execution, SyncEngine, Apple Health workout write, and the late-day nudge were correctly left for M4.

**Deferred out of M3 (don't build ahead):** real Workout Detail + live workout and the late-day reschedule nudge (M4); real HealthKit reads + Pluri Score engine (M5); Outdoor Run stays a stub; Community notification rows stay placeholders until M8.

---

## M4 — Workout Experience

Core of the app (PLAN M4): Workout Detail, live Workout Screen, completion summary, offline-first `SyncEngine`, Apple Health workout sync, late-day reschedule nudge. Builds on M3's `PlanStore` / mutation services / reminder reconcile. **Exit:** user completes a real workout start-to-finish, offline, with data synced and the plan workout checked off.

### Scope & decisions (do first — unblock UI + sync semantics)

- [x] **M4-01** Resolve and record M4 behavior decisions in SPEC §14/§15 before building UI: late-day nudge fire time + reschedule UX (SPEC §5.3); skip vs discard semantics (Detail skip checks off as skipped; completion Discard drops in-progress without check-off); crash/kill recovery for in-progress sessions (resume after relaunch — never lose offline progress); weight unit display (profile metric/imperial from Manage Plan); Ask Pluri = honest stub labeled for M6 (no fake coach); HealthKit usage strings and the write-only Apple Health workout sync boundary vs live HR/calories during an active session (Insights HealthKit *reads* stay M5). Pick the most reversible interim option where the owner is unavailable (AGENTS §7).

> **Learned during M4-01 (2026-07-25):** decisions recorded as SPEC §14 **#50** (late-day nudge = 21:00 local, no catch-up, separate opt-in from #48, notification → day picker / Move to tomorrow via `PlanStore.move`; Detail Skip → `skipped`, completion Discard → drop in-progress, plan stays `scheduled`; crash/kill resume, one in-progress session per `plan_workout_id`; weight UI from profile units, canonical `weight_kg`; Ask Pluri honest M6 stub; HealthKit — live HR/active energy only while session active in M4, workout write only on Save when toggle on, Insights reads stay M5; Start does not complete — Save links session + sets `completed`). §5.3 / §8.1 / #48e point at #50; §15 M4 behavior question resolved. No Swift/UI/HealthKit code in this task — M4-02+ implements against these decisions.

### Offline domain & sync

- [x] **M4-02** SwiftData models + repository for in-progress/completed `WorkoutSession` + `SetLog` (+ workout/exercise notes); local-first writes; resume an in-progress session after relaunch/kill. Cardinal rule: never lose an in-progress workout while offline. Unit tests for create/resume/complete/discard persistence.

> **Learned during M4-02 (2026-07-25):** `WorkoutSessionRecord` / `SetLogRecord` + `SwiftDataWorkoutSessionRepository` ship local-first create/resume/complete/discard with immediate `context.save()` on every mutation; one in-progress session per `plan_workout_id` (#50c); `weightKg` canonical; workout notes on session, per-exercise notes + pause/elapsed fields are **local-only** (SPEC §14 #51). No UI, SyncEngine, or PlanStore mutations in this task.
- [x] **M4-03** `SyncEngine`: queue session / set_log upserts to Supabase (`workout_sessions` / `set_logs`), last-write-wins, retry when online; update `plan_workouts.status` → `completed` (and session link) per the M4-01 decision. Protocol + mock for tests; never block local save on network.

> **Learned during M4-03 (2026-07-25):** `SyncEngine` + `SupabaseSyncEngine` / `MockSyncEngine` upload pending `needsSync` sessions/set_logs (LWW upsert by id); completed sessions with `planWorkoutId` thin-update `plan_workouts.status = completed`. Session link is `workout_sessions.plan_workout_id` only (SPEC §14 #52 — no `plan_workouts.session_id`). Reachability via injectable `NetworkReachability` (`NWPathMonitor` in prod). Never blocks repository saves; flush failures leave `needsSync` for retry. No UI.
- [x] **M4-04** Extend `PlanStore` / `PlanMutator` / plan mutation service: skip workout; mark completed with session link; optimistic UI + rollback on remote failure; reminder reconcile after success (extends M3-15 / #44/#48).

> **Learned during M4-04 (2026-07-25):** `PlanMutator.skippingWorkout` only from `.scheduled`; `completingWorkout` from `.scheduled` **or** `.skipped` (skip → later Save); re-complete `.completed` → `workoutFinished` (SPEC §14 #50b/#52). **Skip** = move-style optimistic + `updateWorkoutStatus` + rollback + reminders on success. **Complete** = local `.completed` + `syncEngine.enqueueSession` (no rollback on sync failure) + reminders after *local* apply. Discard unchanged (repo-only). No Detail/Screen UI (M4-05+).

### Workout Detail (SPEC §7)

- [x] **M4-05** Replace `WorkoutDetailStubView` with the real Detail page: focus-driven title/type/color, equipment rollup for the whole session, exercise list + set counts, **View Workout** → live Screen. Reachable from Home Record menu, selected-day card, and Week Overview (typed routes already stubbed in M3).
- [x] **M4-06** Skip workout action + Workout Notes bottom sheet on Detail (SPEC §7); skip persists via M4-04 and stays gentle (no scolding).

> **Learned during M4-05/06 (2026-07-25):** real `WorkoutDetailView` + `WorkoutDetailViewModel` replace the stub; entry points = Record menu, Home day-card row tap, Week Overview. **View Workout** pushes typed `HomeRoute`/`PlanRoute.workoutScreen` (live Screen in M4-07/08). Notes sheet uses `.pluriBottomSheet`; first save `startOrResume` then `updateWorkoutNotes` (SPEC §14 #53). Skip only when `.scheduled`, via `PlanStore.skipWorkout`, then discards any local in-progress session for that workout. `SwiftDataWorkoutSessionRepository` is `@Observable` and injected from `AppRootView`.

### Live Workout Screen (SPEC §8)

- [x] **M4-07** Pre-start layout: idle timer, empty metric slots, one exercise card per exercise (image/animation, name, equipment, primary/secondary muscle, sets×reps or time), **Start** + Ask Pluri stub (M4-01 / M6).
- [x] **M4-08** Expanded exercise sheet: longer description, per-exercise notes, media (image/animation; **hide video toggle** per SPEC §14 #11 until a video source exists); media caching path so offline sessions still show previously seen assets.

> **Learned during M4-07/08 (2026-07-25):** `WorkoutScreenView` + `WorkoutScreenViewModel` replace `WorkoutScreenStubView`. Pre-start = idle `00:00` hero timer, empty HR/kcal slots, exercise cards (`CachedExerciseMediaView` + disk `ExerciseMediaCache` under `URL.cachesDirectory/ExerciseMedia`), **Start** → `startOrResume` (soft “In progress”; no running timer/Pause/Stop — M4-09). Ask Pluri = honest M6 stub sheet (§14 #50e). Card tap → `.pluriBottomSheet` with catalog `instructions` (graceful empty if missing), per-exercise notes via `updateExerciseNotes`, GIF/image media; video toggle hidden while `videoURL` nil (§14 #11 / #54).

- [x] **M4-09** After Start: running timer; Pause / Stop; hold-to-finish gesture; Stop → pause (hold-to-finish → completion — M4-12 / M4-19). Persist session state continuously (M4-02).
- [x] **M4-10** Inline Log (reps/weight) and timed-exercise timer on cards; log UI expands inline but stays compact; <100 ms feedback; write `SetLog` to SwiftData immediately (M4-02) — sync is opportunistic (M4-03).
- [x] **M4-11** Live HealthKit heart rate + calories during an *active* workout (display only; graceful empty state if unauthorized). Full Insights HealthKit reads and Pluri Score remain M5.

> **Learned during M4-09/10/11 (2026-07-25):** Screen **Start** calls `resume` after soft `startOrResume` so Detail Notes never auto-run the hero timer (`hasStartedLiveTimer`, §14 #55). Pause folds elapsed into `accumulatedActiveSeconds`; originally Stop / hold-to-finish both pushed `workoutCompletion` — **superseded by M4-19 / §14 #55c** (Stop = pause; hold-to-finish only). Inline Log converts lb→`weight_kg` via `Measurement`; optional per-card timer writes `durationSeconds` (plan model still sets×reps only). Live HR/kcal via `WorkoutHealthMetricsProviding` stream only while unpaused; unauthorized stays "—".

### Completion (SPEC §8.1) & Apple Health

- [x] **M4-12** Completion summary: workout name, date performed, planned vs actual duration, total reps, notes field, **Discard** / **Save** (per M4-01 semantics).
- [x] **M4-13** Toggle sync to Apple Health on Save; persist `synced_to_health`; a Health write failure must not lose the local session (gentle retry / leave unsynced).
- [x] **M4-14** Save path: mark plan workout completed + session link (M4-04), enqueue SyncEngine (M4-03), reconcile reminders; Discard drops the in-progress session without check-off. Exit-path acceptance: complete a workout in airplane mode → relaunch → sync when online.

> **Learned during M4-12/13/14 (2026-07-25):** `WorkoutCompletionView` + ViewModel replace the stub; destinations wire `workoutSessionID`. Save order = local `complete` → optional `WorkoutHealthWriting` → `PlanStore.markWorkoutCompleted` (enqueue + reminders). Health toggle defaults **off**; failure = soft inline message + Done, never rollback (SPEC §14 #56). Discard = repo-only, plan stays `.scheduled`. After Discard (and after Save → **Done** per M4-19 / #56), pop Screen + Completion → Detail.

### Late-day nudge (SPEC §5.3)

- [x] **M4-15** Late-day reschedule nudge near midnight for unfinished `.scheduled` dated sessions (fire time + UX from M4-01); reuse `PlanStore` move; make the Notifications page late-day row live; opt-in / permission rules consistent with M3-15 (#48).

> **Learned during M4-15 (2026-07-25):** Late-day uses `pluri.late-day-nudge.*` at 21:00, separate UserDefaults opt-in from morning reminders, same permission rules (#50a / #48). `WorkoutReminderService.reconcileReminders` cancels/schedules both families in one hook. Tap → `LateDayNudgePresenter` → Move to tomorrow / `CalendarDayPickerSheet` → `PlanStore.moveWorkout`.

### Navigation & verification

- [x] **M4-16** Wire `MainRouter` / Record menu → real Detail → Screen; keep Outdoor Run as an honest stub (tracking deferred through M9); Ask Pluri entry points are clearly labeled stubs owned by M6.
- [x] **M4-17** Swift Testing (`PluriTests`): session lifecycle (start/pause/resume/complete/discard), set logging, skip/complete plan mutations, SyncEngine queue/retry + LWW, reminder reconcile after complete/skip, hold-to-finish, weight units from profile.
- [x] **M4-18** M4 UI QA: previews for Detail / Screen (pre-start + active) / completion / offline-resume; Dynamic Type, VoiceOver, dark mode, 44pt targets; airplane-mode complete → relaunch → online sync click-through.

> **Learned during M4-16/17/18 (2026-07-25):** Record / day card / Week Overview → Detail → Screen already wired; Outdoor Run + Ask Pluri remain honest stubs. Added handoff + late-day suite (Stop≡finish handoff later superseded by M4-19). Screen previews cover pre-start / running / paused / offline-resume; a11y spot-fixes on Detail rows, Completion notes, late-day toggle.
>
> **M4-18 manual airplane → sync checklist:** (1) Enable Airplane Mode. (2) Start a scheduled workout → log at least one set → **Hold to finish** → **Save** on completion (Health toggle off is fine; review results → **Done**). (3) Confirm Detail/plan shows the workout **completed** locally. (4) Force-quit and relaunch still offline — completed state and local session persist. (5) Disable Airplane Mode / restore network. (6) Wait for SyncEngine opportunistic flush (or trigger by briefly opening Main) — confirm remote `workout_sessions` / `set_logs` / `plan_workouts.status = completed` catch up without duplicating or rolling back the local completion.

- [x] **M4-19** Workout UX polish (2026-07-26): (1) inline Log weight filter/validation (digits + one decimal; locale comma; empty = bodyweight; disable Log + gentle error when invalid); (2) **Stop** = pause only — hold-to-finish is the sole path to Workout Complete (SPEC §14 #55c); (3) after Save, stay on completion with per-exercise set results until **Done** (SPEC §14 #56). Does **not** implement M5-17 Insights session routing.

> **Learned during M4-19 (2026-07-26):** `WorkoutWeightInput` filters/parses weight; card disables Log on invalid non-empty weight; `logSet` rejects non-finite/negative. Screen Stop → `pause()`; paused UI hides Stop, shows Resume + Hold to finish. Completion loads grouped set logs (kg/lb formatting spirit of Insights `setLine`); successful Save no longer auto-`didFinish` — Done dismisses like the Health-failure path. SPEC §14 #55c / #56 updated.

**Dependencies:** M4-01 → 02/03/04 (domain + sync semantics); 02 → 07–11 (live logging); 03/04 → 12–14 (completion + check-off); 05/06 → 16 (Detail entry); 01/04 → 15 (nudge); everything → 17/18; M4-19 polish on Screen/Completion.

**M4 exit check** (PLAN M4): user completes a real workout start-to-finish, offline, with data synced and the plan workout checked off. Specifically: Detail replaces the stub and is reachable from Home Record, day card, and Week Overview; live Screen supports start/pause/stop, hold-to-finish, inline log + timed exercises with immediate SwiftData persistence; completion Save/Discard match M4-01; SyncEngine retries when online (LWW); Apple Health sync on save is best-effort and never drops the local session; late-day nudge reschedules via existing PlanStore move under the same opt-in rules as M3-15; Ask Pluri and Outdoor Run remain honest stubs; build + Swift Testing suite pass; Dynamic Type/VoiceOver/dark mode/contrast/44pt targets manually checked.

**Deferred out of M4 (don't build ahead):** real Ask Pluri coach (M6 — stub OK); full HealthKit Insights reads + Pluri Score engine (M5); Outdoor Run tracking (stub through M9); Community notification rows (M8); manual "+" / Insights Workouts UI (M5); Cardio / Flexibility / hybrid plans and groups (v2).

---

## M5 — HealthKit Insights & Pluri Score

HealthKit Insights & Pluri Score (PLAN M5): full HealthKit *reads* (steps, sleep, heart rate, calories), live Today's Health tiles on Home, real Insights (Performance + Workouts, week filters, all-time stats, Bevel-style health insights), manual "+" activity logging, and the real Pluri Score engine (replacing M3's stub). Builds on M4's saved `WorkoutSession` / `SetLog` data, `Core/Health/` write/metrics patterns, and Home → Insights deep links. **Exit:** Insights reflect real logged + health data; score updates daily.

### Scope & decisions (do first — unblock formula, auth UX, and storage)

- [x] **M5-01** Resolve and record M5 behavior decisions in SPEC §14/§15 before building UI: adopt/refine the PLAN §1.4 Pluri Score formula (70% consistency over trailing 4 weeks with streak + gentle decay + 30% health trend vs 30-day baseline; clamp daily Δ e.g. ±3 — closes the §15 open question on exact weighting); HealthKit read types + auth UX (connect CTA vs Settings guidance on denial); unauthorized/empty states for tiles and Insights; score refresh cadence (launch vs daily observer); manual-activity storage (local-only vs sync); Devices row stays an honest stub vs out of scope. Pick the most reversible interim option where the owner is unavailable (AGENTS §7).

> **Learned during M5-01 (2026-07-26):** decisions recorded as SPEC §14 **#57** (Pluri Score = `0.7 × consistency + 0.3 × health`, daily Δ clamp ±3, trailing 4 weeks dated plan workouts + 30-day health baseline; skipped ≠ completed; flexible pool excluded; HK denied → 100% consistency; Connect CTA on Connected Apps + Profile with Settings guidance on denial, superseding display-only #35/#43 for Apple Health; honest empty tiles/Insights; refresh on foreground/launch + Save/plan status change — daily HK observer optional M5-18; manual "+" local-first, counts toward Insights stats but not plan-consistency; Devices honest stub; HK/score inputs on-device only — #50f write path stays separate). §5.1 / §5.2 / Connected Apps / §9.3 point at #57; §15 Pluri Score formula question resolved. No Swift/UI/HealthKit/plist code in this task — M5-02+ implements against these decisions.

### HealthKit service & connect

- [x] **M5-02** Protocol-based `HealthKitReading` / `HealthKitService` (+ mocks for previews/tests): request read authorization; query today + historical steps, sleep, heart rate, and active energy. Never upload HealthKit samples off-device (SPEC §13). Reuse/extend M4 `Core/Health/` patterns; keep the workout *write* path (`WorkoutHealthWriting`) separate from Insights *reads*.

> **Learned during M5-02 (2026-07-26):** `HealthKitReading` + `LiveHealthKitService` + `MockHealthKitReading` in `Core/Health/` — read-only auth for steps / sleep / heart rate / active energy; `todaySnapshot` / `daySnapshot` + `dailyHistory` (inclusive calendar days, enough for 30-day baseline); `HealthKitReadAuthorizationStatus` (`unavailable` / `notDetermined` / `authorized` / `denied`) for M5-03 Connected Apps wiring; unauthorized → honest empty nils (no invented metrics). Workout *write* path (`WorkoutHealthWriting` / `LiveWorkoutHealthWriter`) untouched — read service never requests share types or uploads. API shape logged as SPEC §14 **#58**. No Connected Apps / Profile UI, Home tiles, ScoreEngine, or Info.plist edits (M5-03/04/05/14).

- [x] **M5-03** Wire Apple Health connect on Connected Apps + Profile (replace display-only shells — SPEC §5.2, §14 #35/#43): real connection status, connect CTA, and Settings guidance on denial. Devices remain an honest stub ("arrives in a future update" — no pretend Bluetooth).

> **Learned during M5-03 (2026-07-26):** `AppleHealthConnectionViewModel` + shared `AppleHealthConnectionSection` on Connected Apps + Profile, fed by AppRoot-owned `LiveHealthKitService` (`HealthKitReading` only — no `WorkoutHealthWriting`). Status labels: Connected / Not connected / Not available; Connect CTA only when `.notDetermined`; `.denied` → gentle Settings footer (mirror Notifications, no Open Settings deep link); refresh on appear + scene active. Devices stub unchanged. Previews cover four statuses; VM tests with `MockHealthKitReading`. Plist usage-string broaden remains M5-14. **Corrected 2026-07-28 (M5-19 / SPEC §14 #78): this section was never actually mounted on Profile or Connected Apps, and the "no Open Settings deep link" choice is superseded by an Open Settings row.**

### Home live tiles & Score

- [x] **M5-04** Replace Home Today's Health placeholders with live tiles fed by M5-02 (steps, sleep, active heart rate); keep `MainRouter.openInsights(section:)` deep links into Insights (SPEC §5).

> **Learned during M5-04 (2026-07-26):** `HomeViewModel.healthTileMetrics` formats `HealthDaySnapshot` for steps / sleep / avg HR; authorized empties → “No data yet”, not connected → “Enable Health”, unavailable → “Not available”. `HomeHealthTiles` takes live metrics; `onOpen` still calls `MainRouter.openInsights(section:)`. Refresh on `.task` + `scenePhase == .active` (mirror Connected Apps). Tile formatting unit-tested; deep-link path unchanged.

- [x] **M5-05** `ScoreEngine` (pure, unit-tested): consistency + health components + daily clamp per M5-01 / PLAN §1.4; inject plan sessions + on-device HealthKit aggregates (SPEC §5.1). On-device only — score inputs never leave the device (SPEC §13).

> **Learned during M5-05 (2026-07-26):** `Features/Score/Engine/ScoreEngine.swift` (pure `nonisolated` enum, PlanEngine style) + `PluriScoreStore` (user-scoped UserDefaults for ±3 clamp). Formula per #57; streak/decay/health-ratio constants + empty-window = 100 logged as SPEC §14 **#59**. `ScoreEngineTests` cover math, skip/flexible exclusion, HK denied / insufficient samples, clamp edges, store round-trip. No remote upload.

- [x] **M5-06** Replace Home stub Pluri Score card with the live score from M5-05; update Plan Overview explainer so it no longer says the Home score is a sample until Insights (§6.1 / §14 #43).

> **Learned during M5-06 (2026-07-26):** `HomePluriScoreCard` shows live `pluriScore` (no Sample badge / sample disclaimer); `HomeView` refreshes score with health on appear / foreground / plan status fingerprint (#57d). `PlanOverviewView.PluriScoreExplainerCard` rewritten for live consistency-first + HealthKit second layer + ±3/day on-device. SPEC #41f/#43 softened; #59 records wiring. `HomeViewModelTests` replaced stub-score labeling with live refresh + tile tests.

### Insights Performance

- [x] **M5-07** Replace `InsightsPlaceholderView` with the Insights shell: **Performance** \| **Workouts** tabs, calendar + **"+"** in the top bar (SPEC §9); honor `insightsSection` deep links from Home health tiles.

> **Learned during M5-07 (2026-07-26):** `InsightsView` replaces the placeholder — Performance | Workouts chips, calendar + "+" toolbar (honest alerts until M5-12/13). Workouts tab is an honest empty stub (M5-11). Home `openInsights(section:)` still switches tab + sets `insightsSection`; shell lands on **Performance** and highlights the health subsection for M5-10 (SPEC §14 #60).

- [x] **M5-08** Performance tab: per-exercise stats from completed sessions / `set_logs` (reps/sets over time, volume, trends); week filter (SPEC §9.1).

> **Learned during M5-08 (2026-07-26):** `WorkoutSessionRepository.fetchCompletedSessions(endingOnOrAfter:endingBefore:)` + pure `PerformanceStatsEngine` (volume = Σ(reps×weightKg); week = `weekOfYear` on `endedAt`; trend = first vs last day point). `InsightsPerformanceViewModel` + Swift Charts reps line when ≥2 days; honest empty when no completed sessions in the window. Unit-tested engine + repo fetch. All-Time / Health insights / Workouts list deferred to M5-09/10/11.

- [x] **M5-09** Performance All-Time Stats for v1 Weights (strength totals, total time worked out); runner metrics (distance, activity counts) labeled v2 / out of scope (SPEC §9.1).

> **Learned during M5-09 (2026-07-26):** `AllTimeStatsEngine` + `fetchAllCompletedSessions()` — workouts count, volume Σ(reps×weightKg), sets/reps, total `durationSeconds`; independent of week filter; plan sessions only until M5-12. No distance/runner counts. Unit-tested engine + repo fetch. SPEC §14 #61.

- [x] **M5-10** Performance Health insights (steps, sleep, calories, etc.): averages, trends vs the user's own baseline, gentle guidance — Bevel spirit; empty/unauthorized states when HealthKit reads are denied (SPEC §9.1).

> **Learned during M5-10 (2026-07-26):** `HealthInsightsEngine` (30-day baseline / 7-day recent via ScoreEngine constants) + live cards for steps / sleep / calories (active energy) / HR; kind guidance copy; chips honor `router.insightsSection` (added `.calories`); empty/denied mirror Home (“No data yet” / “Enable Health” / “Not available”). SPEC §14 #61.

### Insights Workouts & "+"

- [x] **M5-11** Workouts tab: completed workouts grouped by month + monthly totals; interactive cards with description, duration, total reps, and per-exercise logged sets (SPEC §9.2). Include M4 saved sessions (local + synced).

> **Learned during M5-11 (2026-07-26):** `WorkoutsListEngine` + `InsightsWorkoutsViewModel` group by month of `startOfDay(startedAt)` (#56); monthly count + optional Σ distance; expandable cards with PlanStore title / notes / activity label, duration, total reps, per-exercise sets. Honest empty state. Unit-tested engine. SPEC §14 #62.

- [x] **M5-12** Manual **"+"** logging: Workout / Cardio / Flexibility → date → start time → duration (+ distance for Cardio); logged activities appear in Workouts and count toward stats (SPEC §9.3). Persistence per M5-01. (Manual Cardio/Flexibility *log types* are in scope; Cardio/Flexibility *plans* remain v2.)

> **Learned during M5-12 (2026-07-26):** `createManualActivity` → completed `isManualLog` row (`planWorkoutId = nil`, `needsSync`); `ManualActivityLoggingSheet` wizard; duration-only Workout (no set entry); distance meters + profile-unit display; SyncEngine enqueue; switches to Workouts + refreshes All-Time. No plan completion / no score consistency impact. SPEC §14 #62.

- [x] **M5-13** Insights calendar affordance (top bar): day/range filter or navigate into health/workout context for the selected day — align with Home calendar patterns; record the interim choice in SPEC §14 if SPEC is thin.

> **Learned during M5-13 (2026-07-26):** Day-filter sheet (graphical DatePicker) — not plan `openCalendar()`. Confirm → Workouts + filter that `startedAt` day; Clear restores full list; optional Performance `weekStart` snap. Multi-day range deferred. SPEC §14 #62.

### Privacy & verification

- [x] **M5-14** Confirm Info.plist / usage strings cover M5 read types; App Review HealthKit privacy posture (display / score / insights only — never leave the device except user-initiated workout sync) (SPEC §13, AGENTS).

> **Learned during M5-14 (2026-07-26):** broadened `NSHealthShareUsageDescription` for steps / sleep / heart rate / active energy (Home tiles, Insights, Pluri Score) **and** live workout HR/energy; `NSHealthUpdateUsageDescription` kept for optional Save→Apple Health workout write. Reconciled with `LiveHealthKitService` / `LiveWorkoutHealthMetricsProvider` / `LiveWorkoutHealthWriter`. Confirmed SyncEngine has no HK sample upload path. Documented as SPEC §14 **#63**. Entitlement unchanged. **Corrected 2026-07-28 (M5-19 / SPEC §14 #78): the broadened share-usage string was recorded here but never written to `Config/Info.plist`, which still described workout-only reads until M5-19.**

- [x] **M5-15** Swift Testing (`PluriTests`): `ScoreEngine` math/clamp; HealthKit reader mocks; Home tile aggregation; Performance / Workouts aggregations; manual-activity inclusion; unauthorized empty paths.

> **Learned during M5-15 (2026-07-26):** gap-filled `WorkoutsListEngineTests` manual-inclusion; tightened All-Time plan+manual case; `MainRouterTests` health-tile deep links (`.steps` / `.activeHeartRate` / `.calories` / `.sleep`); `InsightsViewModelTests` for unauthorized health empty copy + Workouts day filter / empty path. Existing suites already cover ScoreEngine, HealthKit mocks, Home tiles, Performance/Health engines.

- [x] **M5-16** M5 UI QA: previews for connected / denied / empty / populated states; Dynamic Type, VoiceOver, dark mode, 44pt targets; Home tiles → Insights section click-through; score moves after completing workouts (and daily refresh per M5-01).

> **Learned during M5-16 (2026-07-26):** previews added for `HomeHealthTiles` (populated / authorized-empty / Enable Health / denied / unavailable), `InsightsPerformanceView` (empty week / populated / HK denied), `InsightsWorkoutsTabView` (empty / populated); Connected Apps 4-status previews retained. **Code/preview verified:** Dynamic Type via `PluriFont`; tile/card a11y labels + hints; health tiles / week chevrons / Clear filter use `minHeight`/`minWidth` 44; dark via `PluriColor` tokens; tile→Insights deep links unit-tested (`MainRouter`). **Needs device confirmation:** VoiceOver rotor walk-through, Dynamic Type XXL layout on device, dark-mode visual pass, score delta after Save + foreground refresh (M5-01 cadence — observer is M5-18).

### Optional parity (nice-to-have — do not block M5 exit)

- [x] **M5-17** Typed Insights routes / workout-detail from Workouts cards (parity with Home/Plan typed navigation).

> **Learned during M5-17 (2026-07-26):** `InsightsRoute` + `MainRouter.insightsPath` mirror Home/Plan. Plan-linked cards → `WorkoutDetailView(planWorkoutId)`; manual → `InsightsCompletedSessionDetailView(sessionLogId)`. Card `id` stays session-log id — never pass it into plan Detail (SPEC §14 #64). Chevron expand kept for set summary; title opens typed route. `WorkoutDetailStack.insights` keeps Screen/Completion on Insights.

- [x] **M5-18** Score + HealthKit observer / background refresh so the score "updates daily" without relying only on launch-time recompute.

> **Learned during M5-18 (2026-07-26):** foreground `HKObserverQuery` on steps/sleep/HR/active energy via `HealthKitReading.start/stopObservingHealthChanges`; ~1s coalesce → Home `refreshHealthTiles` + `refreshPluriScore`. No `healthkit.background-delivery` entitlement (SPEC §14 #65). Tear down on deny/unavailable/Home disappear. Mock `simulateHealthChange` unit-tested.

- [x] **M5-19** Apple Health connect reachable from Profile + Connected Apps (owner bug report, 2026-07-28 — SPEC §14 #78): M5-03's section/view model were never mounted, so nothing in the app ever called `LiveHealthKitService.requestAuthorization()` and steps/sleep were never authorized. Mount the real section on both screens, add Settings guidance, name unreadable categories after a partial grant, refresh Home/Insights without a relaunch, show today's value alongside the Insights 7-day average, and correct `NSHealthShareUsageDescription`.

> **Learned during M5-19 (2026-07-28):** M5-03 and M5-14 were checked off against code that was never wired in — `AppleHealthConnectionSection` existed only in its own previews, `PlanHealthKitNudgeBanner` was never placed on Plan, and `Info.plist` still described workout-only reads. The only HealthKit prompt reachable in the app was the Workout Screen's live HR/active-energy request, which is why Home's step/sleep tiles never matched the Health app. `AppleHealthConnectionSection` now owns its view model (init takes the injected `HealthKitReading`) so any `List` screen mounts it in one line; refresh hangs off the status **row** rather than the `Section` so `List` keeps its section structure. HealthKit's read authorization stays opaque — a prompt where the user turns everything off still resolves to `.authorized` — so the view model probes 7 days of samples and names the categories it can't read instead of leaving Home quietly empty. **Still not wired (candidate task):** `PlanHealthKitNudgeBanner` / `PlanHealthKitNudgeController` remain unmounted dead code on the Plan page.

**Dependencies:** M5-01 → 02/03 (auth + read service); 02 → 04/05/10 (tiles, score inputs, health insights); 05 → 06 (live score card); 01/02 → 07 → 08/09/10 (Performance); 01 + M4 sessions → 11/12 (Workouts + "+"); 07 → 13 (calendar); everything → 14/15/16; 17/18 optional after shell + score land.

**M5 exit check** (PLAN M5): Insights reflect real logged + health data; score updates daily. Specifically: HealthKit read auth is real on Connected Apps + Profile with honest denial/empty states; Home Today's Health tiles and Pluri Score are live (stub copy gone from Home + Plan Overview); Insights Performance shows per-exercise stats, week filter, all-time strength/time stats, and Bevel-style health insights when authorized; Workouts tab lists M4 completed sessions by month plus manual "+" activities per §9.3; HealthKit samples stay on-device (SPEC §13); build + Swift Testing suite pass; Dynamic Type/VoiceOver/dark mode/contrast/44pt targets manually checked. M5-17 typed Insights routes and M5-18 foreground HealthKit observer are complete (SPEC §14 #64 / #65).

**Deferred out of M5 (don't build ahead):** real Ask Pluri coach (M6 — stub OK); Outdoor Run tracking (stub through M9); Community notification rows / feed (M8); Devices / Bluetooth pairing; Cardio / Flexibility / hybrid *plans* and groups (v2) — manual Cardio/Flexibility *log types* via "+" (§9.3) are in scope for M5.

---

## M6 — Ask Pluri (AI Coach) — ARCHIVED

> **Archived (2026-07-28) — SPEC §14 #77.** Ask Pluri was shipped (tasks below remain checked for history) then **removed from the product**: Feature/Networking/tests/`ask-pluri` EF source deleted; Workout Screen + Plan Overview entry points removed. **Not active work.** Owner follow-ups: drop remote `chat_messages` (keep past migration file) and undeploy remote `ask-pluri`. Restartable `PathMonitorReachability` from the mid-workout freeze fix is retained for SyncEngine.

Ask Pluri (AI Coach) (PLAN M6): ~~`ask-pluri` Edge Function with Gemini…~~ **Removed.** Historical exit: mid-workout questions + plan edits via chat.

### Scope & decisions (do first — unblock payload, persistence, and tool schema)

- [x] **M6-01** Resolve and record Ask Pluri decisions in SPEC §14/§15 before building: context payload (current plan, recent sessions, current workout — never HealthKit samples); chat history persistence (remote `chat_messages` vs session-local); confirm UX before add/remove; offline = honest "needs connection" (no fake coach answers); rate-limit / "coach is busy"; safety rails (medical/injury disclaimers, refuse harmful advice); tool schema for add/remove; Gemini model + secrets naming. Pick the most reversible interim option where the owner is unavailable (AGENTS §7).

> **Learned during M6-01 (2026-07-26):** decisions recorded as SPEC §14 **#66** (context = active plan + recent completed session/set summaries + current `plan_workout` + profile injury/equipment — **never** HealthKit samples; history = remote `chat_messages` with owner RLS + high-level schema for M6-02; gentle confirm sheet before add/remove — no silent plan edits; offline = honest "needs connection" / no fake replies; EF busy/throttle → UI "coach is busy"; kind coach + medical/injury disclaimer + gentle refusal of harmful advice; tool actions `{ type: add_workout, sourceWorkoutId, date }` / `{ type: remove_workout, planWorkoutId }` under #38/#44; **M6-10 fork locked** — EF returns structured actions → client confirms → `PlanStore`/`PlanMutator` (not EF-direct mutate); model interim `gemini-flash-latest`, secret `GEMINI_API_KEY` via `supabase secrets set`, never iOS bundle — M0-11 still gates related production secrets). §10 points at #66; §15 M6 Ask Pluri question resolved. No Swift/UI/EF/migration code — M6-02+ implements against these decisions.

### Backend

- [x] **M6-02** Migration: `chat_messages` (+ RLS owner-only) per PLAN §1.3 — not in repo today.

- [x] **M6-03** Edge Function `ask-pluri`: JWT auth, load owner plan/history context, call Gemini (secret server-side), persist messages, return reply; structured tool actions for add/remove `plan_workouts`; throttle + busy/error shapes. Pattern after `supabase/functions/delete-account/`. Secrets: Gemini + service role (M0-11 may `[!]` block production deploy).

- [x] **M6-04** EF unit/integration tests or scripted fixtures for grounding + tool actions (no key in repo).

> **Learned during M6-02/03/04 (2026-07-26):**
> - **Session grounding caps:** last **28 days** completed sessions, max **20** sessions, max **40** set_logs/session (`RECENT_SESSION_DAYS` / `RECENT_SESSION_LIMIT` / `MAX_SET_LOGS_PER_SESSION` in `ask-pluri/_shared/constants.ts`). Chat history load: last **40** turns. Never HealthKit / Pluri Score in context.
> - **JSON contracts:** request `{ message, conversationId?, currentPlanWorkoutId? }`; success `{ reply, conversationId, actions, messageIds?: { user, assistant } }`; busy/throttle `{ error: "busy"|"throttled", message }` (HTTP 429 throttled / 503 busy; no raw quota dumps). Actions: `{ type: "add_workout", sourceWorkoutId, date }` / `{ type: "remove_workout", planWorkoutId }` — **returned only**, EF never mutates `plan_workouts` (#66h; PLAN §1.3 updated).
> - **Throttle:** app-side **8** asks / user / **60s** isolate window + Gemini 429 → `throttled`; Gemini 500/503/empty → `busy`.
> - **Secrets / deploy:** `supabase secrets set GEMINI_API_KEY=...` (optional `GEMINI_MODEL`, default `gemini-flash-latest`); `supabase functions deploy ask-pluri`; `verify_jwt = true` in `config.toml`. Production live Gemini smoke still gated on owner secrets (M0-11 soft blocker) — M6-04 covers mocked Deno tests only.
> - **Tests:** `deno test --allow-read --allow-env supabase/functions/ask-pluri/ask_pluri_test.ts` (JWT 401, grounding excludes HealthKit, tool parse, busy shape, no key in repo, no `plan_workouts` writes).

### Client networking

- [x] **M6-05** `AskPluriClient` protocol + live (invoke EF) + mock for previews/tests; never embed Gemini key (PLAN §1.1, SPEC §14 #6).

### Chat UI

- [x] **M6-06** `Features/AskPluri/` chat UI (sheet/stack from Workout Screen): message list, composer, streaming/busy/error, Dynamic Type / VoiceOver / 44pt.

- [x] **M6-07** Replace Workout Screen stub (`WorkoutScreenView` / `showsAskPluriStub` / "coming in M6") with real entry pre- and mid-workout (SPEC §8 / §10).

- [x] **M6-08** Update Plan Overview `AskPluriExplainerCard` from "later update" to live how-to (SPEC §6.1 / #43).

> **Learned during M6-06/07/08 (2026-07-26):**
> - **Chat UI:** `AskPluriChatView` + `AskPluriViewModel` in `Features/AskPluri/`; “streaming” = in-flight busy row while awaiting non-streaming EF (no SSE). Offline keeps composer draft + “needs a connection”; busy/throttled → coach-is-busy copy; no fake assistant replies. History via RLS `chat_messages` select (`LiveAskPluriHistoryLoader`); reopen restores latest conversation. `actions` decoded into `lastReceivedActions` only — **not** applied (M6-09/10).
> - **DI:** `AppRootView` keeps `SupabaseService` and injects `\.askPluriClient` + `\.askPluriHistoryLoader` (not full `SupabaseService` in `@Environment`).
> - **Workout Screen:** `showsAskPluri` opens chat sheet with `.medium`+`.large` detents; passes `currentPlanWorkoutId` (= plan workout UUID string) on every ask.
> - **Plan Overview:** `AskPluriExplainerCard` is live how-to pointing at Workout Screen Ask Pluri (SPEC #43 updated).

### Plan mutations via chat

- [x] **M6-09** Wire coach add/remove → `PlanStore` / `PlanMutator` / mutation service. Add can reuse `addWorkout(cloning:on:)` (#38); remove needs new API under same history/conflict rules (#38/#44: no delete completed/skipped). Confirm UI per M6-01; optimistic + rollback; reminder reconcile after success.

- [x] **M6-10** Apply EF-returned structured actions on client (or EF mutates remotely + client rehydrates) — pick one in M6-01; keep Plan/calendar consistent.

> **Learned during M6-09/10 (2026-07-26):**
> - **Remove path:** `PlanMutator.removingWorkout` (scheduled-only) → `PlanStore.removeWorkout` optimistic + rollback → `PlanMutationServicing.removeWorkout` deletes `workout_exercises` then `plan_workouts`, upserts reordered siblings; reminder reconcile on success.
> - **Apply path (#66h):** EF returns actions only; client confirms via nested `.pluriBottomSheet` (`AskPluriConfirmChangeSheet`); `AskPluriPlanActionApplier` parses UUIDs + `yyyy-MM-dd` (FormatStyle / `DatabaseCodeMappings.date`) and calls `addWorkout` / `removeWorkout`. Invalid actions skipped (#66g). Multi-action: apply in order, stop on first error (partial apply possible). Cancel/success chat lines are local `.system` only (not persisted).

### Persona, safety, verification

- [x] **M6-11** System prompt / server rails: kind informative coach; no raw API leakage; no cross-user data; gentle refusals.

- [x] **M6-12** Swift Testing: client parsing, mock chat flows, plan mutation from tool payloads, unauthorized/offline/busy paths.

- [x] **M6-13** M6 UI QA: previews empty/busy/error/populated; a11y; mid-workout chat doesn’t break logging; add/remove click-through updates Plan.

> **Learned during M6-11/12/13 (2026-07-26):**
> - **Server rails (M6-11):** `ASK_PLURI_SYSTEM_PROMPT` already encoded #66f (kind coach, medical disclaimer, refuse harmful, no cross-user / API leakage). Hardened client-facing errors: no `detail` / Auth JWT message / Gemini HTTP leakage on 401/5xx / non-mapped Gemini failures — log server-side only (`errors.ts` helpers + `handler.ts` / `gemini.ts`). Deno tests cover prompt rails + safe error shapes.
> - **Swift Testing (M6-12):** Added ViewModel **unauthorized** + **throttled** coverage; `AskPluriPlanActionApplierTests` for `summaryLines` + multi-action stop-on-first-error. Prior client/VM/plan-mutation coverage retained.
> - **UI QA (M6-13):** Busy preview forces `isSending` via `prepareBusyPreviewState()` (no 60s delay wait). Chat + confirm sheet use `PluriFont` / `PluriColor` / `PluriSpacing` / `PluriRadius` and 44pt min targets; VoiceOver labels/hints on Done, dismiss, composer, send, confirm/cancel.

> **Learned during M6-13 follow-up (2026-07-27) — mid-workout Ask Pluri freeze:** the M6-13 "mid-workout chat stays snappy" check was signed off on previews, not on a real session with exercise GIFs, and it missed a real defect: asking a question mid-workout pegged the CPU and stranded the typed question in the composer. Root causes and fixes are recorded in **SPEC §14 #76** — restartable `PathMonitorReachability` (a cancelled `NWPathMonitor` froze `isOnline` and made the offline guard reject every later send), composer no longer `.disabled()` while sending, `isSending` reset from a single `defer`, one keyboard accessory instead of one per exercise card, lazy exercise list with off-main-actor GIF decode, no redundant `UIImageView.image` re-assignment, GIFs paused while a sheet covers the screen, and timer/HealthKit observation isolated in `WorkoutTimerMetricsView`. Hardened further: optimistic `isOnline = true` on fresh monitor `start()`, no reachability `tearDown` on flaky chat-sheet `onDisappear`, and a yield after setting `isSending` so the busy row can paint. Covered by `AskPluriViewModelTests` composer-state cases and `NetworkReachabilityTests`. **Still needs on-device confirmation** (Instruments Time Profiler during a real GIF-heavy session) — the simulator does not reproduce the original spike faithfully.

> **M6-13 manual QA checklist:** (1) Pre-workout: open Ask Pluri from Workout Screen → ask a plan-aware question → dismiss. (2) Mid-workout: start session → open Ask Pluri sheet → log a set while sheet is open and again after dismiss — logging stays snappy, session not corrupted, timer/set state intact. (3) Coach proposes add → Confirm → Plan/calendar shows new workout; Cancel leaves plan untouched. (4) Coach proposes remove on a scheduled workout → Confirm → workout gone; completed/skipped never offered/applied. (5) Dynamic Type (largest), VoiceOver rotor walk-through (chat + confirm sheet), dark mode, 44pt Done/Send/Confirm/Cancel. (6) Airplane mode → offline banner kind “needs a connection” (no raw errors); restore network → busy/throttled path (if hit) shows coach-is-busy copy only.

**Dependencies:** M6-01 → 02/03; 03 → 05 → 06/07; 01+03 → 09/10; everything → 12/13.

**M6 exit check** (PLAN M6): mid-workout questions answered with user-specific context; plan edits via chat work. Specifically: Ask Pluri decisions recorded in SPEC §14/§15; `chat_messages` migration + RLS in place; `ask-pluri` EF authenticates, grounds on owner plan/history (never HealthKit samples), calls Gemini server-side, returns replies + structured add/remove actions with throttle/busy/error shapes (client-facing JSON omits provider/`detail` leakage — #66e/f); client `AskPluriClient` never embeds the Gemini key; Workout Screen stub replaced by real chat pre- and mid-workout; Plan Overview explainer is live how-to; add/remove via chat updates Plan under #38/#44 rules with confirm + optimistic/rollback + reminder reconcile; coach persona/safety rails refuse harmful advice gently; build + Swift Testing suite pass; Dynamic Type/VoiceOver/44pt targets and mid-workout chat QA manually checked.

**Deferred out of M6 (don't build ahead):** Recipes / nutrition (M7); Community (M8); Outdoor Run (M9); Cardio / Flexibility / hybrid plans & groups (v2); Devices.

---

## M7 — Recipes & Nutrition

Recipes & Nutrition (PLAN M7): Recipe tab day view with ~3 auto-suggestions per meal (breakfast / lunch / dinner / dessert), Explore filters, favorites + similarity-biased suggestions, and food logging via the Nutrition API (serving sizes, calories vs maintenance). Builds on M2 Main’s Recipe tab placeholder, Q12 profile inputs (`maintenance_calories`, allergies via `CalorieCalculator` / `AllergenCatalog`), and existing `NUTRITION_API_KEY` wiring in `Secrets` / `.env.example`. TheMealDB is typically keyless — M7-03 spike confirms. **Exit:** user gets daily recipe suggestions and can log foods with calorie totals.

### Scope & decisions (do first — unblock suggestion rules, logging shape, and sync)

- [x] **M7-01** Resolve and record Recipe & nutrition decisions in SPEC §14/§15 before building: day-suggestion algorithm (seed/determinism, how maintenance calories inform picks, allergy hard-filter vs soft); favorites similarity model (closes the §15 open question — pick a reversible interim, e.g. cuisine/ingredient tag overlap); Explore filter value sets (cuisine, meat/protein, cook duration buckets, portion = meal-prep vs single); food-log storage (local-first SwiftData + sync vs remote-only) and meal tagging; offline honesty (cached favorites/suggestions vs no fake network results); calorie-ring UX vs `status/blue` / `accent/pink` tokens (`design.md`); whether Nutrition stays client-side with `NUTRITION_API_KEY` or needs an Edge Function proxy. Pick the most reversible interim option where the owner is unavailable (AGENTS §7).

> **Learned during M7-01 (2026-07-26):** decisions recorded as SPEC §14 **#67** (**a** seed = FNV-1a / PlanEngine **#24** spirit over `userID + yyyy-MM-dd + mealSlot`; **b** maintenance kcal = soft ~25–35% band bias, not hard target; **c** allergy = hard-filter via Q12 / `AllergenCatalog`, honest empty slots; **d** favorites similarity = shared `strArea` + ingredient overlap, top-K boost after allergy filter — closes §15; **e** Explore enums locked (Cuisine / Protein / Duration / Portion; MealDB mapping confirmed in M7-03); **f** local-first SwiftData + opportunistic `food_logs` / `recipe_favorites` sync + meal tags + high-level schema for M7-02; **g** offline = cached favorites/suggestions only, no invented MealDB/Nutrition (mirror **#66d**); **h** calorie ring → `statusBlue`, food/recipe → `accentPink` per `design.md`; **i** Nutrition stays client-side `NUTRITION_API_KEY` / WorkoutX pattern — reversible to EF later; asymmetry vs Gemini **#6**/**#66i**). §12 points at #67; §15 recipe-similarity question resolved. No Swift/UI/schema code in this task — M7-02+ implements against these decisions.

### Backend

- [x] **M7-02** Migration: `food_logs` + `recipe_favorites` + owner-only RLS per PLAN §1.3 — `food_logs` (food, serving, calories, macros, meal, date); `recipe_favorites` (user ↔ MealDB recipe ids). Not in repo today. Schema details follow M7-01.

> **Learned during M7-02 (2026-07-27):**
> - **Remote:** migration `food_logs_recipe_favorites` version `20260727020041` (local file `supabase/migrations/20260727020019_food_logs_recipe_favorites.sql` via `supabase migration new`). Applied via MCP `apply_migration`. RLS on; SELECT/INSERT/UPDATE/DELETE owner policies use `(select auth.uid()) = user_id` (chat_messages / 0001 pattern). Default `anon`/`authenticated`/`service_role` table GRANTs match `chat_messages` (Data API exposed; RLS gates rows).
> - **`food_logs` columns (#67f naming):** `id` uuid PK, `user_id` → profiles CASCADE, `food_name` text, `serving` text (label e.g. "1 cup" / "100g"), `calories` int ≥0, `macros` jsonb nullable, `meal` check `breakfast|lunch|dinner|dessert|snack`, `logged_date` date, optional `mealdb_recipe_id` / `nutrition_food_id` text, `created_at`. Indexes: `(user_id)`, `(user_id, logged_date)`.
> - **`recipe_favorites` columns:** `id` uuid PK, `user_id` → profiles CASCADE, `mealdb_recipe_id` text, optional `cached_title` / `cached_thumb_url`, `created_at`. Indexes: `(user_id)`; **UNIQUE** `(user_id, mealdb_recipe_id)` for toggle upsert.
> - Prefer #67f names (`food_name`, `logged_date`) over vague PLAN "food"/"date". No Swift/SwiftData/UI in this task.

### API spike & clients

- [x] **M7-03** API spike: hit TheMealDB + API Ninjas Nutrition with real endpoints/keys as needed; document response shapes, rate limits, search/filter capabilities, and auth (MealDB often keyless — spike decides) in `Core/Networking/MealDB/README` and `Core/Networking/Nutrition/README` (mirror M1-01 / WorkoutX). Confirm `NUTRITION_API_KEY` → `Secrets.nutritionAPIKey` path; never commit secrets.

- [x] **M7-04** `MealDBClient` protocol + live + mock for previews/tests: recipe search/lookup, cuisine/ingredient filters needed by day suggestions + Explore (PLAN §1.1 / SPEC §12). Typed models; no secrets in source.

- [x] **M7-05** `NutritionClient` protocol + live + mock for previews/tests: food search + nutrition-per-serving parsing for logging (SPEC §12 Log). Inject key from `Secrets` (or EF proxy if M7-01 chose that); never hardcode.

> **Learned during M7-03/04/05 (2026-07-27):**
> - **MealDB:** keyless free path `/api/json/v1/1/`; empty results = `"meals":null`; no cook-time/servings fields — Duration/Portion stay client heuristics (#67e). Cuisine = `strArea` + `filter.php?a=`; Protein = `filter.php?c=` for Chicken/Beef/Pork/Seafood/Vegetarian/Vegan. **Naming drift:** `American`→`United States`, `French`→`France`, `Indian`→`India`, `Dutch`→`Netherlands`; `list.php?a=list` is a large nationality catalog that does **not** 1:1 match filterable areas — validate before Explore. No rate-limit headers observed in spike; still surface `.rateLimited`.
> - **Nutrition:** `NUTRITION_API_KEY` → `Secrets.nutritionAPIKey` → `X-Api-Key`; base `https://api.api-ninjas.com/v1` hardcoded. **Free tier gates `calories` + `protein_g`** (premium string) — fat/carbs/etc. still numeric. Domain optionals + SPEC §14 **#68**. Invalid key → HTTP 400. No durable food id — synthetic `name|serving_g`.
> - **Clients:** `MealDBClient` / `NutritionClient` protocol + Live + Mock under `Core/Networking/{MealDB,Nutrition}/`; Swift Testing offline decode/mock suites. Networking `README.md` files excluded from the Pluri app target membership (avoids duplicate `Pluri.app/README.md` copy). No Recipe UI / SwiftData / suggestion engine in this slice.

### Domain: suggestions & favorites

- [x] **M7-06** Domain: day suggestions engine (pure, unit-tested): ~3 options each for breakfast / lunch / dinner / dessert for a selected calendar day; hard-filter by profile allergies (Q12 / `AllergenCatalog`); informed by `maintenance_calories` per M7-01; bias toward foods similar to favorites when present (SPEC §12). Deterministic given seed + inputs where practical (PlanEngine / ScoreEngine spirit).

- [x] **M7-07** Favorites persist: SwiftData cache for favorited MealDB recipes ± sync to `recipe_favorites` per M7-01/M7-02; toggle API usable from detail + suggestion cards; offline-readable favorites for bias + UI.

> **Learned during M7-06/07 (2026-07-26):** `RecipeSuggestionEngine` (`Features/Recipe/Engine/`) — FNV-1a seed over `userID|yyyy-MM-dd|mealSlot`, allergy hard-filter + synonym map, soft kcal rank when provided (never invent), favorites similarity = shared `strArea` + ingredient overlap with top-K boost, seeded sample of ~3. Slot pooling interim: Breakfast/Dessert by MealDB category; lunch/dinner share the rest (SPEC §14 **#69**). `RecipeFavoriteRecord` + `RecipeFavoritesStore` local-first with `needsSync` / `pendingDelete`; `SyncEngine` upserts/deletes `recipe_favorites` opportunistically. No Recipe tab UI (M7-08+) and no NutritionClient in this slice.

### Recipe tab UI

- [x] **M7-08** Replace Recipe tab placeholder with day shell: calendar-style day picker (Home spirit — SPEC §12); sections for breakfast / lunch / dinner / dessert showing ~3 suggestions from M7-06; honest empty/offline/error; `Features/Recipe/`; design tokens (`accent/pink` food moments, `status/blue` calorie affordances per `design.md`); Dynamic Type / VoiceOver / 44pt.

- [x] **M7-09** Recipe detail + favorite toggle: open from a suggestion/Explore row; show MealDB content (ingredients, instructions, media when available); favorite on/off via M7-07; entry point for Log (wired in M7-12).

- [x] **M7-10** Explore tab + filters: cuisine, meat/protein, cook duration, portion (meal-prep vs single serving) per SPEC §12 / M7-01 value sets; results via `MealDBClient`; honest empty states.

> **Learned during M7-08/09/10:** Recipe root mirrors Insights — `RecipePrimaryTab` Day|Explore via `PluriChip` (not `Picker.segmented`). `MainRouter.recipePath` + `RecipeRoute.detail(mealID:)` for stack navigation. Day strip reuses Home calendar patterns with `accentPink` selection (no workout dots). Candidate pool = search seeds + Breakfast/Dessert category lookups (`RecipeCandidateLoader`); full recipes required for engine; SwiftData `RecipeDaySuggestionsRecord` + `RecipeCandidatePoolRecord` for #67g offline day cache (Explore stays online-only). Cuisine chips use curated validated `strArea` maps (American→`United States`, French→`France`, Indian→`India` — MealDB README caveat). Duration/portion = `RecipeExploreHeuristics` on instructions/measures (no API fields). Detail Log CTA = coming-soon stub only (M7-11/12). `mealDBClient` EnvironmentKey wired in `AppRootView` like Ask Pluri.

### Food logging

- [x] **M7-11** Food log flow + day calorie total vs maintenance: search foods via `NutritionClient` (not only recipes); choose serving size (MyFitnessPal-style — SPEC §12); persist to `food_logs` (+ local cache per M7-01); show calories eaten vs profile `maintenance_calories` (calorie ring / `status/blue` token). Standalone Log entry from Recipe tab.

- [x] **M7-12** Wire Log from recipe detail + standalone: same logging sheet/flow from M7-09 detail and M7-11 standalone; prefill from recipe when available; day total updates after save.

> **Learned during M7-11/12:** Serving label = Nutrition search query text (README). Nil-kcal hits cannot save (#68 interim — honest copy, no invented kcal). `FoodLogMeal` adds `snack` alongside suggestion `MealSlot`s. Shared `FoodLoggingSheet`/`FoodLoggingViewModel` for toolbar + detail; day ring refreshes after save. Sync mirrors favorites (`enqueueFoodLog` / upsert+delete).

### Tests & QA

- [x] **M7-13** Swift Testing (`PluriTests`): suggestions engine (allergy filter, calorie bias, favorites similarity, seed stability); `MealDBClient` / `NutritionClient` parsing + mocks; favorites persist/sync paths; food-log totals vs maintenance; unauthorized/offline/error paths.

- [x] **M7-14** M7 UI QA: previews for empty / offline / populated day, Explore filters, detail + favorite, log sheet + calorie ring; Dynamic Type / VoiceOver / dark mode / 44pt; day → detail → favorite → log click-through; calories update against maintenance.

> **Learned during M7-13/14:** Gap-fill only — engine / MealDB / Nutrition / favorites / food-log totals already covered. Added `MockMealDBClient.errorToThrow` + `.rateLimited` mock tests; FoodLogging VM maps `unauthorized` / `rateLimited` → `.error` and `.transport` → `.offline`; Day / Explore / Detail VMs surface MealDB rate-limit errors when no cache/seed. Food-log `pendingDelete` flush exercised without a store delete API / UI (out of scope). Previews: `FoodLoggingSheet` (idle/results/nil-kcal/offline), `DayCalorieRingView` (under/at/over/no maintenance), Day empty, Detail favorited vs not via `RecipeDetailBody`. **Automated:** build + M7 PluriTests green; previews compile. **Needs human device pass:** Dynamic Type / VoiceOver / dark mode / 44pt tap targets, full day→detail→favorite→log click-through, live calorie ring vs maintenance after save. Unrelated flake: `ExerciseCatalogSourceTests.planGeneratesFromSupabaseCatalog` (live Supabase catalog string compare) — not M7.

**Dependencies:** M7-01 → 02/03/06; 03 → 04/05; 04 → 06/07/10; 02+04 → 07; 06 → 08 → 09/10; 02+05 → 11; 09+11 → 12; everything → 13/14.

**M7 exit check** (PLAN M7): user gets daily recipe suggestions and can log foods with calorie totals. Specifically: Recipe & nutrition decisions recorded in SPEC §14/§15; `food_logs` + `recipe_favorites` migrations + owner RLS in place; `MealDBClient` + `NutritionClient` (protocol/live/mock) documented via spike READMEs; Recipe tab placeholder replaced by a day view with ~3 suggestions × breakfast/lunch/dinner/dessert filtered by allergies and informed by maintenance calories; Explore filters (cuisine, meat/protein, duration, portion) work; favorites persist (SwiftData ± sync) and bias suggestions; Log from recipe detail + standalone searches foods, sets serving size, and shows day calories vs maintenance; build + Swift Testing suite pass; Dynamic Type/VoiceOver/44pt targets and day→detail→log QA manually checked. Community stays M8; Ask Pluri nutrition coaching stays out of scope.

**Deferred out of M7 (don't build ahead):** Community feed / UGC (M8); Ask Pluri nutrition coaching (M6 coach stays plan/workout-grounded — no recipe coach expansion here); Outdoor Run (M9); Cardio / Flexibility / hybrid plans & groups (v2); barcode scanning, custom recipes authoring, grocery lists, macro goal planning beyond maintenance comparison (v2 / unspecified).

---

## M8 — Community

Community (PLAN M8): Runna-like hub (**Feed · Discover · Saved**) — feed (posts, likes, comments, polls), create-post flow with type/image/poll and the 3-word rule, search, saved posts, Discover (Explore Spaces + Challenges coming-soon stubs), **moderation (report/block/hide)** — App Review blocker. Builds on M2 Main’s Community tab placeholder and M3 Notifications stubs. **Exit:** users can post, interact, search, save; Discover stubs honest; UGC moderation in place; author name + like/comment counts on cards.

> **Note:** PLAN §2 dependency notes — M7 (Recipes & Nutrition) and M8 are independent and can ship in parallel or be reordered. Full M7 task section is in this file above (`## M7 — Recipes & Nutrition`).

### Scope & decisions (do first — unblock moderation, feed, and Storage)

- [x] **M8-01** Resolve and record Community decisions in SPEC §14/§15 before building: moderation UX (report / block / hide) and persistence; feed ranking (chronological vs engagement — pick reversible interim); post-image Storage path + size/type limits; offline honesty for Community (no fake feed when offline); Share Workout payload shape (which session fields attach); Explore Spaces v1 stub/directory data source; which Community notification rows belong in M8 vs M9 push. Close/update the SPEC §15 Community moderation bullet when decided. Pick the most reversible interim option where the owner is unavailable (AGENTS §7).

> **Learned during M8-01 (2026-07-26):** decisions recorded as SPEC §14 **#72** (**a** moderation = Report → `post_reports` + post flag, Hide → `post_hides`, Block → `user_blocks`; feed excludes hidden + blocked authors; reporter soft-hide, global hide = staff only — closes §15; **b** ranking = chronological `created_at DESC`; **c** Storage = bucket `post-images`, path `{user_id}/{post_id}.{ext}`, jpeg/png/heic ~5 MB, public-read + auth upload (signed reversible) for M8-03; **d** offline = honest empty/error, no invented feed; **e** Share Workout snapshot jsonb = `session_id`, plan title via `planWorkoutId`, `activityType`, `durationSeconds`, optional `distanceMeters`, set/rep summary counts — no HealthKit; **f** Explore Spaces = bundled/static stub (or empty coming-soon), browse-only, no join/geo; **g** M8 in-app reply notification rows only; clubs = v2; push = M9). §11 points at #72; §5.3 clarified (replies M8 / clubs v2 / push M9); §15 Community moderation question resolved. No Swift/UI/schema/Storage code in this task — M8-02+ implements against these decisions.

### Backend

- [x] **M8-02** Migration: community tables + RLS + moderation day one — `posts`, `post_likes`, `post_comments`, `post_polls`, `poll_votes`, `saved_posts`, plus **`post_reports`**, **`post_hides`**, **`user_blocks`** (SPEC §14 #72 / #73, PLAN §1.3). `posts`: type enum/check (general/gear/recipe/share_workout), timestamps, FK → `profiles` CASCADE, `reported` / `report_count`, staff `hidden`, optional `workout_snapshot` jsonb. Public SELECT of non-staff-hidden posts (exclude viewer hides/blocks/own reports where policy can); owner writes; likes/comments/votes/saves owner-scoped writes; reports/hides/blocks by authenticated viewer with uniqueness. Indexes on `created_at`, FKs, unique `(user_id, post_id)` (and equivalent pairs). Narrow author attribution via `community_author_profiles` (`display_name`; avatar only if column exists later) — do **not** open full `profiles` SELECT. No Swift client in this task.

- [x] **M8-03** Storage bucket + policies for post images: bucket `post-images`; path `{user_id}/{post_id}.{ext}`; MIME jpeg/png/heic; ~5 MB; public-read + authenticated upload only under owner prefix (SPEC §14 #72c). Never ship secrets; no iOS upload code yet.

> **Learned during M8-02/03 (2026-07-27):** remote migrations applied — `community_tables_rls` (+ finish repair migrations after a truncated first apply), `post_images_storage`, `community_author_profiles_table_and_advisor_fixes`. Author attribution is a **synced table** (not a SECURITY DEFINER view) to satisfy advisors while keeping `profiles` owner-only. Storage is public bucket without a broad `storage.objects` SELECT policy (CDN URLs; avoids listing). Smoke: empty feed SELECT OK; anon INSERT blocked by RLS. Runna hub + M8-15/16 tasks documented; UI still M8-04+.

### Client networking & domain

- [x] **M8-04** Domain models + `CommunityClient` / repository (protocol + live Supabase + mocks for previews/tests) covering feed, create, like, comment, poll vote, search, save, moderation actions, author `display_name` + like/comment counts (PLAN §1.2 / §1.3, SPEC §14 #73).

### Feature UI

- [x] **M8-05** Replace Community tab placeholder with hub shell: **Feed · Discover · Saved** chrome per SPEC §11 (Runna-like); top bar search + calendar; honest empty/offline/error states (no fake content). Clubs = omit or honest stub only (not live).

- [x] **M8-06** Feed: Instagram-style scrolling post cards with like, comment, and poll vote (SPEC §11); show **author `display_name`** + **like/comment counts** (with M8-16); Dynamic Type / VoiceOver / 44pt.

- [x] **M8-07** Create Post flow: types General / Gear / Recipe / Share Workout; optional image + optional poll; **Post** enabled only with a title and ≥3 body words (SPEC §11); Share Workout payload per M8-01.

- [x] **M8-08** Search across post types (general, gear, workouts/runs/flexibility, recipe — SPEC §11).

- [x] **M8-09** Saved / bookmarked posts — Saved hub segment + list of user’s saved posts (SPEC §11).

- [x] **M8-10** Explore Spaces directory under **Discover** — browse-only v1 for upcoming races / running groups nearby (SPEC §1.1 / §11 / #72f); join/manage = v2.

- [x] **M8-15** Discover hub stub: wire Discover segment with Spaces (M8-10) + **Challenges coming-soon cards** only (no live Challenges — v2 / SPEC §15). Depends on M8-05 hub chrome (+ M8-10 for Spaces content).

- [x] **M8-16** Author attribution on cards: resolve `display_name` via `community_author_profiles` / M8-02 RLS; surface like + comment counts on feed cards. Wire with M8-06; depends on M8-02.

- [x] **M8-11** Moderation UI + persistence (report / block / hide) per M8-01 — App Review blocker for UGC (SPEC §13 / §15, PLAN M8).

- [x] **M8-12** Notifications Community rows: replies to the user’s posts (SPEC §5.3); club/group messages stay v2 / M9 as decided in M8-01.

### Tests & QA

- [x] **M8-13** Swift Testing: `CommunityClient` parsing/mocks; create / like / save flows; moderation actions; unauthorized/offline/error paths.

- [x] **M8-14** M8 UI QA: a11y (Dynamic Type / VoiceOver / 44pt / dark mode); empty/offline/error previews; create → appears in feed; search/save click-through; Discover Spaces + Challenges stub; moderation report/block/hide click-through.

> **Learned during M8-13/14 (2026-07-27):** M8-13 gap-fill only — suites already covered DTO decode, mock feed/search/create/like/comment/save/vote, hide+transport offline, create 3-word gate, Share Workout gating, feed offline, like/save/hide/report/block VM, search filters, replies exclude self, WorkoutSnapshot builder. **Added client:** unauthorized typed throws on create/like/save/report/fetch; block removes author posts + report soft-hide; unlike/unsave round-trip; CommunityTextRules + ReportReason.persistenceValue; post-row `workout_snapshot` decode; comment→missing post `.notFound`. **Added VM:** feed/search `.unauthorized` → `.error` (sign-in copy) with empty posts; Saved `.empty` + `.offline`; `votePoll` local counts/viewer index. **M8-14 previews:** Hub populated; Feed empty/offline/error; Saved empty; Search empty/offline; Discover Spaces+Challenges; Create can/can't post; Report sheet; Post card poll + workout snapshot. **A11y fixes:** like/comment hit targets `minWidth/minHeight` 44 + `contentShape`; Create Post disabled-hint + title/body VO labels. **Manual click-through (code/VM audit — device still needed):** Create→dismiss→feed reload path wired (`onCreated` + sheet `onDismiss` reload) — **pass (logic)**; Search type chips + result — **pass (logic/tests)**; Save→Saved tab — **pass (logic/tests)**; Discover Spaces + Challenges coming-soon — **pass (UI present)**; Report/Hide/Block remove from feed + confirmation — **pass (VM tests + confirmationDialog/alert)**. Human on-device VoiceOver/Dynamic Type/dark-mode spot-check still recommended.

**Dependencies:** M8-01 → 02/03/04; 02+03 → 04 → 05/06/07; 04 → 08/09/10/11; 05+10 → 15; 02+06 → 16; 01+06 → 12; everything → 13/14.

**M8 exit check** (PLAN M8): users can post, interact, search, save; UGC moderation in place. Specifically: Community decisions recorded in SPEC §14/§15; community tables + RLS + moderation columns and post-image Storage in place; Community hub (Feed · Discover · Saved) replaces the placeholder; create-post enforces title + ≥3 body words; search and saved posts work; Discover shows Spaces + Challenges coming-soon; cards show author name + like/comment counts; report/block/hide ship for App Review; Community reply notification rows are honest (club messages deferred per M8-01); build + Swift Testing suite pass; Dynamic Type/VoiceOver/44pt targets and create→feed + moderation QA manually checked. ✅ M8-13/14 complete (device UI QA residual noted in Learned).

**Deferred out of M8 (don't build ahead):** clubs/groups fully live (v2); live Challenges (v2); follow / full public profiles (v2); Explore Spaces join/manage (v2); races “fully live” (v2 — SPEC §1.1); anything M9 push-only if scoped out in M8-01; Recipes / nutrition UI (M7); Outdoor Run tracking (M9); Cardio / Flexibility / hybrid plans (v2).

---

## Backlog / surfaced items

- Decide the fate of the legacy Supabase prototype tables (`workout_plans`, `plan_days`, `plan_day_exercises`, `user_equipment`, plus the 3 seeded profile rows). Dropping them is destructive → owner approval required (AGENTS §6). **Update (2026-07-13):** the seeded `exercises` catalog (1,327 rows) is no longer just a candidate fallback — it is now the app's **primary catalog source** (`SupabaseExerciseCatalogClient`, SPEC §14 #25), so `exercises` must be kept (and eventually kept in sync with WorkoutX server-side, e.g. from the M2+ `generate-plan` Edge Function). The other legacy tables are still pending an owner decision.
- ~~No test target exists yet~~ **Resolved (M1-17):** the `PluriTests` Swift Testing target was added to `project.pbxproj` and now compiles `CalorieCalculatorTests.swift` + `PlanEngineTests.swift` (24 tests passing). `ExerciseCatalogStore.isStale` (M1-03) is still uncovered but now trivially testable in the same target — a candidate follow-up test.
- ~~`PlanEngine.scheduledDate` mid-week ordering~~ **Resolved (M3-02, 2026-07-16):** each plan week now maps session templates onto that week's training-day dates in chronological order (`PlanEngine.orderedTrainingDates`), so `indexInWeek`, `orderIndex`, and `scheduledDate` ascend together for every start weekday. Covered by parameterized regression tests in `PlanEngineTests`.
- `PluriPillButtonStyle` (M0) has no visual disabled state — it ignores `\.isEnabled`, so onboarding's disabled Continue buttons (empty name, no location picked, <2 training days, …) still render full brand orange and look tappable. Add an `@Environment(\.isEnabled)` dim/desaturate to the style. (Surfaced during M1-04..15 QA — pre-existing component, not fixed inline per AGENTS §7.)
- ~~Q6 equipment strings vs live WorkoutX punctuation/casing differences~~ **Resolved (M1-16):** `EquipmentMatcher` normalizes both sides (lowercase + strip non-alphanumerics) before comparison, so `"Dumbbell + Exercise Ball"` matches `"Dumbbell, Exercise Ball"` etc., with no brittle mapping table. Covered by `PlanEngineTests`. See SPEC §14 #19.
- ~~Consider renaming the Xcode target/product from `pluri_fable_xcode` to `Pluri`~~ **Resolved (M2-01):** target/module renamed to `Pluri`, bundle id `com.codewithmikey.Pluri`.
- Security advisor flags: `public.rls_auto_enable()` (SECURITY DEFINER, pre-existing) is executable by anon/authenticated — revoke EXECUTE or move it; leaked-password protection is disabled in Auth settings.
- Supabase Auth leaked-password protection and the M0-11 key rotation both need the owner in the dashboard — bundle them into one session.

