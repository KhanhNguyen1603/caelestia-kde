#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$REPO_ROOT/shell/modules/nexus/common"
MODEL="$COMMON/updateModel.js"
CHECKER="$REPO_ROOT/shell/services/UpdateChecker.qml"
STATUS="$REPO_ROOT/shell/services/UpdateStatus.qml"
PAGE="$REPO_ROOT/shell/modules/nexus/pages/UpdatesPage.qml"
TIMELINE="$COMMON/UpdateTimeline.qml"
POPOUT="$REPO_ROOT/shell/modules/bar/popouts/Updates.qml"
INDICATOR="$REPO_ROOT/shell/modules/bar/components/UpdateIndicator.qml"
REGISTRY="$REPO_ROOT/shell/modules/nexus/PageCompRegistry.qml"
NEXUS_STATE="$REPO_ROOT/shell/modules/nexus/NexusState.qml"

commit() {
    printf '{hash:"%s",fullHash:"%s",subject:"%s",author:"Solanaceae",date:"today",isMerge:%s}' \
        "$1" "$1" "$2" "${3:-false}"
}

test_a_commit_list_marks_the_installed_commit_and_what_is_new() {
    local commits
    commits="[$(commit aaa 'feat: one'),$(commit bbb 'fix: two'),$(commit ccc 'chore: three')]"

    check_js "states are read off the installed commit" "$MODEL" "Model" "
const out = Model.deriveEntries({versionSummaryMode: false, availableVersions: [], currentVersion: 'unknown', commits: $commits, installedCommitHash: 'bbb'});
assert.deepStrictEqual(out.map(e => e.state), ['available', 'current', 'past']);
assert.deepStrictEqual(out.map(e => e.title), ['one', 'two', 'three'], 'the conventional-commit prefix is stripped');
"

    check_js "an unknown install marks the newest commit as current" "$MODEL" "Model" "
const out = Model.deriveEntries({versionSummaryMode: false, availableVersions: [], currentVersion: 'unknown', commits: $commits, installedCommitHash: ''});
assert.deepStrictEqual(out.map(e => e.state), ['current', 'past', 'past']);
"
}

test_a_release_list_marks_the_installed_version() {
    check_js "releases above the installed one are available" "$MODEL" "Model" "
const out = Model.deriveEntries({versionSummaryMode: true, availableVersions: ['2.9.0', '2.8.0', '2.7.0'], currentVersion: '2.7.0', commits: [], installedCommitHash: ''});
assert.deepStrictEqual(out.map(e => e.state), ['available', 'available', 'current']);
assert.strictEqual(out[0].label, '2.9.0', 'the tag is shown without its v');
assert.ok(out[0].url.endsWith('/releases/tag/2.9.0'), 'each release links to its notes');
"

    check_js "a version the list does not contain leaves the newest as current" "$MODEL" "Model" "
const out = Model.deriveEntries({versionSummaryMode: true, availableVersions: ['2.9.0', '2.8.0'], currentVersion: '9.9.9', commits: [], installedCommitHash: ''});
assert.deepStrictEqual(out.map(e => e.state), ['current', 'past']);
"

    check_js "release notes travel with the release they belong to" "$MODEL" "Model" "
const out = Model.deriveEntries({versionSummaryMode: true, availableVersions: ['2.9.0'], currentVersion: '2.8.0', commits: [{subject: '2.9.0', details: 'what changed'}], installedCommitHash: ''});
assert.strictEqual(out[0].details, 'what changed');
"
}

