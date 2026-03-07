# KezboardSwitcher Migration Plan: Go/Wails → Swift/SwiftUI

## Context

KezboardSwitcher is a macOS utility that automatically switches keyboard input layouts when the user types on a different physical keyboard. A fully working Go/Wails version exists at `/Users/stefan/code/go/kezboard_switcher` (used daily). The Swift rewrite at `/Users/stefan/code/stevio/KezboardSwitcher` has core HID detection and layout switching working, but is missing persistence, full UI, background operation, and permission handling.

This document is a migration requirements spec for a Claude Code agent to complete the Swift rewrite. Beyond Go feature parity, the scope includes: first-run onboarding wizard, localization/translations, and local keyboard usage statistics.

**Bundle ID**: The Swift version uses its own identity `de.stevio.KezboardSwitcher` (not matching Go's `de.stevio.kezboard-switcher`). Config file format remains compatible for migration.

---

## What Already Works in Swift

| Component | File | Status |
|-----------|------|--------|
| IOHIDManager + HID callback + keyboard detection + layout switching | `Features/CoreLogic/KeyboardManager.swift` (250 lines) | Complete |
| Data models (Keyboard, LayoutInfo, KeyboardStatus) | `Shared/Keyboard.swift` (60 lines) | Complete (needs Codable) |
| Basic keyboard list UI | `Features/Configuration/View/ContentView.swift` (148 lines) | Partial |
| App entry point | `App/KezboardSwitcherApp.swift` | Minimal |
| AppDelegate | `App/AppDelegate.swift` | Stub (empty) |
| LayoutDetector | `Features/CoreLogic/LayoutDetector.swift` | Stub (empty) |

---

## Milestones (Ordered by Dependency)

### M1: Make Models Codable (Config Compatibility)

**Why**: Everything downstream (config persistence, UI state) depends on serializable models. JSON format must match the Go version so the user keeps their existing config.

**Go JSON format** (from `pkg/core/models/keyboard.go` and `layout.go`):
```json
{
  "keyboards": [
    {
      "Name": "Keychron Q1 Max",
      "Status": 1,
      "LayoutInfo": {
        "LayoutId": "com.apple.keylayout.German",
        "LayoutName": "German"
      }
    }
  ]
}
```

**File**: `KezboardSwitcher/Shared/Keyboard.swift`

Changes:
- Add `Codable`, `Identifiable`, `Hashable`, `Equatable` to `Keyboard`, `LayoutInfo`, `KeyboardStatus`
- Add `CodingKeys` matching Go's capitalized JSON keys: `Name`, `Status`, `LayoutInfo`, `LayoutId`, `LayoutName`
- Make `Keyboard` properties `var` (UI needs mutation for status/layout changes)
- Add `id` property for `Identifiable` (use `name` or `UUID`)

**Verify**: Unit test encoding/decoding a sample Go config JSON string. Round-trip must preserve all fields.

---

### M2: Config Persistence Service

**Why**: Users need their keyboard-to-layout mappings saved between launches. Must read the existing Go config.

**Go reference**: `pkg/config/config.go` — uses `os.UserConfigDir()` which on macOS = `~/Library/Application Support`

**Config path**: `~/Library/Application Support/kezboard_switcher/config.json`

**New file**: `KezboardSwitcher/Features/Configuration/ConfigService.swift`

Behavior:
- Wrapper struct `ConfigFile` with `keyboards: [Keyboard]` (JSON key: `"keyboards"`)
- `load() -> [Keyboard]`: Read + decode. Return empty array if file doesn't exist
- `save(keyboards:)`: Encode with `.prettyPrinted` + `.sortedKeys`, write atomically
- Create directory on save if missing (`FileManager.default.createDirectory`)
- Use `@Observable` (macOS 14+, project targets 15.5)

**Verify**: Unit test — save keyboards, reload, assert equality. Verify JSON output has capitalized keys.

---

### M3: Layout Detector (Native TIS)

**Why**: Users need to see available keyboard layouts to assign them. The Go version used an external helper binary (`cmd/layoutdetector/`); Swift can call TIS APIs directly.

**Go reference**: `pkg/core/macos/layouts/layout_detector.go` — calls `TISCreateInputSourceList` with category filter, extracts `kTISPropertyInputSourceID` and `kTISPropertyLocalizedName`.

**File**: `KezboardSwitcher/Features/CoreLogic/LayoutDetector.swift`

Implementation:
- `func getAvailableLayouts() -> [LayoutInfo]`
- Filter: `kTISPropertyInputSourceCategory = kTISCategoryKeyboardInputSource`, enabled only
- Extract `kTISPropertyInputSourceID` → `layoutId`, `kTISPropertyLocalizedName` → `layoutName`
- Follow the same TIS pattern already used in `KeyboardManager.switchToLayout()`
- Optional: cache results (layouts rarely change at runtime)

**Verify**: Call function, assert non-empty result containing at least one `com.apple.keylayout.*` entry.

---

### M4: App ViewModel + Keyboard Merge Logic

**Why**: The UI needs a central state manager that merges config keyboards with detected keyboards, handles app states, and coordinates saves.

**Go reference**: `pkg/ui/app.go` — `GetKeyboards()` merges config + detected (config keyboards first, then append any newly detected ones not already in the list).

**New file**: `KezboardSwitcher/Features/Configuration/AppViewModel.swift`

`@Observable class AppViewModel`:
- Owns references to `KeyboardManager`, `ConfigService`, `LayoutDetector`
- Properties: `keyboards: [Keyboard]`, `layouts: [LayoutInfo]`, `selectedKeyboard: Keyboard?`, `appState: AppState` (enum: `.loading`, `.needsPermission`, `.ready`, `.error(String)`)
- `loadKeyboards()`: merge config + detected (config first, append new detections)
- `loadLayouts()`: call LayoutDetector
- `saveConfig()`: persist via ConfigService, update `KeyboardManager.setManagedKeyboards()`
- `assignLayout(to keyboard:, layout:)`: set keyboard's layoutInfo, mark as `.configured`
- `toggleIgnore(keyboard:)`: toggle between `.ignored` and `.new`

**Verify**: Unit test merge logic — 2 configured + 3 detected (1 overlap) → 4 total, no duplicates.

---

### M5: Full Configuration UI

**Why**: Replace the basic keyboard list with the full two-column config interface matching the Go/Svelte UI.

**Go/Svelte reference**:
- `frontend/src/App.svelte` — 4 states, two-column layout
- `frontend/src/components/KeyboardList.svelte` — left panel
- `frontend/src/components/LayoutSelector.svelte` — right panel

**Files to create/modify**:

| File | Action |
|------|--------|
| `Features/Configuration/View/ContentView.swift` | **Rewrite**: switch on `appState` (loading/permission/ready/error), wire `AppViewModel` |
| `Features/Configuration/View/KeyboardListView.swift` | **Create**: `List` with selection, status badges (blue=new, green=configured, red=ignored) |
| `Features/Configuration/View/LayoutSelectorView.swift` | **Create**: layout list for selected keyboard, ignore/unignore button, click-to-assign |
| `Features/Configuration/View/PermissionOnboardingView.swift` | **Create**: explains input monitoring, button to open System Settings |

Layout: `HSplitView` or `HStack` — keyboard list (left), layout selector (right), save button at bottom.

**Verify**: Manual — launch app, see keyboards, select one, see layouts, assign, save, relaunch, verify persistence.

---

### M6: Permission Detection

**Why**: App needs input monitoring permission for IOKit HID. Must guide users on first run.

**Go reference**: `main.go` — if `initCoreServices()` fails, sets `needsPermissions = true`.

**Implementation**: In `AppViewModel` initialization:
1. Try creating `KeyboardManager`
2. If throws → set `appState = .needsPermission`
3. If succeeds → load keyboards/layouts, set `appState = .ready`

Open System Settings: `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)`

**Verify**: Revoke input monitoring in System Settings → launch → see onboarding. Grant → relaunch → see config UI.

---

### M7: Menu Bar / Background Operation

**Why**: The app must keep switching layouts even when the config window is closed. The Go version uses `HideWindowOnClose: true`.

**Files**:
- `App/KezboardSwitcherApp.swift` — add `NSApplicationDelegateAdaptor`
- `App/AppDelegate.swift` — implement `NSStatusItem`, menu bar icon, lifecycle

**Implementation**:
- `AppDelegate`: create `NSStatusItem` with SF Symbol `keyboard` icon
- Menu: "Open Configuration" (show window), separator, "Quit"
- `NSApp.setActivationPolicy(.accessory)` — hide from Dock when window closed
- **Critical**: Move `KeyboardManager` ownership from ContentView to app-level (`AppDelegate` or `AppViewModel` owned by `App` struct) so it persists when window closes

**Verify**: Launch → close window → verify menu bar icon → verify layout switching still works → click "Open Configuration" → window reappears.

---

### M8: Tests

**File**: `KezboardSwitcherTests/KezboardSwitcherTests.swift` (Swift Testing framework, not XCTest)

Test cases:
1. `Keyboard`/`LayoutInfo` Codable round-trip with Go-compatible JSON
2. `KeyboardStatus` raw value encoding (0, 1, 2)
3. Config JSON structure matches Go format (capitalized keys, `"keyboards"` root)
4. `ConfigService` load/save cycle (use temp directory)
5. Keyboard merge logic (no duplicates, config-first ordering)
6. `LayoutDetector.getAvailableLayouts()` returns non-empty
7. `KeyboardManager.setManagedKeyboards()` filters correctly

**Verify**: `xcodebuild test -project KezboardSwitcher.xcodeproj -scheme KezboardSwitcher`

---

### M9: First-Run Onboarding Wizard

**Why**: New users need guided setup — permission granting, explanation of how the app works, and initial keyboard configuration.

**New files**:
- `KezboardSwitcher/Features/Onboarding/OnboardingView.swift` — multi-step wizard container
- `KezboardSwitcher/Features/Onboarding/OnboardingStepView.swift` — reusable step component

**Steps**:
1. **Welcome** — app introduction, what it does
2. **Permissions** — explain input monitoring requirement, button to open System Settings (`x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent`), live status check showing whether permission is granted
3. **How it works** — brief explanation: "Connect keyboards, assign layouts, app switches automatically"
4. **Initial setup** — show detected keyboards, let user assign layouts immediately (reuse KeyboardListView + LayoutSelectorView from M5)
5. **Done** — confirmation, "Open Configuration" or "Close to menu bar"

**State tracking**: Store `hasCompletedOnboarding` in `UserDefaults`. `AppViewModel` checks this on launch — if `false` and permissions are granted, show onboarding instead of config UI. Integrate with M6's `.needsPermission` state.

**Verify**: Delete UserDefaults key → launch → see onboarding wizard → complete all steps → relaunch → go straight to config UI.

---

### M10: Localization / Translations

**Why**: Support multiple languages (de, en, fr, es, pt, nl per Go README).

**Target languages**: English (base), German, French, Spanish, Portuguese, Dutch

**Implementation**:
- Create `Localizable.xcstrings` (String Catalog, Xcode 15+) in the project
- Use `String(localized:)` or `LocalizedStringKey` for all user-facing strings
- Extract all hardcoded strings from views: status labels, button titles, onboarding text, error messages, menu items
- Add `.lproj` folders or use Xcode's String Catalog format (preferred for macOS 15.5 target)
- Localize `LayoutDetector` display names: use `kTISPropertyLocalizedName` (already locale-aware from macOS)

**Files to modify**:
- All view files (ContentView, KeyboardListView, LayoutSelectorView, PermissionOnboardingView, OnboardingView)
- AppDelegate (menu item titles)
- Error messages in KeyboardManager

**New files**:
- `KezboardSwitcher/Localizable.xcstrings` — String Catalog with all translations

**Verify**: Change macOS language in System Settings → launch app → verify all UI text appears in the selected language.

---

### M11: Local Keyboard Usage Statistics

**Why**: Users want to see how much they use each keyboard — useful for ergonomics tracking and curiosity.

**New files**:
- `KezboardSwitcher/Features/Statistics/StatisticsService.swift` — tracks and persists usage data
- `KezboardSwitcher/Features/Statistics/StatisticsView.swift` — displays usage data

**Data model**:
```swift
struct KeyboardUsageRecord: Codable {
    let keyboardName: String
    var totalSwitchCount: Int        // how many times switched to this keyboard
    var totalActiveSeconds: Double   // cumulative active time
    var lastUsed: Date?
    var dailyStats: [String: DailyStat]  // key: "yyyy-MM-dd"
}
struct DailyStat: Codable {
    var switchCount: Int
    var activeSeconds: Double
}
```

**Tracking**: Hook into `KeyboardManager.detectActiveKeyboard()` — when keyboard changes:
1. Record switch event (increment count)
2. Calculate duration on previous keyboard (time since last switch)
3. Persist periodically (every 60s or on app background)

**Storage**: JSON file at `~/Library/Application Support/kezboard_switcher/statistics.json`

**UI**: New tab or section in config window showing:
- Per-keyboard: total time, switch count, last used
- Daily breakdown (simple bar chart or list)
- "Today" / "This Week" / "All Time" toggle

**Menu bar integration**: Optionally show current keyboard name in the menu bar status item.

**Verify**: Use different keyboards → check statistics view → verify counts increment and time accumulates. Quit and relaunch → verify data persists.

---

## Dependency Graph

```
M1 (Codable models)
 ├──► M2 (Config service)  ──►─┐
 └──► M3 (Layout detector) ──►─┤
                                ├──► M4 (ViewModel + merge)
                                │         │
                                │         ▼
                                │    M5 (Full UI)
                                │         │
                                │         ▼
                                │    M6 (Permissions)
                                │         │
                                │         ▼
                                └──► M7 (Menu bar / background)
                                          │
                                     ┌────┼────────┐
                                     ▼    ▼        ▼
                                M9 (Onboarding) M10 (i18n)  M11 (Statistics)
                                     │    │        │
                                     └────┼────────┘
                                          ▼
                                     M8 (Tests — ideally incremental with each milestone)
```

M2 and M3 are independent and can be done in parallel. M9, M10, and M11 are independent of each other and can be done in any order after M7. M8 should be written alongside each milestone.

---

## File Inventory

| File (relative to `KezboardSwitcher/KezboardSwitcher/`) | Action | Milestone |
|---|---|---|
| `Shared/Keyboard.swift` | Modify | M1 |
| `Features/Configuration/ConfigService.swift` | Create | M2 |
| `Features/CoreLogic/LayoutDetector.swift` | Implement | M3 |
| `Features/Configuration/AppViewModel.swift` | Create | M4 |
| `Features/Configuration/View/ContentView.swift` | Rewrite | M5 |
| `Features/Configuration/View/KeyboardListView.swift` | Create | M5 |
| `Features/Configuration/View/LayoutSelectorView.swift` | Create | M5 |
| `Features/Configuration/View/PermissionOnboardingView.swift` | Create | M5/M6 |
| `App/KezboardSwitcherApp.swift` | Modify | M7 |
| `App/AppDelegate.swift` | Implement | M7 |
| `../KezboardSwitcherTests/KezboardSwitcherTests.swift` | Implement | M8 |
| `Features/Onboarding/OnboardingView.swift` | Create | M9 |
| `Features/Onboarding/OnboardingStepView.swift` | Create | M9 |
| `Localizable.xcstrings` | Create | M10 |
| All view files + AppDelegate | Modify (extract strings) | M10 |
| `Features/Statistics/StatisticsService.swift` | Create | M11 |
| `Features/Statistics/StatisticsView.swift` | Create | M11 |

## Go Reference Files

| Purpose | Path (in `/Users/stefan/code/go/kezboard_switcher/`) |
|---|---|
| Config persistence | `pkg/config/config.go` |
| Data models | `pkg/core/models/keyboard.go`, `pkg/core/models/layout.go` |
| Layout detection | `pkg/core/macos/layouts/layout_detector.go` |
| App orchestration / merge logic | `pkg/ui/app.go` |
| UI components | `frontend/src/App.svelte`, `frontend/src/components/KeyboardList.svelte`, `frontend/src/components/LayoutSelector.svelte` |
| HID + switching | `pkg/core/macos/keyboards/switcher.go`, `pkg/core/macos/keyboards/iohid_manager.go` |
| Entitlements | `build/darwin/Entitlements.plist` |
