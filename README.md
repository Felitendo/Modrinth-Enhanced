# Modrinth Enhanced

The [Modrinth App](https://github.com/modrinth/code), without advertising, without telemetry, and
with offline and Ely.by accounts.

Everything else is deliberately left alone. This repository holds no forked source code — only a
series of patches that are applied to an upstream release tag, built, and published. Whenever
Modrinth ships a new version, the patches are reapplied on top of it, the result is built and
checked on Linux, Windows and macOS, and a release is published automatically if it all still
works.

## What changes

| Patch                                     | What it does                                                                                                                                    |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `0001-Rename-the-app-to-Modrinth-Enhanced` | Product name, binary name, window title and version label.                                                                                |
| `0002-Remove-advertising-and-...`          | The sidebar ad slot, both "Upgrade to Modrinth+" prompts and the ad cookie consent prompt. The ad webview is never created.                 |
| `0003-Remove-telemetry`                    | PostHog analytics, Sentry crash reporting, the Tally survey embeds, and the playtime and server-play reports the launcher sends to Modrinth. |
| `0004-Add-offline-accounts`                | A way to add a Minecraft account that never contacts Microsoft or Mojang.                                                                   |
| `0005-Make-the-sidebars-foldable`          | A switch for the Modrinth Servers button, a news section that folds away, and a title bar button that folds the right sidebar away.         |
| `0006-Add-Ely.by-accounts`                 | Sign in with Ely.by, launched through authlib-injector.                                                                                    |
| `0007-Sign-in-to-Microsoft-in-the-...`     | Microsoft sign-in happens in your own browser instead of a webview, so your password manager works.                                        |
| `0008-Round-the-window-corners-on-Linux`   | The undecorated window gets rounded corners on Linux.                                                                                       |
| `0009-Scroll-with-the-middle-mouse-button` | Middle-click autoscroll on Linux and macOS, as browsers do it on Windows.                                                                   |

### Offline accounts

"Add offline account" sits next to "Sign in to Minecraft" in the account card. It asks for a
username and nothing else.

The player UUID is derived exactly the way Minecraft itself derives it — an MD5 name UUID over
`OfflinePlayer:<name>` — so worlds keep the same player data when they are opened from another
launcher. Offline accounts can play singleplayer and join servers running in offline mode. Servers
in online mode reject them, as they do in every other launcher.

Both sit next to "Sign in to Microsoft" everywhere an account can be added: the account card, the
modal you get when pressing Play with no account, and "Sign in to Minecraft" in the getting started
checklist. Upstream offered Microsoft and nothing else at all three.

### Microsoft sign-in

Microsoft sign-in opens your own browser rather than a webview inside the launcher, so your
password manager, autofill and passkeys work, and you can see in the address bar that the page is
really Microsoft's.

Microsoft cannot hand the result back: the client id the launcher uses is Minecraft's own, whose
only registered redirect is a fixed page on `login.live.com`, with no loopback address for the
launcher to listen on. So the browser lands on that page with the code in the address and you copy
the address into the launcher. The webview is still one click away for anyone the browser does not
work out for.

### Ely.by accounts

"Add Ely.by account" sits in the same account card. It asks for an Ely.by account name or email and
a password, which go to `authserver.ely.by` and nowhere else. With two-factor authentication on,
append the current code to the password after a colon, which is Ely.by's own convention.

At launch the game is pointed at Ely.by with
[authlib-injector](https://github.com/yushijinhun/authlib-injector), downloaded once and cached, so
such an account can play singleplayer and join any server that accepts Ely.by.

The account is stored in the same table as every other one, marked by the client token Ely.by
issues; the token pair is checked and renewed against Ely.by a few times a day rather than on every
read of the account list.

Signing in on Ely.by's own page instead of in this form would be better, and needs an OAuth
application registered with Ely.by — one has not been registered for Modrinth Enhanced.

### Sidebar and news

The Modrinth Servers button in the left sidebar can be switched off under
Settings > Features > Sidebar.

The news section in the right sidebar folds away by clicking its heading. The right sidebar itself
folds away with the arrow button in the title bar, which upstream only shows once "Hide right
sidebar" is turned on in settings. Both remember what they were set to across restarts.

None of the three reach Modrinth. Preference syncing maps a fixed list of named fields in both
directions and these are not in it, so they are neither sent to your Modrinth account nor
overwritten by another device.

### Window

On Linux the window has rounded corners while it floats. Maximized, fullscreen or with native
decorations turned on, it is square as before. The window is created transparent for this, which
needs a compositor; without one the corners show black.

A click with the middle mouse button on anything that scrolls starts autoscroll: press and release
to scroll until the next click, or hold and drag to scroll until you let go. Links and text fields
keep their middle-click. Windows is left alone, since WebView2 autoscrolls by itself.

### Modrinth+

Nothing in the app is gated behind Modrinth+. In upstream it decides whether the ad slot, the
consent prompt and the two "Upgrade to Modrinth+" prompts are shown, and nothing else — so removing
the advertising is the whole of it, and there is nothing further to unlock from here. Badges and
everything else a subscription buys are decided on Modrinth's servers.

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
- **Revisions** of the same upstream release are published by running Upstream release by hand
  with `revision` ticked. It builds the upstream release in `upstream.txt` again with the current
  patches and publishes it as `v0.21.2-2`, `v0.21.2-3` and so on. The app and installers still
  carry the upstream version: RPM and the Windows installers do not accept a suffix in it.

`scripts/check.sh` is what makes the automation trustworthy. A patch can apply cleanly and still
stop doing its job if upstream moves the thing it was holding down, so the checks assert the
outcome instead of the diff: the app is named correctly, offline accounts are wired up end to end,
no telemetry endpoint survives into the built frontend, and the installers are named after this
fork.

## Licence

The Modrinth App is GPL-3.0, and so is everything here. Modrinth Enhanced is not affiliated with or
endorsed by Rinth, Inc.
