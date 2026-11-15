pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components
import qs.components.controls
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
    readonly property bool dragging: dragHandler.active
    // A tray icon sits in the same slot as the bar's widgets, so the row lines up,
    // and its glyph is drawn at the size of the icons beside it instead of filling
    // the slot the way an application logo would.
    readonly property int barThickness: Math.round(Tokens.sizes.bar.innerWidth * Math.max(0.6, !isNaN(Config.bar.scale) ? Config.bar.scale : 1.0))
    // Bigger than the text it sits beside: a tray glyph is read at a glance, and the
    // bar has room for it.
    readonly property real glyphSize: Math.round(Tokens.font.icon.small.pointSize * 1.2)
    // Hovering says what the icon is; the menu is the right button's job.
    readonly property string tooltip: root.modelData ? (root.modelData.title || root.modelData.id) : ""
    readonly property bool hovered: stateLayer.containsMouse && !(root.popouts?.hasCurrent ?? false)

    implicitWidth: root.isHorizontal ? root.glyphSize + Tokens.padding.small * 2 : root.barThickness
    implicitHeight: root.isHorizontal ? root.barThickness : root.glyphSize + Tokens.padding.small * 2
    // Fading only once the ghost exists keeps the snapshot clean and means the icon
    // never disappears before there is something under the pointer to replace it.
    opacity: root.dragging && TrayDrag.ghost !== null ? 0.35 : 1

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    StateLayer {
        id: stateLayer

        property bool suppressClick: false

        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: root.implicitWidth + Tokens.padding.extraSmall
        implicitHeight: root.implicitHeight + Tokens.padding.extraSmall
        radius: Tokens.rounding.full
        // No plate under the pointer: hover is for reading the icon's name.
        showHoverBackground: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        Accessible.role: Accessible.Button
        Accessible.name: root.modelData.title || root.modelData.id
        Accessible.description: root.hasMenuEntries && root.popouts ? qsTr("Left-click activates, right-click opens the menu, middle-click runs the secondary action.") : qsTr("Left-click activates, middle- or right-click runs the secondary action.")

        onClicked: event => {
            if (stateLayer.suppressClick) {
                stateLayer.suppressClick = false;
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

    // The gesture is recognised over the icon rather than by watching its press: a
    // pointer handler lifts the icon without stopping the click underneath it, which
    // is how a bar widget is lifted too, so both kinds of item behave alike.
    TrayDragGesture {
        id: dragHandler

        kind: "icon"
        key: root.key
        enabled: root.draggable
        ghostSource: icon

        onDropped: stateLayer.suppressClick = true
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

    Loader {
        asynchronous: true
        active: root.tooltip.length > 0
        z: 10000
        width: 0
        height: 0

        sourceComponent: Component {
            Tooltip {
                // The window is the whole screen, unlike the bar's clipped strip:
                // a tooltip placed against it is not cut off by the bar.
                parent: root.Window.contentItem
                target: root
                text: root.tooltip
            }
        }
    }
}
