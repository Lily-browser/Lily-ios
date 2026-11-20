# Lily for iOS

The iPhone and iPad app of [Lily](https://github.com/Lily-browser), a native, privacy-first WebKit browser. **Status: not started** — this repository holds the plan and rules; the first code lands once [LilyKit](https://github.com/Lily-browser/LilyKit) 0.1.0 is tagged.

## How it's built

- A SwiftUI shell over **WebKit** (`WKWebView`), sharing all platform-neutral logic with [Lily-macos](https://github.com/Lily-browser/Lily-macos) through **LilyKit**: sealed storage and the Keychain key store, history/bookmarks/site settings, page IPC, ad-block rule conversion, migration readers, the assistant client, extension manifest/audit logic.
- iOS-only here: the UI (tab switcher, address bar, share sheet), `WKContentRuleList` wiring, iOS web extension hosting (`WKWebExtensionController`, iOS 18.4+), Handoff with the Mac app, App Store/TestFlight packaging.
- Deployment target iOS 18. No Electron/web wrappers; no analytics; nothing leaves the device except the user's own page loads (see [PRIVACY](https://github.com/Lily-browser/Lily-macos/blob/main/docs/PRIVACY.md)).

## First milestones

1. Xcode project (or SwiftPM app) that depends on a pinned LilyKit tag and shows a `WKWebView` with the command-bar address field.
2. Tabs (metadata-first, web views only for visible tabs) and spaces, backed by LilyKit's stores.
3. Content blocking from LilyKit's converted rules; HTTPS-first and tracking-parameter stripping.
4. Extensions and Handoff.

Device builds, TestFlight and the App Store need a paid Apple Developer Program membership (the same blocker as notarization for the Mac app); the simulator doesn't.

See [`CLAUDE.md`](CLAUDE.md) for the engineering rules. Licensed under GPL-3.0-only (see `LICENSE`).
