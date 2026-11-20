#!/usr/bin/env bash
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVICES="$REPO_ROOT/shell/services"
REGISTRY="$SERVICES/TrayRegistry.qml"
MIGRATIONS="$SERVICES/ConfigMigrations.qml"
ICONS="$REPO_ROOT/shell/utils/Icons.qml"
BAR="$REPO_ROOT/shell/modules/bar/Bar.qml"
TRAY="$REPO_ROOT/shell/modules/bar/components/Tray.qml"
BOX="$REPO_ROOT/shell/modules/bar/popouts/TrayOverflow.qml"
PLACEMENTS="$REPO_ROOT/shell/modules/bar/BarPlacements.qml"
ICONS_PANEL="$REPO_ROOT/shell/modules/bar/popouts/TrayIcons.qml"
WIDGETS="$REPO_ROOT/shell/modules/bar/BarWidgets.qml"
STATUS_PAGE="$REPO_ROOT/shell/modules/nexus/pages/panels/taskbar/BarStatusIcons.qml"
CONTENT="$REPO_ROOT/shell/modules/bar/popouts/Content.qml"
PAGE="$REPO_ROOT/shell/modules/nexus/pages/panels/taskbar/BarTray.qml"
LIST_EDITOR="$REPO_ROOT/shell/modules/nexus/common/ListEditor.qml"
PAGE_BASE="$REPO_ROOT/shell/modules/nexus/common/PageBase.qml"
SELECT_ROW="$REPO_ROOT/shell/modules/nexus/common/SelectRow.qml"

# The tray rules that do not need Qt live in a .pragma library file
# (shell/services/trayicons.js), which each script below runs against with node's assert.
check_tray_icons() { check_js "$1" "$SERVICES/trayicons.js" Icons "$2"; }

test_pid_comes_out_of_the_notifier_id() {
    check_tray_icons "notifier ids start with the pid" '
assert.strictEqual(Icons.pidOf("2652-9"), "2652");
assert.strictEqual(Icons.pidOf("firefox"), "");
assert.strictEqual(Icons.pidOf(""), "");
'
}

test_aliases_name_the_app_rather_than_the_notifier() {
    check_tray_icons "aliases must survive a new notifier id" '
assert.strictEqual(Icons.keyOf("2407-1", "", "firefox"), "proc:firefox", "a known process names the app");
assert.strictEqual(Icons.keyOf("2407-1", "image://icon/firefox", ""), "icon:firefox", "no process name falls back to the theme icon");
assert.strictEqual(Icons.keyOf("2407-1", "image://qspixmap/abc", ""), "2407-1", "a pixmap names nothing, so the id stays");
assert.strictEqual(Icons.keyOf("2407-1", "", ""), "2407-1", "an icon with no name keeps its id");
assert.strictEqual(Icons.keyOf("2407-1", "image://icon/a/absolute/path", "kitty"), "proc:kitty", "a process name wins over a path-like icon");
'
}

test_labels_are_readable() {
    check_tray_icons "row labels come from the alias" '
assert.strictEqual(Icons.labelOf("proc:kitty-terminal"), "kitty terminal");
assert.strictEqual(Icons.labelOf("icon:org_kde_plasma"), "org kde plasma");
assert.strictEqual(Icons.labelOf("2407-1"), "2407-1", "a raw id is not prettified");
assert.strictEqual(Icons.iconNameOf("proc:kitty-terminal"), "kitty-terminal");
'
}

test_a_title_names_the_app_when_it_says_something() {
    check_tray_icons "an app is called what it calls itself" '
assert.strictEqual(Icons.readableTitle("Cachy-Update"), "Cachy-Update", "a title that happens to be the id is still the app name");
assert.strictEqual(Icons.readableTitle("2652-9"), "", "a notifier id is the plumbing, not a name");
assert.strictEqual(Icons.readableTitle("org.kde.StatusNotifierItem-2652-1"), "", "a bus name says nothing either");
assert.strictEqual(Icons.readableTitle(""), "");
'
}

test_a_list_is_written_only_when_it_changes() {
    check_tray_icons "writing a list that already says this costs a redraw" '
assert.strictEqual(Icons.sameList(["a", "b"], ["a", "b"]), true);
assert.strictEqual(Icons.sameList(["a", "b"], ["b", "a"]), false, "order is part of what a list says");
assert.strictEqual(Icons.sameList(["a"], ["a", "b"]), false);
assert.strictEqual(Icons.sameList([], []), true);
assert.strictEqual(Icons.sameList(null, []), true, "an unset list is an empty one");
'
}

