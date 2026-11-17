#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMERS="$REPO_ROOT/shell/services/Timers.qml"
CARD="$REPO_ROOT/shell/modules/utilities/cards/TimersCard.qml"
CONTENT="$REPO_ROOT/shell/modules/utilities/Content.qml"
SCHEMA="$REPO_ROOT/shell/plugin/src/Caelestia/Config/utilitiesconfig.hpp"
PANEL_PAGE="$REPO_ROOT/shell/modules/nexus/pages/utilities/UtilitiesPanelPage.qml"
SERVICES_PAGE="$REPO_ROOT/shell/modules/nexus/pages/ServicesPage.qml"
LOADER="$REPO_ROOT/shell/modules/ServiceLoader.qml"
AI="$REPO_ROOT/shell/modules/sidebar/AiAssistant.qml"
DURATION_JS="$REPO_ROOT/shell/services/duration.js"
RULES_JS="$REPO_ROOT/shell/services/timers.js"
AUDIO="$REPO_ROOT/shell/services/Audio.qml"
CONFIG_HPP="$REPO_ROOT/shell/plugin/src/Caelestia/Config/serviceconfig.hpp"

# A timer is a deadline, not a countdown: storing what is left means a restart two
# minutes into a 25 minute timer silently loses the other 23. The rules are pure, so this
# is executed rather than grepped.
check_rules() { check_js "$1" "$RULES_JS" TimerList "$2"; }

test_a_timer_is_stored_as_the_moment_it_ends() {
    check_rules "a timer must remember when it ends, not how long it has left" '
const started = TimerList.apply([], { type: "start", id: "a", seconds: 1500, message: "bread" }, 1000);
assert.strictEqual(started.list[0].ends, 1000 + 1500000, "the deadline is the start plus the request");
assert.strictEqual(TimerList.remaining(started.list[0], 1000 + 1200000), 300, "so ten minutes in it still has twenty");
assert.strictEqual(TimerList.remaining(started.list[0], 1000), 1500, "and the whole of it at the start");
'

    assert_file_contains "$TIMERS" 'ends: timer.ends' "the deadline is what is written to disk"
    assert_file_contains "$TIMERS" 'path: `${Paths.state}/timers.json`' "beside the other state the shell keeps"
    assert_file_contains "$TIMERS" 'const ended = data.filter(timer => timer.state === "running" && timer.ends <= Date.now())' \
        "and a timer whose end has passed is not brought back"
}

test_a_transition_leaves_the_list_it_was_given_alone() {
    # The elements of a `list<var>` are views of the sequence, so a view holding the old
    # list must not see the new contents. Reducers make that testable without a shell.
    check_rules "every transition has to return new records" '
const before = [{ id: "a", state: "running", ends: 61000, total: 60, paused: null, rangAt: 0, message: "x" }];
const after = TimerList.apply(before, { type: "pause", ids: ["a"] }, 31000).list;
assert.notStrictEqual(after, before, "the list itself is a new array");
assert.notStrictEqual(after[0], before[0], "and so is the record that changed");
assert.strictEqual(before[0].state, "running", "so a view still holding the old list reads the old state");
assert.strictEqual(after[0].state, "paused", "while the new one carries the transition");
'
    assert_file_contains "$TIMERS" 'property var list: []' "the service keeps a plain array of plain records"
}

test_timers_that_ran_out_while_the_shell_was_down_are_reported_once() {
    assert_file_contains "$TIMERS" 'if (ended.length === 1)' "one timer, one message"
    assert_file_contains "$TIMERS" 'timers finished while the shell was not running' \
        "and several timers are counted, not replayed"
}

test_a_timer_ends_as_a_notification() {
    assert_file_contains "$TIMERS" 'Notifs.addShellNotification({' \
        "the completion goes through the shell's own notifications, so it respects DND and lands in the list"
    assert_file_contains "$TIMERS" 'materialIcon: "timer"' "with a timer icon"
}

