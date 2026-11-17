#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="$REPO_ROOT/shell/services/IdleInhibitor.qml"
LOGIC="$REPO_ROOT/shell/services/keepawake.js"
WIDGET="$REPO_ROOT/shell/modules/bar/components/KeepAwakeWidget.qml"
CARD="$REPO_ROOT/shell/modules/utilities/cards/IdleInhibit.qml"
MENU="$REPO_ROOT/shell/modules/bar/popouts/KeepAwakeMenu.qml"
EXPIRY="$REPO_ROOT/shell/modules/bar/popouts/KeepAwakeExpiry.qml"
POBOUTS="$REPO_ROOT/shell/modules/bar/popouts/Content.qml"

test_the_reload_scoped_store_is_not_used_for_it() {
    assert_file_not_contains "$SERVICE" 'reloadableId' \
        "the reload-scoped property store does not survive a restart of the service"
}

test_the_state_is_per_boot_rather_than_permanent() {
    assert_file_contains "$SERVICE" 'Paths.runtimeTemp("keepawake.json")' \
        "the file belongs in the runtime directory: a restart keeps it, a reboot and a new login do not"
}

test_the_only_way_in_writes_the_file() {
    assert_file_contains "$SERVICE" 'function setEnabled(value: bool): void' \
        "toggling has to go through one entry point, so it cannot skip the file"
    assert_file_contains "$SERVICE" 'readonly property bool enabled: root.state.mode !== root.modeOff' \
        "and the flag has to be read-only, so nothing can bypass it"

    # One write path is the invariant: a second `setText` would mean something learned
    # to write the file behind the setter's back.
    assert_eq "$(grep -c 'setText' "$SERVICE")" "1" "the file is written in exactly one place"
}

test_every_caller_uses_the_setter() {
    assert_file_not_contains "$WIDGET" 'IdleInhibitor.enabled = ' "the bar widget must not write the flag"
    assert_file_contains "$WIDGET" 'IdleInhibitor.setEnabled(' "the bar widget goes through the setter"
    assert_file_not_contains "$CARD" 'IdleInhibitor.enabled = ' "the utilities card must not write the flag"
    assert_file_contains "$CARD" 'IdleInhibitor.setEnabled(' "the utilities card goes through the setter"
}

test_restoring_cannot_masquerade_as_a_toggle() {
    assert_file_contains "$SERVICE" 'root.state = KeepAwake.restore(stored, Date.now())' \
        "reading the file replaces the whole value instead of assigning a flag"
    assert_file_contains "$SERVICE" 'onLoaded: root.restore(stateFile.text())' \
        "the file has to be read back on start"
}

test_a_broken_file_does_not_take_the_shell_with_it() {
    assert_file_contains "$SERVICE" 'Logger.log("[IdleInhibitor]' \
        "an unreadable file is reported (under debug logs) rather than swallowed"
    assert_file_contains "$LOGIC" 'isNaN(since.getTime())' \
        "an unparsable timestamp falls back to now instead of throwing"
}

test_the_inhibitor_and_the_ipc_surface_are_unchanged() {
    assert_file_contains "$SERVICE" 'enabled: root.enabled' \
        "the compositor inhibitor stays bound to the restored value"
    assert_file_contains "$SERVICE" 'target: "idleInhibitor"' "the IPC target is unchanged"
    assert_file_contains "$SERVICE" 'function isEnabled(): bool' "and still answers the same question"
}

