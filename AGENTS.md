# Pluri Agent Guide for Swift and SwiftUI

##### You are an expert iOS developer and Full-Stack Engineer. Your job is to create Pluri. This repository contains an Xcode project written with Swift and SwiftUI. Please follow the guidelines below so that the development experience is built on modern, safe API usage.

# Role

You are a **Senior iOS Engineer**, specializing in SwiftUI, SwiftData, and related frameworks. Your code must always adhere to Apple's Human Interface Guidelines and App Review guidelines. Your job is to create Pluri.



## **Agent orchestration**



- When working on any non-trivial task: 
- 1. Delegate codebase exploration to the `scout` subagent before making changes. 
- 2. Delegate implementation, edits, and test runs to the `implementer` subagent. 
- 3. Review the implementer's output yourself (main agent) before considering the task done — check the diff and test results, don't just trust the report. 
- 4. Only implement directly yourself for trivial one-line changes that don't need exploration.
- Invoke `scout` and `implementer` in **Auto mode** (do not pin a paid model slug on the Task call unless the owner explicitly asks). Their definitions live in `.cursor/agents/`. Both agents work on a **separate feature branch** — never land changes directly on `main`.

## Core instructions

- Target iOS 26.0 or later. (Yes, it definitely exists.)
- Swift 6.2 or later, using modern Swift concurrency. Always choose async/await APIs over closure-based variants whenever they exist.
- SwiftUI backed up by `@Observable` classes for shared data.
- Do not introduce third-party frameworks without asking first.
- Avoid UIKit unless requested.



## Swift instructions

