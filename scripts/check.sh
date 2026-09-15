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
check "the checklist offers the same choice" \
	contains "$WORKTREE/apps/app-frontend/src/App.vue" '@login-minecraft="minecraftRequiredModal?.show()"'

# A Tauri command that is not listed in build.rs compiles, ships, and then
# fails at runtime with "not allowed by ACL". Nothing else here would catch it.
log "Tauri command permissions"
while read -r command; do
	[ -n "$command" ] || continue
	check "$command is allowed by the ACL" \
		contains "$WORKTREE/apps/app/build.rs" "\"$command\","
done < <(grep -h -A2 '#\[tauri::command\]' \
	"$WORKTREE/apps/app/src/api/auth.rs" "$WORKTREE/apps/app/src/api/ely_skins.rs" \
	"$WORKTREE/apps/app/src/api/crash_analysis.rs" "$WORKTREE/apps/app/src/api/skin_browser.rs" |
	grep -oE 'pub async fn [a-z_]+' | awk '{print $4}' | sort -u)

# Listing a command in build.rs is not enough either: the main window only
# reaches a plugin whose default permission is in its capabilities.
log "Plugin permissions"
while read -r plugin; do
	[ -n "$plugin" ] || continue
	check "$plugin is granted to the main window" \
		contains "$WORKTREE/apps/app/capabilities/plugins.json" "\"$plugin:default\""
done < <(grep -A1 '\.plugin($' "$WORKTREE/apps/app/build.rs" |
	grep -oE '^ *"[a-z-]+",$' | tr -d ' ",' | sort -u)

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

log "Ely.by skins"
check "the frontend can tell an Ely.by account" \
	contains "$WORKTREE/packages/app-lib/src/state/minecraft_auth.rs" 'serialize_field("ely"'
check "the plugin is registered" \
	contains "$WORKTREE/apps/app/src/main.rs" 'api::ely_skins::init()'
check "the skin page changes skins on Ely.by" \
	contains "$WORKTREE/apps/app-frontend/src/pages/Skins.vue" 'wearElySkin'

log "Skins on offline servers"
check "the agent fills in missing skins" \
	contains "$WORKTREE/packages/app-lib/java/src/main/java/com/modrinth/theseus/agent/TheseusAgent.java" 'SessionServiceTransformer'
check "the launcher turns it on" \
	contains "$WORKTREE/packages/app-lib/src/launcher/args.rs" 'enhanced.skins.source'
check "the skins folder can be opened" \
	contains "$WORKTREE/apps/app/build.rs" '"show_player_skins_folder",'

log "Another copy of a running instance"
check "a running instance can start again" \
	contains "$WORKTREE/packages/app-lib/src/api/instance/run.rs" 'pub async fn run_additional'
check "each copy has a console" \
	contains "$WORKTREE/apps/app-frontend/src/pages/instance/logs/index.vue" 'ProcessConsole'
check "log events say which copy" \
	contains "$WORKTREE/apps/app-frontend/src/generated/app-events/LogPayload.ts" 'process_uuid'

log "Crash explanation"
check "the rules are there" \
	contains "$WORKTREE/packages/app-lib/src/api/crash_analysis.rs" 'pub async fn analyze_instance'
check "the plugin is registered" \
	contains "$WORKTREE/apps/app/src/main.rs" 'api::crash_analysis::init()'
check "the Logs tab shows it" \
	contains "$WORKTREE/apps/app-frontend/src/pages/instance/logs/index.vue" '<CrashDiagnosis'

log "Skin browser"
check "Ely.by's catalogue can be browsed" \
	contains "$WORKTREE/packages/app-lib/src/api/skin_browser.rs" 'pub async fn ely_catalogue'
check "skin sites open in a window" \
	contains "$WORKTREE/apps/app/src/api/skin_browser.rs" 'pub async fn skin_browser_open_site'
check "the skin page has a Browse tab" \
	contains "$WORKTREE/apps/app-frontend/src/pages/Skins.vue" '<SkinBrowser'

log "Sidebar and news"
check "Modrinth Servers is behind a flag" \
	contains "$WORKTREE/apps/app-frontend/src/App.vue" "getFeatureFlag('show_hosting_in_sidebar')"
check "the news section can be collapsed" \
	contains "$WORKTREE/apps/app-frontend/src/App.vue" 'setNewsCollapsed'
check "the right sidebar has a fold button" \
	contains "$WORKTREE/apps/app-frontend/src/App.vue" 'setSidebarCollapsed(sidebarToggled)'

# tauri.linux.conf.json replaces the whole window list, so an upstream change to
# the main window would otherwise silently not reach Linux.
same_linux_window() {
	node -e '
		const fs = require("fs")
		const [base, linux] = process.argv.slice(1).map((p) => JSON.parse(fs.readFileSync(p, "utf8")).app.windows[0])
		delete linux.transparent
		const sorted = (o) => JSON.stringify(o, Object.keys(o).sort())
		process.exit(sorted(base) === sorted(linux) ? 0 : 1)
	' "$WORKTREE/apps/app/tauri.conf.json" "$WORKTREE/apps/app/tauri.linux.conf.json"
}

log "Window"
check "the Linux window is transparent" \
	contains "$WORKTREE/apps/app/tauri.linux.conf.json" '"transparent": true'
check "the Linux window otherwise matches upstream" same_linux_window
check "its corners are rounded" \
	contains "$WORKTREE/apps/app-frontend/src/App.vue" "'rounded-window'"
check "the middle button autoscrolls" \
	contains "$WORKTREE/apps/app-frontend/src/App.vue" 'installAutoscroll()'

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
