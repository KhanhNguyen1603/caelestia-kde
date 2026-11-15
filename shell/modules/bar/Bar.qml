pragma ComponentBehavior: Bound

import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import "components/performance"
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services
import qs.utils
import qs.modules.bar

Item {
    id: root

    required property ShellScreen screen
    Config.screen: screen.name
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    property Item currentHoveredItem: null
    // The tray loader that owns the item under the pointer, when that item is
    // nested inside the unified right-zone tray.
    property Item hoveredTray: null

    readonly property int vPadding: Tokens.padding.large

    readonly property real rawScale: !isNaN(Config.bar.scale) ? Config.bar.scale : 1.0
    readonly property real barScale: rawScale < 1.0 ? Math.sqrt(Math.max(0.1, rawScale)) : rawScale
    readonly property int thickness: Math.round(Tokens.sizes.bar.innerWidth * barScale)

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    readonly property real leftZoneSize: isHorizontal ? leftLayout.implicitWidth : leftLayout.implicitHeight
    readonly property real middleZoneSize: isHorizontal ? middleLayout.implicitWidth : middleLayout.implicitHeight
    readonly property real rightZoneSize: isHorizontal ? rightLayout.implicitWidth : rightLayout.implicitHeight

    property var leftEntries: BarWidgets.normalizedZoneEntries({ entries: Config.bar.entries }, "left")
    property var middleEntries: BarWidgets.normalizedZoneEntries({ entries: Config.bar.entries }, "middle")
    // The right layout is the unified tray plus the clock. The widgets that go
    // inside the tray come from systemTrayEntries; they are not drawn a second
    // time by this layout.
    property var rightEntries: BarWidgets.rightLayoutEntries({ entries: Config.bar.entries })
    readonly property var systemTrayEntries: BarWidgets.systemTrayEntries({ entries: Config.bar.entries })
    readonly property bool systemTrayShowsIcons: BarWidgets.systemTrayShowsIcons({ entries: Config.bar.entries })

    function resetHover(): void {
        if (currentHoveredItem)
            currentHoveredItem = null;
    }

    function getLoaderAt(x, y) {
        root.hoveredTray = null;

        let items = [leftLayout, middleLayout, rightLayout];
        for (let i = 0; i < items.length; i++) {
            let layout = items[i];
            let localPos = mapToItem(layout, x, y);
            if (localPos.x >= 0 && localPos.x <= layout.width && localPos.y >= 0 && localPos.y <= layout.height) {
                let ch = layout.childAt(localPos.x, localPos.y);
                if (ch && ch.hasOwnProperty("id")) {
                    if (ch.id === "tray" && ch.item && typeof ch.item.widgetAt === "function") {
                        const inner = ch.item.widgetAt(root, x, y);
                        if (inner) {
                            root.hoveredTray = ch;
                            return inner;
                        }
                    }
                    if (ch.id === "tray")
                        root.hoveredTray = ch;
                    return ch;
                }
            }
        }
        return null;
    }

    function closeTray(): void {
        if (popouts.currentName === "trayOverflow")
            popouts.hasCurrent = false;
    }

    function checkPopout(pos: real): void {
        // A context menu stays open while the pointer moves over the bar, so
        // the hover routing below must not take it over or close it.
        if (popouts.isContextPopout)
            return;

        // Dragging a widget between the tray and its overflow panel must not let
        // the hover routing swap the panel out from under the pointer.
        if (TrayDrag.active)
            return;

        const ch = getLoaderAt(isHorizontal ? pos : width / 2, isHorizontal ? height / 2 : pos) as WrappedLoader;

        currentHoveredItem = ch ? ch.item : null;

        if (root.hoveredTray) {
            closeTrayTimer.stop();
        } else if (!popouts.hasCurrent || !TrayRegistry.isTrayPopout(popouts.currentName)) {
            if (!closeTrayTimer.running)
                closeTrayTimer.restart();
        }

        if (!ch) {
            if (popouts.hasCurrent && (popouts.currentName === "dockhover" || popouts.currentName === "greeter")) return;
            if (!Config.bar.popouts.tray && TrayRegistry.isTrayPopout(popouts.currentName)) return;
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.id;
        let mappedChPos = mapFromItem(ch, 0, 0);
        const top = isHorizontal ? mappedChPos.x : mappedChPos.y;

        if (id === "tray" && !Config.bar.popouts.tray) {
            return;
        } else if (id === "tray" && Config.bar.popouts.tray && !visibilities.sidebar) {
            const tray = ch.item as Tray;
            if (tray.arrowHit(root, pos)) {
                // The arrow opens the overflow panel. Do not let the bar's hover
                // routing close that panel the moment the pointer reaches it.
                if (popouts.currentName !== "trayOverflow")
                    popouts.hasCurrent = false;
            } else {
                const trayItem = tray.itemAt(root, pos);
                popouts.hasCurrent = !!trayItem;
                if (trayItem) {
                    popouts.currentName = trayItem.popoutName;
                    popouts.currentCenter = isHorizontal ? trayItem.mapToItem(null, trayItem.implicitWidth / 2, 0).x : trayItem.mapToItem(null, 0, trayItem.implicitHeight / 2).y;
                }
            }
        } else if (BarWidgets.statusIconId(id).length > 0) {
            // Each status icon is its own widget, so the icon under the pointer is
            // the one whose popout opens: no hit test inside a shared row.
            const icon = ch.item;
            if (!Config.bar.popouts.statusIcons || !icon || (id === BarWidgets.statusIconPrefix + "notifications" && root.visibilities.sidebar)) {
                popouts.hasCurrent = false;
                return;
            }
            popouts.currentName = icon.popoutName;
            popouts.currentCenter = isHorizontal ? icon.mapToItem(null, icon.width / 2, 0).x : icon.mapToItem(null, 0, icon.height / 2).y;
            popouts.hasCurrent = true;
        } else if (id === "greeter" && Config.bar.popouts.greeter && Config.bar.greeter.showOnHover) {
            const item = ch.item as Item;
            if (item) {
                const relPos = pos - top;
                const inside = isHorizontal ? (relPos >= 0 && relPos <= item.implicitWidth) : (relPos >= 0 && relPos <= item.implicitHeight);
                if (inside) {
                    if (!popouts.hasCurrent || popouts.currentName !== "greetercontext") {
                        popouts.currentName = "greeter";
                        popouts.currentCenter = isHorizontal ? item.mapToItem(null, item.implicitWidth / 2, 0).x : (item.mapToItem(null, 0, item.implicitHeight / 2).y ?? 0);
                        popouts.hasCurrent = true;
                    }
                } else {
                    if (popouts.currentName !== "greetercontext") {
                        popouts.hasCurrent = false;
                    }
                }
            } else {
                popouts.hasCurrent = false;
            }
        } else if (id === "dock") {
            if (popouts.hasCurrent && (popouts.currentName === "dockcontext" || popouts.currentName === "dockbgcontext" || popouts.currentName === "greeter" || popouts.currentName === "greetercontext" || popouts.currentName === "statusiconscontext")) return;

            const item = ch.item;
            if (item && typeof item.handleHover === "function") {
                const relPos = pos - top;
                item.handleHover(relPos, isHorizontal, popouts);
                return;
            }
            popouts.hasCurrent = false;
        } else if (id === "github") {
            const item = ch.item as Item;
            if (item) {
                const relPos = pos - top;
                const inside = isHorizontal ? (relPos >= 0 && relPos <= item.implicitWidth) : (relPos >= 0 && relPos <= item.implicitHeight);
                if (inside) {
                    popouts.currentName = "github";
                    popouts.currentCenter = isHorizontal ? item.mapToItem(null, item.implicitWidth / 2, 0).x : (item.mapToItem(null, 0, item.implicitHeight / 2).y ?? 0);
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
            }
        } else if (id === "notes" || id === "weather" || id === "performance" || id === "shortcuts" || id === "screencapture" || id === "keepawake") {
            const item = ch.item as Item;
            if (item) {
                const relPos = pos - top;
                const inside = isHorizontal ? (relPos >= 0 && relPos <= item.implicitWidth) : (relPos >= 0 && relPos <= item.implicitHeight);
                if (inside) {
                    popouts.currentName = id;
                    popouts.currentCenter = isHorizontal ? item.mapToItem(null, item.implicitWidth / 2, 0).x : (item.mapToItem(null, 0, item.implicitHeight / 2).y ?? 0);
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
            }
        } else if (id === "media") {
            const item = ch.item as Item;
            if (item) {
                const relPos = pos - top;
                const inside = isHorizontal ? (relPos >= 0 && relPos <= item.implicitWidth) : (relPos >= 0 && relPos <= item.implicitHeight);
                if (inside) {
                    popouts.currentName = "media";
                    popouts.currentCenter = isHorizontal ? item.mapToItem(null, item.implicitWidth / 2, 0).x : (item.mapToItem(null, 0, item.implicitHeight / 2).y ?? 0);
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
            }
        } else if (id === "updateIndicator") {
            const item = ch.item as Item;
            if (item) {
                const relPos = pos - top;
                const inside = isHorizontal ? (relPos >= 0 && relPos <= item.implicitWidth) : (relPos >= 0 && relPos <= item.implicitHeight);
                if (inside) {
                    popouts.currentName = "updateIndicator";
                    popouts.currentCenter = isHorizontal ? item.mapToItem(null, item.implicitWidth / 2, 0).x : (item.mapToItem(null, 0, item.implicitHeight / 2).y ?? 0);
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
            }
        } else if (id === "clock") {
            if (Config.bar.popouts.clock) {
                const item = ch.item as Item;
                if (item) {
                    const relPos = pos - top;
                    const inside = isHorizontal ? (relPos >= 0 && relPos <= item.implicitWidth) : (relPos >= 0 && relPos <= item.implicitHeight);
                    if (inside) {
                        popouts.currentName = "clock";
                        popouts.currentCenter = isHorizontal ? item.mapToItem(null, item.implicitWidth / 2, 0).x : (item.mapToItem(null, 0, item.implicitHeight / 2).y ?? 0);
                        popouts.hasCurrent = true;
                    } else {
                        popouts.hasCurrent = false;
                    }
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
            }
        } else {
            // Plugin widgets (and any widget without a bespoke branch) opt into
            // hover popouts by exposing handleHover(pos, isHorizontal, popouts).
            const item = ch.item;
            if (item && typeof item.handleHover === "function") {
                item.handleHover(pos - top, isHorizontal, popouts);
                return;
            }
            popouts.hasCurrent = false;
        }
    }

    function handleWheel(pos: real, angleDelta: point): void {
        const ch = getLoaderAt(isHorizontal ? pos : width / 2, isHorizontal ? height / 2 : pos) as WrappedLoader;

        if (ch?.id === "dock") {
            if (ch.item && typeof ch.item.handleWheel === "function") {
                ch.item.handleWheel(angleDelta);
            }
            return;
        }

        // Plugin widgets (and any widget without a bespoke branch) opt into
        // scroll handling by exposing handleWheel(pos, isHorizontal, angleDelta).
        const item = ch?.item;
        if (item && typeof item.handleWheel === "function") {
            const mappedChPos = mapFromItem(ch, 0, 0);
            item.handleWheel(pos - (isHorizontal ? mappedChPos.x : mappedChPos.y), isHorizontal, angleDelta);
            return;
        }

        if (ch?.id === "workspaces" && Config.bar.scrollActions.workspaces) {
            const mon = (Config.bar.workspaces.perMonitor ? Kwin.monitorFor(screen) : Kwin.focusedMonitor);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Kwin.dispatch(Kwin.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            else {
                const activeId = Kwin.activeWsId;
                if (angleDelta.y < 0 || activeId > 1)
                    Kwin.dispatch(Kwin.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
            }
        } else if ((isHorizontal ? pos < screen.width / 2 : pos < screen.height / 2) && Config.bar.scrollActions.volume) {
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.stepBrightness(GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.stepBrightness(-GlobalConfig.services.brightnessIncrement);
        }
    }

    // Built-in widgets are handed the ambient values one by one in their own
    // delegate choice. Plugin widgets are plain components, so the values they
    // declare are filled in here instead and the rest are left alone.
    function applyWidgetContext(widget: var): void {
        if (!widget)
            return;

        const context = {
            bar: root,
            screen: root.screen,
            popouts: root.popouts,
            visibilities: root.visibilities
        };

        for (const name in context)
            if (widget.hasOwnProperty(name))
                widget[name] = context[name];
    }

    Component.onCompleted: {
        Logger.mark("bar-ready");
    }

    clip: true

    // The hidden-icons box draws the widgets the user dragged out of the tray with
    // the same delegate the bar uses, so they are live there rather than a stale
    // copy of an icon. A binding rather than an assignment: the box may be built
    // before the bar is.
    Binding {
        target: root.popouts
        property: "trayWidgetDelegate"
        value: barDelegate
    }

    Timer {
        id: closeTrayTimer

        interval: 400
        onTriggered: root.closeTray()
    }

    GridLayout {
        id: leftLayout

        anchors.left: isHorizontal ? parent.left : undefined
        anchors.top: !isHorizontal ? parent.top : undefined
        anchors.verticalCenter: isHorizontal ? parent.verticalCenter : undefined
        anchors.horizontalCenter: !isHorizontal ? parent.horizontalCenter : undefined

        anchors.leftMargin: isHorizontal ? root.vPadding : 0
        anchors.topMargin: !isHorizontal ? root.vPadding : 0

        columns: isHorizontal ? -1 : 1
        rows: isHorizontal ? 1 : -1
        flow: isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
        columnSpacing: Tokens.spacing.medium
        rowSpacing: Tokens.spacing.medium

        Repeater {
            id: leftRepeater

            model: root.leftEntries
            delegate: barDelegate
        }
    }

    GridLayout {
        id: middleLayout

        property real idealX: (parent.width - width) / 2
        property real minX: leftLayout.x + leftLayout.width + Tokens.spacing.medium
        property real maxX: rightLayout.x - width - Tokens.spacing.medium
        property real idealY: (parent.height - height) / 2
        property real minY: leftLayout.y + leftLayout.height + Tokens.spacing.medium
        property real maxY: rightLayout.y - height - Tokens.spacing.medium

        anchors.verticalCenter: isHorizontal ? parent.verticalCenter : undefined
        anchors.horizontalCenter: !isHorizontal ? parent.horizontalCenter : undefined
        columns: isHorizontal ? -1 : 1
        rows: isHorizontal ? 1 : -1
        flow: isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
        columnSpacing: Tokens.spacing.medium
        rowSpacing: Tokens.spacing.medium

        Binding on x {
            when: isHorizontal
            value: Math.max(middleLayout.minX, Math.min(middleLayout.idealX, middleLayout.maxX))
        }

        Binding on y {
            when: !isHorizontal
            value: Math.max(middleLayout.minY, Math.min(middleLayout.idealY, middleLayout.maxY))
        }

        Repeater {
            id: middleRepeater

            model: root.middleEntries
            delegate: barDelegate
        }
    }

    GridLayout {
        id: rightLayout

        anchors.right: isHorizontal ? parent.right : undefined
        anchors.bottom: !isHorizontal ? parent.bottom : undefined
        anchors.verticalCenter: isHorizontal ? parent.verticalCenter : undefined
        anchors.horizontalCenter: !isHorizontal ? parent.horizontalCenter : undefined

        anchors.rightMargin: isHorizontal ? root.vPadding : 0
        anchors.bottomMargin: !isHorizontal ? root.vPadding : 0

        columns: isHorizontal ? -1 : 1
        rows: isHorizontal ? 1 : -1
        flow: isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
        columnSpacing: Tokens.spacing.medium
        rowSpacing: Tokens.spacing.medium

        Repeater {
            id: rightRepeater

            model: root.rightEntries
            delegate: barDelegate
        }
    }

    DelegateChooser {
        id: barDelegate

        // The chooser picks on `kind`, which is the widget id for everything the
        // registry declares and its own name for entries that stand for one item
        // of a group, like a single status icon.
        role: "kind"

            DelegateChoice {
                roleValue: "logo"
                delegate: WrappedLoader {
                    sourceComponent: OsIcon {
                        bar: root
                    }
                }
            }
            DelegateChoice {
                roleValue: "workspaces"
                delegate: WrappedLoader {
                    sourceComponent: Workspaces {
                        bar: root
                        screen: root.screen
                        fullscreen: root.fullscreen
                    }
                }
            }
            DelegateChoice {
                roleValue: "dock"
                delegate: WrappedLoader {
                    sourceComponent: Dock {
                        bar: root
                    }
                }
            }
            DelegateChoice {
                roleValue: "greeter"
                delegate: WrappedLoader {
                    sourceComponent: Greeter {
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: WrappedLoader {
                    id: trayLoader

                    sourceComponent: Tray {
                        popouts: root.popouts
                        showTrayIcons: trayLoader.systemTray ? root.systemTrayShowsIcons : true
                        widgetEntries: trayLoader.systemTray ? root.systemTrayEntries : []
                        widgetDelegate: trayLoader.systemTray ? barDelegate : null
                    }
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: WrappedLoader {
                    sourceComponent: Clock {
                        bar: root
                    }
                }
            }
            DelegateChoice {
                roleValue: "statusIcon"
                delegate: WrappedLoader {
                    id: statusLoader

                    sourceComponent: StatusIcon {
                        entryId: statusLoader.widgetId
                        popouts: root.popouts
                        bar: root
                    }
                }
            }
            DelegateChoice {
                roleValue: "kbLayoutIndicator"
                delegate: WrappedLoader {
                    visible: enabled && (Kwin.kbLayout || "").length > 0
                    sourceComponent: KbLayoutIndicator {
                        popouts: root.popouts
                    }
                }
            }
            DelegateChoice {
                roleValue: "notificationsIndicator"
                delegate: WrappedLoader {
                    sourceComponent: NotificationsIndicator {}
                }
            }
            DelegateChoice {
                roleValue: "updateIndicator"
                delegate: WrappedLoader {
                    visible: enabled && GlobalConfig.general.checkUpdates
                    sourceComponent: UpdateIndicator {}
                }
            }
            DelegateChoice {
                roleValue: "perfCpu"
                delegate: WrappedLoader {
                    visible: enabled && Cpu.name.length > 0
                    sourceComponent: PerfCpu {
                        popouts: root.popouts
                    }
                }
            }
            DelegateChoice {
                roleValue: "perfMemory"
                delegate: WrappedLoader {
                    visible: enabled && Memory.total > 1
                    sourceComponent: PerfMemory {
                        popouts: root.popouts
                    }
                }
            }
            DelegateChoice {
                roleValue: "perfStorage"
                delegate: WrappedLoader {
                    visible: enabled && Storage.disks.length > 0
                    sourceComponent: PerfStorage {
                        popouts: root.popouts
                    }
                }
            }
            DelegateChoice {
                roleValue: "perfNetwork"
                delegate: WrappedLoader {
                    sourceComponent: PerfNetwork {
                        popouts: root.popouts
                    }
                }
            }
            DelegateChoice {
                roleValue: "perfGpu"
                delegate: WrappedLoader {
                    visible: enabled && Gpu.type !== Gpu.None
                    sourceComponent: PerfGpu {
                        popouts: root.popouts
                    }
                }
            }
            DelegateChoice {
                roleValue: "perfBattery"
                delegate: WrappedLoader {
                    visible: enabled && UPower.displayDevice.isLaptopBattery
                    sourceComponent: PerfBattery {
                        popouts: root.popouts
                    }
                }
            }
            DelegateChoice {
                roleValue: "github"
                delegate: WrappedLoader {
                    visible: enabled && GithubStore.available
                    sourceComponent: GithubActivity {
                        popouts: root.popouts
                    }
                }
            }
            DelegateChoice {
                roleValue: "media"
                delegate: WrappedLoader {
                    sourceComponent: Media {
                        popouts: root.popouts
                    }
                }
            }
            DelegateChoice {
                roleValue: "notes"
                delegate: WrappedLoader {
                    sourceComponent: Notes {
                        popouts: root.popouts
                    }
                }
            }
            DelegateChoice {
                roleValue: "weather"
                delegate: WrappedLoader {
                    sourceComponent: WeatherWidget {
                        popouts: root.popouts
                    }
                }
            }
            DelegateChoice {
                roleValue: "performance"
                delegate: WrappedLoader {
                    sourceComponent: PerformanceWidget {
                        popouts: root.popouts
                    }
                }
            }
            DelegateChoice {
                roleValue: "shortcuts"
                delegate: WrappedLoader {
                    sourceComponent: ShortcutsWidget {
                        popouts: root.popouts
                    }
                }
            }
            DelegateChoice {
                roleValue: "screencapture"
                delegate: WrappedLoader {
                    sourceComponent: ScreenCaptureWidget {
                        popouts: root.popouts
                    }
                }
            }
            DelegateChoice {
                roleValue: "keepawake"
                delegate: WrappedLoader {
                    sourceComponent: KeepAwakeWidget {
                        popouts: root.popouts
                    }
                }
            }
            DelegateChoice {
                roleValue: "showDesktop"
                delegate: WrappedLoader {
                    sourceComponent: ShowDesktop {}
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: WrappedLoader {
                    sourceComponent: Power {
                        visibilities: root.visibilities
                    }
                }
            }
            // Fallback for plugin-provided widgets: DelegateChooser needs a
            // static choice per id, so unknown ids resolve their component at
            // runtime from the plugin registry.
            DelegateChoice {
                delegate: WrappedLoader {
                    source: BarWidgetRegistry.widget(id)?.componentUrl ?? ""

                    onItemChanged: root.applyWidgetContext(item)
                }
            }
        }

    component WrappedLoader: Loader {
        id: wrapper

        required enabled
        required property string id
        required property int index

        // Filled from the entry the registry hands the view. `systemTray` marks
        // the synthetic tray container, and `zone` tells a widget whether it is
        // being drawn inside it.
        required property bool systemTray
        required property string zone

        // Anything the tray draws can be dragged into its hidden-icons box, and
        // anything in the box can be dragged back. The widget itself is untouched:
        // the gesture is recognised over it, so a click still reaches the widget.
        required property bool draggable
        readonly property string widgetId: id
        readonly property bool dragging: trayDrag.active

        asynchronous: false
        Layout.alignment: root.isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.maximumWidth: implicitWidth
        Layout.maximumHeight: implicitHeight
        Layout.minimumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight

        // Fading only once the ghost exists keeps the snapshot clean and means the
        // widget never disappears before there is something under the pointer.
        opacity: wrapper.dragging && TrayDrag.ghost !== null ? 0.35 : 1

        visible: enabled
        active: enabled

        DragHandler {
            id: trayDrag

            target: null
            enabled: wrapper.draggable
            grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByAnything

            onActiveChanged: {
                if (active) {
                    TrayDrag.begin("widget", "", wrapper.widgetId, wrapper.Window.window);
                    TrayDrag.move(centroid.scenePosition);
                    const grabbedAt = centroid.pressPosition;
                    wrapper.grabToImage(result => TrayDrag.setGhost(result, wrapper.width, wrapper.height, grabbedAt));
                } else if (TrayDrag.active) {
                    TrayDrag.finish();
                }
            }

            onTranslationChanged: {
                if (active)
                    TrayDrag.move(centroid.scenePosition);
            }
        }
    }
}
