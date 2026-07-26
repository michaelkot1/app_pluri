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
Injury + pain level influence plan generation (avoid or de-load exercises targeting painful areas; higher pain = stricter exclusion — graded rules in §14 #47).

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

- On completion, show a "Generating Plan…" screen while the plan is built: exercises selected from WorkoutX filtered by the user's equipment, experience, injuries, goal, session duration; distributed across the chosen days and weeks. Each training day is organized around a **session focus** derived from a weekly split (e.g. Push / Pull / Legs — §14 #46), which names and colors the workout.
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
- **Late-day nudge:** if a scheduled workout is still incomplete near midnight, offer to reschedule it. *(Fire time, opt-in, and reschedule UX — see §14 #50.)*

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
*(Skip vs Discard, Save-only completion + session link, weight units, and HealthKit write boundary — see §14 #50.)*

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
20. **Injury exclusion granularity — v1 is coarse (M1-16):** any exercise whose `bodyPart` matches a selected injured area is excluded from the entire plan, **regardless of pain level**. The pain level (1–5) is still captured (Q7) but not yet used; graded de-loading / partial exclusion by pain level and by `targetMuscle`/`secondaryMuscles` is deferred as the smallest reversible v1 choice (SPEC §3.2 said "higher pain = stricter exclusion" — that gradation is a v2 refinement). **Superseded by §14 #47** — graded pain-level rules are now defined and scheduled (M3-18/19).
21. **v1 plans are weight-training only (M1-16, per §1.1):** the engine drops catalog exercises with `bodyPart == "Cardio"` before selection, so cardio movements never appear in a v1 Workout plan.
22. **Session composition / time budget (M1-16):** exercises per session = `round(sessionMinutes ÷ 8)`, clamped to 3–8 (≈8 min budgeted per exercise incl. sets, rest, and setup). So 30 min → 4, 45 → 6, 60 → 8, 75/90 → 8 (capped). A session's teaser `estimatedMinutes` uses ≈2 min per working set.
23. **Muscle-group-balanced selection with a seeded RNG (M1-16):** eligible exercises are grouped by `bodyPart`, seed-shuffled within each group, drawn round-robin across groups into one balanced pool, then chunked into sessions so each session spans varied muscle groups. The same session templates repeat every week. If the eligible pool is smaller than the plan needs (e.g. a heavily restricted bodyweight/injury combination), the pool is cycled and some exercises recur — acceptable for v1, and only for unusually small catalogs. **Superseded by §14 #46** — selection is now focus-first (split-derived session focuses); the round-robin model here remains as historical context only.
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
36. **Root `AppRouter` routing shipped (M2-18, 2026-07-16, supersedes the interim destinations in #32/#33):** `AppRouter` phases are Splash → Onboarding → Paywall → Main. The splash gates the first transition on **both** the brand moment and auth/RevenueCat hydration, so neither onboarding nor the paywall can flash. The paywall phase has two contexts: (a) end-of-onboarding — answers + generated plan held by the router until the post-unlock flush succeeds (failed flush keeps the payload local with retry), then Main; (b) lapsed entitlement — a **non-dismissible** paywall (no RC close button, no fallback Close) with the restored profile/plan preserved behind it (§4); restore or purchase is the only way through. `WelcomeBackStubView` is deleted: a returning entitled sign-in mid-onboarding re-runs the launch classification (brief splash) and lands on Main or the locked paywall. Main is the minimal five-tab shell (Home · Plan · Insights · Community · Recipe, modern `Tab` API, one `NavigationStack` per tab); Home teases the plan and keeps Profile in the top bar, and sign-out / delete-account reroute to Onboarding via `AppRouter.resetToOnboarding()`. For a just-flushed new user, Main/Profile content hydrates from the same mapper round-trip the remote restore would produce (local answers + plan), avoiding a redundant refetch. Non-entitled returning sign-ins still continue into Q1 per M2-12; their next cold launch classifies them via the router (completed + lapsed → locked paywall).
37. **Flexible-plan calendar appearance (M3-01, 2026-07-16, resolves the §15 open question):** flexible workouts have no concrete weekday/date until the user assigns one. Calendar **dots and day views only show workouts that carry a `scheduledDate`**; unassigned flexible workouts for the current plan week appear as a **weekly pool / checklist** (no fake suggested calendar slots). Assigning a flexible workout to a day (via the Calendar move/add flows, M3-13) sets its `scheduledDate` (+ optional weekday), after which it becomes a normal calendar dot. Most reversible interim choice — owner can revisit suggested-slot rendering later.
38. **Add workout to an empty day (M3-01, SPEC §5.4, 2026-07-16):** adding a workout to an empty day creates a **clone of an existing plan workout the user picks as the source** — same type, color, duration, and exercise list — under a **new workout ID** (and new exercise-row IDs), `status = scheduled`, pinned to the target date. v1 does **not** invent a blank manual workout and does **not** call `PlanEngine` for a single ad-hoc day. Conflict rule: **one workout per day in v1** — adding (or moving) onto a day that already has a workout is rejected.
39. **Manage Plan remaining-plan regeneration (M3-01, SPEC §6.2, 2026-07-16):** regeneration preserves workouts whose status is **`completed` or `skipped`** (including their exercise rows and IDs) unchanged, and replaces only **`scheduled`** (unfinished) workouts from the regeneration cutoff forward — completed/skipped history stays in place even if its dates fall inside an edited window. Replacement workouts get **new IDs**, generated by `PlanEngine` with the deterministic seed derived from the canonical answers (#24). Remote persistence is sequenced failure-safe on the client (M3-05 `SupabasePlanMutationService`): **insert the replacement workouts + exercises first, then delete the replaced scheduled rows by explicit ID** — a failure mid-sequence can leave extra rows to clean up on retry, but never a half-deleted plan. A true transactional DB RPC is deferred to M3-14.
40. **Shared `PlanStore` load states (M3-04, 2026-07-16):** Main tabs observe a single `@MainActor @Observable` `PlanStore` owned by `AppRootView` and configured from `AppRouter.restoredState` on entry to Main. Explicit states are `loading` (pre-configure) / `failed` (router admitted the user via the offline completion hint with `restoredState == nil` — content couldn't be loaded) / `empty` (profile restored, no active plan) / `ready` (profile + plan). The router still collapses restore failure to `nil` for routing; distinguishing "no remote content" from "restore failed" at the store layer is the interim choice until a richer restore error surface is needed. Mutations apply optimistically and roll the local plan back on service failure before rethrowing.
41. **Home & Main navigation interim choices (M3-06..09, 2026-07-17):** (a) **Month summary** is a lightweight header near the calendar strip: current month name + year (e.g. "July 2026") and a completion fraction among that month's **dated** workouts (e.g. "3 of 8 done", counting `completed` only — skipped isn't "done"); no new metrics engine. (b) **Home ignores the flexible weekly pool** — the calendar strip, dots, and selected-day content use only dated sessions (§14 #37); the pool surfaces on Plan/Calendar (M3-10/M3-13). (c) **`MainRouter` is separate from `AppRouter`:** a `@MainActor @Observable` router owned by `MainTabView` holding the selected tab, the Home tab's typed `HomeRoute` path, and the Insights section requested by a health-tile deep link; `AppRouter` keeps owning app phases only. (d) **Workout colors** resolve via `WorkoutColorResolver`: a persisted `plan_workouts.color` naming a known design token (normalized matching, e.g. `status_blue` ≡ `statusBlue`) wins; else when `plan_workouts.focus` is set, the focus's design-token color applies (M3-21 / #46); otherwise type defaults — weights → `brandOrange`, cardio → `statusBlue`, flexibility → `accentLavender`. Tokens only, no ad-hoc hex. (e) **Record Workout menu** hides (not disables) the scheduled-workout option when today has none, always offers Outdoor Run, and uses the first session if a day somehow has several; both options route to honest M4 stubs (no workout execution in M3). (f) **Selected day defaults to today** (`PlanStore.today`); one dot per day in v1. The Pluri Score card shows a fixed sample value (72) clearly badged "Sample" until the M5 engine.
42. **Plan page interim choices (M3-10/11, 2026-07-17):** (a) The **weeks-completed tracker** ("Weeks Completed 1/6") counts `PlanStore.completedWeekCount` — weeks with at least one workout and **nothing still `scheduled`** (completed *or* skipped counts as finished, consistent with #41's gentle tone); the tracker renders as a fraction + progress bar on the plan card. (b) **Flexible (undated) workouts stay visible on their week card** labeled "**Anytime this week**" — no invented dates (#37); dated workouts show their concrete date, weekday-pinned ones the weekday name. Type name and completion state are always spelled out in text — color is supplementary. (c) The four circular **action buttons** (Plan Overview / Rearrange Workouts / Connected Apps / Manage Plan) route to clearly-labelled placeholder pages until M3-12/13/14. (d) The Plan tab gets its own typed `PlanRoute` path on `MainRouter`; **Workout Detail opened from Plan pushes within the Plan stack** (Home's `openWorkoutDetail` still jumps to the Home tab), landing on the shared M4 `WorkoutDetailStubView`. (e) **Week Overview** (§6.3) is the tapped week's full schedule — a summary card ("N workouts", "X of N done" / "Week complete") plus one tappable card per workout.
43. **Plan Overview & Connected Apps shell (M3-12, 2026-07-17):** (a) The **Plan Overview** info page (§6.1) explains the workout color legend (type defaults per #41: weights → `brandOrange`, cardio → `statusBlue`, flexibility → `accentLavender`, noting v1 plans are Weights-only), how to read the Pluri Score (0–100, consistency-first with HealthKit signals as a later secondary layer, moves slowly/kindly — **no formula is invented**; the page says plainly that Home's score is a sample until the real engine lands), and Ask Pluri's future role (kind plan-aware coach that will answer training questions and adjust the plan — §10) — described honestly as upcoming. (b) **Connected Apps is a display-only shell until M5:** Apple Health shows "Not connected" (matching Profile's row) and Devices shows "No devices connected", both with "arrives in a future update" footers — **no pretend connect buttons**.
44. **Calendar / Rearrange page choices (M3-13, 2026-07-17):** (a) One reusable `CalendarView` serves both Home's Calendar button and Plan's "Rearrange Workouts", **staying in whichever tab stack opened it** (no cross-tab jump). (b) Week-by-week navigation over the plan's rolling weeks; the page opens on **today's plan week** when the plan is in progress, week 1 before the start, the last week after the end. (c) Move + add are **button/sheet flows** (a graphical day picker bounded to the plan window; add-to-empty-day picks a source workout to clone per #38) — drag-and-drop is a candidate refinement, not v1. (d) **History is immutable:** only `scheduled` workouts can move (including flexible → dated per #37); `PlanMutator` rejects moving `completed`/`skipped` workouts (`PlanMutationError.workoutFinished`). (e) Conflicts (occupied day, date outside the plan) surface as gentle inline sheet feedback; mutations stay optimistic with the M3-05 rollback. (f) **Reminder reconciliation hook for M3-15:** `PlanStore` calls an injected `WorkoutReminderReconciling` (`NoopWorkoutReminderReconciler` until M3-15) **after** every successful remote move/add/replace/Manage-Plan write; the call is non-throwing by design — a reminder failure must never roll back an already-persisted plan change. M3-15 swaps in the real notification service.
45. **Manage Plan rules & atomic persistence (M3-14, 2026-07-17):** (a) **Date/length precedence:** start date + plan length (weeks) are primary and the end date is derived (`start + weeks × 7 − 1`); editing the end date recomputes the length in **whole weeks** from the start (rounded, clamped to the supported 3–12), after which the end date re-derives — the three fields can never disagree. (b) **Regeneration cutoff = all unfinished:** the v1 reading of #39 — every `scheduled` workout is replaced (no date-based cutoff); `completed`/`skipped` history is preserved untouched. Engine inputs not editable here (experience, equipment, injuries) come from the stored profile; if they're missing the save fails gently with a validation message instead of guessing. (c) **Atomic remote persistence via RPC** (supersedes #39's "deferred to M3-14" note): migration `replace_remaining_plan` adds a **SECURITY INVOKER** Postgres function (RLS applies to every statement inside; explicit `auth.uid()` ownership check first; EXECUTE granted to `authenticated` only) that updates plan settings + profile settings, upserts replacement/preserved workout + exercise rows, and deletes the old scheduled rows **in one transaction** — insert-then-delete semantics preserved, but a failure can no longer leave a partially replaced plan. `SupabasePlanMutationService.applyManagePlan` calls it with a single JSON payload; the M3-05 client-sequenced `replaceRemainingWorkouts` path remains for non-Manage-Plan callers. (d) **Units are a display preference** (`metric`/`imperial`, canonical storage stays metric); a units-only save persists via a plain profile update — no regeneration, no plan touch.
46. **Focus-first split-based plan generation (owner decision, 2026-07-17, supersedes the selection model in #23; scheduled as M3-18..21):** a "session focus" layer decides each training day's job **before** exercise selection. The weekly split is derived from days/week (+ experience/goal) — never asked in onboarding: **2 days** → Full Body A / Full Body B (differing movement patterns); **3 days** → Push / Pull / Legs (or Upper / Lower / Full Body for beginners); **4 days** → Push / Pull / Legs / Upper (or Chest & Triceps / Back & Biceps / Legs / Shoulders & Arms); **5–6 days** → PPL + accessories or a classic body-part split. Each focus defines its primary target muscles, secondary/supporting muscles, a **display title** (e.g. "Chest & Triceps", "Back & Biceps" — the title comes from the focus, not from counting selected body parts, replacing the everything-reads-"Full Body" naming of `sessionTitle(for:)`), and a **design-token color** so the schedule UI gets visual variety through the existing `WorkoutColorResolver` path (#41d). Selection fills a session against its focus using the already-synced `targetMuscle`/`secondaryMuscles` fields (unused until now): a majority of primary-target movements plus 1–2 secondary/supporting movements, which requires a mapping from onboarding `BodyArea` (9 coarse WorkoutX body parts) to WorkoutX target-muscle values. "Full Body" remains a legitimate focus only when **earned**: 2-day plans, or when injury/equipment filtering shrinks the eligible pool too far to fill a focused split. The focus is **persisted on the workout** (not just the free-text `name`) so regeneration, colors, and UI stay consistent — implies a small schema addition (a `focus` code column on `plan_workouts`) plus sync DTO/mapper updates. Session sizing (#22), progression, and determinism (#24) are unchanged; the engine remains client-side for now and must port cleanly to the future `generate-plan` Edge Function (PLAN §1.3).
47. **Graded injury-aware programming (owner decision, 2026-07-17, supersedes the coarse exclusion in #20; scheduled as M3-18/19):** Q7 pain levels now grade how an injured area is programmed, using the same `BodyArea` → `targetMuscle`/`secondaryMuscles` mapping as #46 (coarse `bodyPart` matching alone is too blunt). **Pain 1–2:** the injured area is avoided as a *primary* target/focus but allowed as secondary involvement with light volume (gentle strengthening) — e.g. a shoulder injury at pain 2 skips a Shoulders focus day but still allows Chest & Triceps where delts are secondary. **Pain 3:** avoided as primary; secondary involvement is load-capped / prefers supported or machine variants. **Pain 4–5:** hard exclusion as primary AND as heavy secondary involvement — closest to the previous v1 behavior. This pulls forward a defined version of the "graded pain-level de-loading" §15 v2 candidate, matching §3.2 Q7's "higher pain = stricter exclusion."
48. **Upcoming-workout reminders (M3-15, 2026-07-17):** (a) **Fire time** is **8:00 AM local** on the workout's scheduled calendar day; if that time has already passed for "today", the session is skipped (no immediate catch-up fire). (b) **Opt-in** is a user-scoped UserDefaults preference (keyed by authenticated `userID` when available, device-local fallback when signed out / previews) so the preference cannot leak across accounts; local notifications themselves remain device-local. (c) **Permission** is requested only when the user turns the Upcoming-workout-reminders toggle **on**; denial reverts the toggle, persists opted-out, and shows a gentle inline "enable in iOS Settings" explanation (never a scold); re-enable requires flipping the toggle on again (re-requests when `.notDetermined`, explains Settings when `.denied`). (d) **Content:** title = workout title (or "Workout"), body = "Time for today's workout."; default sound; no badge count; no custom categories; identifier = `pluri.workout-reminder.<workoutUUID>`. (e) **Notifications page rows (SPEC §5.3 shell):** Upcoming workout reminders (functional Toggle + footer); Replies to your posts / Clubs & groups (Coming soon — M8); Late-day reschedule nudge (Coming soon — M4; fire time / opt-in / UX decided in #50). (f) **Reconcile:** when opted-in + authorized, cancel all pending `pluri.workout-reminder.*` then schedule the desired upcoming set; when opted-out or unauthorized, cancel all; `reconcileReminders` never throws into `PlanStore` (extends #44). Reminds only dated `.scheduled` sessions whose fire date is still ahead — flexible undated pool sessions and completed/skipped history are excluded.
49. **Focus-split algorithm forks (M3-18/19, 2026-07-25):** reversible defaults for the weekly split derived in `SessionFocus.split` (#46) — never asked in onboarding. (a) **Beginner on 3 days:** `ExperienceLevel.notYet` and `.oneToSixMonths` → Upper / Lower / Full Body A; `.sixToTwelveMonths` and above → Push / Pull / Legs. (b) **Body-part vs PPL on 4–6 days:** prefer the classic body-part split when `goal == .buildMuscle` **or** experience is `.oneToTwoYears` / `.twoPlusYears`; otherwise PPL (+ Upper on 4 days, doubled Push/Pull on 5, doubled PPL on 6). (c) **Pain-3 "supported/machine" secondary:** when the injured muscle is the exercise's own `targetMuscle` in a secondary focus slot, equipment whose lowercased name contains any of `machine`, `cable`, `leverage`, `smith`, `assisted` is kept; free-weight variants are excluded. A healthy primary-target lift that merely lists the injured muscle in `secondaryMuscles` stays primary (pain 4–5 on those secondaries still hard-excludes). (d) **Small-pool Full Body fallback:** when a focus's graded primary-eligible pool has fewer than 3 exercises (`PlanEngine.smallPoolFullBodyThreshold`), that training day falls back to an earned Full Body focus (alternating A/B). Owner may retune these forks without schema changes — codes and CHECK values stay stable.
50. **M4 workout experience decisions (M4-01, 2026-07-25):** reversible interim choices that unblock Detail / live Screen / completion / SyncEngine / late-day nudge (M4-02+). Owner may retune without schema changes unless noted. (a) **Late-day nudge (§5.3):** fire at **21:00 local** on the workout's scheduled calendar day for unfinished dated `.scheduled` sessions; if that time has already passed when reconcile runs (or the calendar day is already past), skip — **no catch-up** fire (same spirit as #48a). Notification opens a gentle reschedule flow (day picker and/or "**Move to tomorrow**"); persistence reuses `PlanStore.move` under existing conflict/history rules (#38/#44). Opt-in is a **separate** user-scoped preference from morning upcoming-workout reminders (#48); permission rules mirror #48 (request only on toggle-on; denial reverts + Settings guidance; never scolds). Identifier pattern `pluri.late-day-nudge.<workoutUUID>`. Flexible undated pool, completed, and skipped are excluded. Notifications page late-day row becomes live in M4-15. (b) **Skip vs Discard:** Detail **Skip** checks the plan workout off as `skipped` (finished for week-tracker purposes per #42; gentle, no scolding). Completion **Discard** drops the in-progress local session and leaves the plan workout `scheduled` — **no** check-off and **no** `skipped` status; the user can start again later. (c) **Crash/kill recovery:** in-progress sessions persist locally first (SwiftData, M4-02); after relaunch, auto-offer resume when opening Detail/Screen for that workout. At most **one** in-progress session per `plan_workout_id`. Never lose offline progress (cardinal rule, §13). (d) **Weight unit display:** UI shows kg/lb from the profile `units` preference (`metric`/`imperial`, Manage Plan / #45d); canonical logged weight storage is always **`weight_kg`**. (e) **Ask Pluri:** M4 ships an honest stub labeled for M6 — e.g. "**Ask Pluri — coming in a later update (M6)**" — with **no** fake coach chat or invented replies; real Gemini coach remains §10 / M6. (f) **HealthKit M4 boundary:** Info.plist usage strings must state intent clearly — write workouts to Apple Health when the user opts in on Save, and read heart rate / active energy **only while a workout session is active** for live display on the Workout Screen. Insights HealthKit *reads* (steps, sleep, trends, Home health tiles, Pluri Score signals) stay **M5**. Live HR + active energy stream only during an active session; Apple Health **workout write** runs only on **Save** when the sync toggle is on — best-effort, and a Health write failure must never drop the local session (§13 privacy still holds). (g) **Save links session + completes plan workout:** **Start** creates/resumes a local in-progress session but does **not** set `plan_workouts.status = completed` or attach the session link. Only **Save** on the completion summary marks `completed`, links the session, and enqueues sync (M4-03/04/14). Discard and abandon leave status `scheduled`.
51. **Local-only workout session fields (M4-02, 2026-07-25):** SwiftData `WorkoutSessionRecord` mirrors Postgres `workout_sessions` for SyncEngine (M4-03) and adds fields with **no remote columns** today: (a) **Pause / elapsed** — `isPaused`, `accumulatedActiveSeconds`, `lastResumedAt` for live-timer continuity across kill/relaunch (M4-09); not synced until a future migration if product needs cross-device timer state. (b) **Per-exercise notes** — `exerciseNotesByWorkoutExerciseId` (`[workoutExerciseId.uuidString: note]`) for SPEC §7 / §8 expanded-card notes; workout-level notes stay on `notes` (maps to remote `notes`). Discard deletes the local session + cascaded `SetLogRecord`s and leaves plan status untouched (#50b). Owner may later promote per-exercise notes / pause fields to Postgres without changing the local API shape.
52. **Skip vs complete sync semantics (M4-03/04, 2026-07-25):** clarifies #50b/g for the PlanStore / SyncEngine write path. (a) **Skip** uses the same optimistic pattern as `PlanStore.moveWorkout`: snapshot → `PlanMutator` status → `.skipped` → optimistic `applyPlan` → `PlanMutationServicing.updateWorkoutStatus` remote upsert → **rollback on throw** → `reconcileReminders()` only on success. (b) **Complete / Save** is offline-first: local PlanStore marks `.completed` optimistically, enqueues `SyncEngine` for `workout_sessions` + `set_logs` + remote `plan_workouts.status = completed`, and reconciles reminders after the **local** apply. **Do not roll back completion on network failure** — SyncEngine retries when online (cardinal offline-first rule, §13). (c) **Session link** is `workout_sessions.plan_workout_id` only — there is **no** `plan_workouts.session_id` column; do not add a migration. (d) **Discard** stays repository-only; plan status remains `.scheduled`. SyncEngine never blocks `WorkoutSessionRepository` local saves; LWW via upsert `onConflict: id`.

## 15. Open Questions

- Exact Pluri Score formula and weighting (consistency vs. health signals).
- ~~Default equipment subsets for Home Gym / Small Gym / Bodyweight (Q6 auto-select).~~ **Resolved — see §14 decision #14.**
- ~~Plan-generation algorithm details: exercise selection heuristics, progression model, and how injuries map to exercise exclusions.~~ **Resolved for v1 — see §14 decisions #19–#24** (equipment normalization, coarse injury exclusion by `bodyPart`, muscle-group-balanced seeded selection, and linear rep-then-set progression). ~~Graded pain-level de-loading and smarter selection remain candidate v2 refinements.~~ **Now defined and scheduled — see §14 #46 (focus-first split selection) and #47 (graded pain-level programming), tasks M3-18..21.**
- ~~**Free-trial shape.**~~ **Resolved (2026-07-15) — see §14 #7 / §4:** locked to a **1-month free trial** via ASC introductory offers on `monthly` and `yearly` (auto-converts). No custom RevenueCat granted-entitlement trial.
- Community moderation (reporting, blocking) — required by App Review for UGC; must be scoped before Community ships.
- **Terms & Conditions URL (M2-16):** Profile currently links Apple's standard EULA (§14 #35). Owner to supply a hosted Pluri terms (and privacy policy) URL before launch.
- ~~Whether "Flexible" schedule workouts still appear on the calendar (suggested slots) or only in a weekly checklist.~~ **Resolved (2026-07-16) — see §14 #37:** weekly pool/checklist only; calendar dots require a `scheduledDate`. Suggested slots remain a candidate v2 refinement.
- ~~**M4 workout experience behavior** (late-day nudge fire time + reschedule UX; skip vs discard; crash/kill recovery; weight unit display; Ask Pluri stub; HealthKit write vs live HR/calories vs Insights reads).~~ **Resolved (2026-07-25) — see §14 #50.** Fire time (21:00) and stub copy remain owner-tunable without schema changes.
- Recipe suggestion algorithm specifics (similarity model for favorites).
- **M0-11 — real `SUPABASE_SERVICE_ROLE_KEY`:** the `delete-account` Edge Function (M2-05) is implemented but cannot fully run against production until the owner rotates keys and sets the real service-role secret via `supabase secrets set` (never in the iOS bundle). Client invoke path is ready.
- **Sign in with Apple portal gap (M2-03 / M2-04):** app entitlement is present; Apple Developer App ID capability + Supabase Auth → Apple provider still need owner configuration before SIWA works end-to-end. Email/password auth does not depend on that portal step.
- ~~**Returning entitled user after post-name sign-in (M2-15 / M2-18):**~~ **Resolved (2026-07-16) — see §14 #36:** returning entitled sign-in reclassifies through `AppRouter` and lands on Main (or the locked paywall when lapsed). Home placeholder copy is interim until M3's real Home; owner may adjust wording then.
