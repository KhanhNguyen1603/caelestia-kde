pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    required property SystemTrayItem modelData
    property var popouts
    property bool isHorizontal: false
    // Bar and overflow icons can be dragged between the two surfaces.
    property bool draggable: false
    readonly property string key: TrayRegistry.keyOfItem(root.modelData)
    readonly property string popoutName: TrayRegistry.popoutNameOf(root.modelData)
    readonly property bool hasMenuEntries: menuOpener.children.values.some(entry => !entry.isSeparator)

    implicitWidth: Tokens.font.body.small.pointSize * 2
    implicitHeight: Tokens.font.body.small.pointSize * 2

    property bool dragging: false
    property bool _dragArmed: false
    property point _dragOrigin: Qt.point(0, 0)
    property bool _suppressClick: false

    Drag.active: root.draggable && root.dragging
    Drag.source: root
    Drag.hotSpot: Qt.point(root.width / 2, root.height / 2)
    Drag.keys: ["trayIcon"]

    Component.onDestruction: {
        if (root.dragging)
            TrayRegistry.draggingIcon = false;
    }

    StateLayer {
        id: stateLayer

        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: root.implicitWidth + Tokens.padding.extraSmall
        implicitHeight: root.implicitHeight + Tokens.padding.extraSmall
        radius: Tokens.rounding.full
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        Accessible.role: Accessible.Button
        Accessible.name: root.modelData.title || root.modelData.id
        Accessible.description: root.hasMenuEntries && root.popouts ? qsTr("Left-click activates, right-click opens the menu, middle-click runs the secondary action.") : qsTr("Left-click activates, middle- or right-click runs the secondary action.")

        onPressed: mouse => {
            if (!root.draggable)
                return;
            root._dragOrigin = Qt.point(mouse.x, mouse.y);
            root._dragArmed = true;
        }

        onPositionChanged: mouse => {
            if (!root._dragArmed || root.dragging)
                return;
            if (Math.hypot(mouse.x - root._dragOrigin.x, mouse.y - root._dragOrigin.y) < 8)
                return;
            root.dragging = true;
            root._dragArmed = false;
            TrayRegistry.draggingIcon = true;
        }

        onReleased: {
            if (root.dragging) {
                root._suppressClick = true;
                Qt.callLater(() => root._suppressClick = false);
            }
            root.dragging = false;
            root._dragArmed = false;
            TrayRegistry.draggingIcon = false;
        }

        onCanceled: {
            root.dragging = false;
            root._dragArmed = false;
            TrayRegistry.draggingIcon = false;
        }

        onClicked: event => {
            if (root._suppressClick) {
                root._suppressClick = false;
                return;
            }
            if (event.button === Qt.LeftButton) {
                root.modelData.activate();
            } else if (event.button === Qt.MiddleButton || !root.hasMenuEntries || !root.popouts) {
                root.modelData.secondaryActivate();
            } else {
                root.popouts.currentName = root.popoutName;
                root.popouts.currentCenter = root.isHorizontal
                    ? root.mapToItem(null, root.implicitWidth / 2, 0).x
                    : root.mapToItem(null, 0, root.implicitHeight / 2).y;
                root.popouts.hasCurrent = true;
            }
        }
    }

    QsMenuOpener {
        id: menuOpener

        menu: root.modelData.menu // qmllint disable unresolved-type
    }

    ColouredIcon {
        id: icon

        anchors.fill: parent
        source: Icons.getTrayIcon(root.key, root.modelData.icon)
        colour: Colours.palette.m3secondary
        layer.enabled: Config.bar.tray.recolour
    }
}
