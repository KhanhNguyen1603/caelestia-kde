.pragma library

// Where an icon is and how to move it. An icon's place is one of three words, and the
// bar's entry list is the one place that holds it: a row says "off" while it is
// disabled, "tray" while its zone is the box's, and "bar" everywhere else. Icons the
// bar's lists declare rather than place (the status icons, the tray's own apps) answer
// from those lists until a drag writes a row of their own.
//
// Kept free of QML types so the rules can be tested on their own; BarPlacements.qml
// owns the writes.

var OFF = "off";
var TRAY = "tray";
var BAR = "bar";

// The zone a row carries while the icon it stands for is in the box.
var TRAY_ZONE = "tray";
var BAR_ZONE = "right";

function rowOf(rows, id) {
    var list = rows || [];
    for (var i = 0; i < list.length; i++) {
        if (list[i].id === id)
            return list[i];
    }
    return null;
}

// Where a row puts an icon. Without a row, the list that declares the icon decides.
function placeOf(row, fallback) {
    if (!row)
        return fallback;
    if (row.enabled === false)
        return OFF;
    return row.zone === TRAY_ZONE ? TRAY : BAR;
}

// A tray app without a row of its own is placed by its state lists: compact mode keeps
// only the pinned icons on the bar, and a collapsed icon waits in the box.
function trayFallback(state, compact) {
    if (state === "hidden")
        return OFF;
    if (state === "visible")
        return BAR;
    return compact ? TRAY : BAR;
}

// A status icon is placed by the icons list before anything else: switched out of the
// list it is off, whatever a row left behind says.
function statusPlace(enabled, row, fallback) {
    return enabled ? placeOf(row, fallback) : OFF;
}

function sameRows(a, b) {
    var left = a || [];
    var right = b || [];
    if (left.length !== right.length)
        return false;
    for (var i = 0; i < left.length; i++) {
        if (left[i].id !== right[i].id || left[i].enabled !== right[i].enabled || left[i].zone !== right[i].zone)
            return false;
    }
    return true;
}

function declaredIndex(widgets, id) {
    var list = widgets || [];
    for (var i = 0; i < list.length; i++) {
        if (list[i].id === id)
            return i;
    }
    return -1;
}

// Where a row for `id` belongs in the list: beside the neighbours the registry declares
// it with, or in front of the group it was dragged out of.
function insertIndex(rows, id, widgets, anchorId) {
    var list = rows || [];
    var target = declaredIndex(widgets, id);
    if (target >= 0) {
        for (var i = list.length - 1; i >= 0; i--) {
            var other = declaredIndex(widgets, list[i].id);
            if (other >= 0 && other < target)
                return i + 1;
        }
        return 0;
    }
    if (anchorId) {
        for (var j = 0; j < list.length; j++) {
            if (list[j].id === anchorId)
                return j;
        }
    }
    return list.length;
}

// The rows with `row` in place of the one `id` already had, or with a new row where the
// registry's order says it belongs.
function withRow(rows, id, row, widgets, anchorId) {
    var next = (rows || []).slice();
    for (var i = 0; i < next.length; i++) {
        if (next[i].id === id) {
            next[i] = row;
            return next;
        }
    }
    next.splice(insertIndex(next, id, widgets, anchorId), 0, row);
    return next;
}

function withoutRow(rows, id) {
    var list = rows || [];
    for (var i = 0; i < list.length; i++) {
        if (list[i].id === id)
            return list.slice(0, i).concat(list.slice(i + 1));
    }
    return list;
}

// The rows with `id` in front of `beforeId`. Both need a row: an icon the bar draws from
// a group has no row of its own until one is written, and a move needs somewhere to land.
function movedBefore(rows, id, beforeId, widgets, zones, anchorOf) {
    if (!beforeId || id === beforeId)
        return rows || [];
    var ensure = function (list, entryId) {
        if (rowOf(list, entryId))
            return list;
        var declared = (zones || {})[entryId] || BAR_ZONE;
        return withRow(list, entryId, {
            id: entryId,
            enabled: true,
            zone: declared
        }, widgets, anchorOf(entryId));
    };

    var next = ensure(ensure(rows || [], id), beforeId);
    var at = indexOfRow(next, id);
    var moving = next[at];
    var rest = next.slice(0, at).concat(next.slice(at + 1));
    var target = indexOfRow(rest, beforeId);
    return rest.slice(0, target).concat([moving], rest.slice(target));
}

function indexOfRow(rows, id) {
    var list = rows || [];
    for (var i = 0; i < list.length; i++) {
        if (list[i].id === id)
            return i;
    }
    return list.length;
}