test_merges_and_housekeeping_are_internal_but_the_installed_commit_is_not() {
    check_js "internal commits are the bookkeeping ones" "$MODEL" "Model" "
assert.strictEqual(Model.isInternal({isRelease: false, isMerge: true, state: 'available', type: ''}), true, 'a merge carries no change of its own');
assert.strictEqual(Model.isInternal({isRelease: false, isMerge: false, state: 'available', type: 'chore'}), true);
assert.strictEqual(Model.isInternal({isRelease: false, isMerge: false, state: 'available', type: 'feat'}), false, 'a feature is what the reader came for');
assert.strictEqual(Model.isInternal({isRelease: false, isMerge: true, state: 'current', type: ''}), false, 'the installed commit is always shown');
assert.strictEqual(Model.isInternal({isRelease: true, isMerge: false, state: 'available', type: ''}), false);
"
}

test_a_collapsed_commit_list_shows_the_two_ends_of_the_gap() {
    local commits
    commits="[$(commit a1 'feat: a'),$(commit a2 'feat: b'),$(commit a3 'feat: c'),$(commit a4 'feat: d'),$(commit cur 'feat: installed'),$(commit p1 'feat: old')]"

    check_js "collapsed keeps one pending commit and the installed one" "$MODEL" "Model" "
const entries = Model.deriveEntries({versionSummaryMode: false, availableVersions: [], currentVersion: 'unknown', commits: $commits, installedCommitHash: 'cur'});
const out = Model.disclosure(entries, false, false, 3);
assert.deepStrictEqual(out.entries.map(e => e.id), ['a1', 'cur'], 'the run in between is one disclosure away');
assert.strictEqual(out.hiddenByCap, 4, 'the hidden run is counted for the button');
assert.strictEqual(out.capped, true);
assert.strictEqual(out.isCommitList, true);
"

    check_js "expanding shows the whole run" "$MODEL" "Model" "
const entries = Model.deriveEntries({versionSummaryMode: false, availableVersions: [], currentVersion: 'unknown', commits: $commits, installedCommitHash: 'cur'});
const out = Model.disclosure(entries, true, false, 3);
assert.strictEqual(out.entries.length, 6);
assert.strictEqual(out.hiddenByCap, 0);
"

    check_js "a release list keeps three per group" "$MODEL" "Model" "
const versions = ['9.0.0','8.0.0','7.0.0','6.0.0','5.0.0','4.0.0','3.0.0'];
const entries = Model.deriveEntries({versionSummaryMode: true, availableVersions: versions, currentVersion: '7.0.0', commits: [], installedCommitHash: ''});
const out = Model.disclosure(entries, false, false, 3);
assert.deepStrictEqual(out.entries.map(e => e.label), ['9.0.0','8.0.0','7.0.0','6.0.0','5.0.0','4.0.0'], 'two pending, the installed one, and three earlier releases');
assert.strictEqual(out.hiddenByCap, 1);
assert.strictEqual(out.capped, true);
"
}

test_internal_commits_are_counted_and_can_be_revealed() {
    local commits
    commits="[$(commit n1 'feat: visible'),$(commit n2 'chore: build noise'),$(commit n3 'refactor: internal'),$(commit n4 'Merge pull request #12 from x/y' true)]"

    check_js "hidden internal commits are counted, not shown" "$MODEL" "Model" "
const entries = Model.deriveEntries({versionSummaryMode: false, availableVersions: [], currentVersion: 'unknown', commits: $commits, installedCommitHash: 'n1'});
const collapsed = Model.disclosure(entries, false, false, 3);
assert.deepStrictEqual(collapsed.entries.map(e => e.id), ['n1'], 'only the installed commit survives the defaults');
assert.strictEqual(collapsed.internalCount, 3);

const shown = Model.disclosure(entries, true, true, 3);
assert.strictEqual(shown.entries.length, 4, 'revealing internal changes shows them');
"
}

test_release_notes_are_readable_text() {
    check_js "markdown is reduced to lines" "$MODEL" "Model" "
const body = ['## What is Changed', '* install the unit by [me](https://example.com)', '- fixed a crash', '', '# Skipped heading'].join('\n');
assert.strictEqual(Model.formatNotes(body), '• install the unit by me\n• fixed a crash');
assert.strictEqual(Model.formatNotes(body, 1), '• install the unit by me', 'the card caps how much it prints');
assert.strictEqual(Model.formatNotes(''), '');
"
}

