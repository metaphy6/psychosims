# Desktop OAuth — PKCE / state / nonce binding note

Phase 3.1 adds PKCE plus HMAC-signed `state` and a per-request `nonce` for the
Google/Apple desktop deep-link OAuth flow. The server-side state/nonce store and
PKCE verification live in `server/internal/identity`.

Client responsibilities (existing convention; no new Flutter dependency added in
this phase):

- Generate the PKCE code verifier in platform secure storage (Keychain /
  Keystore / OS credential store) and derive the code challenge with SHA-256.
- Launch the system browser with the authorization URL containing `state`,
  `nonce`, and `code_challenge`.
- Handle the deep-link callback, verify the returned `state`, and exchange the
  authorization code using the stored code verifier.
- Cache access/refresh tokens in platform secure storage, never plaintext on
  disk.

Desktop distribution channels:

| Channel | Redirect URI key | Notes |
|---|---|---|
| Steam (Windows/macOS) | `steam` | Distribution only; identity still uses Google/Apple OAuth. |
| Signed direct download (Linux) | `direct_download` | Same OAuth providers; channel selected at build/pack time. |

The redirect URIs are configured server-side via `identity.OAuthConfig`
(`DesktopRedirectURIs`).