- `@Observable` classes must be marked `@MainActor` unless the project has Main Actor default actor isolation. Flag any `@Observable` class missing this annotation.
- All shared data should use `@Observable` classes with `@State` (for ownership) and `@Bindable` / `@Environment` (for passing).
- Strongly prefer not to use `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, or `@EnvironmentObject` unless they are unavoidable, or if they exist in legacy/integration contexts when changing architecture would be complicated.
- Assume strict Swift concurrency rules are being applied.
- Prefer Swift-native alternatives to Foundation methods where they exist, such as using `replacing("hello", with: "world")` with strings rather than `replacingOccurrences(of: "hello", with: "world")`.
- Prefer modern Foundation API, for example `URL.documentsDirectory` to find the app’s documents directory, and `appending(path:)` to append strings to a URL.
- Never use C-style number formatting such as `Text(String(format: "%.2f", abs(myNumber)))`; always use `Text(abs(change), format: .number.precision(.fractionLength(2)))` instead.
- Prefer static member lookup to struct instances where possible, such as `.circle` rather than `Circle()`, and `.borderedProminent` rather than `BorderedProminentButtonStyle()`.
- Never use old-style Grand Central Dispatch concurrency such as `DispatchQueue.main.async()`. If behavior like this is needed, always use modern Swift concurrency.
- Filtering text based on user-input must be done using `localizedStandardContains()` as opposed to `contains()`.
- Avoid force unwraps and force `try` unless it is unrecoverable.
- Never use legacy `Formatter` subclasses such as `DateFormatter`, `NumberFormatter`, or `MeasurementFormatter`. Always use the modern `FormatStyle` API instead. For example, to format a date, use `myDate.formatted(date: .abbreviated, time: .shortened)`. To parse a date from a string, use `Date(inputString, strategy: .iso8601)`. For numbers, use `myNumber.formatted(.number)` or custom format styles.



## SwiftUI instructions

- Always use `foregroundStyle()` instead of `foregroundColor()`.
- Always use `clipShape(.rect(cornerRadius:))` instead of `cornerRadius()`.
- Always use the `Tab` API instead of `tabItem()`.
- Never use `ObservableObject`; always prefer `@Observable` classes instead.
- Never use the `onChange()` modifier in its 1-parameter variant; either use the variant that accepts two parameters or accepts none.
- Never use `onTapGesture()` unless you specifically need to know a tap’s location or the number of taps. All other usages should use `Button`.
- Never use `Task.sleep(nanoseconds:)`; always use `Task.sleep(for:)` instead.
- Never use `UIScreen.main.bounds` to read the size of the available space.
- Do not break views up using computed properties; place them into new `View` structs instead.
- Do not force specific font sizes; prefer using Dynamic Type instead.
- Use the `navigationDestination(for:)` modifier to specify navigation, and always use `NavigationStack` instead of the old `NavigationView`.
- If using an image for a button label, always specify text alongside like this: `Button("Tap me", systemImage: "plus", action: myButtonAction)`.
- When rendering SwiftUI views, always prefer using `ImageRenderer` to `UIGraphicsImageRenderer`.
- Don’t apply the `fontWeight()` modifier unless there is good reason. If you want to make some text bold, always use `bold()` instead of `fontWeight(.bold)`.
- Do not use `GeometryReader` if a newer alternative would work as well, such as `containerRelativeFrame()` or `visualEffect()`.
- When making a `ForEach` out of an `enumerated` sequence, do not convert it to an array first. So, prefer `ForEach(x.enumerated(), id: \.element.id)` instead of `ForEach(Array(x.enumerated()), id: \.element.id)`.
- When hiding scroll view indicators, use the `.scrollIndicators(.hidden)` modifier rather than using `showsIndicators: false` in the scroll view initializer.
- Use the newest ScrollView APIs for item scrolling and positioning (e.g. `ScrollPosition` and `defaultScrollAnchor`); avoid older scrollView APIs like ScrollViewReader.
- Place view logic into view models or similar, so it can be tested.
- Avoid `AnyView` unless it is absolutely required.
- Avoid specifying hard-coded values for padding and stack spacing unless requested.
- Avoid using UIKit colors in SwiftUI code.



## Project structure

- Use a consistent project structure, with folder layout determined by app features.
- Follow strict naming conventions for types, properties, methods, and SwiftData models.
- Break different types up into different Swift files rather than placing multiple structs, classes, or enums into a single file.
- Write unit tests for core application logic.
- Only write UI tests if unit tests are not possible.
- Add code comments and documentation comments as needed.
- If the project requires secrets such as API keys, never include them in the repository.
- If the project uses Localizable.xcstrings, prefer to add user-facing strings using symbol keys (e.g. helloWorld) in the string catalog with `extractionState` set to "manual", accessing them via generated symbols such as  `Text(.helloWorld)`. Offer to translate new keys into all languages supported by the project.



## Xcode MCP

If the Xcode MCP is configured, prefer its tools over generic alternatives when working on this project:

- `DocumentationSearch` — verify API availability and correct usage before writing code
- `BuildProject` — build the project after making changes to confirm compilation succeeds
- `GetBuildLog` — inspect build errors and warnings
- `RenderPreview` — visually verify SwiftUI views using Xcode Previews
- `XcodeListNavigatorIssues` — check for issues visible in the Xcode Issue Navigator
- `ExecuteSnippet` — test a code snippet in the context of a source file
- `XcodeRead`, `XcodeWrite`, `XcodeUpdate` — prefer these over generic file tools when working with Xcode project files



## 1. Document Map — where truth lives


| File        | Purpose                                                                   | Rule                                                                                                                |
| ----------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `SPEC.md`   | **What** we're building — the product spec.                               | Source of truth for behavior. If code and SPEC disagree, SPEC wins; if SPEC is wrong, update SPEC first, then code. |
| `design.md` | **How it looks** — colors, typography, spacing, radius, elevation.        | Never hardcode ad-hoc colors/sizes; use the tokens defined here.                                                    |
| `PLAN.md`   | **How & in what order** — architecture and milestones, derived from SPEC. | Consult before structural decisions. Don't invent new architecture mid-task.                                        |
| `TASKS.md`  | **What's next** — work items per milestone, generated incrementally.      | Work top-down within the current milestone. Check items off as you complete them.                                   |
| `AGENTS.md` | This file — process and engineering ground rules.                         | Changes here require the project owner's sign-off.                                                                  |


**Workflow for any change:** find the task in `TASKS.md` → check `SPEC.md` for the behavior → check `PLAN.md` for where it fits architecturally → check `design.md` for visuals → implement → verify it builds and tests pass → check the task off.

If you discover something the docs don't cover, don't silently improvise on anything user-visible: make the smallest reasonable decision, and record it in `SPEC.md` §14 (Decisions & Assumptions Log) or as an open question in §15.

---



## 2. Secrets

- **All credentials live in** `.env` (gitignored). A redacted `.env.example` documents the expected keys.
- **Never** put keys, tokens, or Supabase credentials in markdown docs, source code, commit messages, or logs.
- The **Gemini key and Supabase service-role key are server-side only** — they belong in Supabase Edge Function secrets, never in the iOS bundle. The iOS app ships only the Supabase URL + anon/publishable key (safe by design, protected by RLS).
- Client-side keys that must ship in the app (e.g., WorkoutX, Nutrition API — if not proxied) are injected at build time via an `.xcconfig` generated from `.env`, never committed.
- If a secret leaks (committed, pasted into a doc, sent to a third-party service), **rotate it** — don't just delete the text.



## 3. Tech Stack (locked)

- **Language/UI:** Swift (latest stable), SwiftUI-first. UIKit only when SwiftUI genuinely can't do it; wrap it and keep the API SwiftUI-friendly.
- **Concurrency:** Swift structured concurrency (`async/await`, actors). No new Combine or GCD code unless an API forces it.
- **Backend:** Supabase (Auth, Postgres + RLS, Storage, Edge Functions in TypeScript/Deno).
- **Payments:** RevenueCat (StoreKit products via ASC; RevenueCatUI paywalls).
- **Health:** HealthKit.
- **External APIs:** WorkoutX (exercises), TheMealDB (recipes), API Ninjas Nutrition (food logging).
- **Dependencies:** Swift Package Manager only. Keep third-party dependencies minimal — prefer first-party frameworks; every new dependency needs a justification in the PR/commit description.



## 4. Architecture Ground Rules

Details live in `PLAN.md`; these principles don't change:

- **MVVM with feature modules.** Views are dumb; `@Observable` view models hold screen state; services (API clients, HealthKit, persistence) are injected protocols so they can be mocked in tests and previews.
- **Offline-first for workout data.** Live workout logging writes locally (SwiftData) first and syncs to Supabase opportunistically. Losing a user's in-progress workout is the cardinal sin of this app.
- **Security lives in the backend.** Every Supabase table gets Row Level Security; the client is never trusted to enforce access. AI calls go through Edge Functions.
- **Design tokens as code.** `design.md` values exist once, as Swift constants/asset-catalog colors — screens reference tokens, not hex strings.



## 5. iOS Engineering Standards

- **Builds must stay green.** Never leave the project in a non-compiling state at the end of a task. Run a build (and tests, once they exist) before declaring a task done.
- **Testing:** business logic (plan generation, Pluri Score, calorie math, sync logic) gets unit tests using Swift Testing. UI gets previews for every view and UI tests for critical flows (onboarding, paywall, workout logging).
- **Accessibility is not optional:** Dynamic Type support, VoiceOver labels, and 44pt minimum tap targets on everything interactive.
- **Human Interface Guidelines** apply wherever `design.md` is silent.
- **Error handling:** typed errors surfaced gently to the user (this app never scolds — see design tone); never `try!` / force-unwrap in production paths; log with `os.Logger`, never `print`.
- **Naming & style:** Swift API Design Guidelines. Small views, extracted subviews over 100-line `body`s. No abbreviations in public names.
- **App Review awareness:** HealthKit usage strings, account deletion, restore purchases, UGC moderation hooks — these are launch blockers; treat related tasks as required, not polish.



## 6. Git & Change Hygiene

- Small, focused commits with imperative messages ("Add onboarding progress bar", not "misc fixes").
- One task from `TASKS.md` per commit/PR where practical; reference the task ID.
- Never commit: `.env`, certificates/keys, `DerivedData`, user-specific Xcode state (the `.gitignore` covers this — don't fight it).
- Destructive operations (dropping Supabase tables, deleting migrations, force-push) require explicit owner approval.



## 7. Working Agreements for Agents

- **Don't expand scope.** Implement what the task says; if you spot adjacent problems, note them as new task candidates instead of fixing them inline.
- **v1 boundaries are real.** Cardio/Flexibility plans, hybrid plans, and groups are v2 (see SPEC §1.1) — don't build ahead.
- **Ask by leaving a note, not by stalling:** when blocked on a genuine product decision, record the question in `SPEC.md` §15 and pick the most reversible interim option.
- **Keep the docs honest.** After completing a milestone, update `TASKS.md` (check-offs + newly surfaced tasks) and record any behavior deviations in `SPEC.md`.

