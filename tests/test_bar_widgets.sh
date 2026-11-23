#!/usr/bin/env bash

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="$REPO_ROOT/shell/modules/bar/BarWidgets.qml"
BAR="$REPO_ROOT/shell/modules/bar/Bar.qml"
TRAY="$REPO_ROOT/shell/modules/bar/components/Tray.qml"
TRAY_ITEM="$REPO_ROOT/shell/modules/bar/components/TrayItem.qml"
UPDATE_INDICATOR="$REPO_ROOT/shell/modules/bar/components/UpdateIndicator.qml"
TRAY_OVERFLOW="$REPO_ROOT/shell/modules/bar/popouts/TrayOverflow.qml"
DELEGATE="$REPO_ROOT/shell/modules/bar/components/BarWidgetDelegate.qml"
PLACEMENT="$REPO_ROOT/shell/modules/bar/BarPlacements.qml"
PLACEMENT_JS="$REPO_ROOT/shell/services/trayplacement.js"
POPOUTS="$REPO_ROOT/shell/modules/bar/popouts/Content.qml"
STATUS_ICON="$REPO_ROOT/shell/modules/bar/components/StatusIcon.qml"
BAR_ICON="$REPO_ROOT/shell/modules/bar/components/BarIcon.qml"
KEEP_AWAKE="$REPO_ROOT/shell/modules/bar/components/KeepAwakeWidget.qml"
GESTURE="$REPO_ROOT/shell/modules/bar/components/TrayDragGesture.qml"
CONFIG="$REPO_ROOT/shell/plugin/src/Caelestia/Config/barconfig.hpp"
EDITOR="$REPO_ROOT/shell/modules/nexus/pages/panels/taskbar/BarComponents.qml"
APPMENU="$REPO_ROOT/shell/modules/bar/components/AppMenu.qml"
CONTENT_WINDOW="$REPO_ROOT/shell/modules/drawers/ContentWindow.qml"
INTERACTIONS="$REPO_ROOT/shell/modules/drawers/Interactions.qml"
VISIBILITIES="$REPO_ROOT/shell/services/Visibilities.qml"

registry_entries() {
    sed -nE 's/^ *\{ id: "([A-Za-z0-9_]+)", zone: "([a-z]+)" \},?$/\1 \2/p' "$REGISTRY"
}

test_peripheral_battery_joins_the_sidebar_at_its_live_width() {
    local popout
    popout="$(sed -n '/sourceComponent: PeripheralBattery {/,/^            }/p' "$POPOUTS")"
    assert_contains "$popout" 'width: _isSidebarOpen' "the horizontal sidebar selects the attached width"
    assert_contains "$popout" 'sidebarWidthFor(Tokens.sizes.sidebar.width) - root.framePadding' \
        "the battery frame should fit the current sidebar, including its padding"
    assert_contains "$popout" ': implicitWidth' "the standalone popout should fit its device labels"
    assert_file_contains "$REPO_ROOT/shell/modules/bar/popouts/PeripheralBattery.qml" 'wrapMode: Text.Wrap' \
        "a device name that exceeds the attached width should wrap"
}

registry_ids() {
    registry_entries | awk '{ print $1 }' | sort
}

schema_entries() {
    sed -nE 's/.*u"id"_s, u"([A-Za-z0-9_]+)"_s.*u"zone"_s, u"([a-z]+)"_s.*/\1 \2/p' "$CONFIG"
}

bar_choice_ids() {
    sed -nE 's/^ *roleValue: "([A-Za-z0-9_]+)"$/\1/p' "$DELEGATE" | sort
}

editor_ids() {
    sed -nE 's/^ *"([A-Za-z0-9_]+)": \{.*$/\1/p' "$EDITOR" | sort
}

assert_same_lines() {
    local what="$1" expected="$2" actual="$3"
    local only_expected only_actual
    only_expected="$(comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") | paste -sd' ' -)"
    only_actual="$(comm -13 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") | paste -sd' ' -)"

    if [[ -n "$only_expected" || -n "$only_actual" ]]; then
        fail "$what (missing: ${only_expected:-nothing}; unexpected: ${only_actual:-nothing})"
    fi
}

assert_matched_something() {
    local what="$1" found="$2"
    assert_ne "" "$found" "$what (the pattern matched nothing, so nothing was checked)"
}

