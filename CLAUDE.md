# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KezboardSwitcher is a native macOS SwiftUI app that automatically switches keyboard input layouts when the user switches between physical keyboards. It detects keyboard input via IOKit HID and uses Carbon's TIS API to change the active input source. Targets macOS 15.5+ with Swift 5.

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
4. `AppViewModel` (`@Observable @MainActor`) manages app state, merges config/detected keyboards, and owns `KeyboardManager`
5. The SwiftUI UI routes on `AppState` (loading/needsPermission/ready/error) with keyboard list + layout selector
6. App runs as menu bar only (`LSUIElement = true`); `AppDelegate` manages `NSStatusItem`

### Key Types
- `Keyboard` — model with name, status (new/configured/ignored), and `LayoutInfo` (layout ID + display name)
- `KeyboardManager` — `@MainActor`, owns the IOHIDManager lifecycle, HID callback, and keyboard detection
- `KeyboardManagerError` — error enum for HID manager failures
- `AppViewModel` — `@Observable @MainActor` view model; owns KeyboardManager, ConfigService, LayoutDetector
- `ConfigService` — JSON persistence to `~/.config/KezboardSwitcher/config.json`
- `LayoutDetector` — enumerates enabled keyboard layouts and switches layouts via TIS API
- `AppDelegate` — `@MainActor`, `NSStatusItem` menu bar icon; uses closure from `OpenWindowAction` to open config window

### Important Details
- App sandbox is **disabled** (`com.apple.security.app-sandbox = false`) — required for IOKit HID access
- The HID callback uses `Unmanaged` pointers to bridge between C callbacks and Swift (`passUnretained`/`fromOpaque`)
- Only keyboards with status `.configured` and a non-empty `layoutId` are used for automatic switching
- `lastKeyboard` tracks the most recent keyboard to avoid redundant layout switches
- All TIS interaction is centralized in `LayoutDetector` via a shared `enumerateInputSources` helper
- `TISGetInputSourceProperty` returns `UnsafeMutableRawPointer?` — use `Unmanaged<CFString>.fromOpaque(ref).takeUnretainedValue()` to bridge to String. Do NOT use `as! CFString` (crashes at runtime) or `unsafeBitCast` (unsafe)
- `TISCreateInputSourceList` follows CF Create Rule — always use `takeRetainedValue()` to avoid memory leaks
- `@MainActor` class `deinit` is nonisolated — cannot call isolated methods; inline IOKit cleanup directly
- `KeyboardStatus` uses `String` raw values for stable JSON serialization (config at `~/.config/KezboardSwitcher/config.json`)

### Project Structure
```
KezboardSwitcher/
  App/                          # App entry point and delegate
  Features/
    Configuration/              # ConfigService, AppViewModel
      View/                     # ContentView, KeyboardListView, LayoutSelectorView, PermissionOnboardingView
    CoreLogic/                  # KeyboardManager, LayoutDetector
  Shared/                       # Keyboard model, LayoutInfo
```

## Testing Notes
- Test target uses `PBXFileSystemSynchronizedRootGroup` — test files are auto-discovered, no pbxproj entries needed
- Main app target uses manual `PBXBuildFile` entries — new source files need pbxproj registration
- Run unit tests only (avoids flaky UI perf test): `xcodebuild test -project KezboardSwitcher.xcodeproj -scheme KezboardSwitcher -only-testing:KezboardSwitcherTests`
- `@MainActor` class static pure functions need `nonisolated` to be callable from tests
