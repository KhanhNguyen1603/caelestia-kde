pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.launcher.services

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property var panels
    Config.screen: root.screen.name
    readonly property real maxWidth: screen.width
    readonly property bool shouldBeActive: visibilities.launcher && Config.launcher.enabled && !visibilities.overview
    readonly property real maxHeight: {
        let max = screen.height - Config.border.thickness * 2 + Tokens.padding.extraLarge;
        if (visibilities.dashboard)
            max -= panels.dashboard.nonAnimHeight;
        return max;
    }
    property real offsetScale: shouldBeActive ? 0 : 1
    property real avatarOpenScale: shouldBeActive ? 1 : 0
    property bool keepAlive: false
    property bool detached: false

    readonly property bool avatarVisible: root.visible && (content.item?.showAvatar ?? false)
    readonly property int avatarSize: content.item?.avatarSize ?? 0

    readonly property bool hasBarBottom: Config.bar.position === "bottom" && (panels?.bar?.visible ?? true)
    readonly property bool hasDockBottom: Config.dockPanel.position === "bottom" && Config.dockPanel.enabled && (panels?.dockPanel?.visible ?? false)
    readonly property bool hasEdgePanelBottom: hasBarBottom || hasDockBottom

    readonly property var activeEdgePanel: hasDockBottom ? panels?.dockPanel : (hasBarBottom ? panels?.bar : null)
    readonly property real edgePanelWidth: activeEdgePanel?.width ?? screen.width
    readonly property real edgePanelCenterX: activeEdgePanel ? (activeEdgePanel.x + activeEdgePanel.width / 2) : (screen.width / 2)
    readonly property real screenCenterX: screen.width / 2

    readonly property bool isLampActive: hasEdgePanelBottom && (edgePanelWidth < implicitWidth)
    readonly property real lampScaleX: (isLampActive && implicitWidth > 0) ? (width / implicitWidth) : 1

    signal closed()

    onOffsetScaleChanged: {
        if (offsetScale >= 1 && !shouldBeActive)
            closed();
    }
    onShouldBeActiveChanged: {
        if (shouldBeActive) {
            implicitHeight = Qt.binding(() => content.implicitHeight);
        } else
            implicitHeight = implicitHeight;
    }
    // Keep the clip while the panel slides away, but not while it is open: the
    // profile picture deliberately overhangs the top edge of the card.
    clip: hasEdgePanelBottom && !root.avatarVisible
    visible: offsetScale < 1
    // Detached, the card floats in the middle of the window: with a bottom
    // anchor that is a bottom margin of half the leftover space.
    anchors.bottomMargin: root.detached ? Math.max(0, (parent.height - implicitHeight) / 2) : (hasEdgePanelBottom ? 0 : -implicitHeight - 5) * offsetScale
    anchors.horizontalCenterOffset: isLampActive ? ((edgePanelCenterX - screenCenterX) * offsetScale) : 0
    width: isLampActive ? (implicitWidth - (implicitWidth - edgePanelWidth) * offsetScale) : implicitWidth
    height: hasEdgePanelBottom && !root.detached ? implicitHeight * (1 - offsetScale) : implicitHeight
    implicitHeight: content.implicitHeight
    implicitWidth: content.implicitWidth || 630
    opacity: 1 - offsetScale
    Component.onCompleted: Qt.callLater(() => Apps)

    Timer {
        running: Config.launcher.enabled && !root.keepAlive
        interval: 1500

        onTriggered: root.keepAlive = true
    }

    Behavior on offsetScale {
        enabled: !visibilities.skipLauncherAnim

        Anim {}
    }

    Behavior on avatarOpenScale {
        enabled: !visibilities.skipLauncherAnim

        Anim {
            type: root.shouldBeActive ? Anim.DefaultSpatial : Anim.FastSpatial
        }
    }
    Loader {
        id: content

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        active: root.shouldBeActive || root.visible || root.keepAlive
        transform: Scale {
            xScale: root.lampScaleX
            origin.x: (content.width || root.implicitWidth) / 2
        }
        sourceComponent: Component {
            Content {
                visibilities: root.visibilities
                panels: root.panels
                maxWidth: root.maxWidth
                maxHeight: root.maxHeight
            }
        }
    }
}
