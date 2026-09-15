# Plan: Phase 7 — Public Release

## Summary
Make Slice downloadable: a GitHub Actions workflow builds an ad-hoc signed Release `Slice.app` on every `v*` tag and attaches `Slice-<version>.zip` to a GitHub Release; `Info.plist` takes its version from the tag; an MIT `LICENSE`; and a final README that explains building, downloading, the Gatekeeper step, and the non-goals. Validation pushes tag `v0.1.0` and checks the real release.

**Dry-run on this machine on 2026-09-15: the Release build command below produced an ad-hoc signed 640 KB `Slice.app`, `ditto` zipped it to ~270 KB, `MARKETING_VERSION=0.2.0 CURRENT_PROJECT_VERSION=7` showed up in the built Info.plist once `project.yml` referenced the build settings, a quarantined copy was `rejected` by `spctl` (expected — documented in README), and `actionlint` passed on the workflow. `macos-26` runners ship Xcode 26.x.** Copy every file exactly.

## User Story
As someone who found the repo, I want to download a build or clone and press Cmd+R, so that I can run Slice without an Apple Developer account on either side.

## Problem → Solution
Source-only repo, hardcoded `1.0` version → tag → CI → zip on a Release page; README tells downloaders how to get past Gatekeeper.

## Metadata
- **Complexity**: Small
- **Source PRD**: `.claude/PRPs/prds/slice.prd.md`
- **PRD Phase**: 7 — Public release
- **Estimated Files**: 3 created, 2 edited, `Info.plist` + `project.pbxproj` regenerated

---

## UX Design
N/A in-app. Repo-level:

### Before
```
github.com/rezaahmadn/Slice → code only, "Coming in Phase 7" in README
```
### After
```
github.com/rezaahmadn/Slice/releases → v0.1.0 → Slice-0.1.0.zip
README → Download → unzip → first launch blocked → System Settings → Privacy & Security → Open Anyway
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| `git push origin v0.1.0` | nothing | CI builds + publishes release | ~3 min |
| About/Finder version | `1.0` | tag version | `$(MARKETING_VERSION)` |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `project.yml` | `info.properties` | Two keys added |
| P0 | `README.md` | all | Being replaced wholesale |
| P1 | `.gitignore` | all | `*.zip` already ignored — local zips never get committed |

## External Documentation

| Topic | Source | Key Takeaway |
|---|---|---|
| macOS 26 runners | https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/ | `runs-on: macos-26`, Xcode 26.x preinstalled |
| action-gh-release | https://github.com/softprops/action-gh-release | `files:` glob, `generate_release_notes: true`, needs `contents: write` |
| Gatekeeper on macOS 15+ | https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unidentified-developer-mh40616/mac | Control-click → Open no longer bypasses; use System Settings → Privacy & Security → Open Anyway |

Verified facts (from the dry run — treat as law):

KEY_INSIGHT: XcodeGen writes literal `1.0`/`1` into `Info.plist` unless `info.properties` sets `CFBundleShortVersionString: $(MARKETING_VERSION)` and `CFBundleVersion: $(CURRENT_PROJECT_VERSION)`.
APPLIES_TO: Task 1.

KEY_INSIGHT: `xcodebuild ... CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES MARKETING_VERSION=x.y.z CURRENT_PROJECT_VERSION=n build` overrides both at build time; `-derivedDataPath build` keeps CI output inside the workspace.
APPLIES_TO: Workflow.

KEY_INSIGHT: `ditto -c -k --keepParent Slice.app Slice-x.y.z.zip` preserves the bundle's signature and resource forks; plain `zip` can break the ad-hoc signature.
APPLIES_TO: Workflow, README.

KEY_INSIGHT: A downloaded (quarantined) ad-hoc app is rejected by Gatekeeper; `spctl --assess` says `rejected`. This is expected and cannot be fixed without a Developer ID. README documents the two escape hatches.
APPLIES_TO: README, Validation 5.

KEY_INSIGHT: `actionlint` is installed at `/opt/homebrew/bin/actionlint` and passes on the workflow as written.
APPLIES_TO: Validation 2.

---

## Patterns to Mirror

### REPO_LAYOUT
// SOURCE: Phase 6 plan — `Design/`, `Scripts/` outside `project.yml` sources. `.github/workflows/` likewise.

### COMMENT_STYLE (YAML)
// SOURCE: `project.yml` — `#` comments explaining why, one or two lines.

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `project.yml` | EDIT | Version keys from build settings |
| `Slice/Info.plist` | REGENERATE | via `xcodegen generate` |
| `Slice.xcodeproj/project.pbxproj` | REGENERATE | via `xcodegen generate` |
| `.github/workflows/release.yml` | CREATE | Tag → build → release |
| `LICENSE` | CREATE | MIT |
| `README.md` | REPLACE | Final |

