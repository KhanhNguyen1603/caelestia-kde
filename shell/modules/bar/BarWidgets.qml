pragma Singleton

import QtQuick
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
        { id: "showDesktop", zone: "right" },
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

    function widget(id: string): var {
        return root.byId[id] ?? null;
    }

    function isKnown(id: string): bool {
        return root.byId[id] !== undefined;
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
    // the view entries that always carry the three fields a tray needs.
    function normalizedEntries(entries: var, zone: string): var {
        return (entries ?? []).map(entry => Object.assign({}, entry, {
            zone: entry.zone ?? zone,
            systemTray: false,
            draggable: false
        }));
    }

    function normalizedZoneEntries(node: var, zone: string): var {
        return root.normalizedEntries(root.zoneEntries(root.entriesOf(node), zone), zone);
    }

    // The right end of the bar is one tray, then the power button, then the
    // clock. Everything else the user put in that zone is drawn inside the tray,
    // so adding a widget there cannot grow a second row of orphan icons.
    function rightLayoutEntries(node: var): var {
        const entries = root.zoneEntries(root.entriesOf(node), "right");
        const trayContent = entries.filter(entry => entry.id !== "clock" && entry.id !== "power" && entry.id !== "tray");
        const model = [];
        if (entries.some(entry => entry.id === "tray") || trayContent.length > 0)
            model.push({ id: "tray", enabled: true, zone: "right", systemTray: true, draggable: false });
        model.push(...root.normalizedEntries(entries.filter(entry => entry.id === "power"), "right"));
        model.push(...root.normalizedEntries(entries.filter(entry => entry.id === "clock"), "right"));
        return model;
    }

    // Widgets the tray owns, in the order the user arranged them. The tray entry
    // itself is the container, and the clock and power stay outside it. Everything
    // here is draggable into the hidden-icons box.
    function systemTrayEntries(node: var): var {
        return root.normalizedEntries(root.zoneEntries(root.entriesOf(node), "right")
            .filter(entry => entry.id !== "clock" && entry.id !== "power" && entry.id !== "tray"), "right")
            .map(entry => Object.assign(entry, { draggable: true }));
    }

    function systemTrayShowsIcons(node: var): bool {
        return root.zoneEntries(root.entriesOf(node), "right").some(entry => entry.id === "tray");
    }

    function overflowWidgets(node: var): var {
        const hidden = [];
        let index = 0;
        for (const entry of root.entriesOf(node)) {
            if (entry.zone !== root.overflowZone || !root.isKnown(entry.id) || entry.id === "tray")
                continue;
            hidden.push({
                id: entry.id,
                enabled: true,
                zone: root.overflowZone,
                systemTray: false,
                draggable: true,
                index: index++
            });
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
