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
    tooltip: qsTr("Keep awake")

    visible: enabled && (!Config.bar.keepawake.autoHide || root.awake)

    glyphComponent: Component {
        MaterialIcon {
            // Filled while it is on: the tint difference alone is too slight to read
            // across a bar.
            text: "coffee"
            fill: root.awake ? 1 : 0
            color: root.awake ? Colours.palette.m3primary : Colours.palette.m3secondary
        }
    }

    onActivated: IdleInhibitor.setEnabled(!IdleInhibitor.enabled)
    onContextMenuRequested: root.openPopout("keepawakecontext")
}