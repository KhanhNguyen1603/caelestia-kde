pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<MenuItem> positionItems: [
        MenuItem {
            property string value: "bottom"

            text: qsTr("Bottom")
        },
        MenuItem {
            property string value: "top"

            text: qsTr("Top")
        },
        MenuItem {
            property string value: "left"

            text: qsTr("Left")
        },
        MenuItem {
            property string value: "right"

            text: qsTr("Right")
        }
    ]

    readonly property list<MenuItem> alignmentItems: [
        MenuItem {
            property string value: "center"

            text: qsTr("Center")
        },
        MenuItem {
            property string value: "start"

            text: qsTr("Start")
        },
        MenuItem {
            property string value: "end"

            text: qsTr("End")
        }
    ]

    readonly property list<MenuItem> indicatorStyleItems: [
        MenuItem {
            property string value: "pill"

            text: qsTr("Pill / Dash")
        },
        MenuItem {
            property string value: "dot"

            text: qsTr("Dot")
        },
        MenuItem {
            property string value: "bar"

            text: qsTr("Line / Bar")
        }
    ]

    readonly property list<MenuItem> windowGroupingItems: [
        MenuItem {
            property int value: DockWindowGrouping.Combined

            text: qsTr("Group all windows")
        },
        MenuItem {
            property int value: DockWindowGrouping.PinnedFirst

            text: qsTr("Pinned icon holds first window")
        },
        MenuItem {
            property int value: DockWindowGrouping.Ungrouped

            text: qsTr("No grouping")
        }
    ]

    title: qsTr("Dock")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Enable floating dock")
            subtext: qsTr("Show a standalone floating dock on your screen")
            reset: ({ node: GlobalConfig.dockPanel, setting: "enabled" })
            checked: Config.dockPanel.enabled
            onToggled: GlobalConfig.dockPanel.enabled = checked
        }

        SectionHeader {
            text: qsTr("Position & Alignment")
        }

        SelectRow {
            first: true
            label: qsTr("Screen edge")
            subtext: qsTr("Position of the floating dock on the screen")
            menuItems: root.positionItems
            active: {
                for (let i = 0; i < root.positionItems.length; i++) {
                    if (root.positionItems[i].value === Config.dockPanel.position)
                        return root.positionItems[i];
                }
                return root.positionItems[0];
            }
            fallbackIcon: "dock_to_bottom"
            onSelected: item => GlobalConfig.dockPanel.position = item.value
        }

        SelectRow {
            last: true
            label: qsTr("Alignment")
            subtext: qsTr("Placement along the chosen screen edge")
            menuItems: root.alignmentItems
            active: {
                for (let i = 0; i < root.alignmentItems.length; i++) {
                    if (root.alignmentItems[i].value === Config.dockPanel.alignment)
                        return root.alignmentItems[i];
                }
                return root.alignmentItems[0];
            }
            fallbackIcon: "align_horizontal_center"
            onSelected: item => GlobalConfig.dockPanel.alignment = item.value
        }

        SectionHeader {
            text: qsTr("Behavior & Visibility")
        }

        ToggleRow {
            first: true
            text: qsTr("Always visible")
            subtext: qsTr("Keep the dock visible on screen at all times instead of auto-hiding")
            reset: ({ node: GlobalConfig.dockPanel, setting: "persistent" })
            checked: Config.dockPanel.persistent
            onToggled: GlobalConfig.dockPanel.persistent = checked
        }

        ToggleRow {
            text: qsTr("Intelligent auto-hide (Intellihide)")
            subtext: qsTr("Only hide the dock when an open window overlaps its area")
            reset: ({ node: GlobalConfig.dockPanel, setting: "dodgeWindows" })
            checked: Config.dockPanel.dodgeWindows
            enabled: !Config.dockPanel.persistent
            opacity: enabled ? 1.0 : 0.5
            onToggled: GlobalConfig.dockPanel.dodgeWindows = checked
        }

        ToggleRow {
            text: qsTr("Dodge focused window only")
            subtext: qsTr("Only hide when the active, focused window intersects with the dock")
            reset: ({ node: GlobalConfig.dockPanel, setting: "dodgeFocusedOnly" })
            checked: Config.dockPanel.dodgeFocusedOnly
            enabled: !Config.dockPanel.persistent && Config.dockPanel.dodgeWindows
            opacity: enabled ? 1.0 : 0.5
            onToggled: GlobalConfig.dockPanel.dodgeFocusedOnly = checked
        }

        ToggleRow {
            text: qsTr("Reveal on mouse hover")
            subtext: qsTr("Show the auto-hidden dock when hovering over the screen edge")
            reset: ({ node: GlobalConfig.dockPanel, setting: "showOnHover" })
            checked: Config.dockPanel.showOnHover
            enabled: !Config.dockPanel.persistent
            opacity: enabled ? 1.0 : 0.5
            onToggled: GlobalConfig.dockPanel.showOnHover = checked
        }

        StepperRow {
            label: qsTr("Hover reveal delay")
            subtext: qsTr("Milliseconds to wait before revealing the hidden dock on mouse hover")
            reset: ({ node: GlobalConfig.dockPanel, setting: "autoHideDelay" })
            value: Config.dockPanel.autoHideDelay
            from: 0
            to: 1000
            stepSize: 50
            enabled: !Config.dockPanel.persistent && Config.dockPanel.showOnHover
            opacity: enabled ? 1.0 : 0.5
            onMoved: v => GlobalConfig.dockPanel.autoHideDelay = v
        }

        StepperRow {
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged across the edge before the dock reveals or hides")
            reset: ({ node: GlobalConfig.dockPanel, setting: "dragThreshold" })
            value: Config.dockPanel.dragThreshold
            from: 0
            to: 100
            stepSize: 5
            onMoved: v => GlobalConfig.dockPanel.dragThreshold = v
        }

        ToggleRow {
            last: true
            text: qsTr("Reserve screen space")
            subtext: qsTr("Prevent maximized windows from covering the dock area (exclusive zone)")
            reset: ({ node: GlobalConfig.dockPanel, setting: "reserveSpace" })
            checked: Config.dockPanel.reserveSpace
            onToggled: GlobalConfig.dockPanel.reserveSpace = checked
        }

        SectionHeader {
            text: qsTr("Window Management")
        }

        SelectRow {
            first: true
            label: qsTr("Window grouping")
            subtext: qsTr("How multiple windows of the same app share a dock icon")
            active: Config.dockPanel.windowGrouping === DockWindowGrouping.Ungrouped ? root.windowGroupingItems[2] : Config.dockPanel.windowGrouping === DockWindowGrouping.PinnedFirst ? root.windowGroupingItems[1] : root.windowGroupingItems[0]
            menuItems: root.windowGroupingItems
            fallbackIcon: "grid_view"
            onSelected: item => GlobalConfig.dockPanel.windowGrouping = item.value
        }

        ToggleRow {
            text: qsTr("Filter by current desktop")
            subtext: qsTr("Only show applications and windows belonging to the active virtual workspace")
            reset: ({ node: GlobalConfig.dockPanel, setting: "currentDesktopOnly" })
            checked: Config.dockPanel.currentDesktopOnly
            onToggled: GlobalConfig.dockPanel.currentDesktopOnly = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Preview window on desktop")
            subtext: qsTr("Highlight and show the window itself on the workspace while hovering over dock previews")
            reset: ({ node: GlobalConfig.dockPanel, setting: "previewOnDesktop" })
            checked: Config.dockPanel.previewOnDesktop
            onToggled: GlobalConfig.dockPanel.previewOnDesktop = checked
        }

        SectionHeader {
            text: qsTr("Dimensions & Sizing")
        }

        ToggleRow {
            first: true
            text: qsTr("Island mode")
            subtext: qsTr("Detach the dock from screen edges into a floating island pill")
            reset: ({ node: GlobalConfig.dockPanel, setting: "islands" })
            checked: Config.dockPanel.islands
            onToggled: GlobalConfig.dockPanel.islands = checked
        }

        ToggleRow {
            text: qsTr("Fixed length")
            subtext: qsTr("Set a fixed panel length instead of sizing automatically to content")
            reset: ({ node: GlobalConfig.dockPanel, setting: "fixedLength" })
            checked: Config.dockPanel.fixedLength
            onToggled: GlobalConfig.dockPanel.fixedLength = checked
        }

        StepperRow {
            label: qsTr("Length percentage")
            subtext: qsTr("Length of the dock as a percentage of the screen edge")
            reset: ({ node: GlobalConfig.dockPanel, setting: "length" })
            value: Config.dockPanel.length
            from: 5
            to: 100
            stepSize: 5
            enabled: Config.dockPanel.fixedLength
            opacity: enabled ? 1.0 : 0.5
            onMoved: v => GlobalConfig.dockPanel.length = v
        }

        StepperRow {
            label: qsTr("Dock size")
            subtext: qsTr("Height or width dimension of the dock container")
            reset: ({ node: GlobalConfig.dockPanel, setting: "size" })
            value: Config.dockPanel.size
            from: 32
            to: 96
            stepSize: 4
            onMoved: v => GlobalConfig.dockPanel.size = v
        }

        StepperRow {
            label: qsTr("Icon size")
            subtext: qsTr("Size of application icons in the dock")
            reset: ({ node: GlobalConfig.dockPanel, setting: "iconSize" })
            value: Config.dockPanel.iconSize
            from: 24
            to: 72
            stepSize: 4
            onMoved: v => GlobalConfig.dockPanel.iconSize = v
        }

        StepperRow {
            label: qsTr("Floating distance")
            subtext: qsTr("Margin separating the dock pill from the screen boundary")
            reset: ({ node: GlobalConfig.dockPanel, setting: "floatingMargin" })
            value: Config.dockPanel.floatingMargin
            from: 0
            to: 48
            stepSize: 2
            onMoved: v => GlobalConfig.dockPanel.floatingMargin = v
        }

        StepperRow {
            label: qsTr("Inner padding")
            subtext: qsTr("Padding around icons inside the dock container")
            reset: ({ node: GlobalConfig.dockPanel, setting: "padding" })
            value: Config.dockPanel.padding
            from: 4
            to: 32
            stepSize: 2
            onMoved: v => GlobalConfig.dockPanel.padding = v
        }

        StepperRow {
            last: true
            label: qsTr("Item spacing")
            subtext: qsTr("Distance between adjacent icons")
            reset: ({ node: GlobalConfig.dockPanel, setting: "spacing" })
            value: Config.dockPanel.spacing
            from: 2
            to: 24
            stepSize: 2
            onMoved: v => GlobalConfig.dockPanel.spacing = v
        }

        SectionHeader {
            text: qsTr("Appearance & Magnification")
        }

        ToggleRow {
            first: true
            text: qsTr("Icon magnification on hover")
            subtext: qsTr("Smoothly magnify icons and their neighbours under the mouse pointer")
            reset: ({ node: GlobalConfig.dockPanel, setting: "magnification" })
            checked: Config.dockPanel.magnification
            onToggled: GlobalConfig.dockPanel.magnification = checked
        }

        StepperRow {
            label: qsTr("Maximum magnification")
            subtext: qsTr("Peak scale multiplier for hovered dock icons")
            reset: ({ node: GlobalConfig.dockPanel, setting: "maxMagnification" })
            value: Config.dockPanel.maxMagnification
            from: 1.1
            to: 1.8
            stepSize: 0.05
            enabled: Config.dockPanel.magnification
            opacity: enabled ? 1.0 : 0.5
            onMoved: v => GlobalConfig.dockPanel.maxMagnification = v
        }

        SliderRow {
            label: qsTr("Background opacity")
            subtext: qsTr("Translucency of the frosted glass dock pill")
            valueLabel: Math.round(Config.dockPanel.backgroundOpacity * 100) + "%"
            value: Config.dockPanel.backgroundOpacity
            reset: ({ node: GlobalConfig.dockPanel, setting: "backgroundOpacity" })
            onMoved: v => GlobalConfig.dockPanel.backgroundOpacity = Math.round(v * 100) / 100
        }

        SelectRow {
            label: qsTr("Running indicator style")
            subtext: qsTr("Visual shape for active and running application indicators")
            menuItems: root.indicatorStyleItems
            active: {
                for (let i = 0; i < root.indicatorStyleItems.length; i++) {
                    if (root.indicatorStyleItems[i].value === Config.dockPanel.indicatorStyle)
                        return root.indicatorStyleItems[i];
                }
                return root.indicatorStyleItems[0];
            }
            fallbackIcon: "more_horiz"
            onSelected: item => GlobalConfig.dockPanel.indicatorStyle = item.value
        }

        ToggleRow {
            text: qsTr("Show running indicators")
            subtext: qsTr("Display pips or bars below running applications")
            reset: ({ node: GlobalConfig.dockPanel, setting: "activeIndicators" })
            checked: Config.dockPanel.activeIndicators
            onToggled: GlobalConfig.dockPanel.activeIndicators = checked
        }

        ToggleRow {
            text: qsTr("Show unread badges")
            subtext: qsTr("Display notification count, progress, and urgency badges on app icons")
            reset: ({ node: GlobalConfig.dockPanel, setting: "showBadges" })
            checked: Config.dockPanel.showBadges
            onToggled: GlobalConfig.dockPanel.showBadges = checked
        }

        ToggleRow {
            text: qsTr("Show app launcher icon")
            subtext: qsTr("Display an application launcher button directly on the dock")
            reset: ({ node: GlobalConfig.dockPanel, setting: "showLauncherIcon" })
            checked: Config.dockPanel.showLauncherIcon
            onToggled: GlobalConfig.dockPanel.showLauncherIcon = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Recolor icons")
            subtext: qsTr("Apply system theme palette colors to monochrome and app icons")
            reset: ({ node: GlobalConfig.dockPanel, setting: "recolourIcons" })
            checked: Config.dockPanel.recolourIcons
            onToggled: GlobalConfig.dockPanel.recolourIcons = checked
        }
    }
}
