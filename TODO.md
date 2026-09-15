# Slice — what's left

State on 2026-09-15: v0.2.0 released, all 9 PRD phases complete, app in daily use.
Pick any item below, add a phase row to `.claude/PRPs/prds/slice.prd.md`, then run
`/ecc:prp-plan .claude/PRPs/prds/slice.prd.md` — the orchestration pattern (dry-run the plan,
Opus implements from `.claude/agents/slice-implementer.md`, verify, tag) is in the existing plans.

## Do once, by hand (no code)

- [ ] **Log out and back in** (or restart) so Notification Center drops its cached blank icon for
      `com.rezaahmadn.Slice`. Then check: a phase-end banner and System Settings → General →
      Login Items both show the red ring. Cause and proof: Phase 9 plan, "Verified facts".
- [ ] Keep the copy you run in `/Applications` and toggle **Launch at login** from that copy —
      macOS stores the path, so a toggle made from a build folder points at the build folder.
- [ ] **30-day hypothesis check (2026-10-15):** used every work/study session, no other timer
      opened? Record the verdict in the PRD "Success Metrics" table.

## Product backlog (PRD "Could" / open questions)

- [ ] Long break after N work sessions (classic 4-cycle Pomodoro). Model change in
      `PomodoroTimer` + one stepper in `SettingsView`.
- [ ] Global hotkey to start/pause (needs Accessibility permission or a Carbon hotkey; keep it
      dependency-free).
- [ ] Alarm extras: snooze button, choose the sound (`NSSound` system names), make the 2-minute
      sound cutoff a setting.
- [ ] Menu bar "icon only when idle" option (PRD open question — default today is always
      showing `25:00`).
- [ ] Full-screen break overlay as a third alert style (PRD open question).
- [ ] Keep the display awake during a work session (`IOPMAssertionCreateWithName`).
- [ ] Refresh `Design/screenshots/panel-settings.png` — it predates the Alert picker.

## Distribution

- [ ] **Developer ID + notarization** once an Apple Developer account exists. Only
      `.github/workflows/release.yml` changes (sign with the cert, `notarytool submit`,
      `stapler staple`); then delete the Gatekeeper paragraph from `README.md`.
- [ ] Optional Homebrew cask / Sparkle updates — only if other people actually use it.
- [ ] Lower `deploymentTarget` in `project.yml` from 26.0 (14.0 is realistic: `@Observable`,
      `MenuBarExtra`, `SMAppService` all exist there) if anyone on an older Mac asks.

## Engineering hygiene

- [ ] `Alarm` has no unit tests (pure AppKit). A smoke test that calls `Alarm.show(for:)` in the
      test host and asserts `NSApp.windows` grew, then `dismiss()`, would cover the regression
      that bit Phase 9 (`hidesOnDeactivate`).
- [ ] Bump `actions/checkout` / `softprops/action-gh-release` when the next majors land.
- [ ] Windows/Linux port stays a "vague maybe". If it becomes real: separate repo or
      `apps/` split — decided then, not now (see PRD Decisions Log).

## Known machine quirks (not bugs in the app)

- Crowded menu bar → new status items land under the notch; verify with the `osascript`
  accessibility probes in the plans, not screenshots.
- `sfltool dumpbtm` sometimes hangs; prove launch-at-login via relaunch + toggle state instead.
- AppleScript reserved words that broke validation scripts: `before`, `running`, `after`.
- `Logger.info` is not persisted; use `.notice` and `/usr/bin/log show` (zsh shadows `log`).
