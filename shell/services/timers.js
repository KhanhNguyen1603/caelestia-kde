.pragma library

// The countdown's rules: every transition is a value in and a value out, so the service
// only stores the result and acts on the events. A timer is `running`, `paused` or `rang`;
// `paused` holds the seconds it had left, and `rangAt` when it reached zero.

function isRinging(timer) {
    return !!timer && timer.state === "rang";
}

function isPaused(timer) {
    return !!timer && timer.state === "paused";
}

function remaining(timer, now) {
    if (!timer)
        return 0;
    if (isPaused(timer))
        return Math.max(0, Math.round(Number(timer.paused) || 0));
    return Math.max(0, Math.ceil((Number(timer.ends) - Number(now)) / 1000));
}

function progress(timer, now) {
    var total = Number(timer ? timer.total : 0) || 0;
    if (total <= 0)
        return 0;
    return Math.max(0, Math.min(1, 1 - remaining(timer, now) / total));
}

function parseKeypad(text) {
    var digits = String(text ?? "").replace(/[^0-9]/g, "");
    if (digits === "")
        return 0;

    var secs = Number(digits.slice(-2)) || 0;
    if (digits.length <= 2)
        return secs;
    if (digits.length <= 4)
        return (Number(digits.slice(0, -2)) || 0) * 60 + secs;

    var mins = Math.min(59, Number(digits.slice(-4, -2)) || 0);
    var hours = Number(digits.slice(0, -4)) || 0;
    return hours * 3600 + mins * 60 + Math.min(59, secs);
}

function _paused(timer, now) {
    var left = remaining(timer, now);
    if (timer.state !== "running" || left <= 0)
        return timer;
    return Object.assign({}, timer, { state: "paused", paused: left, ends: now + left * 1000 });
}

function _resumed(timer, now) {
    if (!isPaused(timer))
        return timer;
    return Object.assign({}, timer, {
        state: "running",
        ends: now + Math.max(1, Math.round(Number(timer.paused))) * 1000,
        paused: null
    });
}

// apply(list, action, now) -> { list, events }
//
// actions: `{ type: "start", id, seconds, message }`
//          `{ type: "pause" | "resume" | "cancel", ids }`
//          `{ type: "clear" }`
//          `{ type: "sweep" }` — the tick's question, answered with a "rang" event per
//          timer that has reached zero, so the shell announces each one exactly once.
function apply(list, action, now) {
    var at = Number(now);

    if (action.type === "start") {
        var seconds = Number(action.seconds);
        var started = {
            id: String(action.id),
            ends: at + seconds * 1000,
            total: seconds,
            paused: null,
            state: "running",
            rangAt: 0,
            message: String(action.message ?? "").trim()
        };
        return {
            list: list.concat([started]).sort(function (a, b) {
                return a.ends - b.ends;
            }),
            events: []
        };
    }

    if (action.type === "pause" || action.type === "resume" || action.type === "cancel") {
        var ids = (action.ids ?? []).map(String);
        var kept = [];
        for (var i = 0; i < list.length; i++) {
            var timer = list[i];
            if (ids.indexOf(timer.id) < 0) {
                kept.push(timer);
            } else if (action.type === "pause") {
                kept.push(_paused(timer, at));
            } else if (action.type === "resume") {
                kept.push(_resumed(timer, at));
            }
        }
        return { list: kept, events: [] };
    }

    if (action.type === "clear")
        return { list: [], events: [] };

    var events = [];
    var swept = [];
    for (var j = 0; j < list.length; j++) {
        var entry = list[j];
        if (entry.state === "running" && remaining(entry, at) <= 0) {
            var rung = Object.assign({}, entry, { state: "rang", ends: at, rangAt: at });
            swept.push(rung);
            events.push({ type: "rang", timer: rung });
        } else {
            swept.push(entry);
        }
    }
    return { list: swept, events: events };
}