test_the_registry_and_the_bar_draw_the_same_widgets() {
    local registry drawn
    # The status icons group is drawn as one widget per icon, so the chooser answers
    # to the kind its entries carry rather than to the group id itself. The tray's own
    # icons are rows of the same list now, drawn by the kind a tray row carries.
    registry="$(registry_ids | sed 's/^statusIcons$/statusIcon/' | sort)"
    drawn="$(bar_choice_ids | grep -v '^trayItem$')"

    assert_matched_something "no widgets are declared in BarWidgets.qml" "$registry"
    assert_matched_something "no widgets are drawn by Bar.qml" "$drawn"
    assert_same_lines "the bar's DelegateChooser and the registry disagree" "$registry" "$drawn"
}

test_the_registry_and_the_schema_defaults_agree() {
    local registry schema
    registry="$(registry_entries | sort)"
    schema="$(schema_entries | sort)"

    assert_matched_something "no widgets are declared in BarWidgets.qml" "$registry"
    assert_matched_something "no default entries are declared in barconfig.hpp" "$schema"
    assert_same_lines "bar.entries defaults and the registry disagree, id or zone" "$registry" "$schema"
}

test_the_editor_labels_every_registered_widget() {
    local registry editor
    registry="$(registry_ids)"
    editor="$(editor_ids)"

    assert_matched_something "the taskbar editor labels no widgets" "$editor"
    assert_same_lines "the taskbar editor's label table and the registry disagree" "$registry" "$editor"
}

test_resetting_the_layout_asks_the_schema_for_its_defaults() {
    assert_file_contains "$EDITOR" 'BarPlacements.resetToDefaults()' \
        "the reset button has to go back to the schema's own defaults"
    assert_file_not_contains "$EDITOR" '{ id: "dock", enabled: true, zone: "middle" }' \
        "and must not grow another copy of the default layout - that copy is how resetting lost media"
    assert_file_contains "$EDITOR" 'BarPlacements.declaredZone(id)' \
        "a widget dragged out of the bar keeps the zone it had, or it comes back on the left"
}

test_nothing_else_writes_the_entry_list_by_hand() {
    local file
    for file in \
        "$BAR" \
        "$EDITOR" \
        "$REPO_ROOT/shell/modules/bar/popouts/Updates.qml" \
        "$REPO_ROOT/shell/modules/nexus/pages/UpdatesPage.qml" \
        "$REPO_ROOT/shell/modules/nexus/pages/panels/taskbar/BarDock.qml" \
        "$REPO_ROOT/shell/modules/nexus/pages/panels/taskbar/BarGreeter.qml" \
        "$REPO_ROOT/shell/modules/nexus/pages/panels/taskbar/BarUpdates.qml"; do
        assert_file_not_contains "$file" 'bar.entries =' \
            "toggling a widget is BarWidgets' job, not a settings page's ($(basename "$file"))"
    done
}

test_the_right_zone_is_one_system_tray_plus_the_clock() {
    assert_file_contains "$BAR" 'BarWidgets.rightLayoutEntries({ entries: Config.bar.entries })' \
        "the bar should ask the registry for the unified right layout"
    assert_file_contains "$DELEGATE" 'widgetEntries: trayLoader.systemTray ? root.bar.systemTrayEntries : []' \
        "only the synthetic tray should own the right-zone widgets"
    assert_file_contains "$TRAY" 'property var widgetEntries: []' \
        "the tray needs somewhere to put the widgets it owns"
    assert_file_contains "$TRAY" 'delegate: root.widgetDelegate' \
        "the tray must draw those widgets with the bar's own delegate"
    assert_file_contains "$TRAY" 'function widgetAt(barItem' \
        "the bar must still be able to route hover and clicks to a nested widget"
    assert_file_contains "$STATUS_ICON" 'readonly property string iconId: BarWidgets.statusIconId(root.entryId)' \
        "one status icon per widget, named by the entry that carries it"
    assert_file_contains "$STATUS_ICON" 'tooltip: BarIconMeta.nameOf(root.iconId)' \
        "and its name comes from BarIconMeta, so the tooltip and the settings list cannot disagree"
    assert_file_not_contains "$STATUS_ICON" 'qsTr(' \
        "rather than a second copy of the names, which is where the two drifted apart"
    assert_file_contains "$REGISTRY" 'kind: "statusIcon"' \
        "the registry expands the status icons group into one entry per icon"
    assert_file_contains "$REGISTRY" 'const entries = root.zoneEntries(root.viewEntries(node), "right");' \
        "the readers expand the group, the writers keep to the configured entries"
}

