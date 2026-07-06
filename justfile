reset:
    -rm -f ~/Library/Application\ Support/KezboardSwitcher/license.json
    -defaults delete ~/Library/Preferences/de.stevio.KezboardSwitcher.plist onboardingCompleted
    -defaults delete ~/Library/Preferences/de.stevio.KezboardSwitcher.plist "de.stevio.KezboardSwitcher.onboardingCompleted"
    @echo "Reset complete. Run 'tccutil reset ListenEvent de.stevio.KezboardSwitcher' to also reset Input Monitoring permission."