## NOT Building
- Developer ID signing, notarization, Sparkle updates, Homebrew cask, DMG
- CI on every push (only tags) — keeps Actions minutes near zero
- Screenshots in README (deferred; add by hand later)

---

## Step-by-Step Tasks

All commands run from `/Users/reza/Slice`. Use absolute paths.

### Task 1: Edit `project.yml`
- **ACTION**: Under `targets.Slice.info.properties`, immediately after the line `        CFBundleName: Slice`, insert EXACTLY these three lines (8-space indent):
```yaml
        # Take the version from build settings so CI can inject it from the git tag.
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
```
- **VALIDATE**: `grep -c 'MARKETING_VERSION)' project.yml` prints `1`.

### Task 2: Create `.github/workflows/release.yml`
- **ACTION**: `mkdir -p .github/workflows` then create with EXACTLY:
```yaml
# Builds an ad-hoc signed Slice.app on every v* tag and attaches it to a GitHub Release.
# No Apple Developer account involved: downloaders must allow the app once in
# System Settings → Privacy & Security (see README).
name: Release

on:
  push:
    tags: ["v*"]

permissions:
  contents: write   # needed to create the release and upload the zip

jobs:
  build:
    runs-on: macos-26
    steps:
      - uses: actions/checkout@v5

      - name: Show Xcode
        run: xcodebuild -version

      - name: Build (Release, ad-hoc signed)
        env:
          TAG: ${{ github.ref_name }}
        run: |
          VERSION="${TAG#v}"
          xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Release \
            -derivedDataPath build \
            CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES \
            MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$GITHUB_RUN_NUMBER" \
            build

      - name: Zip
        env:
          TAG: ${{ github.ref_name }}
        run: |
          ditto -c -k --keepParent build/Build/Products/Release/Slice.app "Slice-${TAG#v}.zip"
          ls -la Slice-*.zip

      - name: Publish release
        uses: softprops/action-gh-release@v2
        with:
          files: Slice-*.zip
          generate_release_notes: true
```
- **VALIDATE**: Validation 2 (`actionlint`).

