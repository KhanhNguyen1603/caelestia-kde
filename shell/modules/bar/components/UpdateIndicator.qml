pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus

// The updates indicator: one icon of the bar's own kind, so it lifts and names itself
// the way the status icons do.
BarIcon {
    id: root

    readonly property var status: UpdateStatus.describe(null, false)
    readonly property int updatesPageIdx: PageRegistry.updatesPageIdx

    entryId: "updateIndicator"
    draggable: true
    tooltip: root.status.title

    glyphComponent: Component {
        MaterialIcon {
            text: root.status.icon
            color: root.status.highlight ? Colours.palette.m3primary : Colours.palette.m3secondary
        }
    }

    onActivated: WindowFactory.create(null, {
        initialPageIdx: root.updatesPageIdx
    })
    // The menu behind the icon: check for updates, open the page, hide the indicator.
    onContextMenuRequested: root.openPopout("updateIndicator")
}