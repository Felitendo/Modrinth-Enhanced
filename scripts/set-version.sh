#!/usr/bin/env bash
# Stamp the build version into the patched checkout.
#
# Upstream leaves `1.0.0-local` in the sources and injects the real version in
# its release workflow; this does the same. Without an argument the version is
# derived from the upstream tag in upstream.txt.

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_worktree

version="${1:-$(app_version)}"
version="${version#v}"

log "Setting version to $version"

python3 - "$WORKTREE" "$version" <<'PY'
import json
import pathlib
import re
import sys

worktree = pathlib.Path(sys.argv[1])
version = sys.argv[2]

for relative in ("apps/app/Cargo.toml", "packages/app-lib/Cargo.toml"):
    path = worktree / relative
    text = path.read_text(encoding="utf-8")
    # Only the `version` key of the leading [package] table, never a dependency.
    patched, count = re.subn(
        r'(?m)^version = "[^"]*"$', f'version = "{version}"', text, count=1
    )
    if count != 1:
        sys.exit(f"Could not find a package version in {relative}")
    path.write_text(patched, encoding="utf-8")
    print(f"  {relative}")

path = worktree / "apps/app-frontend/package.json"
data = json.loads(path.read_text(encoding="utf-8"))
data["version"] = version
# Keep the file byte-compatible with the tab indentation upstream uses so that
# `prettier --check` stays happy.
path.write_text(json.dumps(data, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
print("  apps/app-frontend/package.json")
PY
