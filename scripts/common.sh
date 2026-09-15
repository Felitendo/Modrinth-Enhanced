#!/usr/bin/env bash
# Shared settings for every script in this repository.
#
# Source this, do not run it.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Where the Modrinth App sources come from, and which release of them the
# patches in this repository are written against.
UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/modrinth/code.git}"
UPSTREAM_REF="${UPSTREAM_REF:-$(tr -d '[:space:]' <"$REPO_ROOT/upstream.txt")}"

# The patched checkout. Everything in here is disposable: it is recreated from
# the upstream tag plus patches/ and is never committed to this repository.
WORKTREE="${WORKTREE:-$REPO_ROOT/build/upstream}"

# Branch the patches are applied on top of the upstream tag as.
PATCH_BRANCH=enhanced

PATCH_DIR="${PATCH_DIR:-$REPO_ROOT/patches}"

# The upstream release the patches in patches/ were last exported against,
# written there by export-patches.sh. upstream.txt cannot say: a release bumps
# it without exporting the patches again.
patch_base() {
	if [ -f "$PATCH_DIR/base.txt" ]; then
		tr -d '[:space:]' <"$PATCH_DIR/base.txt"
	else
		printf '%s\n' "$UPSTREAM_REF"
	fi
}

log() {
	printf '\033[1;32m==>\033[0m %s\n' "$*"
}

warn() {
	printf '\033[1;33m==>\033[0m %s\n' "$*" >&2
}

die() {
	printf '\033[1;31m==>\033[0m %s\n' "$*" >&2
	exit 1
}

# Version the built app reports, derived from the upstream tag it is built
# from: `v0.20.5` becomes `0.20.5`.
app_version() {
	printf '%s\n' "${UPSTREAM_REF#v}"
}

require_worktree() {
	[ -d "$WORKTREE/.git" ] || die "No patched checkout at $WORKTREE. Run scripts/prepare.sh first."
}
