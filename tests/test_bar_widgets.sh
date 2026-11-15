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
POPOUTS="$REPO_ROOT/shell/modules/bar/popouts/Content.qml"
STATUS_ICON="$REPO_ROOT/shell/modules/bar/components/StatusIcon.qml"
CONFIG="$REPO_ROOT/shell/plugin/src/Caelestia/Config/barconfig.hpp"
EDITOR="$REPO_ROOT/shell/modules/nexus/pages/panels/taskbar/BarComponents.qml"

registry_entries() {
    sed -nE 's/^ *\{ id: "([A-Za-z0-9_]+)", zone: "([a-z]+)" \},?$/\1 \2/p' "$REGISTRY"
}

registry_ids() {
    registry_entries | awk '{ print $1 }' | sort
}

schema_entries() {
    sed -nE 's/.*u"id"_s, u"([A-Za-z0-9_]+)"_s.*u"zone"_s, u"([a-z]+)"_s.*/\1 \2/p' "$CONFIG"
}

bar_choice_ids() {
    sed -nE 's/^ *roleValue: "([A-Za-z0-9_]+)"$/\1/p' "$BAR" | sort
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
    # to the kind its entries carry rather than to the group id itself.
    registry="$(registry_ids | sed 's/^statusIcons$/statusIcon/' | sort)"
    drawn="$(bar_choice_ids)"

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
    assert_file_contains "$EDITOR" 'BarWidgets.resetToDefaults(GlobalConfig.bar)' \
        "the reset button has to go back to the schema's own defaults"
    assert_file_not_contains "$EDITOR" '{ id: "dock", enabled: true, zone: "middle" }' \
        "and must not grow another copy of the default layout - that copy is how resetting lost media"
    assert_file_contains "$EDITOR" 'BarWidgets.zoneFor(Config.bar, id)' \
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
    assert_file_contains "$BAR" 'widgetEntries: trayLoader.systemTray ? root.systemTrayEntries : []' \
        "only the synthetic tray should own the right-zone widgets"
    assert_file_contains "$TRAY" 'property var widgetEntries: []' \
        "the tray needs somewhere to put the widgets it owns"
    assert_file_contains "$TRAY" 'delegate: root.widgetDelegate' \
        "the tray must draw those widgets with the bar's own delegate"
    assert_file_contains "$TRAY" 'function widgetAt(barItem' \
        "the bar must still be able to route hover and clicks to a nested widget"
    assert_file_contains "$STATUS_ICON" 'readonly property string iconId: BarWidgets.statusIconId(root.entryId)' \
        "one status icon per widget, named by the entry that carries it"
    assert_file_contains "$REGISTRY" 'kind: "statusIcon"' \
        "the registry expands the status icons group into one entry per icon"
    assert_file_contains "$REGISTRY" 'const entries = root.zoneEntries(root.viewEntries(node), "right");' \
        "the readers expand the group, the writers keep to the configured entries"
}

test_the_tray_arrow_opens_a_hidden_icons_panel() {
    assert_file_contains "$TRAY" 'readonly property bool showArrow: root.showTrayIcons' \
        "the chevron is on the bar for as long as the tray is"
    assert_file_contains "$TRAY" 'popouts.currentName = "trayOverflow"' \
        "clicking the arrow should open the overflow panel"
    assert_file_contains "$POPOUTS" 'name: "trayOverflow"' \
        "the popout registry needs an entry for the overflow panel"
    assert_file_contains "$TRAY_OVERFLOW" 'TrayRegistry.overflowItems' \
        "the panel should list the icons that are not on the bar"
    assert_file_contains "$TRAY_OVERFLOW" 'BarWidgets.overflowWidgets' \
        "the panel should also list bar widgets taken off the bar"
    assert_file_contains "$TRAY_OVERFLOW" 'function trayDrop(source: var): void' \
        "the panel has to resolve what a drag leaves in it"
    assert_file_contains "$TRAY_OVERFLOW" 'TrayRegistry.sendToBox(source.key)' \
        "dropping an icon in the box moves it off the bar"
    assert_file_contains "$TRAY" 'function trayDrop(source: var): void' \
        "the tray has to resolve what a drag leaves on it"
    assert_file_contains "$TRAY" 'TrayRegistry.sendToBar(source.key)' \
        "dropping an icon on the icons puts it back on the bar"
    assert_file_contains "$TRAY_ITEM" 'TrayDrag.begin("icon"' \
        "tray icons lift out of the bar and report where the pointer is"
    assert_file_contains "$TRAY_ITEM" 'TrayDrag.finish()' \
        "and letting go decides where it lands"
    assert_file_contains "$TRAY_ITEM" 'root.grabToImage(result => TrayDrag.setGhost' \
        "the gesture carries a snapshot of the icon it lifted"
    assert_file_contains "$BAR" 'TrayDrag.begin("widget"' \
        "bar widgets need to be draggable into the same panel"
    assert_file_contains "$BAR" 'readonly property string widgetId: id' \
        "a dragged widget should name the entry a drop hides"
    assert_file_not_contains "$UPDATE_INDICATOR" 'TrayDrag' \
        "the update indicator drags through its bar wrapper, not on its own"
}

