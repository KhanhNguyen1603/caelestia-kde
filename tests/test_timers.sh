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
LOADER="$REPO_ROOT/shell/modules/ServiceLoader.qml"
AI="$REPO_ROOT/shell/modules/sidebar/AiAssistant.qml"
DURATION_JS="$REPO_ROOT/shell/services/duration.js"
SPLIT_JS="$REPO_ROOT/shell/services/timers.js"
SERVICES_PAGE="$REPO_ROOT/shell/modules/nexus/pages/ServicesPage.qml"
CONFIG_HPP="$REPO_ROOT/shell/plugin/src/Caelestia/Config/serviceconfig.hpp"
AUDIO="$REPO_ROOT/shell/services/Audio.qml"

# A timer is a deadline, not a countdown: storing what is left means a restart two
# minutes into a 25 minute timer silently loses the other 23.
test_a_timer_is_stored_as_the_moment_it_ends() {
    assert_file_contains "$TIMERS" 'ends: Date.now() + seconds * 1000' "starting a timer records when it ends"
    assert_file_contains "$TIMERS" 'ends: timer.ends' "and that is what is written to disk"
    assert_file_contains "$TIMERS" 'path: `${Paths.state}/timers.json`' "beside the other state the shell keeps"
    assert_file_contains "$TIMERS" 'const split = TimerList.split(root.list, now)' \
        "what is due is decided by the pure split, from a clock read once"
    assert_file_contains "$TIMERS" 'root.list = data.filter(timer => TimerList.isPaused(timer) || timer.ends > Date.now())' \
        "loading keeps the ones that have not ended yet, and the paused ones whatever their deadline says"
}

# The elements of a `list<var>` are views of the sequence, so an array of them read after
# `list` is reassigned shows the new contents. That announced the wrong timer's message.
test_the_running_timers_are_plain_values_not_a_sequence_view() {
    assert_file_contains "$TIMERS" 'property var list: []' \
        "the list is a plain array, whose elements keep their own values"
    assert_file_contains "$TIMERS" 'const finished = split.due.map(timer => String(timer.message));' \
        "and what fired is read out before the list is rewritten"
}

# A timer that ran out while the shell was down already happened: one message for the
# batch, not a burst of toasts the moment the shell starts.
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

test_durations_are_read_the_way_they_are_typed() {
    assert_file_contains "$TIMERS" 'function parseDuration(text: string): int' "one parser, shared by the card and the CLI"
    assert_file_contains "$TIMERS" 'return Duration.parse(text);' "and it is the one in duration.js, which a test can run"
}

# The grammar is pure, so it is executed rather than grepped: each script below runs
# against duration.js with node's assert.
check_duration() { check_js "$1" "$DURATION_JS" Duration "$2"; }

test_a_bare_number_is_minutes_and_a_unit_is_read_as_written() {
    check_duration "durations have to read the way someone types them" '
assert.strictEqual(Duration.parse("25"), 1500, "a bare number is minutes");
assert.strictEqual(Duration.parse("25m"), 1500, "and so is m");
assert.strictEqual(Duration.parse("90s"), 90, "s is seconds");
assert.strictEqual(Duration.parse("1h30"), 5400, "an hour and a half, written in one go");
assert.strictEqual(Duration.parse("1h 30m"), 5400, "and with the space people type");
assert.strictEqual(Duration.parse(" 45 min "), 2700, "the long form survives padding");
'
}

test_junk_is_not_a_duration() {
    check_duration "anything with no number in it has to be zero, not a guess" '
assert.strictEqual(Duration.parse(""), 0, "nothing typed");
assert.strictEqual(Duration.parse("   "), 0, "whitespace");
assert.strictEqual(Duration.parse("later"), 0, "words");
assert.strictEqual(Duration.parse("m"), 0, "a unit with no number");
assert.strictEqual(Duration.parse(null), 0, "and a missing field does not throw");
'
}

# The split that decides what fires is pure too (timers.js), and this is the case that got
# it wrong: a timer ten minutes out was announced when an eight second one ended.
check_timers() { check_js "$1" "$SPLIT_JS" TimerList "$2"; }

test_only_the_timers_that_have_ended_are_due() {
    check_timers "a timer that has not ended is not due, however many others are" '
const now = 1000000;
const short = { id: "short", ends: now - 1, message: "eight seconds" };
const long = { id: "long", ends: now + 600000, message: "ten minutes" };
const split = TimerList.split([short, long], now);
assert.deepStrictEqual(split.due.map(t => t.message), ["eight seconds"], "only the ended one is due");
assert.deepStrictEqual(split.running.map(t => t.message), ["ten minutes"], "the other keeps running");
assert.strictEqual(TimerList.split([long], now).due.length, 0, "and nothing is due when nothing has ended");
assert.strictEqual(TimerList.split([], now).running.length, 0, "an empty list splits into nothing");
'
}

test_a_deadline_written_as_text_is_still_a_deadline() {
    check_timers "a hand-edited or restored file must not change what fires" '
const now = 1000000;
const split = TimerList.split([{ id: "a", ends: String(now - 5), message: "text deadline" }], now);
assert.strictEqual(split.due.length, 1, "a numeric string is compared as a number");
'
}

