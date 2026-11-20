# Lily-ios plan

Goal: a native iPhone/iPad browser with the same privacy rules as Lily-macos, sharing every UI-free
piece through [LilyKit](https://github.com/Lily-browser/LilyKit). Simulator-only until the paid
Developer Program exists (device builds, TestFlight, App Store, iOS extensions on device).

## Milestones
| # | Milestone | Needs | Status |
|---|---|---|---|
| 1 | App skeleton: one `WKWebView`, address bar (LilyKit `URLResolver` + `HTTPSFirst`), tab list, CI | LilyKit 0.1.0 | **done** |
| 2 | Tabs proper: spaces, pinned, restore on launch (sealed session), hibernation, thousands of tabs | LilyKit issue #3 (shared `TabModel`, `SessionStore`) | next |
| 3 | Privacy core: content blocking via `WKContentRuleList` from LilyKit's converted rules; tracking-parameter stripping; per-site settings; private tabs (non-persistent store) | LilyKit ad-block, `SiteSettings` | |
| 4 | Library: history, bookmarks, downloads, find in page, share sheet, reader-style start page | LilyKit `History`, `Bookmarks` | |
| 5 | Assistant (Ollama on the LAN / Mac), command palette | LilyKit `Agent` | |
| 6 | Continuity: Handoff with Lily-macos; sync only after #102 is decided | | |
| 7 | Extensions (`WKWebExtensionController`, iOS 18.4+); migration from Safari/Chrome exports | LilyKit `Extensions`, `Migration` | |
| 8 | Release: icon variants, App Store assets, TestFlight | paid membership | blocked |

## Architecture rules
- The app target holds only SwiftUI views, navigation and the `WKWebView` lifecycle. Anything useful on the Mac
  goes to LilyKit first (PR there, tag, bump the exact pin here).
- A web view exists only for the visible tab; other tabs are `TabItem` metadata (milestone 1 already works this way).
- No analytics, no network except the user's page loads; secrets in the Keychain only.

## Working here
`brew install xcodegen`, then `make test` (generates `Lily.xcodeproj` from `project.yml`, builds, tests on the simulator)
and `make lint`. The `.xcodeproj` is generated and not committed.
