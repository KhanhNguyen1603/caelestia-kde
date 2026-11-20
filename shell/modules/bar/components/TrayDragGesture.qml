pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// Lifting something off the bar: a tray icon, a bar widget or a status icon. The
// gesture is recognised over the item rather than by watching its press, so
// whatever sits under the pointer still gets its click.
DragHandler {
    id: root

    property string kind: "widget"
    property string key: ""
    property string widgetId: ""
    // What the drag carries. An icon hands over its glyph alone, so the ghost is the
    // icon itself and not the slot or plate the pointer happened to be over.
    property Item ghostSource: root.item

    readonly property Item item: parent
    // Which gesture owns the drag it started: an icon that carries its own gesture can
    // sit inside a wrapper that carries one too, and only one of them may end it.
    property bool ownsDrag: false

    // Emitted when a gesture that had lifted something ends, so the item can keep
    // the release from also landing as a click.
    signal dropped()

    // The drag is tracked on the screen so the bar and the popouts, which are separate
    // windows, agree on where the pointer is.
    function screenPoint(scene: point): point {
        return TrayDrag.toScreen(root.item ? root.item.Window.window : null, scene.x, scene.y);
    }

    target: null
    grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByAnything

    onActiveChanged: {
        if (!root.item)
            return;

        if (active) {
            if (TrayDrag.active)
                return;

            root.ownsDrag = true;
            TrayDrag.begin(root.kind, root.key, root.widgetId, root.item.Window.window);
            TrayDrag.move(root.screenPoint(centroid.scenePosition));
            const source = root.ghostSource ?? root.item;
            const grabbedAt = source.mapFromItem(root.item, centroid.pressPosition.x, centroid.pressPosition.y);
            source.grabToImage(result => TrayDrag.setGhost(result, source.width, source.height, grabbedAt));
        } else if (root.ownsDrag) {
            root.ownsDrag = false;
            TrayDrag.finish();
            root.dropped();
        }
    }

    onTranslationChanged: {
        if (active)
            TrayDrag.move(root.screenPoint(centroid.scenePosition));
    }
}
