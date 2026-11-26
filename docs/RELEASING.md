# Releasing

This guide is for maintainers who publish signed, notarized builds. Contributors do not need it.

Releases are distributed outside the Mac App Store as a Developer ID–signed, notarized DMG. The
app is not sandboxed because it needs Accessibility, event taps and scrolling automation.

## One-time setup

1. **Apple Developer Program membership** and a **Developer ID Application** certificate installed
   in your login keychain. Check it with:

   ```sh
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```

2. **Notary credentials** stored in the keychain as a notarytool profile. Use an App Store
   Connect API key (preferred) or an app-specific password. The profile name is up to you:

   ```sh
   # With an App Store Connect API key
   xcrun notarytool store-credentials "ssfm-notary" \
     --key /path/to/AuthKey_XXXXXXXXXX.p8 --key-id XXXXXXXXXX --issuer <issuer-uuid>

   # Or with an Apple ID and app-specific password (you will be prompted)
   xcrun notarytool store-credentials "ssfm-notary" --apple-id <apple-id> --team-id <team-id>
   ```

   Credentials stay in the keychain. Never commit them, and never put them in scripts or config
   files in this repository.

3. **Tools:** Xcode (latest stable) and `brew install xcodegen`.

4. **Environment variables** for your shell session, for example from a password manager or a
   file outside the repository:

   | Variable | Example | Purpose |
   |---|---|---|
   | `DEVELOPER_ID_APPLICATION` | `Developer ID Application: Example Inc (ABCDE12345)` | Signing identity for the app and the DMG |
   | `DEVELOPMENT_TEAM` | `ABCDE12345` | Team ID used for archiving and export |
   | `NOTARY_PROFILE` | `ssfm-notary` | notarytool keychain profile from step 2 |

## Release checklist

1. **Start from a clean, up-to-date `main`.** CI must be green.
2. **Bump the version** in `project.yml`:

   ```sh
   scripts/bump-version.sh --patch        # or --minor, --major, or an explicit 1.0.0
   scripts/bump-version.sh --build        # build number only
   scripts/bump-version.sh --dry-run 1.0.0
   ```

   The build number (`CFBundleVersion`) must increase with every release, because Sparkle and
   macOS compare it.
3. **Update `CHANGELOG.md`:** move the **Unreleased** entries under a new `## [x.y.z] - YYYY-MM-DD`
   heading and add the compare link at the bottom.
4. **Commit:** `chore(release): x.y.z`.
5. **Preview the release steps:**

   ```sh
   scripts/release.sh --dry-run
   ```

6. **Build, sign, notarize and staple:**

   ```sh
   scripts/release.sh
   ```

   The script:
   1. runs `xcodegen generate`,
   2. archives the `ScreenShotForMac` scheme in the Release configuration with the hardened
      runtime and a secure timestamp,
   3. exports the app with the `developer-id` method and verifies its signature,
   4. builds a compressed DMG (`hdiutil`) with an `Applications` shortcut and signs it,
   5. submits the DMG with `xcrun notarytool submit --keychain-profile "$NOTARY_PROFILE" --wait`,
   6. staples and validates the ticket and runs a Gatekeeper assessment,
   7. writes `ScreenShotForMac-x.y.z.dmg.sha256` and prints the next steps.

   Output goes to `build/release/` (change it with `--output`). Keep `build/` out of Git.
   Use `--skip-notarize` for a local test build.

7. **Smoke test** the DMG on a second Mac or a new user account: open it, drag the app to
   Applications, launch it, grant permissions, and try each capture mode.
8. **Tag and publish:**

   ```sh
   git tag -a vx.y.z -m "vx.y.z"
   git push origin main vx.y.z
   ```

   Create a GitHub release for the tag, paste the changelog section, and attach the DMG and its
   `.sha256` file.

## If notarization fails

```sh
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE"
xcrun notarytool log <submission-id> --keychain-profile "$NOTARY_PROFILE"
```

Common causes: a nested binary without the hardened runtime, a missing secure timestamp, or a
binary signed with a development certificate. Fix the problem, bump the build number, and run
the script again.

## Auto-updates (Sparkle 2 + GitHub Releases)

Auto-update is implemented with [Sparkle 2](https://sparkle-project.org). The app reads
`SUFeedURL = https://github.com/atak946/ScreenShotForMac/releases/latest/download/appcast.xml`
and verifies every update with the EdDSA public key `SUPublicEDKey` (both in `project.yml`).

- The **private** EdDSA key lives in the release machine's login Keychain (account `ScreenShotForMac`,
  created with Sparkle's `generate_keys --account ScreenShotForMac`). **Back it up**:
  `generate_keys --account ScreenShotForMac -x sparkle_private_key.txt` and store the file in a
  password manager. Losing it means existing installs can no longer verify updates.
- Publishing a release:
  1. `scripts/bump-version.sh --minor` (or `--patch`), update `CHANGELOG.md`, commit.
  2. `scripts/release.sh` → notarized `build/release/ScreenShotForMac-<version>.dmg`.
  3. `scripts/publish-release.sh` → signs the DMG, generates `appcast.xml`, tags `v<version>`,
     and creates the GitHub Release with both assets.
- The appcast lists only the latest version (each release hosts only its own DMG).
