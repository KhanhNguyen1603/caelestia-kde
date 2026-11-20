pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.utils
import "keepawake.js" as KeepAwake

// Keep-awake outlives the shell. The intent is one value in the runtime directory, so a
// restarted or crashed shell picks it up again, while a reboot or a new login starts clean
// — an inhibitor that outlived a reboot would quietly stop the machine from sleeping.
// `PersistentProperties` cannot carry this: it is written when the shell reloads itself,
// not when the service is stopped.
Singleton {
    id: root

    // How the hold was asked for. `interval` and `until` both end at a moment and differ
    // only in which menu entry set it, so the menu can tick the right one.
    readonly property string modeOff: KeepAwake.OFF
    readonly property string modeInterval: KeepAwake.INTERVAL
    readonly property string modeUntil: KeepAwake.UNTIL
    readonly property string modeIndefinite: KeepAwake.INDEFINITE

    // The mode, the moment it ends and the time it was raised move together, so restoring
    // the file cannot look like a toggle, and no reader can catch half of a change. The
    // functions below are the only way in: writing `enabled` directly would skip the file.
    // `until` is an epoch and 0 means "no end", so it survives a round trip as a number.
    property var state: ({ mode: KeepAwake.OFF, since: new Date(), until: 0 })
    // What was last written, so a change that leaves the state alone does not touch the disk.
    property string savedState: ""

    readonly property bool enabled: root.state.mode !== root.modeOff
    readonly property string mode: root.state.mode
    readonly property date enabledSince: root.state.since
    readonly property bool hasExpiry: root.state.until > 0
    /// When the hold lets go on its own, or null while it is indefinite.
    readonly property var expiresAt: root.hasExpiry ? new Date(root.state.until) : null

    /// How the current hold reads in the bar chip and in the utilities card. Owned here
    /// because it is the same question in both places, and a service may carry its own
    /// wording (`Timers` does).
    readonly property string periodText: root.hasExpiry
        ? qsTr("Until %1").arg(Time.clockTime(root.expiresAt))
        : qsTr("Active since %1").arg(Time.clockTime(root.enabledSince))
    /// The card's one-line description of what the inhibitor is doing.
    readonly property string summaryText: !root.enabled
        ? qsTr("Normal power management")
        : root.hasExpiry
            ? qsTr("Preventing sleep until %1").arg(Time.clockTime(root.expiresAt))
            : qsTr("Preventing sleep mode")

    function setEnabled(value: bool): void {
        root.state = value
            ? { mode: root.modeIndefinite, since: root.enabled ? root.state.since : new Date(), until: 0 }
            : { mode: root.modeOff, since: root.state.since, until: 0 };
        root.save();
    }

    /// Keeps the machine awake for a while and then lets go on its own.
    function keepAwakeFor(seconds: int): void {
        root.raise(root.modeInterval, Date.now() + Math.max(1, Math.round(seconds)) * 1000);
    }

    /// Keeps the machine awake until the given moment, picked by hand rather than counted.
    function keepAwakeUntil(when: date): void {
        root.raise(root.modeUntil, when instanceof Date ? when.getTime() : NaN);
    }

    function raise(mode: string, until: real): void {
        // A moment that has already passed is a request this cannot honour. Dropping a hold
        // the caller did not ask to end would be a state change dressed up as a rejection.
        if (!(until > Date.now())) {
            Logger.log("[IdleInhibitor] ignoring an expiry that is not in the future:", until);
            return;
        }

        root.state = { mode: mode, since: root.enabled ? root.state.since : new Date(), until: until };
        root.save();
    }

    function save(): void {
        const data = KeepAwake.serialize(root.state);
        if (data === root.savedState)
            return;

        root.savedState = data;
        stateFile.setText(data);
    }

    function restore(text: string): void {
        let stored = null;
        try {
            stored = JSON.parse(text);
        } catch (err) {
            Logger.log("[IdleInhibitor] keep-awake state is unreadable, starting with it off:", err);
        }

        root.state = KeepAwake.restore(stored, Date.now());
        root.savedState = KeepAwake.serialize(root.state);
    }

    // One ticker for the whole shell. Not a one-shot armed to the expiry: QML timers are
    // monotonic, so a long sleep would fire one late, while comparing the wall clock again
    // every second lets go within a second of the machine waking.
    Timer {
        interval: 1000
        repeat: true
        running: root.hasExpiry
        triggeredOnStart: true
        onTriggered: {
            if (root.hasExpiry && root.state.until <= Date.now())
                root.setEnabled(false);
        }
    }

    IdleInhibitor {
        enabled: root.enabled
        window: PanelWindow {
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            mask: Region {}
        }
    }

    FileView {
        id: stateFile

        path: Paths.runtimeTemp("keepawake.json")
        watchChanges: false
        printErrors: false

        onLoaded: root.restore(stateFile.text())
    }

    IpcHandler {
        function isEnabled(): bool {
            return root.enabled;
        }

        function toggle(): void {
            root.setEnabled(!root.enabled);
        }

        function enable(): void {
            root.setEnabled(true);
        }

        function disable(): void {
            root.setEnabled(false);
        }

        /// Keeps the machine awake for this many seconds, e.g. `1800` for half an hour.
        function setFor(seconds: int): void {
            root.keepAwakeFor(seconds);
        }

        /// Seconds left before an expiring hold lets go, or -1 while it is indefinite.
        function remaining(): int {
            return root.hasExpiry ? Math.max(0, Math.round((root.state.until - Date.now()) / 1000)) : -1;
        }

        target: "idleInhibitor"
    }
}
