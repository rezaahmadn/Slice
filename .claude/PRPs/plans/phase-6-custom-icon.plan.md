# Plan: Phase 6 — Custom Icon

## Summary
Give Slice its own identity: a red squircle app icon with a white ring that has one wedge cut out and pushed aside (the "slice"), and a monochrome template version of the same ring for the menu bar, replacing the SF Symbol `timer`. Icons are authored as SVG in `Design/`, rendered to PNG by a 20-line Swift script in `Scripts/`, and the PNGs are committed into the asset catalog.

**Dry-run on this machine on 2026-09-15 on top of Phases 1–3: build succeeded with zero warnings, `AppIcon.icns` was produced, and `assetutil` shows `MenuBarIcon` with `"Template Mode" : "template"`.** Copy every file exactly.

## User Story
As Reza, I want Slice to have a non-generic icon in the menu bar and in Finder, so that it looks like a real app I made, not a placeholder.

## Problem → Solution
SF Symbol `timer` in the menu bar and an empty `AppIcon` set → committed SVG sources, a reproducible render script, filled `AppIcon.appiconset`, new `MenuBarIcon.imageset` (template), and `Image("MenuBarIcon")` in the label.

## Metadata
- **Complexity**: Small
- **Source PRD**: `.claude/PRPs/prds/slice.prd.md`
- **PRD Phase**: 6 — Custom icon
- **Estimated Files**: 3 sources created, 4 PNGs generated, 2 JSON, 1 Swift edit, 1 README line, `project.pbxproj` regenerated

---

## UX Design

### Before
```
Menu bar: ⏱ 25:00     (SF Symbol timer)
Finder:   generic blank app icon
```

### After
```
Menu bar: ◔ 25:00     (ring with a cut wedge, tinted by macOS)
Finder:   red squircle, white ring with a displaced wedge
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| Menu bar glyph | SF Symbol | Custom template PNG | Template = macOS recolors for light/dark |
| App icon | none | 512@1x + 512@2x PNGs → `.icns` | Xcode builds the `.icns` |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `Slice/SliceApp.swift` | the `label:` closure | The one line that changes |
| P0 | `Slice/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` | all | Being replaced with filenames added |
| P1 | `project.yml` | `sources:` | `Design/` and `Scripts/` are NOT under `Slice/`, so they are not compiled into the app — intended |

## External Documentation

| Topic | Source | Key Takeaway |
|---|---|---|
| Template images | https://developer.apple.com/documentation/appkit/nsimage/istemplate | Black + alpha PNG; system tints it |
| Asset catalog template intent | https://developer.apple.com/documentation/xcode/asset-management | `"template-rendering-intent" : "template"` in `Contents.json` `properties` |
| macOS app icon | https://developer.apple.com/design/human-interface-guidelines/app-icons | 1024 canvas, artwork ~824 centered, rounded-rect shape supplied by you |

Verified facts (from the dry run — treat as law):

KEY_INSIGHT: `NSImage(contentsOf:)` loads SVG natively on macOS 26, so the render script needs no Homebrew tools.
APPLIES_TO: Task 3.

KEY_INSIGHT: `swift Scripts/render-icon.swift in.svg out.png N` renders an N×N PNG with alpha in ~1 s per call.
APPLIES_TO: Task 4.

KEY_INSIGHT: Files under `Design/` and `Scripts/` are outside `project.yml`'s `sources`, so `xcodegen generate` ignores them and they never ship inside the app. Still run `xcodegen generate` because the new PNGs inside `Assets.xcassets` change the catalog contents that the project references.
APPLIES_TO: Task 7.

KEY_INSIGHT: `xcrun assetutil --info Slice.app/Contents/Resources/Assets.car` lists compiled assets; the menu bar image must show `"Template Mode" : "template"`.
APPLIES_TO: Validation 3.

KEY_INSIGHT: The menu bar item is under the notch on this Mac, so the new glyph cannot be checked visually there. The accessibility name (`25:00`) plus `assetutil` output are the proof. The app icon CAN be checked visually via Finder/QuickLook screenshot of the `.icns`.
APPLIES_TO: Validation 4.

---

## Patterns to Mirror

### COMMENT_STYLE
// SOURCE: `Slice/SliceApp.swift` label closure
```swift
            // An `HStack` of image + text shows both in the menu bar.
            // (`Label` would show only the icon here.) Reading `timer.displayText`
