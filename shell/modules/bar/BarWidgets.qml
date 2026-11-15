pragma Singleton

import QtQuick
import Caelestia.Config
import qs.services

QtObject {
    id: root

    readonly property list<var> widgets: [
        { id: "logo", zone: "left" },
        { id: "workspaces", zone: "left" },
        { id: "greeter", zone: "left" },
        { id: "dock", zone: "middle" },
        { id: "tray", zone: "right" },
        { id: "updateIndicator", zone: "right" },
        { id: "github", zone: "right" },
        { id: "media", zone: "right" },
        { id: "clock", zone: "right" },
        { id: "statusIcons", zone: "right" },
        { id: "kbLayoutIndicator", zone: "right" },
        { id: "notificationsIndicator", zone: "right" },
        { id: "perfCpu", zone: "right" },
        { id: "perfMemory", zone: "right" },
        { id: "perfStorage", zone: "right" },
        { id: "perfNetwork", zone: "right" },
        { id: "perfGpu", zone: "right" },
        { id: "perfBattery", zone: "right" },
        { id: "power", zone: "right" },
        { id: "notes", zone: "right" },
        { id: "performance", zone: "right" },
        { id: "weather", zone: "right" },
        { id: "shortcuts", zone: "right" },
        { id: "screencapture", zone: "right" },
        { id: "keepawake", zone: "right" }
    ]

    // Built-ins plus the widgets plugins registered through their manifest.
    // A plugin cannot shadow a built-in id: the built-in keeps its slot.
    readonly property var allWidgets: {
        const taken = {};
        for (const widget of root.widgets)
            taken[widget.id] = true;

        const plugins = [];
        for (const widget of BarWidgetRegistry.widgets) {
            if (!taken[widget.id])
                plugins.push({ id: widget.id, zone: widget.defaultZone ?? "right" });
        }

        return root.widgets.concat(plugins);
    }

    readonly property var byId: {
        const widgets = {};
        root.allWidgets.forEach((widget, index) => widgets[widget.id] = Object.assign({ index: index }, widget));
        return widgets;
    }

    readonly property var ids: root.allWidgets.map(widget => widget.id)

    // A widget dragged out of the tray lives here: it keeps its place in the
    // config, but no zone draws it, so the hidden-icons box is the only place it
    // appears until it is dragged back.
    readonly property string overflowZone: "tray"

    // The box animates the tiles it holds, and an entry recomputed into a fresh
    // object every time would rebuild its tile instead of moving it. Entries are kept
    // by id here and only replaced when the widget they stand for changes kind.
    readonly property var overflowCache: ({})

    // The status icons are drawn one widget per icon, so that each of them can be
    // dragged into the box on its own. Which icons exist, and in what order, is the
    // `bar.statusIcons` list; a row in `bar.entries` under an icon's own id is the
    // override a drag writes, and the `statusIcons` row is the group's anchor.
    readonly property string statusIconPrefix: "statusIcon:"

    function statusIconId(id: string): string {
        return id.startsWith(root.statusIconPrefix) ? id.substring(root.statusIconPrefix.length) : "";
    }

    // Whether an icon has anything to say right now: the list says which icons the
    // user wants on the bar, this says whether the machine has one to show.
    function statusIconActive(id: string): bool {
        switch (id) {
        case "lockStatus":
            return Kwin.capsLock || Kwin.numLock;
        case "privacy":
            return Privacy.inUse;
        case "kbLayout":
            return (Kwin.kbLayout || "").length > 0;
        case "network":
            return !Nmcli.activeEthernet || Config.bar.status.showWifi;
        case "ethernet":
            return Nmcli.activeEthernet;
        case "nightlight":
            return HyprSunset.active;
        case "audio":
        case "microphone":
        case "bluetooth":
        case "battery":
        case "peripheralBattery":
        case "notifications":
            return true;
        default:
            return false;
        }
    }

    function statusIconEntries(node: var): var {
        const raw = root.entriesOf(node);
        const overrides = {};
        for (const entry of raw) {
            const iconId = root.statusIconId(entry.id);
            if (iconId.length > 0)
                overrides[iconId] = entry;
        }
        const anchor = raw.find(entry => entry.id === "statusIcons") ?? {};

        const entries = [];
        for (const icon of Config.bar.statusIcons.values ?? []) {
            if (!icon.enabled || !root.statusIconActive(icon.id))
                continue;
            const override = overrides[icon.id];
            entries.push({
                id: root.statusIconPrefix + icon.id,
                kind: "statusIcon",
                enabled: override ? override.enabled !== false : true,
                zone: override?.zone ?? anchor.zone ?? "right",
                systemTray: false,
                draggable: true
            });
        }
        return entries;
    }

    // What the bar draws: the configured entries with the status-icons group
    // expanded into the icons it holds. Only the readers expand; the writers below
    // stay on `entriesOf`, so writing a zone back never turns the expansion into
    // config.
    function viewEntries(node: var): var {
        const raw = root.entriesOf(node);
        const entries = [];
        let expanded = false;
        for (const entry of raw) {
            if (root.statusIconId(entry.id).length > 0)
                continue;
            if (entry.id === "statusIcons") {
                entries.push(...root.statusIconEntries(node));
                expanded = true;
                continue;
            }
            entries.push(entry);
        }
        // An icon row outlives the group row it was dragged out of, so icons sent
        // to the box keep belonging to the box even without their anchor.
        if (!expanded && raw.some(entry => root.statusIconId(entry.id).length > 0))
            entries.push(...root.statusIconEntries(node));
        return entries;
    }

    function widget(id: string): var {
        const known = root.byId[id];
        if (known !== undefined)
            return known;

        // A status icon is a widget in its own right, declared by the status-icons
        // list rather than by the list above, so it is answered here.
        const iconId = root.statusIconId(id);
        if (iconId.length === 0 || !(Config.bar.statusIcons.values ?? []).some(icon => icon.id === iconId))
            return null;
        return {
            id: id,
            kind: "statusIcon",
            zone: "right",
            index: root.byId.statusIcons?.index ?? 0
        };
    }

    function isKnown(id: string): bool {
        return root.widget(id) !== null;
    }

    function entriesOf(node: var): var {
        return node.entries ?? [];
    }

    function zoneEntries(entries: var, zone: string): var {
        return (entries ?? []).filter(entry => entry.enabled
            && entry.id !== "spacer"
            && root.isKnown(entry.id)
            && (zone === "left" ? !entry.zone || entry.zone === "left" : entry.zone === zone));
    }

    // A delegate can only require a role every entry provides, so the bar hands
    // the view entries that always carry the fields a tray needs. `kind` is what
    // the delegate chooser picks on: the widget id, unless an entry says otherwise.
    function normalizedEntries(entries: var, zone: string): var {
        return (entries ?? []).map(entry => Object.assign({}, entry, {
            kind: entry.kind ?? entry.id,
            zone: entry.zone ?? zone,
            systemTray: false,
            draggable: false
        }));
    }

    function normalizedZoneEntries(node: var, zone: string): var {
        return root.normalizedEntries(root.zoneEntries(root.viewEntries(node), zone), zone);
    }

    // The right end of the bar is one tray, then the clock, then the power button
    // where Windows puts shutdown. Everything else the user put in that zone is
    // drawn inside the tray, so adding a widget there cannot grow a second row of
    // orphan icons.
    function rightLayoutEntries(node: var): var {
        const entries = root.zoneEntries(root.viewEntries(node), "right");
        const trayContent = entries.filter(entry => entry.id !== "clock" && entry.id !== "power" && entry.id !== "tray");
        const model = [];
        if (entries.some(entry => entry.id === "tray") || trayContent.length > 0)
            model.push({ id: "tray", kind: "tray", enabled: true, zone: "right", systemTray: true, draggable: false });
        model.push(...root.normalizedEntries(entries.filter(entry => entry.id === "clock"), "right"));
        model.push(...root.normalizedEntries(entries.filter(entry => entry.id === "power"), "right"));
        return model;
    }

    // Widgets the tray owns, in the order the user arranged them. The tray entry
    // itself is the container, and the clock and power stay outside it. Everything
    // here is draggable into the hidden-icons box.
    function systemTrayEntries(node: var): var {
        return root.normalizedEntries(root.zoneEntries(root.viewEntries(node), "right")
            .filter(entry => entry.id !== "clock" && entry.id !== "power" && entry.id !== "tray"), "right")
            .map(entry => Object.assign(entry, { draggable: true }));
    }

    function systemTrayShowsIcons(node: var): bool {
        return root.zoneEntries(root.viewEntries(node), "right").some(entry => entry.id === "tray");
    }

    function overflowWidgets(node: var): var {
        const hidden = [];
        const cache = root.overflowCache;
        let index = 0;
        for (const entry of root.viewEntries(node)) {
            if (entry.zone !== root.overflowZone || !root.isKnown(entry.id) || entry.id === "tray")
                continue;
            const kind = entry.kind ?? entry.id;
            const reused = cache[entry.id];
            const widget = reused && reused.kind === kind ? reused : {
                id: entry.id,
                kind: kind,
                enabled: true,
                zone: root.overflowZone,
                systemTray: false,
                draggable: true,
                index: index
            };
            cache[entry.id] = widget;
            hidden.push(widget);
            index++;
        }
        return hidden;
    }

    function isEnabled(node: var, id: string): bool {
        for (const entry of root.entriesOf(node)) {
            if (entry.id === id)
                return entry.enabled === true;
        }
        return false;
    }

    function zoneFor(node: var, id: string): string {
        for (const entry of root.entriesOf(node)) {
            if (entry.id === id)
                return entry.zone ?? root.widget(id)?.zone ?? "left";
        }
        return root.widget(id)?.zone ?? "left";
    }

    function setEnabled(node: var, id: string, enabled: bool): void {
        const entries = root.entriesOf(node);
        const zone = root.widget(id)?.zone ?? "left";
        const next = [];
        let found = false;

        for (const entry of entries) {
            if (entry.id !== id || found) {
                next.push(entry);
                continue;
            }

            found = true;
            next.push({ id: id, enabled: enabled, zone: entry.zone ?? zone });
        }

        if (!found)
            next.splice(root.indexFor(entries, id), 0, { id: id, enabled: enabled, zone: zone });

        node.entries = next;
    }

    function setZone(node: var, id: string, zone: string): void {
        const entries = root.entriesOf(node);
        const fallback = root.widget(id)?.zone ?? "left";
        const next = [];
        let found = false;

        for (const entry of entries) {
            if (entry.id !== id || found) {
                next.push(entry);
                continue;
            }

            found = true;
            next.push({ id: id, enabled: entry.enabled === true, zone: zone });
        }

        if (!found)
            next.splice(root.indexFor(entries, id), 0, { id: id, enabled: true, zone: zone });

        node.entries = next;
    }

    // The two moves a drag between the tray and its hidden-icons box performs. A
    // widget coming back to the bar is shown again even if it had been switched
    // off, because the drag is the request to see it.
    function setInTray(node: var, id: string): void {
        root.setZone(node, id, root.overflowZone);
    }

    function setOnBar(node: var, id: string): void {
        root.setEnabled(node, id, true);
        root.setZone(node, id, "right");
    }

    function replaceAll(node: var, entries: var): void {
        node.entries = entries.slice();
    }

    // Where a dragged widget lands: in the place of the widget it was dropped on. The
    // entry keeps its zone and enabled flag, so this is a move and not a re-add; a
    // widget the list does not hold yet is inserted rather than ignored. Status icons
    // are drawn in the order of the icons list, so two of them move there instead.
    function moveBefore(node: var, id: string, beforeId: string): void {
        if (id === beforeId)
            return;

        const iconId = root.statusIconId(id);
        const beforeIconId = root.statusIconId(beforeId);
        if (iconId.length > 0 && beforeIconId.length > 0) {
            root.moveStatusIconBefore(iconId, beforeIconId);
            return;
        }

        const entries = root.entriesOf(node);
        const moving = entries.find(entry => entry.id === id) ?? {
            id: id,
            enabled: true,
            zone: root.widget(id)?.zone ?? "right"
        };
        const rest = entries.filter(entry => entry.id !== id);
        const at = rest.findIndex(entry => entry.id === beforeId);
        rest.splice(at < 0 ? rest.length : at, 0, moving);
        node.entries = rest;
    }

    // The status-icons list is the pill's own order, so a drag between two icons edits
    // it directly rather than leaving a row in `bar.entries`.
    function moveStatusIconBefore(iconId: string, beforeIconId: string): void {
        const icons = Config.bar.statusIcons.values ?? [];
        const from = icons.findIndex(icon => icon.id === iconId);
        const to = icons.findIndex(icon => icon.id === beforeIconId);
        if (from < 0 || to < 0 || from === to)
            return;
        GlobalConfig.bar.statusIcons.move(from, from < to ? to - 1 : to);
    }

    function resetToDefaults(node: var): void {
        node.resetOption("entries");
    }

    function indexFor(entries: var, id: string): int {
        const target = root.widget(id);
        if (target === null)
            return entries.length;

        for (let i = entries.length - 1; i >= 0; i--) {
            const other = root.widget(entries[i].id);
            if (other !== null && other.index < target.index)
                return i + 1;
        }
        return 0;
    }
}