test_the_toggle_helper_keeps_the_widget_list_well_formed() {
    if ! command -v node >/dev/null 2>&1; then
        skip_test "node is not available"
        return 0
    fi

    local harness
    harness="$(mktemp "${TMPDIR:-/tmp}/caelestia-barwidgets.XXXXXX.mjs")"
    cat > "$harness" <<'EOF'
import { readFileSync } from "node:fs";

const src = readFileSync(process.argv[2], "utf8");

function sliceBalanced(from, open, close) {
    let depth = 0;
    for (let i = from; i < src.length; i++) {
        if (src[i] === open) depth++;
        else if (src[i] === close && --depth === 0) return src.slice(from, i + 1);
    }
    throw new Error("unbalanced " + open);
}

function stripTypes(header) {
    return header
        .replace(/\)\s*:\s*[A-Za-z_][\w<>.\[\]|]*\s*$/, ") ")
        .replace(/([(,\s])([A-Za-z_]\w*)\s*:\s*[A-Za-z_][\w<>.\[\]|]*/g, "$1$2");
}

function extractFunction(name) {
    const marker = "function " + name + "(";
    const start = src.indexOf(marker);
    if (start === -1) throw new Error(name + " not found");
    const text = sliceBalanced(start, "{", "}");
    const brace = text.indexOf("{");
    return stripTypes(text.slice(0, brace)) + text.slice(brace);
}

function extractArray(name) {
    const marker = name + ": [";
    const start = src.indexOf(marker);
    if (start === -1) throw new Error(name + " not found");
    return sliceBalanced(src.indexOf("[", start), "[", "]");
}

const widgets = new Function("return " + extractArray("widgets") + ";")();
const root = { widgets };
root.byId = (() => {
    const byId = {};
    root.widgets.forEach((widget, index) => byId[widget.id] = Object.assign({ index: index }, widget));
    return byId;
})();
root.ids = root.widgets.map(widget => widget.id);
root.overflowZone = "tray";
root.statusIconPrefix = "statusIcon:";

// The status icons come from the config and ask the services what they have to
// say, so both are stood up here.
globalThis.Config = {
    bar: {
        status: { showWifi: true },
        statusIcons: {
            values: [
                { id: "audio", enabled: true },
                { id: "battery", enabled: true },
                { id: "privacy", enabled: true },
                { id: "nightlight", enabled: false }
            ]
        }
    }
};
globalThis.Kwin = { capsLock: false, numLock: false, kbLayout: "" };
globalThis.Privacy = { inUse: false };
globalThis.Nmcli = { activeEthernet: false };
globalThis.HyprSunset = { active: false };

const names = ["widget", "isKnown", "entriesOf", "zoneEntries", "normalizedEntries", "normalizedZoneEntries", "rightLayoutEntries", "systemTrayEntries", "systemTrayShowsIcons", "overflowWidgets", "isEnabled", "zoneFor", "setEnabled", "setZone", "setInTray", "setOnBar", "replaceAll", "indexFor", "statusIconId", "statusIconActive", "statusIconEntries", "viewEntries"];
Object.assign(root, new Function("root", names.map(extractFunction).join("\n") + "\nreturn {" + names.join(", ") + "};")(root));

const eq = (actual, expected, msg) => {
    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
        console.error("FAIL:", msg);
        console.error("  actual:  ", JSON.stringify(actual));
        console.error("  expected:", JSON.stringify(expected));
        process.exit(1);
    }
};

