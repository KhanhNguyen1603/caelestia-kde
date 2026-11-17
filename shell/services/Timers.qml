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
///
/// The transitions themselves live in timers.js: this holds the list, the ticker and the
/// two things that happen outside the list — a notification per timer that ends, and the
/// alarm while one is waiting to be dismissed.
Singleton {
    id: root

    /// `{ id, ends, total, paused, state, rangAt, message }`, soonest first. A timer cannot
    /// outlive its message, so only what it takes to run and to say is stored.
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

    /// The timer the card shows in large type: the pinned one, or the one ending soonest.
    readonly property var activeTimer: {
        if (root.count === 0)
            return null;
        if (root.pinnedId !== "")
            return root.list.find(timer => timer.id === root.pinnedId) ?? root.list[0];
        return root.list[0];
    }
    /// Everything the card lists under that countdown.
    readonly property var others: root.list.filter(timer => timer.id !== root.activeTimer?.id)
    readonly property bool ringing: root.list.some(TimerList.isRinging)
    readonly property int alarmDuration: Math.max(0, GlobalConfig.services.timerAlarmDuration)
    readonly property bool alarmUntilDismissed: GlobalConfig.services.timerAlarmUntilDismissed
    readonly property string alarmSound: String(GlobalConfig.services.timerAlarmSound ?? "")

    function remaining(timer: var): int {
        return TimerList.remaining(timer, root.now);
    }

    function progress(timer: var): real {
        return TimerList.progress(timer, root.now);
    }

    function formatted(timer: var): string {
        return Units.formatDuration(root.remaining(timer));
    }

    /// The digits the card's field holds, read the way a timer keypad is.
    function parseKeypad(text: string): int {
        return TimerList.parseKeypad(text);
    }

    /// A duration as someone types one (`25m`, `1h30`), which is what a command line has
    /// room for. The grammar lives in duration.js so a test can run it without a shell.
    function parseTypedDuration(text: string): int {
        return Duration.parse(text);
    }

    /// Keeps the pinned timer pinned while it exists, and otherwise pins the only one left.
    function settlePinned(): void {
        if (root.pinnedId !== "" && root.list.some(timer => timer.id === root.pinnedId))
            return;

        root.pinnedId = root.list.length === 1 ? root.list[0].id : "";
    }

    function dispatch(action: var, at: double): var {
        const result = TimerList.apply(root.list, action, at);
        root.now = at;
        root.list = result.list;
        root.settlePinned();
        return result.events;
    }

    function start(seconds: int, message: string): void {
        if (seconds <= 0)
            return;

        root.dispatch({
                type: "start",
                id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
                seconds: seconds,
                message: message
            }, Date.now());
    }

    function pause(id: string): void {
        root.dispatch({ type: "pause", ids: [id] }, Date.now());
    }

    function resume(id: string): void {
        root.dispatch({ type: "resume", ids: [id] }, Date.now());
    }

    function toggle(id: string): void {
        const timer = root.list.find(entry => entry.id === id);
        if (!timer)
            return;

        root.dispatch({ type: TimerList.isPaused(timer) ? "resume" : "pause", ids: [id] }, Date.now());
    }

    function cancel(id: string): void {
        root.dispatch({ type: "cancel", ids: [id] }, Date.now());
    }

    function clear(): void {
        root.dispatch({ type: "clear" }, Date.now());
    }

    function pin(id: string): void {
        root.pinnedId = root.pinnedId === id ? "" : id;
        root.save();
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
        const at = Date.now();
        for (const event of root.dispatch({ type: "sweep" }, at))
            root.announce(String(event.timer.message));

        root.ring(at);
    }

    /// The chime at zero, repeated for as long as the alarm is set to sound. Once it has had
    /// its say the timer is dropped, so a countdown left unattended stops ringing on its own;
    /// with the alarm set to wait for a dismissal it stays until someone answers it.
    function ring(at: double): void {
        const sounding = root.list.filter(TimerList.isRinging);
        if (sounding.length === 0)
            return;

        if (!root.alarmUntilDismissed) {
            const stale = sounding.filter(timer => at - Number(timer.rangAt) >= root.alarmDuration * 1000).map(timer => timer.id);
            if (stale.length > 0)
                root.dispatch({ type: "cancel", ids: stale }, at);
            if (stale.length === sounding.length)
                return;
        }

        if (!Audio.playSystemSound(root.alarmSound, GlobalConfig.audio.sounds.notificationVolume))
            Audio.playNotification();
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
            data = data.filter(timer => timer && isFinite(Number(timer.ends))).map(timer => {
                const left = timer.paused === null || timer.paused === undefined ? null : Math.max(0, Number(timer.paused));
                return {
                    id: String(timer.id ?? timer.ends),
                    ends: Number(timer.ends),
                    total: Math.max(0, Number(timer.total ?? 0)),
                    paused: left,
                    state: left === null ? "running" : "paused",
                    rangAt: 0,
                    message: String(timer.message ?? ""),
                    pinned: Boolean(timer.pinned)
                };
            });

            // A timer that ran out while the shell was down already happened: say so
            // once, rather than firing a burst of toasts the moment the shell starts. A
            // paused timer is kept whatever its deadline says, because its clock is stopped.
            const ended = data.filter(timer => timer.state === "running" && timer.ends <= Date.now());
            root.list = data.filter(timer => timer.state === "paused" || timer.ends > Date.now()).sort((a, b) => a.ends - b.ends);
            const savedPinned = root.list.find(timer => timer.pinned);
            if (savedPinned)
                root.pinnedId = savedPinned.id;
            else
                root.settlePinned();
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
            root.start(root.parseTypedDuration(duration), message);
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
