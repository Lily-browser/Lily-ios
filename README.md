# Lily for iOS

The iPhone and iPad app of [Lily](https://github.com/Lily-browser), a native, privacy-first WebKit browser. **Status: skeleton** — one web view, address bar, tab list; see [`docs/PLAN.md`](docs/PLAN.md) for the milestones.

## How it's built

- A SwiftUI shell over **WebKit** (`WKWebView`), sharing all platform-neutral logic with [Lily-macos](https://github.com/Lily-browser/Lily-macos) through **LilyKit**: sealed storage and the Keychain key store, history/bookmarks/site settings, page IPC, ad-block rule conversion, migration readers, the assistant client, extension manifest/audit logic.
- iOS-only here: the UI (tab switcher, address bar, share sheet), `WKContentRuleList` wiring, iOS web extension hosting (`WKWebExtensionController`, iOS 18.4+), Handoff with the Mac app, App Store/TestFlight packaging.
- Deployment target iOS 18. No Electron/web wrappers; no analytics; nothing leaves the device except the user's own page loads (see [PRIVACY](https://github.com/Lily-browser/Lily-macos/blob/main/docs/PRIVACY.md)).

## First milestones

1. ~~Xcode project that depends on a pinned LilyKit tag and shows a `WKWebView` with an address field.~~ Done (`make test`).
2. Tabs (metadata-first, web views only for visible tabs) and spaces, backed by LilyKit's stores.
3. Content blocking from LilyKit's converted rules; HTTPS-first and tracking-parameter stripping.
4. Extensions and Handoff.

Your own device works with a free Apple ID (docs/DEVICE.md). TestFlight and the App Store need the paid Apple Developer Program.

See [`CLAUDE.md`](CLAUDE.md) for the engineering rules. Licensed under GPL-3.0-only (see `LICENSE`).
