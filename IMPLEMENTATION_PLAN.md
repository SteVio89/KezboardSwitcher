# KezboardSwitcher: Full Swift Migration Plan (M1-M11)

## Context

KezboardSwitcher is a macOS utility that auto-switches keyboard input layouts when the user types on a different physical keyboard. A working Go/Wails version exists at `/Users/stefan/code/go/kezboard_switcher`. The Swift rewrite has HID detection + layout switching working (`KeyboardManager.swift`, 250 lines), but needs persistence, full UI, background operation, onboarding, localization, and lightweight statistics.

**Key decisions:**
- Menu bar only (no Dock icon ever) — `LSUIElement = true`
- Config path: `~/Library/Application Support/kezboard_switcher/config.json` (same as Go, enables migration)
- `@Observable` (macOS 15.5 target)
- Statistics: switch counts only (no time tracking, no keystroke monitoring)
- Localization: all 6 languages (en, de, fr, es, pt, nl), generated translations
- Tests: Swift Testing framework

---

## Pre-requisite: Fix Deployment Target

The main app target overrides `MACOSX_DEPLOYMENT_TARGET` to `13.5` (pbxproj lines 503, 534). Must change both to `15.5` for `@Observable` support.

**File:** `KezboardSwitcher.xcodeproj/project.pbxproj`

---

## M1: Make Models Codable

**File:** `KezboardSwitcher/Shared/Keyboard.swift`

- Add `Codable`, `Hashable`, `Equatable` to `KeyboardStatus`, `LayoutInfo`, `Keyboard`
- Add `Identifiable` to `Keyboard` with `var id: String { name }`
- Change all `let` properties to `var`
- Add `CodingKeys` with Go-compatible capitalized JSON keys:
  - `Keyboard`: `name`->`"Name"`, `status`->`"Status"`, `layoutInfo`->`"LayoutInfo"`
  - `LayoutInfo`: `layoutId`->`"LayoutId"`, `layoutName`->`"LayoutName"`
- `KeyboardStatus` encodes as raw `Int` (0/1/2) — matches Go's iota

---

## M2: Config Persistence Service

**New file:** `KezboardSwitcher/Features/Configuration/ConfigService.swift`

- Private `ConfigFile` struct: `{ keyboards: [Keyboard] }` (lowercase `"keyboards"` key — matches Go)
- `ConfigService` class with injectable URL for testing
- `load() -> [Keyboard]`: decode JSON, return `[]` if file missing
- `save(keyboards:)`: create directory if needed, encode with `.prettyPrinted` + `.sortedKeys`, write atomically
- Path: `FileManager.default.urls(for: .applicationSupportDirectory)` + `kezboard_switcher/config.json`

---

## M3: Layout Detector (Native TIS)

**File:** `KezboardSwitcher/Features/CoreLogic/LayoutDetector.swift` (implement stub)

- `import Carbon`
- `func getAvailableLayouts() -> [LayoutInfo]`
- Filter: `kTISPropertyInputSourceCategory == kTISCategoryKeyboardInputSource`, enabled only
- Extract `kTISPropertyInputSourceID` -> `layoutId`, `kTISPropertyLocalizedName` -> `layoutName`
- Follows same TIS pattern as `KeyboardManager.switchToLayout()` (lines 216-248)

**M2 and M3 are independent — can be implemented in parallel.**

---

## M4: App ViewModel + Merge Logic

**New file:** `KezboardSwitcher/Features/Configuration/AppViewModel.swift`

- `enum AppState { case loading, needsPermission, ready, error(String) }`
- `@Observable class AppViewModel` owns `KeyboardManager?`, `ConfigService`, `LayoutDetector`
- Properties: `keyboards`, `layouts`, `selectedKeyboard`, `appState`
- `initialize()`: try creating `KeyboardManager`, catch -> `.needsPermission`
- `loadKeyboards()`: merge config + detected (config first, append new detections by name)
- `saveConfig()`: persist via ConfigService, update `KeyboardManager.setManagedKeyboards()`
- `assignLayout(to:layout:)`, `toggleIgnore(keyboard:)`

