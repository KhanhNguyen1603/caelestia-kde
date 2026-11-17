pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.services
import qs.utils

// The workspace-tracker effect is compiled against KWin's internals, so a KDE
// update can leave the installed binary unloadable and the shell silently
// without per-output desktops.
Singleton {
    id: root

    readonly property string checkScript: Quickshell.shellPath("scripts/check-workspace-tracker.sh")
    property string announced: ""
    property bool loaded: false
    property string pending: ""

    function report(detail: string): void {
        if (!root.loaded) {
            root.pending = detail;
            return;
        }

        if (detail === root.announced)
            return;

        root.announced = detail;
        storage.setText(JSON.stringify({
                announced: detail
            }));
        // The toast is one elided title line above a box ~410px wide, so the message
        // stays to a sentence: what KWin refused, and the one command that fixes it.
        Toaster.toast(qsTr("Desktop tracking is off"), qsTr("KWin refused the workspace tracker (%1). Run caelestia update.").arg(detail), "extension_off", Toast.Warning);
    }

    function clearAnnouncement(): void {
        if (!root.loaded || root.announced === "")
            return;

        root.announced = "";
        storage.setText(JSON.stringify({
                announced: ""
            }));
    }

    function finish(): void {
        root.loaded = true;
        if (root.pending === "")
            return;

        const detail = root.pending;
        root.pending = "";
        root.report(detail);
    }

    // KWin loads its effects long before the shell starts, so the delay only
    // covers a login that brings both up at once.
    Timer {
        interval: 5000
        running: true

        onTriggered: check.running = true
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.state}/workspace-tracker.json`

        onLoaded: {
            try {
                root.announced = String(JSON.parse(text()).announced ?? "");
            } catch (err) {
                root.announced = "";
            }
            root.finish();
        }

        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                Logger.log("[WorkspaceTrackerGuard] could not read what was announced:", err);
            root.finish();
        }
    }

    Process {
        id: check

        // The script says why it gave up on stdout, so the message can name the
        // versions rather than only reporting that something is missing.
        readonly property string reason: String(out.text ?? "").trim()

        command: ["bash", root.checkScript]
        stdout: StdioCollector {
            id: out
        }

        onExited: code => {
            if (code !== 3) {
                root.clearAnnouncement();
                return;
            }

            const detail = check.reason.length > 0 ? check.reason : qsTr("no reason given");
            console.warn(`[WorkspaceTrackerGuard] workspace tracker not loaded: ${detail}`);
            root.report(detail);
        }
    }
}
