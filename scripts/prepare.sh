#!/usr/bin/env bash
# Check out the pinned Modrinth App release and apply every patch on top of it.
#
# The result lands in build/upstream on the `enhanced` branch and is what all
# other scripts build from. Running this again always starts from a clean
# upstream tree, so it is safe to repeat.
#
# The patches are applied to the release they were exported against, where they
# always fit, and rebased onto $UPSTREAM_REF when that is a different release.
# A rebase merges against the files the patches were written for, so upstream
# changing something near a patch resolves by itself. `git am` straight onto the
# new release cannot do that: a shallow checkout does not have those files.

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

BASE_REF="$(patch_base)"

log "Upstream $UPSTREAM_REF from $UPSTREAM_REPO"

fetch_tag() {
	git -C "$WORKTREE" fetch --depth 1 --force origin "refs/tags/$1:refs/tags/$1"
}

if [ ! -d "$WORKTREE/.git" ]; then
	log "Cloning into $WORKTREE"
	mkdir -p "$(dirname "$WORKTREE")"
	git clone --depth 1 --branch "$UPSTREAM_REF" "$UPSTREAM_REPO" "$WORKTREE"
else
	log "Fetching $UPSTREAM_REF into the existing checkout"
	git -C "$WORKTREE" remote set-url origin "$UPSTREAM_REPO"
	fetch_tag "$UPSTREAM_REF"
fi

if [ "$BASE_REF" != "$UPSTREAM_REF" ]; then
	log "Fetching $BASE_REF, which the patches were exported against"
	fetch_tag "$BASE_REF"
fi

# Neither `git am` nor `git rebase` runs while the other is in progress, and a
# previous run may have stopped on a conflict in either.
git -C "$WORKTREE" am --abort 2>/dev/null || true
git -C "$WORKTREE" rebase --abort 2>/dev/null || true

log "Resetting to $BASE_REF"
git -C "$WORKTREE" checkout --detach --force "$BASE_REF"
git -C "$WORKTREE" branch -f "$PATCH_BRANCH" "$BASE_REF"
git -C "$WORKTREE" checkout --force "$PATCH_BRANCH"
git -C "$WORKTREE" reset --hard "$BASE_REF"
git -C "$WORKTREE" clean -fdx -e node_modules -e target

# `git am` and `git rebase` need an identity for the commits they create.
git -C "$WORKTREE" config user.name "Modrinth Enhanced"
git -C "$WORKTREE" config user.email "patches@modrinth-enhanced.invalid"
git -C "$WORKTREE" config commit.gpgsign false

shopt -s nullglob
patches=("$PATCH_DIR"/*.patch)
shopt -u nullglob

[ ${#patches[@]} -gt 0 ] || die "No patches found in $PATCH_DIR"

log "Applying ${#patches[@]} patches to $BASE_REF"
if ! git -C "$WORKTREE" am --3way --whitespace=nowarn "${patches[@]}"; then
	cat >&2 <<EOF

A patch did not apply to $BASE_REF.

The failed patch is left staged in $WORKTREE so it can be fixed by hand:

  cd $WORKTREE
  git status                 # see the conflicts
  # ...resolve them, then:
  git add -A && git am --continue
  # once every patch is in:
  $REPO_ROOT/scripts/export-patches.sh

EOF
	exit 1
fi

if [ "$BASE_REF" != "$UPSTREAM_REF" ]; then
	log "Rebasing the patches onto $UPSTREAM_REF"
	if ! git -C "$WORKTREE" rebase --onto "$UPSTREAM_REF" "$BASE_REF" "$PATCH_BRANCH"; then
		cat >&2 <<EOF

A patch conflicts with what changed between $BASE_REF and $UPSTREAM_REF.

The rebase is left stopped in $WORKTREE so it can be resolved by hand:

  cd $WORKTREE
  git status                 # see the conflicts
  # ...resolve them, then:
  git add -A && git rebase --continue
  # once every patch is in, with upstream.txt set to $UPSTREAM_REF:
  $REPO_ROOT/scripts/export-patches.sh

EOF
		exit 1
	fi
fi

log "Patched checkout ready at $WORKTREE"
git -C "$WORKTREE" --no-pager log --oneline "$UPSTREAM_REF..$PATCH_BRANCH"
