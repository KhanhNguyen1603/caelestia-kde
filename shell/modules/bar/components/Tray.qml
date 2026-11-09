pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar

StyledRect {
    id: root

    readonly property alias layout: layout
    readonly property alias items: items
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

    readonly property bool showArrow: root.showTrayIcons && TrayRegistry.overflowCount > 0

    readonly property real nonAnimHeight: {
        if (isHorizontal)
            return barThickness;
        return layout.implicitHeight + padding * 2;
    }

    readonly property real nonAnimWidth: {
        if (!isHorizontal)
            return barThickness;
        return layout.implicitWidth + padding * 2;
    }

    // Hit test for the bar's hover routing: the positioner owns the layout, so it
    // also owns which icon sits under a bar coordinate. `barItem` is the bar
    // itself, because the tray may be nested inside the unified right-zone
    // wrapper and its local coordinates are no longer the bar's.
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

    function itemAt(barItem: var, x: real, y: real): TrayItem {
        const p = layout.mapFromItem(barItem, x, y);
        for (let i = 0; i < items.count; i++) {
            const child = items.itemAt(i) as TrayItem;
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
        return coord >= -root.spacing && coord <= size + root.padding;
    }

    clip: true
    visible: height > 0

    implicitWidth: isHorizontal ? nonAnimWidth : barThickness
    implicitHeight: isHorizontal ? barThickness : nonAnimHeight

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, (root.hasBackground && (items.count > 0 || widgetItems.count > 0)) ? Colours.tPalette.m3surfaceContainer.a : 0)
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

        anchors.horizontalCenter: isHorizontal ? undefined : parent.horizontalCenter
        anchors.verticalCenter: isHorizontal ? parent.verticalCenter : undefined
        anchors.top: isHorizontal ? undefined : parent.top
        anchors.topMargin: isHorizontal ? 0 : root.padding
        anchors.left: isHorizontal ? parent.left : undefined
        anchors.leftMargin: isHorizontal ? root.padding : 0

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

        Loader {
            id: expandIcon

            visible: root.showArrow
            active: root.showArrow

            sourceComponent: Item {
                id: arrowContainer

                readonly property real iconDimension: Math.max(expandIconInner.implicitWidth, expandIconInner.implicitHeight)

                implicitWidth: iconDimension
                implicitHeight: iconDimension

                TapHandler {
                    margin: Tokens.padding.extraSmall
                    cursorShape: Qt.PointingHandCursor

                    onTapped: {
                        if (!root.popouts)
                            return;

                        if (root.popouts.hasCurrent && root.popouts.currentName === "trayOverflow") {
                            root.popouts.hasCurrent = false;
                            return;
                        }

                        root.popouts.currentName = "trayOverflow";
                        root.popouts.currentCenter = root.isHorizontal
                            ? arrowContainer.mapToItem(null, arrowContainer.width / 2, 0).x
                            : arrowContainer.mapToItem(null, 0, arrowContainer.height / 2).y;
                        root.popouts.hasCurrent = true;
                    }
                }

                MaterialIcon {
                    id: expandIconInner

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

        Repeater {
            id: items

            model: ScriptModel {
                values: root.showTrayIcons ? TrayRegistry.barItems : []
            }

            TrayItem {
                popouts: root.popouts
                isHorizontal: root.isHorizontal
                draggable: true
            }
        }

        Repeater {
            id: widgetItems

            model: root.widgetEntries
            delegate: root.widgetDelegate
        }
    }

    // Dropping a hidden icon on the tray pins it back to the bar.
    DropArea {
        anchors.fill: parent
        keys: ["trayIcon", "barWidget"]

        onDropped: drop => {
            const source = drop.source;
            if (!source)
                return;
            if (source.key)
                TrayRegistry.setState(source.key, "visible");
            else if (source.widgetId)
                BarWidgets.setEnabled(GlobalConfig.bar, source.widgetId, true);
            TrayRegistry.draggingIcon = false;
        }
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
