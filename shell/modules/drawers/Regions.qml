pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.modules.bar as Bar

Region {
    id: root

    required property Bar.BarWrapper bar
    required property var dockPanel
    required property Panels panels
    required property var win
    readonly property real borderThickness: root.bar.isIsland ? 0 : Config.border.thickness
    readonly property real clampedThickness: root.bar.isIsland ? 0 : Config.border.clampedThickness
    readonly property real dockPanelThickness: dockPanel && !dockPanel.disabled ? (!Config.dockPanel.persistent ? Math.max(dockPanel.clampedThickness, edgeExtent(Config.dockPanel.dragThreshold)) : dockPanel.clampedThickness) : 0
    readonly property int dockMagExtra: 0
    readonly property string dockPanelPosition: dockPanel ? dockPanel.position : Config.dockPanel.position
    readonly property real barLeftWidth: bar.position === "left" ? (bar.clampedThickness + bar.islandMargin) : clampedThickness
    readonly property real barRightWidth: bar.position === "right" ? (bar.clampedThickness + bar.islandMargin) : clampedThickness
    readonly property real barTopHeight: bar.position === "top" ? (bar.clampedThickness + bar.islandMargin) : clampedThickness
    readonly property real barBottomHeight: bar.position === "bottom" ? (bar.clampedThickness + bar.islandMargin) : clampedThickness
    // A closed panel's input region must be at least as deep as its hover trigger,
    // otherwise the pointer never reaches the area Interactions tests against.

    function edgeExtent(hoverThickness: real): real {
        return Math.max(borderThickness, hoverThickness);
    }

    x: barLeftWidth + win.dragMaskPadding
    y: barTopHeight + win.dragMaskPadding
    width: win.width - barLeftWidth - barRightWidth - win.dragMaskPadding * 2
    height: win.height - barTopHeight - barBottomHeight - win.dragMaskPadding * 2
    intersection: Intersection.Xor

    R {
        panel: root.panels.dashboard
        y: 0
        height: root.Config.dashboard.enabled ? panel.height * (1 - root.panels.dashboard.offsetScale) + root.edgeExtent(root.Config.dashboard.hoverThickness) : 0
    }
    R {
        panel: root.panels.launcher
        y: root.win.height - height
        height: root.Config.launcher.enabled ? panel.height * (1 - root.panels.launcher.offsetScale) + root.edgeExtent(root.Config.launcher.hoverThickness) + (panel.height * (1 - root.panels.launcher.offsetScale) > 0 ? root.panels.bottomMargin : 0) : 0
    }
    R {
        panel: root.panels.launcherAvatar
        width: root.panels.launcher.avatarVisible ? panel.width : 0
        height: root.panels.launcher.avatarVisible ? panel.height : 0
    }
    R {
        id: sessionRegion

        panel: root.panels.sessionWrapper
        x: root.bar.position === "right" ? 0 : root.win.width - sessionRegion.width
        width: root.Config.session.enabled ? panel.width * (1 - root.panels.session.offsetScale) + root.borderThickness + sidebarRegion.width : sidebarRegion.width
    }
    R {
        id: sidebarRegion

        panel: root.panels.sidebar
        x: root.bar.position === "right" ? 0 : root.win.width - sidebarRegion.width
        width: root.Config.sidebar.enabled ? panel.width * (1 - root.panels.sidebar.offsetScale) + root.borderThickness : 0
    }
    R {
        id: osdRegion

        panel: root.panels.osdWrapper
        x: root.bar.position === "right" ? 0 : root.win.width - osdRegion.width
        width: (root.Config.osd.enabled ? panel.width * (1 - root.panels.osd.offsetScale) + (root.Config.osd.showOnHover ? root.edgeExtent(root.Config.osd.hoverThickness) : 0) : 0) + sessionRegion.width
    }
    R {
        panel: root.panels.notifications
    }
    R {
        panel: root.panels.utilities
        y: root.bar.position === "bottom" ? 0 : root.win.height - height
        height: root.Config.utilities.enabled ? panel.height * (1 - root.panels.utilities.offsetScale) + root.edgeExtent(root.Config.utilities.hoverThickness) : 0
    }
    R {
        panel: root.panels.popoutsWrapper
        width: panel.width * (1 - root.panels.popoutsWrapper.offsetScale)
    }
    Region {
        x: {
            if (!root.dockPanel || root.dockPanel.disabled) return 0;
            if (root.dockPanel.visible) return root.dockPanel.x;
            if (root.dockPanel.isHorizontal) return root.dockPanel.x;
            const barOffset = (root.bar.position === "left") ? (root.bar.clampedThickness + root.bar.islandMargin) : 0;
            return root.dockPanel.position === "left" ? barOffset : root.win.width - width - (root.bar.position === "right" ? (root.bar.clampedThickness + root.bar.islandMargin) : 0);
        }
        y: {
            if (!root.dockPanel || root.dockPanel.disabled) return 0;
            if (root.dockPanel.visible) return root.dockPanel.y;
            if (!root.dockPanel.isHorizontal) return root.dockPanel.y;
            const barOffset = (root.bar.position === "top") ? (root.bar.clampedThickness + root.bar.islandMargin) : 0;
            return root.dockPanel.position === "top" ? barOffset : root.win.height - height - (root.bar.position === "bottom" ? (root.bar.clampedThickness + root.bar.islandMargin) : 0);
        }
        width: {
            if (!root.dockPanel || root.dockPanel.disabled) return 0;
            if (root.dockPanel.visible) return root.dockPanel.width;
            if (root.dockPanel.isHorizontal) return root.dockPanel.clampedLength;
            return root.Config.dockPanel.showOnHover ? root.edgeExtent(root.Config.dockPanel.dragThreshold) : 0;
        }
        height: {
            if (!root.dockPanel || root.dockPanel.disabled) return 0;
            if (root.dockPanel.visible) return root.dockPanel.height;
            if (!root.dockPanel.isHorizontal) return root.dockPanel.clampedLength;
            return root.Config.dockPanel.showOnHover ? root.edgeExtent(root.Config.dockPanel.dragThreshold) : 0;
        }
        intersection: Intersection.Subtract
    }
    Region {
        x: 0; y: 0
        width: (root.Config.overview.enabled && root.Config.overview.hoverTopLeft) ? root.Config.overview.hoverThickness : 0
        height: root.Config.overview.hoverThickness
        intersection: Intersection.Subtract
    }
    Region {
        x: root.win.width - root.Config.overview.hoverThickness; y: 0
        width: (root.Config.overview.enabled && root.Config.overview.hoverTopRight) ? root.Config.overview.hoverThickness : 0
        height: root.Config.overview.hoverThickness
        intersection: Intersection.Subtract
    }
    Region {
        x: 0; y: root.win.height - root.Config.overview.hoverThickness
        width: (root.Config.overview.enabled && root.Config.overview.hoverBottomLeft) ? root.Config.overview.hoverThickness : 0
        height: root.Config.overview.hoverThickness
        intersection: Intersection.Subtract
    }
    Region {
        x: root.win.width - root.Config.overview.hoverThickness; y: root.win.height - root.Config.overview.hoverThickness
        width: (root.Config.overview.enabled && root.Config.overview.hoverBottomRight) ? root.Config.overview.hoverThickness : 0
        height: root.Config.overview.hoverThickness
        intersection: Intersection.Subtract
    }

    component R: Region {
        required property Item panel

        x: panel.x + root.panels.leftMargin
        y: panel.y + root.panels.topMargin
        width: panel.width
        height: panel.height
        intersection: Intersection.Subtract
    }
    Config.screen: win.screen.name
}
