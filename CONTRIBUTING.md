# Contributing to ScreenShotForMac

Thanks for your interest in improving ScreenShotForMac. This guide explains how to set up the
project and what a pull request needs before it can be merged.

## Getting started

1. Fork the repository and clone your fork.
2. Follow [Build from source](README.md#build-from-source) in the README.
3. Install the tools CI uses:

   ```sh
   brew install xcodegen swiftformat swiftlint
   ```

Never commit `Config/Local.xcconfig`, signing identities, certificates, API keys or upload
credentials. The repository ignores `Local.xcconfig` for this reason.

## Branches

- `main` is always releasable. Do not push to it directly.
- Create a topic branch from `main`, prefixed by the type of change:
  `feat/scrolling-horizontal`, `fix/editor-undo-crash`, `docs/readme-cli`.
- Keep branches short-lived and rebase on `main` before you ask for review.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/) in English:

```text
feat(editor): add curved arrow style
fix(capture): keep selection inside the active display
docs: document the ssfm URL scheme
chore(ci): cache SwiftPM dependencies
```

Allowed types: `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `chore`, `ci`. The scope is
the module name without the `Shot` prefix (`editor`, `capture`, `recording`, …) or `app`.
Keep each commit small and focused on one change.

## Code style

- **Swift 6** with strict concurrency (`swiftLanguageModes: [.v6]`). Do not silence concurrency
  diagnostics with `@unchecked Sendable` or `nonisolated(unsafe)` unless you explain why in a
  comment.
- UI code is `@MainActor`. Long work (encoding, OCR, stitching) runs off the main actor.
- Format with **SwiftFormat** and lint with **SwiftLint**. The configuration is in
  `.swiftformat` and `.swiftlint.yml`:

  ```sh
  swiftformat .
  swiftlint lint
  ```

- 4-space indentation, lines up to 140 characters.
- Keep files under 400 lines and functions under 50 lines. Split large types with extensions in
  separate files (`EditorViewModel+Canvas.swift`), as the existing code does.
- Prefer value types and immutable data. Handle errors explicitly. Never swallow an error
  silently; log it with the module's `Log` category.
- Do not log personal data such as file paths, OCR text, URLs or credentials.

## Module boundaries

The `ShotKit` package is split into feature modules (see the
[architecture table](README.md#architecture)):

- Feature modules depend only on `ShotCore`. They never import each other.
- Cross-module communication goes through protocols and models in `ShotCore`. The app target
  (`App/`) wires the concrete implementations together.
- New third-party dependencies need discussion in an issue first. Their licenses must be
  compatible with MIT. Do not copy code or assets from GPL-licensed projects.
- Change `project.yml`, never the generated `.xcodeproj`.

## Localization

Every user-visible string must be localized, and every new string must have a **Turkish**
translation in the same pull request.

- In code, use `String(localized: "…", bundle: .module)` in package modules, or
  `Text("…", bundle: .module)` in SwiftUI. In the app target, use the main bundle.
- Add the key and its English and Turkish values to the module's
  `Resources/Localizable.xcstrings`. Building in Xcode extracts new keys automatically.
- Do not build sentences by concatenating strings. Use interpolation so translators can reorder
  words.
- Log messages, error identifiers and code comments stay in English and are not localized.

## Tests

Add or update unit tests for logic such as geometry, encoding, file name templates, stitching
and upload signing. Run `swift test` before opening a pull request. If you could not test a
change, say so in the pull request description.

## Pull requests

- Fill in the pull request template.
- Add screenshots or a short recording for UI changes, in both light and dark appearance.
- CI must pass: build, tests, SwiftFormat lint, SwiftLint and the app build.
- Update `CHANGELOG.md` under **Unreleased** for changes users will notice.

## Reporting bugs and requesting features

Use the issue templates. For security issues, do not open a public issue. Use GitHub's private
vulnerability reporting for this repository instead.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