test_the_tray_arrow_opens_a_hidden_icons_panel() {
    assert_file_contains "$TRAY" 'readonly property bool hasOverflow: (root.showTrayIcons && TrayRegistry.overflowCount > 0) || BarWidgets.overflowWidgets(GlobalConfig.bar).length > 0' \
        "the tray checks both overflow icons and overflow bar widgets"
    assert_file_contains "$TRAY" 'readonly property bool showArrow: root.hasOverflow' \
        "the chevron stays hidden when the overflow box is empty"
    assert_file_contains "$TRAY" 'function closeEmptyOverflow(): void' \
        "the overflow box closes when a drag ends or its last item leaves and it is empty"
    assert_file_contains "$TRAY" 'popouts.currentName = "trayOverflow"' \
        "clicking the arrow should open the overflow panel"
    assert_file_contains "$POPOUTS" 'name: "trayOverflow"' \
        "the popout registry needs an entry for the overflow panel"
    assert_file_contains "$TRAY_OVERFLOW" 'TrayRegistry.overflowItems' \
        "the panel should list the icons that are not on the bar"
    assert_file_contains "$TRAY_OVERFLOW" 'BarWidgets.overflowWidgets' \
        "the panel should also list bar widgets taken off the bar"
    assert_file_contains "$TRAY_OVERFLOW" 'function trayDrop(source: var, x: real, y: real): void' \
        "the panel has to resolve what a drag leaves in it"
    assert_file_contains "$TRAY_OVERFLOW" 'BarPlacements.setPlacement(id, BarPlacements.trayZone' \
        "dropping an icon in the box moves it off the bar"
    assert_file_contains "$TRAY" 'function trayDrop(source: var, x: real, y: real): void' \
        "the tray has to resolve what a drag leaves on it"
    assert_file_contains "$TRAY" 'BarPlacements.setPlacement(id, "bar"' \
        "dropping an icon on the icons puts it back on the bar"
    assert_file_not_contains "$TRAY" 'overChevron' \
        "a drop on the chevron is a drop on the tray, so a tray emptied into the box can still take one back"
    assert_file_contains "$TRAY" 'return root.nearTray(x, y)' \
        "and a drop half a bar away from an empty tray still belongs to it"
    assert_file_contains "$GESTURE" 'TrayDrag.begin(root.kind, root.key, root.widgetId, root.item.Window.window)' \
        "one gesture lifts whatever it is put on and says what it lifted"
    assert_file_contains "$GESTURE" 'TrayDrag.finish()' \
        "and letting go decides where it lands"
    assert_file_contains "$GESTURE" 'grabToImage(result => TrayDrag.setGhost' \
        "the gesture carries a snapshot of the item it lifted"
    assert_file_contains "$TRAY_ITEM" 'dragKind: "icon"' \
        "a tray icon lifts as an icon"
    assert_file_contains "$DELEGATE" 'readonly property string widgetId: id' \
        "a dragged widget should name the entry a drop hides"
    assert_file_contains "$BAR_ICON" 'widgetId: root.entryId' \
        "an icon lifts on its own, by the entry it is drawn from"
    assert_file_contains "$KEEP_AWAKE" 'BarIcon {' \
        "the coffee cup is the same icon the status icons are"
    assert_file_contains "$UPDATE_INDICATOR" 'BarIcon {' \
        "and so is the updates indicator"
    assert_file_contains "$TRAY" 'function followBox(): void {' \
        "the box is drawn from the chevron's place, so that place is read again when it moves"
    assert_file_contains "$TRAY" 'if (root.popouts && root.popouts.hasCurrent && root.popouts.currentName === "trayOverflow")' \
        "and only while the box is the popout that is open"
    assert_file_contains "$TRAY" 'onWidthChanged: root.followBox()' \
        "an icon leaving the tray makes the bar room for one fewer, and the box moves with the chevron"
    assert_file_contains "$TRAY" 'onXChanged: root.followBox()' \
        "which moves along the bar as well as shrinking"
    assert_file_contains "$DELEGATE" 'enabled: wrapper.draggable && !BarWidgets.dragsItself(wrapper.kind)' \
        "the wrapper stays out of the way of an icon that lifts itself"
    assert_file_not_contains "$UPDATE_INDICATOR" 'TrayDrag' \
        "the update indicator drags through its own icon, not on its own again"
    assert_file_contains "$PLACEMENT" 'root.setPlacement(id, shown ? Placement.BAR : Placement.OFF, shown ? { zone: Placement.BAR_ZONE } : undefined);' \
        "a switch that turns an icon on puts it on the bar, where it can be seen, and off takes it away"
    local writers
    writers="$(grep -rlE '\.entries = ' "$REPO_ROOT/shell" --include='*.qml' 2>/dev/null \
        | grep -v -E 'BarPlacements\.qml|Autostart\.qml|ContextMenuStore\.qml|ConfigMigrations\.qml' || true)"
    assert_eq "" "$writers" \
        "the placement writer owns the bar's entry list; the only other file that rewrites a saved one is the migration"
}

