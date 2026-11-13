# Security

## Reporting a vulnerability

Please report privately through GitHub: **Security > Report a vulnerability** on this repository.
Do not open a public issue for security problems. You will get a reply as soon as possible.

## What EmberBar does with your account

- Sign-in uses OAuth with PKCE in your own browser. EmberBar never sees your password.
- The access and refresh tokens are stored only on your device:
  - Windows: encrypted with DPAPI for your user.
  - macOS: in the Keychain, device-only (`ThisDeviceOnly`), not synced.
- Tokens are sent only to `api.anthropic.com` and `platform.claude.com`, over HTTPS.
- The macOS update check contacts `api.github.com` (public releases list). It sends no account data, token or identifier, and it never downloads or runs anything: it only shows a link to the release page, which you open yourself.
- Preferences (language, interval, open at login) stay in the app's local sandbox container.
- No telemetry, no analytics, no third-party servers, no third-party packages.

## macOS hardening

- **App Sandbox**: the app cannot read or write files outside its own container. It is allowed only
  outgoing network connections and one loopback listener used during sign-in.
- **Hardened runtime**: blocks code injection and unsigned library loading.
- **Sign-in listener** (`mac/Sources/EmberBarCore/CallbackRequest.swift`): bound to loopback only, accepts
  only `GET /callback` for its own `localhost:<port>`, checks the `state` value in constant time, ignores
  invalid requests instead of aborting, times out after 5 minutes, and never reflects request data.
- **Network client**: ephemeral session (no cache, cookies or credentials on disk), redirects are not
  followed, only the two hosts above are allowed, and responses are size-limited.
- **Input**: the usage response is validated and range-checked before it is drawn.
- **Repository hygiene**: a CI check fails any push that contains credentials, personal e-mails or local paths, or commits not authored with a GitHub `noreply` address.
- **Build**: GitHub Actions runs with read-only permissions and no secrets. Actions are pinned to commit
  SHAs and kept up to date by Dependabot. The release `.zip` ships with a SHA-256 checksum.

## Known limitations

- The macOS app is signed ad-hoc and not notarized (this keeps the project free). macOS Gatekeeper will
  warn on first launch. Verify the SHA-256 on the release page, or build it yourself from source.
- The sign-in uses the OAuth client and the usage endpoint that Claude Code uses. Both are undocumented
  and may change without notice.
- Anyone with access to your unlocked user session can use the stored tokens, as with any app.
  Use **Sign out** in the menu to delete them.
