## Summary

<!-- What does this change and why? Link related issues: "Closes #123". -->

## Type

- [ ] `feat` new feature
- [ ] `fix` bug fix
- [ ] `refactor` / `perf`
- [ ] `docs` / `chore` / `ci`

## Screenshots / recording

<!-- Required for UI changes. Show light and dark appearance. -->

## Checklist

- [ ] Commit messages follow Conventional Commits
- [ ] `swift build` and `swift test` pass locally
- [ ] `swiftformat --lint .` and `swiftlint lint` report no new issues
- [ ] Feature modules depend only on `ShotCore`; no cross-module imports
- [ ] Every new user-visible string is localized, with a Turkish translation
- [ ] No secrets, team IDs or personal data in code, logs or config
- [ ] `CHANGELOG.md` updated under **Unreleased** (if users will notice)
- [ ] `project.yml` changed instead of the generated `.xcodeproj` (if applicable)

## Testing

<!-- How did you verify this? Mention macOS version and display setup. Say what is untested. -->
