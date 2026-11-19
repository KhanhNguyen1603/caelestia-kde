#!/usr/bin/env bash
set -euo pipefail

fixture_dir=$(cd "$(dirname "$0")" && pwd)
shell_dir="$fixture_dir/../../../shell"
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export XDG_RUNTIME_DIR="$test_dir/run" XDG_CONFIG_HOME="$test_dir/config" XDG_DATA_HOME="$test_dir/data"
export XDG_CACHE_HOME="$test_dir/cache" XDG_STATE_HOME="$test_dir/state"
export WAYLAND_DISPLAY=fullscreen-test QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software
export QML2_IMPORT_PATH="${QML2_IMPORT_PATH:+$QML2_IMPORT_PATH:}$HOME/.local/lib/qt6/qml"
mkdir -m 700 "$XDG_RUNTIME_DIR"
mkdir "$test_dir/probe"
install -Dm644 "$shell_dir/../assets/org.quickshell.desktop" "$XDG_DATA_HOME/applications/org.quickshell.desktop"
cat >"$XDG_DATA_HOME/applications/drawer-test.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Drawer test
Exec=true
Icon=applications-games
DESKTOP
mkdir -p "$XDG_CONFIG_HOME/caelestia"
cat >"$XDG_CONFIG_HOME/caelestia/shell.json" <<'JSON'
{"bar":{"position":"bottom","entries":[{"id":"dock","zone":"middle","enabled":true},{"id":"statusIcon:audio","zone":"right","enabled":true}],"dock":{"pinnedApps":["drawer-test"]}}}
JSON
cp "$fixture_dir/shell.qml" "$test_dir/probe/shell.qml"
ln -s "$shell_dir"/{assets,components,modules,scripts,services,utils} "$test_dir/probe/"

# A separate bus and runtime directory keep the test's windows and focus changes off the user's desktop.
dbus-run-session -- bash -s -- "$test_dir" <<'SESSION'
set -euo pipefail
test_dir=$1
kwin_wayland --virtual --output-count 2 --width 960 --height 640 --no-lockscreen --socket "$WAYLAND_DISPLAY" >"$test_dir/kwin.log" 2>&1 &
kwin_pid=$!
qs_pid=
outside_pid=
cleanup() {
    if [[ -n "$qs_pid" ]]; then kill "$qs_pid" 2>/dev/null || :; fi
    if [[ -n "$outside_pid" ]]; then kill "$outside_pid" 2>/dev/null || :; fi
    kill "$kwin_pid" 2>/dev/null || :
    wait || :
}
trap cleanup EXIT
for _ in {1..100}; do
    [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]] && break
    sleep 0.05
done
qs -p "$test_dir/probe" >"$test_dir/qs.log" 2>&1 &
qs_pid=$!
expect() {
    local action=$1 expected=$2 actual=
    for _ in {1..80}; do
        if ! kill -0 "$qs_pid" 2>/dev/null; then cat "$test_dir/qs.log" >&2; return 1; fi
        actual=$(qs ipc --pid "$qs_pid" call test "$action" 2>/dev/null) && [[ "$actual" == "$expected" ]] && return 0
        sleep 0.06
    done
    echo "$action after ${scenario:-startup}: expected $expected, got $actual" >&2
    return 1
}
step() {
    scenario=$1
    cat >"$test_dir/step.js" <<'JS'
const game = workspace.windowList().find(w => w.caption === "Fullscreen test game");
const app = workspace.windowList().find(w => w.caption === "Fullscreen test app");
const outside = workspace.windowList().find(w => w.caption === "Outside game");
const [first, second] = workspace.screenOrder;
JS
    printf '%s\n' "$2" >>"$test_dir/step.js"
    local id
    id=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$test_dir/step.js" fullscreen-test)
    qdbus6 org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script.run
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript fullscreen-test >/dev/null
    expect outputs "$3"
}

expect ready true
step foreground 'workspace.sendClientToScreen(game, first); workspace.sendClientToScreen(app, first); workspace.activeWindow = game;' Virtual-0
step covered 'workspace.activeWindow = app;' none
step lowered 'app.keepBelow = true;' Virtual-0
step raised 'app.keepBelow = false; workspace.raiseWindow(app);' none
step other_output 'workspace.sendClientToScreen(game, second);' Virtual-1
step minimized 'game.minimized = true;' none
step restored 'game.minimized = false; workspace.activeWindow = game;' Virtual-1
step covered_again 'workspace.sendClientToScreen(app, second); workspace.activeWindow = app;' none
step other_desktop 'workspace.createDesktop(1, "test"); app.desktops = [workspace.desktops[1]];' Virtual-1
step current_desktop 'workspace.currentDesktop = workspace.desktops[1];' none
step both_desktops 'game.desktops = [workspace.desktops[0], workspace.desktops[1]]; workspace.activeWindow = game;' Virtual-1
step show_desktop 'workspace.slotToggleShowDesktop();' none
step hide_desktop 'workspace.slotToggleShowDesktop();' Virtual-1
qdbus6 org.kde.ActivityManager /ActivityManager/Activities org.kde.ActivityManager.Activities.AddActivity "Fullscreen test" >/dev/null
step other_activity 'game.activities = workspace.activities.filter(id => id !== workspace.currentActivity);' none
step current_activity 'game.activities = workspace.activities; workspace.activeWindow = game;' Virtual-1
step drawer_output 'workspace.sendClientToScreen(game, first); workspace.activeWindow = game;' Virtual-0
call() { qs ipc --pid "$qs_pid" call test "$@"; }
call openLauncher
expect launcherReady true
[[ $(call crossDock) == true ]] || { echo "The pinned dock item is missing" >&2; exit 1; }
expect launcherReady true
[[ $(call clickAudio) == true ]] || { echo "The audio icon is missing" >&2; exit 1; }
expect audioOpen true
step dismiss 'workspace.activeWindow = game;' Virtual-0
expect suppressed true
step covered_for_preview 'workspace.sendClientToScreen(app, first); workspace.activeWindow = app;' none
expect barOpen true
[[ $(call crossDock) == true ]] || { echo "The pinned dock item is missing" >&2; exit 1; }
expect dockPreview true

# A reload builds a new bridge over the window handles the plugin already holds,
# so a window from another client must still be followed afterwards.
mkdir "$test_dir/outside"
cat >"$test_dir/outside/shell.qml" <<'QML'
import QtQuick
import Quickshell
ShellRoot { Window { title: "Outside game"; visibility: Window.FullScreen } }
QML
qs -p "$test_dir/outside" >"$test_dir/outside.log" 2>&1 &
outside_pid=$!
expect outsideOpen true
step outside 'workspace.sendClientToScreen(outside, second); workspace.activeWindow = outside;' Virtual-1
loaded=$(call loadedAt)
# Quickshell reloads in place when shell.qml changes. The reloaded probe has no windows of its own.
grep -v '^    Window {' "$test_dir/probe/shell.qml" >"$test_dir/reloaded.qml"
cat "$test_dir/reloaded.qml" >"$test_dir/probe/shell.qml"
for _ in {1..80}; do
    [[ $(call loadedAt 2>/dev/null || :) != "$loaded" ]] && break
    sleep 0.06
done
[[ $(call loadedAt) != "$loaded" ]] || { echo "The probe did not reload" >&2; exit 1; }
step outside_minimized 'outside.minimized = true;' none
step outside_restored 'outside.minimized = false; workspace.activeWindow = outside;' Virtual-1
echo "Fullscreen stacking and drawer tests passed."
SESSION