test_the_page_previews_the_selected_entry_or_the_newest_release() {
    check_js "the selected entry wins, otherwise the newest available release" "$MODEL" "Model" "
const entries = Model.deriveEntries({versionSummaryMode: true, availableVersions: ['3.0.0','2.0.0','1.0.0'], currentVersion: '2.0.0', commits: [], installedCommitHash: ''});
assert.strictEqual(Model.previewEntry(entries, '3.0.0').label, '3.0.0');
assert.strictEqual(Model.previewEntry(entries, '1.0.0').label, '1.0.0', 'an older selection previews its own notes');
assert.strictEqual(Model.previewEntry(entries, 'gone').label, '3.0.0', 'a stale selection falls back to the update');
assert.strictEqual(Model.entryById(entries, 'gone'), null, 'and the page sees no selection at all');
"

    check_js "a development build has no release to preview" "$MODEL" "Model" "
const entries = Model.deriveEntries({versionSummaryMode: false, availableVersions: [], currentVersion: 'unknown', commits: [], installedCommitHash: ''});
assert.strictEqual(Model.previewEntry(entries, ''), null);
"
}

test_every_entry_field_always_exists() {
    check_js "one shape for both modes" "$MODEL" "Model" "
const fields = ['author','date','details','id','isMerge','isRelease','label','state','subject','title','type','url'];
const releases = Model.deriveEntries({versionSummaryMode: true, availableVersions: ['2.0.0'], currentVersion: '1.0.0', commits: [], installedCommitHash: ''});
const commits = Model.deriveEntries({versionSummaryMode: false, availableVersions: [], currentVersion: 'unknown', commits: [$(commit zz 'chore: x')], installedCommitHash: ''});
for (const entry of [releases[0], commits[0]])
    assert.deepStrictEqual(Object.keys(entry).sort(), fields, 'no caller has to guard for a missing field');
"
}

test_a_failed_check_is_not_reported_as_uptodate() {
    assert_file_contains "$CHECKER" 'FAIL|GitHub is unreachable' \
        "the check has to be able to say it could not reach GitHub"
    assert_file_contains "$CHECKER" 'if (root.checkError === "")' \
        "only a check that answered may advance lastCheckSuccessMs"
    assert_file_contains "$CHECKER" 'root.lastCheckSuccessMs = Date.now()' \
        "the last success is what the failure notice reports"
}

test_a_manual_check_ignores_the_periodic_setting() {
    assert_file_contains "$CHECKER" 'if (!manual && !root.checkingEnabled)' \
        "the setting gates automatic checks only, or the page becomes a dead end"
    assert_file_contains "$PAGE" 'UpdateChecker.checkNow()' "the page asks for a manual check"
    assert_file_contains "$CHECKER" 'function checkInBackground' \
        "and automatic checks have their own entry point"
    assert_file_not_contains "$CHECKER" 'checkUpdates(' "the positional-flag API is gone"
}

test_the_handoff_is_a_state_the_service_owns() {
    assert_file_contains "$CHECKER" 'enum Handoff' "the handoff is one state"
    assert_file_contains "$CHECKER" 'root.probeHandoff();' \
        "a shell that starts during an update has to ask the lock, not assume none"
    assert_file_contains "$CHECKER" 'handoffProbeIntervalMs: 2000' "the probe interval is named"
    assert_file_contains "$CHECKER" 'handoffGraceMs: 10000' "the grace is named"
    assert_file_contains "$PAGE" 'UpdateChecker.markHandoff(version)' "the page hands off to the service"
    assert_file_contains "$STATUS" 'UpdateChecker.Handoff.Running' "the card says an update is running"
    assert_file_not_contains "$CHECKER" 'wl-copy' "copying a command is a surface's job"
}

