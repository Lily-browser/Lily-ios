# Lily for iOS: security test plan

Scope: the iOS app (`dev.lily.browser.ios`) and the LilyKit code it runs. Three passes:

| Pass | Who | Where | What |
|---|---|---|---|
| **A. Static and source review** | Claude | repo | Code, config and dependency review; lint rules |
| **B. Dynamic, simulator** | Claude | iOS Simulator | Automated tests and instrumented runs; hostile pages served from localhost |
| **C. Device, jailbroken** | the owner | physical iPhone | Data at rest, Keychain, runtime tampering, network interception |

Findings go in a private GitHub security advisory (or `SECURITY.md`'s contact), never a public issue, until fixed.
Severity: **High** = data of a user's browsing readable or sent to someone it shouldn't be; **Medium** = a protection
can be bypassed with effort; **Low** = hardening. Each test below says what *pass* looks like.

## 1. What we protect, and from whom

| Asset | Where it lives | Threat |
|---|---|---|
| Open tab addresses (can carry tokens) | `Application Support/Lily/` sealed session (encrypted, key in the Keychain) | Someone with the unlocked file system, a backup, or a jailbroken phone reads them |
| Private-tab activity | `WKWebsiteDataStore.nonPersistent()` (memory) | Leaves traces on disk, in the app-switcher snapshot, or in the tab-overview thumbnails |
| Browsing choices (site settings, filter lists, preferences) | sealed site settings, `UserDefaults` | Tamper or read |
| Filter lists and compiled rules | `Application Support/Lily/filters/` | A poisoned list blocks the wrong thing or breaks pages |
| Page isolation | `WKWebView` | A hostile page reaches native code, other tabs, or local files |

Attackers considered: a malicious website; a network attacker (public Wi-Fi); a malicious link or another app that opens
Lily; someone with a lost, unlocked or backed-up device; the supply chain (LilyKit, filter-list hosts, CI actions).
Out of scope: WebKit's own engine bugs (report to Apple), a fully compromised OS.

## 2. Known observations to confirm first

From the code review that produced this plan. Each is covered by a test below.

1. **Address bar accepts `file:`, `data:` and `blob:` URLs** (`URLResolver.allowedSchemes`, shared with the Mac). On iOS this should be harmless (a `WKWebView` is not given file read access), but it needs a test. (A-4, B-3)
2. **No `WKNavigationDelegate.decidePolicyFor` and no download handling.** Pages can try `tel:`, `sms:`, app schemes, `itms-services:` and file downloads; the default WebKit behavior applies. Confirm nothing is opened without a tap and nothing hangs. (B-4, B-5)
3. **No certificate-error UI and no pinning on iOS.** WebKit refuses bad certificates by default; confirm there is no override path. (B-6)
4. **No camera, microphone or location usage strings in `Info.plist`.** `getUserMedia` and geolocation requests from pages should fail cleanly, not crash. (B-7)
5. **Tab-overview thumbnails are in memory only** (`SnapshotCache`); confirm private tabs are never captured, and the app-switcher snapshot hides private content. (B-8, C-6)
6. **Session file is sealed; the legacy plaintext `session.json` is migrated and deleted.** Confirm on a device that upgraded from an old build and on a fresh install. (C-2)
7. **Filter lists are fetched over HTTPS from third-party hosts** and converted on device. Confirm size limits, hash or TLS-only handling, and that a malformed list cannot crash the app. (A-5, B-9)

## 3. Pass A: static and source review (Claude)

| ID | Test | Pass |
|---|---|---|
| A-1 | `scripts/security-lint.sh` on iOS and LilyKit, plus `grep` for `evaluateJavaScript`, `WKScriptMessageHandler`, `loadHTMLString`, `loadFileURL`, `allowFileAccess*`, `javaScriptCanOpenWindowsAutomatically` | No use outside the reviewed list; every script message handler validates source and schema |
| A-2 | Info.plist and entitlements: ATS (`NSAppTransportSecurity` absent or no exceptions), `LSApplicationQueriesSchemes`, URL types, background modes, usage strings, app-group or keychain-group entitlements | Minimal; no `NSAllowsArbitraryLoads` |
| A-3 | Keychain: attribute classes (`AfterFirstUnlockThisDeviceOnly` expected), no `kSecAttrSynchronizable`, no secrets in `UserDefaults` | Matches `SecureStorage.swift`; no iCloud-syncable item |
| A-4 | URL handling: every place a user string or a page URL becomes a load (`go(to:)`, `open(_:)`, `createWebViewWith`, restore, Handoff later). Allowed schemes, `javascript:` rejected, `file:`/`data:` behavior | Only `http(s)` reach `WKWebView.load` from pages; address-bar exceptions documented |
| A-5 | Filter-list pipeline (`FilterLists`, `AdBlocker`, `FilterListConverter`): max size, timeouts, redirects, redirect-to-HTTP, parsing of hostile input, rule-count cap | Bounded memory and time; HTTPS only; rejected lists leave the old rules |
| A-6 | Sealed storage (`SecureStorage`, `TabSessionStore`): algorithm, nonce use, key derivation, key rotation, behavior when the Keychain refuses | AEAD with unique nonces; fails closed (nothing written in plaintext) |
| A-7 | Logging: every `os.Logger` interpolation has a privacy qualifier; nothing logs URLs or titles at `.public` | No sensitive values public |
| A-8 | Dependencies and CI: LilyKit exact pin, GitHub Actions pinned to SHAs, no third-party packages, Dependabot on, secret scanning on | All true; today Dependabot and secret scanning are off on this repo, so that is a finding to close |
| A-9 | Private tabs: every code path that stores a tab (session snapshot, `SiteSettings`, `SnapshotCache`, history, Handoff) excludes `privateIDs` | No path persists a private tab's URL, title or thumbnail |
| A-10 | Memory safety and concurrency: `@unchecked Sendable`, `nonisolated(unsafe)`, `assumeIsolated` uses | Each justified in a comment |

## 4. Pass B: dynamic tests on the simulator (Claude)

Automate what can be a unit or UI test and keep it in `Tests/`; the rest is a scripted run. Hostile pages are served from a
local server (`python3 -m http.server`) and reached at `http://localhost`.

| ID | Test | Pass |
|---|---|---|
| B-1 | `make test`; add tests for every fix | Green |
| B-2 | Sealed session round-trip, tamper (flip a byte), truncate, wrong key, missing key | Load returns nil, app starts with a blank tab, no crash, no plaintext written |
| B-3 | Type `file:///etc/hosts`, `file://` into the app container, `data:text/html,<script>…`, `blob:`, `javascript:alert(1)`, `about:blank` | Nothing outside the page sandbox is readable; `javascript:` never runs; no crash |
| B-4 | Page navigates to `tel:`, `sms:`, `mailto:`, `itms-services://`, `facetime:`, a custom `foo://`; `window.open` with each; `window.open` flood (200 calls) | No auto-launch without a user gesture; flood creates a bounded number of tabs or none |
| B-5 | Download triggers: `Content-Disposition: attachment`, a PDF, a 2 GB stream | App does not hang or fill storage; user sees a sane result |
| B-6 | Certificate errors: self-signed, expired, wrong host, HTTP-downgrade redirect (HTTPS-first fallback) | Load fails with an error; no bypass; fallback to HTTP asks or is blocked as designed |
| B-7 | Page calls `getUserMedia`, `geolocation`, `Notification.requestPermission`, clipboard read | Denied or prompted by the system; no crash |
| B-8 | Open a private tab, browse, background the app, screenshot the app switcher (`xcrun simctl io … screenshot` after backgrounding); open tab overview | Private page not visible in the switcher snapshot (or documented as a known gap); no thumbnail for private tabs |
| B-9 | Filter lists: serve a 500 MB list, a list with 10 M rules, invalid UTF-8, a redirect to HTTP, a slow-loris response | Rejected or bounded; app stays responsive; memory stays under a documented cap |
| B-10 | Resource exhaustion pages: infinite alert loop, `history.pushState` flood, 10,000 iframes, huge `localStorage`, a 1 GB image, deep recursion | App stays alive; the tab can be closed; other tabs unaffected |
| B-11 | Isolation: a page in tab 1 and a page in tab 2 (same site, different space or private); read cookies, `localStorage`, `IndexedDB` | Private tab shares nothing with normal tabs; after the last private tab closes, its data is gone |
| B-12 | Spoofing: address-bar spoof pages (long URLs, `user@host` tricks, RTL characters, punycode), fullscreen API, popup under address bar | Displayed host is the real host; fullscreen exits cleanly |
| B-13 | Fuzz the decoders: `TabSession`, `SiteSettings`, `Space`, `TabModel` with random and truncated JSON | No crash (a failed decode is a nil) |
| B-14 | Per-site settings: JavaScript off and ads off apply on next load and survive relaunch; a site cannot change them | As described |
| B-15 | Rapid state changes: open and close 5,000 tabs, switch spaces repeatedly, split and unsplit, restore | No crash, no leak of web views (Instruments: Leaks and Allocations) |

## 5. Pass C: jailbroken physical iPhone (the owner)

Use a test device with a copy of the real data only (no real accounts). Install the **Release-like** build built with
`make device`. Install tools: Filza or SSH, `frida-server`, `objection` (on the Mac), `keychain-dumper` (or `objection
ios keychain dump`), `otool`, mitmproxy, `class-dump` or `ipsw class-dump`, Cydia Substrate or Substitute.
Bundle id: `dev.lily.browser.ios` (yours may differ in `Config/Local.xcconfig`).

### C-1. Data container inventory
1. Open Lily, browse 5 sites in 3 spaces, open one private tab, pin one tab, change two site settings, then force-quit.
2. SSH in and list the container: `find /var/mobile/Containers/Data/Application/<UUID> -type f | sort`, and the bundle container.
3. Open every file with `strings` and `plutil -p`. Search for the sites you visited: `grep -rIl "<hostname>" <container>`.

*Pass:* no file contains the visited host names, titles or full URLs in plaintext except WebKit's own caches; the session file is binary and unreadable; no `session.json` exists. WebKit's own databases under `Library/WebKit` and `Library/Caches` will contain page data for normal tabs (expected); note what is there. *Fail (High):* the private tab's host appears anywhere on disk.

### C-2. Upgrade path and legacy file
Install an older build that wrote `session.json`, browse, then install the current build over it. *Pass:* `session.json` is gone after first launch, the session restores, and the sealed file exists. If you no longer have an old build, create a plaintext `session.json` by hand in the container; *pass:* it is sealed and removed on next launch.

### C-3. Keychain
1. Dump the app's keychain items (`objection -g dev.lily.browser.ios explore`, then `ios keychain dump`).
2. Check accessibility attribute, access group, and that the item is not synchronizable.

*Pass:* only Lily's own key items; accessibility `AfterFirstUnlockThisDeviceOnly` (`ck` in dumps); not in iCloud Keychain. *Note (expected on a jailbreak):* the key itself is readable by root; the point of sealing is protecting backups and a copied file, so also run C-4.

### C-4. Backup and file protection
Make an encrypted backup (Finder), extract it (e.g. iMazing or `idevicebackup2`), and search it as in C-1. *Pass:* sealed files are unreadable without the Keychain key, the key is `ThisDeviceOnly` so it is not in the backup, and the filter lists contain nothing personal. Also check each file's data-protection class: `objection ... env`, or `xattr`/`ls -@` equivalents; *expected* `NSFileProtectionCompleteUntilFirstUserAuthentication` or better for the sealed files.

### C-5. Runtime tampering and jailbreak awareness
1. Attach Frida: `frida -U -n Lily` and hook `-[WKWebView loadRequest:]`, `SecItemCopyMatching`, and `UserDefaults`.
2. Try to change a site setting (JavaScript off) from the hook and see if the UI state and the web view disagree.
3. Try to make the app load a `file://` URL into a tab through `loadRequest:`.

*Pass:* no secret is passed in cleartext through hooked calls beyond what must be; the app does not claim any anti-tamper protection (it has none by design; document that). A privilege to attach is **not** a finding on a jailbroken device. Record what an attacker with this access can already read, for the threat-model notes.

### C-6. App switcher and screenshots
Background the app with (a) a normal tab, (b) a private tab. Open the app switcher; screenshot it (`idevicescreenshot`) or read `Library/SplashBoard/Snapshots`. *Pass:* a private tab is not shown in the snapshot (if it is, this is a **Medium**: add a privacy cover on `willResignActive` for private tabs).

### C-7. Network
1. Route the phone through mitmproxy and install its CA as trusted. Browse HTTPS sites.
2. With SSL Kill Switch 3 (or Frida) also disabling the system trust, check **Lily's own requests**: filter-list downloads and `SearchSuggestions` (if enabled).
3. Watch for traffic you did not expect: `mitmproxy` flows from a cold launch to idle for 10 minutes, with no page open.

*Pass:* with only a system-trusted CA, Lily's own list downloads work (they use the system trust, so a user-installed CA will work: expected); at idle there are **no** requests except documented ones (list updates). No analytics, no identifiers in headers, a generic User-Agent. *Fail (High):* any unexpected host contacted, or a plaintext HTTP request.

### C-8. URL schemes, Handoff, share, drag
Send Lily links from Safari, Messages, Mail and AirDrop; use the Share extension ("Lily" in the share sheet) on a page, a link, and a non-web item. The app registers one scheme, `lily://open?url=<http(s) page>`: try it with `javascript:`, `file:`, `data:`, another host (`lily://settings`), a 10 KB address and a malformed query (`LilyLinkTests` covers the logic; do it for real on the device). Drag a link between windows on iPad. *Pass:* only `http(s)` open; nothing runs automatically; a malformed link does nothing.

### C-9. Binary hardening
`otool -hv`, `otool -Iv | grep stack_chk`, `codesign -dvvv --entitlements -`, `strings -a Lily | grep -iE "http|key|token|secret|password"`.
*Pass:* PIE, stack canaries, ARC, no debugging entitlement in the Release build (`get-task-allow` is expected in local device builds only), no secrets or private keys in the binary or bundle, no non-HTTPS URLs.

### C-10. Crash and abuse resistance on device
Open the B-10 hostile pages on the device; trigger low-memory with 30 heavy tabs; rotate during load; toggle Low Power Mode. *Pass:* no crash loop; after a crash the session restores or a blank tab opens, never a stuck launch screen. Check `Settings → Privacy → Analytics & Improvements → Analytics Data` for Lily crash logs and read them for sensitive data.

## 6. Reporting and tracking

For each finding: ID, title, severity, steps, evidence (log, screenshot, flow), root cause, fix PR, and a regression test
in `Tests/` (or a LilyKit test when the cause is in the kit). Keep a table at the end of this file:

| Date | Test | Result | Finding / PR |
|---|---|---|---|
| 2026-11-21 | A-1, A-4 | Medium: no navigation policy. Links to `file:`, `data:` (as the page) and `itms-services:` were not decided anywhere, and `tel:`/`mailto:` never worked | Fixed: `NavigationPolicy` (unit-tested), calls and mail only from a tap |
| 2026-11-21 | A-4 | Low: the address bar and restored tabs accepted `file:` and `data:` addresses (the shared resolver allows them) | Fixed: tabs only load `http(s)` and `about:blank` |
| 2026-11-21 | A-2, B-7 | Medium: no camera, microphone or location usage strings, so a page asking for the camera could end the app | Fixed: strings added; the system asks per site |
| 2026-11-21 | B-4 | Medium: `window.open` from a script opened an unlimited number of tabs | Fixed: one per page load; taps are unlimited |
| 2026-11-21 | B-5 | Medium: no download handling (attachments silently failed) | Fixed: `Downloads` (own folder per file, safe names, 2 GB cap, Save to Files, purged at launch) |
| 2026-11-21 | B-6 | Medium: a failed load or a bad certificate showed a blank page, and an HTTPS-first failure had no way forward | Fixed: error page; HTTP only after asking, never for certificate errors; redirect loops broken |
| 2026-11-21 | B-8 | Medium: the app switcher snapshot and tab thumbnails could show a private page | Fixed: cover while inactive, no thumbnails for private tabs |
| 2026-11-21 | B-10 | Low: JavaScript alert/confirm/prompt were silently dropped | Fixed: system dialogs naming the site, three per page load |
| 2026-11-21 | A-5 | Low (LilyKit): filter-list size is checked after the whole body is downloaded | Fixed in LilyKit 1.1.0 ([LilyKit #13](https://github.com/Lily-browser/LilyKit/pull/13)): the download streams and stops at the 15 MB cap. The iOS app has it since its LilyKit pin moved to 1.1.0 (now 1.2.0) |
| 2026-11-21 | A-2 | Medium (regression I introduced): the library PR dropped the usage strings from `project.yml`; regenerating would have removed them | Fixed in #20, and lint now fails if any is missing |
| 2026-11-21 | A-8 | Low: Dependabot and secret scanning off on this repo | Fixed: Dependabot alerts, secret scanning and push protection on (all three repos); Dependabot config for Actions pins added |

Run live on the simulator (iPhone 17 Pro, iOS 26.5) through `xcrun simctl openurl booted "lily://open?url=…"`, which also exercises the `lily://` link:

| Date | Test | Live result |
|---|---|---|
| 2026-11-21 | B-6 expired certificate (`expired.badssl.com`) | Error page "This connection isn't private", no bypass, address bar shows a warning, not a lock |
| 2026-11-21 | B-6 HTTPS-first on a site with no HTTPS (`neverssl.com`) | Prompt "isn't available securely": Open with HTTP / Cancel. Found two bugs, fixed: a reset connection (-1005) didn't offer the prompt, and the attempt waited the system's 60 s (now 10 s) |
| 2026-11-21 | B-5 attachment download (`httpbin.org/response-headers?Content-Disposition=attachment…`) | Save to Files sheet opens with the file |
| 2026-11-21 | A-4 `lily://open?url=javascript:…` and `file:///…` | Ignored, no navigation |
| 2026-11-21 | Address bar lock | Bug: a lock showed for HTTP and for the error page. Fixed: lock only for a loaded HTTPS page |

Still to run live: B-3 (typed `data:`/`blob:`), B-4 (scripted pop-up flood, `tel:`), B-7 (camera/location prompts), B-9 to B-15, and C-1 to C-10 on the device.

## 7. Order of work

1. Pass A (a day of reading) and Pass B tests that become unit tests, as one PR per finding class.
2. The owner runs Pass C; start with C-1, C-3, C-6 and C-7 (highest value for a browser), then the rest.
3. Re-run A and B after every LilyKit bump and before each release; re-run C before the first TestFlight build.
