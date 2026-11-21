# Lily for iOS

The iPhone and iPad app of [Lily](https://github.com/Lily-browser), a native, privacy-first WebKit browser.
**Status: early, runs in the simulator and on your own device** (free Apple ID, see [`docs/DEVICE.md`](docs/DEVICE.md)).
TestFlight and the App Store wait for the paid Apple Developer Program. Milestones: [`docs/PLAN.md`](docs/PLAN.md).

## What works today

- **Tabs and spaces:** pinned and regular tabs, spaces with their own tabs, a card-grid tab overview, drag to reorder, reopen closed tabs, duplicate, move to a space. Only the visible tab has a web view; the rest are metadata, so thousands of tabs are cheap.
- **iPhone and iPad:** one app, two layouts by size class: a bottom bar that slides away while you read (compact), and the Mac's sidebar with Split View, a menu bar with the Mac's shortcuts, find in page and extra windows (regular).
- **Privacy:** ad and tracker blocking through `WKContentRuleList` (EasyList and EasyPrivacy on by default, more in Settings), HTTPS-first, tracking-parameter removal, per-site settings (zoom, dark mode, JavaScript, ads), and private tabs on a non-persistent data store that is never saved or offered for reopening.
- **Library:** bookmarks, history (by day, searchable, can be turned off) and downloads (saved to Files); the command bar suggests them.
- **Open in Lily:** a Share extension ("Lily" in the share sheet) and the `lily://open?url=` link open a page in a new tab. Lily can't be the system's default browser without the paid program (see [`docs/RELEASE.md`](docs/RELEASE.md)).
- **Safe by default:** pages can't open `file:` or `data:` addresses, scripts get one pop-up per page, downloads go to their own temporary folder, a failed load shows an error page, and private tabs are hidden in the app switcher ([`docs/SECURITY-TEST-PLAN.md`](docs/SECURITY-TEST-PLAN.md)).
- **Saved session:** sealed with a Keychain key (LilyKit `TabSessionStore`), so addresses that carry tokens never touch disk in plaintext.
- The Lily mark as app icon (light, dark and tinted). Security reports: [`SECURITY.md`](SECURITY.md).

Not planned on iOS: the assistant, Little Lily and pointer hover states.

## How it's built

- A SwiftUI shell over **WebKit** (`WKWebView`). Everything with no UI is in [LilyKit](https://github.com/Lily-browser/LilyKit), shared with [Lily-macos](https://github.com/Lily-browser/Lily-macos): the tab model (`TabCollection`), sealed storage and the Keychain key store, site settings, ad-block rule conversion, URL resolution. `BrowserModel` is a thin layer over `TabCollection`, so tab rules behave the same as on the Mac.
- iOS-only here (`Sources/`): the views (`UI/`), the web view and its lifecycle (`Browser/`), commands and the app entry (`App/`).
- LilyKit is pinned to an exact tag in `project.yml`; a kit change reaches this app only through a reviewed bump.
- Deployment target iOS 18. No Electron or web wrappers, no analytics; nothing leaves the device except your page loads and filter-list downloads (see [PRIVACY](docs/PRIVACY.md)).

## Development

```sh
brew install xcodegen
make lint     # static security checks (scripts/security-lint.sh)
make test     # generate Lily.xcodeproj from project.yml, build, test on the simulator
make device   # run on your own iPhone (docs/DEVICE.md)
```

The `.xcodeproj` is generated and not committed. Engineering rules: [`CLAUDE.md`](CLAUDE.md). Security testing: [`docs/SECURITY-TEST-PLAN.md`](docs/SECURITY-TEST-PLAN.md).

Licensed under GPL-3.0-only (see `LICENSE`).
