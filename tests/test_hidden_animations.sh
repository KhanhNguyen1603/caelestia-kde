#!/usr/bin/env bash

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CTRL="$REPO_ROOT/shell/components/controls"
VIS_FILE="$REPO_ROOT/shell/services/Visibilities.qml"
CONTENT_LIST_FILE="$REPO_ROOT/shell/modules/launcher/ContentList.qml"
CONTENT_FILE="$REPO_ROOT/shell/modules/launcher/Content.qml"
APP_LIST_FILE="$REPO_ROOT/shell/modules/launcher/AppList.qml"
LOADING_SRC="$(cat "$CTRL/LoadingIndicator.qml")"
CIRCULAR_SRC="$(cat "$CTRL/CircularProgress.qml")"
BAR_SRC="$(cat "$CTRL/StyledProgressBar.qml")"
COVER_SRC="$(cat "$REPO_ROOT/shell/components/widgets/CoverArt.qml")"

test_loading_indicator_runs_only_while_visible() {
    assert_contains "$LOADING_SRC" 'readonly property bool running: animated && visible' "running must depend on visibility"
    assert_contains "$LOADING_SRC" 'running: root.running && !root.springSettled' "the frame animation must follow running"
    assert_not_contains "$LOADING_SRC" 'running: root.animated' "no animation may follow animated alone"
}

test_looping_animations_pause_while_hidden() {
    assert_contains "$CIRCULAR_SRC" '|| !root.visible' "CircularProgress wave must pause while hidden"
    assert_contains "$BAR_SRC" 'root.wavePaused || !root.visible' "StyledProgressBar wave must pause while hidden"
    assert_contains "$COVER_SRC" '|| !root.visible' "CoverArt rotation must pause while hidden"
}

test_progress_bar_size_transitions_are_skipped_while_hidden() {
    local count
    count=$(grep -c 'enabled: root.visible' "$CTRL/StyledProgressBar.qml")
    assert_eq 2 "$count" "both size behaviours must be disabled while hidden"
}

test_launcher_opens_mode_before_becoming_visible() {
    local open_fn
    open_fn="$(sed -n '/function openLauncher/,/}/p' "$VIS_FILE")"

    assert_contains "$open_fn" 'launcherOpened(mode);' "launcherOpened signal must be emitted in openLauncher"
    assert_contains "$open_fn" 'v.launcher = true;' "v.launcher must be activated"

    # Ensure launcherOpened occurs before v.launcher = true so sizing takes place while hidden
    local emit_line set_line
    emit_line="$(echo "$open_fn" | grep -n 'launcherOpened(mode);' | cut -d: -f1)"
    set_line="$(echo "$open_fn" | grep -n 'v.launcher = true;' | cut -d: -f1)"

    if [[ "$emit_line" -ge "$set_line" ]]; then
        fail "launcherOpened(mode) (line $emit_line) must precede v.launcher = true (line $set_line) so mode is sized while hidden"
    fi
}

test_launcher_content_list_animates_size_only_while_visible() {
    local list_src
    list_src="$(cat "$CONTENT_LIST_FILE")"
    assert_contains "$list_src" 'Behavior on implicitWidth' "ContentList should have width behavior"
    assert_contains "$list_src" 'Behavior on implicitHeight' "ContentList should have height behavior"
    assert_contains "$list_src" 'enabled: root.visibilities.launcher && !root.visibilities.skipLauncherAnim' \
        "implicit size behaviors must be guarded by visibilities.launcher"
}

test_launcher_content_applies_mode_on_open() {
    local content_src
    content_src="$(cat "$CONTENT_FILE")"
    assert_contains "$content_src" 'root.searchTextForMode(Visibilities.launcherMode)' \
        "Content search text must be initialized from Visibilities.launcherMode"
}

test_launcher_app_list_transition_disabled_while_hidden() {
    local app_list_src
    app_list_src="$(cat "$APP_LIST_FILE")"
    assert_contains "$app_list_src" 'if (!visibilities.launcher || requestedState === displayState)' \
        "AppList must sync displayText while launcher is hidden"
    assert_contains "$app_list_src" 'enabled: root.visibilities.launcher && !root.visibilities.skipLauncherAnim' \
        "AppList state transition must be disabled while hidden"
}

test_launcher_empty_state_behaviors_disabled_while_hidden() {
    local empty_block
    empty_block="$(sed -n '/id: empty/,/Behavior on implicitWidth/p' "$CONTENT_LIST_FILE")"
    local count
    count=$(echo "$empty_block" | grep -c 'enabled: root.visibilities.launcher && !root.visibilities.skipLauncherAnim')
    assert_eq 2 "$count" "both empty state behaviors must be guarded by visibilities.launcher"
}

run_tests
