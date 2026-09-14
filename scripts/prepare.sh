#!/usr/bin/env bash
# Check out the pinned Modrinth App release and apply every patch on top of it.
#
# The result lands in build/upstream on the `enhanced` branch and is what all
# other scripts build from. Running this again always starts from a clean
# upstream tree, so it is safe to repeat.

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

log "Upstream $UPSTREAM_REF from $UPSTREAM_REPO"

if [ ! -d "$WORKTREE/.git" ]; then
	log "Cloning into $WORKTREE"
	mkdir -p "$(dirname "$WORKTREE")"
	git clone --depth 1 --branch "$UPSTREAM_REF" "$UPSTREAM_REPO" "$WORKTREE"
else
	log "Fetching $UPSTREAM_REF into the existing checkout"
	git -C "$WORKTREE" remote set-url origin "$UPSTREAM_REPO"
	git -C "$WORKTREE" fetch --depth 1 --force origin "refs/tags/$UPSTREAM_REF:refs/tags/$UPSTREAM_REF"
fi

# `git am` refuses to run with a rebase or merge in progress, and a previous
# run may have stopped on a conflict.
git -C "$WORKTREE" am --abort 2>/dev/null || true

log "Resetting to $UPSTREAM_REF"
git -C "$WORKTREE" checkout --detach --force "$UPSTREAM_REF"
git -C "$WORKTREE" branch -f "$PATCH_BRANCH" "$UPSTREAM_REF"
git -C "$WORKTREE" checkout --force "$PATCH_BRANCH"
git -C "$WORKTREE" reset --hard "$UPSTREAM_REF"
git -C "$WORKTREE" clean -fdx -e node_modules -e target

# `git am` needs an identity for the commits it creates.
git -C "$WORKTREE" config user.name "Modrinth Enhanced"
git -C "$WORKTREE" config user.email "patches@modrinth-enhanced.invalid"
git -C "$WORKTREE" config commit.gpgsign false

shopt -s nullglob
patches=("$PATCH_DIR"/*.patch)
shopt -u nullglob

[ ${#patches[@]} -gt 0 ] || die "No patches found in $PATCH_DIR"

log "Applying ${#patches[@]} patches"
if ! git -C "$WORKTREE" am --3way --whitespace=nowarn "${patches[@]}"; then
	cat >&2 <<EOF

A patch did not apply to $UPSTREAM_REF.

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

log "Patched checkout ready at $WORKTREE"
git -C "$WORKTREE" --no-pager log --oneline "$UPSTREAM_REF..$PATCH_BRANCH"