test_the_placement_model_says_where_an_icon_is() {
    if ! command -v node >/dev/null 2>&1; then
        skip_test "node is not available"
        return 0
    fi

    check_js "a row is the icon's place: off when it says so, in the box when its zone is the box's" "$PLACEMENT_JS" Placement '
assert.equal(Placement.placeOf({ id: "dock", enabled: false, zone: "middle" }, "bar"), "off");
assert.equal(Placement.placeOf({ id: "dock", enabled: true, zone: "tray" }, "bar"), "tray");
assert.equal(Placement.placeOf({ id: "dock", enabled: true, zone: "middle" }, "bar"), "bar");
assert.equal(Placement.placeOf(null, "bar"), "bar", "an icon without a row is where its list puts it");
assert.equal(Placement.placeOf(null, "off"), "off");
'

    check_js "the tray places its own icons until the bar holds a row for one" "$PLACEMENT_JS" Placement '
assert.equal(Placement.trayFallback("hidden", true), "off");
assert.equal(Placement.trayFallback("visible", true), "bar");
assert.equal(Placement.trayFallback("collapsed", true), "tray");
assert.equal(Placement.trayFallback("collapsed", false), "bar", "without compact mode there is no box to wait in");
'

    check_js "the icons list decides whether a status icon exists at all" "$PLACEMENT_JS" Placement '
assert.equal(Placement.statusPlace(false, { id: "statusIcon:battery", enabled: true, zone: "right" }, "bar"), "off");
assert.equal(Placement.statusPlace(true, { id: "statusIcon:battery", enabled: true, zone: "tray" }, "bar"), "tray");
assert.equal(Placement.statusPlace(true, null, "bar"), "bar");
'

    check_js "a widget switched off keeps the place it had, so switching it back on does not move it" "$PLACEMENT_JS" Placement '
const rows = [{ id: "tray", enabled: true, zone: "right" }, { id: "clock", enabled: true, zone: "right" }];
const off = Placement.plan({
    rows: rows,
    id: "clock",
    place: "off",
    kind: "widget",
    declaredZone: "right"
});
assert.deepEqual(off.rows, [{ id: "tray", enabled: true, zone: "right" }, { id: "clock", enabled: false, zone: "right" }]);
assert.equal(rows[1].enabled, true, "the list handed in is not written through");
'

    check_js "a widget dropped in the box is one row, in one write" "$PLACEMENT_JS" Placement '
const rows = [{ id: "tray", enabled: true, zone: "right" }, { id: "clock", enabled: true, zone: "right" }];
const boxed = Placement.plan({
    rows: rows,
    id: "clock",
    place: "tray",
    kind: "widget",
    declaredZone: "right"
});
assert.deepEqual(boxed.rows, [{ id: "tray", enabled: true, zone: "right" }, { id: "clock", enabled: true, zone: "tray" }],
    "shown again, in the box, in the place the row already held");
assert.equal(boxed.trayState, undefined, "a widget has no tray state to set");
'

    check_js "a drop takes the place of the icon it landed on, and gives that icon a row of its own" "$PLACEMENT_JS" Placement '
const widgets = [{ id: "tray", zone: "right" }, { id: "updateIndicator", zone: "right" }, { id: "clock", zone: "right" }];
const zones = { tray: "right", updateIndicator: "right", clock: "right" };
const dropped = Placement.plan({
    rows: [{ id: "tray", enabled: true, zone: "right" }, { id: "updateIndicator", enabled: false, zone: "tray" }, { id: "clock", enabled: true, zone: "right" }],
    id: "updateIndicator",
    place: "bar",
    zone: "right",
    beforeId: "clock",
    kind: "widget",
    declaredZone: "right",
    widgets: widgets,
    zones: zones,
    anchorOf: id => id === "tray" ? "tray" : ""
});
assert.deepEqual(dropped.rows.map(entry => entry.id), ["tray", "updateIndicator", "clock"], "in the place it was dropped");
assert.equal(dropped.rows[1].enabled, true, "switched on by the drag");
assert.equal(dropped.rows[1].zone, "right", "and drawn on the bar");
'

    check_js "a move onto the icon it is already in front of says the same thing the list already says" "$PLACEMENT_JS" Placement '
const rows = [{ id: "tray", enabled: true, zone: "right" }, { id: "clock", enabled: true, zone: "right" }];
const settled = Placement.plan({
    rows: rows,
    id: "tray",
    place: "bar",
    beforeId: "clock",
    kind: "widget",
    declaredZone: "right"
});
assert.equal(Placement.sameRows(settled.rows, rows), true, "so the writer has nothing to write");
const moved = Placement.plan({
    rows: rows,
    id: "clock",
    place: "bar",
    beforeId: "tray",
    kind: "widget",
    declaredZone: "right"
});
assert.deepEqual(moved.rows.map(entry => entry.id), ["clock", "tray"]);
assert.equal(Placement.sameRows(moved.rows, rows), false, "a move that changes the order is written");
'

    check_js "a status icon switched off is switched out of the icons list, and its row follows" "$PLACEMENT_JS" Placement '
const rows = [{ id: "statusIcon:battery", enabled: true, zone: "right" }];
const off = Placement.plan({
    rows: rows,
    id: "statusIcon:battery",
    place: "off",
    kind: "statusIcon",
    declaredZone: "right"
});
assert.equal(off.iconEnabled, false);
assert.equal(off.rows[0].enabled, false, "a row that said otherwise is the older answer");
const on = Placement.plan({
    rows: off.rows,
    id: "statusIcon:battery",
    place: "bar",
    kind: "statusIcon",
    declaredZone: "right"
});
assert.equal(on.iconEnabled, true);
assert.deepEqual(on.rows, [{ id: "statusIcon:battery", enabled: true, zone: "right" }], "and it holds the place it had");
'

    check_js "a status icon dropped in the box gets a row that says so" "$PLACEMENT_JS" Placement '
const boxed = Placement.plan({
    rows: [{ id: "tray", enabled: true, zone: "right" }, { id: "statusIcons", enabled: true, zone: "right" }],
    id: "statusIcon:battery",
    place: "tray",
    kind: "statusIcon",
    declaredZone: "right",
    widgets: [{ id: "tray" }, { id: "statusIcons" }],
    anchorOf: id => id.startsWith("statusIcon:") ? "statusIcons" : ""
});
assert.deepEqual(boxed.rows.map(entry => [entry.id, entry.zone]), [
    ["tray", "right"],
    ["statusIcon:battery", "tray"],
    ["statusIcons", "right"]
], "a row of its own, in front of the group it came out of");
assert.equal(boxed.iconEnabled, true, "still one of the icons the list draws");
'

    check_js "a status icon dropped back on the bar gives up its row, so its own place in the list returns" "$PLACEMENT_JS" Placement '
const onBar = Placement.plan({
    rows: [{ id: "tray", enabled: true, zone: "right" }, { id: "statusIcon:battery", enabled: true, zone: "tray" }],
    id: "statusIcon:battery",
    place: "bar",
    zone: "right",
    kind: "statusIcon",
    declaredZone: "right"
});
assert.deepEqual(onBar.rows.map(entry => entry.id), ["tray"]);
assert.equal(onBar.iconEnabled, true);
'

    check_js "a tray app is shown by its own state, and a row is only the place a drag gives it" "$PLACEMENT_JS" Placement '
const request = {
    kind: "trayItem",
    id: "tray:cachy-update",
    trayKey: "cachy-update",
    declaredZone: "right",
    compact: true
};
const off = Placement.plan(Object.assign({}, request, {
    rows: [{ id: "tray", enabled: true, zone: "right" }],
    place: "off"
}));
assert.equal(off.trayState, "hidden", "off is the tray being told to hide it");
assert.deepEqual(off.rows.map(entry => [entry.id, entry.enabled]), [["tray", true], ["tray:cachy-update", false]],
    "with a row that keeps it out of the bar and the box alike");

const shown = Placement.plan(Object.assign({}, request, {
    rows: [{ id: "tray", enabled: true, zone: "right" }, { id: "tray:cachy-update", enabled: false, zone: "right" }],
    place: "bar"
}));
assert.equal(shown.trayState, "visible");
assert.deepEqual(shown.rows.map(entry => [entry.id, entry.enabled]), [["tray", true], ["tray:cachy-update", true]],
    "shown again in the place the row held");

const boxed = Placement.plan(Object.assign({}, request, {
    rows: [{ id: "tray", enabled: true, zone: "right" }, { id: "tray:cachy-update", enabled: true, zone: "right" }],
    place: "tray"
}));
assert.equal(boxed.trayState, "collapsed", "compact mode waits in the box");
assert.deepEqual(boxed.rows.map(entry => entry.id), ["tray"], "and the row goes, so the state decides again");

const pinned = Placement.plan(Object.assign({}, request, {
    rows: [{ id: "tray", enabled: true, zone: "right" }, { id: "clock", enabled: true, zone: "right" }],
    place: "bar",
    beforeId: "clock"
}));
assert.deepEqual(pinned.rows.map(entry => entry.id), ["tray", "tray:cachy-update", "clock"],
    "dropped on an icon, it holds a row in front of it");
assert.equal(pinned.rows[1].zone, "right");
'

    check_js "a row for an icon the list does not hold goes beside the neighbours it is declared with" "$PLACEMENT_JS" Placement '
const widgets = [{ id: "tray" }, { id: "updateIndicator" }, { id: "clock" }, { id: "power" }];
assert.equal(Placement.insertIndex([{ id: "tray" }, { id: "clock" }], "updateIndicator", widgets), 1,
    "after the last row whose widget comes before it in the registry");
assert.equal(Placement.insertIndex([], "power", widgets), 0);
assert.equal(Placement.insertIndex([{ id: "tray" }], "statusIcon:battery", widgets, "statusIcons"), 1,
    "an icon from a group goes where the group is");
assert.equal(Placement.insertIndex([{ id: "clock" }], "tray:cachy-update", widgets, "tray"), 1);
'
}

