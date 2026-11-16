.pragma library

// What the keep-awake widget can ask for. `interval` and `until` both end at a moment and
// differ only in which menu entry set it, so the menu can tick the right one.
var OFF = "off";
var INTERVAL = "interval";
var UNTIL = "until";
var INDEFINITE = "indefinite";

var MODES = [OFF, INTERVAL, UNTIL, INDEFINITE];

function isMode(value) {
    return MODES.indexOf(value) !== -1;
}

/// Whether a hold with this mode ends on its own rather than lasting until it is released.
function ends(mode) {
    return mode === INTERVAL || mode === UNTIL;
}

/// The hold a saved state asks for at `now`, which is not always the one it was saved with:
/// an expiry that passed while the shell was down was never raised this boot, and a file
/// written before the modes existed only carried `enabled`.
function restoredMode(stored, now) {
    const raw = stored && typeof stored === "object" ? stored : {};
    const mode = typeof raw.mode === "string" ? raw.mode : (raw.enabled === true ? INDEFINITE : OFF);
    if (!isMode(mode))
        return OFF;
    if (ends(mode) && !(Number(raw.until) > now))
        return OFF;
    return mode;
}

/// When the restored hold ends, or 0 when it has no end. Anything unreadable is treated as
/// "no end" so a corrupt number cannot invent one.
function restoredUntil(stored, mode) {
    if (!ends(mode))
        return 0;

    const until = Number(stored && stored.until);
    return isFinite(until) && until > 0 ? until : 0;
}

/// Remembered across restarts; a missing or unreadable value keeps the screen on, which is
/// what the widget has always done.
function restoredScreenOn(stored) {
    return !(stored && stored.screenOn === false);
}

function serialize(mode, since, until, screenOn) {
    return JSON.stringify({ mode: mode, since: since, until: until, screenOn: screenOn });
}
