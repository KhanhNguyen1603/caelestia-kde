pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.utils
import "duration.js" as Duration
import "timers.js" as TimerList

/// The countdown timers that are running, how long they have left, and what to say
/// when one ends.
///
/// A timer stores the moment it ends rather than the time left, and that moment is what
/// is written to disk: a timer set for 25 minutes still has 23 left if the shell restarts
/// two minutes later, which a counter reset on reload would quietly lose. One ticker runs
/// for all of them.
Singleton {
    id: root

    /// `{ id, ends, message }`, soonest first. A timer cannot outlive its message, so
    /// only what it takes to run and to say is stored.
    ///
    /// A plain `var` array, not `list<var>`: the elements of a `list<var>` are views of
    /// the sequence, so an array of them taken before `list` is reassigned silently reads
    /// the *new* contents afterwards. That is how the wrong timer got announced.
    property var list: []
    property string pinnedId: ""
    /// Read so that every view showing a countdown recomputes with the ticker.
    property double now: Date.now()
    property bool loaded: false
    property string savedState: ""

    readonly property int count: root.list.length
    readonly property string appName: qsTr("Timers")

    readonly property var activeTimer: {
        if (root.count === 0)
            return null;
        if (root.pinnedId !== "")
            return root.list.find(timer => timer.id === root.pinnedId) ?? root.list[0];
        return root.list[0];
    }
    readonly property var others: root.list.filter(timer => timer.id !== root.activeTimer?.id)
    readonly property bool ringing: root.list.some(timer => timer.rang === true)
    readonly property int alarmDuration: Math.max(0, GlobalConfig.services.timerAlarmDuration ?? 10)
    readonly property bool alarmUntilDismissed: GlobalConfig.services.timerAlarm === true
    property var alarmSounds: []
    readonly property string alarmSoundRoot: "/usr/share/sounds/"
    readonly property string alarmSound: String(GlobalConfig.services.timerAlarmSound ?? "")

    function remaining(timer: var): int {
        return TimerList.remaining(timer, root.now);
    }

    function progress(timer: var): real {
        return TimerList.progress(timer, root.now);
    }

    function paused(timer: var): bool {
        return TimerList.isPaused(timer);
    }

    function formatted(timer: var): string {
        return TimerList.format(root.remaining(timer));
    }

    function parseDigits(text: string): int {
        return TimerList.parseDigits(text);
    }

    function alarmSoundPath(name: string): string {
        return root.alarmSoundRoot + name;
    }

    function chime(): void {
        if (root.alarmSound !== "" && root.alarmSounds.indexOf(root.alarmSound) >= 0) {
            Audio.playSystemSound(root.alarmSoundPath(root.alarmSound), GlobalConfig.audio.sounds.notificationVolume);
            return;
        }

        Audio.playNotification();
    }

    function start(seconds: int, message: string): void {
        if (seconds <= 0)
            return;

        const timer = {
            id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
            ends: Date.now() + seconds * 1000,
            total: seconds,
            paused: null,
            rang: false,
            rangAt: 0,
            message: message.trim()
        };
        root.list = [...root.list, timer].sort((a, b) => a.ends - b.ends);
        if (root.list.length === 1)
            root.pinnedId = timer.id;
    }

    function pause(id: string): void {
        const timer = root.list.find(entry => entry.id === id);
        if (!timer || TimerList.isPaused(timer))
            return;

        const now = Date.now();
        const left = TimerList.remaining(timer, now);
        if (left <= 0)
            return;

        root.now = now;
        const ends = now + left * 1000;
        root.list = root.list.map(entry => entry.id === id ? Object.assign({}, entry, { ends: ends, paused: left }) : entry);
    }

    function resume(id: string): void {
        const now = Date.now();
        root.now = now;
        root.list = root.list.map(timer => {
            if (timer.id !== id || !TimerList.isPaused(timer))
                return timer;
            return Object.assign({}, timer, {
                ends: now + Math.max(1, Math.round(Number(timer.paused))) * 1000,
                paused: null
            });
        });
    }

    function toggle(id: string): void {
        const timer = root.list.find(entry => entry.id === id);
        if (!timer)
            return;

        if (TimerList.isPaused(timer))
            root.resume(id);
        else
            root.pause(id);
    }

    function cancel(id: string): void {
        root.list = root.list.filter(timer => timer.id !== id);
        if (root.pinnedId === id)
            root.pinnedId = root.list.length === 1 ? root.list[0].id : "";
        else if (root.list.length === 1 && !root.pinnedId)
            root.pinnedId = root.list[0].id;
    }

    function clear(): void {
        root.list = [];
        root.pinnedId = "";
    }

    function pin(id: string): void {
        root.pinnedId = root.pinnedId === id ? "" : id;
        root.save();
    }

    /// Reads a duration the way someone types one. The grammar lives in duration.js, so a
    /// test can run it without a shell.
    function parseDuration(text: string): int {
        return Duration.parse(text);
    }

    function announce(message: string): void {
        Notifs.addShellNotification({
            appName: root.appName,
            summary: qsTr("Timer finished"),
            body: message.length > 0 ? message : qsTr("Time is up."),
            materialIcon: "timer"
        });
    }

    function tick(): void {
        // The clock is read once and handed over as a value, and what fired is read out
        // before the list is rewritten: see the note on `list` for why the order matters.
        const now = Date.now();
        root.now = now;

        const split = TimerList.split(root.list, now);
        if (split.due.length > 0) {
            const finished = split.due.map(timer => String(timer.message));
            root.list = root.list.map(timer => split.due.some(due => due.id === timer.id) ? Object.assign({}, timer, { ends: now, rang: true, rangAt: now }) : timer);

            // One notification per timer that ends while the shell is running: each message
            // is still news. The load path below batches instead, because those timers ended
            // while nobody was watching and their messages are one fact, not several.
            for (let i = 0; i < finished.length; i++)
                root.announce(finished[i]);
        }

        root.ring(now);
    }

    function ring(now: double): void {
        let sounding = root.list.filter(timer => timer.rang === true);
        if (sounding.length === 0)
            return;

        if (!root.alarmUntilDismissed) {
            const stale = sounding.filter(timer => now - Number(timer.rangAt ?? now) >= root.alarmDuration * 1000);
            if (stale.length > 0) {
                for (const timer of stale)
                    root.cancel(timer.id);
                sounding = sounding.filter(timer => !stale.some(gone => gone.id === timer.id));
            }
            if (sounding.length === 0)
                return;
        }

        root.chime();
    }

    function serialize(): string {
        return JSON.stringify(root.list.map(timer => ({
                        id: timer.id,
                        ends: timer.ends,
                        total: timer.total,
                        paused: timer.paused ?? null,
                        message: timer.message,
                        pinned: timer.id === root.pinnedId
                    })));
    }

    function save(): void {
        const data = root.serialize();
        if (data === root.savedState)
            return;
        root.savedState = data;
        storage.setText(data);
    }

    onListChanged: {
        if (root.loaded)
            root.save();
    }

    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.count > 0
        onTriggered: root.tick()
    }

    Process {
        id: soundScan

        running: true
        command: ["bash", "-c", "find -L /usr/share/sounds -type f \\( -name '*.ogg' -o -name '*.oga' -o -name '*.wav' \\) 2>/dev/null | sed 's|^/usr/share/sounds/||' | LC_ALL=C sort"]

        stdout: StdioCollector {
            onStreamFinished: root.alarmSounds = String(text ?? "").trim().split("\n").filter(name => name.length > 0)
        }
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.state}/timers.json`

        onLoaded: {
            let data;
            try {
                data = JSON.parse(text());
            } catch (err) {
                Logger.log("[Timers] saved timers are corrupt, starting fresh:", err);
                data = [];
            }
            if (!Array.isArray(data))
                data = [];

            // Anything saved by an older version, or by hand, has to carry a real end
            // time: a timer that cannot say when it ends can never fire.
            data = data.filter(timer => timer && isFinite(Number(timer.ends))).map(timer => ({
                            id: String(timer.id ?? timer.ends),
                            ends: Number(timer.ends),
                            total: Math.max(0, Number(timer.total ?? 0)),
                            paused: timer.paused === null || timer.paused === undefined ? null : Math.max(0, Number(timer.paused)),
                            rang: false,
                            rangAt: 0,
                            message: String(timer.message ?? ""),
                            pinned: Boolean(timer.pinned)
                        }));

            // A timer that ran out while the shell was down already happened: say so
            // once, rather than firing a burst of toasts the moment the shell starts.
            const ended = data.filter(timer => !TimerList.isPaused(timer) && timer.ends <= Date.now());
            root.list = data.filter(timer => TimerList.isPaused(timer) || timer.ends > Date.now()).sort((a, b) => a.ends - b.ends);
            const savedPinned = root.list.find(timer => timer.pinned);
            if (savedPinned)
                root.pinnedId = savedPinned.id;
            else if (root.list.length === 1)
                root.pinnedId = root.list[0].id;
            else
                root.pinnedId = "";
            root.loaded = true;
            root.savedState = root.serialize();

            if (ended.length === 1)
                root.announce(ended[0].message);
            else if (ended.length > 1)
                root.announce(qsTr("%1 timers finished while the shell was not running.").arg(ended.length));
        }

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.loaded = true;
                root.savedState = "[]";
                Qt.callLater(() => storage.setText("[]"));
                return;
            }

            // A file that cannot be read cannot be honoured either. Saying so and carrying
            // on beats never writing a timer again: the timers still tick, so the session
            // has to be able to save what comes next.
            Logger.log("[Timers] could not read the saved timers:", err);
            root.loaded = true;
            root.savedState = "[]";
        }
    }

    IpcHandler {
        function start(seconds: int, message: string): void {
            root.start(seconds, message);
        }

        /// Starts a timer from a duration as typed, e.g. `25m`, `1h30` or `90s`.
        function startFor(duration: string, message: string): void {
            root.start(root.parseDuration(duration), message);
        }

        function pause(id: string): void {
            root.pause(id);
        }

        function resume(id: string): void {
            root.resume(id);
        }

        function toggle(id: string): void {
            root.toggle(id);
        }

        function toggleActive(): void {
            if (root.activeTimer)
                root.toggle(root.activeTimer.id);
        }

        function cancel(id: string): void {
            root.cancel(id);
        }

        function clear(): void {
            root.clear();
        }

        /// The running timers, soonest first, with the seconds each has left.
        function list(): string {
            return JSON.stringify(root.list.map(timer => ({
                            id: timer.id,
                            message: timer.message,
                            remaining: root.remaining(timer)
                        })));
        }

        target: "timers"
    }
}
