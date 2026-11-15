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
            const grabbedAt = centroid.pressPosition;
            root.item.grabToImage(result => TrayDrag.setGhost(result, root.item.width, root.item.height, grabbedAt));
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
