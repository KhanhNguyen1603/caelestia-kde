.pragma library

function isPaused(timer) {
    return !!timer && timer.paused !== null && timer.paused !== undefined;
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

function format(seconds) {
    var value = Math.max(0, Math.floor(Number(seconds) || 0));
    var mins = Math.floor(value / 60);
    var secs = String(value % 60).padStart(2, "0");
    if (mins >= 60)
        return Math.floor(mins / 60) + ":" + String(mins % 60).padStart(2, "0") + ":" + secs;
    return mins + ":" + secs;
}

function parseDigits(text) {
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

// Splits the running timers into the ones that have ended at `now` and the ones that are
// still going. Pure, and given the clock as a value: the tick asks this once and then
// acts, rather than reading the clock again inside a predicate per timer.
function split(list, now) {
    var at = Number(now);
    var due = [];
    var running = [];
    for (var i = 0; i < list.length; i++) {
        var timer = list[i];
        if (isPaused(timer) || (timer && timer.rang === true))
            running.push(timer);
        else if (remaining(timer, at) <= 0)
            due.push(timer);
        else
            running.push(timer);
    }

    return { due: due, running: running };
}
