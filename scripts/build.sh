#!/usr/bin/env bash
# Build Modrinth Enhanced from the patched checkout and collect the installers.
#
# Expects scripts/prepare.sh to have run. Finished bundles are copied to
# build/artifacts.

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_worktree

ARTIFACTS="${ARTIFACTS:-$REPO_ROOT/build/artifacts}"

# Upstream keeps the API endpoints out of the sources and picks one at build
# time; production is the only sensible choice for a release build.
log "Selecting the production environment"
cp "$WORKTREE/packages/app-lib/.env.prod" "$WORKTREE/packages/app-lib/.env"

"$REPO_ROOT/scripts/set-version.sh"

log "Installing JavaScript dependencies"
(cd "$WORKTREE" && pnpm install --frozen-lockfile)

# The frontend is built through turbo, whose local cache keeps every task's
# outputs, and upstream counts the Rust target directory among them: gigabytes
# a build, never cleaned up, and copied back over target/ on a cache hit. A
# release build wants none of that, so the local cache is off and what an
# earlier build left there is removed.
export TURBO_CACHE=remote:r
rm -rf "$WORKTREE/.turbo/cache"

tauri_args=()
case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN* | Windows_NT)
	platform=windows
	tauri_args+=(--bundles nsis)
	;;
Darwin)
	platform=macos
	tauri_args+=(--target universal-apple-darwin)
	;;
*)
	platform=linux
	# The AppImage is assembled by linuxdeploy, which is itself an AppImage and
	# needs FUSE to mount. Plenty of desktops no longer ship FUSE 2, so tell it
	# to unpack itself instead; on a machine that has FUSE this changes nothing.
	export APPIMAGE_EXTRACT_AND_RUN=1
	# Its strip pass fails outright on some distributions, taking the whole
	# bundle with it and reporting nothing about why. Skipping it was measured
	# to cost 4KB of the finished 136MB AppImage, which is not worth a build
	# that only works on some machines.
	export NO_STRIP=1
	# appimagetool guesses the architecture from every ELF file in the AppDir
	# and gives up when it finds two, which happens as soon as the GTK plugin
	# picks up a 32-bit GIO module from a multilib system's /usr/lib32.
	export ARCH="$(uname -m)"
	;;
esac

# The repository releases come from, which the app's update notice points at.
export MODRINTH_ENHANCED_REPOSITORY="${GITHUB_REPOSITORY:-$(git -C "$REPO_ROOT" remote get-url origin | sed -E 's#^.*github\.com[:/]##; s#\.git$##')}"

# Updates come from this repository's own releases, signed with its own key
# (the public half is updater.pub). A build without the private key, such as
# one for a pull request or a local one, has nothing to sign them with and
# leaves the updater out.
if [ -n "${TAURI_SIGNING_PRIVATE_KEY:-}" ]; then
	repository="$MODRINTH_ENHANCED_REPOSITORY"
	updater_conf="$REPO_ROOT/build/updater.conf.json"
	mkdir -p "$(dirname "$updater_conf")"
	node -e '
		const fs = require("fs")
		const [conf, pubkey, repository] = process.argv.slice(1)
		const { capabilities } = JSON.parse(fs.readFileSync(conf, "utf8")).app.security
		console.log(JSON.stringify({
			bundle: { createUpdaterArtifacts: true },
			build: { features: ["updater"] },
			app: { security: { capabilities: [...capabilities, "updater"] } },
			plugins: {
				updater: {
					pubkey: fs.readFileSync(pubkey, "utf8").trim(),
					endpoints: [`https://github.com/${repository}/releases/latest/download/latest.json`],
					windows: { installMode: "passive" },
				},
			},
		}, null, "\t"))
	' "$WORKTREE/apps/app/tauri.conf.json" "$REPO_ROOT/updater.pub" "$repository" >"$updater_conf"
	tauri_args+=(--config "$updater_conf")
	# Tauri asks for the password when none is set, which fails without a
	# terminal. The project's key has none.
	export TAURI_SIGNING_PRIVATE_KEY_PASSWORD="${TAURI_SIGNING_PRIVATE_KEY_PASSWORD-}"
	log "Updates will come from github.com/$repository"
else
	warn "TAURI_SIGNING_PRIVATE_KEY is not set, so this build has no updater"
fi

# Which release of this upstream version this is, for the updater to tell
# v1.2.3-2 from v1.2.3, since the app's own version cannot carry it.
export MODRINTH_ENHANCED_REVISION="${MODRINTH_ENHANCED_REVISION:-1}"

# Emptied before the build, not after it: a build that fails halfway would
# otherwise leave the previous run's installers sitting here, where
# scripts/check.sh would happily pass them off as this build's output.
log "Clearing $ARTIFACTS"
rm -rf "$ARTIFACTS"
mkdir -p "$ARTIFACTS"

if [ "$platform" = macos ]; then
	bundle_dir="$WORKTREE/target/universal-apple-darwin/release/bundle"
else
	bundle_dir="$WORKTREE/target/release/bundle"
fi

# Tauri leaves earlier bundles, and their signatures, where they were. A build
# without the key would otherwise ship an older build's signatures.
rm -rf "$bundle_dir"

log "Building for $platform"
(cd "$WORKTREE" && pnpm --filter=@modrinth/app run tauri build "${tauri_args[@]}")

log "Collecting bundles into $ARTIFACTS"

found=0
while IFS= read -r -d '' artifact; do
	cp "$artifact" "$ARTIFACTS/"
	found=1
done < <(find "$bundle_dir" -maxdepth 2 -type f \
	\( -name '*.AppImage' -o -name '*.deb' -o -name '*.rpm' \
	-o -name '*.dmg' -o -name '*.app.tar.gz' -o -name '*-setup.exe' \
	-o -name '*.sig' \) -print0)

[ "$found" = 1 ] || die "No bundles were produced under $bundle_dir"

ls -la "$ARTIFACTS"
