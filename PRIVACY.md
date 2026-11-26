# Privacy Policy

_Last updated: November 2026_

ScreenShotForMac is built to work entirely on your Mac. This policy explains what the app does
with your data, which is almost nothing beyond what you ask it to do.

## Summary

- **No telemetry.** The app does not collect analytics, usage statistics, crash reports or
  identifiers, and it does not contain third-party tracking or advertising SDKs.
- **On-device processing.** Screenshots, recordings, text recognition (OCR), barcode and QR
  detection, measurements and image effects are processed locally with Apple frameworks such as
  ScreenCaptureKit, Vision and Core Image.
- **No account.** There is nothing to sign up for, and no server operated by the project
  receives your data.
- **Uploads only where you choose.** The app makes network requests only when you set up an
  upload destination and upload something, or when you open a link yourself.

## Data the app stores on your Mac

| Data | Where | How to remove it |
|---|---|---|
| Screenshots and recordings you save | The folder you choose in Settings | Delete the files |
| Capture history (images, thumbnails, OCR text index) | The app's Application Support folder | Settings → History, or turn history off |
| Settings and preferences | macOS user defaults | Delete the app's preferences |
| Upload credentials (access keys, secret headers) | Your macOS Keychain | Settings → Upload, or Keychain Access |

History entries older than the retention period you set are deleted automatically.

## Uploads

Uploading is optional and turned off by default. When you configure a destination, such as an
S3-compatible bucket or a custom HTTP endpoint:

- Files go **directly** from your Mac to the destination you configured. They do not pass through
  any server operated by the project.
- What happens to the uploaded files is governed by the provider you chose and its privacy
  policy.
- Credentials are stored in your Keychain and sent only to the destination they belong to.

## Permissions

| Permission | Why the app uses it |
|---|---|
| **Screen Recording** | macOS requires it to read screen contents for screenshots, recordings, OCR, color picking and measuring. Screen contents are read only while you capture or use a tool. |
| **Accessibility** | Used to detect UI elements for snapping, to scroll windows during scrolling capture, and to show clicks in recordings. The app does not record keystrokes or read the text of other apps. |
| **Microphone** | Used only when you turn on microphone audio for a screen recording. |

You can revoke any permission in **System Settings → Privacy & Security** at any time. Features
that need a revoked permission stop working, and the rest of the app keeps working.

## Software updates

The app checks for updates with [Sparkle](https://sparkle-project.org) once a day (you can turn
automatic checks off when Sparkle first asks, or check manually from the menu). The check downloads
an update feed (`appcast.xml`) from GitHub Releases of this project. The request contains only
standard HTTP information such as your IP address, the app version and macOS version; no system
profile is sent. Updates are verified with an EdDSA signature before they are installed.

## Children

The app does not knowingly collect any data from anyone, including children.

## Changes

Changes to this policy are recorded in this file's Git history and noted in `CHANGELOG.md`.

## Contact

Open an issue in the project's GitHub repository for privacy questions.
