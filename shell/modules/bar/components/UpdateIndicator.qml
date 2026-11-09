pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus

Item {
    id: root

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    readonly property int barThickness: Math.round(Tokens.sizes.bar.innerWidth * Math.max(0.6, !isNaN(Config.bar.scale) ? Config.bar.scale : 1.0))

    readonly property var status: UpdateStatus.describe(null, false)

    readonly property int updatesPageIdx: PageRegistry.updatesPageIdx

    // The update icon is a bar widget, so it drags with its own key; the hidden
    // icons panel turns that into a disabled entry and shows the widget there.
    readonly property string widgetId: "updateIndicator"
    property bool draggable: true
    property bool dragging: false
    property bool _dragArmed: false
    property point _dragOrigin: Qt.point(0, 0)
    property bool _suppressClick: false

    Drag.active: root.draggable && root.dragging
    Drag.source: root
    Drag.hotSpot: Qt.point(root.width / 2, root.height / 2)
    Drag.keys: ["barWidget"]

    Component.onDestruction: {
        if (root.dragging)
            TrayRegistry.draggingIcon = false;
    }

    implicitWidth: isHorizontal ? (icon.implicitWidth + Tokens.padding.small * 2) : barThickness
    implicitHeight: isHorizontal ? barThickness : (icon.implicitHeight + Tokens.padding.small * 2)

    MaterialIcon {
        id: icon

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: Centering.pixelAlign(parent.width, width)
        text: root.status.icon
        color: root.status.highlight ? Colours.palette.m3primary : Colours.palette.m3secondary
    }

    StateLayer {
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: root.implicitWidth
        implicitHeight: root.implicitHeight
        radius: Tokens.rounding.full
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        Accessible.name: qsTr("Caelestia updates: %1").arg(root.status.title)
        Accessible.role: Accessible.Button
        Accessible.description: qsTr("Left-click to open the Updates page. Right-click to check for updates")

        onPressed: mouse => {
            if (!root.draggable)
                return;
            root._dragOrigin = Qt.point(mouse.x, mouse.y);
            root._dragArmed = true;
        }

        onPositionChanged: mouse => {
            if (!root._dragArmed || root.dragging)
                return;
            if (Math.hypot(mouse.x - root._dragOrigin.x, mouse.y - root._dragOrigin.y) < 8)
                return;
            root.dragging = true;
            root._dragArmed = false;
            TrayRegistry.draggingIcon = true;
        }

        onReleased: {
            if (root.dragging) {
                root._suppressClick = true;
                Qt.callLater(() => root._suppressClick = false);
            }
            root.dragging = false;
            root._dragArmed = false;
            TrayRegistry.draggingIcon = false;
        }

        onCanceled: {
            root.dragging = false;
            root._dragArmed = false;
            TrayRegistry.draggingIcon = false;
        }

        onClicked: mouse => {
            if (root._suppressClick) {
                root._suppressClick = false;
                return;
            }
            if (mouse.button === Qt.RightButton) {
                UpdateChecker.checkNow();
            } else {
                WindowFactory.create(null, { initialPageIdx: root.updatesPageIdx });
            }
        }
    }
}
