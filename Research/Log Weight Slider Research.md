# Log-Weight Slider: Range, Increment & UX Research

**Purpose:** define min / max / step / default for the inline weight slider revealed by the "Log" button on each exercise card in Pluri's live workout screen, per exercise category, in both kg and lb — plus a UX recommendation for the control itself.

**Status:** research only. No code changes. Numbers below are proposals for the implementer, not yet recorded in `SPEC.md`.

**Headline finding up front:** no leading strength app uses a drag slider as its primary weight input. Strong, Hevy, Fitbod and Peloton all prefill the previous value and open a numeric keypad. Nielsen Norman Group names "current weight" as an explicit example of a value that should *not* be entered with a slider. A slider can still work here, but only as a *coarse* control paired with a stepper and a tap-to-type numeric field. Section 4 covers this in detail; it is the most consequential recommendation in this document.

---

## 1. Summary table

All values assume the weight the user *loads*, matching how strength-standards references count it: barbell figures **include the bar**, dumbbell figures are **per dumbbell**, weighted-bodyweight figures are **added weight only**.

### Kilograms

| Category ID | kg min | kg max | kg step | kg default | Steps on slider |
|---|---|---|---|---|---|
| `barbellLower` | 10 | 300 | 2.5 | 20 | 116 |
| `barbellPress` | 10 | 220 | 2.5 | 20 | 84 |
| `barbellPull` | 10 | 200 | 2.5 | 20 | 76 |
| `dumbbellHeavy` (per hand) | 2.5 | 60 | 2.5 | 10 | 23 |
| `dumbbellLight` (per hand) | 1 | 40 | 1 | 5 | 39 |
| `machineCable` | 2.5 | 150 | 2.5 | 25 | 59 |
| `legPressHeavy` | 20 | 400 | 5 | 60 | 76 |
| `kettlebell` | 4 | 48 | 2 | 8 | 22 |
| `addedLoad` (weighted pull-up/dip) | 0 | 100 | 2.5 | 0 | 40 |
| `noLoad` | — no slider — | | | | |
| `fallback` | 0 | 200 | 2.5 | 10 | 80 |

### Pounds

| Category ID | lb min | lb max | lb step | lb default | Steps on slider |
|---|---|---|---|---|---|
| `barbellLower` | 25 | 700 | 5 | 45 | 135 |
| `barbellPress` | 25 | 500 | 5 | 45 | 95 |
| `barbellPull` | 25 | 450 | 5 | 45 | 85 |
| `dumbbellHeavy` (per hand) | 5 | 150 | 5 | 25 | 29 |
| `dumbbellLight` (per hand) | 2.5 | 90 | 2.5 | 10 | 35 |
| `machineCable` | 5 | 350 | 5 | 50 | 69 |
| `legPressHeavy` | 45 | 900 | 5 | 135 | 171 |
| `kettlebell` | 5 | 105 | 5 | 20 | 20 |
| `addedLoad` (weighted pull-up/dip) | 0 | 220 | 5 | 0 | 44 |
| `noLoad` | — no slider — | | | | |
| `fallback` | 0 | 450 | 5 | 25 | 90 |

The two ladders are deliberately **not** conversions of each other. 700 lb is 317 kg, not 300 kg; 150 lb is 68 kg, not 60 kg. Each ladder is built from the plates, dumbbells and stack pins that actually exist in gyms labelled in that unit, so both read as clean numbers to a native user of that unit. Do not derive one from the other.

---

## 2. Rationale and citations per category

### `barbellLower` — back squat, front squat, deadlift, RDL, hip thrust, barbell lunge, good morning

