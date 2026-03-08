# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KezboardSwitcher is a native macOS SwiftUI app that automatically switches keyboard input layouts when the user switches between physical keyboards. It detects keyboard input via IOKit HID and uses Carbon's TIS API to change the active input source. Targets macOS 15.5+ with Swift 5.

Bundle ID: `de.stevio.KezboardSwitcher`

## Build & Test

```bash
# Justfile commands
just build              # Build debug
just test               # Run unit tests
just reset-license      # Remove license from Keychain (for testing)

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
6. App runs as menu bar only (`LSUIElement = true`); `AppDelegate` manages `NSStatusItem` with left-click (open window) and right-click (context menu) via `NSEvent.addLocalMonitorForEvents`

### Key Types
- `Keyboard` — model with name, status (new/configured/ignored), and `LayoutInfo` (layout ID + display name)
- `KeyboardManager` — `@MainActor`, owns the IOHIDManager lifecycle, HID callback, and keyboard detection
- `KeyboardManagerError` — error enum for HID manager failures
- `AppViewModel` — `@Observable @MainActor` view model; owns KeyboardManager, ConfigService, LayoutDetector
- `ConfigService` — JSON persistence to `~/.config/KezboardSwitcher/config.json`
- `LayoutDetector` — enumerates enabled keyboard layouts and switches layouts via TIS API
- `AppDelegate` — `@MainActor`, `NSStatusItem` menu bar icon; uses closure from `OpenWindowAction` to open config window
- `StatisticsService` — SQLite-backed event store at `~/.config/KezboardSwitcher/stats.db`; records keyboard switch events and provides aggregates
- `LicenseService` — license activation via stevio_store API, Ed25519 signature verification (CryptoKit), Keychain persistence
- `LicenseActivationView` — license key input gate shown when `AppState.unlicensed`

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
    Statistics/                 # StatisticsService, StatisticsView
    Licensing/                  # LicenseService, LicenseActivationView
  Shared/                       # Keyboard model, LayoutInfo
Assets/                           # Source SVG icons (AppIcon.svg, MenuBarIcon.svg)
```

## Testing Notes
- All targets use `PBXFileSystemSynchronizedRootGroup` — source files are auto-discovered, no pbxproj entries needed
- Run unit tests only (avoids flaky UI perf test): `xcodebuild test -project KezboardSwitcher.xcodeproj -scheme KezboardSwitcher -only-testing:KezboardSwitcherTests`
- `@MainActor` class static pure functions need `nonisolated` to be callable from tests

## Licensing
- License activation: `POST <baseURL>/api/license/activate` with `{"license_key": "...", "machine_hash": "..."}`
- Machine hash: SHA-256 of `IOPlatformUUID`, 64-char lowercase hex
- Server returns `SignedLicense` with Ed25519 signature; stored in macOS Keychain (not file — dotfiles repo safety)
- Ed25519 public key placeholder at `LicenseService.publicKeyBase64` — **replace before release** with key from `store-cli generate key`
- DEBUG builds skip Ed25519 signature verification (`#if DEBUG`) — no valid public key needed for development
- DEBUG base URL: `http://localhost:3000` (frontend proxy); Release: `https://store.stevio.de`
- Canonical JSON for signature verification must match Go struct field order: `bundle_id`, `license_key`, `machine_hash`, `activated_at` — do NOT use `JSONEncoder` with `.sortedKeys`
- Server uses `bundle_id` (not `app_id`) as the JSON key in `LicensePayload`
- `AppState.unlicensed` gates the entire app — `KeyboardManager` never starts without a valid license
- Reset license for testing: `just reset-license` or `security delete-generic-password -s "de.stevio.KezboardSwitcher.license"`

## Gotchas
- Xcode may silently re-enable `ENABLE_APP_SANDBOX = YES` and empty the entitlements file when upgrading the project — always verify sandbox is disabled after Xcode upgrades
- `NSStatusBarButton.sendAction(on:)` is unreliable for custom click handling — use `NSEvent.addLocalMonitorForEvents` with `event.window == button.window` check instead
- Config JSON uses `KeyboardStatus` string raw values (`"new"`, `"configured"`, `"ignored"`) — integer values from the old Go version will cause silent decode failures
- SwiftUI `.task` is cancelled when the view disappears — use an unstructured `Task` for initialization that must survive window close
- Store API uses `bundle_id` not `app_id` in the signed license payload — the Swift `LicensePayload.CodingKeys` must map to `"bundle_id"`
