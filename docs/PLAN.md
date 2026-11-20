# Lily-ios plan

Goal: a native iPhone/iPad browser with the same privacy rules as Lily-macos, sharing every UI-free
piece through [LilyKit](https://github.com/Lily-browser/LilyKit). Simulator-only until the paid
Developer Program exists (device builds, TestFlight, App Store, iOS extensions on device).

## Milestones
| # | Milestone | Needs | Status |
|---|---|---|---|
| 1 | App skeleton: one `WKWebView`, address bar (LilyKit `URLResolver` + `HTTPSFirst`), tab list, CI | LilyKit 0.1.0 | **done** |
| 2 | Tabs: spaces, pinned, card-grid overview with in-memory thumbnails, restore on launch, Settings (theme, accent, search engine, privacy toggles, spaces) | | **done** (session file is file-protected JSON; move to LilyKit's sealed storage once builds are signed) |
| 2b | Shared tab model, sealed session, hibernation, thousands of tabs | LilyKit issue #3 | next |
| 3 | Privacy core: content blocking via `WKContentRuleList` from LilyKit's converted rules; tracking-parameter stripping; per-site settings; private tabs (non-persistent store) | LilyKit ad-block, `SiteSettings` | |
| 4 | Library: history, bookmarks, downloads, find in page, share sheet, reader-style start page | LilyKit `History`, `Bookmarks` | |
| 5 | Assistant (Ollama on the LAN / Mac), command palette | LilyKit `Agent` | |
| 6 | Continuity: Handoff with Lily-macos; sync only after #102 is decided | | |
| 7 | Extensions (`WKWebExtensionController`, iOS 18.4+); migration from Safari/Chrome exports | LilyKit `Extensions`, `Migration` | |
| 8 | Release: icon variants, App Store assets, TestFlight | paid membership | blocked |

## iPad and foldables
- **Done:** one app, two layouts chosen by size class, not by device. Compact width (iPhone, folded phones, narrow Stage Manager windows): bottom bar and card-grid tab overview. Regular width (iPad, unfolded foldables, wide windows): the Mac's sidebar (pinned tiles, space, tabs, space switcher) plus a system toolbar with address pill; sidebar width is capped so the page keeps the room.
- **Planned, from the Mac:** Split View (two pages side by side, drag a tab to the edge), multiple windows and Stage Manager (a window per space), drag and drop tabs between windows and apps, hardware-keyboard shortcuts beyond ⌘T/⌘L/⌘R/⌘[/⌘], pointer hover states, Little Lily (peek window).
- iPadOS runs only iPadOS builds. Macs can run this app as an iPad app or via Mac Catalyst, but Lily-macos stays a native AppKit app; the two share LilyKit and the design language, not the UI code.

## Architecture rules
- The app target holds only SwiftUI views, navigation and the `WKWebView` lifecycle. Anything useful on the Mac
  goes to LilyKit first (PR there, tag, bump the exact pin here).
- A web view exists only for the visible tab; other tabs are `TabItem` metadata (milestone 1 already works this way).
- No analytics, no network except the user's page loads; secrets in the Keychain only.

## Working here
`brew install xcodegen`, then `make test` (generates `Lily.xcodeproj` from `project.yml`, builds, tests on the simulator)
and `make lint`. The `.xcodeproj` is generated and not committed.
