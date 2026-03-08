# Build the app
build:
    xcodebuild -project KezboardSwitcher.xcodeproj -scheme KezboardSwitcher -configuration Debug build

# Run unit tests
test:
    xcodebuild test -project KezboardSwitcher.xcodeproj -scheme KezboardSwitcher -only-testing:KezboardSwitcherTests

# Remove stored license from Keychain (for testing activation flow)
reset-license:
    security delete-generic-password -s "de.stevio.KezboardSwitcher.license"
