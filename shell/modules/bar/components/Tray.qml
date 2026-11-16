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

    readonly property int padding: root.hasBackground ? Tokens.padding.medium : Tokens.padding.extraSmall
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

    function arrowHit(barItem: var, x: real, y: real): bool {
        if (!expandIcon.item)
            return false;
        const p = expandIcon.mapFromItem(barItem, x, y);
        const coord = isHorizontal ? p.x : p.y;
        const size = isHorizontal ? expandIcon.width : expandIcon.height;
        return coord >= -root.spacing && coord <= size + root.spacing;
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
        root.popouts.trayPinned = true;
    }

    function overChevron(x: real, y: real): bool {
        if (!root.showArrow || !expandIcon.item)
            return false;
        const own = root.ownPoint(x, y);
        const corner = expandIcon.mapToItem(null, 0, 0);
        const reach = root.spacing;
        return own.x >= corner.x - reach && own.x <= corner.x + root.arrowSize + reach && own.y >= corner.y - reach && own.y <= corner.y + root.arrowSize + reach;
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
        const own = root.ownPoint(x, y);
        const p = root.mapFromItem(null, own.x, own.y);
        return p.x >= 0 && p.y >= 0 && p.x <= root.width && p.y <= root.height;
    }

    // A drop arrives in screen coordinates, because the box it may be heading for is a
    // different window; the tray turns it into one of its own before using it.
    function ownPoint(x: real, y: real): point {
        return TrayDrag.toLocal(root.Window.window, x, y);
    }

    // Dropping on the chevron is the same move as dropping in the box, and dropping
    // on the icons puts the icon or the widget back on the bar, in the place of the
    // one it landed on.
    function trayDrop(source: var, x: real, y: real): void {
        if (!source)
            return;

        const toBox = root.overChevron(x, y);
        if (toBox) {
            root.openOverflow();
            if (source.kind === "widget")
                BarWidgets.setInTray(GlobalConfig.bar, source.widgetId);
            else if (source.kind === "icon") {
                BarWidgets.clearRow(GlobalConfig.bar, TrayRegistry.rowOf(source.key));
                TrayRegistry.sendToBox(source.key);
            }
            return;
        }

        // Scene coordinates: `dropTarget` maps from the item it is given, and the drop
        // arrives in the window's space. The nearest cell takes the drop, so landing
        // between two icons still moves something. A tray icon now holds a row like any
        // other, so it is moved the same way.
        const target = root.dropTarget(source.kind, source.kind === "icon" ? source.key : source.widgetId, x, y);
        if (source.kind === "widget") {
            BarWidgets.setOnBar(GlobalConfig.bar, source.widgetId);
            if (target && target.id)
                BarWidgets.moveBefore(GlobalConfig.bar, source.widgetId, target.id);
        } else if (source.kind === "icon") {
            TrayRegistry.sendToBar(source.key);
            if (target && target.id)
                BarWidgets.moveBefore(GlobalConfig.bar, TrayRegistry.rowOf(source.key), target.id);
        }
    }

    visible: height > 0

    implicitWidth: isHorizontal ? nonAnimWidth : barThickness
    implicitHeight: isHorizontal ? barThickness : nonAnimHeight

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
                root.popouts.currentName = "traycontext";
                root.popouts.currentCenter = root.isHorizontal ? root.mapToItem(null, root.implicitWidth / 2, 0).x : (root.mapToItem(null, 0, root.implicitHeight / 2).y ?? 0);
                root.popouts.hasCurrent = true;
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

            add: Transition {
                Anim {
                    properties: "scale"
                    from: 0
                    to: 1
                    easing: Tokens.anim.standardDecel
                }
            }

            move: Transition {
                Anim {
                    properties: "scale"
                    to: 1
                    easing: Tokens.anim.standardDecel
                }
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
        radius: width / 2
        color: Colours.palette.m3primary
        // In the gap before the icon, which is where the dragged one would be put: on
        // top of an icon it reads as a highlight rather than a place.
        x: dropMarker.slot ? Math.round(dropMarker.slot.mapToItem(root, 0, 0).x - root.spacing / 2 - width / 2) : 0
        y: Math.round((root.height - height) / 2)
    }

    Behavior on implicitHeight {
        enabled: !isHorizontal

        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitWidth {
        enabled: isHorizontal

        Anim {
            type: Anim.DefaultSpatial
        }
    }
}
