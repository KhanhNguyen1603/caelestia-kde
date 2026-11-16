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
    assert_file_contains "$SERVICE" 'root.state = {' \
        "reading the file replaces the whole value instead of assigning a flag"
    assert_file_contains "$SERVICE" 'onLoaded: root.restore(stateFile.text())' \
        "the file has to be read back on start"
}

test_a_broken_file_does_not_take_the_shell_with_it() {
    assert_file_contains "$SERVICE" 'Logger.log("[IdleInhibitor]' \
        "an unreadable file is reported (under debug logs) rather than swallowed"
    assert_file_contains "$SERVICE" 'isNaN(since.getTime())' \
        "an unparsable timestamp falls back to now instead of throwing"
}

test_the_inhibitor_and_the_ipc_surface_are_unchanged() {
    assert_file_contains "$SERVICE" 'enabled: root.enabled' \
        "the compositor inhibitor stays bound to the restored value"
    assert_file_contains "$SERVICE" 'target: "idleInhibitor"' "the IPC target is unchanged"
    assert_file_contains "$SERVICE" 'function isEnabled(): bool' "and still answers the same question"
}

test_a_restored_expiry_that_passed_is_not_raised_again() {
    check_js "a hold whose moment passed while the shell was down starts off" \
        "$LOGIC" KeepAwake '
const K = KeepAwake;
assert.strictEqual(K.restoredMode({ mode: "interval", until: 1000 }, 2000), "off");
assert.strictEqual(K.restoredMode({ mode: "until", until: 1000 }, 2000), "off");
assert.strictEqual(K.restoredMode({ mode: "interval", until: 3000 }, 2000), "interval");
assert.strictEqual(K.restoredMode({ mode: "until", until: 3000 }, 2000), "until");
'
}

test_an_indefinite_hold_has_no_moment_to_wait_for() {
    check_js "indefinite ignores a stale moment, and old files keep working" \
        "$LOGIC" KeepAwake '
const K = KeepAwake;
assert.strictEqual(K.restoredMode({ mode: "indefinite", until: 1000 }, 2000), "indefinite");
assert.strictEqual(K.restoredMode({ enabled: true }, 2000), "indefinite");
assert.strictEqual(K.restoredMode({ enabled: false }, 2000), "off");
assert.strictEqual(K.restoredMode({ mode: "nonsense" }, 2000), "off");
assert.strictEqual(K.restoredMode(null, 2000), "off");
assert.strictEqual(K.restoredUntil({ mode: "indefinite", until: 1000 }, "indefinite"), 0);
assert.strictEqual(K.restoredUntil({ mode: "interval", until: 3000 }, "interval"), 3000);
assert.strictEqual(K.restoredUntil({ mode: "until", until: "soon" }, "until"), 0);
'
}

test_the_state_survives_a_round_trip() {
    check_js "what is written reads back as the same hold" \
        "$LOGIC" KeepAwake '
const K = KeepAwake;
const saved = JSON.parse(K.serialize("until", "2024-01-01T00:00:00.000Z", 5000, false));
assert.deepStrictEqual(saved, { mode: "until", since: "2024-01-01T00:00:00.000Z", until: 5000, screenOn: false });
assert.strictEqual(K.restoredMode(saved, 1000), "until");
assert.strictEqual(K.restoredUntil(saved, "until"), 5000);
assert.strictEqual(K.restoredScreenOn(saved), false);
assert.strictEqual(K.restoredScreenOn({}), true);
'
}

test_the_widget_opens_the_menu_rather_than_the_settings_card() {
    assert_file_contains "$WIDGET" 'currentName = "keepawakemenu"' \
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
    assert_file_contains "$MENU" 'IdleInhibitor.keepAwakeFor(' "the interval presets go through the service"
    assert_file_contains "$MENU" 'IdleInhibitor.keepAwakeIndefinitely(' "so does the indefinite hold"
    assert_file_contains "$MENU" 'IdleInhibitor.setKeepScreenOn(' "and the screen toggle"
}

test_the_picker_refuses_a_moment_that_has_passed() {
    assert_file_contains "$EXPIRY" 'readonly property bool valid: root.pickedDate.getTime() > Date.now()' \
        "a moment in the past is not a hold"
    assert_file_contains "$EXPIRY" 'disabled: !root.valid' "so confirming it is unavailable"
    assert_file_contains "$EXPIRY" 'IdleInhibitor.keepAwakeUntil(root.pickedDate)' \
        "confirming hands the picked moment to the service"
}

test_the_screen_entry_cannot_be_ticked_while_the_hold_is_off() {
    # Off and "keep screen on" together is a contradiction: nothing keeps the display lit
    # when nothing is holding the machine awake.
    assert_file_contains "$MENU" 'checked: IdleInhibitor.enabled && IdleInhibitor.keepScreenOn' \
        "the tick has to require the hold"
    assert_file_contains "$MENU" 'enabled: IdleInhibitor.enabled' \
        "and the entry is unavailable without one"
}

test_hovering_the_widget_does_nothing() {
    assert_file_not_contains "$WIDGET" 'showOnHover' \
        "hovering must not open anything; the widget answers left and right clicks only"
    assert_file_not_contains "$WIDGET" 'onEntered' "no hover behaviour is left behind"
}

run_tests