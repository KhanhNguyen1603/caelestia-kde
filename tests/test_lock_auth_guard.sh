#!/usr/bin/env bash

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTH_HANDLER="$REPO_ROOT/src/kde/shells/caelestia.desktop/contents/lockscreen/components/AuthHandler.qml"
PASSWORD_PILL="$REPO_ROOT/src/kde/shells/caelestia.desktop/contents/lockscreen/components/PasswordPill.qml"
LOCKSCREEN_UI="$REPO_ROOT/src/kde/shells/caelestia.desktop/contents/lockscreen/LockScreenUi.qml"

# Prints one QML function's body.
qml_function() {
    awk -v name="$2" '
        $0 ~ "^    function " name "\\(" { capture = 1 }
        capture { print }
        capture && $0 == "    }" { exit }
    ' "$1"
}

test_backend_heartbeat_timer_matches_upstream() {
    local qml
    qml="$(cat "$AUTH_HANDLER")"

    assert_contains "$qml" 'id: backendHeartbeatTimer' \
        "AuthHandler should have a backendHeartbeatTimer"
    assert_contains "$qml" 'interval: 1000' \
        "backendHeartbeatTimer should match upstream 1000ms interval"
    assert_contains "$qml" 'running: root.viewVisible && Boolean(activeAuthenticator) && !(activeAuthenticator && activeAuthenticator.unlocked)' \
        "backendHeartbeatTimer should run continuously while visible and locked"
    assert_contains "$qml" 'activeAuthenticator.startAuthenticating();' \
        "backendHeartbeatTimer should trigger startAuthenticating"
}

test_submitting_password_delegates_to_authenticator() {
    local resp
    resp="$(qml_function "$AUTH_HANDLER" respond)"

    assert_contains "$resp" 'activeAuthenticator.pamTimeout' \
        "respond should check pamTimeout matching upstream"
    assert_contains "$resp" 'root.pendingPassword = pass;' \
        "respond should queue pendingPassword if pamTimeout is active"
    assert_contains "$resp" 'activeAuthenticator.respond(pass);' \
        "respond should directly invoke activeAuthenticator.respond when not timed out"
}

test_pam_timeout_changed_resubmits_pending_password() {
    local qml
    qml="$(cat "$AUTH_HANDLER")"

    assert_contains "$qml" 'function onPamTimeoutChanged()' \
        "AuthHandler should handle onPamTimeoutChanged"
    assert_contains "$qml" 'activeAuthenticator.respond(root.pendingPassword);' \
        "onPamTimeoutChanged should flush pendingPassword when timeout clears"
    assert_contains "$qml" 'root.pendingPassword = "";' \
        "onPamTimeoutChanged should clear pendingPassword after flush"
}

test_failed_unlock_restarts_authenticating() {
    local qml
    qml="$(cat "$AUTH_HANDLER")"

    assert_contains "$qml" 'function onFailed(kind, auth)' \
        "AuthHandler should handle onFailed"
    assert_contains "$qml" 'activeAuthenticator.startAuthenticating();' \
        "onFailed should restart authenticating on failure matching upstream"
    assert_contains "$qml" 'root.clearPasswordRequested();' \
        "onFailed should request password clear"
}

test_mouse_movement_does_not_flood_authentication() {
    local qml
    qml="$(cat "$LOCKSCREEN_UI")"

    assert_not_contains "$qml" 'onPositionChanged: authHandler.ensureAuthenticating()' \
        "mouse movement over the lock screen must not flood authentication requests"
}

test_lockscreen_does_not_force_view_visible() {
    local qml
    qml="$(cat "$LOCKSCREEN_UI")"

    assert_not_contains "$qml" 'Binding { target: root; property: "viewVisible"; value: true }' \
        "LockScreenUi should not overwrite kscreenlocker root viewVisible"
}

test_lockscreen_ui_does_not_authenticate_on_creation() {
    local qml
    qml="$(cat "$LOCKSCREEN_UI")"

    assert_not_contains "$qml" 'Component.onCompleted: authHandler.ensureAuthenticating()' \
        "LockScreenUi should not start authenticating on component creation before ready and visible"
}

test_no_artificial_blocking_booleans() {
    local qml
    qml="$(cat "$AUTH_HANDLER")"

    assert_not_contains "$qml" 'root.isAuthenticating = true' \
        "AuthHandler must not set artificial isAuthenticating = true locks"
    assert_not_contains "$qml" 'root.localGraceLocked = true' \
        "AuthHandler must not set artificial localGraceLocked locks"
}

test_about_to_suspend_only_clears_password() {
    local qml
    qml="$(cat "$LOCKSCREEN_UI")"

    assert_contains "$qml" 'function onAboutToSuspend() { root.clearPassword(); }' \
        "onAboutToSuspend should only clear password matching upstream"
}

test_prompt_for_secret_respects_show_prompt() {
    local qml
    qml="$(cat "$AUTH_HANDLER")"

    assert_contains "$qml" 'activeAuthenticator.showPrompt' \
        "onPromptForSecretChanged should check showPrompt matching upstream before handling message"
    assert_contains "$qml" 'lower === "password:" || lower === "password" || lower === "passwd:" || lower === "passwd"' \
        "handleMessage should filter out raw secret prompt strings"
}

test_heartbeat_timer_guards_active_prompts() {
    local qml helper
    qml="$(cat "$AUTH_HANDLER")"
    helper="$(qml_function "$AUTH_HANDLER" hasOpenPrompt)"

    assert_contains "$qml" '!root.promptPending' \
        "backendHeartbeatTimer and ensureAuthenticating must guard active prompts (both secret and echo-on)"
    assert_contains "$qml" '!activeAuthenticator.busy' \
        "backendHeartbeatTimer must not interrupt busy authenticators"
    assert_contains "$qml" 'function onStateChanged()' \
        "AuthHandler should reset promptPending when authenticator state returns to Idle"
    assert_contains "$qml" 'Qt.callLater(root.flushPendingPassword)' \
        "prompt handlers should defer flushPendingPassword until PamAuthenticator::promptInternal() records m_pendingPrompt"
    assert_contains "$helper" 'root.isAuthenticatingState(auth)' \
        "hasOpenPrompt should check that the backend is actively authenticating"
    assert_not_contains "$qml" 'ScreenLocker.Authenticators' \
        "AuthHandler must not reference ScreenLocker.Authenticators (not exposed to QML across Plasma 6 versions)"
    assert_contains "$helper" 'auth.promptForSecret || auth.prompt' \
        "hasOpenPrompt should check both secret and echo-on prompts"
}

test_unlock_failure_feedback() {
    local qml_auth qml_pill
    qml_auth="$(cat "$AUTH_HANDLER")"
    qml_pill="$(cat "$PASSWORD_PILL")"

    assert_not_contains "$qml_auth" 'isExactFailMsg' \
        "AuthHandler must not suppress unlocking failed messages"
    assert_contains "$qml_pill" 'root.isError' \
        "PasswordPill should track error state on rejection"
    assert_contains "$qml_pill" 'root.clError' \
        "PasswordPill border should turn red on error or shake"
}

run_tests
