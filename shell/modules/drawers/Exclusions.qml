pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.modules.bar as Bar

Scope {
    id: root

    required property ShellScreen screen
    required property Bar.BarWrapper bar
    required property var dockPanel
    required property DrawerVisibilities visibilities

    // A pinned sidebar reserves its width so maximised windows sit beside it
    // rather than under it. It stays reserved while hidden for a fullscreen window
    // so the other windows are not resized back and forth.
    readonly property bool reserveSidebar: Visibilities.sidebarPinned && Config.sidebar.enabled
        && (visibilities.sidebar || visibilities.sidebarSuspended)

    // Follows the sidebar width, but only once a resize drag ends: reserving every
    // step of the drag would resize maximised windows on each frame. The default
    // comes from the bar, which has the screen's tokens.
    property real sidebarWidth

    readonly property int dockPanelThickness: root.dockPanel ? root.dockPanel.exclusiveZone : 0
    readonly property string dockPanelPosition: root.dockPanel ? root.dockPanel.position : Config.dockPanel.position
    readonly property int defaultBorderExclusion: root.bar.isIsland ? 0 : Config.border.thickness
    readonly property int dockPanelAdditionalExclusion: (root.dockPanel && !root.dockPanel.disabled && Config.dockPanel.reserveSpace
        && !root.dockPanel.dodgeEnabled && (Config.dockPanel.persistent || root.visibilities.dockPanel))
        ? (root.dockPanel.contentThickness + root.dockPanel.islandMargin) : 0

    readonly property int leftExclusion: (root.bar.position === "left"
        ? (root.bar.exclusiveZone + (dockPanelPosition === "left" ? dockPanelAdditionalExclusion : 0))
        : (dockPanelPosition === "left" ? (root.dockPanel && !root.dockPanel.disabled ? root.dockPanel.exclusiveZone : defaultBorderExclusion) : defaultBorderExclusion))
        + (root.reserveSidebar && root.bar.position === "right" ? root.sidebarWidth : 0)
    readonly property int topExclusion: root.bar.position === "top"
        ? (root.bar.exclusiveZone + (dockPanelPosition === "top" ? dockPanelAdditionalExclusion : 0))
        : (dockPanelPosition === "top" ? (root.dockPanel && !root.dockPanel.disabled ? root.dockPanel.exclusiveZone : defaultBorderExclusion) : defaultBorderExclusion)
    readonly property int rightExclusion: (root.bar.position === "right"
        ? (root.bar.exclusiveZone + (dockPanelPosition === "right" ? dockPanelAdditionalExclusion : 0))
        : (dockPanelPosition === "right" ? (root.dockPanel && !root.dockPanel.disabled ? root.dockPanel.exclusiveZone : defaultBorderExclusion) : defaultBorderExclusion))
        + (root.reserveSidebar && root.bar.position !== "right" ? root.sidebarWidth : 0)
    readonly property int bottomExclusion: root.bar.position === "bottom"
        ? (root.bar.exclusiveZone + (dockPanelPosition === "bottom" ? dockPanelAdditionalExclusion : 0))
        : (dockPanelPosition === "bottom" ? (root.dockPanel && !root.dockPanel.disabled ? root.dockPanel.exclusiveZone : defaultBorderExclusion) : defaultBorderExclusion)

    readonly property real usableWidth: Math.max(100, root.screen.width - leftExclusion - rightExclusion)
    readonly property real usableHeight: Math.max(100, root.screen.height - topExclusion - bottomExclusion)
    readonly property rect usableArea: Qt.rect(leftExclusion, topExclusion, usableWidth, usableHeight)

    onLeftExclusionChanged: Visibilities.notifyExclusionBoundsChanged(root.screen)
    onTopExclusionChanged: Visibilities.notifyExclusionBoundsChanged(root.screen)
    onRightExclusionChanged: Visibilities.notifyExclusionBoundsChanged(root.screen)
    onBottomExclusionChanged: Visibilities.notifyExclusionBoundsChanged(root.screen)
    onUsableWidthChanged: Visibilities.notifyExclusionBoundsChanged(root.screen)
    onUsableHeightChanged: Visibilities.notifyExclusionBoundsChanged(root.screen)

    Component.onCompleted: {
        Visibilities.registerExclusions(root.screen, root);
    }

    Binding on sidebarWidth {
        value: Visibilities.sidebarWidthFor(root.bar.Tokens.sizes.sidebar.width)
        when: !Visibilities.sidebarResizing
        restoreMode: Binding.RestoreNone
    }

    ExclusionZone {
        anchors.left: true
        exclusiveZone: root.leftExclusion
        Config.screen: root.screen.name
    }

    ExclusionZone {
        anchors.top: true
        exclusiveZone: root.topExclusion
        Config.screen: root.screen.name
    }

    ExclusionZone {
        anchors.right: true
        exclusiveZone: root.rightExclusion
        Config.screen: root.screen.name
    }

    ExclusionZone {
        anchors.bottom: true
        exclusiveZone: root.bottomExclusion
        Config.screen: root.screen.name
    }

    component ExclusionZone: StyledWindow {
        screen: root.screen
        name: "border-exclusion"
        exclusiveZone: Config.border.thickness
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
        Config.screen: root.screen.name
    }
}
