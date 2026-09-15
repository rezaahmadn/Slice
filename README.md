# Slice

Minimal Pomodoro timer for the macOS menu bar. Nothing else.

**Status:** work in progress — Phase 2 of 7 (timer core). The menu bar still shows a static `25:00`; the timer model is done and tested, the UI binds to it next.

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

## Non-goals

Slice will not get task lists, statistics, sync, accounts, an iOS app, a Windows/Linux port, or an App Store release. It is one timer in the menu bar.

## License

MIT (license file arrives with the first release).