# The field is a keypad, not a duration box: no unit is typed, and the number of digits
# decides what the columns mean.
test_digits_are_read_the_way_a_keypad_is() {
    check_timers "the digit count has to decide what the columns mean" '
assert.strictEqual(TimerList.parseDigits("30"), 30, "two digits are seconds");
assert.strictEqual(TimerList.parseDigits("300"), 180, "three digits are minutes and seconds");
assert.strictEqual(TimerList.parseDigits("1030"), 630, "four digits are the same two columns");
assert.strictEqual(TimerList.parseDigits("10300"), 3780, "five digits grow an hour column");
assert.strictEqual(TimerList.parseDigits("19999"), 7199, "and seconds past fifty-nine are clamped, not carried");
assert.strictEqual(TimerList.parseDigits(""), 0, "nothing typed");
assert.strictEqual(TimerList.parseDigits("12m"), 12, "letters are dropped rather than read as a unit");
'
}

test_a_countdown_reads_like_a_clock() {
    check_timers "the card shows a clock, not a duration line with units in it" '
assert.strictEqual(TimerList.format(0), "0:00", "zero reads as zero");
assert.strictEqual(TimerList.format(9), "0:09", "seconds are padded");
assert.strictEqual(TimerList.format(90), "1:30", "minutes and seconds");
assert.strictEqual(TimerList.format(3600), "1:00:00", "an hour grows a column");
assert.strictEqual(TimerList.format(-5), "0:00", "a timer that has ended cannot count up");
'
}

test_a_paused_timer_waits_where_it_was_stopped() {
    check_timers "a timer waiting on purpose cannot fire" '
const now = 1000000;
const paused = { id: "p", ends: now - 60000, paused: 300 };
const split = TimerList.split([paused], now);
assert.strictEqual(split.due.length, 0, "however far its deadline has passed");
assert.strictEqual(TimerList.remaining(paused, now), 300, "it keeps the time it had left");
assert.strictEqual(TimerList.isPaused(paused), true, "which is what marks it paused");
assert.strictEqual(TimerList.isPaused({ id: "r", ends: now + 1000, paused: null }), false, "a running timer carries none");
assert.strictEqual(TimerList.progress({ total: 600, ends: now + 300000, paused: null }, now), 0.5, "progress is the part that has run");
assert.strictEqual(TimerList.progress({}, now), 0, "and nothing with no total to divide by");
'
}

test_a_timer_that_already_rang_is_not_announced_twice() {
    check_timers "the second pass over a finished timer must not fire it again" '
const now = 1000000;
const split = TimerList.split([{ id: "r", ends: now - 1, rang: true }], now);
assert.strictEqual(split.due.length, 0, "it stays in the list without coming due again");
assert.strictEqual(split.running.length, 1, "and is still a timer the card can show");
'
}

test_a_running_timer_can_be_paused_from_the_card_or_a_keybind() {
    assert_file_contains "$TIMERS" 'function pause(id: string): void' "the service stops a countdown where it stands"
    assert_file_contains "$TIMERS" 'function resume(id: string): void' "and restarts it from the time it had left"
    assert_file_contains "$CARD" 'Timers.pause(root.active.id)' "the card's button is that switch"
    assert_file_contains "$TIMERS" 'function toggleActive(): void' "which a keybind can drive without an id"
}

test_the_alarm_is_configurable() {
    assert_file_contains "$CONFIG_HPP" 'timerAlarmDuration, 10' "ten seconds by default"
    assert_file_contains "$CONFIG_HPP" 'timerAlarm, false' "and it gives up on its own unless told otherwise"
    assert_file_contains "$CONFIG_HPP" 'timerAlarmSound' "and it plays one of the system's sounds"
    assert_file_contains "$SERVICES_PAGE" 'setting: "timerAlarm"' "the dismissal switch is in the settings"
    assert_file_contains "$SERVICES_PAGE" 'setting: "timerAlarmDuration"' "beside the length it replaces"
    assert_file_contains "$SERVICES_PAGE" 'GlobalConfig.services.timerAlarmSound' "and the sound it plays"
    assert_file_contains "$TIMERS" 'Audio.playSystemSound(root.alarmSoundPath(root.alarmSound)' "which comes from the system's own sounds, not a bundled chime"
}

test_the_alarm_sound_cannot_name_an_arbitrary_file() {
    # The setting is a name, not a path: what it can reach is fixed by the shell, the same
    # way the notification sound is a name in one directory.
    assert_file_contains "$TIMERS" 'alarmSoundRoot: "/usr/share/sounds/"' "every alarm sound lives under one root"
    assert_file_contains "$TIMERS" 'root.alarmSounds.indexOf(root.alarmSound) >= 0' "and a name this machine does not offer falls back to the shell chime"
    assert_file_contains "$AUDIO" 'function playSystemSound(path: string, volume: real): void' "played through the one entry point that honours the sound settings"
}

test_the_card_and_its_setting_exist() {
    assert_file_exists "$CARD"
    assert_file_contains "$CARD" "Timers.start(" "the card starts timers"
    assert_file_contains "$CARD" "Timers.formatted(" "and shows what is left"
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
    assert_file_contains "$CARD" 'readonly property int typedSeconds: Timers.parseDigits(digitsField.text)' \
        "one reading of the field, shared by the button and both fields"
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
