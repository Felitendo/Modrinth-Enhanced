#!/usr/bin/env bash
# Bundle the Linux build in build/artifacts as a Flatpak.
#
# Expects scripts/build.sh to have run on Linux. Its .deb is repackaged on the
# GNOME runtime by flatpak/, and the .flatpak lands next to it. Needs
# flatpak-builder, or org.flatpak.Builder from Flathub.

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

ARTIFACTS="${ARTIFACTS:-$REPO_ROOT/build/artifacts}"
FLATPAK_BUILD="${FLATPAK_BUILD:-$REPO_ROOT/build/flatpak}"
APP_ID=io.github.felitendo.ModrinthEnhanced
FLATHUB=https://dl.flathub.org/repo/flathub.flatpakrepo

shopt -s nullglob
debs=("$ARTIFACTS"/*.deb)
shopt -u nullglob
[ ${#debs[@]} = 1 ] || die "Expected one .deb in $ARTIFACTS, found ${#debs[@]}"
deb="${debs[0]}"

# "Modrinth Enhanced_0.23.1_amd64.deb" becomes
# "Modrinth Enhanced_0.23.1_x86_64.flatpak".
name="$(basename "$deb" _amd64.deb)"
version="${name##*_}"
bundle="$ARTIFACTS/${name}_x86_64.flatpak"

if command -v flatpak-builder >/dev/null; then
	builder=(flatpak-builder)
elif flatpak info org.flatpak.Builder >/dev/null 2>&1; then
	builder=(flatpak run org.flatpak.Builder)
else
	die "Needs flatpak-builder, or: flatpak install flathub org.flatpak.Builder"
fi

src="$FLATPAK_BUILD/src"
log "Preparing $src"
rm -rf "$src"
mkdir -p "$src"
cp "$REPO_ROOT"/flatpak/* "$src/"
cp "$deb" "$src/modrinth-enhanced.deb"

# The release, for software centres to show.
sed -i "s|<!-- scripts/flatpak.sh adds the release it builds. -->|<release version=\"$version\" date=\"$(date -u +%F)\"/>|" \
	"$src/$APP_ID.metainfo.xml"

# A dev build is an app of its own, as in scripts/build.sh, with the data
# directory of its bundle identifier. modrinth:// links and modpacks stay with
# the stable app.
if [ -n "${DEV:-}" ]; then
	dev_id="$APP_ID.Devel"
	sed -i \
		-e "s/$APP_ID/$dev_id/g" \
		-e 's#xdg-data/ModrinthApp:#xdg-data/ModrinthAppDev:#' \
		-e 's/ModrinthApp\.SingleInstance/ModrinthAppDev.SingleInstance/' \
		-e 's/desktop-file-edit \\$/desktop-file-edit --remove-key=MimeType \\/' \
		"$src/$APP_ID.yml"
	sed -i \
		-e "s/$APP_ID/$dev_id/g" \
		-e 's#<name>Modrinth Enhanced</name>#<name>Modrinth Enhanced (dev)</name>#' \
		"$src/$APP_ID.metainfo.xml"
	mv "$src/$APP_ID.yml" "$src/$dev_id.yml"
	mv "$src/$APP_ID.metainfo.xml" "$src/$dev_id.metainfo.xml"
	APP_ID="$dev_id"
	log "Building $APP_ID, which shares nothing with a stable install"
fi

flatpak remote-add --user --if-not-exists flathub "$FLATHUB"

log "Building $APP_ID $version"
"${builder[@]}" --user --install-deps-from=flathub --disable-rofiles-fuse \
	--force-clean --default-branch=stable \
	--state-dir="$FLATPAK_BUILD/state" --repo="$FLATPAK_BUILD/repo" \
	"$FLATPAK_BUILD/app" "$src/$APP_ID.yml"

log "Bundling $(basename "$bundle")"
rm -f "$bundle"
flatpak build-bundle --runtime-repo="$FLATHUB" \
	"$FLATPAK_BUILD/repo" "$bundle" "$APP_ID" stable

ls -la "$bundle"
