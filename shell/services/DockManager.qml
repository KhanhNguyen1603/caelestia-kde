pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.Services
import qs.services
import qs.utils

Singleton {
    id: root

    property string targetScreen: ""
    property var launchingApps: ({})
    property var _launchTimestamps: ({})
    property bool isDragging: false
    property var modelDataArray: []
    property var modelDataMap: ({})
    property var currentOrder: []
    property int modelUpdateTrigger: 0

    readonly property alias listModel: dockModel
    readonly property int count: dockModel.count
    readonly property var activeTop: (Kwin.activeWindow && Kwin.activeWindow.address) ? Kwin.activeWindow : null

    readonly property bool useDockPanel: Boolean(Config.dockPanel && Config.dockPanel.enabled)
    readonly property var effectivePinnedApps: useDockPanel
        ? (GlobalConfig.dockPanel.pinnedApps || [])
        : (GlobalConfig.bar.dock.pinnedApps || [])
    readonly property int effectiveGrouping: useDockPanel
        ? Config.dockPanel.windowGrouping
        : GlobalConfig.bar.dock.windowGrouping
    readonly property bool effectiveCurrentDesktopOnly: useDockPanel
        ? Config.dockPanel.currentDesktopOnly
        : Config.bar.dock.currentDesktopOnly

    property var _pinnedCache: null
    property var _entryCache: ({})
    property string _lastSignature: ""

    property var _toplevels: effectiveCurrentDesktopOnly
        ? Kwin.filterWindows(Kwin.windowList, Kwin.activeWorkspaceFor(targetScreen || null), targetScreen || null, true)
        : (Kwin.windowList || [])

    function scheduleRebuild(): void {
        Qt.callLater(root.rebuildModel);
    }

    function resolvePinned(pinnedIds: var): var {
        const key = pinnedIds.join("\n");
        if (root._pinnedCache && root._pinnedCache.key === key)
            return root._pinnedCache.entries;

        const entries = [];
        for (const pid of pinnedIds) {
            for (const entry of DesktopEntries.applications.values) {
                if (Strings.testRegex(pid, entry.id) && !entries.some(e => e.id === entry.id))
                    entries.push(entry);
            }
        }
        root._pinnedCache = { key: key, entries: entries };
        return entries;
    }

    function resolveEntry(appClass: string): var {
        const cached = root._entryCache[appClass];
        if (cached !== undefined)
            return cached;

        let entry = null;
        let iconName = appClass;
        if (appClass.toLowerCase().startsWith("steam_app_")) {
            const appId = appClass.substring(10);
            iconName = `steam_icon_${appId}`;
            entry = DesktopEntries.applications.values.find(e => e.id.toLowerCase() === `steam_app_${appId}.desktop` || e.id.toLowerCase() === `steam-${appId}.desktop`) || null;
        } else {
            entry = DesktopEntries.heuristicLookup(appClass) || null;
            if (!entry)
                entry = DesktopEntries.applications.values.find(e => Kwin.classNamesApp(appClass, [e.id])) || null;
            iconName = entry ? entry.id : (appClass.toLowerCase().split(/[^a-z0-9]/)[0] || appClass);
        }

        const resolved = { entry: entry, iconName: iconName };
        root._entryCache[appClass] = resolved;
        return resolved;
    }

    function modelSignature(apps: var): string {
        return apps.map(a => `${a.id}|${a.isPinned}|${a.entry?.id ?? ""}|` + a.toplevels.map(t => `${t.address}${t.focused ? "*" : ""}${t.minimized ? "m" : ""}`).join(",")).join("\n");
    }

    function rebuildModel(): void {
        if (root.isDragging) return;
        let apps = [];

        const pinnedIds = root.effectivePinnedApps;

        for (const entry of root.resolvePinned(pinnedIds)) {
            apps.push({
                id: entry.id,
                isPinned: true,
                entry: entry,
                toplevels: [],
                appClass: entry.id.replace(".desktop", ""),
                iconName: entry.id,
                pid: 0
            });
        }

        for (const toplevel of root._toplevels) {
            const ipc = toplevel;
            if (!ipc) continue;
            const appClass = ipc.class || ipc.initialClass;
            if (!appClass) continue;

            if (appClass.toLowerCase().includes("xwaylandvideobridge")) continue;

            const grouping = root.effectiveGrouping;
            const ungrouped = grouping === DockWindowGrouping.Ungrouped;
            const pinnedFirst = grouping === DockWindowGrouping.PinnedFirst;
            let found = false;
            let pinnedCapped = false;
            if (!ungrouped) {
                for (const app of apps) {
                    if (!Kwin.classNamesApp(appClass, [app.id, app.appClass]))
                        continue;

                    if (pinnedFirst && app.isPinned && app.toplevels.length > 0)
                        pinnedCapped = true;
                    else {
                        app.toplevels.push(toplevel);
                        found = true;
                    }
                    break;
                }
            }

            if (!found) {
                const { entry, iconName } = root.resolveEntry(appClass);

                const pid = ipc.pid || 0;
                if (!entry)
                    WinIcons.request(appClass, ipc.title || "", pid, ipc.address ? String(ipc.address) : "");

                apps.push({
                    id: ungrouped || pinnedCapped ? `${appClass}#${ipc.address || pid}` : appClass,
                    isPinned: false,
                    entry: entry,
                    toplevels: [toplevel],
                    appClass: appClass,
                    iconName: iconName,
                    pid: pid
                });
            }
        }

        let newLaunching = Object.assign({}, root.launchingApps);
        let launchingChanged = false;

        for (const app of apps) {
            if (app.toplevels.length > 0) {
                if (newLaunching[app.appClass]) {
                    delete newLaunching[app.appClass];
                    delete root._launchTimestamps[app.appClass];
                    launchingChanged = true;
                }
                if (newLaunching[app.id]) {
                    delete newLaunching[app.id];
                    delete root._launchTimestamps[app.id];
                    launchingChanged = true;
                }
            }
        }

        if (launchingChanged) {
            root.launchingApps = newLaunching;
        }

        const existingOrder = (root.currentOrder && root.currentOrder.length > 0) ? root.currentOrder : root.modelDataArray;
        const existingPinnedOrder = existingOrder.filter(a => a && a.isPinned).map(a => a.id);
        const pinnedOrderMatches = existingPinnedOrder.length === pinnedIds.length &&
            existingPinnedOrder.every((id, idx) => id === pinnedIds[idx]);

        if (existingOrder.length > 0 && pinnedOrderMatches) {
            const orderedApps = [];
            const remainingApps = [...apps];

            for (let i = 0; i < existingOrder.length; i++) {
                const prevItem = existingOrder[i];
                if (!prevItem) continue;
                const idx = remainingApps.findIndex(a => a.id === prevItem.id);
                if (idx !== -1) {
                    orderedApps.push(remainingApps.splice(idx, 1)[0]);
                }
            }

            for (let i = 0; i < remainingApps.length; i++) {
                orderedApps.push(remainingApps[i]);
            }

            apps = orderedApps;
        }

        const signature = root.modelSignature(apps);
        if (signature === root._lastSignature) {
            for (const app of apps) {
                const prev = root.modelDataMap[app.id];
                if (prev)
                    prev.toplevels = app.toplevels;
            }
            return;
        }
        root._lastSignature = signature;

        let changed = false;
        if (apps.length !== dockModel.count) {
            changed = true;
        } else {
            for (let i = 0; i < apps.length; i++) {
                if (apps[i].id !== dockModel.get(i).appId) {
                    changed = true;
                    break;
                }
            }
        }

        if (changed) {
            for (let i = dockModel.count - 1; i >= 0; i--) {
                let found = false;
                for (let j = 0; j < apps.length; j++) {
                    if (apps[j].id === dockModel.get(i).appId) { found = true; break; }
                }
                if (!found) {
                    dockModel.remove(i);
                }
            }

            for (let i = 0; i < apps.length; i++) {
                let found = false;
                for (let j = 0; j < dockModel.count; j++) {
                    if (dockModel.get(j).appId === apps[i].id) { found = true; break; }
                }
                if (!found) {
                    dockModel.append({ appId: apps[i].id });
                }
            }

            for (let i = 0; i < apps.length; i++) {
                let currentId = apps[i].id;
                if (dockModel.get(i).appId !== currentId) {
                    let foundIdx = -1;
                    for (let j = i + 1; j < dockModel.count; j++) {
                        if (dockModel.get(j).appId === currentId) { foundIdx = j; break; }
                    }
                    if (foundIdx !== -1) {
                        dockModel.move(foundIdx, i, 1);
                    }
                }
            }
        }

        const map = {};
        for (const app of apps) {
            map[app.id] = app;
        }
        root.modelDataMap = map;
        root.modelDataArray = apps;
        root.modelUpdateTrigger += 1;
    }

    function activateEntry(entry: var): void {
        if (!entry)
            return;

        if (entry.toplevels && entry.toplevels.length > 0) {
            let activeIdx = -1;
            let activeAddr = "";

            if (Kwin.activeWindow) {
                activeAddr = Kwin.activeWindow.address ? String(Kwin.activeWindow.address) : "";
            } else if (root.activeTop && root.activeTop.address) {
                activeAddr = String(root.activeTop.address);
            }

            for (let i = 0; i < entry.toplevels.length; i++) {
                let top = entry.toplevels[i];
                let topAddr = String(top.address);
                let isMinimized = top.minimized || false;
                if (!isMinimized && (top.focused || (activeAddr !== "" && activeAddr === topAddr))) {
                    activeIdx = i;
                    break;
                }
            }

            if (entry.toplevels.length === 1) {
                let addr = String(entry.toplevels[0].address);
                if (activeIdx === 0) {
                    Kwin.minimizeWindow(addr);
                } else {
                    Kwin.focusWindow(addr);
                }
            } else {
                let nextIdx = activeIdx !== -1 ? (activeIdx + 1) % entry.toplevels.length : 0;
                let addr = String(entry.toplevels[nextIdx].address);
                Kwin.focusWindow(addr);
            }
        } else if (entry.entry) {
            root.trackLaunch(entry.appClass || entry.id);
            Launch.launchEntry(entry.entry);
        }
    }

    function trackLaunch(key: string): void {
        if (!key) return;
        const newLaunching = Object.assign({}, root.launchingApps);
        const newTimestamps = Object.assign({}, root._launchTimestamps);
        newLaunching[key] = true;
        newTimestamps[key] = Date.now();
        root._launchTimestamps = newTimestamps;
        root.launchingApps = newLaunching;
    }

    function activateIndex(idx: int): void {
        if (idx < 0 || idx >= root.modelDataArray.length)
            return;
        root.activateEntry(root.modelDataArray[idx]);
    }

    function activateNewIndex(idx: int): void {
        if (idx < 0 || idx >= root.modelDataArray.length)
            return;
        const entry = root.modelDataArray[idx];
        if (!entry)
            return;
        if (entry.entry) {
            root.trackLaunch(entry.appClass || entry.id);
            Launch.launchEntry(entry.entry);
        } else if (entry.toplevels && entry.toplevels.length > 0) {
            root.activateEntry(entry);
        }
    }

    function moveItem(from: int, to: int): void {
        if (from === undefined || to === undefined || from === to) return;
        if (from < 0 || to < 0 || from >= dockModel.count || to >= dockModel.count) return;
        dockModel.move(from, to, 1);
        const movedItem = root.currentOrder.splice(from, 1)[0];
        root.currentOrder.splice(to, 0, movedItem);
    }

    function saveNewOrder(): void {
        const newArr = [];
        const newFavs = [];

        for (let i = 0; i < root.currentOrder.length; ++i) {
            const mData = root.currentOrder[i];
            if (!mData) continue;

            if (mData.isPinned) {
                newFavs.push(mData.id);
            }
            newArr.push(mData);
        }

        const currentFavs = root.useDockPanel
            ? (GlobalConfig.dockPanel.pinnedApps || [])
            : (GlobalConfig.bar.dock.pinnedApps || []);
        let changed = currentFavs.length !== newFavs.length;
        if (!changed) {
            for (let i = 0; i < newFavs.length; i++) {
                if (currentFavs[i] !== newFavs[i]) {
                    changed = true;
                    break;
                }
            }
        }

        if (changed) {
            if (root.useDockPanel)
                GlobalConfig.dockPanel.pinnedApps = newFavs;
            else
                GlobalConfig.bar.dock.pinnedApps = newFavs;
        }

        root.modelDataArray = newArr;
        root._lastSignature = "";
        const map = {};
        for (const app of newArr) {
            map[app.id] = app;
        }
        root.modelDataMap = map;
    }

    function _matchesApp(pattern: string, id: string): bool {
        if (!pattern || !id) return false;
        if (pattern === id) return true;
        if (Strings.testRegex(pattern, id)) return true;
        if (id.endsWith(".desktop") && Strings.testRegex(pattern, id.replace(".desktop", ""))) return true;
        if (pattern.endsWith(".desktop") && Strings.testRegex(id, pattern.replace(".desktop", ""))) return true;
        return false;
    }

    function isPinned(id: string): bool {
        if (!id) return false;
        const current = root.effectivePinnedApps || [];
        for (let i = 0; i < current.length; i++) {
            if (_matchesApp(current[i], id))
                return true;
        }
        return false;
    }

    function pinApp(id: string): void {
        const targetNode = root.useDockPanel ? GlobalConfig.dockPanel : GlobalConfig.bar.dock;
        const current = [...(targetNode.pinnedApps || [])];
        if (!root.isPinned(id)) {
            current.push(id);
            targetNode.pinnedApps = current;
        }
    }

    function unpinApp(id: string): void {
        const targetNode = root.useDockPanel ? GlobalConfig.dockPanel : GlobalConfig.bar.dock;
        const current = (targetNode.pinnedApps || []).filter(item => !_matchesApp(item, id));
        targetNode.pinnedApps = current;
    }

    function publishMinimizeGeometries(sourceItem: var, win: var, isHorizontal: bool, originX: real, originY: real, itemSize: real, spacing: real, span: real, scrolled: real, position: string): void {
        if (!win || span <= 0 || itemSize <= 0)
            return;

        const size = Math.round(itemSize);
        const step = itemSize + spacing;

        for (let i = 0; i < root.modelDataArray.length; i++) {
            const tops = root.modelDataArray[i]?.toplevels ?? [];
            if (tops.length === 0)
                continue;

            const offset = Math.max(0, Math.min(i * step - scrolled, span - size));

            let x = Math.round(isHorizontal ? originX + offset : originX);
            let y = Math.round(isHorizontal ? originY : originY + offset);
            let w = size;
            let h = size;

            if (position === "left") {
                w = x + size;
                x = 0;
            } else if (position === "right") {
                const winW = win ? win.width : 0;
                w = winW > 0 ? winW - x : size;
            } else if (position === "top") {
                h = y + size;
                y = 0;
            } else if (position === "bottom") {
                const winH = win ? win.height : 0;
                h = winH > 0 ? winH - y : size;
            }

            for (let j = 0; j < tops.length; j++) {
                const address = tops[j]?.address;
                if (address)
                    MinimizeGeometry.setGeometry(sourceItem, String(address), x, y, w, h);
            }
        }
    }

    on_ToplevelsChanged: root.scheduleRebuild()
    onModelDataArrayChanged: root.currentOrder = [...root.modelDataArray]

    Component.onCompleted: {
        root.rebuildModel();
    }

    ListModel {
        id: dockModel
    }

    Timer {
        id: staleLaunchTimer

        interval: 2000
        repeat: true
        running: Object.keys(root.launchingApps).length > 0
        onTriggered: {
            const now = Date.now();
            let changed = false;
            const newLaunching = Object.assign({}, root.launchingApps);
            const newTimestamps = Object.assign({}, root._launchTimestamps);
            for (const key of Object.keys(newLaunching)) {
                if (newTimestamps[key] && (now - newTimestamps[key] > 15000)) {
                    delete newLaunching[key];
                    delete newTimestamps[key];
                    changed = true;
                }
            }
            if (changed) {
                root._launchTimestamps = newTimestamps;
                root.launchingApps = newLaunching;
            }
        }
    }

    Connections {
        function onPinnedAppsChanged(): void {
            if (!root.useDockPanel) {
                root._pinnedCache = null;
                root.scheduleRebuild();
            }
        }

        target: GlobalConfig.bar.dock
    }

    Connections {
        function onPinnedAppsChanged(): void {
            if (root.useDockPanel) {
                root._pinnedCache = null;
                root.scheduleRebuild();
            }
        }

        target: GlobalConfig.dockPanel
    }

    Connections {
        function onWindowListChanged(): void {
            root.scheduleRebuild();
        }

        function onActiveWindowChanged(): void {
            root.scheduleRebuild();
        }

        function onActiveWsIdChanged(): void {
            if (root.effectiveCurrentDesktopOnly)
                root.scheduleRebuild();
        }

        function onActiveByOutputChanged(): void {
            if (root.effectiveCurrentDesktopOnly)
                root.scheduleRebuild();
        }

        target: Kwin
    }

    Connections {
        function onCurrentDesktopOnlyChanged(): void {
            if (!root.useDockPanel)
                root.scheduleRebuild();
        }

        function onWindowGroupingChanged(): void {
            if (!root.useDockPanel)
                root.scheduleRebuild();
        }

        target: Config.bar.dock
    }

    Connections {
        function onCurrentDesktopOnlyChanged(): void {
            if (root.useDockPanel)
                root.scheduleRebuild();
        }

        function onWindowGroupingChanged(): void {
            if (root.useDockPanel)
                root.scheduleRebuild();
        }

        function onEnabledChanged(): void {
            root._pinnedCache = null;
            root.scheduleRebuild();
        }

        target: Config.dockPanel
    }

    Connections {
        function onValuesChanged(): void {
            root._pinnedCache = null;
            root._entryCache = ({});
            root._lastSignature = "";
            root.scheduleRebuild();
        }

        target: DesktopEntries.applications
    }
}