test_a_tray_icon_is_a_bar_icon() {
    local icon="$REPO_ROOT/shell/modules/bar/components/BarIcon.qml"
    assert_file_matches "$TRAY_ITEM" '^BarIcon \{' \
        "a tray icon is the bar's own icon, not a second kind that only looks like one"
    assert_file_contains "$TRAY_ITEM" 'glyphComponent: Component {' \
        "the app supplies the glyph; the slot, the name, the drag and the buttons are the icon's"
    assert_file_contains "$TRAY_ITEM" 'dragKind: "icon"' \
        "and it says a drag of it carries a tray icon"
    assert_file_contains "$icon" 'signal middleActivated()' \
        "which is where the second action a tray app offers lives"
    assert_file_contains "$icon" 'onDropped: root.suppressClick = true' \
        "and the release that ends a drag is not read as a click on the icon"
    assert_file_contains "$icon" 'readonly property real iconScale: 1.2 * root.barScale' \
        "a bar made thinner shrinks its icons with it, instead of drawing them past its edge"
    assert_file_not_contains "$icon" 'scale: root.iconScale' \
        "the glyph is drawn at that size instead of being scaled into it, which would stretch a glyph rendered smaller"
    assert_file_contains "$TRAY_ITEM" 'Math.round(Tokens.font.icon.small.pointSize * 1.33 * root.iconScale)' \
        "and an app's bitmap is asked for at the size it is drawn at, so it is not upscaled"
    assert_file_contains "$STATUS_ICON" 'fontScale: root.iconScale' \
        "a glyph icon is asked for at that size too, rather than scaled up from its font size"
    for gone in 'StateLayer' 'QsMenuOpener' 'Tooltip' 'TrayDragGesture' 'ColouredIcon'; do
        if [[ "$gone" != 'QsMenuOpener' && "$gone" != 'ColouredIcon' ]]; then
            assert_file_not_contains "$TRAY_ITEM" "$gone {" \
                "the icon draws its own $gone, so the tray item must not draw a second one"
        fi
    done
}