test_only_a_running_timer_comes_due_once() {
    check_rules "the tick asks one question, and each timer answers it once" '
const now = 1000000;
const running = { id: "r", state: "running", ends: now + 600000, total: 600, paused: null, rangAt: 0 };
const due = { id: "d", state: "running", ends: now - 1, total: 600, paused: null, rangAt: 0 };
const paused = { id: "p", state: "paused", ends: now - 60000, total: 600, paused: 300, rangAt: 0 };

const sweep = TimerList.apply([running, due, paused], { type: "sweep" }, now);
assert.deepStrictEqual(sweep.events.map(e => e.timer.id), ["d"], "only the timer that ran out is announced");
assert.strictEqual(sweep.events[0].type, "rang", "as a completion the shell can act on");
assert.strictEqual(sweep.list.find(t => t.id === "d").state, "rang", "and it keeps its place, ringing");
assert.strictEqual(sweep.list.find(t => t.id === "r").state, "running", "the others are untouched");
assert.strictEqual(sweep.list.find(t => t.id === "p").state, "paused", "a paused timer waits however far its deadline has passed");

const again = TimerList.apply(sweep.list, { type: "sweep" }, now + 1000);
assert.strictEqual(again.events.length, 0, "a timer that already rang is not announced twice");
assert.strictEqual(again.list.length, 3, "and stays in the list until it is dismissed");
'
}

test_a_paused_timer_waits_where_it_was_stopped() {
    check_rules "pausing has to stop the clock, not just the display" '
const timer = { id: "a", state: "running", ends: 61000, total: 60, paused: null, rangAt: 0 };
const paused = TimerList.apply([timer], { type: "pause", ids: ["a"] }, 31000).list[0];
assert.strictEqual(paused.state, "paused", "the timer is paused");
assert.strictEqual(TimerList.remaining(paused, 31000), 30, "with the half minute it had left");
assert.strictEqual(TimerList.remaining(paused, 31000 + 120000), 30, "which two minutes later is still thirty seconds");

const resumed = TimerList.apply([paused], { type: "resume", ids: ["a"] }, 31000 + 120000).list[0];
assert.strictEqual(resumed.state, "running", "resuming starts it again");
assert.strictEqual(TimerList.remaining(resumed, 31000 + 120000), 30, "from the second it was stopped at");
assert.strictEqual(TimerList.remaining(resumed, 31000 + 150000), 0, "and it runs on from there");

const rung = TimerList.apply([resumed], { type: "sweep" }, 31000 + 200000).list[0];
const repaused = TimerList.apply([rung], { type: "pause", ids: ["a"] }, 31000 + 200000).list[0];
assert.strictEqual(repaused.state, "rang", "a timer that has rung cannot be paused");
'
}

test_cancelling_one_timer_leaves_the_others() {
    check_rules "cancel and clear are the only ways to lose a timer" '
const list = [
    { id: "a", state: "running", ends: 5000, total: 10, paused: null, rangAt: 0 },
    { id: "b", state: "paused", ends: 9000, total: 10, paused: 4, rangAt: 0 }
];
const kept = TimerList.apply(list, { type: "cancel", ids: ["a"] }, 1000).list;
assert.deepStrictEqual(kept.map(t => t.id), ["b"], "the named timer goes, the rest stay");
assert.strictEqual(TimerList.apply(kept, { type: "clear" }, 1000).list.length, 0, "clear empties the list");
'
}

test_a_countdown_reads_like_a_clock() {
    check_rules "the card shows a clock, not a duration line with units in it" '
assert.strictEqual(TimerList.remaining({ state: "running", ends: 5000 }, 1000), 4, "the seconds are rounded up to the deadline");
assert.strictEqual(TimerList.remaining({ state: "running", ends: 1000 }, 5000), 0, "a timer that has ended cannot count up");
assert.strictEqual(TimerList.progress({ total: 10, state: "running", ends: 16000 }, 11000), 0.5, "progress is the part that has run");
assert.strictEqual(TimerList.progress({}, 1000), 0, "and nothing with no total to divide by");
'
    # One duration formatter, not two: the shell already has this one.
    assert_file_contains "$TIMERS" 'Units.formatDuration(root.remaining(timer))' "the card and the CLI share the shell's formatter"
    assert_file_not_contains "$RULES_JS" 'function format' "the timer rules do not grow a second one"
}

test_digits_are_read_the_way_a_keypad_is() {
    check_rules "the digit count has to decide what the columns mean" '
assert.strictEqual(TimerList.parseKeypad("30"), 30, "two digits are seconds");
assert.strictEqual(TimerList.parseKeypad("300"), 180, "three digits are minutes and seconds");
assert.strictEqual(TimerList.parseKeypad("10300"), 3780, "five digits grow an hour column");
assert.strictEqual(TimerList.parseKeypad("19999"), 7199, "and seconds past fifty-nine are clamped, not carried");
assert.strictEqual(TimerList.parseKeypad(""), 0, "nothing typed");
assert.strictEqual(TimerList.parseKeypad("12m"), 12, "letters are dropped rather than read as a unit");
'
}