test_hidden_wins_over_pinned() {
    check_tray_icons "state precedence is hidden > visible > collapsed" '
assert.strictEqual(Icons.stateOf("a", ["a"], ["a"]), "hidden");
assert.strictEqual(Icons.stateOf("a", [], ["a"]), "visible");
assert.strictEqual(Icons.stateOf("a", ["b"], ["c"]), "collapsed");
'
}

test_listed_keys_come_first_in_listed_order() {
    check_tray_icons "the saved order leads and the rest keeps registration order" '
const rows = [{ key: "a" }, { key: "b" }, { key: "c" }];
assert.deepStrictEqual(Icons.ordered(rows, ["c", "a"]).map(row => row.key), ["c", "a", "b"]);
assert.deepStrictEqual(Icons.ordered(rows, []).map(row => row.key), ["a", "b", "c"], "an empty order keeps registration order");
assert.deepStrictEqual(Icons.ordered(rows, ["gone", "b"]).map(row => row.key), ["b", "a", "c"], "keys the order does not know are skipped");
assert.deepStrictEqual(Icons.ordered([], ["a"]), [], "no rows need no order");
'
}

test_the_bar_and_the_popout_read_one_list() {
    assert_file_contains "$REGISTRY" "readonly property var trayItems" "the registry publishes the bar's icons"
    assert_file_contains "$REGISTRY" "readonly property var barItems" "the registry publishes the list the bar actually draws"
    assert_file_contains "$REGISTRY" "readonly property var overflowItems" "the registry publishes the overflow list"
    assert_file_contains "$REPO_ROOT/shell/modules/bar/BarWidgets.qml" "TrayRegistry.barItems" "the bar reads the list it is meant to draw"
    assert_file_contains "$CONTENT" "TrayRegistry.liveItems" "the tray popout gives every running icon a menu, drawn on the bar or in the box"
    assert_file_not_contains "$CONTENT" "TrayRegistry.trayItems" "an icon in the box must be able to open its menu too"
    assert_file_not_contains "$CONTENT" "SystemTray.items.values.filter" "the popout must not re-derive which icons exist"
    assert_file_not_contains "$BAR" "tray.layout.childAt" "the bar must not reach into the tray's layout"
    assert_file_not_contains "$BAR" "tray.itemAt(root, pos)" "the bar does not hit-test the tray's icons: hovering one opens nothing, so there is nothing to ask them"
}

test_popout_names_have_one_definition() {
    assert_file_contains "$REGISTRY" "function popoutName(key: string): string" "the popout name prefix lives in the registry"
    assert_file_not_contains "$BAR" "traymenu" "the bar must not rebuild the popout name"
    assert_file_not_contains "$BAR" "trayItem.popoutName" "hovering an icon opens nothing, so the bar never asks it for its menu"
    assert_file_contains "$CONTENT" "TrayRegistry.popoutNameOf" "the popout names itself through the registry"
}

test_the_reorder_list_is_the_shared_one() {
    assert_file_missing "$REPO_ROOT/shell/modules/nexus/pages/panels/taskbar/TrayOrderList.qml" "the tray must reuse the shared reorder list"
    assert_file_contains "$PAGE" "ListEditor {" "the tray page reorders with the shared list editor"
    assert_file_contains "$LIST_EDITOR" "property Component trailingComponent" "the shared list editor carries the extra control"
    assert_file_not_contains "$PAGE_BASE" "scrollLocked" "pages must not grow drag-specific scroll modes"
    assert_file_not_contains "$SELECT_ROW" "highlight" "the shared select row must not grow drag-specific modes"
}

test_a_single_identity_reads_icon_substitutions() {
    assert_file_contains "$ICONS" "function getTrayIcon(key: string, icon: string): string" "icon substitutions are keyed by the alias alone"
    assert_file_contains "$MIGRATIONS" "function migrateTrayIcons(aliases: var): void" "the config rewrite maps ids to aliases"
    assert_file_contains "$MIGRATIONS" "sub.id = aliases[sub.id]" "icon substitutions are rewritten with the lists"
    assert_file_contains "$REGISTRY" "ConfigMigrations.migrateTrayIcons(aliases)" "the registry hands its aliases over"
}

