pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus

Item {
    id: root

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    readonly property int barThickness: Math.round(Tokens.sizes.bar.innerWidth * Math.max(0.6, !isNaN(Config.bar.scale) ? Config.bar.scale : 1.0))

    readonly property var status: UpdateStatus.describe(null, false)

    readonly property int updatesPageIdx: PageRegistry.updatesPageIdx
    property var popouts

    // Hovering says what the icon is; the menu is the right button's job.
    readonly property string tooltip: root.status.title
    readonly property bool hovered: layer.containsMouse && !(root.popouts?.hasCurrent ?? false)

    implicitWidth: isHorizontal ? (icon.implicitWidth + Tokens.padding.small * 2) : barThickness
    implicitHeight: isHorizontal ? barThickness : (icon.implicitHeight + Tokens.padding.small * 2)

    MaterialIcon {
        id: icon

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: Centering.pixelAlign(parent.width, width)
        text: root.status.icon
        color: root.status.highlight ? Colours.palette.m3primary : Colours.palette.m3secondary
        fontStyle: Tokens.font.icon.medium
    }

    StateLayer {
        id: layer

        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: root.implicitWidth
        implicitHeight: root.implicitHeight
        radius: Tokens.rounding.full
        // No plate under the pointer: hover is for reading the icon's name.
        showHoverBackground: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        Accessible.name: qsTr("Caelestia updates: %1").arg(root.status.title)
        Accessible.role: Accessible.Button
        Accessible.description: qsTr("Left-click to open the Updates page. Right-click for the updates menu")

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                // The menu behind the icon: check for updates, open the page, hide the
                // indicator. Hovering never opens it.
                if (root.popouts) {
                    root.popouts.currentName = "updateIndicator";
                    root.popouts.currentCenter = root.isHorizontal ? root.mapToItem(null, root.implicitWidth / 2, 0).x : root.mapToItem(null, 0, root.implicitHeight / 2).y;
                    root.popouts.hasCurrent = true;
                }
                return;
            }
            WindowFactory.create(null, { initialPageIdx: root.updatesPageIdx });
        }
    }

    Loader {
        asynchronous: true
        active: root.tooltip.length > 0
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
