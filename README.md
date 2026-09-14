# Modrinth Enhanced

The [Modrinth App](https://github.com/modrinth/code), without advertising, without telemetry, and
with offline accounts.

Everything else is deliberately left alone. This repository holds no forked source code — only a
series of patches that are applied to an upstream release tag, built, and published. Whenever
Modrinth ships a new version, the patches are reapplied on top of it, the result is built and
checked on Linux, Windows and macOS, and a release is published automatically if it all still
works.

## What changes

| Patch                                     | What it does                                                                                                                                    |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `0001-Rename-the-app-to-Modrinth-Enhanced` | Product name, binary name, window title, version label, and an "Enhanced" pill next to the wordmark.                                             |
| `0002-Use-the-Modrinth-Enhanced-icon`      | The Modrinth mark with a sparkle badge, rendered into every icon the bundles need. The vector source ships alongside them.                       |
| `0003-Remove-advertising`                  | The sidebar ad slot, the "Upgrade to Modrinth+" nag and the ad cookie consent prompt. The ad webview is never created.                           |
| `0004-Remove-telemetry`                    | PostHog analytics, Sentry crash reporting, the Tally survey embed, and the playtime and server-play reports the launcher sends to Modrinth.       |
| `0005-Add-offline-accounts`                | A second way to add a Minecraft account that never contacts Microsoft or Mojang.                                                                  |

### Offline accounts

"Add offline account" sits next to "Sign in to Minecraft" in the account card. It asks for a
username and nothing else.

The player UUID is derived exactly the way Minecraft itself derives it — an MD5 name UUID over
`OfflinePlayer:<name>` — so worlds keep the same player data when they are opened from another
launcher. Offline accounts can play singleplayer and join servers running in offline mode. Servers
in online mode reject them, as they do in every other launcher.

Microsoft sign-in is untouched and still the default.

### What is *not* removed

Download attribution still happens. It is a header on downloads you already asked for, and it is
what credits project authors for them. Removing it would take money out of creators' pockets
without making anyone more private.

`posthog-js` and `@sentry/vue` remain listed in `package.json`. Nothing imports them any more, so
neither ends up in a build; removing the entries would mean carrying a patch against the lockfile
for no practical gain.

## Relationship to the official app

Modrinth Enhanced keeps the upstream bundle identifier, which means it uses **the same data
directory as the official Modrinth App**. Instances, settings and accounts carry over in both
directions, and it can be installed as a drop-in replacement.

The flip side: do not run both at once, and on Windows the two installers share an uninstall entry.
If you would rather have them fully separated, change `identifier` in
`apps/app/tauri.conf.json` — it is one line in `0001-Rename-the-app-to-Modrinth-Enhanced.patch`.

## Building it yourself

You need git, Node (the version in the upstream `.nvmrc`), pnpm via Corepack, a Rust toolchain,
JDK 17, and on Linux `libwebkit2gtk-4.1-dev`, `libayatana-appindicator3-dev` and `librsvg2-dev`.

```bash
scripts/prepare.sh   # check out the pinned upstream tag and apply every patch
scripts/check.sh     # assert the patches still do what they claim
scripts/build.sh     # build installers into build/artifacts
```

`build/` is scratch space and is never committed.

## Working on the patches

The patched checkout is an ordinary git repository with one commit per patch, so patches are
maintained as commits rather than as diffs by hand:

```bash
scripts/prepare.sh                  # build/upstream, branch `enhanced`
cd build/upstream
# ...edit, then either commit a new change or amend an existing one
cd ../..
scripts/export-patches.sh           # rewrite patches/ from those commits
```

The icons are the one thing that is generated rather than written. Edit
`build/upstream/apps/app/icons/modrinth-enhanced.svg`, run `scripts/render-icons.py`, and every PNG,
`.ico` and `.icns` next to it is rewritten from that source; rendering the unchanged source again
reproduces the current files byte for byte.

Patches are applied with `git am --3way`, so small upstream movements around a hunk resolve by
themselves. When one genuinely conflicts, `scripts/prepare.sh` stops and leaves the conflict staged
in `build/upstream` to be resolved with `git am --continue`, after which `scripts/export-patches.sh`
writes the fixed series back.

To move to a newer upstream release:

```bash
scripts/latest-upstream.sh --write  # update upstream.txt
scripts/prepare.sh
```

## Automation

- **Build** (`.github/workflows/build.yml`) runs on every push and pull request, and is also the
  reusable workflow the release job calls. It applies the patches, checks them, and builds on
  Linux, Windows and macOS.
- **Upstream release** (`.github/workflows/upstream-release.yml`) runs daily. If Modrinth has
  published a newer release than `upstream.txt`, it rebuilds against it and — only if every
  platform built and every check passed — commits the bump, tags it with the upstream version and
  publishes a release with the installers.

`scripts/check.sh` is what makes the automation trustworthy. A patch can apply cleanly and still
stop doing its job if upstream moves the thing it was holding down, so the checks assert the
outcome instead of the diff: the app is named correctly, offline accounts are wired up end to end,
no telemetry endpoint survives into the built frontend, and the installers are named after this
fork.

## Licence

The Modrinth App is GPL-3.0, and so is everything here. Modrinth Enhanced is not affiliated with or
endorsed by Rinth, Inc.
