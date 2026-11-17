pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar

Item {
    id: root

    readonly property alias layout: layout
    readonly property alias expandIcon: expandIcon

    // The icons sit inside a pill of their own, so the space around them is a step wider
    // than the inset the other bar widgets use: at the medium inset the row read as pinned
    // to the edge of the pill rather than held in it.
    readonly property int padding: root.hasBackground ? Tokens.padding.large : Tokens.padding.small
    readonly property int spacing: root.hasBackground ? Tokens.spacing.small : 0

    // When the tray owns the right-zone widgets it is the one system tray for
    // the bar, and it draws a single surface behind all of them. Without extra
    // widgets it keeps the old standalone-tray look.
    property var widgetEntries: []
    property var widgetDelegate: null
    property bool showTrayIcons: true
    readonly property bool unified: root.widgetEntries.length > 0
    readonly property bool hasBackground: Config.bar.tray.background || root.unified

    property var popouts
    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property int barThickness: Math.round(Tokens.sizes.bar.innerWidth * Math.max(0.6, !isNaN(Config.bar.scale) ? Config.bar.scale : 1.0))

    // The chevron is the box's handle, so it is on the bar for as long as the tray
    // is: an empty box still needs somewhere to be opened from.
    readonly property bool showArrow: root.showTrayIcons

    readonly property real nonAnimHeight: {
        if (isHorizontal)
            return barThickness;
        return arrowSize + arrowGap + layout.implicitHeight + padding * 2;
    }

    readonly property real nonAnimWidth: {
        if (!isHorizontal)
            return barThickness;
        return arrowSize + arrowGap + layout.implicitWidth + padding * 2;
    }

    // The surface is exactly the size its icons need, and it is that size as soon as they
    // are: an animation here would run behind the bar's own layout, which reflows in a
    // frame, and the icons would read as landing late.

    // The chevron sits on the bar, outside the surface the icons share, and is the
    // only thing that makes the surface start further in.
    readonly property real arrowSize: root.showArrow && expandIcon.item ? (root.isHorizontal ? expandIcon.item.implicitWidth : expandIcon.item.implicitHeight) : 0
    readonly property real arrowGap: root.showArrow && expandIcon.item ? root.spacing : 0

    // The child of the row nearest the point, among the ones that can take the drop:
    // dropping between two icons still has somewhere to go.
    function closestChild(repeater: var, x: real, y: real, accept: var): var {
        const own = root.ownPoint(x, y);
        const p = layout.mapFromItem(null, own.x, own.y);
        const along = root.isHorizontal ? p.x : p.y;
        let best = null;
        let bestDist = Infinity;
        for (let i = 0; i < repeater.count; i++) {
            const child = repeater.itemAt(i);
            if (!child || !child.visible)
                continue;
            if (accept && !accept(child))
                continue;
            const start = root.isHorizontal ? child.x : child.y;
            const size = root.isHorizontal ? child.width : child.height;
            if (along >= start && along <= start + size)
                return child;
            const dist = Math.abs(along - (start + size / 2));
            if (dist < bestDist) {
                bestDist = dist;
                best = child;
            }
        }
        return best;
    }

    // Where the widget a drag carries would land, or null when the row is empty: the
    // tray's icons and the bar's own share one row now, so any cell can take a drop.
    function dropTarget(kind: string, id: string, x: real, y: real): var {
        return root.closestChild(widgetItems, x, y);
    }

    // Hit test for the bar's hover routing: the positioner owns the layout, so it also
    // owns which icon sits under a bar coordinate.
    function widgetAt(barItem: var, x: real, y: real): var {
        const p = layout.mapFromItem(barItem, x, y);
        for (let i = 0; i < widgetItems.count; i++) {
            const child = widgetItems.itemAt(i);
            if (!child || !child.visible)
                continue;
            if (p.x >= child.x && p.x <= child.x + child.width && p.y >= child.y && p.y <= child.y + child.height)
                return child;
        }
        return null;
    }

    // `pos` is the pointer's cross-axis coordinate on the bar, which is all the hover
    // routing has: the chevron is matched against its own span on that axis.
    function arrowHit(barItem: var, pos: real): bool {
        const item = expandIcon.item;
        if (!item)
            return false;
        const center = root.isHorizontal ? item.mapToItem(barItem, item.width / 2, 0).x : item.mapToItem(barItem, 0, item.height / 2).y;
        const size = root.isHorizontal ? item.width : item.height;
        return pos >= center - size / 2 - root.spacing && pos <= center + size / 2 + root.spacing;
    }

    // The point on the bar the box hangs from: the chevron when it is there, the
    // tray itself when it is not.
    function anchor(): real {
        if (expandIcon.item) {
            return root.isHorizontal
                ? expandIcon.item.mapToItem(null, expandIcon.item.width / 2, 0).x
                : expandIcon.item.mapToItem(null, 0, expandIcon.item.height / 2).y;
        }
        return root.isHorizontal ? root.mapToItem(null, root.width / 2, 0).x : root.mapToItem(null, 0, root.height / 2).y;
    }

    // The box hangs from the chevron, and the chevron moves whenever an icon leaves the
    // tray for the box and the bar makes room for one fewer. The tray is resized before
    // the bar has moved it, so the chevron is read a pass later: mapping it now answers
    // with the place it is about to leave.
    function followBox(): void {
        if (root.popouts && root.popouts.hasCurrent && root.popouts.currentName === "trayOverflow")
            Qt.callLater(() => {
                if (root.popouts.hasCurrent && root.popouts.currentName === "trayOverflow")
                    root.popouts.currentCenter = root.anchor();
            });
    }

    // The box opens from the chevron and is centred on it, or on the tray when there
    // is no chevron yet. Opening it for the whole of a drag is what lets a tray icon
    // be dropped into it: there is nowhere else for the gesture to end.
    function openOverflow(): void {
        if (!root.popouts)
            return;
        if (root.popouts.hasCurrent && root.popouts.currentName === "trayOverflow")
            return;
        root.popouts.currentName = "trayOverflow";
        root.popouts.currentCenter = root.anchor();
        root.popouts.hasCurrent = true;
    }

    // The panel that says where each icon goes: the tray's own gesture, on the arrow or
    // anywhere the icons are not, opens it instead of a jump into the settings window.
    function openIcons(): void {
        if (!root.popouts)
            return;
        root.popouts.currentName = "trayicons";
        root.popouts.currentCenter = root.isHorizontal ? root.mapToItem(null, root.implicitWidth / 2, 0).x : (root.mapToItem(null, 0, root.implicitHeight / 2).y ?? 0);
        root.popouts.hasCurrent = true;
    }

    // The arrow is the box's handle: it opens the box and leaves it open, so the icons
    // can be picked from without the pointer having to stay on them. Clicking it again
    // — or clicking anywhere else — closes it.
    function toggleOverflow(): void {
        if (!root.popouts)
            return;

        if (root.popouts.hasCurrent && root.popouts.currentName === "trayOverflow") {
            root.popouts.hasCurrent = false;
            return;
        }

        root.openOverflow();
        root.popouts.staysOpen = true;
    }

    // Whether a drop is near enough the tray to belong to it. An empty tray is a chevron
    // and a little padding, which is a small thing to aim at, so a drop half a bar away
    // from it still counts: there is nowhere else on the bar for one of these to land.
    function nearTray(x: real, y: real): bool {
        const own = root.ownPoint(x, y);
        const p = root.mapFromItem(null, own.x, own.y);
        const reach = Math.round(root.barThickness * 0.5);
        return p.x >= -reach && p.y >= -reach && p.x <= root.width + reach && p.y <= root.height + reach;
    }

    // A drag that starts in the box is lifted from the popout's window and released
    // over the bar's, so the move has to work across the two: they are compared by
    // screen, and only when both report one, which keeps another output's tray from
    // answering for this one.
    function onDragScreen(window: var): bool {
        const mine = root.Window.window;
        if (!window || !mine)
            return false;
        return !window.screen || !mine.screen || window.screen === mine.screen;
    }

    function trayDropAt(window: var, x: real, y: real): bool {
        if (!root.visible || !root.onDragScreen(window))
            return false;
        return root.nearTray(x, y);
    }

    // A drop arrives in screen coordinates, because the box it may be heading for is a
    // different window; the tray turns it into one of its own before using it.
    function ownPoint(x: real, y: real): point {
        return TrayDrag.toLocal(root.Window.window, x, y);
    }

    // Dropping on the tray puts the icon or the widget back on the bar, in the place of
    // the one it landed on. Hiding something is the box's job, and the box is open for
    // the whole drag: making the chevron send a drop to the box would leave an empty
    // tray with nowhere to drop one back onto.
    function trayDrop(source: var, x: real, y: real): void {
        if (!source)
            return;

        // Scene coordinates: `dropTarget` maps from the item it is given, and the drop
        // arrives in the window's space. The nearest cell takes the drop, so landing
        // between two icons still moves something. A tray icon now holds a row like any
        // other, so it is moved the same way.
        const target = root.dropTarget(source.kind, source.kind === "icon" ? source.key : source.widgetId, x, y);
        const id = source.kind === "icon" ? TrayRegistry.rowOf(source.key) : source.widgetId;
        const beforeId = target?.id ?? "";
        // A drop on an icon takes that icon's place. One on empty bar space only says the
        // icon belongs on the bar, so its own place is kept where it has one.
        BarPlacements.setPlacement(id, "bar", {
            zone: beforeId || source.kind === "widget" ? "right" : undefined,
            beforeId: beforeId
        });
    }

    visible: height > 0

    implicitWidth: isHorizontal ? nonAnimWidth : barThickness
    implicitHeight: isHorizontal ? barThickness : nonAnimHeight

    onWidthChanged: root.followBox()
    onHeightChanged: root.followBox()
    onXChanged: root.followBox()
    onYChanged: root.followBox()

    Component.onCompleted: TrayDrag.register(root)

    Component.onDestruction: TrayDrag.unregister(root)

    // The box is where a drag off the bar ends, so it is open for the whole gesture.
    Connections {
        function onActiveChanged(): void {
            if (TrayDrag.active)
                Qt.callLater(() => root.openOverflow());
        }

        target: TrayDrag
    }

    // The hidden-icons chevron sits on the bar, not in the cluster: that is where
    // Windows keeps it, and it is what the box opens from.
    Loader {
        id: expandIcon

        visible: root.showArrow
        active: root.showArrow

        anchors.left: root.isHorizontal ? parent.left : undefined
        anchors.top: root.isHorizontal ? undefined : parent.top
        anchors.verticalCenter: root.isHorizontal ? parent.verticalCenter : undefined
        anchors.horizontalCenter: root.isHorizontal ? undefined : parent.horizontalCenter

        sourceComponent: Item {
            id: arrowContainer

            readonly property real iconDimension: Math.max(arrowIcon.implicitWidth, arrowIcon.implicitHeight)
            // The chevron is a control on the bar, so it takes a hover wash instead
            // of floating on its own.
            property bool hovered: false

            implicitWidth: iconDimension
            implicitHeight: iconDimension

            HoverHandler {
                onHoveredChanged: arrowContainer.hovered = hovered
            }

            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.full
                color: Colours.tPalette.m3surfaceContainer
                opacity: arrowContainer.hovered ? 0.9 : 0

                Behavior on opacity {
                    Anim {}
                }
            }

            TapHandler {
                margin: Tokens.padding.extraSmall
                cursorShape: Qt.PointingHandCursor
                onTapped: root.toggleOverflow()
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onTapped: root.openIcons()
            }

            MaterialIcon {
                id: arrowIcon

                anchors.centerIn: parent
                text: "expand_less"
                fontStyle: Tokens.font.icon.large
                rotation: Config.bar.position === "top" ? 180 : Config.bar.position === "left" ? 90 : Config.bar.position === "right" ? 270 : 0

                Behavior on rotation {
                    Anim {}
                }
            }
        }
    }

    StyledRect {
        id: surface

        readonly property bool filled: root.hasBackground && widgetItems.count > 0

        x: root.isHorizontal ? root.arrowSize + root.arrowGap : 0
        y: root.isHorizontal ? 0 : root.arrowSize + root.arrowGap
        width: root.isHorizontal ? root.width - x : root.width
        height: root.isHorizontal ? root.height : root.height - y
        clip: true

        color: Qt.alpha(Colours.tPalette.m3surfaceContainer, surface.filled ? Colours.tPalette.m3surfaceContainer.a : 0)
        radius: Tokens.rounding.full

        // icon-level
        // right-clicks stay with the icons themselves (their own handlers sit on top
        // of this one, so they win first).
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (!root.popouts)
                    return;
                // The tray's own gesture is where the icons are chosen from: one list of
                // every icon with the three places beside it.
                root.openIcons();
                mouse.accepted = true;
            }
        }

        Grid {
            id: layout

            anchors.centerIn: parent

            columns: isHorizontal ? -1 : 1
            rows: isHorizontal ? 1 : -1
            flow: isHorizontal ? Grid.LeftToRight : Grid.TopToBottom

            spacing: Tokens.spacing.small

            // A row is rebuilt from the bar's entry list whenever that list is written,
            // and every icon in it is added again. A scale-in on each of them makes one
            // icon moving look like the whole tray emptying and refilling, so adding is
            // silent and only what actually moves animates.
            move: Transition {
                Anim {
                    properties: "x,y"
                }
            }

            Repeater {
                id: widgetItems

                model: root.widgetEntries
                delegate: root.widgetDelegate
            }
        }
    }

    // Where a dragged icon would land: a bar between two icons, so a drop reads as a
    // move before the button is let go.
    StyledRect {
        id: dropMarker

        readonly property var slot: TrayDrag.active && root.trayDropAt(TrayDrag.window, TrayDrag.pos.x, TrayDrag.pos.y) ? root.dropTarget(TrayDrag.kind, TrayDrag.kind === "icon" ? TrayDrag.key : TrayDrag.widgetId, TrayDrag.pos.x, TrayDrag.pos.y) : null

        visible: root.isHorizontal && dropMarker.slot !== null
        width: Tokens.padding.extraSmall
        height: Math.round(root.barThickness * 0.6)
        radius: Tokens.rounding.full
        color: Colours.palette.m3primary
        // In the gap before the icon, which is where the dragged one would be put: on
        // top of an icon it reads as a highlight rather than a place.
        x: dropMarker.slot ? Math.round(dropMarker.slot.mapToItem(root, 0, 0).x - root.spacing / 2 - width / 2) : 0
        y: Math.round((root.height - height) / 2)
    }
}