const defaults = [
    { id: "logo", enabled: true, zone: "left" },
    { id: "workspaces", enabled: true, zone: "left" },
    { id: "greeter", enabled: true, zone: "left" },
    { id: "dock", enabled: true, zone: "middle" },
    { id: "tray", enabled: true, zone: "right" },
    { id: "updateIndicator", enabled: true, zone: "right" },
    { id: "github", enabled: false, zone: "right" },
    { id: "media", enabled: false, zone: "right" },
    { id: "clock", enabled: true, zone: "right" },
    { id: "power", enabled: true, zone: "right" }
];
const ids = entries => entries.map(entry => entry.id);

eq(ids(root.zoneEntries(defaults, "left")), ["logo", "workspaces", "greeter"], "left zone");
eq(ids(root.zoneEntries(defaults, "middle")), ["dock"], "middle zone");
eq(ids(root.zoneEntries(defaults, "right")), ["tray", "updateIndicator", "clock", "power"], "the right zone drops the disabled widgets");
eq(ids(root.rightLayoutEntries({ entries: defaults })), ["tray", "power", "clock"], "the right layout is one tray, the power button and the clock");
eq(root.rightLayoutEntries({ entries: defaults })[0].systemTray, true, "the synthetic tray is marked as the tray container");
eq(root.systemTrayEntries({ entries: defaults }).every(entry => entry.systemTray === false && entry.zone === "right"), true,
    "the widgets inside the tray carry the roles the bar delegate requires");
eq(ids(root.systemTrayEntries({ entries: defaults })), ["updateIndicator"], "the tray owns the right widgets but not the power button or the clock");
eq(root.systemTrayShowsIcons({ entries: defaults }), true, "the tray entry supplies the system tray icons");
eq(ids(root.rightLayoutEntries({ entries: defaults.filter(entry => entry.id === "clock") })), ["clock"],
    "a clock on its own stays outside a tray");
eq(ids(root.rightLayoutEntries({ entries: defaults.filter(entry => entry.id !== "clock") })), ["tray", "power"],
    "the tray and the power button remain when the clock is not in the right zone");
eq(root.systemTrayShowsIcons({ entries: defaults.filter(entry => entry.id !== "tray") }), false,
    "disabling the tray entry leaves the widget tray without system tray icons");
eq(ids(root.systemTrayEntries({ entries: defaults.filter(entry => entry.id !== "tray") })), ["updateIndicator"],
    "the other right widgets still belong to the tray when the tray entry is off");
eq(root.overflowWidgets({ entries: defaults }), [], "nothing is in the box while every right-zone widget is on the bar");
eq(root.overflowWidgets({ entries: [{ id: "updateIndicator", enabled: true, zone: "tray" }, { id: "clock", enabled: true, zone: "right" }] }).map(entry => entry.id), ["updateIndicator"],
    "a widget dragged into the box is the one the box draws");
eq(root.overflowWidgets({ entries: [{ id: "updateIndicator", enabled: true, zone: "tray" }] })[0].enabled, true,
    "the box draws it live, so the delegate must activate it");
eq(root.overflowWidgets({ entries: [{ id: "updateIndicator", enabled: true, zone: "tray" }] })[0].draggable, true,
    "and it can be dragged back out");
eq(root.overflowWidgets({ entries: [{ id: "nonsense", enabled: true, zone: "tray" }] }), [],
    "an id no widget answers to never reaches the box");
eq(root.systemTrayEntries({ entries: defaults }).every(entry => entry.draggable === true), true,
    "everything the tray draws can be dragged into the box");
eq(ids(root.zoneEntries([{ id: "clock", enabled: true, zone: "tray" }], "right")), [],
    "a widget in the box is drawn by no zone");
