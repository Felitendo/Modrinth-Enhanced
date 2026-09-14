#!/usr/bin/env bash
# Verify that the patched checkout still is Modrinth Enhanced.
#
# A patch can apply cleanly and still stop doing its job - upstream may move
# the thing it was holding down. These checks assert the outcome rather than
# the diff: the app is named correctly, offline accounts exist, and no
# telemetry endpoint survives into the built frontend.
#
# Checks that need the built frontend are skipped when it is not there yet, so
# this is useful both before and after scripts/build.sh.

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_worktree

failures=0

check() {
	local description="$1"
	shift
	if "$@" >/dev/null 2>&1; then
		printf '  \033[1;32mok\033[0m    %s\n' "$description"
	else
		printf '  \033[1;31mFAIL\033[0m  %s\n' "$description"
		failures=$((failures + 1))
	fi
}

contains() {
	grep -qF "$2" "$1"
}

missing() {
	! grep -qrF "$2" "$1"
}

log "Branding"
check "tauri.conf.json is named Modrinth Enhanced" \
	contains "$WORKTREE/apps/app/tauri.conf.json" '"productName": "Modrinth Enhanced"'
check "the window is titled Modrinth Enhanced" \
	contains "$WORKTREE/apps/app/tauri.conf.json" '"title": "Modrinth Enhanced"'

log "Offline accounts"
check "app-lib exposes login_offline" \
	contains "$WORKTREE/packages/app-lib/src/api/minecraft_auth.rs" 'pub async fn login_offline'
check "the Tauri command is registered" \
	contains "$WORKTREE/apps/app/src/api/auth.rs" 'login_offline,'
check "the frontend can reach it" \
	contains "$WORKTREE/apps/app-frontend/src/helpers/auth.js" "plugin:auth|login_offline"
check "it is reachable with no account yet" \
	contains "$WORKTREE/apps/app-frontend/src/components/ui/minecraft-required-modal/MinecraftRequiredModal.vue" 'showOfflineAccountModal'

log "Microsoft sign-in"
check "the browser flow is registered" \
	contains "$WORKTREE/apps/app/src/api/auth.rs" 'login_browser_begin,'
check "the sign-in button opens it" \
	contains "$WORKTREE/apps/app-frontend/src/components/ui/AccountsCard.vue" 'microsoftLoginModal.value?.show'

log "Ely.by accounts"
check "app-lib can sign in to Ely.by" \
	contains "$WORKTREE/packages/app-lib/src/api/minecraft_auth.rs" 'pub async fn login_ely'
check "the Tauri command is registered" \
	contains "$WORKTREE/apps/app/src/api/auth.rs" 'login_ely,'
check "authlib-injector is added at launch" \
	contains "$WORKTREE/packages/app-lib/src/launcher/mod.rs" 'authlib_injector'

log "Sidebar and news"
check "Modrinth Servers is behind a flag" \
	contains "$WORKTREE/apps/app-frontend/src/App.vue" "getFeatureFlag('show_hosting_in_sidebar')"
check "the news section can be collapsed" \
	contains "$WORKTREE/apps/app-frontend/src/App.vue" 'setNewsCollapsed'
check "the right sidebar has a fold button" \
	contains "$WORKTREE/apps/app-frontend/src/App.vue" 'setSidebarCollapsed(sidebarToggled)'

log "No advertising or upsells"
check "no Modrinth+ upsell in the app" \
	missing "$WORKTREE/apps/app-frontend/src/App.vue" "modrinth.plus"
check "the ad helpers are stubbed" \
	missing "$WORKTREE/apps/app-frontend/src/helpers/ads.js" "plugin:ads"

log "No telemetry in the sources"
# Quoted, so that the module names being mentioned in a comment explaining why
# they are gone does not count as importing them.
check "nothing imports posthog-js" \
	missing "$WORKTREE/apps/app-frontend/src" "'posthog-js'"
check "nothing imports @sentry/vue" \
	missing "$WORKTREE/apps/app-frontend/src" "'@sentry/vue'"
check "the Tally embed is gone" \
	missing "$WORKTREE/apps/app-frontend/index.html" "tally.so"
check "playtime is not reported" \
	missing "$WORKTREE/packages/app-lib/src/api/instance/run.rs" "analytics/playtime"
check "server plays are not reported" \
	missing "$WORKTREE/packages/app-lib/src/api/instance/run.rs" "analytics/minecraft-server-play"
check "the CSP does not allow PostHog" \
	missing "$WORKTREE/apps/app/tauri.conf.json" "posthog"
check "the CSP does not allow Sentry" \
	missing "$WORKTREE/apps/app/tauri.conf.json" "sentry.io"

dist="$WORKTREE/apps/app-frontend/dist"
if [ -d "$dist" ]; then
	log "No telemetry in the built frontend"
	check "no PostHog endpoint in the bundle" missing "$dist" "posthog.modrinth.com"
	check "no Sentry endpoint in the bundle" missing "$dist" "ingest.us.sentry.io"
	check "no Tally embed in the bundle" missing "$dist" "tally.so"
else
	warn "Skipping bundle checks: $dist does not exist yet"
fi

artifacts="${ARTIFACTS:-$REPO_ROOT/build/artifacts}"
if [ -d "$artifacts" ] && [ -n "$(ls -A "$artifacts" 2>/dev/null)" ]; then
	log "Installers"
	for artifact in "$artifacts"/*; do
		name="$(basename "$artifact")"
		case "$name" in
		"Modrinth Enhanced"* | ModrinthEnhanced* | "Modrinth_Enhanced"*)
			printf '  \033[1;32mok\033[0m    %s\n' "$name"
			;;
		*)
			printf '  \033[1;31mFAIL\033[0m  %s is not named after Modrinth Enhanced\n' "$name"
			failures=$((failures + 1))
			;;
		esac
	done
fi

if [ "$failures" -gt 0 ]; then
	die "$failures check(s) failed"
fi

log "All checks passed"