### Task 3: Create `LICENSE`
- **ACTION**: Create with EXACTLY:
```
MIT License

Copyright (c) 2026 Reza Ahmad

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
- **VALIDATE**: `head -3 LICENSE` shows `MIT License` and the copyright line.

### Task 4: Replace `README.md`
- **ACTION**: Overwrite with EXACTLY:
````markdown
# Slice

Minimal Pomodoro timer for the macOS menu bar. Nothing else.

A ring in the menu bar, a countdown next to it, Start / Pause / Reset in a small panel, a banner and a sound when work or break ends. Work and break lengths are configurable; it can launch at login. No task list, no stats, no sync, no account, no network.

Requires macOS 26.

## Download

Grab `Slice-<version>.zip` from the [latest release](https://github.com/rezaahmadn/Slice/releases/latest), unzip, and move `Slice.app` to `/Applications`.

The app is ad-hoc signed (no Apple Developer account), so the first launch is blocked by Gatekeeper. Either:

1. Try to open it once, then go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**; or
2. In Terminal: `xattr -d com.apple.quarantine /Applications/Slice.app`

After that it opens normally.

## Build from source

Requires Xcode 26.

```sh
git clone https://github.com/rezaahmadn/Slice.git
cd Slice
open Slice.xcodeproj   # then press Cmd+R
```

Or from the terminal:

```sh
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug build
```

Builds you make yourself are not quarantined, so they open directly.

## Using it

- Click the ring in the menu bar to open the panel.
- **Start** begins a work session; the same button becomes **Pause**. **Reset** returns to an idle work session.
- Work ends → break starts by itself and a banner says so. Break ends → back to idle; starting the next session is up to you.
- The gear unfolds settings: work minutes, break minutes, launch at login.
- Cmd+Q in the panel quits.

## Project layout

- `Slice/` — the app, one type per file: `SliceApp` (entry), `PomodoroTimer` (state machine), `MenuBarView`, `SettingsView`, `Notifications`.
- `SliceTests/` — Swift Testing suites; the timer is driven with synthetic dates so tests never wait.
- `Design/` — SVG icon sources. `Scripts/render-icon.swift` turns them into the PNGs in the asset catalog.
- `project.yml` — [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec. `Slice.xcodeproj` is generated from it and committed, so you only need XcodeGen if you edit `project.yml` (`brew install xcodegen && xcodegen generate`).
- `.github/workflows/release.yml` — on a `v*` tag, builds a Release `Slice.app` on a macOS 26 runner and attaches it as a zip to a GitHub Release.

## Releasing

```sh
git tag v0.2.0
git push origin v0.2.0
```

The version inside the app comes from the tag.

## Non-goals

Slice will not get task lists, statistics, sync, accounts, an iOS app, a Windows/Linux port, or an App Store release. It is one timer in the menu bar.

## License

[MIT](LICENSE)
````
- **VALIDATE**: `grep -c "Open Anyway" README.md` prints `1`.

### Task 5: Regenerate, validate, commit, push, tag
- **ACTION**: `xcodegen generate`, then Validation Commands 1–3, then:
```sh
git add -A
git commit -m "feat: release workflow, MIT license, final README

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
git tag v0.1.0
git push origin v0.1.0
```
- **GOTCHA**: The tag push is the outward-facing step: it creates a public GitHub Release. Only run it after Validations 1–3 pass.
- **VALIDATE**: Validations 4–6.

---

## Testing Strategy
No unit-test changes. The release is the test.

### Edge Cases Checklist
- [x] Tag without leading `v` — workflow does not trigger (pattern `v*`)
- [x] Zip breaks signature — `ditto` used, `codesign -dv` on the downloaded app must still say `adhoc`
- [ ] Runner Xcode drifts to 27 — revisit `runs-on` then

---

## Validation Commands

Run from `/Users/reza/Slice`, in order.

### 1. Generate + version keys + build + tests
```sh
xcodegen generate | tail -1
grep -A1 -E "CFBundleShortVersionString|CFBundleVersion" Slice/Info.plist
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug build 2>&1 | grep -E "error:|warning:|BUILD" | grep -v -E "appintentsmetadataprocessor|Error Domain"
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug test 2>&1 | grep -E "✘|Test run with|TEST (SUCCEEDED|FAILED)" | grep -v "Error Domain"
```
EXPECT: `Created project at ...`; the plist shows `<string>$(MARKETING_VERSION)</string>` and `<string>$(CURRENT_PROJECT_VERSION)</string>`; `** BUILD SUCCEEDED **`; `✔ Test run with 13 tests in 3 suites passed`.

### 2. Workflow lint
```sh
/opt/homebrew/bin/actionlint .github/workflows/release.yml && echo "actionlint ok"
```
EXPECT: `actionlint ok` and nothing else.

### 3. Local Release build with an injected version (mirrors CI)
```sh
mkdir -p /tmp/slice-rel
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Release -derivedDataPath /tmp/slice-rel CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES MARKETING_VERSION=0.1.0 CURRENT_PROJECT_VERSION=1 build 2>&1 | grep -E "error:|BUILD" | grep -v "Error Domain"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" /tmp/slice-rel/Build/Products/Release/Slice.app/Contents/Info.plist
codesign -dv /tmp/slice-rel/Build/Products/Release/Slice.app 2>&1 | grep "^Signature"
```
EXPECT: `** BUILD SUCCEEDED **`, `0.1.0`, `Signature=adhoc`.

### 4. CI run (after the tag push in Task 5; takes 2–5 min)
```sh
sleep 30
gh run list --workflow=release.yml --limit 1
RUN_ID=$(gh run list --workflow=release.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status && echo "run ok"
gh release view v0.1.0 --json assets --jq '.assets[].name'
```
EXPECT: a run for `v0.1.0`; `run ok`; asset name `Slice-0.1.0.zip`. If the run fails, print `gh run view "$RUN_ID" --log-failed | tail -40` and STOP — do not edit the workflow.

### 5. Downloaded artifact is the real thing
```sh
mkdir -p /tmp/slice-dl && cd /tmp/slice-dl
gh release download v0.1.0 --repo rezaahmadn/Slice --pattern 'Slice-0.1.0.zip' --clobber
ditto -x -k Slice-0.1.0.zip .
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Slice.app/Contents/Info.plist
codesign -dv Slice.app 2>&1 | grep -E "^Signature|^Identifier"
xattr -w com.apple.quarantine "0083;$(printf '%x' $(date +%s));Safari;" Slice.app
spctl --assess --type execute Slice.app 2>&1 | head -1
xattr -d com.apple.quarantine Slice.app && spctl --assess --type execute Slice.app 2>&1 | head -1; echo "spctl-after-xattr=$?"
cd /Users/reza/Slice
```
EXPECT: `0.1.0`; `Identifier=com.rezaahmadn.Slice`, `Signature=adhoc`; `Slice.app: rejected` (Gatekeeper on a quarantined download — expected); after removing quarantine the second `spctl` line may still say rejected (ad-hoc apps never pass `spctl`) — that is fine; what matters is that `open Slice.app` works, checked next.
```sh
pkill -x Slice; open /tmp/slice-dl/Slice.app; sleep 4; pgrep -x Slice && echo "downloaded build runs"; pkill -x Slice
```
EXPECT: a PID and `downloaded build runs`.

### 6. Repo state
```sh
git status --short; git log --oneline -1; git tag
```
EXPECT: empty status; commit line containing `feat: release workflow`; `v0.1.0`.

---

## Acceptance Criteria
- [ ] Tasks 1–5 done
- [ ] Validations 1–6 match EXPECT
- [ ] https://github.com/rezaahmadn/Slice/releases/tag/v0.1.0 exists with `Slice-0.1.0.zip`

## Completion Checklist
- [ ] Files byte-identical to plan
- [ ] No local `.zip` committed (`.gitignore` covers it)
- [ ] PRD Phase 7 row → `complete` (orchestrator)

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Runner's default Xcode newer than 26.2 breaks the build | L | CI red | Report; orchestrator pins `sudo xcode-select -s /Applications/Xcode_26.2.app` |
| `gh` not authenticated on runner side | — | n/a | `GITHUB_TOKEN` is automatic for action-gh-release |
| Tag pushed before validations | L | Broken public release | Task 5 order; delete with `gh release delete v0.1.0 --yes && git push --delete origin v0.1.0` if it ever happens |

## Notes
- Later, with a Developer ID: change only the workflow (sign with the cert, `notarytool submit`, `stapler staple`) and drop the Gatekeeper section from README.
- `CURRENT_PROJECT_VERSION` = GitHub run number, so every CI build has a distinct build number.
