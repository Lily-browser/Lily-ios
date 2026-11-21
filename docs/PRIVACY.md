# Privacy in Lily for iOS

**In short:** Lily has no account, no analytics, no telemetry and no crash reporting of its own, and shares nothing with
third parties. What it stores stays on your device; what it sends is what browsing needs (the pages you open) plus the
ad-blocking filter lists it downloads.

## What stays on your device

In the app's own storage. "Sealed" means AES-GCM encrypted with a key in the Keychain (`AfterFirstUnlockThisDeviceOnly`,
so the key never leaves this device and is not in iCloud Keychain).

| What | Sealed | Kept for | Removed by |
|---|---|---|---|
| Open tabs, pinned tabs, spaces (the session) | yes | the saved session always matches your open tabs | closing the tabs (Clear Browsing Data leaves your tabs alone); "Restore tabs on launch" off stops restoring them at launch |
| History: addresses, titles, times | yes | 90 days by default, at most 20,000 visits | Settings → Clear Browsing Data; Library → History → Clear History; swiping a row |
| Bookmarks | yes | until removed | swiping a bookmark; deleting the app |
| Per-site choices (zoom, dark mode, JavaScript, ads) | yes | until you change them | Website Settings; deleting the app |
| Page thumbnails in the tab overview | no (memory only, never written to disk) | until the tab closes or Clear Browsing Data | closing tabs; quitting the app |
| Downloads | no (a temporary folder) | until the next launch | Save to Files, then they are yours; the temporary copy is deleted at the next launch |
| Cookies, caches, site storage | by iOS | per site | Settings → Clear Browsing Data |

"Keep browsing history" in Settings turns history off.

## Private tabs

A private tab uses a separate, non-persistent web data store: no cookies, cache or site storage survive it. Its pages are never
added to history, its picture is never kept as a thumbnail, and the app hides it with a cover in the app switcher. When the last
private tab closes, its data is dropped. A bookmark you add yourself is kept, because it's your choice.

## What leaves your device

- **The pages you open**, to those sites and your network, as in any browser. HTTPS is tried first.
- **Search**: what you type as a search goes to your chosen search engine when you submit it. Lily does not send suggestions as you type.
- **Filter lists**: ad-blocking lists are downloaded from their publishers (EasyList and others, shown in Settings). Those servers see
  your IP address when the lists update, and nothing about your browsing.
- **Link tracking parameters** (`utm_*` and similar) are removed from links before they load, when "Remove tracking from links" is on.

## Permissions

Camera, microphone and location are asked per site by iOS, and only when a page requests them. Lily doesn't read your contacts,
photos or other apps' data. The Share extension ("Lily" in the share sheet) reads only the address of the page you share.

## Your control

Everything above can be removed from the app (Settings → Clear Browsing Data, the Library sheet, swiping rows) or by deleting
the app, which also removes its Keychain key.

Questions or concerns: open an issue, or for anything security-related see [SECURITY.md](../SECURITY.md).
