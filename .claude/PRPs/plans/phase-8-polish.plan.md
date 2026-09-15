# Plan: Phase 8 — Polish

## Summary
Close the loose ends left after v0.1.0: README screenshots, bump the two GitHub Actions to their current majors (Node 24 runtime — the v0.1.0 run logged a Node 20 deprecation), and ship it as v0.1.1 so the workflow change is proven live.

**The three screenshots were captured on this machine on 2026-09-15 from the v0.1.0 build; the action bumps were checked against upstream release notes (v3 = Node 24 only, same inputs; checkout v7 routine).**

## User Story
As a visitor to the repo, I want to see what Slice looks like before downloading it, and as the maintainer I want CI on a supported runtime.

## Problem → Solution
Text-only README, deprecated action runtime → three PNGs under `Design/screenshots/` embedded in README, `actions/checkout@v7`, `softprops/action-gh-release@v3`, tag v0.1.1.

## Metadata
- **Complexity**: Small
- **Source PRD**: `.claude/PRPs/prds/slice.prd.md`
- **PRD Phase**: 8 — Polish
- **Estimated Files**: 3 PNGs added, 2 edited

---

## UX Design
Repo-level only. README gains a screenshot block right after "Requires macOS 26."

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| README | text only | menu bar + panel + settings images | HTML `<img width>` so 2x PNGs render at natural size |
| Release CI | Node 20 deprecation annotation | none | v3 / v7 |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `README.md` | first 12 lines | Insertion point |
| P0 | `.github/workflows/release.yml` | `uses:` lines | Two version bumps |
| P1 | `.gitignore` | all | PNGs are not ignored; `*.zip` is |

## External Documentation

| Topic | Source | Key Takeaway |
|---|---|---|
| action-gh-release v3 | https://github.com/softprops/action-gh-release/releases/tag/v3.0.0 | Node 24 runtime, inputs unchanged |
| checkout v7 | https://github.com/actions/checkout/releases/tag/v7.0.0 | routine |

Verified facts:

KEY_INSIGHT: Screenshot sources live at `/private/tmp/claude-501/-Users-reza/399b41e2-b0d7-4dd4-bbca-e6118c31bfc8/scratchpad/shots/{menubar,panel,panel-settings}.png` (60 KB, 100 KB, 125 KB). Copy them; do not recapture.
APPLIES_TO: Task 1.

KEY_INSIGHT: GitHub renders raw Markdown images at pixel size; these are 2x captures, so use `<img ... width="...">`.
APPLIES_TO: Task 2.

---

## Patterns to Mirror

### REPO_LAYOUT
// SOURCE: Phase 6 — non-code assets under `Design/`.

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `Design/screenshots/menubar.png` | ADD | copied |
| `Design/screenshots/panel.png` | ADD | copied |
| `Design/screenshots/panel-settings.png` | ADD | copied |
| `README.md` | EDIT | screenshot block |
| `.github/workflows/release.yml` | EDIT | two `uses:` bumps |

## NOT Building
- Anything in `Slice/`; no version bump in `project.yml` (the tag drives the version)
- New features

---

## Step-by-Step Tasks

All commands run from `/Users/reza/Slice`. Use absolute paths.

### Task 1: Copy screenshots
- **ACTION**:
```sh
mkdir -p /Users/reza/Slice/Design/screenshots
cp "/private/tmp/claude-501/-Users-reza/399b41e2-b0d7-4dd4-bbca-e6118c31bfc8/scratchpad/shots/menubar.png" "/private/tmp/claude-501/-Users-reza/399b41e2-b0d7-4dd4-bbca-e6118c31bfc8/scratchpad/shots/panel.png" "/private/tmp/claude-501/-Users-reza/399b41e2-b0d7-4dd4-bbca-e6118c31bfc8/scratchpad/shots/panel-settings.png" /Users/reza/Slice/Design/screenshots/
ls -la /Users/reza/Slice/Design/screenshots/
```
- **VALIDATE**: three PNGs listed, sizes roughly 60K / 100K / 125K.

