# KezboardSwitcher

<p align="center">
  <img src="Assets/AppIcon.svg" width="128" height="128" alt="KezboardSwitcher icon">
</p>

<p align="center">
  <strong>Automatic keyboard layout switching for macOS</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2015.5%2B-blue" alt="macOS 15.5+">
  <img src="https://img.shields.io/badge/swift-5-orange" alt="Swift 5">
</p>

---

KezboardSwitcher is a lightweight macOS menu bar app that automatically switches your keyboard input layout when you switch between physical keyboards. Perfect for multilingual users who use different layouts on different keyboards (e.g. US on an external keyboard, German on the MacBook).

## How It Works

1. Plug in your keyboards
2. Assign a layout to each keyboard in the configuration window
3. KezboardSwitcher detects which keyboard you're typing on and instantly switches the macOS input source

No more manually toggling layouts every time you switch keyboards.

## Features

- **Automatic layout switching** — detects keyboard changes via IOKit HID and switches input source instantly
- **Menu bar app** — runs silently in the background with no Dock icon
- **Per-keyboard configuration** — assign any enabled macOS input source to each keyboard
- **Ignore list** — mark keyboards you don't want to trigger switches (e.g. YubiKey, Touch Bar)
- **Switch HUD** — a brief on-screen overlay confirms the layout each time it switches
- **Statistics** — track how often you switch keyboards with daily charts and per-keyboard usage breakdowns
- **Guided onboarding** — a first-launch wizard walks you through privacy, permissions and license activation
- **Persistent config** — settings saved to `~/.config/KezboardSwitcher/config.json`

## Screenshots

| Configuration | Statistics |
|:---:|:---:|
| Assign layouts to keyboards | Track your switching patterns |

## Installation

### Requirements

- macOS 15.5 or later
- **Input Monitoring** permission (required for keyboard detection)
- A valid license key to activate the app (see [Licensing](#licensing))

### Build from Source

```bash
git clone https://github.com/stevio/KezboardSwitcher.git
cd KezboardSwitcher
xcodebuild -project KezboardSwitcher.xcodeproj -scheme KezboardSwitcher -configuration Release build
```

The built app will be in `~/Library/Developer/Xcode/DerivedData/KezboardSwitcher-*/Build/Products/Release/`.

## Usage

- **Left-click** the menu bar icon to open the configuration window
- **Right-click** for the context menu (Open Configuration / Quit)
- The app starts minimized to the menu bar on subsequent launches
- On first launch, a setup wizard guides you through welcome, privacy, Input Monitoring permission and license activation before the app becomes active

### Configuring a Keyboard

1. Open the configuration window
2. Select a keyboard from the list on the left
3. Choose a layout from the dropdown on the right
4. Click **Save** to persist your configuration

Keyboards are automatically detected when connected. New keyboards appear with a "New" badge until configured.

### Permissions

KezboardSwitcher requires **Input Monitoring** access to detect which keyboard you're typing on. On first launch, you'll be guided to enable this in System Settings > Privacy & Security > Input Monitoring.

> The app sandbox is disabled because IOKit HID access is not available in sandboxed apps.

### Licensing

KezboardSwitcher is activated with a license key. On activation the app contacts the
activation server (`https://stevio.de`), which returns an **Ed25519-signed license** bound to
the current machine. The signature is verified against a public key pinned in the binary, so
after the first activation the license is validated **offline** on every launch.

- The signed license is stored at `~/Library/Application Support/KezboardSwitcher/license.json`
- A license is tied to one machine via a hardware-derived machine hash; use the wizard's
  deactivation flow to move it to another Mac
- Debug builds talk to `http://localhost:3000` instead of the production server

## Architecture

```
KezboardSwitcher/
  App/                          # App entry point and delegate
  Features/
    Configuration/              # ConfigService, AppViewModel
      View/                     # ContentView, KeyboardListView, LayoutSelectorView,
                                #   PermissionOnboardingView, TroubleshootView
    CoreLogic/                  # KeyboardManager (IOKit HID), LayoutDetector (TIS API), SwitchHUD
    Licensing/                  # LicenseService (Ed25519 verification), LicenseActivationView
    Onboarding/                 # OnboardingWizardView (first-launch setup)
    Statistics/                 # StatisticsService (SQLite)
      View/                     # StatisticsView
  Shared/                       # Keyboard model, Theme
```

The app uses a straightforward SwiftUI + `@Observable` architecture:

- **KeyboardManager** — listens for HID keyboard events via `IOHIDManager` and detects when you switch keyboards
- **LayoutDetector** — wraps Carbon's Text Input Source (TIS) API to enumerate and switch input layouts
- **ConfigService** — persists keyboard-to-layout mappings as JSON
- **StatisticsService** — records switch events in a local SQLite database
- **SwitchHUD** — presents the brief on-screen overlay shown on each layout switch
- **LicenseService** — activates and verifies the Ed25519-signed, machine-bound license
- **AppViewModel** — ties everything together as the single source of truth

## Development

```bash
# Build
xcodebuild -project KezboardSwitcher.xcodeproj -scheme KezboardSwitcher -configuration Debug build

# Run tests
xcodebuild test -project KezboardSwitcher.xcodeproj -scheme KezboardSwitcher -only-testing:KezboardSwitcherTests
```

To reset local state (stored license, onboarding flag) back to a fresh-install condition:

```bash
just reset
```

It also prints the `tccutil` command to reset the Input Monitoring permission.

### Release / Distribution

Distribution builds are produced from Xcode: **Product > Archive**, then distribute the
archive from the Organizer with **Developer ID** signing and Apple notarization. Note that
release builds verify licenses against the production server (`https://stevio.de`).

#### Packaging the exported `.app` as a DMG

Run this from the directory containing the exported `KezboardSwitcher.app`:

```bash
STAGE=$(mktemp -d)
ditto KezboardSwitcher.app "$STAGE/KezboardSwitcher.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname KezboardSwitcher -srcfolder "$STAGE" -ov -format UDZO KezboardSwitcher.dmg
rm -rf "$STAGE"
```

The `/Applications` symlink gives the drag-to-install window. The notarization ticket is
already stapled into the exported app by the Organizer.

## License

Copyright (c) 2026 Stefan Viol. All rights reserved.

This is proprietary software. Unauthorized copying, distribution, or modification is strictly prohibited.