Strength Level's community data (24.9M squat lifts, 23.0M deadlift lifts) puts the male squat ladder at 66 / 95 / 131 / 173 / 219 kg for beginner → elite, and the female ladder at 32 / 51 / 76 / 105 / 137 kg ([squat standards](https://strengthlevel.com/strength-standards/squat/kg)). Deadlift runs higher: 80 / 113 / 154 / 202 / 253 kg male, 41 / 63 / 91 / 124 / 160 kg female ([deadlift standards](https://strengthlevel.com/strength-standards/deadlift/kg)). Front squat is a little below back squat at 54 / 77 / 105 / 137 / 172 kg male ([front squat](https://strengthlevel.com/strength-standards/front-squat/kg)). ExRx's classification-based tables agree in shape, topping out at an elite 595 lb squat and 615 lb deadlift for the heaviest bodyweight class ([ExRx squat](https://exrx.net/Testing/WeightLifting/SquatStandards), [ExRx deadlift](https://exrx.net/Testing/WeightLifting/DeadliftStandards)).

Hip thrust is the outlier that sets the ceiling. Its male elite mark is 286 kg overall, and at 140 kg bodyweight the elite threshold is 419 kg ([hip thrust standards](https://strengthlevel.com/strength-standards/hip-thrust/kg)). A fixed 300 kg cap therefore covers elite squat, deadlift and front squat comfortably but clips the very strongest hip thrusters. That is what the auto-extend rule in §7 exists for; it is not worth degrading slider resolution for every squat user to accommodate a 400 kg hip thrust.

Minimum of 10 kg / 25 lb rather than 20 kg / 45 lb: gyms stock 15 kg women's Olympic bars, 10 kg technique bars and 25 lb training bars alongside the standard 20 kg / 45 lb bar ([Rogue](https://www.roguefitness.com/weightlifting-bars-plates/barbells?barweight=15KG), [bar-type list](https://ismartcalculator.com/tools/plate-weight-calculator/)). A deconditioned beginner or someone rehabbing genuinely squats a 10 kg bar, and a floor of 20 kg would make that unloggable.

Step of 2.5 kg / 5 lb is the smallest jump most gyms can actually produce: plates must be loaded in pairs, so a 1.25 kg pair is a 2.5 kg total change and a 2.5 lb pair is a 5 lb total change ([plate math](https://arvo.guru/tools/plate-calculator), [microloading](https://gymvalid.com/microloading-progression-calculator/)). Sub-2.5 kg jumps require fractional plates that most commercial gyms don't own, so they belong in the keypad, not on the slider.

### `barbellPress` — bench press, incline bench, overhead press, close-grip bench

Bench press is the heaviest press. Strength Level's male ladder is 47 / 70 / 98 / 132 / 169 kg and female is 17 / 31 / 51 / 74 / 101 kg (Strength Level bench data as summarised [here](https://www.strongermobileapp.com/blog/strength-standards)); ExRx tops its elite column at 425 lb ([ExRx bench](https://exrx.net/Testing/WeightLifting/BenchStandards)). Overhead press is far lighter — roughly 0.35× bodyweight at beginner and 1.2× at elite, about 96 kg for an 80 kg male ([ratio tables](https://strengthcalculator.org/strength-standards)). A 220 kg / 500 lb ceiling sits above the strongest raw bench most users will ever log while keeping the range 27% tighter than `barbellLower`, which buys back real dragging precision on the most-logged lift in the app.

### `barbellPull` — barbell row, Pendlay row, power clean, snatch, barbell shrug, barbell curl

Power clean tops out at a male elite 141 kg overall and 190 kg at 140 kg bodyweight ([power clean](https://strengthlevel.com/strength-standards/power-clean/kg)). Bent-over row sits near 81 kg intermediate for an 80 kg male ([LiftCodex row](https://liftcodex.com/strength-standards/bent-over-row/male/kg/)). Barbell curl is much lighter but shares the same implement and the same 2.5 kg / 5 lb loading granularity, so it lives here rather than getting its own category — the cost of an over-wide range on curls is resolution, not correctness, and the stepper mitigates it. A 200 kg / 450 lb ceiling covers heavy shrugs and elite cleans. Note the EZ-curl bar weighs 7–11 kg, slightly below the 10 kg floor; users on a light EZ bar will need the keypad or will round to 10 kg.

### `dumbbellHeavy` — dumbbell bench/incline press, dumbbell shoulder press, dumbbell row, goblet squat, dumbbell lunge, farmer's carry

**Dumbbell values are per dumbbell, and the UI must say so.** Strength Level is explicit: "Dumbbell weights are for one dumbbell and include the weight of the bar, normally 2 kg / 4.4 lb" ([dumbbell bench press](https://strengthlevel.com/strength-standards/dumbbell-bench-press/kg)). Without that label users will log a 2×30 kg set as 60 kg and corrupt their own history.

Dumbbell bench press male standards are 17 / 26 / 38 / 53 / 69 kg per hand; female 7 / 13 / 20 / 30 / 40 kg. That elite 69 kg figure exceeds what most gyms own: the standard commercial pro-style set is 2.5–50 kg in 2.5 kg increments, 20 pairs ([Titanium USA set](https://commercialfitnessequipment.com.au/products/2-5-to-50kg-pro-style-dumbbell-set-with-racks), [UK Gym Equipment](https://www.ukgymequipment.com/free-weights-c68/dumbbells-c9/2-5-50kg-premium-rubber-dumbbell-set-horizontal-racks-p5779), [Vulcan](https://vulcanfitness.com.au/products/vulcan-commercial-round-dumbbells-2-5kg-to-50kg-2-5kg-increments-20-sets-dumbbell-rack-in-stock)). A 60 kg / 150 lb ceiling covers the rack in a normal gym plus the well-equipped gyms that run to 150 lb, and reaches the elite standard.

Step of 2.5 kg / 5 lb matches the rack exactly — every value on the slider is a dumbbell that physically exists. Floor of 2.5 kg / 5 lb is the lightest dumbbell in a commercial pro set.

### `dumbbellLight` — lateral raise, front raise, rear-delt fly, dumbbell fly, dumbbell curl, triceps kickback, wrist curl

These are genuinely lighter and cluster in a narrow band. Lateral raise male standards are 4 / 9 / 16 / 24 / 34 kg per hand, female 3 / 6 / 9 / 13 / 18 kg ([lateral raise](https://strengthlevel.com/strength-standards/dumbbell-lateral-raise/kg)). Dumbbell curl is 7 / 13 / 21 / 31 / 42 kg male, 4 / 7 / 12 / 18 / 25 kg female ([dumbbell curl](https://strengthlevel.com/strength-standards/dumbbell-curl/kg)). Half the population logging lateral raises lives between 3 and 16 kg, so the 2.5 kg step used for heavy dumbbells would give a beginner woman only two usable positions between 3 kg and 9 kg.

Hence a **1 kg step in kg** — light dumbbells and adjustable/home sets do exist at 1, 2, 3 and 4 kg, and a 1 kg change on a lateral raise is a meaningful progression. The **lb step stays at 2.5 lb**, since a 1 lb step over a 2.5–90 lb range would produce 88 positions and destroy draggability. This is the one place the two ladders are asymmetric in granularity, and it's deliberate. Caveat to flag: light US dumbbell racks carry odd sizes (3, 8, 12 lb) that a 2.5 lb ladder can't hit — those users need the keypad.

### `machineCable` — lat pulldown, cable row, triceps pushdown, chest press machine, pec deck, leg extension, leg curl, cable fly

Typical selectorized stacks are 100 kg / 220 lb, built from 5 kg plates with an optional 2.5 kg add-on, and with a documented minimum start weight of 5 kg ([Pulse Fitness lat pulldown](https://pulsefitness.com/product/strength-selectorised-premium-lat-pulldown-380h-adb/), [UK Gym Equipment spec](https://www.ukgymequipment.com/strength-training-c8/strength-equipment-c25/premium-line-seated-lat-pulldown-with-10-1in-touchscreen-console-p5510)). US-spec machines commonly run 10 lb plates with a 5 lb increment weight and stacks up to 250 lb ([Spirit Fitness](https://www.spiritfitness.com/commercial/lat-pulldown), [Leadman 100 kg / 21+1 plates at 10 lb](https://www.leadmanfitness.com/functional-trainer/lat-pulldown-low-row-stand-alone.html)).

The 150 kg / 350 lb ceiling is above a 100 kg stack on purpose: male elite lat pulldown is 134 kg and at 140 kg bodyweight it's 177 kg ([lat pulldown](https://strengthlevel.com/strength-standards/lat-pulldown/kg)), and plenty of machines carry heavier stacks or added plates. Step of 2.5 kg / 5 lb reflects the plate-plus-add-on granularity that most premium machines offer.

Default of 25 kg / 50 lb is roughly quarter-stack, not mid-stack. Mid-stack of a 100 kg machine is 50 kg, which sits above the *beginner* lat pulldown threshold for men (42 kg) and more than double it for women (23 kg). The failure modes are asymmetric — seeding too light costs one extra pin change, seeding too heavy invites a failed rep on set one — so quarter-stack is the safer anchor.

### `legPressHeavy` — leg press, hack squat, belt squat, pendulum squat, plate-loaded sled machines

Sled leg press is one of the most-logged exercises on Strength Level (2.66M lifts) and plate-loaded sleds routinely carry loads far above any selectorized stack because the machine's leverage reduces effective resistance. A 400 kg / 900 lb ceiling keeps these exercises loggable without forcing every cable exercise onto a coarse ladder. Default of 60 kg / 135 lb approximates a lightly loaded sled (a couple of 20 kg or 45 lb plates per side) and is deliberately conservative. This ceiling is an equipment-capacity judgement, not a strength-standards figure — I did not find a citable elite leg-press number.

The pound step here is 5 lb, not 10 lb, and that asymmetry with the 5 kg metric step is intentional. US sleds are loaded with 45 lb plates, so the loads users actually report are 90, 135, 180, 225, 315 lb. A 10 lb ladder can express 90 and 180 but not 135, 225 or 315 — i.e. it would miss the single most common leg-press load in the country. The cost is that this is the one category where the slider is purely a rough-positioning tool (171 increments) and the nudge buttons and keypad do most of the real work.

### `kettlebell`

Kettlebells only exist in discrete commercial sizes, so the slider should only offer those sizes. Kilogram lines run 4–48 kg in 2 kg jumps through the mid range (4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 28, 32, 36, 40, 44, 48) ([REP Fitness](https://repfitness.com/products/kettlebells-kg), [Kodiak 4–56 kg](https://www.kodiaksports.com/products/kodiak-echo-cast-kettlebells-singles)). Pound-labelled lines run in 5 lb jumps from 5 lb up ([Kettlebell Kings comparison](https://www.kettlebellkings.com/pages/kettlebell-comparison)). A 2 kg / 5 lb step reproduces both lineups almost exactly.

Default of 8 kg / 20 lb: the widely repeated coaching starting points are 8 kg for women and 12 kg for men ([size guide](https://cookwithrome.com/kettle/what-size-kettle-bell-to-get/), [REP's own recommendation of 8–20 kg men / 6–12 kg women for strength work](https://repfitness.com/products/kettlebells-kg)). Seeding at 8 kg errs light, which is the right direction. If Pluri knows the user's sex at that point, seed 12 kg / 26 lb for men.

One caveat: kg-labelled bells convert to odd pound values (16 kg = 35 lb, 24 kg = 53 lb, 32 kg = 70 lb, 44 kg = 97 lb). A 5 lb ladder can't express 53 lb or 97 lb. Users in lb gyms with kg-stamped bells will need the keypad.

### `addedLoad` — weighted pull-up, weighted dip, weighted vest carries

Logged value is **added weight only**, not bodyweight plus load, and the UI must label it that way ("+ added"). Added-weight standards cluster at roughly 0–10 kg beginner, 10–25 kg novice, 25–45 kg intermediate, 45–70 kg advanced, 70 kg+ elite ([standards table](https://fitliferegime.com/max-weighted-pull-up-calculator/), [second source](https://fithealthregimen.com/max-weighted-pull-up-calculator/)). Expressed relatively: elite is adding at least your own bodyweight ([Liftoff](https://liftoffrank.com/blog/weighted-pull-up-standards)). A 100 kg / 220 lb ceiling covers elite; 0 is the floor and is a legitimate, meaningful value here.

Default of 0 with the label "Bodyweight": most people who log a pull-up are not adding weight, and the standards themselves note that beginners should build to 8–10 strict bodyweight reps before adding load ([Endura](https://endura.coach/weighted-pull-ups-1-rep-max-calculator/)).

Assisted variants (assisted pull-up machine, band-assisted) are *negative* load. Recommendation for v1: classify assisted machine variants as `machineCable` and label the field "assist" rather than introducing a negative range. Flag as an open question — it is a genuine product decision, not an engineering one.

### `noLoad` — push-up, air squat, plank, glute bridge (unloaded), band pull-apart, mobility work

See §6.

---

## 3. Increment recommendations, consolidated

One increment per category, chosen so that **every position on the slider is a load the user can physically produce**:

| Category | kg step | Why |
|---|---|---|
| All barbell | 2.5 | Smallest plate pair most gyms own (1.25 kg × 2) |
| `dumbbellHeavy` | 2.5 | Exactly the commercial rack lineup (2.5–50 kg) |
| `dumbbellLight` | 1 | Rack jumps are too coarse where the population lives (3–16 kg) |
| `machineCable` | 2.5 | Stack plate (5 kg) plus add-on weight (2.5 kg) |
| `legPressHeavy` | 5 | Sleds are loaded with 20/25 kg plates; the range demands a coarse step |
| `kettlebell` | 2 | Reproduces the commercial 4→48 kg lineup |
| `addedLoad` | 2.5 | Belt/vest plates are the same plates |
| `fallback` | 2.5 | Loadable on the widest variety of equipment |

Pound equivalents: 5 lb everywhere except `dumbbellLight`, which uses 2.5 lb. 5 lb is the smallest jump a 2.5 lb plate pair produces and it matches the increment weights fitted to US machines.

Sub-step precision (fractional plates, 1 kg microloads, odd 3/8/12 lb dumbbells) is real but rare. It belongs in the keypad, which should accept any value, not on the slider.

---

## 4. UX precedent and slider design

### What the leading apps actually do

| App | Weight entry mechanism |
|---|---|
| **Strong** | Prefills the previous session's weight and reps; tap the field to edit via numeric keypad. Includes a plate calculator showing what to load per side. Two taps to log an unchanged set. ([review](https://aitoolsbakery.com/blog/fitbod-vs-strong-app/)) |
| **Hevy** | Same pattern: previous weight and reps prefilled, tap to confirm or edit, keypad. The prefill is repeatedly cited as the main time-saver. ([review](https://aitoolsbakery.com/blog/hevy-vs-strong-app/)) |
| **Fitbod** | Algorithmically *recommends* the weight, user confirms or edits by keypad. |
| **Peloton Gym / Strength+** | Tap the movement card, tap the weight field, type the number. Saving prefills all subsequent rounds. Accepts 0 through 999.99 and decimals; the field locks once a round is marked complete. Weights are also adjustable from Apple Watch. ([Peloton support](https://support.onepeloton.com/s/article/14195473421332-Peloton-Gym), [Strength+ listing](https://apps.apple.com/us/app/peloton-strength/id6476712925)) |
| **Runna** | Tags each exercise card with its equipment type (the strength cards literally read "Bodyweight" under the exercise name). Coaching is RPE-anchored — "aim for 85–95% of your maximum effort… if you're asked to do 8 reps, pick a weight you could manage 10–12 with" — and it explicitly tells users to start with bodyweight and add load later. ([Runna strength](https://www.runna.com/training/strength-training)) |
| **Apple Fitness+ / Nike Training Club** | Class-led formats without per-set load logging; the instructor cues effort, the app records the session, not the weight. *(Stated from product familiarity — I could not find a primary source confirming the absence of a weight field, so treat as unverified.)* |

**Nobody ships a drag slider for this.** That's a signal worth taking seriously, not a gap in the market.

### Why a pure slider is risky

- **Precision.** NN/g's guidance is blunt: "Selecting a precise value using a slider is a difficult task requiring good motor skills… If picking an exact value is important to the goal of the interface, choose an alternate UI element" — and it names entering "current weight" in a form as a case where a slider is *not* okay ([NN/g](https://www.nngroup.com/articles/gui-slider-controls/)). The underlying constraint is the Accot–Zhai steering law: acquiring a precise value in a narrow track is slow and error-prone ([NN/g](https://www.nngroup.com/articles/sliders-knobs/)).
- **Range arithmetic.** On a ~300pt track, `barbellLower` in pounds is 135 steps, i.e. **2.2pt per increment**. A millimetre of thumb wobble is several 5 lb jumps. This is not fixable by tuning; it's what a generous range costs.
- **Context.** The user is mid-set, sweaty, breathing hard, often one-handed. Fine motor control is at its worst exactly when this control appears.
- **Accessibility.** NN/g specifically calls out users with motor difficulties and older users with less steady hands as being poorly served by sliders.

### Recommended design

Keep the slider — it's fast, it's a differentiator, and drag-to-set genuinely feels good — but make it the *coarse* control in a three-part input. NN/g's own prescription for this situation is "separate but linked controls for coarse and fine values" plus good defaults.

1. **Large numeric value above the slider**, with unit, updating live during the drag. Above, never below — a label below the track is covered by the user's thumb ([NN/g](https://www.nngroup.com/articles/gui-slider-controls/)), and the value must be in a fixed position rather than floating in the track.
2. **Snap to the category step**, with tick marks. Apple's HIG recommends tick marks to increase clarity and accuracy, and labelling only the minimum and maximum. Tick marks also happen to work around a live iOS 26 bug where a stepped `Slider` spams sensory feedback at the range boundaries ([Stack Overflow](https://stackoverflow.com/questions/79948820/swiftui-slider-spams-sensory-feedback), [write-up](https://www.technetexperts.com/swiftui-slider-feedback-spam-fixed/)).
3. **`−` and `+` buttons flanking the slider**, each moving exactly one step, 44pt minimum touch targets. These carry the precision load and are not optional.
4. **Tap the numeric value to type.** Opens a decimal keypad and accepts off-step values (3 lb dumbbells, 47.5 kg, 53 lb kettlebells). This is the escape hatch that makes the coarse slider defensible.
5. **Seed at the last logged weight for that exercise** (see §5). This is the single highest-leverage thing in the whole feature — every competitor's speed advantage comes from prefill, not from the input widget.
6. **Selection haptic on each increment crossing**, guarded so it fires only when the snapped value actually changes. Use `.sensoryFeedback(.selection, trigger:)` driven off the snapped state value, not off the raw drag.
7. **Accessibility:** set `accessibilityValue` to the spoken value with units ("forty-seven point five kilograms"), and confirm the adjustable action steps by the category step — SwiftUI's `Slider` already uses `step` for VoiceOver adjustment ([SwiftUI docs](https://developer.apple.com/documentation/swiftui/slider)). Thumb and nudge buttons at 44pt minimum. Verify the whole control with VoiceOver before shipping.
8. **Label the semantics on the control itself:** "per dumbbell" for dumbbells, "+ added" for weighted bodyweight, "total incl. bar" for barbells. Ambiguity here silently corrupts history and progression.
9. **Optional, barbell only:** a plate hint under the value ("20 kg bar + 2 × 20 kg + 2 × 5 kg"). Both Strong and Fitbod ship plate calculators and users rate them highly.

---

## 5. Default / starting position

Resolve in this order and stop at the first hit:

1. **The user's last logged weight for this exact exercise**, if within the last 90 days. Snap to the nearest step.
2. **A prescribed target from the plan**, if the program specifies a load for this set.
3. **The last logged weight for a sibling exercise** — same equipment type and same primary muscle group (e.g. seed incline dumbbell press from flat dumbbell press). Optional; skip if it complicates the first release.
4. **The category default from §1.**

Within a session, once set 1 is logged, seed sets 2+ at set 1's value. This is exactly Peloton's documented behaviour and it removes almost all input work from a normal straight-set exercise.

**Why the category defaults are what they are.** For barbell work the answer is unambiguous: the empty bar. Strength Level counts barbell loads as including the bar "normally 20 kg / 44 lb," ACSM's novice prescription is an 8–12RM load with technique established first, and the standard coaching instruction for a first session is literally "start with an empty barbell, a very light dumbbell, or light weight selected on the machine," then add 5–10 lb at a time until bar speed slows ([Barbell Medicine](https://www.barbellmedicine.com/blog/the-beginner-prescription-blog/), [ACSM position stand](https://www.acsm.org/docs/default-source/certification-documents/img-327023929-0001-(1).pdf?sfvrsn=283c5662_0), [British Weight Lifting via Healthline](https://www.healthline.com/health/how-to-start-lifting-weights)). Seeding at 20 kg / 45 lb both matches that advice and puts a landmark under the thumb.

For every other category the principle is the same: **err light.** A seed that's too light costs one pin change or one walk to the rack. A seed that's too heavy invites a failed rep, and Pluri's whole tone is that it doesn't set users up to fail. That's why machines seed at quarter-stack rather than the mid-stack that first intuition suggests, and why kettlebells seed at the women's starting size rather than the men's.

---

## 6. Bodyweight movements — recommendation

**Hide the slider. Log the set directly, and offer "+ Add weight" as a secondary affordance.**

For a push-up, air squat or plank, tapping "Log" should immediately record the set (reps or time as prescribed) with no slider, no drag and no decision. If the user taps the small "+ Add weight" text button, reveal the `addedLoad` slider — seeded at 0, labelled "+ added" — for the minority wearing a vest or holding a plate.

Rejected alternatives and why:

- *Show the slider with "Bodyweight" as the bottom-of-range option.* Semantically fine, but it makes every user perform a drag to express "nothing changed." Runna-style plans are dense with bodyweight work — the workout screenshot in this repo shows four consecutive bodyweight movements in one superset — so this tax lands on the most common case, not the rare one.
- *Always allow optional added weight inline.* Same problem, just with the control permanently occupying vertical space on cards that will never use it.

For bands, weight is not the right unit at all — a band has a force curve, not a load. Log completion only for v1. Band colour/level as a first-class logged attribute is a reasonable v2 candidate; note it as a future task rather than approximating it with kilograms.

---

## 7. Recommended implementation rules

Written to be implemented directly. `W` is the value the slider produces, in the user's display unit.

### R1 — Category resolution, in order

Normalise `exerciseName`, `equipmentName` and `muscleGroup` to lowercase, strip punctuation and collapse whitespace before matching. Evaluate rules top to bottom and return on the first match.

1. **No-load.** If `equipment` ∈ {bodyweight, body weight, none, band, resistance band, mini band, loop band, trx, suspension, mat, foam roller, stability ball, bosu} **and** `name` does not contain {weighted, vest, belt} → `noLoad`.
2. **Added load.** If `name` contains {pull-up, pull up, pullup, chin-up, chin up, chinup, dip, muscle-up} **and** `equipment` is not machine/cable-like → `addedLoad`. Also `addedLoad` if `name` contains {weighted, vest} and `equipment` ∈ {bodyweight, none, weighted, belt, vest}.
3. **Kettlebell.** If `equipment` or `name` contains {kettlebell, kb} → `kettlebell`.
4. **Heavy sled.** If `name` contains {leg press, hack squat, belt squat, pendulum squat} → `legPressHeavy`.
5. **Machine / cable.** If `equipment` contains {machine, cable, selectorized, selectorised, pin-loaded, pulley, stack, sled, assisted} → `machineCable`. (Exception: `smith machine` falls through to the barbell rules in step 7.)
6. **Dumbbell.** If `equipment` contains {dumbbell, db}:
   a. If `name` contains any *heavy-pattern* keyword {press, row, squat, deadlift, lunge, thruster, clean, snatch, swing, step-up, step up, farmer, goblet, shrug, pullover, carry} → `dumbbellHeavy`.
   b. Else if `name` contains any *light-pattern* keyword {raise, fly, flye, curl, kickback, extension, wrist, rotation, pull-apart} → `dumbbellLight`.
   c. Else if `muscleGroup` ∈ {shoulders, biceps, triceps, forearms, rear delts, arms} → `dumbbellLight`.
   d. Else → `dumbbellHeavy`.
7. **Barbell.** If `equipment` contains {barbell, bar, ez bar, ez-bar, trap bar, hex bar, smith, landmine}:
   a. If `name` contains {squat, deadlift, hip thrust, glute bridge, lunge, good morning, rdl, romanian, step-up, step up, calf raise} **or** `muscleGroup` ∈ {legs, quads, hamstrings, glutes, calves} → `barbellLower`.
   b. Else if `name` contains {row, clean, snatch, shrug, curl, high pull} **or** `muscleGroup` ∈ {back, lats, traps, biceps} → `barbellPull`.
   c. Else → `barbellPress`.
8. **Equipment known, movement unknown.** Map by equipment family: barbell → `barbellPress`, dumbbell → `dumbbellHeavy`, machine or cable → `machineCable`, kettlebell → `kettlebell`.
9. **Fallback.** Anything else, including missing or unrecognised equipment → `fallback`.

Ordering notes that matter: step 6a must precede 6b and 6c, or "dumbbell shoulder press" is misclassified as light by its muscle group. Step 2 must precede step 5, or "assisted pull-up machine" lands in `addedLoad` instead of `machineCable`. Step 1 must check equipment before name, or "weighted plank" ends up unloadable.

Graceful degradation is built in: a misclassification between two categories in the same family changes only the range and step, never correctness, because the keypad accepts any value and R4 extends any ceiling. The worst realistic outcome is a slider that feels slightly coarse or slightly short, which the user can still resolve in one tap.

### R2 — Range and step

Look up `{min, max, step, default}` from the §1 table using the resolved category **and the user's current display unit**. Do not convert one unit's table into the other.

### R3 — Snapping

`W = clamp(round((raw − min) / step) × step + min, min, max)`. Update state only when the snapped value differs from the current value. Fire the selection haptic off that state change, not off the raw drag — this is both correct and the documented workaround for the iOS 26 boundary feedback bug.

### R4 — Adaptive bounds

Before presenting the slider, widen the range to contain the seed and the user's history:

- `effectiveMax = max(categoryMax, ceilToStep(seed × 1.5))`
- `effectiveMin = min(categoryMin, floorToStep(seed))`

This is what lets a 400 kg hip thruster or a 200 kg leg presser keep using the slider without every other user paying for the range. It also means the fixed ceilings in §1 never hard-block anyone.

### R5 — Seeding

Apply the §5 precedence chain, then snap the result with R3. If the seed comes from history recorded in the other unit, convert then snap.

### R6 — Persistence and units

Persist **two** fields per logged set: `weightKg: Double` (canonical) and `enteredUnit: UnitMass`. Display in the user's current preference; when the display unit equals `enteredUnit`, render the originally entered number rather than a round-tripped conversion. Without this, a user who logs 45 lb sees 45 lb, switches to kg, switches back, and sees 45.1 lb. Use `Measurement<UnitMass>` for conversion, never a hardcoded 2.2.

### R7 — Labels

Render a unit-and-semantics caption on the control per category: `dumbbellHeavy`/`dumbbellLight` → "per dumbbell"; `addedLoad` → "added weight"; all barbell → "including bar"; `machineCable`/`legPressHeavy` → "as shown on the machine"; `kettlebell` → no caption needed.

### R8 — No-load exercises

For `noLoad`, render no slider. "Log" completes the set immediately. Render a low-emphasis "Add weight" button that, when tapped, switches the card to `addedLoad` for that set only.

### R9 — Accessibility

44pt minimum for the thumb and both nudge buttons. Set `accessibilityLabel` ("Weight") and `accessibilityValue` (formatted value with unit, via `Measurement.formatted`). Confirm VoiceOver's adjustable action moves by exactly one `step`. Support Dynamic Type on the numeric readout without truncation at the largest accessibility sizes — the value is the most important element on the control.

---

## 8. Open questions to record in `SPEC.md` §15

1. **Assisted movements.** Assisted pull-up / dip machines represent negative load. Interim decision above routes them to `machineCable` labelled "assist," which is semantically muddy and will make progression charts read backwards (more assist = less strength). Needs a product decision.
2. **Bands.** Logged as completion only for v1. Should band level/colour become a first-class logged attribute?
3. **Kettlebell and light-dumbbell odd sizes in pounds.** 53 lb and 97 lb bells, and 3/8/12 lb dumbbells, are unreachable on a 5 lb / 2.5 lb ladder. Acceptable to push these to the keypad, or should the lb kettlebell ladder be an explicit size list rather than a step?
4. **Per-side vs total for dumbbells.** Confirmed here as per-dumbbell, matching Strength Level. Worth stating in `SPEC.md` so it can't drift.
5. **Sex-aware defaults.** Kettlebell and machine seeds would be better with sex known (12 kg vs 8 kg). Is that available at log time, and do we want to use it?
6. **Slider vs keypad as primary.** Every major competitor uses a keypad with prefill. Recommend instrumenting the slider: measure edits-after-drag and keypad-fallback rate, and be willing to demote the slider if it's slower than a prefilled tap-to-confirm.

---

## 9. Source list

**Strength standards**
- Strength Level — [squat](https://strengthlevel.com/strength-standards/squat/kg), [deadlift](https://strengthlevel.com/strength-standards/deadlift/kg), [front squat](https://strengthlevel.com/strength-standards/front-squat/kg), [hip thrust](https://strengthlevel.com/strength-standards/hip-thrust/kg), [power clean](https://strengthlevel.com/strength-standards/power-clean/kg), [dumbbell bench press](https://strengthlevel.com/strength-standards/dumbbell-bench-press/kg), [dumbbell lateral raise](https://strengthlevel.com/strength-standards/dumbbell-lateral-raise/kg), [dumbbell curl](https://strengthlevel.com/strength-standards/dumbbell-curl/kg), [lat pulldown](https://strengthlevel.com/strength-standards/lat-pulldown/kg), [male tables by bodyweight (kg)](https://strengthlevel.com/strength-standards/male/kg), [male tables (lb)](https://strengthlevel.com/strength-standards/male/lb)
- ExRx.net — [methodology](https://exrx.net/Testing/WeightLifting/StrengthStandards), [squat](https://exrx.net/Testing/WeightLifting/SquatStandards), [deadlift](https://exrx.net/Testing/WeightLifting/DeadliftStandards), [bench press](https://exrx.net/Testing/WeightLifting/BenchStandards)
- Bodyweight-ratio summaries — [strengthcalculator.org](https://strengthcalculator.org/strength-standards), [Stronger](https://www.strongermobileapp.com/blog/strength-standards), [LiftCodex bent-over row](https://liftcodex.com/strength-standards/bent-over-row/male/kg/)
- Weighted pull-ups — [fitliferegime](https://fitliferegime.com/max-weighted-pull-up-calculator/), [fithealthregimen](https://fithealthregimen.com/max-weighted-pull-up-calculator/), [Liftoff](https://liftoffrank.com/blog/weighted-pull-up-standards), [Endura](https://endura.coach/weighted-pull-ups-1-rep-max-calculator/)

**Equipment reality**
- Bars and plates — [Rogue](https://www.roguefitness.com/weightlifting-bars-plates/barbells?barweight=15KG), [Arvo plate calculator](https://arvo.guru/tools/plate-calculator), [bar types and plate denominations](https://ismartcalculator.com/tools/plate-weight-calculator/), [microloading](https://gymvalid.com/microloading-progression-calculator/)
- Dumbbells — [Titanium USA 2.5–50 kg](https://commercialfitnessequipment.com.au/products/2-5-to-50kg-pro-style-dumbbell-set-with-racks), [UK Gym Equipment](https://www.ukgymequipment.com/free-weights-c68/dumbbells-c9/2-5-50kg-premium-rubber-dumbbell-set-horizontal-racks-p5779), [Vulcan](https://vulcanfitness.com.au/products/vulcan-commercial-round-dumbbells-2-5kg-to-50kg-2-5kg-increments-20-sets-dumbbell-rack-in-stock)
- Machine stacks — [Pulse Fitness (100 kg, 5 kg plates, 2.5 kg add-on, 5 kg min)](https://pulsefitness.com/product/strength-selectorised-premium-lat-pulldown-380h-adb/), [UK Gym Equipment spec](https://www.ukgymequipment.com/strength-training-c8/strength-equipment-c25/premium-line-seated-lat-pulldown-with-10-1in-touchscreen-console-p5510), [Spirit Fitness (250 lb, 10 lb plates, 5 lb increment)](https://www.spiritfitness.com/commercial/lat-pulldown), [Leadman (100 kg, 21+1 × 10 lb)](https://www.leadmanfitness.com/functional-trainer/lat-pulldown-low-row-stand-alone.html)
- Kettlebells — [REP Fitness kg line](https://repfitness.com/products/kettlebells-kg), [Kodiak 4–56 kg](https://www.kodiaksports.com/products/kodiak-echo-cast-kettlebells-singles), [Kettlebell Kings size comparison](https://www.kettlebellkings.com/pages/kettlebell-comparison), [sizing guide](https://cookwithrome.com/kettle/what-size-kettle-bell-to-get/)

**Programming / starting loads**
- [ACSM position stand on progression in resistance training](https://www.acsm.org/docs/default-source/certification-documents/img-327023929-0001-(1).pdf?sfvrsn=283c5662_0)
- [NSCA — Foundations of Fitness Programming](https://www.nsca.com/contentassets/8323553f698a466a98220b21d9eb9a65/foundationsoffitnessprogramming_201508.pdf), [NSCA — teaching movement patterns](https://www.nsca.com/education/articles/ptq/teaching-resistance-training-movement-patterns/)
- [Barbell Medicine — The Beginner Prescription](https://www.barbellmedicine.com/blog/the-beginner-prescription-blog/), [British Weight Lifting guidance via Healthline](https://www.healthline.com/health/how-to-start-lifting-weights)

**UX**
- [NN/g — Slider Design: Rules of Thumb](https://www.nngroup.com/articles/gui-slider-controls/), [NN/g — Sliders, Knobs, and Matrices](https://www.nngroup.com/articles/sliders-knobs/)
- [Apple HIG — Sliders](https://developer.apple.com/design/human-interface-guidelines/sliders), [SwiftUI Slider reference](https://developer.apple.com/documentation/swiftui/slider), [SwiftUI accessibility modifiers](https://developer.apple.com/documentation/swiftui/view-accessibility)
- [iOS 26 stepped-slider sensory feedback bug](https://stackoverflow.com/questions/79948820/swiftui-slider-spams-sensory-feedback), [analysis and workaround](https://www.technetexperts.com/swiftui-slider-feedback-spam-fixed/)
- [Slider anatomy and accessibility checklist](https://www.setproduct.com/blog/slider-ui-design)
- [Peloton Gym weight tracking](https://support.onepeloton.com/s/article/14195473421332-Peloton-Gym), [Peloton Strength+](https://apps.apple.com/us/app/peloton-strength/id6476712925), [Runna strength training](https://www.runna.com/training/strength-training), [Strong vs Hevy logging flows](https://aitoolsbakery.com/blog/hevy-vs-strong-app/), [Fitbod vs Strong](https://aitoolsbakery.com/blog/fitbod-vs-strong-app/)
