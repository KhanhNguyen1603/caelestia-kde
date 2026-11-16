pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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
    property var state: ({ mode: "off", since: new Date(), until: 0, screenOn: true })

    readonly property bool enabled: root.state.mode !== root.modeOff
    readonly property string mode: root.state.mode
    readonly property date enabledSince: root.state.since
    readonly property bool hasExpiry: root.state.until > 0
    /// When the hold lets go on its own, or null while it is indefinite.
    readonly property var expiresAt: root.hasExpiry ? new Date(root.state.until) : null
    // The compositor's idle inhibitor keeps the display lit as well as the machine awake,
    // so this is a remembered preference rather than a second, separate inhibit.
    readonly property bool keepScreenOn: root.state.screenOn

    function setEnabled(value: bool): void {
        if (value === root.enabled)
            return;

        if (value) {
            root.keepAwakeIndefinitely();
            return;
        }

        root.state = { mode: root.modeOff, since: root.state.since, until: 0, screenOn: root.state.screenOn };
        root.save();
    }

    function keepAwakeIndefinitely(): void {
        root.state = { mode: root.modeIndefinite, since: root.enabled ? root.state.since : new Date(), until: 0, screenOn: root.state.screenOn };
        root.save();
    }

    /// Keeps the machine awake for a while and then lets go on its own.
    function keepAwakeFor(seconds: int): void {
        root.raise(root.modeInterval, Date.now() + Math.max(1, Math.round(seconds)) * 1000);
    }

    /// Keeps the machine awake until the given moment, picked by hand rather than counted.
    function keepAwakeUntil(when: date): void {
        const until = when instanceof Date ? when.getTime() : NaN;
        if (isNaN(until)) {
            Logger.log("[IdleInhibitor] ignoring an unreadable expiry:", when);
            return;
        }

        root.raise(root.modeUntil, until);
    }

    function raise(mode: string, until: real): void {
        // A moment that has already passed is the same request as letting go now.
        if (!(until > Date.now())) {
            root.setEnabled(false);
            return;
        }

        root.state = { mode: mode, since: root.enabled ? root.state.since : new Date(), until: until, screenOn: root.state.screenOn };
        root.save();
    }

    function setKeepScreenOn(value: bool): void {
        if (value === root.state.screenOn)
            return;

        root.state = { mode: root.state.mode, since: root.state.since, until: root.state.until, screenOn: value };
        root.save();
    }

    function save(): void {
        stateFile.setText(root.serialize(root.state));
    }

    function serialize(state: var): string {
        return KeepAwake.serialize(state.mode, state.since.toISOString(), state.until, state.screenOn);
    }

    function restore(text: string): void {
        let stored = null;
        try {
            stored = JSON.parse(text);
        } catch (err) {
            Logger.log("[IdleInhibitor] keep-awake state is unreadable, starting with it off:", err);
        }

        // An unparsable timestamp falls back to now rather than throwing.
        const since = stored?.since ? new Date(stored.since) : new Date();
        const mode = KeepAwake.restoredMode(stored, Date.now());
        root.state = {
            mode: mode,
            since: isNaN(since.getTime()) ? new Date() : since,
            until: KeepAwake.restoredUntil(stored, mode),
            screenOn: KeepAwake.restoredScreenOn(stored)
        };
    }

    // One ticker for the whole shell. A restarted shell still lets go on time, because the
    // moment that was stored is read back rather than a countdown restarted.
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