test_durations_are_read_the_way_they_are_typed() {
    check_js "the command line keeps the other grammar, which duration.js owns" "$DURATION_JS" Duration '
assert.strictEqual(Duration.parse("25"), 1500, "a bare number is minutes");
assert.strictEqual(Duration.parse("90s"), 90, "s is seconds");
assert.strictEqual(Duration.parse("1h30"), 5400, "an hour and a half, written in one go");
assert.strictEqual(Duration.parse("later"), 0, "anything with no number in it is nothing");
'
    assert_file_contains "$TIMERS" 'import "duration.js" as Duration' "the service does not grow a third grammar"
}

test_the_alarm_is_configurable() {
    assert_file_contains "$CONFIG_HPP" 'timerAlarmDuration, 10' "ten seconds by default"
    assert_file_contains "$CONFIG_HPP" 'timerAlarmUntilDismissed, false' "and it gives up on its own unless told otherwise"
    assert_file_contains "$SERVICES_PAGE" 'setting: "timerAlarmUntilDismissed"' "the dismissal switch is in the settings"
    assert_file_contains "$SERVICES_PAGE" 'setting: "timerAlarmDuration"' "beside the length it replaces"
}

test_the_alarm_sound_is_one_of_the_machines_own_sounds() {
    # The setting names a sound; the list it is checked against belongs to the layer that
    # owns sound, so the timer cannot invent a second catalogue or a second validator.
    assert_file_contains "$AUDIO" 'property var systemSounds: []' "the audio service lists what is installed"
    assert_file_contains "$AUDIO" 'function playSystemSound(name: string, volume: real): bool' \
        "and plays one by name, saying so when the name is not there"
    assert_file_contains "$SERVICES_PAGE" 'model: Audio.systemSounds' "the picker offers exactly that list"
    assert_file_contains "$TIMERS" 'Audio.playSystemSound(root.alarmSound' "the timer asks for the configured sound"
    assert_file_not_contains "$TIMERS" 'alarmSounds' "and keeps no catalogue of its own"
    assert_file_not_contains "$TIMERS" '?? 10' "a missing setting is not papered over with a silent default"
}

test_the_card_and_its_setting_exist() {
    assert_file_exists "$CARD"
    assert_file_contains "$CARD" "Timers.start(" "the card starts timers"
    assert_file_contains "$CARD" "Timers.formatted(" "and shows what is left"
    assert_file_contains "$CARD" 'root.active.state' "reading one state rather than re-deciding it per label"
    assert_file_contains "$CONTENT" "TimersCard {" "the card is in the utilities drawer"
    assert_file_contains "$CONTENT" 'const visible = [...layout.children].filter(card => card.visible' \
        "and the height the drawer animates to is read from the layout, not from a second list of names"
    assert_file_contains "$SCHEMA" "showTimers" "the card can be turned off"
    assert_file_contains "$PANEL_PAGE" 'setting: "showTimers"' "from the utilities panel page"
}

# Enter starts a timer. Losing focus does not: `editingFinished` fires for both, and a
# timer that starts because the pointer left the field is a timer nobody asked for.
test_a_timer_starts_on_enter_and_not_on_a_blur() {
    assert_file_contains "$CARD" 'onAccepted: root.beginTyped()' "the card commits on Enter"
    assert_file_not_contains "$CARD" 'onEditingFinished' "and never on focus loss"
}

test_the_ai_tool_uses_the_same_timers() {
    assert_file_contains "$AI" 'Timers.start(secs, msg);' "a timer the assistant sets is a real one"
    assert_file_not_contains "$AI" 'Qt.createQmlObject(timerQml' \
        "and not an anonymous timer nobody can see or cancel"
    assert_file_contains "$LOADER" 'Timers;' "the service is loaded at startup, so the IPC target exists"
}

test_timers_can_be_driven_without_the_drawer() {
    assert_file_contains "$TIMERS" 'target: "timers"' "there is an IPC target"
    assert_file_contains "$TIMERS" 'function startFor(duration: string, message: string): void' \
        "which takes a duration as typed"
    assert_file_contains "$TIMERS" 'function list(): string' "and can report what is running"
}

run_tests
