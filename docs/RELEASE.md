# Releasing Lily for iOS

Today Lily installs on your own devices with a free Apple ID (docs/DEVICE.md): it expires after 7 days, has no TestFlight, and can't
be the default browser. Everything below needs the **Apple Developer Program** (99 USD / year). Nothing in the code has to change for
it; the release is configuration.

## Why the paid program, and what it does not change
- TestFlight and the App Store, and builds that don't expire after 7 days.
- The **default browser** entitlement (`com.apple.developer.web-browser`), which Apple grants by request, only to the paid program.
- It does not make the app less safe. Apple signs the build with a key held in the account, and a user can verify an App Store build
  is the one you shipped. What can go wrong is the account itself: protect it (below), and the risk stays small.

## Protecting the account and the keys
- Two-factor authentication on the Apple ID, with a hardware key or passkey if possible; a recovery contact; no shared logins.
- Use **Xcode-managed signing** (certificates stay in the Keychain, private key never in the repository). If you ever need a certificate in CI,
  keep it only as a GitHub Actions secret on a protected branch, never in a PR build (the Mac pipeline already works that way).
- App Store Connect: your account is *Account Holder*; add nobody else, or only with the *Developer* role (no access to sales or legal).
- Keep the repository's own protections on: reviewed PRs into `main`, signed commits, immutable release tags.

## Checklist, in order
1. **Enrol** (developer.apple.com/programs). An individual account is enough for one person; an organisation needs a D-U-N-S number.
2. **Identifiers**: bundle id `dev.lily.browser.ios` and `dev.lily.browser.ios.share` (the Share extension). Set `DEVELOPMENT_TEAM` for the paid team.
3. **Default browser** (optional, later): request the Web Browser entitlement at developer.apple.com/contact/request/default-browser-entitlement
   (the app must be a real browser, which it is). Once granted, add it to the target's entitlements and declare `http` and `https` under
   `CFBundleURLTypes`; then Lily appears under Settings → Apps → Default Browser App.
4. **App Store Connect record**: name, subtitle, category (Utilities or Productivity), age rating, price.
5. **Privacy**: App Privacy answers *Data Not Collected* (matches `Sources/PrivacyInfo.xcprivacy` and docs/PRIVACY.md); privacy policy URL
   `https://github.com/Lily-browser/Lily-ios/blob/main/docs/PRIVACY.md`. Export compliance: the app only uses encryption provided by the OS (HTTPS,
   Keychain, CryptoKit) so `ITSAppUsesNonExemptEncryption` is `false`; confirm that with the questionnaire when asked.
6. **Screenshots**: iPhone 6.9" and iPad 13" (the simulators in `xcrun simctl`), light and dark; an app preview is optional.
7. **Review notes**: Lily uses WKWebView only (no other engine); explain that camera, microphone and location are asked per website;
   a demo is just "open any website". Mention the Share extension and the `lily://` link.
8. **Build**: `xcodebuild archive` with the Release configuration, then upload through Xcode Organizer. Check the archive has no
   `get-task-allow` (`codesign -d --entitlements - Lily.app`), is arm64 only, and `Info.plist` has the usage strings.
9. **TestFlight**: internal testing first (your own devices, no review), then external if you want testers.
10. **Submit for review**, release manually after approval.

## Before every release
- `make lint` and `make test` pass; the simulator build is clean.
- Re-run the security test plan, passes A and B (docs/SECURITY-TEST-PLAN.md); pass C on a device before the first TestFlight build.
- LilyKit pinned by exact tag; Dependabot has no open security alerts.
- Version and build number bumped; release notes written.
