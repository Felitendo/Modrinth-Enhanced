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
	;;
esac

# Emptied before the build, not after it: a build that fails halfway would
# otherwise leave the previous run's installers sitting here, where
# scripts/check.sh would happily pass them off as this build's output.
log "Clearing $ARTIFACTS"
rm -rf "$ARTIFACTS"
mkdir -p "$ARTIFACTS"

log "Building for $platform"
(cd "$WORKTREE" && pnpm --filter=@modrinth/app run tauri build "${tauri_args[@]}")

log "Collecting bundles into $ARTIFACTS"

if [ "$platform" = macos ]; then
	bundle_dir="$WORKTREE/target/universal-apple-darwin/release/bundle"
else
	bundle_dir="$WORKTREE/target/release/bundle"
fi

found=0
while IFS= read -r -d '' artifact; do
	cp "$artifact" "$ARTIFACTS/"
	found=1
done < <(find "$bundle_dir" -maxdepth 2 -type f \
	\( -name '*.AppImage' -o -name '*.deb' -o -name '*.rpm' \
	-o -name '*.dmg' -o -name '*.app.tar.gz' -o -name '*-setup.exe' \) -print0)

[ "$found" = 1 ] || die "No bundles were produced under $bundle_dir"

ls -la "$ARTIFACTS"