test_the_hidden_icons_box_is_icons_only() {
    assert_file_not_contains "$TRAY_OVERFLOW" "qsTr(" \
        "the box holds tiles, not copy"
    assert_file_contains "$TRAY_OVERFLOW" 'BarComponents.BarWidgetCell' \
        "the widgets in the box are the bar's own, so they stay live there"
    assert_file_contains "$TRAY_OVERFLOW" 'readonly property int maxRows: 4' \
        "the box fills at most four rows"
    assert_file_contains "$TRAY_OVERFLOW" 'readonly property int columns: Math.max(root.minColumns, Math.ceil(Math.sqrt(root.filled)), Math.ceil(root.filled / root.maxRows))' \
        "the grid is the squarest shape its icons fit, and a column wider once four rows are full"
    assert_file_contains "$TRAY_OVERFLOW" 'readonly property int rows: Math.max(root.minRows, Math.ceil(root.filled / root.columns))' \
        "with no rows reserved beyond the icons themselves"
    assert_file_not_contains "$TRAY_OVERFLOW" 'root.filled === 0 ? 1 : 0' \
        "a box with nothing in it is only the room it keeps: a stand-in cell reads as something to press"
    assert_file_contains "$TRAY_OVERFLOW" 'BarComponents.StatusIcon' \
        "a status icon in the box is a cell the box sizes, not a widget that sizes itself"
    assert_file_not_contains "$TRAY_OVERFLOW" 'RowLayout' \
        "every entry is a cell of the one grid, with nothing on a line of its own"
    assert_file_contains "$TRAY_OVERFLOW" 'function trayDropAt(window: var, x: real, y: real): bool' \
        "anything the tray draws can be dropped into the box"
    assert_file_contains "$TRAY_OVERFLOW" 'BarComponents.BarWidgetCell' \
        "the box draws the widgets it holds with the bar's own delegate, so they stay live there"
    assert_file_not_contains "$BAR" 'trayWidgetDelegate' \
        "and the bar does not hand its popout state a component to do it with"
    assert_file_contains "$GESTURE" 'grabPermissions: PointerHandler.CanTakeOverFromAnything' \
        "a drag over a widget takes the gesture without stealing the click under it"
    assert_file_contains "$GESTURE" 'TrayDrag.move(root.screenPoint(centroid.scenePosition))' \
        "and reports where the pointer is on the screen, so the drop can be resolved"
}