eq(ids(root.zoneEntries([{ id: "clock", enabled: true }], "left")), ["clock"], "an entry with no zone is a left one, which is what the bar always assumed");

eq(ids(root.zoneEntries([
    { id: "spacer", enabled: true, zone: "left" },
    { id: "nonsense", enabled: true, zone: "left" },
    { id: "clock", enabled: true, zone: "left" }
], "left")), ["clock"], "spacer and unknown ids never reach the bar");
eq(root.isKnown("media"), true, "media is a widget");
eq(root.isKnown("spacer"), false, "spacer is not");

eq(root.isEnabled({ entries: defaults }, "dock"), true, "dock is on");
eq(root.isEnabled({ entries: defaults }, "github"), false, "github is off");
eq(root.isEnabled({ entries: defaults }, "perfCpu"), false, "a widget with no entry is off");
eq(root.isEnabled({}, "dock"), false, "an empty list reads as off");

eq(root.zoneFor({ entries: defaults }, "dock"), "middle", "an entry's own zone wins");
eq(root.zoneFor({}, "dock"), "middle", "and a widget with no entry keeps the zone it was declared with");
eq(root.zoneFor({}, "nonsense"), "left", "an id the registry does not know still lands somewhere");

const toggled = { entries: defaults.map(entry => Object.assign({}, entry)) };
const handedOver = toggled.entries;
root.setEnabled(toggled, "github", true);
eq(ids(toggled.entries), ["logo", "workspaces", "greeter", "dock", "tray", "updateIndicator", "github", "media", "clock", "power"],
    "an existing widget keeps its place");
eq(root.isEnabled(toggled, "github"), true, "and turns on");
eq(handedOver[6].enabled, false, "without writing through the entry objects the old list handed over");

const restored = { entries: defaults.filter(entry => entry.id !== "updateIndicator") };
root.setEnabled(restored, "updateIndicator", true);
eq(ids(restored.entries).indexOf("updateIndicator"), ids(restored.entries).indexOf("tray") + 1,
    "a widget missing from the list goes back beside the neighbours it was declared with");
eq(restored.entries.find(entry => entry.id === "updateIndicator").zone, "right", "with its declared zone");

const empty = {};
root.setEnabled(empty, "dock", true);
eq(empty.entries, [{ id: "dock", enabled: true, zone: "middle" }], "and into an empty list the registry supplies the zone");

const source = [{ id: "clock", enabled: true, zone: "right" }];
const editor = {};
root.replaceAll(editor, source);
source.push({ id: "dock", enabled: true, zone: "middle" });
eq(ids(editor.entries), ["clock"], "the editor's list is snapshotted, not aliased");

const moved = { entries: defaults.map(entry => Object.assign({}, entry)) };
root.setInTray(moved, "updateIndicator");
eq(moved.entries.find(entry => entry.id === "updateIndicator").zone, "tray",
    "dropping a widget in the box is what moves it out of the bar's zones");
eq(root.isEnabled(moved, "updateIndicator"), true, "and it keeps its own on/off state");
eq(ids(root.zoneEntries(moved.entries, "right")), ["tray", "clock", "power"],
    "so the tray no longer draws it");

root.setOnBar(moved, "updateIndicator");
eq(moved.entries.find(entry => entry.id === "updateIndicator").zone, "right",
    "dragging it back puts it in the tray's zone again");
eq(root.isEnabled(moved, "updateIndicator"), true, "switched on, because the drag asked to see it");
eq(ids(root.systemTrayEntries(moved)), ["updateIndicator"], "and the tray draws it again");

const woken = { entries: [{ id: "updateIndicator", enabled: false, zone: "tray" }] };
root.setOnBar(woken, "updateIndicator");
eq(root.isEnabled(woken, "updateIndicator"), true, "a widget dragged back is shown even if it had been switched off");

// The status icons are one widget each, so they move one at a time.
// A privacy indicator only exists while something is watching or listening.
globalThis.Privacy.inUse = true;
const groups = [
    { id: "tray", enabled: true, zone: "right" },
    { id: "statusIcons", enabled: true, zone: "right" },
    { id: "clock", enabled: true, zone: "right" }
];
eq(ids(root.viewEntries({ entries: groups })), ["tray", "statusIcon:audio", "statusIcon:battery", "statusIcon:privacy", "clock"],
    "the group is expanded in place: one entry per icon, in the configured order, with the switched-off one left out");
