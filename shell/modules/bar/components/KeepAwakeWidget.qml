pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services

// Keep awake: one icon of the bar's own kind, so it lifts like the status icons do
// instead of being a widget that only looks like one.
BarIcon {
    id: root

    readonly property bool awake: IdleInhibitor.enabled

    entryId: "keepawake"
    draggable: true

    visible: enabled && (!Config.bar.keepawake.autoHide || root.awake)
    // The remaining time is what the chip under the icon used to say, said where a bar
    // icon has room for it: the hover name. The menu behind the right button shows it
    // too, for the times the icon is not hovered.
    tooltip: root.awake ? `${qsTr("Keep awake")} (${IdleInhibitor.periodText})` : qsTr("Keep awake")

    glyphComponent: Component {
        MaterialIcon {
            // Filled while it is on: the tint difference alone is too slight to read
            // across a bar.
            text: "coffee"
            fill: root.awake ? 1 : 0
            fontScale: root.iconScale
            color: root.awake ? Colours.palette.m3primary : Colours.palette.m3secondary
        }
    }

    onActivated: IdleInhibitor.setEnabled(!IdleInhibitor.enabled)
    // The right button opens the menu dev added: it carries the expiry picker and the
    // settings card, so one gesture reaches everything about the inhibitor.
    onContextMenuRequested: root.openPopout("keepawakemenu")
}
