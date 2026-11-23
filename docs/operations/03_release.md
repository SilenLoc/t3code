# Release Runbook

Unified release workflow: `.github/workflows/release.yml`. Beta is a product label, not a release channel—channels remain `stable` and `nightly` (plus `preview` for maintainer test builds).

## Channels and triggers

This fork publishes GitHub Releases only. Pushing a `vX.Y.Z` tag builds that commit and publishes a public release. Manual dispatch of `release.yml` also accepts:

- **`nightly`:** a GitHub prerelease, plus the `update-feed` pointer that nightly installs read.
- **`preview`:** a draft release for testing the pipeline. Never publish a preview draft or push a test tag, since the update feed reads release tags.

Scheduled nightlies are off. Desktop builds are Linux only (AppImage, `.deb`, and the CLI archive, for x64 and arm64).

## Critical release invariants

- **Server self-update:** Connected servers update to the exact client version by downloading the GitHub Release CLI archive (or `npx t3@<version>`). The `release` job attaches the archives and `SHA256SUMS`, so nothing else should publish before it.
- **Standalone CLI archives & Node pin:** `engines.node` in root `package.json` must stay exact (Node SEA builds reject mismatches).
- **Smoke fixture:** `scripts/fixtures/desktop-launch` is intentionally an old SQLite snapshot to verify forward migrations on packaged builds—never regenerate it on schema changes.

## Update feed

Nightly installs check `releases.atom` (the 10 newest git tags), then the `update-feed` release's `nightly.json` pointer, then the GitHub API as fallback. **Never delete the `update-feed` release.**

- If `Check the update feed` fails because stray/preview tags pushed the newest nightly out of `releases.atom`, delete the unneeded tags (`git push origin :refs/tags/<tag>`—converting a release to draft keeps its tag).
- **To pull a bad nightly:** delete its release and tag, run `gh release delete-asset update-feed nightly.json` (so installs fall back until the next nightly rewrites it).

## T3 Connect relay deployment

Relay deployment is not part of CI. Release builds use the public Clerk and relay identifiers in `.env.example`, the same ones preview builds use, so no Cloudflare credentials are needed.

### Managed tunnel cleanup rollout

`RELAY_TUNNEL_CLEANUP_MODE` and `RELAY_LEGACY_TUNNEL_CLEANUP_MODE` accept `off` (default), `dry-run`, or `enabled` and take effect on the next relay deploy (without `force`). Monitor `relay.managed_endpoint_reaper.sweep` spans in Axiom. To stop cleanup during an incident, set the mode to `off` and redeploy the relay.


## Windows payload topology and update validation

Windows packages the bundled server and its unpacked native modules in `resources/server.asar` (+ `server.asar.unpacked`) and embeds the matching-architecture Linux CLI archive as `resources/wsl-runtime.tar.gz` + SHA-256 sidecar (passed via `--wsl-runtime`). Avoid whole-package smart unpacking (keeps unpacked file counts and NSIS differential blockmaps bounded). `scripts/build-desktop-artifact.ts` enforces all structural, native-load, and WSL archive checks at build time.

## One-time credentials setup

### Apple signing and notarization (macOS)

- **Secrets:** `CSC_LINK` (base64 `.p12`), `CSC_KEY_PASSWORD`, `APPLE_API_KEY` (raw `.p8`), `APPLE_API_KEY_ID`, `APPLE_API_ISSUER`, `MACOS_PROVISIONING_PROFILE` (base64 profile for `com.t3tools.t3code` with Associated Domains).
- **Variables:** `APPLE_TEAM_ID`, optional `CLERK_PASSKEY_RP_DOMAINS`.
- The packager only enables passkey entitlements (`keychain-access-groups`, `com.apple.developer.web-browser.public-key-credential`) present in the provisioning profile; regenerate and re-upload `MACOS_PROVISIONING_PROFILE` after Apple approves managed capabilities. Complete Clerk AASA setup per [Connect setup](./02_connect-setup.md#desktop-passkeys).

## Ongoing stable release checklist

1. Push the `vX.Y.Z` tag on the commit you want to ship.
2. Confirm the `release` job succeeds and the GitHub Release lists the AppImage, `.deb`, CLI archives, and `SHA256SUMS`.
3. Install the AppImage or `.deb` from the release and smoke-test it.

