# Lily-ios plan

Goal: a native iPhone/iPad browser with the same privacy rules as Lily-macos, sharing every UI-free
piece through [LilyKit](https://github.com/Lily-browser/LilyKit). Simulator-only until the paid
Developer Program exists (device builds, TestFlight, App Store, iOS extensions on device).

## Milestones
| # | Milestone | Needs | Status |
|---|---|---|---|
| 1 | App skeleton: one `WKWebView`, address bar (LilyKit `URLResolver` + `HTTPSFirst`), tab list, CI | LilyKit 0.1.0 | **done** |
| 2 | Tabs: spaces, pinned, card-grid overview with in-memory thumbnails, restore on launch, Settings (theme, accent, search engine, privacy toggles, spaces) | | **done** (session is sealed with a Keychain key since 2b) |
| 2b | Shared tab model, sealed session, hibernation, thousands of tabs | LilyKit 0.2.0 | model and sealed session **done**; hibernation (web view only for visible tab, `TabSleepPolicy`) next |
| 3 | Privacy core: content blocking via `WKContentRuleList` from LilyKit's converted rules; tracking-parameter stripping; per-site settings; private tabs (non-persistent store) | LilyKit ad-block, `SiteSettings` | ad and tracker blocking (built-in + filter lists, Settings) **done**; per-site settings, private tabs, tracking-parameter stripping (done) |
| 4 | Library: history, bookmarks, downloads, find in page, share sheet, reader-style start page | LilyKit `History`, `Bookmarks` | |
| 5 | Assistant (Ollama on the LAN / Mac), command palette | LilyKit `Agent` | |
| 6 | Continuity: Handoff with Lily-macos; sync only after #102 is decided | | |
| 7 | Extensions (`WKWebExtensionController`, iOS 18.4+); migration from Safari/Chrome exports | LilyKit `Extensions`, `Migration` | |
| 8 | Release: icon variants, App Store assets, TestFlight | paid membership (device installs work free, see docs/DEVICE.md) | blocked |

## iPad and foldables
- **Done:** one app, two layouts chosen by size class, not by device. Compact width (iPhone, folded phones, narrow Stage Manager windows): bottom bar and card-grid tab overview. Regular width (iPad, unfolded foldables, wide windows): the Mac's sidebar (pinned tiles, space, tabs, space switcher) plus a system toolbar with address pill; sidebar width is capped so the page keeps the room.
- **Done, from the Mac (iPad and wide windows):** Split View (two pages, focus by tapping a pane header, ⌃⌘1 / ⌃⌘0), menu bar with the Mac's shortcuts (⌘T/W/⇧T/F/G/L/K/S/R/D/1–9/+/−/0, ⌃Tab, ⌥⌘[ ], ⌘P), find in page, reopen closed tab, duplicate, move to space, close below, drag to reorder, per-site zoom (this run only), links that open new windows become tabs, extra windows (⌘N, Open in New Window).
- **Planned, from the Mac:** more split layouts (stacked, 3, 2×2) and Link Scrolling, drag and drop between windows and apps, ad and tracker blocking, history and bookmarks, site settings (needs signed builds for LilyKit's sealed storage).
- **Not planned on iOS:** the assistant, Little Lily and pointer hover states (decided 2026-11-20).
- iPadOS runs only iPadOS builds. Macs can run this app as an iPad app or via Mac Catalyst, but Lily-macos stays a native AppKit app; the two share LilyKit and the design language, not the UI code.

## Architecture rules
- The app target holds only SwiftUI views, navigation and the `WKWebView` lifecycle. Anything useful on the Mac
  goes to LilyKit first (PR there, tag, bump the exact pin here).
- A web view exists only for the visible tab; other tabs are `TabItem` metadata (milestone 1 already works this way).
- No analytics, no network except the user's page loads; secrets in the Keychain only.

## Working here
`brew install xcodegen`, then `make test` (generates `Lily.xcodeproj` from `project.yml`, builds, tests on the simulator)
and `make lint`. The `.xcodeproj` is generated and not committed.
