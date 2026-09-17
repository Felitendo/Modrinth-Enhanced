# Modrinth Enhanced

The [Modrinth App](https://github.com/modrinth/code), without advertising, without telemetry, and
with offline, Ely.by and custom server accounts, a skins browser and tons of fixes for Linux.

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
| `0010-Manage-Ely.by-skins-from-...`        | An Ely.by account's skins can be picked, uploaded, switched between models and deleted on the skin page.                                   |
| `0011-Show-every-player-s-skin-...`        | Players who have a skin show it on offline-mode servers, and skins can be put in a folder by hand.                                          |
| `0012-Launch-a-running-instance-...`       | A running instance can be started again on another account, with a console per copy.                                                       |
| `0013-Explain-what-went-wrong-...`         | The Logs tab says what a crash was and offers a fix where there is one, without a connection.                                               |
| `0014-Browse-skins-from-...`               | A Browse tab on the skin page: Ely.by's catalogue in the app, and NameMC, laby.net and crafty.gg in a window.                               |
| `0015-Use-the-desktop-s-file-picker-...`   | File pickers on Linux are the desktop's own, such as KDE's, through the XDG desktop portal.                                                 |
| `0016-Show-the-account-in-the-title-bar-...` | With the right sidebar folded away, the Minecraft account is shown in the title bar and managed from there.                         |
| `0017-Start-on-Wayland-with-an-NVIDIA-GPU` | The app no longer crashes at start under Wayland with the NVIDIA driver.                                                                    |
| `0018-Update-from-Modrinth-Enhanced-s-...` | Updates come from this project's own signed releases rather than Modrinth's.                                                                |
| `0019-Add-accounts-from-other-...`         | Sign in to Drasl, Blessing Skin and other account servers, as with Ely.by.                                                                  |

### Offline accounts

"Offline" under "Add account" in the account card asks for a username and nothing else.

The player UUID is derived exactly the way Minecraft itself derives it — an MD5 name UUID over
`OfflinePlayer:<name>` — so worlds keep the same player data when they are opened from another
launcher. Offline accounts can play singleplayer and join servers running in offline mode. Servers
in online mode reject them, as they do in every other launcher.

Offline, Ely.by and custom server accounts sit next to Microsoft everywhere an account can be
added: the account card, the title bar menu, the modal you get when pressing Play with no account,
and "Sign in to Minecraft" in the getting started checklist. Upstream offered Microsoft and nothing
else.

### Microsoft sign-in

Microsoft sign-in opens your own browser rather than a webview inside the launcher, so your
password manager, autofill and passkeys work, and you can see in the address bar that the page is
really Microsoft's.

The client id the launcher uses is Minecraft's own, with no redirect the launcher could listen on.
So the browser signs in on Microsoft's device code page, with the code already filled in, while the
launcher asks Microsoft every few seconds whether that has happened. Once it has, the account is
added and the launcher comes back to the front, without anything to paste. The window inside the
launcher is still one click away in the dialog, for when the browser does not work out.

### Ely.by accounts

"Ely.by" asks for an Ely.by account name or email and a password. With two-factor authentication on, append the current code to the password after a
colon, which is Ely.by's own convention.

At launch the game is pointed at Ely.by with
[authlib-injector](https://github.com/yushijinhun/authlib-injector), downloaded once and cached, so
such an account can play singleplayer and join any server that accepts Ely.by.

The account is stored in the same table as every other one, marked by the client token Ely.by
issues; the token pair is checked and renewed against Ely.by a few times a day rather than on every
read of the account list.

Signing in on Ely.by's own page instead of in this form would be better, and needs an OAuth
application registered with Ely.by — one has not been registered for Modrinth Enhanced.

### Custom server accounts

"Custom server" does the same for any other server authlib-injector works with, such as
[Drasl](https://github.com/unmojang/drasl), Blessing Skin or LittleSkin. It asks for the server as
well: its website is enough, since the server names its API in the `X-Authlib-Injector-API-Location`
header. The dialog then shows the server's name and a link to sign up there. An account with several
players asks which one to play as.

On Drasl, a player who signed up through another service uses the Minecraft token from their
account page as the password; the dialog says so.

The account list shows which server an account is on.

### Sidebar and news

The Modrinth Servers button in the left sidebar can be switched off under
Settings > Features > Sidebar.

The news section in the right sidebar folds away by clicking its heading. The right sidebar itself
folds away with the arrow button in the title bar, which upstream only shows once "Hide right
sidebar" is turned on in settings. Both remember what they were set to across restarts, and the
title bar button briefly shows a check once its state is saved; the first time, a short note
explains this. On pages that need the sidebar, such as the mod browser, the button stays in place,
greyed out. While the sidebar is folded away, the
Minecraft account sits in the title bar next to the window buttons, to switch, add or remove accounts.

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

File pickers on Linux go through the XDG desktop portal, so KDE shows its own dialog and GNOME its
own, instead of a GTK dialog the AppImage themes as light Adwaita. Without a portal, GTK's dialog is
used as before. Windows and macOS already use their native pickers.

With the NVIDIA driver under Wayland, WebKitGTK used to close the window at start with "Error 71".
The webview now hands its frames over through shared memory there
(`WEBKIT_DMABUF_RENDERER_FORCE_SHM=1`), still rendering on the GPU. Setting that or
`WEBKIT_DISABLE_DMABUF_RENDERER` yourself keeps your choice. The AppImage forces X11 and was not
affected.

### Skins

With an Ely.by account selected, the skin page shows the account's skins on Ely.by: apply one, add
one from a file, switch its model or delete it. Ely.by has no API for changing skins, so the
launcher makes the website's own calls from a hidden window and asks you to sign in there once.

On servers that send no skins, such as offline-mode servers, the game looks each player's skin up by
name: first in the `player_skins` folder in the launcher directory (`<name>.png`, `<name>-slim.png`,
`capes/`, `elytras/`), then Ely.by, then Mojang, with capes from OptiFine. Settings > Features > Skins
has the switch and a button that opens the folder.

The Browse tab finds skins elsewhere. Ely.by's catalogue is browsed in the app, with its sorting,
filters and like, wearer and view counts. NameMC, laby.net and crafty.gg open in a window of the app
instead, because their skin lists are bot-protected or not meant for other programs; the skin page
you open there is previewed and can be added.

### Instances and crashes

A running instance can be started again from the button next to Stop, as whichever account is
selected, and the Logs tab then shows a console for each copy.

After a crash the Logs tab reads the crash report, the JVM error file and the end of the log, and
says what went wrong: out of memory, the wrong Java, missing or duplicate mods and more.

Ely.by skin management, skins for every player, second copies and crash explanations are adapted
from [Noctrinth](https://github.com/Everelsu/Noctrinth).

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

### Updates

The app updates itself from this project's releases on GitHub: on Windows, on macOS, and as an
AppImage on Linux. Updates are signed with this project's own key, whose public half is
`updater.pub`, and Modrinth is no longer asked, since its update would be the official app.
Installs from the AUR, a `.deb` or a `.rpm` are updated like any other package; the app shows a
notice with a button to the release when there is a new one.

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

Patches are applied to the release they were exported against (`patches/base.txt`), where they
always fit, and then rebased onto the release in `upstream.txt` when that is newer. The rebase
merges against the files the patches were written for, so upstream changes near a hunk resolve by
themselves. When one genuinely conflicts, `scripts/prepare.sh` stops with the rebase in progress in
`build/upstream`, to be resolved with `git rebase --continue`, after which
`scripts/export-patches.sh` writes the fixed series back against the new release.

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
  published a newer release than `upstream.txt`, it rebases the patches onto it, rebuilds and — only if every
  platform built and every check passed — commits the bump, tags it with the upstream version and
  publishes a release with the installers.
- **Revisions** come from the same run: when `patches/` or `scripts/` changed since the last
  release of that upstream version, it is released again as `v0.21.2-2`, `v0.21.2-3` and so on.
  The app and installers still carry the upstream version: RPM and the Windows installers do not
  accept a suffix in it.
- **Updates** are published with every release as `latest.json`, next to installers signed with the
  `TAURI_SIGNING_PRIVATE_KEY` secret. A release without signatures fails instead of shipping, since
  every install it reached could never update again. Builds without the secret, such as pull
  requests from forks, have no updater.

`scripts/check.sh` is what makes the automation trustworthy. A patch can apply cleanly and still
stop doing its job if upstream moves the thing it was holding down, so the checks assert the
outcome instead of the diff: the app is named correctly, offline accounts are wired up end to end,
no telemetry endpoint survives into the built frontend, and the installers are named after this
fork.

## Licence

The Modrinth App is GPL-3.0, and so is everything here. Modrinth Enhanced is not affiliated with or
endorsed by Rinth, Inc.
