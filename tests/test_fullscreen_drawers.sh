#!/usr/bin/env bash
# suite: isolated

set -uo pipefail

tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$tests_dir/helpers.sh"

test_fullscreen_stacking_and_drawers() {
    local cmd
    for cmd in qs kwin_wayland qdbus6 dbus-run-session; do
        if ! command -v "$cmd" >/dev/null; then
            skip_test "fullscreen drawer tests require $cmd"
            return 0
        fi
    done

    bash "$tests_dir/qml/fullscreen/run-kwin.sh" || fail "the fullscreen drawer regression failed"
}

run_tests
