#!/usr/bin/env bash
# Print the newest Modrinth App release tag upstream has published.
#
# With --write, also store it in upstream.txt. Exits with status 0 either way;
# compare the output with upstream.txt to find out whether anything moved.

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

latest="$(
	git ls-remote --tags --refs "$UPSTREAM_REPO" 'v*' |
		sed 's#.*refs/tags/##' |
		grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' |
		sort -V |
		tail -1
)"

[ -n "$latest" ] || die "Could not determine the latest upstream release tag"

if [ "${1:-}" = --write ]; then
	printf '%s\n' "$latest" >"$REPO_ROOT/upstream.txt"
fi

printf '%s\n' "$latest"
