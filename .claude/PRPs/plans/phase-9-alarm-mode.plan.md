# Plan: Phase 9 — Alarm Mode

## Summary
Add an **Alert style** setting: *Banner* (today's behaviour) or *Alarm* — the banner plus a floating window above everything, on every Space, with a looping sound until the user clicks Dismiss (sound stops by itself after 2 minutes; the window stays). Also fix two icon issues found on the way: ship the full 16–512 px app icon set, and add `CFBundleIconName` so modern system lookups (Notification Center, Login Items) find the icon. Ships as v0.2.0.

**Dry-run on this machine on 2026-09-15 on top of v0.1.1: build clean, `✔ Test run with 16 tests in 4 suites passed`; with `alertStyle=alarm` and a 1-minute work phase the log showed `Alarm shown: Work done`, accessibility saw one window with static texts `Work done, Take a break.` and one button, clicking it closed the window and logged `Alarm dismissed`. The segmented picker is `radio group 1 of group 1 of window 1`, buttons 1 = Banner, 2 = Alarm.** Copy every file exactly.

## User Story
As Reza, I want an option that behaves like an alarm clock — impossible to miss, on screen and audible until I acknowledge it — because a banner is too easy to ignore mid-focus.

## Problem → Solution
One transient banner → user-selectable Alarm style backed by an `NSPanel` (`.floating`, all Spaces, `hidesOnDeactivate = false`) hosting a SwiftUI view, plus a looping `NSSound`.

## Metadata
- **Complexity**: Medium
- **Source PRD**: `.claude/PRPs/prds/slice.prd.md`
- **PRD Phase**: 9 — Alarm mode
- **Estimated Files**: 4 created, 4 edited, 10 PNGs regenerated, `Info.plist` + `project.pbxproj` regenerated

---

## UX Design

### Before
```
Work ends → banner + one sound.
Settings: Work / Break / Launch at login
```

### After
```
Settings: Work / Break / Launch at login / Alert: [Banner | Alarm]
Alarm mode, work ends →
   banner (as before)
 + centered floating window:  ⏰  Work done  /  Take a break.  /  [Dismiss]
 + "Glass" sound looping until Dismiss (max 2 min)
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| Settings | 3 rows | + segmented "Alert" picker | `@AppStorage("alertStyle")`, default `banner` |
| Phase end (Alarm) | banner | banner + window + looping sound | Style is re-read at each phase end, no relaunch |
| Dismiss | — | click or Return | stops sound, closes window |
| Notification banner icon | blank on this Mac | correct after logout/restart | see Notes |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `Slice/SliceApp.swift` | `init()` | 5-line edit inside `onPhaseCompleted` |
| P0 | `Slice/SettingsView.swift` | properties + `body` | Two insertions |
| P0 | `Slice/Notifications.swift` | `content(for:)` | Reused for the alarm text |
| P0 | `project.yml` | `info.properties` | One insertion after `LSUIElement: true` |
| P1 | `Slice/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` | all | Replaced |
| P1 | `Scripts/render-icon.swift`, `Design/AppIcon.svg` | — | Used to render the icon set |

## External Documentation

| Topic | Source | Key Takeaway |
|---|---|---|
| NSPanel | https://developer.apple.com/documentation/appkit/nspanel | `hidesOnDeactivate` defaults to true for panels |
| NSWindow.Level / collectionBehavior | https://developer.apple.com/documentation/appkit/nswindow/level | `.floating`; `.canJoinAllSpaces`, `.fullScreenAuxiliary` |
| NSHostingView | https://developer.apple.com/documentation/swiftui/nshostingview | Hosts SwiftUI inside AppKit windows |
| NSSound | https://developer.apple.com/documentation/appkit/nssound | `NSSound(named:)` finds system sounds; `loops = true` |
| CFBundleIconName | https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleiconname | Asset-catalog icon name for modern lookups |

Verified facts (from the dry run — treat as law):

KEY_INSIGHT: An `NSPanel` shown by a menu bar (LSUIElement) app disappears immediately unless `hidesOnDeactivate = false` — the app is never "active", so the default hides it. Also give the panel an explicit size; a hosting view has no fitting size before it is in a window.
APPLIES_TO: `Alarm.swift`.

KEY_INSIGHT: AppleScript reserved words seen so far: `before`, `running`, `after`. The validation scripts avoid them; do not rename variables.
APPLIES_TO: Validation 4.

KEY_INSIGHT: Xcode emits only 16/128 px into `AppIcon.icns` even with the full set; the rest live in `Assets.car`. That is normal.
APPLIES_TO: Task 6.

KEY_INSIGHT: Notification Center caches an app's icon per bundle ID when it first registers; on this Mac it registered in Phase 4 with no icon, so banners show a blank glyph until the next logout/restart. A never-seen bundle ID renders the icon correctly. Not fixable from the app; do not chase it.
APPLIES_TO: Notes.

---

## Patterns to Mirror

### NAMESPACE_ENUM + LOGGING
// SOURCE: `Slice/Notifications.swift` — case-less `enum`, `private static let logger = Logger(subsystem: "com.rezaahmadn.Slice", category: "<Type>")`, `.notice` with `privacy: .public`.

### VIEW_STRUCTURE / COMMENT_STYLE
// SOURCE: `Slice/SettingsView.swift`, `Slice/AlarmView.swift` (new) — `///` on the type, `//` explaining why, `#Preview` at the bottom.

### TEST_STRUCTURE
// SOURCE: `SliceTests/NotificationsTests.swift` — `struct XTests { @Test func ... { #expect } }`.

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `Slice/AlertStyle.swift` | CREATE | Enum + defaults loader |
| `Slice/AlarmView.swift` | CREATE | Window content |
| `Slice/Alarm.swift` | CREATE | Panel + sound lifecycle |
| `SliceTests/AlertStyleTests.swift` | CREATE | 3 tests |
| `Slice/SliceApp.swift` | EDIT | Call `Alarm.show` when style is `.alarm` |
| `Slice/SettingsView.swift` | EDIT | Picker |
| `project.yml` | EDIT | `CFBundleIconName` |
| `Slice/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` | REPLACE | Full set |
| `Slice/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-{16,32,128,256,512}{,@2x}.png` | GENERATE | 10 files (the two 512 files are re-rendered, identical content) |
| `Slice/Info.plist`, `Slice.xcodeproj/project.pbxproj` | REGENERATE | `xcodegen generate` |
| `README.md` | EDIT | One bullet under "Using it" |

## NOT Building
- Snooze, custom sound picker, volume control
- Full-screen takeover / blocking input
- Different alarm for work vs break (same window, different text)

---

## Step-by-Step Tasks

All commands run from `/Users/reza/Slice`. Use absolute paths.

### Task 1: Create `Slice/AlertStyle.swift`
- **ACTION**: Create with EXACTLY:
```swift
import Foundation

/// How Slice gets your attention when a phase ends.
/// Stored in `UserDefaults` under `alertStyle` as its raw string.
enum AlertStyle: String, CaseIterable {
    /// A normal macOS notification banner with one sound.
    case banner
    /// The banner plus a floating window and a looping sound until dismissed.
    case alarm

    static let defaultsKey = "alertStyle"

    /// Reads the saved style; anything missing or unknown falls back to `.banner`.
    static func load(from defaults: UserDefaults = .standard) -> AlertStyle {
        guard let raw = defaults.string(forKey: defaultsKey) else { return .banner }
        return AlertStyle(rawValue: raw) ?? .banner
    }
}
```
- **VALIDATE**: Validation 1.

### Task 2: Create `Slice/AlarmView.swift`
- **ACTION**: Create with EXACTLY:
```swift
import SwiftUI

/// Contents of the alarm window: what ended, and one big Dismiss button.
struct AlarmView: View {
    let title: String
    let message: String
    /// Called when the user clicks Dismiss (or presses Return).
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 44))
                .foregroundStyle(.red)
            Text(title)
                .font(.title)
                .bold()
            Text(message)
                .foregroundStyle(.secondary)
            Button("Dismiss", action: onDismiss)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
        .padding(32)
        .frame(width: 360)
    }
}

#Preview {
    AlarmView(title: "Work done", message: "Take a break.") {}
}
```
- **GOTCHA**: The text property is named `message`, not `body` — `body` is SwiftUI's.
- **VALIDATE**: Validation 1.

### Task 3: Create `Slice/Alarm.swift`
- **ACTION**: Create with EXACTLY:
```swift
import AppKit
import SwiftUI
import os

/// The "alarm" alert style: a floating window above everything, on every Space,
/// plus a looping sound, until the user clicks Dismiss. Not a notification, so
/// Focus modes cannot hide it.
///
/// `@MainActor` because it owns AppKit objects; a case-less enum with static
/// state is enough since there is only ever one alarm at a time.
@MainActor
enum Alarm {
    private static let logger = Logger(subsystem: "com.rezaahmadn.Slice", category: "Alarm")

    /// Stop the sound after this long even if nobody clicks Dismiss.
    /// The window stays until dismissed.
    static let soundCutoff: TimeInterval = 120

    /// Name of a system sound in /System/Library/Sounds.
    static let soundName = "Glass"

    private static var panel: NSPanel?
    private static var sound: NSSound?
    private static var cutoffTask: Task<Void, Never>?

    /// Shows the window and starts the looping sound for the phase that ended.
    static func show(for finished: PomodoroTimer.Phase) {
        dismiss()   // one alarm at a time
        let (title, message) = Notifications.content(for: finished)

        let view = AlarmView(title: title, message: message) { dismiss() }
        // `NSHostingView` wraps a SwiftUI view so AppKit windows can show it.
        let hosting = NSHostingView(rootView: view)
        // Give the panel a real size up front; a SwiftUI hosting view has no
        // fitting size until it is inside a window, and a zero-size window is invisible.
        let size = NSSize(width: 360, height: 260)
        hosting.frame = NSRect(origin: .zero, size: size)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.contentView = hosting
        // `.floating` sits above normal windows; the collection behavior makes it
        // follow you to every Space and over full-screen apps.
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        // Panels hide when their app deactivates — which, for a menu bar app, is
        // always. Turn that off or the alarm vanishes the instant it appears.
        panel.hidesOnDeactivate = false
        panel.center()
        panel.orderFrontRegardless()
        NSApp.activate()
        Self.panel = panel

        if let s = NSSound(named: NSSound.Name(soundName)) {
            s.loops = true
            s.play()
            sound = s
        }
        cutoffTask = Task {
            try? await Task.sleep(for: .seconds(soundCutoff))
            sound?.stop()
        }
        logger.notice("Alarm shown: \(title, privacy: .public)")
    }

    /// Stops the sound and closes the window. Safe to call when nothing is showing.
    static func dismiss() {
        cutoffTask?.cancel()
        cutoffTask = nil
        sound?.stop()
        sound = nil
        if panel != nil {
            logger.notice("Alarm dismissed")
        }
        panel?.close()
        panel = nil
    }
}
```
- **GOTCHA**: Keep `hidesOnDeactivate = false` and the explicit 360×260 size. Keep `.notice` logging.
- **VALIDATE**: Validation 1 and 4.

### Task 4: Create `SliceTests/AlertStyleTests.swift`
- **ACTION**: Create with EXACTLY:
```swift
import Foundation
import Testing
@testable import Slice

/// Uses a throwaway `UserDefaults` suite so tests never touch real preferences.
struct AlertStyleTests {
    private func freshDefaults() -> UserDefaults {
        let name = "AlertStyleTests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func missingKeyMeansBanner() {
        #expect(AlertStyle.load(from: freshDefaults()) == .banner)
    }

    @Test func savedAlarmIsRead() {
        let d = freshDefaults()
        d.set("alarm", forKey: AlertStyle.defaultsKey)
        #expect(AlertStyle.load(from: d) == .alarm)
    }

    @Test func unknownValueFallsBackToBanner() {
        let d = freshDefaults()
        d.set("klaxon", forKey: AlertStyle.defaultsKey)
        #expect(AlertStyle.load(from: d) == .banner)
    }
}
```
- **VALIDATE**: Validation 2 shows 16 tests in 4 suites.

### Task 5: Edit `Slice/SliceApp.swift`
- **ACTION**: Replace this block inside `init()`:
```swift
        // Wire the model's completion hook to notifications once, at launch.
        timer.onPhaseCompleted = { finished in
            Notifications.post(for: finished)
        }
```
with EXACTLY:
```swift
        // Wire the model's completion hook once, at launch. The alert style is
        // re-read every time so a change in Settings applies without a relaunch.
        timer.onPhaseCompleted = { finished in
            Notifications.post(for: finished)
            if AlertStyle.load() == .alarm {
                Alarm.show(for: finished)
            }
        }
```
- **VALIDATE**: `grep -c "Alarm.show(for: finished)" Slice/SliceApp.swift` prints `1`.

### Task 6: Edit `Slice/SettingsView.swift`
- **ACTION** (a): After the line `    @AppStorage("breakMinutes") private var breakMinutes = 5` insert EXACTLY:
```swift
    /// Stored as the enum's raw string so `@AppStorage` can hold it.
    @AppStorage(AlertStyle.defaultsKey) private var alertStyle = AlertStyle.banner.rawValue
```
- **ACTION** (b): After the line `            Toggle("Launch at login", isOn: $launchAtLogin)` insert EXACTLY:
```swift
            // Banner = one notification. Alarm = banner + floating window + looping
            // sound until you click Dismiss.
            Picker("Alert", selection: $alertStyle) {
                Text("Banner").tag(AlertStyle.banner.rawValue)
                Text("Alarm").tag(AlertStyle.alarm.rawValue)
            }
            .pickerStyle(.segmented)
```
- **VALIDATE**: `grep -c "pickerStyle(.segmented)" Slice/SettingsView.swift` prints `1`.

### Task 7: Edit `project.yml`
- **ACTION**: After the line `        LSUIElement: true` insert EXACTLY (8-space indent):
```yaml
        # Notification Center and other modern lookups find the icon by asset name,
        # not by CFBundleIconFile; without this the banner shows a blank icon.
        CFBundleIconName: AppIcon
```
- **VALIDATE**: `grep -c CFBundleIconName project.yml` prints `1`.

### Task 8: Full icon set
- **ACTION**: Run EXACTLY:
```sh
A=Slice/Resources/Assets.xcassets/AppIcon.appiconset
for s in 16 32 128 256 512; do
  swift Scripts/render-icon.swift Design/AppIcon.svg $A/AppIcon-$s.png $s
  swift Scripts/render-icon.swift Design/AppIcon.svg $A/AppIcon-$s@2x.png $((s*2))
done
```
Then overwrite `Slice/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` with EXACTLY:
```json
{
  "images": [
    {
      "filename": "AppIcon-16.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "16x16"
    },
    {
      "filename": "AppIcon-16@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "16x16"
    },
    {
      "filename": "AppIcon-32.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "32x32"
    },
    {
      "filename": "AppIcon-32@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "32x32"
    },
    {
      "filename": "AppIcon-128.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "128x128"
    },
    {
      "filename": "AppIcon-128@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "128x128"
    },
    {
      "filename": "AppIcon-256.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "256x256"
    },
    {
      "filename": "AppIcon-256@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "256x256"
    },
    {
      "filename": "AppIcon-512.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "512x512"
    },
    {
      "filename": "AppIcon-512@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "512x512"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```
- **VALIDATE**: `ls Slice/Resources/Assets.xcassets/AppIcon.appiconset/*.png | wc -l` prints `10`.

### Task 9: README
- **ACTION**: Under `## Using it`, after the bullet that starts with `- The gear unfolds settings:`, replace that bullet with EXACTLY:
```
- The gear unfolds settings: work minutes, break minutes, launch at login, and the alert style — **Banner** (one notification) or **Alarm** (notification plus a floating window and a looping sound until you click Dismiss).
```
- **VALIDATE**: `grep -c "looping sound" README.md` prints `1`.

### Task 10: Regenerate, validate, commit, push, tag
- **ACTION**: `xcodegen generate`, then Validations 1–4, then:
```sh
git add -A
git commit -m "feat: alarm alert style, full icon set, CFBundleIconName

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
git tag v0.2.0
git push origin v0.2.0
```
- **VALIDATE**: Validations 5–6.

---

## Testing Strategy

### Unit Tests
| Test | Input | Expected | Edge Case? |
|---|---|---|---|
| missingKeyMeansBanner | empty defaults | `.banner` | default |
| savedAlarmIsRead | `"alarm"` | `.alarm` | — |
| unknownValueFallsBackToBanner | `"klaxon"` | `.banner` | corrupt value |

### Edge Cases Checklist
- [x] Two alarms in a row — `show` calls `dismiss` first
- [x] Nobody dismisses — sound stops after 120 s, window stays
- [x] Style changed while a session runs — read at phase end, applies
- [ ] Sound file missing — `NSSound(named:)` returns nil, window still shows

---

## Validation Commands

Run from `/Users/reza/Slice`, in order.

### 1. Generate + build
```sh
xcodegen generate | tail -1
grep -A1 CFBundleIconName Slice/Info.plist | tail -1
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug build 2>&1 | grep -E "error:|warning:|BUILD" | grep -v -E "appintentsmetadataprocessor|Error Domain"
```
EXPECT: `Created project at ...`; `<string>AppIcon</string>`; exactly `** BUILD SUCCEEDED **`.

### 2. Test
```sh
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug test 2>&1 | grep -E "✘|Test run with|TEST (SUCCEEDED|FAILED)" | grep -v "Error Domain"
```
EXPECT: `✔ Test run with 16 tests in 4 suites passed` and `** TEST SUCCEEDED **`.

### 3. Changed files
```sh
git status --short | sort
```
EXPECT: `M README.md`, `M Slice.xcodeproj/project.pbxproj`, `M Slice/Info.plist`, `M Slice/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`, `M Slice/SettingsView.swift`, `M Slice/SliceApp.swift`, `M project.yml`, `?? Slice/Alarm.swift`, `?? Slice/AlarmView.swift`, `?? Slice/AlertStyle.swift`, `?? SliceTests/AlertStyleTests.swift`, plus `?? Slice/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-16.png` and the other 7 new PNGs (the two 512 files may show as unchanged or `M`). Nothing else.

### 4. Live: picker writes defaults, then a 1-minute alarm cycle (≈90 s, plays sound briefly)
```sh
APP="$(xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR =/{print $3}')/Slice.app"
pkill -x Slice; sleep 1
defaults delete com.rezaahmadn.Slice alertStyle 2>/dev/null; defaults delete com.rezaahmadn.Slice workMinutes 2>/dev/null; defaults delete com.rezaahmadn.Slice breakMinutes 2>/dev/null
open "$APP"; sleep 4
echo "--- A: pick Alarm in settings ---"
osascript <<'APPLESCRIPT'
tell application "System Events"
  tell process "Slice"
    if (count windows) = 0 then
      click menu bar item 1 of menu bar 2
      delay 1
    end if
    click button 3 of group 1 of window 1
    delay 1
    click radio button 2 of radio group 1 of group 1 of window 1
    delay 1
    return value of radio button 2 of radio group 1 of group 1 of window 1
  end tell
end tell
APPLESCRIPT
echo "alertStyle=$(defaults read com.rezaahmadn.Slice alertStyle)"
pkill -x Slice; sleep 1
defaults write com.rezaahmadn.Slice workMinutes -int 1; defaults write com.rezaahmadn.Slice breakMinutes -int 1
open "$APP"; sleep 4
osascript <<'APPLESCRIPT'
tell application "System Events"
  tell process "Slice"
    if (count windows) = 0 then
      click menu bar item 1 of menu bar 2
      delay 1
    end if
    click button 1 of group 1 of window 1
    delay 0.5
    click menu bar item 1 of menu bar 2
  end tell
end tell
APPLESCRIPT
sleep 63
echo "--- B: alarm window ---"
osascript <<'APPLESCRIPT'
tell application "System Events"
  tell process "Slice"
    set n to count windows
    set texts to name of every static text of group 1 of window 1
    set btns to count buttons of group 1 of window 1
    click button 1 of group 1 of window 1
    delay 1
    set remaining to count windows
    return {n, texts, btns, remaining}
  end tell
end tell
APPLESCRIPT
/usr/bin/log show --last 90s --predicate 'subsystem == "com.rezaahmadn.Slice" AND category == "Alarm"' --style compact 2>&1 | grep -v "^Timestamp"
pkill -x Slice
defaults delete com.rezaahmadn.Slice workMinutes; defaults delete com.rezaahmadn.Slice breakMinutes; defaults delete com.rezaahmadn.Slice alertStyle
echo "defaults-left=$(defaults read com.rezaahmadn.Slice 2>&1 | grep -c -E 'Minutes|alertStyle')"
```
EXPECT: A → `1`; `alertStyle=alarm`; then one echoed line `menu bar item 01:00 of menu bar 2 of application process Slice` (osascript's return value, expected); B → `1, Work done, Take a break., 1, 0`; log contains `Alarm shown: Work done` then `Alarm dismissed`; `defaults-left=0`. If an osascript errors with "Can't get window 1", re-run Validation 4 once from the top.

### 5. CI run for v0.2.0 (after the tag push)
```sh
gh run list --workflow=release.yml --limit 1
RUN_ID=$(gh run list --workflow=release.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status && echo "run ok"
gh release view v0.2.0 --json assets --jq '.assets[].name'
```
EXPECT: run for `v0.2.0`; `run ok`; `Slice-0.2.0.zip`. On failure print `gh run view "$RUN_ID" --log-failed | tail -40` and STOP.

### 6. Downloaded build
```sh
mkdir -p /tmp/slice-dl3 && cd /tmp/slice-dl3
gh release download v0.2.0 --repo rezaahmadn/Slice --pattern 'Slice-0.2.0.zip' --clobber
ditto -x -k Slice-0.2.0.zip .
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" -c "Print :CFBundleIconName" Slice.app/Contents/Info.plist
cd /Users/reza/Slice; git status --short; git log --oneline -1
```
EXPECT: `0.2.0`, `AppIcon`; empty status; commit line containing `feat: alarm alert style`.

---

## Acceptance Criteria
- [ ] Tasks 1–10 done; Validations 1–6 match
- [ ] https://github.com/rezaahmadn/Slice/releases/tag/v0.2.0 exists

## Completion Checklist
- [ ] Files byte-identical to plan
- [ ] `PomodoroTimer.swift`, `Notifications.swift`, `MenuBarView.swift` untouched
- [ ] No `print`, `try!`, `fatalError` in `Slice/`
- [ ] PRD Phase 9 row → `complete` (orchestrator)

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Panel focus flake in Validation 4 | L | osascript error | one re-run allowed |
| Sound keeps looping if the agent's dismiss click fails | L | up to 120 s of "Glass" | `pkill -x Slice` at the end of Validation 4 stops it |

## Notes
- The blank banner icon on this Mac is Notification Center's stale record from Phase 4; a logout/restart refreshes it. New Macs never see it.
- `CFBundleIconName` and the full icon set are correct regardless and cost nothing.
