#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DINO_GAME="$REPO_ROOT/src/kde/shells/caelestia.desktop/contents/lockscreen/components/DinoGame.qml"

test_dino_game_runs_on_frame_clock() {
    local content
    content="$(cat "$DINO_GAME")"

    assert_contains "$content" 'FrameAnimation {' \
        "DinoGame must use FrameAnimation to drive physics"
    assert_contains "$content" 'DinoGameBackend.advance(frameTime * 1000)' \
        "FrameAnimation must advance DinoGameBackend by frame delta"
    assert_contains "$content" 'running: root.isRunning && root.visible' \
        "FrameAnimation must only run when the game is active and visible"
}

test_dino_game_pauses_when_hidden_or_destroyed() {
    local content
    content="$(cat "$DINO_GAME")"

    assert_contains "$content" 'onVisibleChanged:' \
        "DinoGame must handle visibility changes"
    assert_contains "$content" 'if (!visible)' \
        "DinoGame must check when visibility is lost"
    assert_contains "$content" 'DinoGameBackend.pause()' \
        "DinoGame must pause backend when hidden"
    assert_contains "$content" 'Component.onDestruction:' \
        "DinoGame must handle destruction"
    assert_not_contains "$content" 'onActiveFocusChanged' \
        "DinoGame must not auto-pause on activeFocus changes"
}

test_dino_game_mouse_only_and_does_not_steal_focus() {
    local content
    content="$(cat "$DINO_GAME")"

    assert_not_contains "$content" 'forceActiveFocus' \
        "DinoGame must not steal active focus from the password field"
    assert_not_contains "$content" 'Keys.onSpacePressed' \
        "DinoGame must not capture Space or steal keyboard input"
    assert_contains "$content" 'DinoGameBackend.jump()' \
        "Mouse click must invoke DinoGameBackend.jump()"
}

test_dino_game_handles_paused_and_high_score_overlays() {
    local content
    content="$(cat "$DINO_GAME")"

    assert_contains "$content" 'visible: root.isPlaying && DinoGameBackend.isPaused' \
        "DinoGame must show a paused banner when paused"
    assert_contains "$content" 'DinoGameBackend.isNewHighScore' \
        "DinoGame must highlight new high score"
}

run_tests
