import QtQuick
import QtQuick.Window
import qs.components
import qs.services

// The press surface of a tray icon and the gesture that lifts it off the bar. A
// press that turns into a drag moves the icon's state rather than clicking it, so
// the click that ends the gesture is dropped instead of reaching the icon.
StateLayer {
    id: root

    property bool draggable: false
    property string key: ""

    readonly property bool dragging: root._dragging

    property bool _dragging: false
    property bool _armed: false
    property bool _suppressClick: false
    property point _origin: Qt.point(0, 0)

    signal tapped(event: var)

    onPressed: mouse => {
        root.press(mouse.x, mouse.y);
        if (!root.draggable || mouse.button !== Qt.LeftButton)
            return;
        root._origin = Qt.point(mouse.x, mouse.y);
        root._armed = true;
    }

    onPositionChanged: mouse => {
        if (root._dragging) {
            TrayDrag.move(root.mapToItem(null, mouse.x, mouse.y));
            return;
        }
        if (!root._armed || Math.hypot(mouse.x - root._origin.x, mouse.y - root._origin.y) < 8)
            return;
        root._armed = false;
        root._dragging = true;
        TrayDrag.begin("icon", root.key, "", root.Window.window);
        TrayDrag.move(root.mapToItem(null, mouse.x, mouse.y));
    }

    onReleased: {
        if (root._dragging) {
            root._dragging = false;
            root._suppressClick = true;
            Qt.callLater(() => root._suppressClick = false);
            TrayDrag.finish();
        }
        root._armed = false;
    }

    onCanceled: {
        if (root._dragging) {
            root._dragging = false;
            TrayDrag.cancel();
        }
        root._armed = false;
    }

    onClicked: event => {
        if (root._suppressClick) {
            root._suppressClick = false;
            return;
        }
        root.tapped(event);
    }
}