```

### REPO_LAYOUT (new)
```
Design/           ← SVG sources (hand-editable, the truth)
Scripts/          ← developer tooling, not compiled into the app
Slice/Resources/Assets.xcassets/
  AppIcon.appiconset/     AppIcon-512.png, AppIcon-512@2x.png
  MenuBarIcon.imageset/   MenuBarIcon.png (18px), MenuBarIcon@2x.png (36px)
```

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `Design/AppIcon.svg` | CREATE | App icon source |
| `Design/MenuBarIcon.svg` | CREATE | Menu bar glyph source |
| `Scripts/render-icon.swift` | CREATE | SVG → PNG renderer |
| `Slice/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png` | GENERATE | 512 px |
| `Slice/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png` | GENERATE | 1024 px |
| `Slice/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` | REPLACE | Add filenames |
| `Slice/Resources/Assets.xcassets/MenuBarIcon.imageset/MenuBarIcon.png` | GENERATE | 18 px |
| `Slice/Resources/Assets.xcassets/MenuBarIcon.imageset/MenuBarIcon@2x.png` | GENERATE | 36 px |
| `Slice/Resources/Assets.xcassets/MenuBarIcon.imageset/Contents.json` | CREATE | Template intent |
| `Slice/SliceApp.swift` | EDIT | `Image(systemName: "timer")` → `Image("MenuBarIcon")` + comment |
| `Slice.xcodeproj/project.pbxproj` | REGENERATE | Catalog contents changed |
| `README.md` | UPDATE | Status line + one "Icons" section |

## NOT Building
- Icon Composer `.icon` bundle / Liquid Glass layered icon — plain PNG is enough
- Dark-mode or tinted app icon variants
- Animated / progress-ring menu bar glyph (would be a nice Could later)

---

## Step-by-Step Tasks

All commands run from `/Users/reza/Slice`. Use absolute paths.

### Task 1: Create `Design/AppIcon.svg`
- **ACTION**: `mkdir -p Design` then create the file with EXACTLY this content.
- **IMPLEMENT**:
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#F0524F"/>
      <stop offset="1" stop-color="#C62828"/>
    </linearGradient>
  </defs>
  <!-- macOS squircle: 824px artwork centered on a 1024 canvas -->
  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bg)"/>
  <!-- ring (outer r=280, inner r=170) with a 45° wedge removed between 12 and 1:30 o'clock -->
  <path fill="#FFF7F2"
        d="M710 314 A280 280 0 1 1 512 232 L512 342 A170 170 0 1 0 632 392 Z"/>
  <!-- the removed wedge, pushed outward along the gap's bisector so it reads as a cut slice -->
  <path fill="#FFF7F2" transform="translate(26,-62)"
        d="M512 232 A280 280 0 0 1 710 314 L632 392 A170 170 0 0 0 512 342 Z"/>
</svg>
```
- **VALIDATE**: File exists.

### Task 2: Create `Design/MenuBarIcon.svg`
- **ACTION**: Create the file with EXACTLY this content.
- **IMPLEMENT**:
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 1024 1024">
  <!-- monochrome template image: black + alpha; macOS tints it for light/dark menu bars -->
  <!-- ring (outer r=400, inner r=250) with a 60° wedge removed between 12 and 2 o'clock -->
  <path fill="#000"
        d="M858 312 A400 400 0 1 1 512 112 L512 262 A250 250 0 1 0 728 387 Z"/>
  <path fill="#000" transform="translate(50,-86)"
        d="M512 112 A400 400 0 0 1 858 312 L728 387 A250 250 0 0 0 512 262 Z"/>
