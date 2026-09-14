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
	;;
esac

log "Building for $platform"
(cd "$WORKTREE" && pnpm --filter=@modrinth/app run tauri build "${tauri_args[@]}")

log "Collecting bundles into $ARTIFACTS"
rm -rf "$ARTIFACTS"
mkdir -p "$ARTIFACTS"

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
