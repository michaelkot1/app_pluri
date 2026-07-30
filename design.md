# Design.md — Pluri
Design Inspirtation app ["Genter Streak "](https://mobbin.com/apps/gentler-streak-ios-ccc0bb26-39b3-48fa-862d-2df69182840e/91403472-6e15-413b-ae56-0ad41f2ca6d2/screens)
Not everything but colors are good.
## 1. Visual Theme & Atmosphere

Pluri's atmosphere is **warm, soft, and reassuring** — aesthetic that rewards balance over exhaustion. The UI breathes: large
airy canvases, cushiony rounded cards, keeps it
approachable and non-clinical.

**Key Characteristics**

- **Sunrise warmth** — 
- **Gentle, never harsh** 
- **Cushioned & rounded** — 
- **Data made friendly** — rings, smooth line charts, and colored zone bars
  present health data in an inviting, digestible way.
- **Light-first & spacious** — default light mode on off-white/cream canvases;
  content floats with lots of negative space.

---

## 2. Color Palette & Roles

### Brand
| Token | Approx. Hex | Role |
|---|---|---|
| `brand/orange` | `#FF5C39` | Primary brand color — heart/logo, active tab, primary CTAs, key accents |
| `brand/orange-deep` | `#E8460F` | Pressed/darker orange, on-glow text over warm gradients |
| `brand/coral-soft` | `#FF7A59` | Softer coral for highlights and secondary accents |

### Sunrise Gradient (Hero)
| Token | Approx. Hex | Role |
|---|---|---|
| `sunrise/core` | `#F4A63B` | Warm center of the radial hero glow |
| `sunrise/mid` | `#F6C561` | Amber mid-ring |
| `sunrise/edge` | `#F3E7C4` | Faded cream outer edge blending into background |

### Status / Activity Path
| Token | Approx. Hex | Role |
|---|---|---|
| `status/green` | `#2FBF71` | "On path" / optimal / Rest & Active-Recovery success |
| `status/green-deep` | `#12A55A` | Rest CTA buttons, positive emphasis |
| `status/red-soft` | `#F0553C` | "Too high" / overexertion end of the path (gentle, not alarming) |
| `status/blue` | `#7FA8F5` | Recovery / calorie ring / cool accent |

### Heart-Rate Zones (spectrum)
| Zone | Approx. Hex |
|---|---|
| Zone 0 | `#B9D4EA` (pale blue) |
| Zone 1 | `#9FD9E6` (teal) |
| Zone 2 | `#F6D97A` (yellow) |
| Zone 3 | `#F4A85E` (orange) |
| Zone 4 | `#EF7C6B` (coral) |
| Zone 5 | `#C86BD8` (violet) |

### Accent Surfaces
| Token | Approx. Hex | Role |
|---|---|---|
| `accent/pink` | `#F26D82` | "Food you've burned" playful full-bleed card |
| `accent/lavender` | `#EEEFF6` | Cool onboarding / Go-Gentler background |

### Neutrals
| Token | Approx. Hex | Role |
|---|---|---|
| `bg/canvas` | `#FBFAF7` | App background (warm off-white/cream) |
| `bg/surface` | `#FFFFFF` | Cards, sheets, tab bar |
| `bg/muted` | `#F2F2F0` | Inset rows, secondary chips, unselected onboarding options |
| `text/primary` | `#1C1C1E` | Headlines, big numerals |
| `text/secondary` | `#6E6E73` | Labels, captions, metadata, onboarding subtitles |
| `text/tertiary` | `#B0B0B5` | Disabled, "No Data", axis labels |
| `line/divider` | `#ECECEC` | Hairline separators, chart gridlines |

### Selection (onboarding questionnaire)
| Token | Approx. Hex | Role |
|---|---|---|
| `selection/fill` | `#1C1C1E` (light) / `#F5F4F1` (dark) | Selected option row, tile, or chip fill — near-black, **not** brand orange |
| `selection/on-fill` | `#FFFFFF` (light) / `#1C1C1E` (dark) | Text/icon on top of `selection/fill` |

**Role principles**

- Orange is precious — reserve it for the single most important action on a
  screen (onboarding: the bottom Continue CTA only). Selected questionnaire
  options use `selection/fill`, never orange.
- Green = permission & balance (on-path, rest, recovery). Never use green to mean
  "go harder."
- Warm sunrise gradients belong to celebratory/hero data; keep them behind a
  single focal metric, not layered across a whole screen.
- Semantic red is intentionally softened to coral — this app never scolds.

---

## 3. Typography Rules

**Font Family**

- **Primary UI:** Apple system rounded sans — **SF Pro Rounded** (fall back to
  `-apple-system`, `Inter`, `system-ui`). The rounded terminals reinforce the
  gentle, friendly personality.

**Hierarchy**

| Style | Weight / Size | Usage |
|---|---|---|
| Hero Numeral | Bold, ~56–64pt | The one focal metric (steps, kcal, "Zone 0") |
| Display Numeral | Bold, ~34–40pt | Secondary big stats (147 kcal, 0.55 mi) |
| Title (H1) | Bold, ~26–28pt | Section headers ("Go Gentler", "Keep Track of Your Activities") |
| Section Header | Semibold, ~20–22pt | Card group titles ("Wellness", "Past Activities") |
| Body | Regular, ~16–17pt | Descriptive paragraphs, guidance copy |
| Metric Value | Bold, ~20pt | In-card numbers with a lighter unit suffix |
| Label / Caption | Medium, ~13–15pt | Field labels, dates, "Total Distance" |
| Overline | Semibold caps, ~12pt, tracked | Eyebrow labels ("ENERGY", "DISTANCE", "ACTIVITY HEART RATE") |



---

## 5. Layout Principles

**Spacing System** — Base unit of **4px**, primary rhythm on an **8px** scale.

| Token | Value | Typical use |
|---|---|---|
| `space/xs` | 4px | Icon-to-label gaps, value/unit spacing |
| `space/sm` | 8px | Chip padding, tight stacks |
| `space/md` | 16px | Default card padding, element gaps |
| `space/lg` | 24px | Section separation, screen side gutters |
| `space/xl` | 32px | Major section breaks, above hero |
| `space/2xl` | 48px+ | Around hero numerals and headers |

**Grid & Container**



**Whitespace Philosophy**

- **Whitespace is a feature, not filler.** Abundant negative space is core to the
  "gentle, unhurried" feel — resist the urge to fill it.

### Home data presentation

- **Schedule surface:** Calendar context and selected activity share one
  `bg/surface` card (`radius/lg`, Elevation 1). Use a compact seven-day strip;
  keep the month/completion label and View calendar action in the same card.
  Flexible sessions follow a divider under the label **Anytime this week**.
- **Pluri Score hero:** The score uses a 12pt circular track with a
  `brand/orange` → `sunrise/core` → `brand/coral-soft` angular fill. Place the
  existing sunrise radial gradient behind this ring at restrained opacity.
  This is the only ambient glow on Home. Show real consistency and Health
  components beside the ring; do not add achievement claims.
- **Health goal progress:** Use a two-column adaptive grid (collapse naturally
  for large Dynamic Type). A thin progress bar appears only when the user has
  explicitly saved a goal. Without one, show the user's available baseline and
  a 44pt **Set goal** action; never draw progress against a default target.
  Average heart rate is comparison-only and never receives a progress bar.
- **Metric accents:** Steps = `brand/orange`; Sleep = `status/blue`; Active
  Energy = `sunrise/core`; Average Heart Rate = `accent/pink`. Accent is limited
  to the icon well, progress fill, and goal action; values remain
  `text/primary` for consistent readability.

**Border Radius Scale**

| Token | Value | Usage |
|---|---|---|
| `radius/sm` | 8px | Small chips, inset elements |
| `radius/md` | 16px | Inputs, small tiles, **onboarding select rows & tiles** |
| `radius/lg` | 20–24px | Cards, sheets |
| `radius/xl` | 28px | Pill buttons, tab bar, onboarding Continue CTA |
| `radius/full` | 999px | Radios, thumbs, circular icons, capsule gauges |

---

## 5.1 Onboarding questionnaire patterns

Strava-inspired DNA for preference screens (keep Pluri content / progress bar):

- **Canvas:** Keep `bg/canvas` (`#FBFAF7` cream). Pure white would be closer to
  Strava, but cream matches Pluri’s warm atmosphere and still reads as a light
  airy questionnaire surface — do not switch to white unless product asks.
- **Title:** Large bold (`displayNumeral` / ~largeTitle); subtitle in
  `text/secondary` with airy spacing below.
- **Selection:** Full-width rounded rows (`OnboardingSelectRow`, `radius/md`)
  for text options and multi-select lists (training days, equipment items);
  2-col icon tiles (`OnboardingSelectTile`) for short icon sets (e.g. fitness
  type). Equipment (Q6) is a vertical categorized list (section overlines +
  `OnboardingSelectRow` per item). Training days (Q8) use the same row list
  with multi-select toggle. Dense multi-select that still fits chips
  (allergies, body areas) stays on `PluriChip` / `PluriChipGrid`. Selected
  state always uses `selection/fill` (black), not orange.
- **Injury severity (Q7):** After selecting body-area chips, each active area
  shows a 1–5 `Slider` (not steppers); tint with `selection/fill`. Empty
  injuries = healthy remains valid.
- **CTA:** Full-width pill Continue pinned at the bottom. Enabled = `brand/orange`
  + white label. Disabled = soft peach (`brand/coral-soft` at ~55% opacity) with
  slightly translucent white label — never leave Continue gated on nil required
  singles; seed defaults instead.
- **Defaults:** Required preference screens always have a preselected value
  (goal, experience, regularity, location, gender, etc.). Optional multi-selects
  like injuries may start empty (“healthy”).

---

## 6. Depth & Elevation

Depth is **soft and subtle** — achieved through gentle shadows and warm glows,
never hard borders or heavy drop shadows.

- **Elevation 0 — Canvas:** Flat warm off-white background; content sits directly
  on it with no shadow.
- **Elevation 1 — Cards:** Small, diffuse, low-opacity shadow
  (`0 2px 8px rgba(0,0,0,0.04–0.06)`) to gently lift white cards off the canvas.
- **Elevation 2 — Floating Tab Bar / Sheets:** Larger, softer shadow
  (`0 8px 24px rgba(0,0,0,0.10)`) so the detached pill bar and bottom sheets
  clearly hover above content.
- **Elevation 3 — Primary CTAs:** Colored buttons carry a subtle tinted shadow to
  signal tappability.
- **Ambient Glow (special):** The sunrise radial gradient behind hero metrics
  functions as "light" rather than shadow — a warm halo that draws focus without
  a container edge.
- **Layering order:** canvas → cards → gauges/charts → floating bar → sheets →
  modals, with shadow softness increasing up the stack.

---

## 7. Live Workout exercise card patterns

Cushioned `PluriCard` rows on the live Workout Screen (cream canvas, orange
accents — not a novel palette). Visual DNA may borrow spacing calm from
reference apps; content must come from real `PlannedExercise` / set-log data.

- **Prescription:** Derive copy from `sets` + `reps` only —
  `"{reps}–{reps+2} reps, repeat {sets} times"` (singular **time** when
  `sets == 1`). Never show terse `"4 × 5"`. Do not invent rest timers, duration
  prescriptions, supersets, or multi-part progress bars.
- **Log drawer:** Resting card shows media, name, equipment, prescription, a
  primary **Log** CTA (44pt), and a growing list of already-logged sets. Tapping
  Log expands an animated inline drawer; after a successful log the drawer
  collapses back to resting (no lingering weight/reps clutter).
- **Weighted logging:** Large live numeric weight, snapping slider, −/+ nudges,
  and reps −/+. Category min/max/step/default ladders live in
  `ExerciseWeightRange` and follow `Research/Log Weight Slider Research.md`
  (barbell / dumbbell / machine / kettlebell / added-load / fallback). Seed from
  the last logged weight in the session when available; else the category
  default. Persist kg; display per profile units.
- **Bodyweight / no-load:** When classification is `noLoad` (e.g. catalog
  `"Body Weight"`, bands), the drawer shows an in-card stopwatch and logs
  `durationSeconds` — never a fabricated “20 secs” prescription. Sets/reps
  prescription copy still shows when those ints exist.
- **Floating controls:** Keep the existing Start → Pause/Stop → Resume /
  Hold-to-Finish bar; do not invent secondary session “parts.”

---
