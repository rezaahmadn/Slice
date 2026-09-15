# Slice

Minimal Pomodoro timer for the macOS menu bar. Nothing else.

**Status:** work in progress — Phase 5 of 7 (settings). Timer, notifications, icon and settings are done; a downloadable release is next.

## Build from source

Requires macOS 26 and Xcode 26.

```sh
git clone https://github.com/rezaahmadn/Slice.git
cd Slice
open Slice.xcodeproj   # then press Cmd+R
```

Or from the terminal:

```sh
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug build
```

The build is ad-hoc signed, so it runs on the Mac that built it with no Apple Developer account.

## Download a build

Coming in Phase 7. Downloaded builds will be ad-hoc signed, so macOS will ask you to right-click → Open the first time.

## Project layout

`Slice.xcodeproj` is generated from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen) and committed, so you only need XcodeGen if you change `project.yml`:

```sh
brew install xcodegen
xcodegen generate
```

## Icons

Icons are SVGs in `Design/`, rendered to the PNGs in the asset catalog by `Scripts/render-icon.swift` (AppKit, no extra tools). After editing an SVG:

```sh
swift Scripts/render-icon.swift Design/AppIcon.svg Slice/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png 1024
```

and the same for the other three sizes listed in the Phase 6 plan.

## Non-goals

Slice will not get task lists, statistics, sync, accounts, an iOS app, a Windows/Linux port, or an App Store release. It is one timer in the menu bar.

## License

MIT (license file arrives with the first release).
