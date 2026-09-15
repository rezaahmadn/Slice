# Slice — Pomodoro Menu Bar Timer (macOS)

## Problem Statement

Reza wants a Pomodoro timer for coding, studying, and research sessions. Existing macOS Pomodoro apps are bloated (task lists, stats, sync, subscriptions) and are third-party binaries he does not trust running on his machine. The cost of not solving it: no clear time window per session, less commitment, lower productivity.

## Evidence

- Direct user statement: "existing apps too bloated, want minimal menu bar timer, I don't trust other third party app."
- Market survey (2026-09-15): most open-source menu bar Pomodoros (CapyTimer, stacksjs/pomodoro, bogdankim/pomodoro) grow task lists and notes over time. Minimal-and-staying-minimal is the exception (TomatoBar, pomodo-timer).
- Assumption — needs validation through use: that owning the code (vs. reading TomatoBar's open source) is what makes the trust difference. Honest framing: this is a personal tool and a Swift learning project, not a market gap.

## Proposed Solution

A single-purpose macOS menu bar app written in Swift/SwiftUI using `MenuBarExtra`. Menu bar shows the live countdown. Clicking opens a small popover with Start/Pause/Reset and current phase. Work and break durations are configurable; the app can launch at login. Notification plus sound on each phase transition. Custom app icon so it is not a generic tomato. Public GitHub repo; anyone can build from source in Xcode or download an unsigned build from GitHub Releases (right-click, Open). Chosen over a cross-platform toolkit because native menu bar feel, tiny binary, and learning Swift are the point.

## Key Hypothesis

We believe a minimal, self-built menu bar timer will give clear commit windows for work and study sessions.
We'll know we're right when Reza uses it for every work/study session for 30 consecutive days without reaching for another timer app.

## What We're NOT Building

- Task list / todo integration — the bloat being escaped
- Stats, history, streaks, charts — same
- iCloud/any sync, accounts, telemetry — trust requirement; zero network calls
- iOS / watchOS companion — out of scope
- Windows / Linux port — "vague maybe"; revisit only if real demand. Repo stays a plain single-app layout, no `apps/` monorepo nesting
- Mac App Store release — no Developer account, no sandbox work
- Developer ID signing + notarization — deferred until Reza has an account; README documents the right-click-Open workaround
- Global hotkey, sound picker, long-break cycle — deferred to post-MVP

## Success Metrics

| Metric | Target | How Measured |
|--------|--------|--------------|
| Daily use | Every work/study session, 30 consecutive days | Honest self-report; optional local-only session counter in UserDefaults |
| No substitution | 0 other timer apps opened in that window | Self-report |
| Build from clean clone | Cmd+R works in Xcode with zero manual setup | Test on a fresh clone |
| Weekend delivery | MVP runnable by end of build weekend | Calendar |
| Swift learning | Reza can explain every file in the repo | Self-check after build |

## Open Questions

- [ ] Notification style — **default: system banner via UserNotifications**. Full-screen break overlay only if banners prove too easy to ignore.
- [ ] Menu bar display when idle — **default: countdown always visible** (e.g. `25:00` when idle, `24:59` running). Icon-only mode later if it feels noisy.
- [ ] Keep screen awake during work phase — **default: no**. Add `IOPMAssertion` later if display sleep interrupts sessions.
- [ ] Deployment target — **default: macOS 26** (Reza's machine). Lower to 13 only if a cloner asks.
- [ ] Icon direction — needs a sketch. Constraint: recognizable at 16px menu bar size and 512px app icon size.

---

## Users & Context

**Primary User**
- **Who**: Reza. Developer, learning Swift, macOS 26.6 on Xcode 26.2.
- **Current behavior**: no timer, or tolerating a bloated one; sessions have no defined end.
- **Trigger**: sitting down to code, study, or research.
- **Success state**: glances at menu bar, sees time left, does not think about the timer otherwise.

**Job to Be Done**
When I sit down to work or study, I want a clear time window I can commit to, so I can stay focused and productive for that window.

**Non-Users**
People who want task tracking, statistics, sync, team features, or a polished App Store product. Cloners on macOS older than the deployment target. Ignored deliberately.

---

## Solution Detail

### Core Capabilities (MoSCoW)

| Priority | Capability | Rationale |
|----------|------------|-----------|
| Must | Countdown timer with work and break phases, auto-switch | The whole point |
| Must | Live countdown in menu bar (`MenuBarExtra`) | "Glance, don't think" |
| Must | Popover with Start / Pause / Reset and phase label | Minimum control surface |
| Must | Notification + sound on phase transition | Otherwise a break is missed |
| Must | Custom work/break durations, persisted in UserDefaults | User asked; defaults 25/5 |
| Must | Launch at login toggle (`SMAppService`) | User asked; timer must always be there |
| Must | Custom app + menu bar icon | User asked; not generic |
| Must | Public repo, buildable from clean clone, README with right-click-Open note | Sharing goal |
| Should | GitHub Actions workflow building an unsigned `.app` zip on tag, attached to Release | "Download the build" goal |
| Could | Long break after N cycles | Classic Pomodoro, small addition |
| Could | Global hotkey to start/pause | Convenience |
| Could | Sound picker / mute | Convenience |
| Won't | Task list, stats, sync, iOS, Windows/Linux, App Store, notarization | See Not Building |

### MVP Scope

Menu bar shows `25:00`. Click: popover with Start/Pause/Reset, phase name, gear to open settings (work minutes, break minutes, launch at login). Timer runs work, notifies, runs break, notifies, returns to idle work. Custom icon. Repo public with README. That is v1.

### User Flow

1. App launches (manually or at login). Menu bar shows icon + `25:00`.
2. User clicks menu bar item, hits Start. Popover closes. Menu bar counts down.
3. At `00:00`: banner "Work done — take a break" + sound. Timer starts 5:00 break automatically.
4. At `00:00`: banner "Break over — back to work" + sound. Timer returns to idle `25:00` (does not auto-start work; user commits deliberately).
5. Any time: click, Pause or Reset.

---

## Technical Approach

**Feasibility**: HIGH

**Architecture Notes**
- Swift 6.2 / SwiftUI, Xcode project (not SwiftPM-only) because `.app` bundle, icon asset catalog, and Info.plist keys (`LSUIElement = YES` to hide Dock icon) are simplest in Xcode.
- `MenuBarExtra` with `.menuBarExtraStyle(.window)` for a popover-style panel.
- One `@MainActor @Observable final class PomodoroTimer` owns all state (phase, remaining seconds, running flag, durations). Keeping everything on the main actor sidesteps Swift 6 strict-concurrency `Sendable` errors — the top beginner pitfall. Comment explains why.
- Tick source: `Timer.publish` or `Task.sleep` loop. Store the *end date*, not a decrementing counter, so sleeping the Mac does not drift the timer.
- Persistence: `@AppStorage` / `UserDefaults` for durations and launch-at-login preference. No files, no network.
- Notifications: `UserNotifications` framework; request permission on first Start, not at launch.
- Launch at login: `SMAppService.mainApp` (macOS 13+). Note: unsigned/ad-hoc builds may need re-toggling after rebuild because the bundle signature changes.
- Signing: "Sign to Run Locally" locally. CI builds with `CODE_SIGN_IDENTITY=-` (ad-hoc). Swap to Developer ID + `notarytool` later; only the CI step changes.
- Code style for learning: one concept per file (`PomodoroTimer.swift`, `MenuBarView.swift`, `SettingsView.swift`, `Notifications.swift`, `App.swift`). Comments explain intent and Swift/SwiftUI concepts on first use, not line-by-line narration.
- Deployment target macOS 26. Repo layout: flat, single Xcode project at root. No monorepo.

**Technical Risks**

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Swift 6 strict concurrency errors block a beginner | M | All state `@MainActor`; avoid `DispatchQueue`; comment the pattern once |
| Timer drifts after Mac sleep | M | Store end `Date`, recompute remaining on each tick |
| Gatekeeper blocks downloaded release for other users | H (certain) | README: right-click, Open; or build from source. Notarize later |
| Launch-at-login flaky with ad-hoc signature | M | Document; acceptable for personal use |
| Icon looks bad at 16px | M | Design as simple silhouette; test in menu bar early; template image (monochrome) for menu bar, full color for app icon |
| Scope creep (task list temptation) | L now, H later | "Won't" list in this PRD; README states non-goals |

---

## Implementation Phases

<!--
  STATUS: pending | in-progress | complete
  PARALLEL: phases that can run concurrently
  DEPENDS: phases that must complete first
  PRP: link to generated plan file once created
-->

| # | Phase | Description | Status | Parallel | Depends | PRP Plan |
|---|-------|-------------|--------|----------|---------|----------|
| 1 | Project skeleton | Xcode project, `LSUIElement`, `MenuBarExtra` showing static `25:00`, git init, README stub, .gitignore | complete | - | - | [plan](../plans/phase-1-project-skeleton.plan.md) |
| 2 | Timer core | `PomodoroTimer` model: phases, start/pause/reset, end-date ticking, auto-switch | complete | - | 1 | [plan](../plans/phase-2-timer-core.plan.md) |
| 3 | Menu bar UI | Live countdown in menu bar, popover with controls and phase label | complete | with 4 | 2 | [plan](../plans/phase-3-menu-bar-ui.plan.md) |
| 4 | Notifications | Permission request, banner + sound on transitions | in-progress | with 3 | 2 | [plan](../plans/phase-4-notifications.plan.md) |
| 5 | Settings | Custom durations, launch at login, persisted | pending | with 6 | 3 | - |
| 6 | Custom icon | App icon set + monochrome menu bar template image | pending | with 5 | 1 | - |
| 7 | Public release | README (build, right-click-Open, non-goals), LICENSE, GitHub Actions unsigned build on tag | pending | - | 5, 6 | - |

### Phase Details

**Phase 1: Project skeleton**
- **Goal**: Something runs in the menu bar; repo exists.
- **Scope**: New macOS App target (SwiftUI), `LSUIElement=YES`, `MenuBarExtra` with hardcoded label, `.gitignore` for Xcode, README title only.
- **Success signal**: Cmd+R shows `25:00` in menu bar, no Dock icon.

**Phase 2: Timer core**
- **Goal**: Correct Pomodoro state machine, independent of UI.
- **Scope**: `@MainActor @Observable` class; `Phase` enum (work, break, idle); start/pause/reset; end-date based remaining time; auto-transition work→break→idle. Unit tests for transitions.
- **Success signal**: Tests pass; model survives simulated sleep (end date approach).

**Phase 3: Menu bar UI**
- **Goal**: Control the timer from the menu bar.
- **Scope**: Menu bar label bound to remaining time; `.window` style popover with Start/Pause/Reset, phase text, gear button.
- **Success signal**: Full work→break cycle driven from UI.

**Phase 4: Notifications**
- **Goal**: Never miss a transition.
- **Scope**: `UNUserNotificationCenter` permission on first Start; local notification with default sound at each transition.
- **Success signal**: Banner + sound fire when app is in background.

**Phase 5: Settings**
- **Goal**: User-chosen durations and always-on presence.
- **Scope**: Settings view (or scene) with work/break minute steppers, launch-at-login toggle via `SMAppService`; `@AppStorage` persistence; model reads durations on reset.
- **Success signal**: Values survive relaunch; app appears after login.

**Phase 6: Custom icon**
- **Goal**: Distinct identity.
- **Scope**: Design concept (sketch), export `AppIcon` asset set (1024 base), 16/32pt monochrome template PNG for menu bar. Generated as SVG then rasterized.
- **Success signal**: Icon readable at 16px in menu bar and in Finder.

**Phase 7: Public release**
- **Goal**: Others can build or download.
- **Scope**: README with screenshots, build steps, Gatekeeper workaround, explicit non-goals; MIT LICENSE; `release.yml` that runs `xcodebuild` with ad-hoc signing, zips `.app`, uploads to GitHub Release on `v*` tag.
- **Success signal**: Fresh clone builds; tagged release produces downloadable zip that opens after right-click-Open.

### Parallelism Notes

Phases 3 and 4 both depend only on the timer model and touch different files. Phases 5 and 6 are independent (settings code vs. icon assets). For a solo weekend, "parallel" mostly means "order does not matter"; suggested order is 1→2→3→4→6→5→7 so the icon shows up early for motivation.

---

## Decisions Log

| Decision | Choice | Alternatives | Rationale |
|----------|--------|--------------|-----------|
| Repo layout | Single flat Mac repo | Monorepo with `apps/mac` + `apps/cross` | Windows/Linux is a vague maybe; nesting now is premature. `git mv` is cheap later |
| Stack | Swift 6.2 + SwiftUI `MenuBarExtra` | Tauri, Electron, Flutter, AppKit `NSStatusItem` | Native feel, tiny binary, learning Swift is a goal; `MenuBarExtra` is the least code |
| Deployment target | macOS 26 | 13 (widest `MenuBarExtra` support) | Only Reza's Mac matters now; newest APIs, no compat code |
| Distribution | Ad-hoc signed, GitHub Releases, right-click-Open documented | Developer ID + notarization; source-only | No Developer account yet; upgrade path is a CI-only change |
| Timer implementation | Store end `Date`, recompute | Decrement counter each tick | Survives sleep and timer coalescing |
| Concurrency | Everything `@MainActor` | Actors, GCD | Avoids Swift 6 strict-concurrency friction for a beginner |
| Persistence | `UserDefaults` / `@AppStorage` | SwiftData, JSON file | Two integers and a bool; anything more is bloat |
| Break → work | Return to idle, user starts next work manually | Auto-start next work | Deliberate commitment matches the JTBD |
| Notifications | System banner | Full-screen overlay | Simplest; revisit if ignored |
| Icon | Custom, monochrome template for menu bar | SF Symbol `timer` | User asked for non-generic |

---

## Research Summary

**Market Context**
Crowded space of open-source Swift menu bar Pomodoros. TomatoBar (ivoronin) is the minimal reference; viraptor/pomodoro is a clean `MenuBarExtra` + `UserDefaults` code reference; pomodo-timer targets ultra-low CPU. Common drift: projects add task lists and notes. This app's value is personal ownership and staying minimal, not novelty.

Sources: https://github.com/ivoronin/TomatoBar , https://github.com/viraptor/pomodoro , https://github.com/berkaycit/pomodo-timer , https://github.com/bogdankim/pomodoro , https://github.com/stacksjs/pomodoro

**Technical Context**
Environment verified 2026-09-15: macOS 26.6.2, Xcode 26.2 (17C52), Swift 6.2.3. `MenuBarExtra` (macOS 13+), `SMAppService` (13+), `UserNotifications`, `@Observable` (14+) cover every Must. Distribution outside the App Store without Developer ID means Gatekeeper prompts for downloaders; notarization requires a paid account and hardened runtime, deferred.

Sources: https://help.apple.com/xcode/mac/current/en.lproj/dev033e997ca.html , https://www.dolthub.com/blog/2024-10-22-how-to-publish-a-mac-desktop-app-outside-the-app-store/

---

*Generated: 2026-09-15*
*Status: DRAFT - needs validation*