// What a request writes, so the caller can apply it in one go: every write makes the bar
// draw all of its widgets again. Each field is null when it does not change.
//
// request = {
//     rows, id, place, beforeId, zone,
//     kind: "trayItem" | "statusIcon" | "widget",
//     declaredZone, widgets, zones, anchorOf,
//     trayKey, compact
// }
function plan(request) {
    var rows = request.rows || [];
    var id = request.id;
    var place = request.place;
    var beforeId = request.beforeId || "";
    var zone = request.zone;
    var declaredZone = request.declaredZone || BAR_ZONE;
    var row = rowOf(rows, id);
    var widgets = request.widgets;
    var zones = request.zones;
    var anchorOf = request.anchorOf || function () {
        return "";
    };

    if (request.kind === "trayItem") {
        // The tray's own lists decide which of its icons exist and where; a row is the
        // override a drag writes. Shown without a place of its own is a state, not a row.
        if (place === TRAY)
            return {
                rows: withoutRow(rows, id),
                trayState: request.compact ? "collapsed" : "hidden",
                trayKey: request.trayKey
            };
        if (place === OFF)
            return {
                rows: withRow(rows, id, {
                    id: id,
                    enabled: false,
                    zone: row ? (row.zone || declaredZone) : declaredZone
                }, widgets, anchorOf(id)),
                trayState: "hidden",
                trayKey: request.trayKey
            };
        if (!beforeId && zone === undefined)
            // Shown is a state rather than a place: a row it already holds is where it
            // shows, and without one the tray's own list puts it on the bar.
            return {
                rows: row ? withRow(rows, id, {
                    id: id,
                    enabled: true,
                    zone: row.zone || declaredZone
                }, widgets, anchorOf(id)) : withoutRow(rows, id),
                trayState: "visible",
                trayKey: request.trayKey
            };
        var onBar = withRow(rows, id, {
            id: id,
            enabled: true,
            zone: zone || BAR_ZONE
        }, widgets, anchorOf(id));
        return {
            rows: beforeId ? movedBefore(onBar, id, beforeId, widgets, zones, anchorOf) : onBar,
            trayState: "visible",
            trayKey: request.trayKey
        };
    }

    // In the box: a row that says so, shown again whatever it said before. A status icon
    // keeps its place in the icons list, so it is switched back on there.
    if (place === TRAY)
        return {
            rows: withRow(rows, id, {
                id: id,
                enabled: true,
                zone: TRAY_ZONE
            }, widgets, anchorOf(id)),
            iconEnabled: request.kind === "statusIcon" ? true : null
        };

    if (request.kind === "statusIcon") {
        // The icons list is whether the icon exists at all; its row only says where.
        if (place === OFF)
            return {
                rows: row ? withRow(rows, id, {
                    id: id,
                    enabled: false,
                    zone: row.zone || declaredZone
                }, widgets, anchorOf(id)) : rows,
                iconEnabled: false
            };
        var switchedOn = row ? withRow(rows, id, {
            id: id,
            enabled: true,
            zone: row.zone || declaredZone
        }, widgets, anchorOf(id)) : rows;
        if (beforeId)
            return {
                rows: movedBefore(withRow(switchedOn, id, {
                    id: id,
                    enabled: true,
                    zone: zone || BAR_ZONE
                }, widgets, anchorOf(id)), id, beforeId, widgets, zones, anchorOf),
                iconEnabled: true
            };
        if (zone === undefined)
            return {
                rows: switchedOn,
                iconEnabled: true
            };
        // Dropped on the bar: its own place in the list again when that is where it
        // already belongs, a row when it is being moved out of the box.
        if (zone === declaredZone)
            return {
                rows: withoutRow(switchedOn, id),
                iconEnabled: true
            };
        return {
            rows: withRow(switchedOn, id, {
                id: id,
                enabled: true,
                zone: zone
            }, widgets, anchorOf(id)),
            iconEnabled: true
        };
    }

    // A widget's row is its place among the bar's icons, so a row always says both.
    if (place === OFF)
        return {
            rows: withRow(rows, id, {
                id: id,
                enabled: false,
                zone: row ? (row.zone || declaredZone) : declaredZone
            }, widgets, anchorOf(id))
        };
    var placed = withRow(rows, id, {
        id: id,
        enabled: true,
        zone: zone || (beforeId ? BAR_ZONE : (row ? (row.zone || declaredZone) : declaredZone))
    }, widgets, anchorOf(id));
    return {
        rows: beforeId ? movedBefore(placed, id, beforeId, widgets, zones, anchorOf) : placed
    };
}