test_one_description_for_every_surface() {
    assert_file_contains "$STATUS" 'function describe(selection, launchFailed)' \
        "one function decides what the card says"
    assert_file_contains "$PAGE" 'UpdateStatus.describe(root.selection, root.launchFailed)' \
        "the page renders it"
    assert_file_contains "$POPOUT" 'UpdateStatus.describe(null, false)' "and so does the popout"
    assert_file_contains "$INDICATOR" 'root.status.icon' "and the indicator"
    assert_file_not_contains "$PAGE" 'readonly property string primaryActionText' \
        "the page keeps no second copy of the wording"
    assert_file_not_contains "$CHECKER" 'statusTitle' "nor does the service"
}

test_the_history_is_grouped_and_reachable_by_keyboard() {
    assert_file_not_contains "$TIMELINE" "What you'll get" \
        "the pending rows need no heading: the card is already 'Commit history'"
    assert_file_contains "$TIMELINE" 'qsTr("Your version")' "current group"
    assert_file_contains "$TIMELINE" 'qsTr("Earlier")' "past group"
    assert_file_contains "$TIMELINE" 'activeFocusOnTab: !row.isHeader' "timeline rows are in the tab order"
    assert_file_contains "$TIMELINE" 'Accessible.role: Accessible.ListItem' "and announce what they are"
    assert_file_contains "$TIMELINE" 'Keys.onPressed' "Enter and Space select a row"
    assert_file_not_contains "$TIMELINE" 'Flickable' "the list scrolls with the page instead of inside it"
}

test_the_rows_do_not_depend_on_the_selection() {
    assert_file_contains "$PAGE" 'entries: root.shown.entries' \
        "the timeline is handed the disclosure result, which the selection does not touch"
    assert_file_contains "$PAGE" 'disclosure(root.entries, root.timelineExpanded, root.showInternal' \
        "and nothing in that chain reads the selection"
    assert_file_contains "$TIMELINE" 'height: row.isHeader ? root.headerHeight' \
        "a selected row grows in place instead"
    assert_file_contains "$TIMELINE" 'Column {' "and the column reflows around it"
}

test_the_update_rows_have_one_owner() {
    assert_file_contains "$PAGE" 'text: qsTr("Automatic Updates")' \
        "the page owns whether checking happens"
    assert_file_not_contains "$PAGE" 'Show Update Indicator' "and does not also own the indicator"
    assert_file_contains "$PAGE" 'label: qsTr("Backup folder")' "the backup it takes is a row in that group"
    assert_file_contains "$PAGE" 'label: qsTr("Update channel")' "and the channel is a setting"
}

test_the_abandoned_in_page_runner_stays_deleted() {
    assert_file_not_contains "$CHECKER" 'function startUpdate' \
        "the runner referenced properties that never existed"
    assert_file_not_contains "$CHECKER" 'updateProgress' "and its progress state is gone"
    assert_file_not_contains "$CHECKER" 'processLineBuffer' "along with its output buffer"
}

test_the_dialogs_share_one_frame() {
    assert_file_contains "$COMMON/NexusDialog.qml" 'property string confirmText' "the frame owns the buttons"
    assert_file_contains "$COMMON/UninstallDialog.qml" 'NexusDialog {' "the uninstaller renders it"
    assert_file_contains "$COMMON/UpdateConfirmDialog.qml" 'NexusDialog {' "and so does the restore confirmation"
    assert_file_not_contains "$COMMON/UninstallDialog.qml" 'Elevation {' "neither keeps its own copy of the chrome"
    assert_file_not_contains "$COMMON/UpdateConfirmDialog.qml" 'Elevation {' "neither keeps its own copy of the chrome"
}

test_update_links_open_the_updates_subpage() {
    assert_file_contains "$POPOUT" 'initialPageIdx: "updates", initialSubPage: "updates"' "the popout opens the Updates page by key"
    assert_file_contains "$INDICATOR" 'initialPageIdx: "updates", initialSubPage: "updates"' "the indicator opens the same page"
    assert_file_contains "$REPO_ROOT/shell/modules/nexus/pages/panels/taskbar/BarUpdates.qml" \
        'goToSubPage(root.updatesPageIdx, "updates")' \
        "the taskbar settings link opens the Updates subpage"
}