test_a_move_lands_without_redrawing_the_row() {
    assert_file_not_contains "$TRAY" 'from: 0' \
        "one icon moving must not scale every icon in the tray in from nothing"
    assert_file_not_contains "$TRAY" 'properties: "scale"' \
        "the tray's icons keep their size: the row is rebuilt when the bar's list is written, not moved"
    assert_file_not_contains "$TRAY_OVERFLOW" 'from: 0' \
        "and the box's cells are not scaled in either"
    assert_file_contains "$TRAY" 'zone: beforeId || source.kind === "widget" ? "right" : undefined' \
        "a widget dropped on the bar is placed and moved in one write"
    assert_file_contains "$PLACEMENT" "function setPlacement(id: string, place: string, options: var): void" \
        "because placing and moving are one statement"
}

test_the_tray_is_as_wide_as_its_icons_right_away() {
    for axis in implicitWidth implicitHeight; do
        assert_file_not_contains "$TRAY" "Behavior on $axis" \
            "the surface takes the size its icons need at once, rather than springing after the bar has already reflowed"
    done
    assert_file_contains "$TRAY" 'readonly property real nonAnimWidth: {' \
        "the width is counted from the row the icons are in"
    assert_file_contains "$TRAY" 'implicitWidth: isHorizontal ? nonAnimWidth : barThickness' \
        "and it is that count the surface is drawn at"
}

