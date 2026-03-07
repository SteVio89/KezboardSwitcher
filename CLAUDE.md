# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KezboardSwitcher is a native macOS SwiftUI app that automatically switches keyboard input layouts when the user switches between physical keyboards. It detects keyboard input via IOKit HID and uses Carbon's TIS API to change the active input source.

This is a **rewrite** of an earlier Go/Wails version located at `/Users/stefan/code/go/kezboard_switcher`. The Swift version targets macOS 15.5+ with Swift 5.

Bundle ID: `de.stevio.KezboardSwitcher`

## Build & Test

```bash
# Build
xcodebuild -project KezboardSwitcher.xcodeproj -scheme KezboardSwitcher -configuration Debug build

# Run tests (uses Swift Testing framework, not XCTest)
xcodebuild -project KezboardSwitcher.xcodeproj -scheme KezboardSwitcher test

# Run a single test
xcodebuild test -project KezboardSwitcher.xcodeproj -scheme KezboardSwitcher -only-testing:KezboardSwitcherTests/KezboardSwitcherTests/testName
```

## Architecture

### Core Flow
1. `KeyboardManager` creates an `IOHIDManager` filtered to keyboard devices (HID usage page `kHIDPage_GenericDesktop`, usage `kHIDUsage_GD_Keyboard`)
2. A global C-style callback (`globalHidInputCallback`) receives HID input events and forwards them to `KeyboardManager.handleHidInputEvent`
3. On keypress (usage page `0x07`), `detectActiveKeyboard` checks if the source keyboard changed and switches the macOS input layout via `TISSelectInputSource`
4. The SwiftUI `ContentView` provides a configuration UI showing connected keyboards and their status

### Key Types
- `Keyboard` — model with name, status (new/configured/ignored), and `LayoutInfo` (layout ID + display name)
- `KeyboardManager` — owns the IOHIDManager lifecycle, HID callback, keyboard detection, and layout switching
- `KeyboardManagerError` — error enum for HID manager failures

### Important Details
- App sandbox is **disabled** (`com.apple.security.app-sandbox = false`) — required for IOKit HID access
- The HID callback uses `Unmanaged` pointers to bridge between C callbacks and Swift (`passUnretained`/`fromOpaque`)
- Only keyboards with status `.configured` and a non-empty `layoutId` are used for automatic switching
- `lastKeyboard` tracks the most recent keyboard to avoid redundant layout switches
- Layout switching iterates enabled input sources via `TISCreateInputSourceList` and matches by `kTISPropertyInputSourceID`

### Project Structure
```
KezboardSwitcher/
  App/                          # App entry point and delegate
  Features/
    Configuration/View/         # SwiftUI views (ContentView)
    CoreLogic/                  # KeyboardManager, LayoutDetector (stub)
  Shared/                       # Keyboard model, LayoutInfo
```
