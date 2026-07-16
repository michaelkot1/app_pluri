# SPEC.md — Pluri

> **Product spec for Pluri**, an iOS fitness-coaching app built with Swift / SwiftUI.
> Companion docs: [`design.md`](design.md) (visual system), [`PLAN.md`](PLAN.md) (architecture & milestones), [`TASKS.md`](TASKS.md) (work items), [`AGENTS.md`](AGENTS.md) (ground rules).

---

## 1. Product Overview

Pluri is a personal fitness coach in your pocket. A user answers a short onboarding questionnaire; Pluri generates a multi-week, personalized weight-training plan, schedules it onto a calendar, guides the user through each workout with exercise instructions and logging, tracks health data via Apple Health, and provides an AI coach ("Ask Pluri") plus recipes, nutrition logging, insights, and a community feed.

**Tone & feel:** warm, gentle, encouraging — never scolding. See `design.md`.

### 1.1 Version scope

| Area | v1 | v2+ |
|---|---|---|
| Fitness type | **Workout (weight training) only.** Cardio and Flexibility appear as options in onboarding but are disabled/"coming soon". | Cardio & Flexibility plans; hybrid plans (e.g., workout + cardio with separate goals/dates) |
| Manual activity logging | Workout, Cardio (with distance), Flexibility | — |
| Calendar dots | One dot per day with a workout | Two dots for hybrid days |
| Outdoor Run (record button) | Entry point exists; screen may be a minimal stub | Full GPS run tracking |
| Community | Full feed (posts, likes, comments, polls, saved posts) | Clubs/groups, races & running groups near you ("Explore Spaces" fully live) |

### 1.2 Platform & integrations

- **Client:** iOS, Swift + SwiftUI. (Minimum iOS version decided in PLAN.md.)
- **Backend:** Supabase (auth, Postgres, storage) — user data, plans, workout logs, community content.
- **Exercise database:** WorkoutX API — exercise catalog (names, equipment, target/secondary muscles, images/animations, videos, instructions).
- **AI coach:** Google Gemini API (free tier) — "Ask Pluri" chat; must be grounded with the user's plan and past-workout data from Supabase.
- **Recipes:** TheMealDB API.
- **Food/nutrition logging:** API Ninjas Nutrition API.
- **Health data:** Apple HealthKit (steps, sleep, heart rate, calories, workout sync).
- **Payments:** Apple In-App Purchase subscriptions via RevenueCat (ASC hosts products; client uses Purchases + RevenueCatUI).

> **Secrets:** all API keys and Supabase credentials live in the local `.env` file (never committed, never in docs). See `AGENTS.md` §Secrets.

---

## 2. Accounts & Authentication

*(Implied by profile "sign out / delete account" — made explicit here.)*

- Users create an account so plans and logs sync to Supabase. **Sign in with Apple** is the primary method; email + password as a fallback. Auth happens via Supabase Auth.
- Auth is **blocking** and happens **right after name entry**, before Q1 — there is no guest path past name. Returning users with an existing entitled account + remote plan skip the questionnaire later via restore (M2-15 / M2-18).
- Onboarding answers and the generated plan stay **local** until a flush after paywall unlock (while signed in); auth does not itself persist questionnaire data.
- Profile supports **Sign out** and **Delete account** (full remote data deletion — App Store requirement).
- If a signed-in user reinstalls or gets a new device, their plan, history, and subscription restore from Supabase / RevenueCat.

---

## 3. Onboarding

### 3.1 Flow

1. **Splash screen** (brand moment, sunrise glow per `design.md`).
2. **Name entry** — "What should we call you?" (no progress bar yet).
3. **Account / auth** (§2) — Sign in with Apple (primary) or email/password; blocking. Not counted in the progress bar (chrome between name and Q1). Already-signed-in users skip this screen.
4. **Questionnaire** — starting at question 1 below, a progress bar appears at the top. It does **not** start at 0%: it starts at the percentage corresponding to the current step's position in the full flow (name entry counts as the completed first step; auth does not add a step), and fills as the user advances. Back navigation is allowed.
5. **Plan generation** — "Generating your plan…" loading screen.
6. **Plan ready + paywall** (§4).
7. **Home page** (§5).

### 3.2 Questions