test_the_box_is_the_size_its_cells_are() {
    assert_file_contains "$TRAY_OVERFLOW" 'implicitWidth: root.gridWidth' \
        "the box is as wide as its cells, so nothing a cell holds can stretch the panel"
    assert_file_contains "$TRAY_OVERFLOW" 'implicitHeight: root.gridHeight' \
        "and as tall"
    assert_file_not_contains "$TRAY_OVERFLOW" 'grid.implicitWidth' \
        "measuring the grid instead is what let one wide widget open the box halfway across the screen"
    assert_file_contains "$TRAY_OVERFLOW" 'readonly property int minColumns: 3' \
        "a box keeps room for a few icons before it holds any"
    assert_file_contains "$TRAY_OVERFLOW" 'readonly property int minRows: 2' \
        "in both directions, so one icon is not a hole the size of one icon"
    assert_file_contains "$TRAY_OVERFLOW" 'readonly property real gap: Tokens.spacing.small * root.scaleOffset' \
        "the cells are spaced to be read apart from each other"
    assert_file_contains "$TRAY_OVERFLOW" 'readonly property real popoutMargin: Tokens.padding.small' \
        "its frame is only the room the glyphs need"
    assert_file_contains "$TRAY_OVERFLOW" 'readonly property bool popoutOwnSurface: true' \
        "it says it draws its own surface, so the drawer puts nothing behind it"
    assert_file_contains "$TRAY_OVERFLOW" 'color: Qt.alpha(Colours.palette.m3surfaceContainer, 0.92)' \
        "and draws it from the opaque palette, since the transparent one barely shows over the desktop"
    local content_window="$REPO_ROOT/shell/modules/drawers/ContentWindow.qml"
    assert_file_contains "$content_window" 'readonly property bool ownsSurface: panels.popouts.currentOwnsSurface' \
        "the box is the one popout that opens without a panel behind it"
    assert_file_contains "$content_window" 'group: popoutBg.shown ? blobGroup : null' \
        "and is kept out of the blob the panels are merged into, which draws its shape whatever the plate does"
    assert_file_contains "$content_window" 'visible: popoutBg.shown' \
        "so the shared popout plate stays down for it"
    assert_file_contains "$content_window" 'target: popoutBg.ownsSurface ? null : panels.popoutsWrapper' \
        "and nothing is blurred where that plate would have been, which showed as the box split across its middle"
    local wrapper="$REPO_ROOT/shell/modules/bar/popouts/Wrapper.qml"
    assert_file_contains "$wrapper" 'readonly property bool currentOwnsSurface: (content.item as Content)?.currentOwnsSurface ?? false' \
        "a popout's own answer about its surface reaches the drawer"
    assert_file_contains "$TRAY_OVERFLOW" 'anchors.centerIn: parent
                    visible: !widgetCell.isIcon' \
        "a widget in a cell is centred in it"
    assert_file_contains "$TRAY_OVERFLOW" 'scale: fit' \
        "and a widget too wide for the cell is fitted into it rather than left to overflow"
}

test_the_chevron_sits_outside_the_icons_surface() {
    assert_file_contains "$TRAY" 'id: surface' \
        "the icons share one surface, and the chevron is not in it"
    assert_file_contains "$TRAY" 'x: root.isHorizontal ? root.arrowSize + root.arrowGap : 0' \
        "the surface starts after the chevron instead of containing it"
    assert_file_contains "$TRAY" 'return arrowSize + arrowGap + layout.implicitWidth + padding * 2' \
        "and the tray is as wide as both"
    assert_file_contains "$TRAY" 'if (TrayDrag.active)' \
        "the box is open for the whole drag, so the icon has somewhere to land"
}

test_appmenu_and_pinned_popouts_stay_open_until_dismissed() {
    assert_file_contains "$APPMENU" 'popouts.staysOpen = true;' \
        "appmenu sets staysOpen so pointer exit does not close it"
    assert_file_contains "$BAR" 'if (popouts.staysOpen && popouts.hasCurrent)' \
        "bar hover routing must not swap out a pinned popout"
    assert_file_contains "$INTERACTIONS" 'if (popouts.staysOpen)' \
        "the auto-hide timer must not dismiss a pinned popout"
    assert_file_contains "$CONTENT_WINDOW" '(panels.popouts.staysOpen && panels.popouts.hasCurrent)' \
        "pinned popouts must be recognized as transient overlays so the input mask covers the screen"
    assert_file_contains "$VISIBILITIES" 'bar?.popouts?.staysOpen && bar?.popouts?.hasCurrent' \
        "visibilities must broadcast pinned popout presence across all screens for dismissal"
    assert_file_contains "$INTERACTIONS" 'const boxOpen = popouts.staysOpen && popouts.hasCurrent;' \
        "interactions must track pinned popouts as dismissible boxes on outside click"
}

run_tests