eq(root.viewEntries({ entries: groups }).filter(entry => entry.kind === "statusIcon").every(entry => entry.draggable === true), true,
    "and each icon is draggable on its own");
eq(ids(root.systemTrayEntries({ entries: groups })), ["statusIcon:audio", "statusIcon:battery", "statusIcon:privacy"],
    "the tray draws each icon separately, so each can be lifted off the bar");
eq(root.rightLayoutEntries({ entries: groups }).length, 2, "one tray and one clock: the icons are drawn inside the tray");

globalThis.Privacy.inUse = false;
eq(root.statusIconActive("privacy"), false, "an icon that has nothing to say is not drawn");
eq(ids(root.viewEntries({ entries: groups })), ["tray", "statusIcon:audio", "statusIcon:battery", "clock"],
    "so the row it would have taken closes up");
globalThis.Privacy.inUse = true;

const movedIcon = { entries: groups.map(entry => Object.assign({}, entry)) };
root.setInTray(movedIcon, "statusIcon:battery");
eq(movedIcon.entries.find(entry => entry.id === "statusIcon:battery").zone, "tray",
    "dropping one icon in the box moves that icon and only that icon");
eq(ids(root.viewEntries(movedIcon)).filter(id => id === "statusIcon:battery"), ["statusIcon:battery"],
    "the expansion reads the override, so the icon is still drawn once");
eq(ids(root.zoneEntries(root.viewEntries(movedIcon), "right")), ["tray", "statusIcon:audio", "statusIcon:privacy", "clock"],
    "and the bar no longer draws it");
eq(root.overflowWidgets(movedIcon).map(entry => entry.id), ["statusIcon:battery"],
    "the box is where it went");
eq(root.zoneFor(movedIcon, "statusIcon:battery"), "tray", "the registry knows the zone an icon was dragged to");
eq(ids(movedIcon.entries), ["tray", "statusIcons", "clock", "statusIcon:battery"],
    "the drag writes one row for that icon and leaves the configured group where it was");

root.setOnBar(movedIcon, "statusIcon:battery");
eq(root.zoneFor(movedIcon, "statusIcon:battery"), "right", "dragging it back returns it to the tray");
eq(ids(root.systemTrayEntries(movedIcon)), ["statusIcon:audio", "statusIcon:battery", "statusIcon:privacy"],
    "in the place the configured order gives it");

const orphan = { entries: [{ id: "statusIcon:audio", enabled: true, zone: "tray" }] };
eq(ids(root.viewEntries(orphan)), ["statusIcon:audio", "statusIcon:battery", "statusIcon:privacy"],
    "icon rows outlive the group row: the icons it left behind still belong to the bar");

console.log("bar widget registry: all harness cases passed");
EOF

    if ! timeout 15 node "$harness" "$REGISTRY"; then
        rm -f "$harness"
        fail "the bar widget registry harness failed"
        return 0
    fi
    rm -f "$harness"
}

test_the_hidden_icons_box_is_icons_only() {
    assert_file_not_contains "$TRAY_OVERFLOW" "qsTr(" \
        "the box holds tiles, not copy"
    assert_file_contains "$TRAY_OVERFLOW" 'delegate: root.popouts.trayWidgetDelegate' \
        "the widgets in the box are the bar's own, so they stay live there"
    assert_file_contains "$TRAY_OVERFLOW" 'function trayDropAt(window: var, x: real, y: real): bool' \
        "anything the tray draws can be dropped into the box"
    assert_file_contains "$BAR" 'property: "trayWidgetDelegate"' \
        "the bar is what hands that delegate over"
    assert_file_contains "$BAR" 'grabPermissions: PointerHandler.CanTakeOverFromAnything' \
        "a drag over a widget takes the gesture without stealing the click under it"
    assert_file_contains "$BAR" 'TrayDrag.move(centroid.scenePosition)' \
        "and reports where the pointer is so the drop can be resolved"
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

run_tests