**Q1. What type of fitness would you like to do?**
- Workout ✅ (only selectable option in v1)
- Cardio *(visible, disabled — "coming soon")*
- Flexibility *(visible, disabled — "coming soon")*

**Q2. What's your main goal?** *(added — plans need a name/goal, and Manage Plan lets users adjust the goal later)*
- Build muscle
- Get stronger
- Lose fat / tone up
- General fitness & consistency

**Q3. How long have you been weight training?**
- Not yet
- 1–6 months
- 6–12 months
- 1–2 years
- 2+ years

**Q4. Do you weight train regularly?**
- I've never done weight training before
- I tend to go on and off
- I train regularly
- I used to — I'm coming back after a long break

**Q5. Where do you work out?**
- Commercial Gym
- Home Gym
- Small Gym
- Bodyweight

**Q6. What equipment is available to you?** (multi-select from the WorkoutX equipment list)
- Selecting **Commercial Gym** in Q5 auto-selects **all** equipment.
- Home Gym / Small Gym / Bodyweight pre-select a sensible common subset (defined in TASKS when the equipment mapping is built); user can adjust freely.

Equipment list (from WorkoutX):

```
Assisted, Assisted (towel), Band, Barbell, Body Weight,
Body Weight (with Resistance Band), Bosu Ball, Cable, Dumbbell,
Dumbbell (used as Handles for Deeper Range), Dumbbell + Exercise Ball,
Dumbbell + Exercise Ball + Tennis Ball, Elliptical Machine, Ez Barbell,
Ez Barbell + Exercise Ball, Hammer, Kettlebell, Leverage Machine,
Medicine Ball, Olympic Barbell, Resistance Band, Roller, Rope,
Skierg Machine, Sled Machine, Smith Machine, Stability Ball,
Stationary Bike, Stepmill Machine, Tire, Trap Bar,
Upper Body Ergometer, Weighted, Wheel Roller
```

**Q7. Any injuries?** (multi-select body areas; for each selected area, pick a pain level 1–5)
Areas: Back, Cardio, Chest, Lower Arms, Lower Legs, Neck, Shoulders, Upper Arms, Upper Legs, Waist.
Injury + pain level influence plan generation (avoid or de-load exercises targeting painful areas; higher pain = stricter exclusion).

**Q8. How often would you like to work out?**
- Pick specific weekdays. Default: **Mon / Wed / Fri**.
- Min 2 days, max 6 days per week.

**Q9. Scheduled or flexible schedule, and how long should the plan run?**
- Schedule type: **Scheduled** (workouts pinned to the chosen weekdays) or **Flexible** (N workouts per week, do them any day).
- Plan length in weeks: suggest **6**, min **3**, max **12**.

**Q10. How much time do you want to devote each workout?**
- 30 min / 45 min / 1 hr / 1 hr 15 min / 1 hr 30 min

