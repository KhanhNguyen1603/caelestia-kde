#!/usr/bin/env bash

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTH_HANDLER="$REPO_ROOT/src/kde/shells/caelestia.desktop/contents/lockscreen/components/AuthHandler.qml"

# Prints one QML function's body. The file indents its functions by four spaces and
# closes them with a brace at that indent, so nested blocks do not end the capture.
# (helpers.sh's extract_function expects a top-level shell function.)
qml_function() {
    awk -v name="$2" '
        $0 ~ "^    function " name "\\(" { capture = 1 }
        capture { print }
        capture && $0 == "    }" { exit }
    ' "$1"
}

# kscreenlocker keeps a prompt open until the password answers it, and since its 6.8 PAM
# rework a second startAuthenticating() in that window is refused as a failed login. The
# greeter cannot read that state off `busy` (false while a prompt waits) or
# `isAuthenticating` (false while it waits for the user), so it tracks the prompt itself.
# tests/test_lockscreen_auth_loop.sh proves the behaviour; these assertions keep the
# mechanism that carries it.
test_the_handler_tracks_a_pending_prompt() {
    local qml
    qml="$(cat "$AUTH_HANDLER")"

    assert_contains "$qml" 'property bool promptPending: false' \
        "AuthHandler should track whether a prompt is waiting for the password"
}

test_authenticating_is_not_restarted_while_a_prompt_waits() {
    local guard
    guard="$(qml_function "$AUTH_HANDLER" ensureAuthenticating)"

    assert_contains "$guard" 'root.promptPending' \
        "ensureAuthenticating should refuse to start a second conversation while a prompt waits"
}

# The backend is started from one place, so "no prompt is waiting yet" cannot be
# forgotten at a stray call site -- which is how the restart loop kept coming back.
test_a_conversation_starts_from_one_place() {
    local starts
    starts="$(grep -c 'activeAuthenticator\.startAuthenticating();' "$AUTH_HANDLER")"

    assert_contains "$(qml_function "$AUTH_HANDLER" startConversation)" \
        'activeAuthenticator.startAuthenticating();' \
        "startConversation should be the function that starts the backend"
    assert_eq 1 "$starts" "the backend should be started from exactly one place"
}

test_a_prompt_is_answered_from_one_place() {
    local answer
    answer="$(qml_function "$AUTH_HANDLER" answerPrompt)"

    assert_contains "$answer" 'root.promptPending = false;' \
        "answering a prompt should clear the prompt state"
    assert_contains "$answer" 'activeAuthenticator.respond(pass);' \
        "answering a prompt should be what calls respond()"

    # The prompt handlers hand the password over; they must not consume the prompt
    # themselves, or the bookkeeping starts drifting between call sites again.
    assert_not_contains "$(qml_function "$AUTH_HANDLER" onPromptChanged)" \
        'root.promptPending = false;' \
        "onPromptChanged should leave the prompt state to answerPrompt"
    assert_not_contains "$(qml_function "$AUTH_HANDLER" onPromptForSecretChanged)" \
        'root.promptPending = false;' \
        "onPromptForSecretChanged should leave the prompt state to answerPrompt"
}

test_the_prompt_flag_comes_from_the_prompt_value() {
    local qml
    qml="$(cat "$AUTH_HANDLER")"

    # The signal also fires with no prompt behind it when the backend resets its
    # authenticator, so the value decides, not the signal.
    assert_contains "$qml" 'root.promptPending = Boolean(activeAuthenticator && activeAuthenticator.promptForSecret);' \
        "a secret prompt should mark the prompt as waiting according to its value"
    assert_contains "$qml" 'root.promptPending = Boolean(activeAuthenticator && activeAuthenticator.prompt);' \
        "an echo-on prompt should mark the prompt as waiting too"
    assert_not_contains "$qml" 'root.promptPending = true;' \
        "the prompt flag must not be set from the bare signal"
}

test_login_responds_only_to_a_live_prompt() {
    local login
    login="$(qml_function "$AUTH_HANDLER" startLogin)"

    # promptForSecret/prompt stay set after a conversation ends, so they cannot say
    # whether respond() has anything to answer.
    assert_contains "$login" 'root.answerPrompt(pass)' \
        "startLogin should answer through the shared prompt path"
    assert_not_contains "$login" 'activeAuthenticator.promptForSecret' \
        "startLogin should not read the sticky prompt strings"
}

test_mouse_movement_does_not_flood_authentication() {
    local lockscreen_ui="$REPO_ROOT/src/kde/shells/caelestia.desktop/contents/lockscreen/LockScreenUi.qml"
    local qml
    qml="$(cat "$lockscreen_ui")"

    assert_not_contains "$qml" 'onPositionChanged: authHandler.ensureAuthenticating()' \
        "mouse movement over the lock screen must not flood authentication requests"
}

test_auth_timeout_defers_restart_to_avoid_worker_kill_race() {
    local qml
    qml="$(cat "$AUTH_HANDLER")"

    assert_contains "$qml" 'id: authRestartTimer' \
        "AuthHandler should have a dedicated authRestartTimer"
    assert_contains "$qml" 'authRestartTimer.restart();' \
        "authTimeoutTimer should restart via authRestartTimer rather than starting synchronously"
    assert_contains "$(qml_function "$AUTH_HANDLER" ensureAuthenticating)" 'authRestartTimer.running' \
        "ensureAuthenticating should refuse to start while a delayed restart is pending"
}

test_login_does_not_restart_conversation_when_busy() {
    local login
    login="$(qml_function "$AUTH_HANDLER" startLogin)"

    assert_contains "$login" '!activeAuthenticator.busy' \
        "startLogin should avoid calling startConversation if the authenticator is already busy"
}

test_lockscreen_does_not_force_view_visible() {
    local lockscreen_ui="$REPO_ROOT/src/kde/shells/caelestia.desktop/contents/lockscreen/LockScreenUi.qml"
    local qml
    qml="$(cat "$lockscreen_ui")"

    assert_not_contains "$qml" 'Binding { target: root; property: "viewVisible"; value: true }' \
        "LockScreenUi should not overwrite kscreenlocker root viewVisible"
}

test_lockscreen_ui_does_not_authenticate_on_creation() {
    local lockscreen_ui="$REPO_ROOT/src/kde/shells/caelestia.desktop/contents/lockscreen/LockScreenUi.qml"
    local qml
    qml="$(cat "$lockscreen_ui")"

    assert_not_contains "$qml" 'Component.onCompleted: authHandler.ensureAuthenticating()' \
        "LockScreenUi should not start authenticating on component creation before ready and visible"
}

test_auth_handler_checks_visibility_before_authenticating() {
    local guard
    guard="$(qml_function "$AUTH_HANDLER" ensureAuthenticating)"

    assert_contains "$guard" 'root.viewVisible' \
        "ensureAuthenticating should check viewVisible before authenticating"
}

run_tests