test_the_updates_page_index_has_one_lookup() {
    local copies
    copies="$(grep -rl 'indexForKey("updates")' "$REPO_ROOT/shell" | wc -l | tr -d ' ')"
    assert_eq "0" "$copies" "the three copies of the lookup belong to PageRegistry"
    assert_file_contains "$REPO_ROOT/shell/modules/nexus/PageRegistry.qml" 'updatesPageIdx' \
        "which resolves it once"
}

test_the_updates_entry_opens_the_page_without_a_hub() {
    # A sidebar entry that opens a list of one asks for a second click to reach the only
    # thing on the list.
    assert_file_contains "$REGISTRY" 'singlePage: true' "the Updates category is a single page"
    assert_file_contains "$REGISTRY" 'cat.singlePage ? [] : [root.hubSubPage]' \
        "so its stack has no hub to land on"
    assert_file_contains "$NEXUS_STATE" 'isSinglePageCategory(pageIdx)' \
        "and the entry resolves straight to the page"
}

test_the_page_hands_the_updater_its_arguments_exactly_once() {
    # The arguments already name the program; the terminal's shell script has to exec them
    # as they are. Naming it again passed "caelestia-update" as the branch, which falls back
    # to main and drops the version that was selected.
    assert_file_contains "$PAGE" '''const hold = '"'"'"$@"; s=$?''' \
        "the held-open terminal execs the arguments it was given"
    assert_file_not_contains "$PAGE" 'caelestia-update "$@"' \
        "and never prefixes them with the program name a second time"
}

test_a_channel_pick_only_checks_when_it_changes_the_channel() {
    assert_file_contains "$PAGE" 'if (item.text === UpdateChecker.currentBranch)' \
        "a pick that matches the channel already followed is not a switch"
    assert_file_contains "$PAGE" 'function onCheckingUpdatesChanged' \
        "and the loading state ends when the check it armed finishes"
}

test_the_selected_row_offers_the_selections_own_action() {
    assert_file_contains "$PAGE" 'UpdateStatus.selectionAction(root.selection.state, root.selection.label)' \
        "the row's action comes from the selection, not from whatever card is showing"
    assert_file_contains "$TIMELINE" 'selectAction !== null' "and the row reserves room only for an action it has"
}

test_the_timeline_names_the_available_group() {
    assert_file_contains "$TIMELINE" 'qsTr("Available")' \
        "an available version needs its own heading, or it reads as the installed one"
    # The row's own tap area has to sit under the content: declared after it, it covers the
    # action strip and a press on "Update to X" toggles the selection off instead.
    local mousearea content
    mousearea="$(grep -n 'MouseArea {' "$TIMELINE" | cut -d: -f1 | tail -n 1)"
    content="$(grep -n 'topMargin: row.isRelease ? 7 : 10' "$TIMELINE" | cut -d: -f1)"
    if [[ -z "$mousearea" || -z "$content" ]] || ((mousearea > content)); then
        fail "the row's tap area must be declared before the content it sits under"
    fi
}

test_the_card_says_what_the_update_does() {
    assert_file_contains "$STATUS" 'function handoffDetail' "the restart promise matches the path"
    assert_file_contains "$STATUS" 'qsTr("also upgrades system packages")' \
        "a packaged update is a system upgrade and says so"
    assert_file_contains "$CHECKER" 'packagedUpdate' "which the checker detects from the install"
    assert_file_contains "$STATUS" 'UpdateChecker.updaterArgs(selectedId)' \
        "the command the card prints is the one Copy hands over"
}