**Merge logic** (matches Go's `GetKeyboards()` + `isNewKnownKeyboard()`):
```swift
func mergeKeyboards(configured: [Keyboard], detected: [Keyboard]) -> [Keyboard] {
    var merged = configured
    for kb in detected where !merged.contains(where: { $0.name == kb.name }) {
        merged.append(kb)
    }
    return merged
}
```

---

## M5: Full Configuration UI

### Rewrite: `KezboardSwitcher/Features/Configuration/View/ContentView.swift`
- Switch on `appState`: loading -> ProgressView, needsPermission -> PermissionView, ready -> HSplitView, error -> retry

### New: `KezboardSwitcher/Features/Configuration/View/KeyboardListView.swift`
- `List(selection:)` with status badges (blue=new, green=configured, red=ignored)

### New: `KezboardSwitcher/Features/Configuration/View/LayoutSelectorView.swift`
- Layout list for selected keyboard, ignore/unignore toggle, click-to-assign, save button

### New: `KezboardSwitcher/Features/Configuration/View/PermissionOnboardingView.swift`
- Explains input monitoring, privacy reassurance, "Open System Settings" button

---

## M6: Permission Detection

Integrated into `AppViewModel.initialize()` (M4) — no separate files.

- `KeyboardManager()` throws on IOKit access denied -> set `.needsPermission`
- System Settings URL: `x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent`
- Add "Check Again" button that re-calls `initialize()`
- Note: may need full app restart for permission to take effect

---

## M7: Menu Bar / Background Operation

### Implement: `KezboardSwitcher/App/AppDelegate.swift`
- `NSStatusItem` with SF Symbol `keyboard` icon
- Menu: "Open Configuration", separator, "Quit"
- No `setActivationPolicy` call — use `LSUIElement` instead (see below)

### Modify: `KezboardSwitcher/App/KezboardSwitcherApp.swift`
- `@NSApplicationDelegateAdaptor(AppDelegate.self)`
- `@State var viewModel = AppViewModel()` at App level (persists when window closes)
- Use `Window` (single instance) instead of `WindowGroup`

### Modify: `project.pbxproj`
- Add `INFOPLIST_KEY_LSUIElement = YES` to build settings (standard menu-bar-only pattern)

**Critical ownership:** `App` -> `AppViewModel` -> `KeyboardManager` (all persist forever). Window/views are transient.

---

## M8: Tests (Swift Testing)

**File:** `KezboardSwitcherTests/KezboardSwitcherTests.swift` (auto-discovered, no pbxproj edits)

1. Keyboard Codable round-trip with Go JSON string
2. Encode/decode symmetry
3. KeyboardStatus raw values (0, 1, 2)
4. ConfigFile JSON has lowercase `"keyboards"` root key
5. ConfigService load/save cycle (temp directory)
6. Load non-existent file returns `[]`
7. Merge logic: no duplicates, config-first ordering
8. LayoutDetector returns non-empty (integration test)

Tests should be written incrementally with each milestone, not deferred to the end.

---

## M9: First-Run Onboarding Wizard

### New: `KezboardSwitcher/Features/Onboarding/OnboardingView.swift`
- Multi-step wizard with `@State var currentStep`
- Steps: Welcome -> Permissions -> How it works -> Initial setup (reuse M5 views) -> Done
- `@AppStorage("hasCompletedOnboarding")` tracking

### New: `KezboardSwitcher/Features/Onboarding/OnboardingStepView.swift`
- Reusable step component (icon, title, description, content slot)

**Integration:** In ContentView, if `!hasCompletedOnboarding && appState == .ready`, show onboarding. If `appState == .needsPermission`, show onboarding at permissions step regardless.

---

## M10: Localization

### New: `KezboardSwitcher/Localizable.xcstrings`
- String Catalog with all 6 languages (en, de, fr, es, pt, nl)
- All user-facing strings from views, AppDelegate menu items, error messages, status labels

### Modify: All view files + AppDelegate
- Replace hardcoded strings with `String(localized:)` / `LocalizedStringKey`

### Modify: `project.pbxproj`
- Add to `knownRegions`: de, fr, es, pt, nl
- Add `Localizable.xcstrings` to Resources build phase

---

## M11: Lightweight Statistics

### New: `KezboardSwitcher/Features/Statistics/StatisticsService.swift`
- Simple model: `struct KeyboardSwitchStats: Codable { var switchCounts: [String: Int] }`
- `recordSwitch(keyboardName:)`: increment counter
- Persists to `~/Library/Application Support/kezboard_switcher/statistics.json`

### New: `KezboardSwitcher/Features/Statistics/StatisticsView.swift`
- Simple list: "Keyboard X: N switches"
- Accessible from menu bar menu or config window section

### Modify: `KezboardSwitcher/Features/CoreLogic/KeyboardManager.swift`
- Add `var onKeyboardSwitch: ((String) -> Void)?` callback
- Call from `detectActiveKeyboard()` after updating `lastKeyboard`
- AppViewModel wires this to `statisticsService.recordSwitch()`

---

## Xcode Project File Strategy

New `.swift` files need 4 additions to `project.pbxproj`: PBXFileReference, PBXBuildFile, PBXGroup child, PBXSourcesBuildPhase entry. New groups needed for `Onboarding` and `Statistics` under `Features`.

**10 new files total:**
| File | Group |
|------|-------|
| `ConfigService.swift` | Configuration |
| `AppViewModel.swift` | Configuration |
| `KeyboardListView.swift` | View |
| `LayoutSelectorView.swift` | View |
| `PermissionOnboardingView.swift` | View |
| `OnboardingView.swift` | Onboarding (new) |
| `OnboardingStepView.swift` | Onboarding (new) |
| `Localizable.xcstrings` | KezboardSwitcher (Resources) |
| `StatisticsService.swift` | Statistics (new) |
| `StatisticsView.swift` | Statistics (new) |

---

## Execution Order

```
Pre-req: Fix deployment target (15.5)
   |
   v
M1: Models Codable
   |
   +--> M2: ConfigService  --+
   |                         |--> M4: ViewModel + Merge
   +--> M3: LayoutDetector --+         |
                                       v
                                 M5+M6: Full UI + Permissions
                                       |
                                       v
                                 M7: Menu Bar
                                       |
                          +------------+------------+
                          v            v            v
                    M9: Onboarding  M10: i18n   M11: Stats

M8: Tests written incrementally with each milestone
```

## Verification

After all milestones:
1. `xcodebuild -project KezboardSwitcher.xcodeproj -scheme KezboardSwitcher build` — clean build
2. `xcodebuild test -project KezboardSwitcher.xcodeproj -scheme KezboardSwitcher` — all tests pass
3. Manual: Launch -> onboarding wizard appears -> grant permissions -> configure keyboards -> save -> close window -> menu bar icon persists -> layout switching works -> relaunch -> config persisted -> stats increment on keyboard switch
4. Manual: Change macOS language -> verify localized strings