### Task 2: README screenshot block
- **ACTION**: In `README.md`, immediately AFTER the line `Requires macOS 26.` and its following blank line, insert EXACTLY this block followed by one blank line:
```html
<p><img src="Design/screenshots/menubar.png" width="300" alt="Slice in the menu bar: ring icon and 24:44"></p>
<p>
  <img src="Design/screenshots/panel.png" width="280" alt="Slice panel: Work, 24:44, Pause, Reset, gear, Quit Slice">
  <img src="Design/screenshots/panel-settings.png" width="280" alt="Slice panel with settings unfolded: work minutes, break minutes, launch at login">
</p>
```
- **VALIDATE**: `grep -c 'Design/screenshots/' README.md` prints `3`; `sed -n '1,20p' README.md` shows the block between "Requires macOS 26." and "## Download".

### Task 3: Bump actions
- **ACTION**: In `.github/workflows/release.yml` change `uses: actions/checkout@v5` to `uses: actions/checkout@v7` and `uses: softprops/action-gh-release@v2` to `uses: softprops/action-gh-release@v3`. Nothing else changes.
- **VALIDATE**: `grep -E "uses:" .github/workflows/release.yml` prints exactly the two bumped lines.

### Task 4: Validate, commit, push, tag
- **ACTION**: Validation Commands 1–2, then:
```sh
git add -A
git commit -m "docs: README screenshots; ci: checkout v7, action-gh-release v3

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
git tag v0.1.1
git push origin v0.1.1
```
- **VALIDATE**: Validations 3–5.

---

## Testing Strategy
No code change. The release is the test.

---

## Validation Commands

### 1. Lint + expected diff
```sh
/opt/homebrew/bin/actionlint .github/workflows/release.yml && echo "actionlint ok"
git status --short
```
EXPECT: `actionlint ok`; then exactly `M .github/workflows/release.yml`, `M README.md`, `?? Design/screenshots/`.

### 2. Build + tests still green (sanity, nothing in Slice/ changed)
```sh
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug test 2>&1 | grep -E "✘|Test run with|TEST (SUCCEEDED|FAILED)" | grep -v "Error Domain"
```
EXPECT: `✔ Test run with 13 tests in 3 suites passed`, `** TEST SUCCEEDED **`.

### 3. CI run for v0.1.1 (after the tag push)
```sh
gh run list --workflow=release.yml --limit 1
RUN_ID=$(gh run list --workflow=release.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status && echo "run ok"
gh run view "$RUN_ID" --json jobs --jq '.jobs[].steps[] | select(.conclusion != "success") | .name' | wc -l
gh release view v0.1.1 --json assets --jq '.assets[].name'
```
EXPECT: a run for `v0.1.1`; `run ok`; `0` non-success steps; asset `Slice-0.1.1.zip`. If the run fails, print `gh run view "$RUN_ID" --log-failed | tail -40` and STOP.

### 4. No Node deprecation annotation
```sh
gh api "repos/rezaahmadn/Slice/actions/runs/$RUN_ID/jobs" --jq '.jobs[0].id' | xargs -I{} gh api "repos/rezaahmadn/Slice/check-runs/{}/annotations" --jq 'length'
```
EXPECT: `0`.

### 5. Downloaded build has the new version; README images resolve
```sh
mkdir -p /tmp/slice-dl2 && cd /tmp/slice-dl2
gh release download v0.1.1 --repo rezaahmadn/Slice --pattern 'Slice-0.1.1.zip' --clobber
ditto -x -k Slice-0.1.1.zip .
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Slice.app/Contents/Info.plist
cd /Users/reza/Slice
gh api repos/rezaahmadn/Slice/contents/Design/screenshots --jq '.[].name'
```
EXPECT: `0.1.1`; then `menubar.png`, `panel-settings.png`, `panel.png`.

---

## Acceptance Criteria
- [ ] Tasks 1–4 done, Validations 1–5 match
- [ ] https://github.com/rezaahmadn/Slice/releases/tag/v0.1.1 exists

## Completion Checklist
- [ ] Only the five listed paths changed
- [ ] PRD Phase 8 row → `complete` (orchestrator)

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Annotations endpoint returns a non-deprecation notice | L | Validation 4 shows 1 | Report the annotation text; orchestrator judges |
