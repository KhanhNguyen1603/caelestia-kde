pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components.effects
import qs.services
import qs.utils

// A tray icon is a bar icon whose glyph an app draws: the same slot, the same hover
// name, the same drag. Only the buttons differ, because the app owns what they do.
BarIcon {
    id: root

    required property SystemTrayItem modelData

    readonly property string key: TrayRegistry.keyOfItem(root.modelData)
    readonly property string popoutName: TrayRegistry.popoutNameOf(root.modelData)
    readonly property bool hasMenuEntries: menuOpener.children.values.some(entry => !entry.isSeparator)

    entryId: TrayRegistry.rowOf(root.key)
    draggable: true
    dragKind: "icon"
    dragKey: root.key
    tooltip: root.modelData ? (root.modelData.title || root.modelData.id) : ""
    accessibleName: root.tooltip
    accessibleDescription: root.hasMenuEntries && root.popouts ? qsTr("Left-click activates, right-click opens the menu, middle-click runs the secondary action.") : qsTr("Left-click activates, middle- or right-click runs the secondary action.")

    onActivated: {
        if (root.modelData)
            root.modelData.activate();
    }

    onMiddleActivated: {
        if (root.modelData)
            root.modelData.secondaryActivate();
    }

    // The menu belongs to the app, so it is asked for by name; an app without one has
    // only its second action to offer.
    onContextMenuRequested: {
        if (root.hasMenuEntries && root.popouts)
            root.openPopout(root.popoutName);
        else if (root.modelData)
            root.modelData.secondaryActivate();
    }

    glyphComponent: Component {
        ColouredIcon {
            implicitSize: Tokens.font.icon.small.pointSize
            source: Icons.getTrayIcon(root.key, root.modelData?.icon ?? "")
            colour: Colours.palette.m3secondary
            layer.enabled: Config.bar.tray.recolour
        }
    }

    QsMenuOpener {
        id: menuOpener

        menu: root.modelData?.menu ?? null // qmllint disable unresolved-type
    }
}
