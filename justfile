# Build the app
build:
    xcodebuild -project KezboardSwitcher.xcodeproj -scheme KezboardSwitcher -configuration Debug build

# Run unit tests
test:
    xcodebuild test -project KezboardSwitcher.xcodeproj -scheme KezboardSwitcher -only-testing:KezboardSwitcherTests

# Remove stored license and onboarding state (for testing full flow from scratch)
reset:
    -security delete-generic-password -s "de.stevio.KezboardSwitcher.license"
    -defaults delete ~/Library/Preferences/de.stevio.KezboardSwitcher.plist onboardingCompleted
    -defaults delete ~/Library/Preferences/de.stevio.KezboardSwitcher.plist "de.stevio.KezboardSwitcher.onboardingCompleted"
    @echo "Reset complete. Run 'tccutil reset ListenEvent de.stevio.KezboardSwitcher' to also reset Input Monitoring permission."
