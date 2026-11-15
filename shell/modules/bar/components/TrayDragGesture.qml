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

    // Emitted when a gesture that had lifted something ends, so the item can keep
    // the release from also landing as a click.
    signal dropped()

    target: null
    grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByAnything

    onActiveChanged: {
        if (!root.item)
            return;

        if (active) {
            TrayDrag.begin(root.kind, root.key, root.widgetId, root.item.Window.window);
            TrayDrag.move(centroid.scenePosition);
            const source = root.ghostSource ?? root.item;
            const grabbedAt = source.mapFromItem(root.item, centroid.pressPosition.x, centroid.pressPosition.y);
            source.grabToImage(result => TrayDrag.setGhost(result, source.width, source.height, grabbedAt));
        } else if (TrayDrag.active) {
            TrayDrag.finish();
            root.dropped();
        }
    }

    onTranslationChanged: {
        if (active)
            TrayDrag.move(centroid.scenePosition);
    }
}
