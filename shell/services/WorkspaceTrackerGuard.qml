pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.services

// The workspace-tracker effect is compiled against KWin's internals, so a KDE
// update can leave the installed binary unloadable and the shell silently
// without per-output desktops.
Singleton {
    id: root

    readonly property string checkScript: Quickshell.shellPath("scripts/check-workspace-tracker.sh")

    function report(detail: string): void {
        if (detail === memory.announced)
            return;

        memory.announced = detail;
        // The toast is one elided title line above a box ~410px wide, so the message
        // stays to a sentence: what KWin refused, and the one command that fixes it.
        Toaster.toast(qsTr("Desktop tracking is off"), qsTr("KWin refused the workspace tracker (%1). Run caelestia update.").arg(detail), "extension_off", Toast.Warning);
    }

    // The failure already announced. The same mismatch comes back at every login until the
    // effect is rebuilt, and a toast that covers the panels each time is worse than the
    // thing it reports; a working check clears it, so a later breakage is news again.
    PersistentProperties {
        id: memory

        property string announced: ""

        reloadableId: "workspaceTracker"
    }

    // KWin loads its effects long before the shell starts, so the delay only
    // covers a login that brings both up at once.
    Timer {
        interval: 5000
        running: true

        onTriggered: check.running = true
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
                memory.announced = "";
                return;
            }

            const detail = check.reason.length > 0 ? check.reason : qsTr("no reason given");
            console.warn(`[WorkspaceTrackerGuard] workspace tracker not loaded: ${detail}`);
            root.report(detail);
        }
    }
}