**Q11. About you** — age, gender, height, weight. (Units respect the user's locale; changeable later in Manage Plan.)

**Q12. Maintenance calories + allergies.**
- Screen opens with: "Based on your goals, your maintenance calories are **N**" (computed from Q11 via Mifflin-St Jeor + activity estimate; used by the Recipe/nutrition features).
- Then: "Do you have any allergies?" — chips for the most common food allergies (peanuts, tree nuts, milk/dairy, eggs, wheat/gluten, soy, fish, shellfish, sesame) plus a search field for specific ones.

**Q13. When do you want to start?**
- Today / Tomorrow / Choose a date.

### 3.3 Plan generation

- On completion, show a "Generating Plan…" screen while the plan is built: exercises selected from WorkoutX filtered by the user's equipment, experience, injuries, goal, session duration; distributed across the chosen days and weeks.
- When ready, transition to the "Your plan is ready" screen (§4).
- Generation must feel deliberate (a few seconds of progress animation) but never dead-end; failures retry silently, then surface a gentle retry button.

---

## 4. Paywall & Subscription

- Shown once the plan is ready — plan is teased but locked behind the paywall.
- Pricing: **$7.99 / month** or **$29.99 / year**, both with a **1-month free trial** (App Store Connect introductory offer — see §14 #7).
- Implemented via **RevenueCat** (Purchases + RevenueCatUI Paywalls) on top of App Store Connect auto-renewable products; entitlement id **`Pluri Pro`**, product ids **`monthly`** / **`yearly`**. Trial / intro state is applied by Apple on eligible purchases and reflected in RevenueCat `CustomerInfo` / entitlement info; the SDK does not invent a custom trial length.
- Must include: restore purchases, terms & privacy links, and clear trial disclosure (App Review requirements) — provided by the RevenueCat Paywall template when enabled in the dashboard editor.
- The user is already signed in by this point (§2 / §3.1). After purchase (or trial start), onboarding answers + plan flush to Supabase (while authenticated), then the user lands on **Home**.
- If the subscription lapses, the user returns to a locked state with the paywall (content preserved, not deleted).

---

## 5. Home Page

Top bar: **User profile**, **Notifications**, **Calendar** buttons.

Body, top to bottom:

1. **Calendar strip / month view** — a small dot marks days that have a workout (two dots for hybrid days — v2). Tapping a day shows that day's workout.
2. **Pluri Score card** — score out of 100 (§5.1).
3. **Today's Health** — tiles for steps, sleep, active heart rate (from HealthKit). Tapping a tile deep-links to the relevant section of the Insights page (averages, trends, how to improve).
4. **Record Workout button** — floating above the nav bar. Tapping pops up options: **today's scheduled workout** (→ workout detail, §7) or **Outdoor Run** (→ run screen; stub in v1).
5. **Tab bar:** Home · Plan · Insights · Community · Recipe.

### 5.1 Pluri Score

A 0–100 score measuring how the user is doing overall, combining:
- **Consistency** (primary driver): scheduled workouts completed on time, streaks, rescheduling behavior.
- **Health insights** (secondary): trends from HealthKit (steps, sleep, activity) relative to the user's own baseline.

Exact weighting is an implementation decision (PLAN.md); the score must move slowly and kindly — it rewards showing up, and dips gently rather than punishing missed days. The "Plan Overview" info page (§6.1) explains it to the user.

### 5.2 Profile page

- Basic plan info (goal, dates, schedule).
- **Connected apps** — shows Apple Health connection and insights permissions.
- Notification settings.
- Language.
- Theme: light / dark.
- Terms & conditions.
- Sign out.
- Delete account.

### 5.3 Notifications page

Message types:
- Community: replies to the user's posts; messages from clubs/groups the user is in (groups full feature = v2).
- Upcoming workout reminders.
- **Late-day nudge:** if a scheduled workout is still incomplete near midnight, offer to reschedule it.

### 5.4 Calendar page

- Week-by-week layout; each workout visible on its day.
- User can add a workout to any empty day.
- This same page is reused as "Rearrange Workouts" from the Plan page (§6).

---

## 6. Plan Page

Top: **Plan card** — goal/plan name, plan end date, weeks-completed tracker (e.g., "Weeks Completed 1/6").

Below: horizontal row of circular buttons:
- **Plan Overview** (§6.1)
- **Rearrange Workouts** — opens the Calendar page (§5.4).
- **Connected Apps** — shows connected apps/devices; add watch or other Bluetooth devices.
- **Manage Plan** (§6.2)

Below the buttons: a **card per week** — week number, workout count, and each workout's name, duration, and day. Workouts are color-coded by workout type and get a checkmark when completed.

Tapping a week card opens **Week Overview** (§6.3).

### 6.1 Plan Overview (info page)

Explains:
- what each color next to a workout means,
- how to read the Pluri Score,
- how to talk to the Pluri coach (Ask Pluri).

### 6.2 Manage Plan

Adjust: goal, start date, end date, plan length, training days, workout duration, units of measure. Changes regenerate/adjust the remaining (not yet completed) part of the plan.
*(v2: hybrid plan management — separate dates/goals for cardio etc.)*

### 6.3 Week Overview

*(Called "Plan Overview" in early notes; renamed to avoid clashing with §6.1.)*

A larger view of the selected week's card. From here the user selects a specific workout → **Workout Detail** (§7).

---

## 7. Workout Detail Page

For a selected workout:
- Workout name and type (Weights / Cardio / Flexibility).
- **Skip workout** option.
- Organized summary of the **equipment needed** for the whole workout.
- Description of **each exercise** and its set count.
- **Workout Notes** button — quick bottom sheet to log notes for the workout.
- **View Workout** button → Workout Screen (§8).

---

## 8. Workout Screen (live workout)

**Layout (pre-start):**
- Timer at top (idle), empty metric slots below it.
- One **exercise card** per exercise: exercise image/animation, name, equipment (Body Weight / Barbell / Dumbbell / …), main target muscle, secondary muscle, and either time or sets × reps.
- Tapping a card opens an expanded sheet: longer description, per-exercise notes field, and an **image/animation ↔ video toggle** (video = real person performing the exercise, from WorkoutX).
- Bottom: **Start** button and **Ask Pluri** button.

**Ask Pluri (§10)** is available both before and during the workout.

**After Start:**
- Timer runs; health metrics (heart rate, calories) stream in live via HealthKit.
- **Pause / Stop Workout** control appears.
- Each exercise card gains:
  - a **timer button** for timed exercises, or
  - a **Log button** for sets/reps/weight exercises. The log UI expands inline after input but stays compact — it must not push content far down the screen.
- **Hold-to-finish** gesture to complete the workout.

### 8.1 Workout completion

Summary screen shows:
- Workout name and date performed,
- planned duration vs. **actual duration** and total reps achieved,
- option to add workout notes,
- toggle to **sync to Apple Health**,
- **Discard** and **Save** buttons.

On save, the workout is checked off on the Plan/calendar and appears in Insights.

---

## 9. Insights Page

Two tabs: **Performance** and **Workouts**. Top bar has a calendar button and a **"+"** button.

### 9.1 Performance tab

- Per-exercise stats: reps/sets over time, total weight moved, progress trends.
- Filter insights by week.
- **All-Time Stats** — depends on plan type: e.g., strength totals, total time worked out; (for runners: total distance, total activities — v2 emphasis).
- **Health insights** — steps, sleep, calories burned, etc., presented richly (averages, trends, guidance) in the spirit of the app *Bevel*.

### 9.2 Workouts tab

- All completed workouts grouped **by month**, with monthly totals (activity count; total distance where relevant).
- Each completed workout is an interactive card: description, duration, total reps, and every exercise with the sets/reps/weight the user logged.

### 9.3 Manual activity logging ("+")

- Asks: Workout / Cardio / Flexibility → date → start time → duration.
- Cardio additionally asks for distance.
- Logged activities appear in the Workouts tab and count toward stats.

---

## 10. Ask Pluri (AI Coach)

- Chat interface, opened from the Workout Screen (pre- and mid-workout) and referenced in Plan Overview.
- Powered by Gemini (free tier), grounded with the user's Supabase data: current plan, past workouts, logged stats.
- Capabilities:
  - Answer questions about exercises and training ("informative, kind coach" persona).
  - **Modify the plan on request:** add a workout, remove a workout.
- Must never expose raw API details or other users' data; requests go through a Supabase Edge Function, not directly from the client (keeps the Gemini key server-side).

---

## 11. Community Page

Top bar: search button + calendar button.

- **Search** across: general questions, gear questions, workouts / runs / flexibility posts.
- **Explore Spaces** button — browse upcoming races and running groups nearby *(directory browsing in v1; joining/managing groups is v2)*.
- **Bookmark button** — view the user's saved posts.
- **Feed** — Instagram-style scrolling posts: like, comment, polls.
- **Create Post** (bottom button):
  - Title + body text.
  - Post type: **General**, **Gear**, **Recipe**, or **Share Workout**.
  - Optional image; optional poll.
  - The **Post** button activates only once there's a title and at least 3 words of body text.

---

## 12. Recipe Page

- Calendar-style view (like Home): select a day to see the recipes suggested for that day.
- **Automatic suggestions:** ~3 options each for breakfast, lunch, dinner, and dessert, filtered by the user's allergies (§3.2 Q12) and informed by maintenance calories.
- **Explore tab** — filter by cuisine, specific meat/protein, cooking duration, and portion size (meal-prep vs. single serving).
- **Favorites** — save recipes; a suggestion algorithm biases future suggestions toward foods similar to favorites.
- **Log button** — available from a recipe page or standalone:
  - Search **foods** (not just recipes) via the Nutrition API.
  - Choose serving size, etc. — MyFitnessPal-style logging.
  - Shows the user calories eaten (tracked against maintenance calories).

---

## 13. Non-Functional Requirements

- **Offline tolerance:** an in-progress workout must never lose data — log locally first, sync to Supabase when online.
- **Privacy:** HealthKit data is used for display/score/insights only and never leaves the device except via the user-initiated Apple Health workout sync; comply with App Store HealthKit rules. Community content is the only user-generated public data.
- **Performance:** workout screen interactions (logging a set) must feel instant (<100 ms UI response); exercise media should be cached.
- **Accessibility:** Dynamic Type, VoiceOver labels on all interactive elements, sufficient contrast (the soft palette still must pass WCAG AA for text).
- **Design:** all UI follows `design.md` (colors, type scale, spacing, radius, elevation).

---

## 14. Decisions & Assumptions Log

Choices made while structuring this spec (flag if wrong):

1. **Auth added (§2):** original notes implied accounts (sign out / delete account) but never specified sign-up. Chose Sign in with Apple + email via Supabase. **Superseded by §14 #29** — auth is no longer at the paywall; it runs right after name entry.
2. **Goal question added (Q2):** the Plan card shows a "goal/plan name" and Manage Plan edits a goal, but no onboarding question captured one.
3. **"Week Overview" naming:** the week-detail page was also called "Plan Overview" in notes; renamed to avoid collision with the info page.
4. **Q9 combined:** "scheduled vs flexible" and plan length (3–12 weeks, suggest 6) were tangled in one note; kept as one two-part question.
5. **Maintenance calories formula:** Mifflin-St Jeor chosen as default; can be revisited.
6. **Gemini via Edge Function:** the AI key stays server-side rather than shipping in the app.
7. **Trial:** **1-month free trial** applies to both monthly and yearly plans, configured as an App Store Connect **introductory offer** (Free → 1 Month) on each product. Apple applies it automatically for eligible users in the subscription group; RevenueCat surfaces it via the paywall / `CustomerInfo`. (Supersedes the earlier draft “10-day” wording — ASC has no 10-day intro duration.)
8. **Outdoor Run in v1:** entry point exists but is a stub — full run tracking isn't specced for v1.
9. **Schema v1 applied non-destructively (M0):** the Supabase project pre-dated M0 with prototype tables (`workout_plans`, `plan_days`, `plan_day_exercises`, `user_equipment`, `exercises`). PLAN §1.3 tables (`plans`, `plan_workouts`, `workout_exercises`, `workout_sessions`, `set_logs`) were added alongside and `profiles` extended in place; legacy tables untouched pending owner approval (see TASKS backlog).
10. **iOS minimum:** the Xcode project targets the current iOS SDK generation (created on Xcode 26); PLAN §1.2's "iOS 17 minimum" is superseded by the project's setting.
11. **WorkoutX has no video URL (M1-01):** §8's "image/animation ↔ video toggle" assumed WorkoutX exposes a video per exercise. The real API only returns an animated GIF (`gifUrl`); no video field or endpoint exists (confirmed by trying several plausible endpoint shapes — see `Core/Networking/WorkoutX/README.md`). Interim decision: the `Exercise` domain model keeps an optional `videoURL` for a future provider/tier to fill in; until then, the toggle in §8 has only one state (image/animation) and the video option should be hidden rather than shown-and-broken. Revisit when a video source is identified.
12. **Exercise catalog staleness window (M1-03):** the SwiftData cache refreshes from WorkoutX after 7 days (or immediately if empty), not on every launch — WorkoutX's free-tier quota is 500 requests/month and the catalog itself rarely changes.
13. **Progress bar denominator confirmed (M1-07):** §3.1's "14 steps" = name entry (step 1) + Q1–Q13 (steps 2–14). The bar is hidden on splash/name, appears at Q1 already showing 2/14 (~14%) filled (name counts as the completed first step), and reaches 14/14 (100%) at Q13. Both forward taps and back-swipes mutate the same navigation path, so the bar recedes correctly on back navigation. **Auth after name (M2-11) does not change the denominator** — see §14 #29.
14. **Q6 equipment auto-select subsets defined (M1-10, resolves the §15 open question below):** Commercial Gym selects the full 34-item WorkoutX equipment list. The other three locations pre-select an editorial subset (WorkoutX doesn't tag equipment by "typical setting"), freely editable afterwards:
    - **Home Gym:** Band, Barbell, Body Weight, Body Weight (with Resistance Band), Bosu Ball, Dumbbell, Dumbbell (used as Handles for Deeper Range), Ez Barbell, Kettlebell, Medicine Ball, Olympic Barbell, Resistance Band, Rope, Stability Ball, Trap Bar, Weighted.
    - **Small Gym:** Assisted, Band, Barbell, Body Weight, Cable, Dumbbell, Ez Barbell, Kettlebell, Leverage Machine, Medicine Ball, Olympic Barbell, Resistance Band, Smith Machine, Stability Ball, Stationary Bike, Trap Bar, Weighted.
    - **Bodyweight:** Body Weight, Body Weight (with Resistance Band), Band, Resistance Band, Roller, Wheel Roller.
15. **Q7 excludes "Cardio" from injury body areas (M1-11):** WorkoutX's `bodyPart` taxonomy has 10 values including `"Cardio"`, but that isn't a physical area someone reports pain in, so the injury question offers only the other 9 (Back, Chest, Lower Arms, Lower Legs, Neck, Shoulders, Upper Arms, Upper Legs, Waist).
16. **`CalorieCalculator` "Other" gender (M1-14):** Mifflin-St Jeor only defines male/female offsets (+5 / −161). `.other` uses their average (−78) as a documented, reasonable middle ground pending better guidance.
17. **Q12 allergy search (M1-14):** the search field filters a secondary pool of ~20 less-common allergens via `localizedStandardContains`; submitting text that matches neither the 9 common chips nor that pool still adds it as a free-text custom allergy.
18. ~~**M1-16/17/18 intentionally deferred**~~ **Superseded (M1-16..18 now shipped):** `PlanEngine`, its unit tests, and the "Generating Plan" → "Plan Ready" screens are implemented. Q13 now advances to `PlanGeneratingView` (the old dead-end stub is deleted). Decisions #19–#24 below capture the v1 algorithm choices.
19. **Equipment reconciliation via normalization (M1-16, resolves the TASKS backlog item):** user equipment selections (Q6, in SPEC punctuation) are matched against catalog `equipment` (WorkoutX punctuation) by normalizing both — lowercase, then strip every non-alphanumeric character — and comparing the results. This collapses all observed differences (`"Dumbbell + Exercise Ball"` vs `"Dumbbell, Exercise Ball"`; `"used as"` vs `"used As"`) to one key and degrades gracefully if WorkoutX changes punctuation again, avoiding a brittle 1:1 mapping table. Lives in `EquipmentMatcher`.
20. **Injury exclusion granularity — v1 is coarse (M1-16):** any exercise whose `bodyPart` matches a selected injured area is excluded from the entire plan, **regardless of pain level**. The pain level (1–5) is still captured (Q7) but not yet used; graded de-loading / partial exclusion by pain level and by `targetMuscle`/`secondaryMuscles` is deferred as the smallest reversible v1 choice (SPEC §3.2 said "higher pain = stricter exclusion" — that gradation is a v2 refinement).
21. **v1 plans are weight-training only (M1-16, per §1.1):** the engine drops catalog exercises with `bodyPart == "Cardio"` before selection, so cardio movements never appear in a v1 Workout plan.
22. **Session composition / time budget (M1-16):** exercises per session = `round(sessionMinutes ÷ 8)`, clamped to 3–8 (≈8 min budgeted per exercise incl. sets, rest, and setup). So 30 min → 4, 45 → 6, 60 → 8, 75/90 → 8 (capped). A session's teaser `estimatedMinutes` uses ≈2 min per working set.
23. **Muscle-group-balanced selection with a seeded RNG (M1-16):** eligible exercises are grouped by `bodyPart`, seed-shuffled within each group, drawn round-robin across groups into one balanced pool, then chunked into sessions so each session spans varied muscle groups. The same session templates repeat every week. If the eligible pool is smaller than the plan needs (e.g. a heavily restricted bodyweight/injury combination), the pool is cycled and some exercises recur — acceptable for v1, and only for unusually small catalogs.
24. **Progression + determinism (M1-16):** base sets×reps per goal — strength 4×5, hypertrophy (build muscle) 3×10, fat-loss/tone 3×12, general 3×10. Progression is linear: +1 rep per week capped at +3, then +1 set from week 5 onward. The engine is fully deterministic given a `seed`; `PlanInput.deterministicSeed` derives a stable seed (FNV-1a over the canonical answers, not `Hasher` which is per-process randomized) so identical answers always regenerate the same plan.
25. **Exercise catalog source switched to the Supabase seed (bug fix, 2026-07-13):** on-device plan generation always failed on fresh installs because the live WorkoutX free tier now caps every `/exercises` response at **10 rows** regardless of `limit`, so a full 1,327-row catalog fetch needs ~133 requests and 429s against the 30-requests/window burst limit before finishing (each attempt also burning ~¼ of the 500/month quota). Fix: catalog reads now come from the Supabase `exercises` table — the seeded 1:1 WorkoutX snapshot flagged as a reusable fallback in M1-01 — via `SupabaseExerciseCatalogClient`, with an anon SELECT RLS policy added (migration `allow_anon_read_exercises`) since the catalog is public, non-sensitive reference data (auth now runs after name — §14 #29 — but Q1+ still needs anonymous-friendly catalog reads for any pre-auth edge cases / signed-out restore). `LiveWorkoutXClient` is retained for single-exercise lookups and a future paid-tier path; keeping the snapshot in sync with WorkoutX becomes a server-side concern for the M2+ `generate-plan` Edge Function.
26. **Bundle id settled (M2-01, 2026-07-15):** app `com.codewithmikey.Pluri`, tests `com.codewithmikey.Pluri.PluriTests`. Still changeable until the App Store Connect app record exists.
27. **RevenueCat for subscriptions (owner decision 2026-07-13):** subscription infrastructure will use RevenueCat (third-party SDK, owner-approved) on top of App Store Connect / StoreKit products. The SDK lands in M2-06/07; ASC still hosts the actual `$7.99/month` and `$29.99/year` auto-renewable products.
28. **Client uses RevenueCat SDK + RevenueCatUI only (M2-06..10, 2026-07-15):** no app-authored StoreKit 2 service. SPM packages `RevenueCat` + `RevenueCatUI`; paywall is dashboard `PaywallView`; Customer Center wrapped as `PluriCustomerCenterView` for Profile (M2-16). Entitlement id **`Pluri Pro`**; package/product ids **`monthly`** / **`yearly`**. Public Apple API key injected via `REVENUECAT_API_KEY` → `Secrets.revenueCatAPIKey` (never committed).
29. **Auth after name entry (owner decision, M2-11 / M2-12, 2026-07-15):** auth is blocking UI between name and Q1 (not an extra progress step). Answers + plan remain local until flush after paywall unlock while signed in (M2-14). Paywall unlock no longer implies “account creation next.” Returning entitled sign-in → remote restore / Main is M2-15 / M2-18; interim stub until those land.
30. **Email OTP after sign-up (owner decision, extends M2-11, 2026-07-15):** when `signUp` returns no session (Supabase email confirmation required), the app shows a **6-digit OTP** screen. User verifies via `verifyOTP(…, type: .signup)` then RevenueCat `logIn` and continues to Q1 **without** re-entering password. If `signUp` already returns a session (confirm off), OTP is skipped. Dashboard assumption: Auth email template for signup OTP delivers a **6-digit code** (not only a magic link).
31. **Profile / plan DB code mapping (M2-13, 2026-07-15):** UI enum display `rawValue`s map to Postgres CHECK snake_case codes. Goal (4 app → DB): `Build muscle` → `build_muscle`, `Get stronger` → `build_strength`, `Lose fat / tone up` → `get_lean`, `General fitness & consistency` → `overall_fitness`. Unused DB goals `get_in_shape` / `lose_weight` reverse-map into general / fat-loss for restore. Experience / regularity / location / schedule / weekday / gender use the schema’s existing codes (`1_6_months`, `on_and_off`, `commercial_gym`, `scheduled`, `mon`…). `profiles.injuries` jsonb shape: `[{ "area": "<BodyArea rawValue>", "pain": 1...5 }]`. Units default `metric` (canonical storage). Flush sets `onboarding_completed = true`.
32. **Returning entitled path split (M2-15 vs M2-18, 2026-07-15):** M2-15 hydrates profile + active plan after entitled sign-in and improves the welcome-back placeholder with restored summary. M2-18 owns `AppRouter` → Main TabView; until then users stay on the restored stub (no invented Main shell).
33. **Cold-launch questionnaire skip without Main (owner, 2026-07-15):** After account + questions + plan are saved, cold launch / return must **not** re-ask the questionnaire. Launch gate waits for auth + RevenueCat hydration, retries flush checkpoint, re-aliases RevenueCat, restores remote profile/plan. Skip when signed-in and (`onboarding_completed` **or** an active plan exists); otherwise keep Splash→Qs. Destination is still `WelcomeBackStubView` until M2-18. Lapsed entitlement still skips Qs (no locked Paywall Main yet). Optional UserDefaults completion hint (keyed by userID) for offline relaunch; cleared on sign-out; remote remains source of truth when online.
34. **Debug entitlements omit Sign in with Apple (2026-07-16):** Personal/free Apple Developer teams cannot provision the `com.apple.developer.applesignin` capability. **Debug** builds use `Config/Pluri-Debug.entitlements` (no SIWA) so device installs work on a personal team; **Release** keeps `Config/Pluri.entitlements` with SIWA for paid-program App Store builds. SIWA UI/code remains in the app — it will not succeed on Debug device builds without the entitlement; use email/OTP auth for on-device testing until enrolled in the paid Apple Developer Program.
35. **Profile interim choices (M2-16 / M2-17, 2026-07-16):** Profile's **Terms & Conditions** links Apple's **standard EULA** (`apple.com/legal/internet-services/itunes/dev/stdeula/`) as the smallest reversible option until Pluri hosts its own terms (open question in §15; constant lives in `LegalLinks`). **Theme** offers Auto / Light / Dark with Auto (follow device) as the default; the choice persists per-device in UserDefaults (`ThemeStore`) and intentionally survives sign-out because it's a device preference, not account data. **Apple Health** row is display-only ("Not connected") until M5; **Notifications** row is a stub until M3; **Language** row displays the device language (no in-app localization yet). Sign-out / delete-account reroute via a narrow `AppLaunchGate.resetToOnboarding()` — full phase routing remains M2-18. Sign-out and successful deletion also RevenueCat-`logOut()` and clear the signed-out user's pending flush checkpoint **user-scoped** (another account's unsent checkpoint is preserved); shared exercise-catalog caches are never wiped. Failed deletion keeps the user signed in with local state intact.

## 15. Open Questions

- Exact Pluri Score formula and weighting (consistency vs. health signals).
- ~~Default equipment subsets for Home Gym / Small Gym / Bodyweight (Q6 auto-select).~~ **Resolved — see §14 decision #14.**
- ~~Plan-generation algorithm details: exercise selection heuristics, progression model, and how injuries map to exercise exclusions.~~ **Resolved for v1 — see §14 decisions #19–#24** (equipment normalization, coarse injury exclusion by `bodyPart`, muscle-group-balanced seeded selection, and linear rep-then-set progression). Graded pain-level de-loading and smarter selection remain candidate v2 refinements.
- ~~**Free-trial shape.**~~ **Resolved (2026-07-15) — see §14 #7 / §4:** locked to a **1-month free trial** via ASC introductory offers on `monthly` and `yearly` (auto-converts). No custom RevenueCat granted-entitlement trial.
- Community moderation (reporting, blocking) — required by App Review for UGC; must be scoped before Community ships.
- **Terms & Conditions URL (M2-16):** Profile currently links Apple's standard EULA (§14 #35). Owner to supply a hosted Pluri terms (and privacy policy) URL before launch.
- Whether "Flexible" schedule workouts still appear on the calendar (suggested slots) or only in a weekly checklist.
- Recipe suggestion algorithm specifics (similarity model for favorites).
- **M0-11 — real `SUPABASE_SERVICE_ROLE_KEY`:** the `delete-account` Edge Function (M2-05) is implemented but cannot fully run against production until the owner rotates keys and sets the real service-role secret via `supabase secrets set` (never in the iOS bundle). Client invoke path is ready.
- **Sign in with Apple portal gap (M2-03 / M2-04):** app entitlement is present; Apple Developer App ID capability + Supabase Auth → Apple provider still need owner configuration before SIWA works end-to-end. Email/password auth does not depend on that portal step.
- ~~**Returning entitled user after post-name sign-in (M2-15 / M2-18):**~~ **Partially resolved (2026-07-15):** remote hydrate + welcome-back “plan restored” stub ships in M2-15; **Main TabView / AppRouter landing remains M2-18.** Confirm final Home copy when Main lands.
