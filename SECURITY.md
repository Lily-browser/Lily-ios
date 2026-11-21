# Security policy

## Reporting a vulnerability

Please **don't open a public issue** for security problems. Report them privately through GitHub:
**[Security → Report a vulnerability](https://github.com/Lily-browser/Lily-ios/security/advisories/new)**.

Include what you found, how to reproduce it (a minimal page or steps), the Lily version and your iOS or iPadOS version.
Lily is maintained by one person, so replies are best effort; you'll get an acknowledgement, and a credit in the advisory if you want one.

## Supported versions

Only the latest release and `main` get security fixes.

## Scope

In scope, Lily's own code and configuration, for example:
- navigation and download handling (`Sources/Browser/`), the `lily://` link and the Share extension (`Share/`, `Shared/`)
- data at rest (sealed files, Keychain keys) and private tabs leaking data (history, thumbnails, the app-switcher picture)
- the build and release pipeline (`scripts/`, `.github/`)

Out of scope: bugs in WebKit or iOS itself (report them to [Apple](https://security.apple.com)), and attacks that need an
already-compromised device or account. How the app is tested: [docs/SECURITY-TEST-PLAN.md](docs/SECURITY-TEST-PLAN.md).
