# Dev Island 0.4 — updates and publishing

## User behavior

The first 0.4 installation is manual. Official signed releases subsequently update in place through Sparkle 2.9.6. Settings → Updates and the menu bar offer manual checks; scheduled checks run hourly. Checks default on, beta off, and installation always requires a user action. A background discovery adds a menu/settings indicator without opening the island or stealing focus. Turning beta off does not downgrade an installed beta.

`dev.island.app`, existing UserDefaults preferences, SwiftData store, queue, and normalized window positions are retained. The installed bridge is refreshed through a same-directory atomic rename only when the owned integration is already installed and permitted. No Claude settings file is rewritten during refresh. Running Claude terminals are not stopped for an app update; the bounded local queue handles the application's restart gap. A VS Code connector update remains an explicit install action; this release preserves RPC compatibility.

Local ad-hoc builds, previews, demos and storage diagnostics do not start the updater. The Updates page explains this. `--disable-updates` also disables it for diagnostics. No telemetry or system profiling is added.

## One-time release setup

The source repository is `akaanuzman/DevIsland`. Public distribution uses `akaanuzman/DevIsland-releases`, without changing source visibility. Its feed will be `https://akaanuzman.github.io/DevIsland-releases/appcast.xml`.

1. Install GitHub CLI and sign in with the account authorized for these repositories: `brew install gh`, then `gh auth login`.
2. From the project root run `bash scripts/setup-release-repo.sh`. This creates the public releases repository and `gh-pages` branch, and configures Pages. It does not publish a fake appcast or an unverified package.
3. Create a `release` environment in the **source** repository. Add the secrets/variables below through GitHub Settings. Never commit the `.p12`, keys or passwords.
4. Resolve Sparkle using `bash scripts/swift.sh package resolve`. Generate the one permanent EdDSA key using `.build/artifacts/sparkle/Sparkle/bin/generate_keys`. Keep the original key safe; export its base64 private key using the tool's `-x` option into a protected temporary file for the GitHub secret, then remove the temporary export. Store the printed public key in the variable below. Test keys created by the automated suite are disposable and must never be used for distribution.
5. Export a **Developer ID Application** identity with its private key as `.p12` using Keychain Access. An Apple Development certificate is insufficient. Base64-encode the `.p12` for `APPLE_CERTIFICATE`.

| GitHub configuration | Kind | Value |
| --- | --- | --- |
| `APPLE_CERTIFICATE` | Secret | Base64 Developer ID Application `.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | Secret | `.p12` export password |
| `APPLE_ID` | Secret | Notarization Apple ID |
| `APPLE_PASSWORD` | Secret | App-specific notarization password |
| `APPLE_TEAM_ID` | Secret | Developer team ID |
| `SPARKLE_PRIVATE_KEY` | Secret | Base64 private signing key exported by Sparkle |
| `RELEASES_TOKEN` | Secret | Fine-grained token limited to the releases repository, Contents read/write; the setup login also needs Pages write |
| `DEV_ISLAND_SIGN_IDENTITY` | Variable | Exact `Developer ID Application: … (TEAMID)` identity |
| `SPARKLE_PUBLIC_KEY` | Variable | Matching base64 EdDSA public key |

No GitHub token is shipped in the app. Downloads and the feed are public HTTPS. Apple credentials and the private Sparkle key exist only in the CI temporary keychain/files and are removed on exit.

## Each release

Edit **only `Resources/version.json`** for version/build values, then run `python3 scripts/version.py --generate` and add `docs/releases/<version>.md`. Commit the generated BuildInfo and Info.plist along with the change. The display version is SemVer (`0.4.0` or `0.4.1-beta.1`); the numeric build must increase across **all** stable and beta releases. Sparkle uses that numeric build to order updates, rather than comparing SemVer labels.

Push a matching `v<version>` tag whose commit belongs to `main`. The workflow runs tests, embeds and signs nested Sparkle code, notarizes/staples the app and DMG, generates the EdDSA-signed appcast entry, and verifies preserved history, channel, build, URL, size and signature presence. The appcast is pushed only after the verified public release assets exist. An error leaves the previous feed in place. Existing GitHub releases are not overwritten by a rerun; inspect and recover a partial publication before retrying, or publish a new version/build.

Stable tags are GitHub Latest releases. Beta tags are prereleases with the Sparkle `beta` channel; everyone can receive stable, only opted-in users receive beta. The feed retains old entries. Installation from a read-only DMG is not supported; copy the app to Applications first.

## End-to-end acceptance

Before calling remote updates complete, publish two signed beta builds with increasing numeric builds, install the first into Applications, opt into beta, update to the second, and verify preferences, sessions, bridge events, terminal routing and relaunch. Also check a newer stable build with beta disabled. Local signature/fixture tests are not an end-to-end update installation.
