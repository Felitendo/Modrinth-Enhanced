# CLAUDE.md

## Style

Keep everything short — replies, explanations, comments, docs.

## Commits

- English only.
- Conventional Commits prefix: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `ci:`, `build:`.
- Subject as short as possible. Imperative, lowercase, no trailing period.
- Body only when something genuinely cannot be inferred from the diff.
- Never add `Co-Authored-By`, "Generated with" or any other AI attribution to commits or PR descriptions.
- Exception: the commits in `build/upstream` that `patches/` is exported from. Their subjects become the patch file names, so they stay plain and descriptive.

## Dev builds

Never build over an installed Modrinth Enhanced. The stable app on this machine is installed
separately, from the AUR, and stays untouched.

- `DEV=1 scripts/build.sh` builds "Modrinth Enhanced (dev)". Its bundle identifier is
  `ModrinthAppDev`, so it has a data directory of its own and shares no instances, accounts or
  settings with the stable app, and it has no updater.
- Install it beside the stable app, never over it: `~/.local/bin/Modrinth.Enhanced.dev.AppImage`
  with a desktop entry of its own.
- `FAST=1` cuts the build to about a third of the time, at the cost of a few megabytes. Use it for
  anything that is not meant to be release-like: `DEV=1 FAST=1 scripts/build.sh`.