test_a_restored_file_becomes_the_whole_state() {
    check_js "a saved file restores to a state the widget can use" \
        "$LOGIC" KeepAwake '
const K = KeepAwake;
const now = new Date("2024-01-01T12:00:00.000Z").getTime();
const later = now + 60000;
const earlier = now - 60000;

// A hold whose moment passed while the shell was down was never raised this boot.
assert.strictEqual(K.restore({ mode: "interval", until: earlier, since: "2024-01-01T11:00:00.000Z" }, now).mode, "off");
assert.strictEqual(K.restore({ mode: "until", until: earlier }, now).mode, "off");

const held = K.restore({ mode: "until", until: later, since: "2024-01-01T11:00:00.000Z" }, now);
assert.strictEqual(held.mode, "until");
assert.strictEqual(held.until, later);
assert.strictEqual(new Date(held.since).getTime(), new Date("2024-01-01T11:00:00.000Z").getTime());

// A file from before the modes existed only carried `enabled`.
assert.strictEqual(K.restore({ enabled: true }, now).mode, "indefinite");
assert.strictEqual(K.restore({ enabled: false }, now).mode, "off");
assert.strictEqual(K.restore({ mode: "nonsense" }, now).mode, "off");
assert.strictEqual(K.restore(null, now).mode, "off");

// Indefinite and off have nowhere to end, and a broken moment cannot invent one.
assert.strictEqual(K.restore({ mode: "indefinite", until: later }, now).until, 0);
assert.strictEqual(K.restore({ mode: "until", until: "soon" }, now).until, 0);

// A timestamp that cannot be read falls back to now rather than propagating a bad date.
assert.strictEqual(new Date(K.restore({ mode: "indefinite", since: "not a date" }, now).since).getTime(), now);
'
}

test_the_state_survives_a_round_trip() {
    check_js "what is written reads back as the same hold" \
        "$LOGIC" KeepAwake '
const K = KeepAwake;
const since = new Date("2024-01-01T00:00:00.000Z");
const saved = JSON.parse(K.serialize({ mode: "until", since: since, until: 5000 }));
assert.deepStrictEqual(saved, { mode: "until", since: "2024-01-01T00:00:00.000Z", until: 5000 });

const restored = K.restore(saved, 1000);
assert.strictEqual(restored.mode, "until");
assert.strictEqual(restored.until, 5000);
assert.strictEqual(new Date(restored.since).getTime(), since.getTime());
'
}

test_the_widget_opens_the_menu_rather_than_the_settings_card() {
    # A bar icon opens its menu through the one helper every icon uses, so the check is
    # that it asks for the menu by name rather than that it sets the popout itself.
    assert_file_contains "$WIDGET" 'openPopout("keepawakemenu")' \
        "the right click has to open the new menu"
    assert_file_contains "$POBOUTS" 'name: "keepawakemenu"' "the menu is a registered popout"
    assert_file_contains "$POBOUTS" 'sourceComponent: KeepAwakeMenu' "and is drawn by the menu itself"
    assert_file_contains "$POBOUTS" 'name: "keepawakeexpiry"' "the expiry picker is a popout too"
    assert_file_contains "$POBOUTS" 'sourceComponent: KeepAwakeExpiry' "drawn by the picker"
    assert_file_contains "$POBOUTS" 'name: "keepawakecontext"' "the settings card stays reachable from the menu"
}

test_the_menu_offers_every_mode_and_the_expiry() {
    assert_file_contains "$MENU" 'currentName = "keepawakeexpiry"' \
        "the third entry hands off to the expiry picker"
    # Every mode is set through the service, so none of them can write the file behind it.
    assert_file_contains "$MENU" 'IdleInhibitor.keepAwakeFor(' "the interval presets"
    assert_file_contains "$MENU" 'IdleInhibitor.setEnabled(' "the indefinite hold and off"
}

test_the_picker_hands_its_moment_to_the_service() {
    assert_file_contains "$EXPIRY" 'IdleInhibitor.keepAwakeUntil(root.pickedDate)' \
        "confirming hands the picked moment to the service"
    assert_file_contains "$EXPIRY" 'disabled: !root.valid' "a moment it refuses cannot be confirmed"
}

test_hovering_the_widget_does_nothing() {
    assert_file_not_contains "$WIDGET" 'showOnHover' \
        "hovering must not open anything; the widget answers left and right clicks only"
    assert_file_not_contains "$WIDGET" 'onEntered' "no hover behaviour is left behind"
}

run_tests