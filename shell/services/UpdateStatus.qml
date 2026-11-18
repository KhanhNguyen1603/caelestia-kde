pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

// One description of the update state for every surface that reports it: the
// page, the bar popout and the bar indicator all render `describe()` rather than
// deciding for themselves what to say. A surface that knows more (the page knows
// about a selected version, and about a terminal it failed to open) passes that in
// and gets the same object back.
Singleton {
    id: root

    property double now: Date.now()

    readonly property var current: root.describe(null, false)

    function action(key, label, icon): var {
        return {
            key: key,
            label: label,
            icon: icon
        };
    }

    function card(icon, title, detail, primary, secondary, extra): var {
        const result = {
            icon: icon,
            title: title,
            detail: detail,
            primary: primary === undefined ? null : primary,
            secondary: secondary === undefined ? null : secondary,
            dismissible: false,
            highlight: false
        };
        if (extra !== undefined) {
            for (const key in extra)
                result[key] = extra[key];
        }
        return result;
    }

    function formatDuration(ms: real): string {
        const seconds = Math.max(0, Math.floor(ms / 1000));
        if (seconds < 60)
            return qsTr("less than a minute");
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60)
            return qsTr("%1 min").arg(minutes);
        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return qsTr("%1 h").arg(hours);
        return qsTr("%1 d").arg(Math.floor(hours / 24));
    }

    function versionText(): string {
        const version = UpdateChecker.currentVersion;
        return version === "unknown" || version === "" ? "" : version;
    }

    // When the check itself last worked, which is what a failure has to report:
    // the last attempt is useless once it failed.
    function checkTiming(): string {
        if (UpdateChecker.checkingUpdates)
            return qsTr("checking now");
        if (!UpdateChecker.everChecked)
            return qsTr("not checked yet");
        const parts = [qsTr("checked %1 ago").arg(root.formatDuration(root.now - UpdateChecker.lastCheckSuccessMs))];
        if (UpdateChecker.checkingEnabled && UpdateChecker.handoff === UpdateChecker.Handoff.None)
            parts.push(qsTr("next in %1").arg(root.formatDuration(UpdateChecker.lastCheckSuccessMs + UpdateChecker.checkIntervalMs - root.now)));
        return parts.join(" · ");
    }

    function baseDetail(): string {
        const parts = [];
        const version = root.versionText();
        if (version !== "")
            parts.push(version);
        if (UpdateChecker.checkFailed) {
            parts.push(UpdateChecker.everChecked ? qsTr("last success %1 ago").arg(root.formatDuration(root.now - UpdateChecker.lastCheckSuccessMs)) : qsTr("never checked successfully"));
            parts.push(UpdateChecker.checkError);
            return parts.join(" · ");
        }
        parts.push(root.checkTiming());
        return parts.join(" · ");
    }

    function latestVersion(): string {
        const versions = UpdateChecker.availableVersions;
        return versions.length > 0 ? versions[0].replace(/^v/i, "") : "";
    }

    function selectionTitle(state, label): string {
        if (state === "past")
            return qsTr("Restore %1?").arg(label);
        if (state === "current")
            return qsTr("Reinstall %1?").arg(label);
        return qsTr("Update to %1?").arg(label);
    }

    function selectionAction(state, label): var {
        if (state === "past")
            return root.action("restore", qsTr("Restore %1").arg(label), "history");
        if (state === "current")
            return root.action("reinstall", qsTr("Reinstall %1").arg(label), "replay");
        return root.action("install", qsTr("Update to %1").arg(label), "system_update_alt");
    }

    // The packaged path hands the install to the package manager, which replaces the files
    // the shell runs from but cannot restart it; the source path rebuilds and restarts.
    function handoffDetail(): string {
        return UpdateChecker.packagedUpdate ? qsTr("Log out and back in when it finishes") : qsTr("The shell restarts when it finishes");
    }

    // What the update leaves behind, said the same way wherever the card describes it.
    function afterwardsText(): string {
        return UpdateChecker.packagedUpdate ? qsTr("also upgrades system packages") : qsTr("the shell restarts");
    }

    function updateDetail(): string {
        const detail = root.baseDetail();
        if (UpdateChecker.stagedLabel !== "")
            return qsTr("%1 downloaded").arg(UpdateChecker.stagedLabel);
        return UpdateChecker.packagedUpdate ? qsTr("%1 · %2").arg(detail).arg(root.afterwardsText()) : detail;
    }

    function selectionDetail(state): string {
        const parts = [];
        const version = root.versionText();
        if (version !== "")
            parts.push(qsTr("From %1").arg(version));
        if (state === "past")
            parts.push(qsTr("older version"));
        parts.push(qsTr("settings are backed up"));
        parts.push(root.afterwardsText());
        return parts.join(" · ");
    }

    function selectionIcon(state): string {
        if (state === "past")
            return "history";
        if (state === "current")
            return "replay";
        return "system_update_alt";
    }

    function describe(selection, launchFailed): var {
        // The command this card is about. A selection names a version; with none, the
        // updater falls back to the version the running handoff is for. Passing "" for
        // "nothing selected" would drop that version, so Copy would hand over a different
        // command than the one the card shows.
        const selectedId = selection !== null && selection !== undefined ? selection.id : undefined;
        const command = UpdateChecker.updaterArgs(selectedId).join(" ");

        if (launchFailed) {
            return root.card("error", qsTr("Couldn't start the update"), qsTr("Run %1 in a terminal instead").arg(command), root.action("copy", qsTr("Copy command"), "content_copy"), root.action("terminal", qsTr("Run in terminal"), "open_in_new"), {
                highlight: true
            });
        }

        if (UpdateChecker.handoff === UpdateChecker.Handoff.Running || UpdateChecker.handoff === UpdateChecker.Handoff.Pending) {
            // What the run itself reports, when it reports anything: the stage it is in and
            // how far through the five it is. A minute of silence means the record is left
            // over from a run that stopped, so the state below speaks instead.
            if (UpdateChecker.progressTotal > 0 && root.now - UpdateChecker.progressAtMs < 60000) {
                const step = qsTr("Step %1 of %2").arg(UpdateChecker.progressIndex).arg(UpdateChecker.progressTotal);
                return root.card("sync", UpdateChecker.progressText, step, null, root.action("terminal", qsTr("Run in terminal"), "open_in_new"), {
                    dismissible: true,
                    highlight: true,
                    progress: UpdateChecker.progressFraction
                });
            }
        }

        if (UpdateChecker.handoff === UpdateChecker.Handoff.Running) {
            return root.card("terminal", qsTr("Updating in the terminal"), root.handoffDetail(), root.action("terminal", qsTr("Run in terminal"), "open_in_new"), root.action("copy", qsTr("Copy command"), "content_copy"), {
                dismissible: true,
                highlight: true
            });
        }

        if (UpdateChecker.handoff === UpdateChecker.Handoff.Pending) {
            return root.card("terminal", qsTr("Starting the update…"), qsTr("Running %1").arg(command), root.action("terminal", qsTr("Run in terminal"), "open_in_new"), root.action("copy", qsTr("Copy command"), "content_copy"), {
                dismissible: true,
                highlight: true
            });
        }

        // The updater runs in a terminal this shell cannot see, so its own record of what
        // happened is the only thing that can report the outcome - and the restart it
        // causes is the moment that record is news.
        if (UpdateChecker.handoff === UpdateChecker.Handoff.None && UpdateChecker.lastResultStatus !== "") {
            const label = UpdateChecker.lastResultLabel;
            const named = /^v?\d/.test(label);
            const dismiss = root.action("dismissResult", qsTr("Dismiss"), "close");
            if (UpdateChecker.lastResultStatus === "failed") {
                return root.card("error", qsTr("The last update did not finish"), label === "" ? qsTr("Run the update again to see why") : qsTr("%1 did not finish").arg(label), dismiss, null, {
                    highlight: true
                });
            }
            return root.card("check_circle", named ? qsTr("Updated to %1").arg(label) : qsTr("Update finished"), named && UpdateChecker.lastResultLogout ? qsTr("Log out and back in to load it") : named ? "" : qsTr("The %1 channel was updated").arg(label), null, dismiss, {});
        }

        if (selection !== null && selection !== undefined) {
            const clear = root.action("clear", qsTr("Clear selection"), "close");
            return root.card(root.selectionIcon(selection.state), root.selectionTitle(selection.state, selection.label), root.selectionDetail(selection.state), root.selectionAction(selection.state, selection.label), clear, {
                highlight: true
            });
        }

        if (UpdateChecker.checkingUpdates) {
            return root.card("sync", qsTr("Checking for updates…"), root.baseDetail(), null, null);
        }

        if (UpdateChecker.checkFailed) {
            return root.card("cloud_off", qsTr("Couldn't check for updates"), root.baseDetail(), root.action("check", qsTr("Try again"), "refresh"), null, {
                highlight: true
            });
        }

        if (UpdateChecker.hasUpdate) {
            const latest = root.latestVersion();
            const staged = UpdateChecker.stagedLabel !== "";
            const title = UpdateChecker.versionSummaryMode
                ? (latest !== "" ? qsTr("Caelestia %1 is available").arg(latest) : qsTr("An update is available"))
                : qsTr("%1 new commits on %2").arg(UpdateChecker.pendingCount).arg(UpdateChecker.currentBranch);
            const primary = root.action("install", staged ? qsTr("Restart & Update") : latest !== "" && UpdateChecker.versionSummaryMode ? qsTr("Update to %1").arg(latest) : qsTr("Update now"), "system_update_alt");
            // Downloading first costs the user nothing and takes the slow half off the one
            // click that changes the system. It is only separable where the package manager
            // owns the install, so a checkout keeps its single action.
            const secondary = UpdateChecker.stagedLabel !== "" || !UpdateChecker.packagedUpdate ? root.action("check", qsTr("Check again"), "refresh") : root.action("stage", qsTr("Download first"), "download");
            return root.card("update", title, root.updateDetail(), primary, secondary, {
                highlight: true
            });
        }

        if (!UpdateChecker.checkingEnabled) {
            return root.card("sync_disabled", qsTr("Update checking is off"), root.baseDetail(), root.action("turnOn", qsTr("Turn on"), "sync"), null);
        }

        if (root.versionText() === "") {
            return root.card("help", qsTr("Installed version unknown"), root.baseDetail(), root.action("check", qsTr("Check again"), "refresh"), null);
        }

        return root.card("check_circle", qsTr("You're up to date"), root.baseDetail(), null, root.action("check", qsTr("Check again"), "refresh"));
    }

    Timer {
        interval: 15000
        repeat: true
        running: true
        onTriggered: root.now = Date.now()
    }
}
