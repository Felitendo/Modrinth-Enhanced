#!/usr/bin/env python3
"""Render the Modrinth Enhanced icon set from its vector sources.

Two sources live in the patched checkout next to the generated files:
`apps/app/icons/modrinth-enhanced.svg` for 64px and up, and
`modrinth-enhanced-small.svg` for everything below that, where the full maze
no longer resolves. This rewrites every generated icon from them. Run it after
editing either SVG, then commit the result in build/upstream and re-export the
patches.

Needs `rsvg-convert` (librsvg). ImageMagick is not used: the ICNS and ICO
writers below are a few lines each and work the same everywhere, whereas
ImageMagick's ICNS support depends on how it was built.
"""

import os
import shutil
import struct
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(
    os.environ.get("WORKTREE", os.path.join(REPO_ROOT, "build", "upstream")),
    "apps",
    "app",
    "icons",
)
SVG = os.path.join(ICONS, "modrinth-enhanced.svg")
SVG_SMALL = os.path.join(ICONS, "modrinth-enhanced-small.svg")

# Below this the full mark's rings are thinner than a pixel and smear into each
# other, so the cropped source is used instead.
SMALL_MAX = 48

# Every PNG the Tauri bundles reference, and the size it has to be.
PNGS = {
    "icon.png": 512,
    "128x128.png": 128,
    "128x128@2x.png": 256,
    "StoreLogo.png": 50,
    "Square30x30Logo.png": 30,
    "Square44x44Logo.png": 44,
    "Square71x71Logo.png": 71,
    "Square89x89Logo.png": 89,
    "Square107x107Logo.png": 107,
    "Square142x142Logo.png": 142,
    "Square150x150Logo.png": 150,
    "Square284x284Logo.png": 284,
    "Square310x310Logo.png": 310,
}

ICO_SIZES = [16, 24, 32, 48, 64, 256]
FAVICON_SIZES = [16, 24, 32, 64]

# ICNS chunk type -> pixel size. All chunks carry PNG payloads, which macOS
# 10.7 and newer understand.
ICNS_TYPES = [
    (b"icp4", 16),
    (b"icp5", 32),
    (b"ic11", 32),
    (b"ic12", 64),
    (b"ic07", 128),
    (b"ic13", 256),
    (b"ic08", 256),
    (b"ic14", 512),
    (b"ic09", 512),
    (b"ic10", 1024),
]


def render(size, path):
    """Rasterise the source for `size` at exactly that size, rather than
    downscaling one large render, so the small sizes stay crisp."""
    source = SVG_SMALL if size <= SMALL_MAX else SVG
    subprocess.run(
        ["rsvg-convert", "-w", str(size), "-h", str(size), source, "-o", path],
        check=True,
    )


def build_ico(sizes, cache, path):
    entries, blobs, offset = [], [], 6 + 16 * len(sizes)
    for size in sizes:
        with open(cache[size], "rb") as handle:
            data = handle.read()
        entries.append(
            struct.pack(
                "<BBBBHHII",
                # 256 is written as 0 in an ICO directory entry.
                size if size < 256 else 0,
                size if size < 256 else 0,
                0,
                0,
                1,
                32,
                len(data),
                offset,
            )
        )
        blobs.append(data)
        offset += len(data)
    with open(path, "wb") as handle:
        handle.write(struct.pack("<HHH", 0, 1, len(sizes)))
        for entry in entries:
            handle.write(entry)
        for blob in blobs:
            handle.write(blob)


def build_icns(cache, path):
    chunks = b""
    for kind, size in ICNS_TYPES:
        with open(cache[size], "rb") as handle:
            data = handle.read()
        chunks += kind + struct.pack(">I", len(data) + 8) + data
    with open(path, "wb") as handle:
        handle.write(b"icns" + struct.pack(">I", len(chunks) + 8) + chunks)


def main():
    if not shutil.which("rsvg-convert"):
        sys.exit("rsvg-convert is required (install librsvg)")
    for source in (SVG, SVG_SMALL):
        if not os.path.isfile(source):
            sys.exit(f"No icon source at {source}. Run scripts/prepare.sh first.")

    with tempfile.TemporaryDirectory() as tmp:
        cache = {}
        needed = set(PNGS.values()) | set(ICO_SIZES) | set(FAVICON_SIZES)
        needed |= {size for _, size in ICNS_TYPES}
        for size in sorted(needed):
            cache[size] = os.path.join(tmp, f"{size}.png")
            render(size, cache[size])

        for name, size in PNGS.items():
            shutil.copyfile(cache[size], os.path.join(ICONS, name))
        build_ico(ICO_SIZES, cache, os.path.join(ICONS, "icon.ico"))
        build_ico(FAVICON_SIZES, cache, os.path.join(ICONS, "favicon.ico"))
        build_icns(cache, os.path.join(ICONS, "icon.icns"))

    for name in sorted(os.listdir(ICONS)):
        full = os.path.join(ICONS, name)
        if os.path.isfile(full):
            print(f"{name:24s} {os.path.getsize(full):>8d} bytes")


if __name__ == "__main__":
    main()