</svg>
```
- **GOTCHA**: Fill must stay `#000`; template images are black + alpha only.
- **VALIDATE**: File exists.

### Task 3: Create `Scripts/render-icon.swift`
- **ACTION**: `mkdir -p Scripts` then create the file with EXACTLY this content.
- **IMPLEMENT**:
```swift
import AppKit

// Usage: swift render.swift input.svg output.png pixelSize
let args = CommandLine.arguments
let url = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[2])
let px = Int(args[3])!
guard let svg = NSImage(contentsOf: url) else { fatalError("cannot load \(url.path)") }
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: px, height: px)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
svg.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote \(out.lastPathComponent) \(px)px")
```
- **GOTCHA**: This is a script, not app code — `fatalError`/`try!` are acceptable here (they are the script's error reporting). It must never be placed under `Slice/`.
- **VALIDATE**: Task 4 runs it.

### Task 4: Render the PNGs
- **ACTION**: Run EXACTLY:
```sh
mkdir -p Slice/Resources/Assets.xcassets/MenuBarIcon.imageset
swift Scripts/render-icon.swift Design/AppIcon.svg Slice/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png 512
swift Scripts/render-icon.swift Design/AppIcon.svg Slice/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png 1024
swift Scripts/render-icon.swift Design/MenuBarIcon.svg Slice/Resources/Assets.xcassets/MenuBarIcon.imageset/MenuBarIcon.png 18
swift Scripts/render-icon.swift Design/MenuBarIcon.svg Slice/Resources/Assets.xcassets/MenuBarIcon.imageset/MenuBarIcon@2x.png 36
```
- **VALIDATE**: Four lines `wrote <name> <N>px`; `sips -g pixelWidth Slice/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png` prints `pixelWidth: 1024`.

### Task 5: Replace `AppIcon.appiconset/Contents.json`
- **ACTION**: Overwrite with EXACTLY:
```json
{
  "images" : [
    {
      "filename" : "AppIcon-512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "AppIcon-512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```
- **VALIDATE**: `python3 -m json.tool Slice/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json > /dev/null && echo valid` prints `valid`.

### Task 6: Create `MenuBarIcon.imageset/Contents.json`
- **ACTION**: Create with EXACTLY:
```json
{
  "images" : [
    {
      "filename" : "MenuBarIcon.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "filename" : "MenuBarIcon@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "template-rendering-intent" : "template"
  }
}
```
- **GOTCHA**: The `3x` entry has no filename on purpose (macOS never uses it); keep it so Xcode does not warn about an incomplete set. `properties.template-rendering-intent` is what makes macOS tint the glyph.
- **VALIDATE**: `python3 -m json.tool ... > /dev/null && echo valid` prints `valid`.

### Task 7: Edit `Slice/SliceApp.swift`
- **ACTION**: Inside the `label:` closure, replace the single line `                Image(systemName: "timer")` with EXACTLY these three lines (same indentation, 16 spaces):
```swift
                // Our own icon from the asset catalog. It is marked "template" there,
                // so macOS recolors it to match the menu bar in light and dark mode.
                Image("MenuBarIcon")
```
- **GOTCHA**: Change nothing else in the file.
- **VALIDATE**: `grep -c 'Image("MenuBarIcon")' Slice/SliceApp.swift` prints `1`; `grep -c 'systemName: "timer"' Slice/SliceApp.swift` prints `0`.

### Task 8: README
- **ACTION**: Replace the `**Status:**` line with EXACTLY:
```
**Status:** work in progress — Phase 6 of 7 (custom icon). Timer, notifications and icon are done; settings and a downloadable release are next.
```
  Then insert this section immediately BEFORE the `## Non-goals` heading:
````markdown
## Icons

Icons are SVGs in `Design/`, rendered to the PNGs in the asset catalog by `Scripts/render-icon.swift` (AppKit, no extra tools). After editing an SVG:

```sh
swift Scripts/render-icon.swift Design/AppIcon.svg Slice/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png 1024
```

and the same for the other three sizes listed in the Phase 6 plan.

````
- **NOTE**: If Phase 4 or 5 has not yet run when you implement this (check the PRD table), keep the Status line's wording but drop the parts that are not true yet — e.g. "Timer and icon are done; notifications, settings and a downloadable release are next."
- **VALIDATE**: `grep -c "^## Icons" README.md` prints `1`.

### Task 9: Regenerate, validate, commit, push
- **ACTION**: `xcodegen generate`, then Validation Commands 1–5, then:
```sh
git add -A
git commit -m "feat: custom app icon and template menu bar glyph

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
```
- **VALIDATE**: `git status --short` empty; `git log --oneline -1` shows the commit.

---

## Testing Strategy
No unit tests — asset-only change. Existing tests must still pass.

### Edge Cases Checklist
- [x] Light vs dark menu bar — template intent handles it
- [x] Retina vs non-Retina — 1x and 2x PNGs provided
- [ ] Icon at 16 px Finder list view — acceptable, ring still reads as a circle

---

## Validation Commands

Run from `/Users/reza/Slice`, in order.

### 1. Build
```sh
xcodegen generate | tail -1
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug build 2>&1 | grep -E "error:|warning:|BUILD" | grep -v appintentsmetadataprocessor
```
EXPECT: `Created project at /Users/reza/Slice/Slice.xcodeproj`, then exactly `** BUILD SUCCEEDED **`.

### 2. Test
```sh
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug test 2>&1 | grep -E "✘|Test run with|TEST (SUCCEEDED|FAILED)" | grep -v "Error Domain"
```
EXPECT: `✔ Test run with N tests in M suites passed` (N ≥ 10) and `** TEST SUCCEEDED **`.

### 3. Bundle contains the icons
```sh
APP="$(xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR =/{print $3}')/Slice.app"
ls "$APP/Contents/Resources/AppIcon.icns"
xcrun assetutil --info "$APP/Contents/Resources/Assets.car" | grep -E '"Name"|"Template Mode"' | sort | uniq -c
```
EXPECT: the `.icns` path is printed; then lines containing `"Name" : "AppIcon"`, `"Name" : "MenuBarIcon"`, and `"Template Mode" : "template"`.

### 4. App still runs and the label is intact
```sh
pkill -x Slice; sleep 1; open "$APP"; sleep 4
osascript -e 'tell application "System Events" to tell process "Slice" to get name of every menu bar item of menu bar 2'
pkill -x Slice
```
EXPECT: `25:00`.

### 5. App icon looks right
```sh
qlmanage -t -s 256 -o /tmp "$APP/Contents/Resources/AppIcon.icns" >/dev/null 2>&1; ls /tmp/AppIcon.icns.png
```
EXPECT: the path is printed. Open `/tmp/AppIcon.icns.png` with the Read tool: red rounded square, white ring, a wedge of the ring displaced toward the upper right.

### 6. After commit and push
```sh
git status --short; git log --oneline -1
```
EXPECT: empty status; commit line containing `feat: custom app icon`.

---

## Acceptance Criteria
- [ ] Tasks 1–9 done
- [ ] Validations 1–6 match EXPECT
- [ ] Pushed

## Completion Checklist
- [ ] SVGs, script, JSON byte-identical to plan
- [ ] Only the label line changed in `SliceApp.swift`
- [ ] `Design/` and `Scripts/` not referenced by `project.yml`
- [ ] PRD Phase 6 row → `complete` (orchestrator)

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `qlmanage` thumbnail not produced | L | Validation 5 only | Fall back to `sips -s format png "$APP/Contents/Resources/AppIcon.icns" --out /tmp/AppIcon.icns.png` |
| Glyph looks heavy at 18 px | M | Cosmetic | Tune `Design/MenuBarIcon.svg` ring thickness later; not a blocker |

## Notes
- The menu bar glyph deliberately uses a 60° cut (vs 45° on the app icon) so the gap survives at 18 px.
- If Phase 4/5 land after this phase, they must keep `Image("MenuBarIcon")` in the label.