test_the_outcome_of_a_run_comes_back() {
    assert_file_contains "$PAGE" 'UpdateChecker.clearResult()' "the page can dismiss what the updater recorded"
    assert_file_contains "$STATUS" 'lastResultStatus' "the card reports it"
    assert_file_contains "$CHECKER" 'parseRecord' "from the record caelestia-update writes"
    assert_file_contains "$REPO_ROOT/src/bin/caelestia-update" 'record last-update' \
        "which the updater writes when it finishes"
}

test_staging_is_a_separate_step() {
    local updater
    updater="$REPO_ROOT/src/bin/caelestia-update"
    assert_file_contains "$updater" '--stage) STAGE_REQUEST=1' "the updater takes a staging flag"
    assert_file_contains "$updater" 'pacman -Syuw' "which downloads without installing"
    assert_file_not_contains "$PAGE" 'pacman -Syu' "the page never names the package manager itself"
    assert_file_contains "$CHECKER" 'function stageArgs' "and the page reaches it through the checker"
}

test_the_run_reports_its_own_progress() {
    local updater="$REPO_ROOT/src/bin/caelestia-update"

    assert_file_contains "$updater" 'printf '"'"'%s|%s|%s|%s\n'"'"' "$1" "$2" "$3"' \
        "the updater writes the stage it is in where the shell can read it"
    assert_file_contains "$updater" 'stage 1 5' "and reports the first of its five stages"
    assert_file_contains "$updater" 'clear_progress' "and clears the record when it finishes"

    assert_file_contains "$CHECKER" 'progressFile' "the checker watches that record"
    assert_file_contains "$CHECKER" 'progressFraction' "and turns it into a fraction"
    assert_file_contains "$STATUS" 'progress: UpdateChecker.progressFraction' "the card carries it"
    assert_file_contains "$PAGE" 'root.status.progress' "and the row draws it"
}

test_the_update_runs_without_taking_over_the_screen() {
    # The run restarts the shell by the end, so the pane is what can survive it: the update
    # is launched on its own and its progress read back, not handed to a terminal window.
    assert_file_contains "$PAGE" 'Launch.exec(UpdateChecker.updaterArgs(version))' \
        "the update is started without a terminal"
    assert_file_contains "$PAGE" 'function runInTerminal' "with the terminal kept as the escape hatch"
    assert_file_contains "$STATUS" 'root.action("terminal"' "which the card offers when the run needs watching"
}

test_a_run_the_shell_started_restarts_the_shell() {
    local updater="$REPO_ROOT/src/bin/caelestia-update"

    assert_file_contains "$updater" 'INTERACTIVE=0' "the updater knows whether anyone is watching"
    # A prompt needs a terminal; a run the shell started has none, and the click that
    # started it already answered the only question the prompt would ask.
    assert_file_contains "$updater" '[ "$INTERACTIVE" -eq 0 ] || ask_yes_no' \
        "so an unwatched run restarts the shell instead of waiting for an answer"
    # A logout closes everything open, so it is reported rather than taken.
    assert_file_contains "$updater" 'NEEDS_LOGOUT=1' "a rebuilt plugin is reported, not acted on"
    assert_file_contains "$updater" '"${NEEDS_LOGOUT:-0}"' "and the record carries it"
    assert_file_contains "$CHECKER" 'lastResultLogout' "which the shell reads back"
    assert_file_contains "$STATUS" 'qsTr("Log out and back in to load it")' "and says so after the restart"
}

test_a_run_that_never_started_is_reported() {
    assert_file_contains "$PAGE" 'root.awaitingStart = true' "starting an update arms a watchdog"
    assert_file_contains "$PAGE" 'root.launchFailed = true' "which reports a run that never began"
    assert_file_contains "$PAGE" 'UpdateChecker.progressTotal === 0' \
        "and only while nothing has reported a stage"
    assert_file_contains "$STATUS" "qsTr(\"Couldn't start the update\")" "the card names what failed"
    assert_file_contains "$STATUS" 'root.action("terminal"' "and offers the terminal as the way through"
}

run_tests
