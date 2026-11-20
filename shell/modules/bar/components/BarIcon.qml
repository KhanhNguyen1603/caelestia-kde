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
    // What a drag of this icon carries: the bar's widgets are moved by id, the tray's
    // icons by their stable key, and the drop reads which of the two it is holding.
    property string dragKind: "widget"
    property string dragKey: ""
    property string tooltip: ""
    // What a screen reader hears for this icon. The name defaults to the tooltip, which
    // is what a sighted user reads on hover; the description says what the buttons do
    // when that is not obvious.
    property string accessibleName: ""
    property string accessibleDescription: ""
    // The release that ends a drag lands on the icon the drag started from, which Qt
    // reports as a click. It is not one: it is the end of the gesture.
    property bool suppressClick: false
    // An icon the tray's box draws is inside a popout, so the popout being open is not a
    // reason to keep its name back. The box shows that name itself: a tooltip is a window,
    // and one opened over a box this small takes the hover away from the icon under it.
    property bool insidePopout: false

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    // The bar thins itself with a curve rather than in step with the number, and the icons
    // have to follow it: a glyph drawn at its full size in a bar that was made shorter
    // than it is gets cut off at both ends, which is what reads as fuzzy.
    readonly property real rawScale: !isNaN(Config.bar.scale) ? Config.bar.scale : 1.0
    readonly property real barScale: root.rawScale < 1.0 ? Math.sqrt(Math.max(0.1, root.rawScale)) : root.rawScale
    readonly property int barThickness: Math.round(Tokens.sizes.bar.innerWidth * root.barScale)
    // A bar icon is read at a glance, so its glyph is drawn a little larger than the
    // slot it asks for, and the slot grows with it. The glyph grows itself rather than
    // being scaled: it is either text, which is rendered at the size its font asks for,
    // or a bitmap, which is asked for at the size it is drawn at. A glyph stretched by
    // a transform is a resampled copy of whatever size it was drawn at.
    readonly property real iconScale: 1.2 * root.barScale
    readonly property bool dragging: dragGesture.active
    readonly property bool hovered: area.containsMouse && (root.insidePopout || !(root.popouts?.blocksHoverNames ?? false))
    readonly property Item glyph: glyphLoader.item

    // A left click does what the widget does; a right click asks for its menu, and a
    // middle click does whatever the widget offers beside that (an app's second action).
    signal activated()
    signal middleActivated()
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

    implicitWidth: root.isHorizontal ? Math.round(glyphLoader.implicitWidth) : root.barThickness
    implicitHeight: root.isHorizontal ? root.barThickness : Math.round(glyphLoader.implicitHeight)
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

        kind: root.dragKind
        key: root.dragKey
        widgetId: root.entryId
        enabled: root.draggable
        ghostSource: glyphLoader

        onDropped: root.suppressClick = true
    }

    Loader {
        id: glyphLoader

        anchors.centerIn: parent
        sourceComponent: root.glyphComponent
    }

    MouseArea {
        id: area

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: root.accessibleName.length > 0 ? root.accessibleName : root.tooltip
        Accessible.description: root.accessibleDescription

        onPressed: root.suppressClick = false

        onClicked: mouse => {
            if (root.suppressClick) {
                root.suppressClick = false;
                return;
            }
            if (mouse.button === Qt.MiddleButton)
                root.middleActivated();
            else if (mouse.button === Qt.RightButton)
                root.contextMenuRequested();
            else
                root.activated();
        }
    }

    Loader {
        asynchronous: true
        active: root.tooltip.length > 0 && !root.insidePopout
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
