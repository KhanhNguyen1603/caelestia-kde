pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common
import "../common/updateModel.js" as UpdateModel

// The status of the install, presented the way the pane this is modelled on does it:
// one row that answers "am I safe, and what happens if I click" - a symbol, a title, a
// subtitle and the one button that acts - with the settings that decide that answer in
// the group under it and the version history kept below as reference.
PageBase {
    id: root

    readonly property list<MenuItem> branchItems: branchVariants.instances

    readonly property var activeBranchItem: {
        const found = branchItems.find(function(i) {
            return i.text === UpdateChecker.currentBranch;
        });
        return found || (branchItems.length > 0 ? branchItems[0] : null);
    }

    property string selectedVersionId: ""
    property string pendingBranch: ""
    property bool launchFailed: false
    // Set when a run was started and has not yet shown a sign of life. The update has no
    // terminal to fail visibly in, so this is what notices that it never began.
    property bool awaitingStart: false
    property string backupError: ""
    property bool timelineExpanded: false
    property bool showInternal: false

    property bool configuredTerminalAvailable: true
    property bool konsoleAvailable: false

    readonly property bool branchDataLoading: root.pendingBranch !== "" && UpdateChecker.checkingUpdates

    readonly property var entries: UpdateModel.deriveEntries({
        versionSummaryMode: UpdateChecker.versionSummaryMode,
        availableVersions: UpdateChecker.availableVersions,
        currentVersion: UpdateChecker.currentVersion,
        commits: UpdateChecker.commits,
        installedCommitHash: UpdateChecker.installedCommitHash
    })

    readonly property var shown: UpdateModel.disclosure(root.entries, root.timelineExpanded, root.showInternal, 1)

    readonly property var selection: {
        const entry = UpdateModel.entryById(root.entries, root.selectedVersionId);
        return entry === null ? null : {
            id: entry.id,
            state: entry.state,
            label: entry.label
        };
    }

    readonly property var status: UpdateStatus.describe(root.selection, root.launchFailed)

    readonly property var preview: UpdateModel.previewEntry(root.entries, root.selectedVersionId)
    readonly property string notesText: root.preview !== null && root.preview.isRelease ? UpdateModel.formatNotes(root.preview.details) : ""
    readonly property string releaseUrl: root.preview !== null && root.preview.isRelease ? root.preview.url : ""

    // The configured terminal is a bare command and may not be installed - the
    // default is foot, which a KDE box often does not have - so fall back to
    // konsole, KDE's own terminal, instead of launching nothing.
    readonly property list<string> terminalCommand: root.configuredTerminalAvailable ? GlobalConfig.general.apps.terminal : ["konsole"]
    readonly property bool terminalAvailable: root.configuredTerminalAvailable || root.konsoleAvailable
    readonly property bool busy: UpdateChecker.checkingUpdates && root.status.primary === null

    readonly property int inset: Tokens.padding.largeIncreased

    function runAction(key): void {
        if (key === "check") {
            root.checkNow();
        } else if (key === "turnOn") {
            GlobalConfig.general.checkUpdates = true;
            root.checkNow();
        } else if (key === "restore") {
            confirmDialog.open();
        } else if (key === "install" || key === "reinstall" || key === "reopen") {
            root.launchUpdater();
        } else if (key === "terminal") {
            root.runInTerminal();
        } else if (key === "stage") {
            root.stageUpdate();
        } else if (key === "copy") {
            root.copyCommand();
        } else if (key === "clear") {
            root.selectedVersionId = "";
        } else if (key === "dismiss") {
            UpdateChecker.dismissHandoff();
        } else if (key === "dismissResult") {
            UpdateChecker.clearResult();
        }
    }

    function checkNow(): void {
        root.launchFailed = false;
        UpdateChecker.checkNow();
    }

    function copyCommand(): void {
        // An empty selection is not a version: passing "" would suppress the version the
        // card is about, so the copied command would not be the one on screen.
        const version = root.selectedVersionId === "" ? undefined : root.selectedVersionId;
        const command = UpdateChecker.updaterArgs(version).join(" ");
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "--", command]);
    }

    // The terminal holds its window open afterwards: the update restarts the shell and its
    // output is what the user needs to read. The arguments are exec'd as they are - naming
    // the program again would hand the updater "caelestia-update" as its first argument,
    // which is not a branch, so it falls back to main and drops the version asked for.
    function launchInTerminal(args): void {
        if (!root.terminalAvailable) {
            root.launchFailed = true;
            return;
        }
        const hold = '"$@"; s=$?; printf "\\n[update exited with status %s] Press Enter to close..." "$s"; read -r _';
        Launch.exec([...root.terminalCommand, "sh", "-c", hold, "sh", ...args]);
    }

    // The update runs on its own, not in a terminal the user has to watch: it restarts the
    // shell by the end, so its progress comes back through the record it writes, and the
    // pane keeps working while it runs. The terminal stays available as the escape hatch
    // for an escalation prompt or a failure worth reading.
    function launchUpdater(): void {
        root.launchFailed = false;
        const version = root.selectedVersionId !== "" ? root.selectedVersionId : UpdateChecker.handoffVersion;
        root.selectedVersionId = "";
        Launch.exec(UpdateChecker.updaterArgs(version));
        UpdateChecker.markHandoff(version);
        root.awaitingStart = true;
    }

    function runInTerminal(): void {
        root.launchFailed = false;
        const version = UpdateChecker.handoffVersion;
        root.launchInTerminal(UpdateChecker.updaterArgs(version));
        UpdateChecker.markHandoff(version);
    }

    function stageUpdate(): void {
        root.launchFailed = false;
        const version = root.selectedVersionId === "" ? undefined : root.selectedVersionId;
        root.launchInTerminal(UpdateChecker.stageArgs(version));
        UpdateChecker.markStaged(version);
    }

    title: qsTr("Updates")

    Item {
        visible: false

        // A run started from here has no terminal to fail in, so nothing would tell the
        // reader that it never began. Eight seconds is enough for the process to reach its
        // first stage; after that the pane offers the terminal and the command instead.
        Timer {
            interval: 8000
            repeat: false
            running: root.awaitingStart && UpdateChecker.handoff === UpdateChecker.Handoff.Pending && UpdateChecker.progressTotal === 0
            onTriggered: {
                root.awaitingStart = false;
                root.launchFailed = true;
            }
        }

        // pendingBranch describes one check: the one its channel pick started. Left set,
        // every later check - the periodic one, a retry - re-shows "Switching to X…" and
        // hides the settings below it while nothing is being switched.
        Connections {
            function onCheckingUpdatesChanged(): void {
                if (!UpdateChecker.checkingUpdates)
                    root.pendingBranch = "";
            }

            target: UpdateChecker
        }

        Variants {
            id: branchVariants

            model: UpdateChecker.availableBranches

            MenuItem {
                required property string modelData

                text: modelData
                icon: "call_split"
            }
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        // ---- the row that is the whole task -------------------------------------
        ConnectedRect {
            first: true
            last: true
            Layout.fillWidth: true
            implicitHeight: statusRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: statusRow

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: root.inset
                    rightMargin: root.inset
                    topMargin: Tokens.padding.medium
                }
                spacing: Tokens.spacing.medium

                StyledRect {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: Tokens.padding.largeIncreased * 2
                    implicitHeight: implicitWidth
                    radius: Tokens.rounding.large
                    color: Qt.alpha(Colours.palette.m3primary, 0.22)

                    MaterialIcon {
                        anchors.centerIn: parent
                        fontStyle: Tokens.font.icon.medium
                        text: root.status.icon
                        color: root.status.highlight ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: root.status.title
                        font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                        color: Colours.palette.m3onSurface
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.status.detail
                        font: NexusStyle.secondaryFont
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    // The run's own report, in the row it belongs to: a thin bar and the
                    // stage it names, rather than a sentence claiming an update is under way.
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.extraSmall
                        implicitHeight: Tokens.padding.small
                        visible: root.status.progress !== undefined && root.status.progress > 0
                        radius: Tokens.rounding.full
                        color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

                        StyledRect {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: parent.width * Math.max(0, Math.min(1, root.status.progress))
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3primary

                            Behavior on width {
                                Anim {
                                    type: Anim.FastEffects
                                }
                            }
                        }
                    }
                }

                TextButton {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.status.dismissible
                    text: qsTr("Dismiss")
                    type: TextButton.Text
                    font: Tokens.font.body.small
                    horizontalPadding: Tokens.padding.medium
                    verticalPadding: Tokens.padding.small
                    onClicked: root.runAction("dismiss")
                }

                TextButton {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.status.secondary !== null
                    text: root.status.secondary !== null ? root.status.secondary.label : ""
                    type: TextButton.Text
                    font: Tokens.font.body.small
                    horizontalPadding: Tokens.padding.medium
                    verticalPadding: Tokens.padding.small
                    onClicked: root.runAction(root.status.secondary.key)
                }

                IconTextButton {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.busy || root.status.primary !== null
                    disabled: root.busy
                    text: root.busy ? qsTr("Checking…") : (root.status.primary !== null ? root.status.primary.label : "")
                    icon: root.busy ? "refresh" : (root.status.primary !== null ? root.status.primary.icon : "")
                    type: TextButton.Filled
                    font: Tokens.font.body.small
                    horizontalPadding: Tokens.padding.large
                    verticalPadding: Tokens.padding.small
                    onClicked: {
                        if (root.status.primary !== null)
                            root.runAction(root.status.primary.key);
                    }
                }
            }
        }

        // What the version you picked would do. It appears only once there is a version to
        // describe, so the pane opens on one row rather than a wall of release notes.
        ConnectedRect {
            first: true
            last: true
            visible: root.selectedVersionId !== "" && root.notesText !== ""
            Layout.fillWidth: true
            implicitHeight: notesBlock.implicitHeight + root.inset * 2

            ColumnLayout {
                id: notesBlock

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: root.inset
                    rightMargin: root.inset
                    topMargin: root.inset
                }
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Release notes")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.notesText
                    font: NexusStyle.secondaryFont
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.Wrap
                }

                TextButton {
                    visible: root.releaseUrl !== ""
                    text: qsTr("Open on GitHub")
                    type: TextButton.Text
                    font: NexusStyle.secondaryFont
                    horizontalPadding: Tokens.padding.medium
                    verticalPadding: Tokens.padding.extraSmall
                    onClicked: Qt.openUrlExternally(root.releaseUrl)
                }
            }
        }

        // ---- what an automatic update means, in the group that sets it ----------
        // The rows sit 2px apart so they read as one group rather than three cards:
        // proximity is what says they belong to the same decision.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            // No reset: the row keeps no room for a reset affordance the setting does not
            // need, which is what puts the switch on the trailing edge.
            ToggleRow {
                first: true
                last: !GlobalConfig.general.checkUpdates
                text: qsTr("Automatic Updates")
                subtext: qsTr("Checked every 30 minutes, and once when the shell starts")
                checked: GlobalConfig.general.checkUpdates
                onToggled: GlobalConfig.general.checkUpdates = checked
            }

            SelectRow {
                visible: GlobalConfig.general.checkUpdates
                enabled: !root.branchDataLoading
                label: qsTr("Update channel")
                subtext: UpdateChecker.currentBranch === "main" ? qsTr("Stable releases") : qsTr("Development builds (may be unstable)")
                menuItems: root.branchItems
                active: root.activeBranchItem
                fallbackText: UpdateChecker.currentBranch
                fallbackIcon: "call_split"
                onSelected: function(item) {
                    // SelectRow emits this when the menu is cancelled and on every arrow
                    // key, so a pick that matches the channel already followed must not
                    // start a check, let alone write that channel to the state again.
                    if (item.text === UpdateChecker.currentBranch)
                        return;
                    root.selectedVersionId = "";
                    root.pendingBranch = item.text;
                    UpdateChecker.checkNow(item.text);
                }
            }

            NavRow {
                last: true
                visible: GlobalConfig.general.checkUpdates
                icon: "folder"
                label: qsTr("Backup folder")
                status: root.backupError !== "" ? root.backupError : qsTr("Your settings are saved here before each update")
                onClicked: {
                    root.backupError = "";
                    backupFolderProcess.running = true;
                }
            }
        }

        // ---- reference material, not the task ----------------------------------
        ConnectedRect {
            first: true
            last: true
            Layout.fillWidth: true
            implicitHeight: historyBlock.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: historyBlock

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: root.inset
                    rightMargin: root.inset
                    topMargin: Tokens.padding.medium
                }
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: root.shown.isCommitList ? qsTr("Commit history") : qsTr("Version history")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurface
                    }

                    TextButton {
                        visible: !root.timelineExpanded && root.shown.hiddenByCap > 0
                        text: qsTr("More…")
                        type: TextButton.Text
                        font: NexusStyle.secondaryFont
                        horizontalPadding: Tokens.padding.medium
                        verticalPadding: Tokens.padding.extraSmall
                        onClicked: root.timelineExpanded = true
                    }

                    TextButton {
                        visible: root.timelineExpanded && root.shown.capped
                        text: qsTr("Less")
                        type: TextButton.Text
                        font: NexusStyle.secondaryFont
                        horizontalPadding: Tokens.padding.medium
                        verticalPadding: Tokens.padding.extraSmall
                        onClicked: root.timelineExpanded = false
                    }

                    TextButton {
                        visible: root.shown.internalCount > 0
                        text: root.showInternal ? qsTr("Hide internal") : qsTr("Internal (%1)").arg(root.shown.internalCount)
                        type: TextButton.Text
                        font: NexusStyle.secondaryFont
                        horizontalPadding: Tokens.padding.medium
                        verticalPadding: Tokens.padding.extraSmall
                        onClicked: root.showInternal = !root.showInternal
                    }
                }

                UpdateTimeline {
                    Layout.fillWidth: true
                    visible: root.shown.entries.length > 0
                    entries: root.shown.entries
                    selectedId: root.selectedVersionId
                    selectAction: root.selection !== null ? UpdateStatus.selectionAction(root.selection.state, root.selection.label) : null
                    onEntryClicked: (entryId, entryState) => {
                        root.selectedVersionId = root.selectedVersionId === entryId ? "" : entryId;
                    }
                    onActionRequested: key => root.runAction(key)
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !root.branchDataLoading && root.entries.length === 0
                    text: qsTr("No history yet.")
                    font: NexusStyle.secondaryFont
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.Wrap
                }

                TextButton {
                    visible: root.shown.isCommitList && UpdateChecker.hasMoreCommits
                    text: UpdateChecker.loadingMoreCommits ? qsTr("Loading…") : qsTr("Load older commits")
                    type: TextButton.Text
                    font: NexusStyle.secondaryFont
                    horizontalPadding: Tokens.padding.medium
                    verticalPadding: Tokens.padding.extraSmall
                    disabled: UpdateChecker.loadingMoreCommits
                    onClicked: UpdateChecker.loadMoreCommits()
                }
            }
        }

        // The footnote this pane keeps under its groups.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.inset
            Layout.rightMargin: root.inset
            spacing: Tokens.spacing.small

            Item {
                Layout.fillWidth: true
            }

            TextButton {
                text: qsTr("Troubleshooting")
                type: TextButton.Text
                font: NexusStyle.secondaryFont
                horizontalPadding: Tokens.padding.medium
                verticalPadding: Tokens.padding.extraSmall
                onClicked: Qt.openUrlExternally("https://github.com/caelestia-kde/caelestia/blob/main/docs/TROUBLESHOOTING.md#10-update-issues")
            }
        }

        Process {
            id: terminalCheck

            command: ["bash", "-c", "command -v \"$1\" >/dev/null 2>&1", "--", GlobalConfig.general.apps.terminal[0] || ""]
            running: true
            onExited: code => {
                root.configuredTerminalAvailable = code === 0;
                if (code === 0)
                    root.launchFailed = false;
            }
        }

        Process {
            id: konsoleCheck

            command: ["bash", "-c", "command -v konsole >/dev/null 2>&1"]
            running: true
            onExited: code => root.konsoleAvailable = code === 0
        }

        Process {
            id: backupFolderProcess

            // One shot: the binding on `running` is spent the first time it starts.
            command: ["sh", "-c",
                'dir="$1"; shift; mkdir -p "$dir" && exec "$@" "$dir"',
                "--",
                Paths.absolutePath("~/.config/caelestia-update/backups")
            ].concat(GlobalConfig.general.apps.explorer)
            onExited: code => {
                if (code !== 0)
                    root.backupError = qsTr("Couldn't open the folder — it is at ~/.config/caelestia-update/backups");
            }
        }

        UpdateConfirmDialog {
            id: confirmDialog

            toVersion: root.selection !== null ? root.selection.label : ""
            fromVersion: UpdateChecker.currentVersion !== "unknown" ? UpdateChecker.currentVersion : ""
            onConfirmed: root.launchUpdater()
        }
    }
}
