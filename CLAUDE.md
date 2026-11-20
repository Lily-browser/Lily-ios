# Lily-ios — Claude Rules

Native iOS app: Swift + SwiftUI, WebKit (`WKWebView`) only. Shares platform-neutral logic with Lily-macos via the **LilyKit** package. No Electron/web wrappers. Priorities: user delight, low energy/RAM (zero idle wake-ups), small binary.

## Token discipline (user is token-constrained)
- Work inline; at most one `builder` per task for large multi-file work; run gates yourself; short reports.
- End with "`/compact` now (or `/clear` before an unrelated task)" after a PR or in a long session.

## Layering
- **LilyKit owns everything with no UI** (storage, models, IPC, ad-block conversion, migration, assistant client, extension logic). If logic would be useful on macOS too, add it to LilyKit (PR there, tag, then bump the pin here). Never copy kit code into this repo.
- **This repo owns**: SwiftUI views, navigation, iOS tab/web-view lifecycle, share/handoff, iOS extension hosting, packaging.
- Pin LilyKit with `exact:` (tag) or `revision:`; no `.package(path:)` committed.

## Code rules (same as the other repos; add scripts/security-lint.sh once code exists)
- `async/await`, `actor`, `@MainActor`; Swift 6, strict concurrency complete.
- `os.Logger` with `privacy: .sensitive` on dynamic values; no `print`/`NSLog`.
- Secrets in the Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`); never UserDefaults/files.
- WebKit: schema-validated JSON message handlers; no `eval`/string timers/`innerHTML` with dynamic input; no interpolated JS strings; no `allowFileAccessFromFileURLs`.
- No unsafe pointers; UI errors sanitized. Minimal entitlements/capabilities. SPM deps pinned.
- Tabs: metadata-first `struct TabItem`, web views only for visible tabs, hibernate idle tabs; must handle thousands of tabs.

## Build and gates
Simulator builds need no Apple account; device/TestFlight need the paid Developer Program (not bought yet). Gates before a PR: lint, unit tests, simulator build.

## Git
On `main`, branch first (`feature/…`, `fix/…`). Conventional, atomic, signed commits. When done: push and open the PR to `main` automatically.
