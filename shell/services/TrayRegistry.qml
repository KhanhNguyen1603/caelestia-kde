pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.services
import "trayicons.js" as TrayIcons

// Per-icon tray state, and the one place that decides which icons the bar draws and
// in what order. Settings live in config, keyed by the stable alias trayicons.js
// derives, so they outlive the notifier ids that change between launches.
Singleton {
    id: root

    // The three states an icon can be in; collapsed is the default.
    readonly property var states: [
        { value: "visible", label: qsTr("Always visible"), icon: "push_pin" },
        { value: "collapsed", label: qsTr("Collapse"), icon: "expand_more" },
        { value: "hidden", label: qsTr("Hidden"), icon: "visibility_off" }
    ]

    readonly property string popoutPrefix: "traymenu"

    // A tray icon can be dragged in among the bar's own icons, so on the bar it holds a
    // row in the same list they use. The row names the icon by its stable key.
    readonly property string rowPrefix: "tray:"

    // Pids of the running notifiers, so an alias can name the app rather than the
    // process that happens to host its icon.
    property var procNames: ({})
    property bool procRefreshPending: false

    // Every icon the tray settings know about, running or not, in bar order. Two
    // notifiers that fold onto one alias (one app, two instances) share a row: the
    // alias is what the settings apply to.
    readonly property var entries: {
        const rows = [];
        const known = new Set();
        for (const row of root.liveRows()) {
            if (known.has(row.key))
                continue;
            known.add(row.key);
            rows.push(row);
        }
        for (const key of root.configuredKeys) {
            if (known.has(key))
                continue;
            known.add(key);
            rows.push({
                key: key,
                id: "",
                title: TrayIcons.labelOf(key),
                icon: root.fallbackIcon(key),
                running: false
            });
        }
        return TrayIcons.ordered(rows, GlobalConfig.bar.tray.order);
    }

    // Every running icon, before the bar's state decides where it belongs.
    readonly property var liveItems: SystemTray.items.values.filter(item => item.status !== Status.Passive)

    // The icons the bar draws, in bar order. Hidden icons are in neither list, so the
    // bar and the tray popout cannot disagree about which icons exist.
    readonly property var trayItems: root.orderedItems(root.liveItems.filter(item => !root.isHidden(item)))

    // In compact mode the bar only draws the icons pinned to it; the rest wait in
    // the overflow panel. Without compact mode collapsed icons stay on the bar,
    // and only explicitly hidden icons move to the panel.
    readonly property var visibleItems: root.orderedItems(root.liveItems.filter(item => root.stateOfItem(item) === "visible"))
    // An icon the bar gave a row to is drawn from that row, on the bar, so the panel's
    // own list leaves it out: the row decides where the icon is, not the state lists.
    readonly property var boxedItems: root.liveItems.filter(item => !root.keysOf(item).some(key => root.rowedKeys[key]))
    readonly property var overflowItems: root.orderedItems(root.boxedItems.filter(item => GlobalConfig.bar.tray.compact ? root.stateOfItem(item) !== "visible" : root.stateOfItem(item) === "hidden"))
    readonly property var barItems: GlobalConfig.bar.tray.compact ? root.visibleItems : root.trayItems
    readonly property int overflowCount: root.overflowItems.length

    readonly property int collapsedCount: root.trayItems.filter(item => root.isCollapsed(item)).length

    // The tray icons the bar's entry list holds a place for, keyed by the icon's key.
    readonly property var rowedKeys: {
        const keys = {};
        for (const entry of GlobalConfig.bar.entries ?? []) {
            const key = root.keyOfRow(entry.id ?? "");
            if (key.length > 0)
                keys[key] = true;
        }
        return keys;
    }

    readonly property var configuredKeys: {
        const tray = GlobalConfig.bar.tray;
        return [...new Set(tray.order.concat(tray.alwaysVisible, tray.hiddenIcons))];
    }

    function orderedItems(items: var): var {
        return TrayIcons.ordered(items.map(item => ({
            key: root.keyOfItem(item),
            item: item
        })), GlobalConfig.bar.tray.order).map(row => row.item);
    }

    function liveRows(): var {
        return SystemTray.items.values.filter(item => item.status !== Status.Passive).map(item => ({
                    key: root.keyOfItem(item),
                    id: item.id,
                    title: root.displayName(item),
                    icon: item.icon,
                    running: true
                }));
    }

    function keyOfItem(item: var): string {
        return TrayIcons.keyOf(item.id, item.icon, root.procNames[TrayIcons.pidOf(item.id)] ?? "");
    }

    // Every name one icon answers to. The process alias only exists once `ps` has said
    // which app a notifier belongs to, so a setting written before that names the icon by
    // its theme icon instead; the notifier id outlives neither. Readers and writers take
    // any of them, which keeps a place from going stale when the alias arrives.
    function keysOf(item: var): var {
        const keys = [];
        const push = key => {
            if (key && !keys.includes(key))
                keys.push(key);
        };
        push(root.keyOfItem(item));
        push(TrayIcons.keyOf(item.id, item.icon, ""));
        push(item.id);
        return keys;
    }

    function displayName(item: var): string {
        return TrayIcons.readableTitle(item.title) || TrayIcons.labelOf(root.keyOfItem(item)) || item.id;
    }

    function fallbackIcon(key: string): string {
        return Quickshell.iconPath(TrayIcons.iconNameOf(key), "") || Quickshell.iconPath("application-x-executable", "");
    }

    function stateOf(key: string): string {
        return TrayIcons.stateOf(key, GlobalConfig.bar.tray.hiddenIcons, GlobalConfig.bar.tray.alwaysVisible);
    }

    function metaOf(state: string): var {
        return root.states.find(entry => entry.value === state) ?? root.states[1];
    }

    function stateLabel(state: string): string {
        return root.metaOf(state).label;
    }

    function stateIcon(state: string): string {
        return root.metaOf(state).icon;
    }

    function stateOfItem(item: var): string {
        for (const key of root.keysOf(item)) {
            if (GlobalConfig.bar.tray.hiddenIcons.includes(key))
                return "hidden";
        }
        for (const key of root.keysOf(item)) {
            if (GlobalConfig.bar.tray.alwaysVisible.includes(key))
                return "visible";
        }
        return "collapsed";
    }

    function isHidden(item: var): bool {
        return root.stateOfItem(item) === "hidden";
    }

    function isCollapsed(item: var): bool {
        return root.stateOfItem(item) === "collapsed";
    }

    function setState(key: string, state: string): void {
        const tray = GlobalConfig.bar.tray;
        // The lists may name this icon by an older alias of it: a state says where the
        // icon is, so every name it had goes with it.
        const item = root.itemOf(key);
        const names = item ? root.keysOf(item) : [key];
        const visible = tray.alwaysVisible.filter(entry => !names.includes(entry));
        const hidden = tray.hiddenIcons.filter(entry => !names.includes(entry));
        const nextVisible = state === "visible" ? [...visible, key] : visible;
        const nextHidden = state === "hidden" ? [...hidden, key] : hidden;
        // A list that already says this is written anyway only to make the bar draw every
        // icon it holds again, which is what a slow-feeling toggle is made of.
        if (!TrayIcons.sameList(nextVisible, tray.alwaysVisible))
            tray.alwaysVisible = nextVisible;
        if (!TrayIcons.sameList(nextHidden, tray.hiddenIcons))
            tray.hiddenIcons = nextHidden;
    }

    function forget(key: string): void {
        const tray = GlobalConfig.bar.tray;
        tray.alwaysVisible = tray.alwaysVisible.filter(entry => entry !== key);
        tray.hiddenIcons = tray.hiddenIcons.filter(entry => entry !== key);
        tray.order = tray.order.filter(entry => entry !== key);
    }

    // Commits the order the settings list shows, so the config holds every key it
    // lists rather than only the ones a drag happened to touch.
    function move(from: int, to: int): void {
        const keys = root.entries.map(entry => entry.key);
        if (from < 0 || from >= keys.length || to < 0 || to >= keys.length || from === to)
            return;
        keys.splice(to, 0, keys.splice(from, 1)[0]);
        GlobalConfig.bar.tray.order = keys;
    }

    // Where a dragged icon lands: in the place of the icon it was dropped on. The
    // order list holds every key the tray knows, so a key new to it is inserted
    // rather than dropped.
    function moveBefore(key: string, beforeKey: string): void {
        if (key === beforeKey)
            return;

        const tray = GlobalConfig.bar.tray;
        const order = [...new Set([...(tray.order ?? []), ...root.configuredKeys])].filter(entry => entry !== key);
        const at = order.indexOf(beforeKey);
        order.splice(at < 0 ? order.length : at, 0, key);
        tray.order = order;
    }

    function rowOf(key: string): string {
        return root.rowPrefix + key;
    }

    function keyOfRow(id: string): string {
        return id.startsWith(root.rowPrefix) ? id.substring(root.rowPrefix.length) : "";
    }

    function itemOf(key: string): var {
        return root.liveItems.find(item => root.keysOf(item).includes(key)) ?? null;
    }

    // The row this icon already holds, whichever alias it was written under, or the one a
    // fresh drop should write: a drop must not leave a second row for one icon.
    function rowFor(key: string): string {
        const item = root.itemOf(key);
        const names = item ? root.keysOf(item) : [key];
        const entries = GlobalConfig.bar.entries ?? [];
        for (const entry of entries) {
            const rowKey = root.keyOfRow(entry.id ?? "");
            if (rowKey.length > 0 && names.includes(rowKey))
                return entry.id;
        }
        return root.rowOf(key);
    }

    function popoutName(key: string): string {
        return `${root.popoutPrefix}${key}`;
    }

    // The settings alias is shared on purpose: two live notifiers can resolve to
    // the same key. The popout name carries the item id as well, so a second icon
    // with the same alias cannot match the selected name and draw its menu too.
    function popoutNameOf(item: var): string {
        return `${root.popoutName(root.keyOfItem(item))}#${item.id}`;
    }

    function isTrayPopout(name: string): bool {
        return name.startsWith(root.popoutPrefix);
    }

    function refreshProcNames(): void {
        if (proc.running) {
            root.procRefreshPending = true;
            return;
        }
        const pids = [...new Set([...SystemTray.items.values].map(item => TrayIcons.pidOf(item.id)).filter(pid => pid))];
        if (pids.length === 0)
            return;
        proc.command = ["ps", "-o", "pid=,comm=", "-p", pids.join(",")];
        proc.running = true;
    }

    // Settings written before aliases existed hold notifier ids, which only the
    // running icons can map back to an alias, so the rewrite happens as they appear.
    // It is idempotent and leaves anything it cannot map alone.
    function migrateLegacyKeys(): void {
        const aliases = {};
        let found = false;
        for (const item of SystemTray.items.values) {
            const key = root.keyOfItem(item);
            if (key === item.id)
                continue;
            aliases[item.id] = key;
            found = true;
        }
        if (found)
            ConfigMigrations.migrateTrayIcons(aliases);
    }

    Component.onCompleted: {
        root.refreshProcNames();
        root.migrateLegacyKeys();
    }

    onProcNamesChanged: root.migrateLegacyKeys()

    Connections {
        function onValuesChanged(): void {
            root.refreshProcNames();
            root.migrateLegacyKeys();
        }

        target: SystemTray.items
    }

    Process {
        id: proc

        command: []

        stdout: StdioCollector {
            id: procOut
        }

        onExited: {
            const next = Object.assign({}, root.procNames);
            let changed = false;
            for (const line of procOut.text.trim().split("\n")) {
                const fields = line.trim().split(/\s+/);
                const pid = fields.shift() ?? "";
                const comm = fields.join(" ");
                if (!pid || !comm || next[pid] === comm)
                    continue;
                next[pid] = comm;
                changed = true;
            }
            if (changed)
                root.procNames = next;
            if (root.procRefreshPending) {
                root.procRefreshPending = false;
                root.refreshProcNames();
            }
        }
    }
}