test_a_bar_from_before_the_tray_gets_it_back() {
    assert_file_contains "$MIGRATIONS" "function migrateBarEntries(): void" \
        "an installed bar that predates the unified tray is migrated rather than left without one"
    assert_file_contains "$MIGRATIONS" 'if (!bar.isOverride("entries"))' \
        "only a list the user actually saved is rewritten"
    assert_file_contains "$MIGRATIONS" 'entries.some(entry => entry.id === "tray")' \
        "a row that says the tray is off is the user's answer, so only its absence is taken as an older bar"
    assert_file_contains "$MIGRATIONS" 'next.splice(at, 0, { id: "tray", enabled: true, zone: "right" })' \
        "the row goes back among the neighbours the schema declares it with"
    assert_file_contains "$MIGRATIONS" "root.migrateBarEntries();" \
        "and the migration runs when the shell starts"
}

test_an_icon_answers_to_every_name_it_has_had() {
    assert_file_contains "$REGISTRY" "function keysOf(item: var): var" \
        "an icon has one name per alias, because the process alias only arrives after ps has said whose icon it is"
    assert_file_contains "$REGISTRY" 'push(TrayIcons.keyOf(item.id, item.icon, ""));' \
        "the theme-icon alias is one of them, and it is what a setting written early holds"
    assert_file_contains "$REGISTRY" "root.keysOf(item).some(key => root.rowedKeys[key])" \
        "an icon with a row under any of its names is drawn from that row, so it cannot also wait in the box"
    assert_file_contains "$REGISTRY" "root.liveItems.find(item => root.keysOf(item).includes(key)) ?? null" \
        "and a stored name resolves to the icon it was written for, whichever alias it used"
    assert_file_contains "$REGISTRY" "function rowFor(key: string): string" \
        "a drop reuses the row the icon already holds instead of writing a second one"
    assert_file_contains "$REGISTRY" "const names = item ? root.keysOf(item) : [key];" \
        "and setting a state takes every name with it, so the lists cannot disagree about one icon"
}

test_an_icon_with_a_row_is_drawn_from_it_alone() {
    assert_file_contains "$REGISTRY" "readonly property var rowedKeys" \
        "the registry knows which icons the bar's entry list holds a place for"
    assert_file_contains "$REGISTRY" "root.boxedItems.filter" \
        "the panel's own list is worked out from the icons no row placed, so one icon cannot be drawn twice"
    assert_file_contains "$BOX" "BarPlacements.setPlacement(id, BarPlacements.trayZone" \
        "an icon dropped in the box gives up its row in the bar"
    assert_file_not_contains "$TRAY" "BarPlacements.trayZone" \
        "and the tray never hides one: an empty tray still has to take an icon back"
}

test_every_icon_is_placed_from_one_list() {
    assert_file_contains "$CONTENT" 'name: "trayicons"' "the bar has one panel for choosing what shows"
    assert_file_contains "$CONTENT" "sourceComponent: TrayIcons {" "drawn by the panel that holds the switch"
    assert_file_contains "$TRAY" 'root.popouts.currentName = "trayicons"' \
        "and the tray's own gesture opens it, rather than a page of settings"
    assert_file_contains "$PLACEMENTS" "readonly property var rows: {" \
        "one list names every icon with the place it is in"
    assert_file_contains "$PLACEMENTS" "function setShown(id: string, shown: bool): void" \
        "and one switch turns each of them on and off"
    assert_file_contains "$ICONS_PANEL" "StyledSwitch {" "the list is a switch per icon, not a row of places"
    assert_file_contains "$ICONS_PANEL" "BarPlacements.setShown(id, shown)" \
        "a switch writes whether the icon shows and nothing else"
    assert_file_not_contains "$ICONS_PANEL" 'qsTr("Off")' "there is no per-icon place to choose"
    assert_file_not_contains "$STATUS_PAGE" "lockStatus: qsTr(" \
        "the status icons are named once, by the map the panel reads too"
}

test_config_is_the_only_store() {
    assert_file_not_contains "$REGISTRY" "FileView" "tray settings live in config, not in a second file"
    assert_file_not_contains "$REGISTRY" "unseenTtl" "there is nothing to expire"
    assert_file_contains "$REGISTRY" "GlobalConfig.bar.tray.order" "the bar order is the saved order"
}

run_tests
