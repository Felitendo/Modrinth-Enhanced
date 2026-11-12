#!/bin/bash
# Starts Modrinth Enhanced inside the Flatpak.

# The data directory, and the launchers instances are imported from, are where
# every other install finds them, not in the sandbox's own data folder.
export XDG_DATA_HOME="${HOST_XDG_DATA_HOME:-$HOME/.local/share}"

# The app turns on its fix for NVIDIA under Wayland from /sys/module, which the
# sandbox does not have.
if [ -e /dev/nvidia-modeset ] &&
	[ -z "${WEBKIT_DMABUF_RENDERER_FORCE_SHM+set}${WEBKIT_DISABLE_DMABUF_RENDERER+set}" ]; then
	export WEBKIT_DMABUF_RENDERER_FORCE_SHM=1
fi

# Discord rich presence, with Discord installed as a Flatpak.
for i in {0..9}; do
	test -S "$XDG_RUNTIME_DIR/discord-ipc-$i" ||
		ln -sf "$XDG_RUNTIME_DIR/app/com.discordapp.Discord/discord-ipc-$i" "$XDG_RUNTIME_DIR/discord-ipc-$i"
done

# argv[0] becomes the Wayland app id, which has to match the desktop file.
exec -a "$FLATPAK_ID" /app/bin/ModrinthEnhanced "$@"
