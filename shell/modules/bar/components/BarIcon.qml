pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// One icon on the bar: the glyph that says what it is, its name on hover, its menu on
// the right button, and the drag that moves it. Everything the tray draws is one of
// these, so a status icon, an update and the coffee cup are the same kind of thing
// rather than a few kinds that only look alike.
Item {
    id: root

    // What a drag carries and what the icon's menu is opened for.
    required property string entryId
    // The glyph; it decides how much room the icon takes.
    required property Component glyphComponent
    property var popouts
    property bool draggable: false
    property string tooltip: ""

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property int barThickness: Math.round(Tokens.sizes.bar.innerWidth * Math.max(0.6, !isNaN(Config.bar.scale) ? Config.bar.scale : 1.0))
    // A bar icon is read at a glance, so its glyph is drawn a little larger than the
    // slot it asks for, and the slot grows with it.
    readonly property real iconScale: 1.2
    readonly property bool dragging: dragGesture.active
    readonly property bool hovered: area.containsMouse && !(root.popouts?.hasCurrent ?? false)
    readonly property Item glyph: glyphLoader.item

    // A left click does what the widget does; a right click asks for its menu.
    signal activated()
    signal contextMenuRequested()

    // The menu a widget opens sits above the icon it belongs to.
    function openPopout(name: string): void {
        const popouts = root.popouts;
        if (!popouts)
            return;

        if (popouts.hasCurrent && popouts.currentName === name) {
            popouts.hasCurrent = false;
            return;
        }

        popouts.currentName = name;
        popouts.currentCenter = root.isHorizontal ? root.mapToItem(null, root.width / 2, 0).x : root.mapToItem(null, 0, root.height / 2).y;
        popouts.hasCurrent = true;
    }

    implicitWidth: root.isHorizontal ? Math.round(glyphLoader.implicitWidth * root.iconScale) : root.barThickness
    implicitHeight: root.isHorizontal ? root.barThickness : Math.round(glyphLoader.implicitHeight * root.iconScale)
    // Fading only once the ghost exists keeps the snapshot clean and means the icon
    // never disappears before there is something under the pointer to replace it.
    opacity: root.dragging && TrayDrag.ghost !== null ? 0.35 : 1

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    TrayDragGesture {
        id: dragGesture

        widgetId: root.entryId
        enabled: root.draggable
        ghostSource: glyphLoader
    }

    Loader {
        id: glyphLoader

        anchors.centerIn: parent
        scale: root.iconScale
        sourceComponent: root.glyphComponent
    }

    MouseArea {
        id: area

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.contextMenuRequested();
            else
                root.activated();
        }
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
