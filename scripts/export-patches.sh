#!/usr/bin/env bash
# Regenerate patches/ from the commits in build/upstream.
#
# Run this after changing anything in the patched checkout: every commit on top
# of the upstream tag becomes one patch file, and patch files that no longer
# have a commit behind them are deleted.

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_worktree

if [ -n "$(git -C "$WORKTREE" status --porcelain)" ]; then
	die "$WORKTREE has uncommitted changes. Commit them first: each commit becomes one patch."
fi

count="$(git -C "$WORKTREE" rev-list --count "$UPSTREAM_REF..HEAD")"
[ "$count" -gt 0 ] || die "No commits on top of $UPSTREAM_REF to export."

log "Exporting $count patches"
rm -f "$PATCH_DIR"/*.patch
git -C "$WORKTREE" format-patch \
	--binary \
	--zero-commit \
	--no-signature \
	--no-numbered \
	--output-directory "$PATCH_DIR" \
	"$UPSTREAM_REF..HEAD"

log "patches/ now contains:"
ls -1 "$PATCH_DIR"
