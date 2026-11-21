# Running on your own iPhone/iPad without the paid program

A free Apple ID is enough to install on devices you own.

1. Xcode > Settings > Accounts: add your Apple ID (creates a *Personal Team*).
2. `cp Config/Local.xcconfig.example Config/Local.xcconfig`, set `DEVELOPMENT_TEAM` and a free bundle id.
3. Device: enable Developer Mode (Settings > Privacy & Security), connect, trust the computer.
4. `make device`, or run the Lily scheme from Xcode on the device. Trust the profile in Settings > General > VPN & Device Management.

Limits of the free tier: the app expires after 7 days (re-run to renew), 3 apps per device, 10 app ids per week.
No TestFlight, App Store, push, iCloud, app groups or associated domains. The Keychain (LilyKit sealed storage)
works. iOS web extensions on device and App Store assets (milestone 8) still need the paid program.
