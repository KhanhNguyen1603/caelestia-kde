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
    property bool draggable: false
    readonly property string key: TrayRegistry.keyOfItem(root.modelData)
    readonly property string popoutName: TrayRegistry.popoutNameOf(root.modelData)
    readonly property bool hasMenuEntries: menuOpener.children.values.some(entry => !entry.isSeparator)
    readonly property bool dragging: stateLayer.dragging
    // A tray icon sits in the same slot as the bar's widgets, so the row lines up,
    // and its glyph is drawn at the size of the icons beside it instead of filling
    // the slot the way an application logo would.
    readonly property int barThickness: Math.round(Tokens.sizes.bar.innerWidth * Math.max(0.6, !isNaN(Config.bar.scale) ? Config.bar.scale : 1.0))
    readonly property real glyphSize: Math.round(Tokens.font.body.small.pointSize * 1.5)

    implicitWidth: root.isHorizontal ? root.glyphSize + Tokens.padding.small * 2 : root.barThickness
    implicitHeight: root.isHorizontal ? root.barThickness : root.glyphSize + Tokens.padding.small * 2

    opacity: root.dragging ? 0.4 : 1

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    TrayDragSurface {
        id: stateLayer

        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: root.implicitWidth + Tokens.padding.extraSmall
        implicitHeight: root.implicitHeight + Tokens.padding.extraSmall
        radius: Tokens.rounding.full
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        draggable: root.draggable
        key: root.key

        Accessible.role: Accessible.Button
        Accessible.name: root.modelData.title || root.modelData.id
        Accessible.description: root.hasMenuEntries && root.popouts ? qsTr("Left-click activates, right-click opens the menu, middle-click runs the secondary action.") : qsTr("Left-click activates, middle- or right-click runs the secondary action.")

        onTapped: event => {
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

        anchors.centerIn: parent
        implicitSize: root.glyphSize
        source: Icons.getTrayIcon(root.key, root.modelData.icon)
        colour: Colours.palette.m3secondary
        layer.enabled: Config.bar.tray.recolour
    }
}
