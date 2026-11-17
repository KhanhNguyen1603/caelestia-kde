pragma Singleton

import QtQuick
import Caelestia.Config
import qs.services
import qs.modules.bar
import "../../services/trayplacement.js" as Placement

// The one place an icon's place is written. Every switch, drag and settings page asks for
// a place here rather than editing the config itself, so the rules live in
// `trayplacement.js` and are applied in one go: the bar redraws all of its widgets on
// every write, and a change that says what is already true writes nothing.
QtObject {
    id: root

    readonly property string trayZone: Placement.TRAY_ZONE

    // Every icon the bar can show, with the place it is in and whether it has anything to
    // say right now: the bar's status icons, the icons beside them and the tray's own apps
    // are one list here, because choosing where an icon goes is one decision whatever kind
    // of icon it is. The tray's apps come first: they are the ones that come and go.
    readonly property var rows: {
        const entries = GlobalConfig.bar.entries ?? [];
        const rows = [];
        // An app that is not running and was never placed is not something to place now,
        // so the list leaves it to the settings page.
        for (const item of TrayRegistry.entries ?? []) {
            const id = TrayRegistry.rowOf(item.key);
            if (!item.running && Placement.rowOf(entries, id) === null)
                continue;
            rows.push({
                kind: "trayItem",
                id: id,
                key: item.key,
                place: root.placementOf(id),
                active: item.running !== false
            });
        }
        for (const widget of BarWidgets.allWidgets) {
            if (!BarWidgets.dragsItself(widget.id))
                continue;
            rows.push({
                kind: widget.id,
                id: widget.id,
                key: "",
                place: root.placementOf(widget.id),
                active: BarWidgets.saysSomething(widget.id)
            });
        }
        // The icons list decides whether a status icon exists at all; the row only says
        // where it goes, so an icon switched off stays off whatever a row says.
        for (const icon of Config.bar.statusIcons.values ?? []) {
            const id = BarWidgets.statusIconPrefix + icon.id;
            rows.push({
                kind: "statusIcon",
                id: id,
                key: "",
                place: root.placementOf(id),
                active: BarWidgets.statusIconActive(icon.id)
            });
        }
        return rows;
    }

    readonly property var zones: {
        const zones = {};
        for (const widget of BarWidgets.allWidgets)
            zones[widget.id] = widget.zone;
        return zones;
    }

    // Which of the three kinds of icon this is, which is where its place comes from.
    function kindOf(id: string): string {
        if (TrayRegistry.keyOfRow(id).length > 0)
            return "trayItem";
        const iconId = BarWidgets.statusIconId(id);
        if (iconId.length === 0)
            return "widget";
        return (Config.bar.statusIcons.values ?? []).some(icon => icon.id === iconId) ? "statusIcon" : "widget";
    }

    function declaredZone(id: string): string {
        return root.zones[id] ?? Placement.BAR_ZONE;
    }

    // A group the bar expands draws its icons where the group's row sits, so one of its
    // icons only gets a row when it needs a place of its own.
    function anchorOf(id: string): string {
        switch (root.kindOf(id)) {
        case "statusIcon":
            return "statusIcons";
        case "trayItem":
            return "tray";
        default:
            return "";
        }
    }

    // Where an icon is now. The three answers are the whole vocabulary: off, in the tray's
    // box, on the bar.
    function placementOf(id: string): string {
        const row = Placement.rowOf(GlobalConfig.bar.entries ?? [], id);
        switch (root.kindOf(id)) {
        case "trayItem":
            return Placement.placeOf(row, Placement.trayFallback(TrayRegistry.stateOf(TrayRegistry.keyOfRow(id)), GlobalConfig.bar.tray.compact));
        case "statusIcon": {
            const iconId = BarWidgets.statusIconId(id);
            const icon = (Config.bar.statusIcons.values ?? []).find(icon => icon.id === iconId);
            return Placement.statusPlace(icon ? icon.enabled !== false : false, row, Placement.BAR);
        }
        default:
            return Placement.placeOf(row, Placement.BAR);
        }
    }

    // A switch asks for this: shown, or gone. Shown means drawn on the bar, because a
    // switch that puts an icon somewhere nobody can see it is not a switch anyone can
    // read: the box is where a drag puts things, not where a switch does.
    function setShown(id: string, shown: bool): void {
        if ((root.placementOf(id) !== Placement.OFF) === shown)
            return;
        root.setPlacement(id, shown ? Placement.BAR : Placement.OFF, shown ? { zone: Placement.BAR_ZONE } : undefined);
    }

    // A tray app's own state, which is what the tray draws from.
    function setTrayState(key: string, state: string): void {
        root.setPlacement(TrayRegistry.rowFor(key), state === "hidden" ? Placement.OFF : state === "visible" ? Placement.BAR : Placement.TRAY);
    }

    // The one write path. `zone` and `beforeId` are for a drag, which decides a place as
    // well as a visibility; `beforeKey` orders the tray's own list the same way.
    function setPlacement(id: string, place: string, options: var): void {
        const kind = root.kindOf(id);
        const outcome = Placement.plan({
            rows: GlobalConfig.bar.entries ?? [],
            id: id,
            place: place,
            kind: kind,
            beforeId: options?.beforeId ?? "",
            zone: options?.zone,
            declaredZone: root.declaredZone(id),
            widgets: BarWidgets.allWidgets,
            zones: root.zones,
            anchorOf: root.anchorOf,
            trayKey: kind === "trayItem" ? TrayRegistry.keyOfRow(id) : "",
            compact: GlobalConfig.bar.tray.compact
        });

        if (outcome.rows && !Placement.sameRows(outcome.rows, GlobalConfig.bar.entries ?? []))
            GlobalConfig.bar.entries = outcome.rows;

        if (outcome.iconEnabled !== undefined && outcome.iconEnabled !== null) {
            const values = Config.bar.statusIcons.values ?? [];
            const index = values.findIndex(icon => icon.id === BarWidgets.statusIconId(id));
            if (index >= 0 && values[index].enabled !== outcome.iconEnabled)
                GlobalConfig.bar.statusIcons.at(index).enabled = outcome.iconEnabled;
        }

        if (outcome.trayKey)
            TrayRegistry.setState(outcome.trayKey, outcome.trayState);

        if (options?.beforeKey && TrayRegistry.keyOfRow(id).length > 0)
            TrayRegistry.moveBefore(TrayRegistry.keyOfRow(id), options.beforeKey);
    }

    // Replacing the whole list is what the settings page's own editor does when it saves
    // the row it has been arranging.
    function replaceAll(entries: var): void {
        const next = (entries ?? []).slice();
        if (Placement.sameRows(next, GlobalConfig.bar.entries ?? []))
            return;
        GlobalConfig.bar.entries = next;
    }

    function resetToDefaults(): void {
        const node = GlobalConfig.bar;
        node.resetOption("entries");
    }
}
