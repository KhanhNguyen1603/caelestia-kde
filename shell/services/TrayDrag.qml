pragma Singleton

import QtQuick
import Quickshell

// Moving a tray icon or a bar widget between the bar and the hidden-icons box.
// Qt's own drag and drop is no use here: the gesture starts on the bar, which is
// a layer surface whose input region covers only its panels, so the pointer leaves
// the surface the drop would be delivered on. Tracking the pointer and resolving
// the release against the surfaces that accept it keeps the whole gesture inside
// one window.
Singleton {
    id: root

    property bool active: false
    property string kind: ""
    property string key: ""
    property string widgetId: ""
    // On the screen, not in any one window: the bar, the box and the popouts are
    // separate surfaces, so a point in one is not a point in the others.
    property point pos: Qt.point(0, 0)
    property var window: null

    // A snapshot of the item the drag lifted, kept alive here because the grab
    // result owns the image its url points at. The gesture draws this under the
    // pointer so what is being carried is never a guess.
    property var ghost: null
    property real ghostWidth: 0
    property real ghostHeight: 0
    // Where in the snapshot the pointer was, so an item longer than one slot can be
    // carried by the part of it that was grabbed.
    property point ghostOffset: Qt.point(0, 0)

    // The surfaces that take a drop, in the order they were created. Anything that
    // wants one registers itself and answers the two calls below.
    readonly property var targets: []

    function begin(kind: string, key: string, widgetId: string, window: var): void {
        root.kind = kind;
        root.key = key;
        root.widgetId = widgetId;
        root.window = window;
        root.ghost = null;
        root.active = true;
    }

    function setGhost(result: var, width: real, height: real, offset: point): void {
        if (!result)
            return;
        root.ghostWidth = width;
        root.ghostHeight = height;
        root.ghostOffset = offset;
        root.ghost = result;
    }

    function move(position: point): void {
        if (root.active)
            root.pos = position;
    }

    // A drop is tracked on the screen: the bar, the box and the popouts are separate
    // surfaces with their own origins, so a point in one is not a point in the others.
    function toScreen(window: var, x: real, y: real): point {
        if (!window)
            return Qt.point(x, y);
        return Qt.point(window.x + x, window.y + y);
    }

    function toLocal(window: var, x: real, y: real): point {
        if (!window)
            return Qt.point(x, y);
        return Qt.point(x - window.x, y - window.y);
    }

    function finish(): void {
        if (!root.active)
            return;
        const source = {
            kind: root.kind,
            key: root.key,
            widgetId: root.widgetId
        };
        for (let i = root.targets.length - 1; i >= 0; i--) {
            const target = root.targets[i];
            if (target && target.trayDropAt(root.window, root.pos.x, root.pos.y)) {
                target.trayDrop(source, root.pos.x, root.pos.y);
                break;
            }
        }
        root.cancel();
    }

    function cancel(): void {
        root.active = false;
        root.kind = "";
        root.key = "";
        root.widgetId = "";
        root.window = null;
    }

    function register(target: var): void {
        if (!root.targets.includes(target))
            root.targets.push(target);
    }

    function unregister(target: var): void {
        const index = root.targets.indexOf(target);
        if (index >= 0)
            root.targets.splice(index, 1);
    }
}
