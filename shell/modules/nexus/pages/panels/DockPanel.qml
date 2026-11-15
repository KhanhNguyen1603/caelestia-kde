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
            reset: ({ node: GlobalConfig.dock, setting: "enabled" })
            checked: Config.dock.enabled
            onToggled: GlobalConfig.dock.enabled = checked
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
                    if (root.positionItems[i].value === Config.dock.position)
                        return root.positionItems[i];
                }
                return root.positionItems[0];
            }
            fallbackIcon: "dock_to_bottom"
            onSelected: item => GlobalConfig.dock.position = item.value
        }

        SelectRow {
            last: true
            label: qsTr("Alignment")
            subtext: qsTr("Placement along the chosen screen edge")
            menuItems: root.alignmentItems
            active: {
                for (let i = 0; i < root.alignmentItems.length; i++) {
                    if (root.alignmentItems[i].value === Config.dock.alignment)
                        return root.alignmentItems[i];
                }
                return root.alignmentItems[0];
            }
            fallbackIcon: "align_horizontal_center"
            onSelected: item => GlobalConfig.dock.alignment = item.value
        }

        SectionHeader {
            text: qsTr("Behavior & Visibility")
        }

        ToggleRow {
            first: true
            text: qsTr("Always visible")
            subtext: qsTr("Keep the dock visible on screen at all times instead of auto-hiding")
            reset: ({ node: GlobalConfig.dock, setting: "persistent" })
            checked: Config.dock.persistent
            onToggled: GlobalConfig.dock.persistent = checked
        }

        ToggleRow {
            text: qsTr("Intelligent auto-hide (Intellihide)")
            subtext: qsTr("Only hide the dock when an open window overlaps its area")
            reset: ({ node: GlobalConfig.dock, setting: "dodgeWindows" })
            checked: Config.dock.dodgeWindows
            enabled: !Config.dock.persistent
            opacity: enabled ? 1.0 : 0.5
            onToggled: GlobalConfig.dock.dodgeWindows = checked
        }

        ToggleRow {
            text: qsTr("Dodge focused window only")
            subtext: qsTr("Only hide when the active, focused window intersects with the dock")
            reset: ({ node: GlobalConfig.dock, setting: "dodgeFocusedOnly" })
            checked: Config.dock.dodgeFocusedOnly
            enabled: !Config.dock.persistent && Config.dock.dodgeWindows
            opacity: enabled ? 1.0 : 0.5
            onToggled: GlobalConfig.dock.dodgeFocusedOnly = checked
        }

        StepperRow {
            label: qsTr("Hover reveal delay")
            subtext: qsTr("Milliseconds to wait before revealing the hidden dock on mouse hover")
            reset: ({ node: GlobalConfig.dock, setting: "autoHideDelay" })
            value: Config.dock.autoHideDelay
            from: 0
            to: 1000
            stepSize: 50
            enabled: !Config.dock.persistent
            opacity: enabled ? 1.0 : 0.5
            onMoved: v => GlobalConfig.dock.autoHideDelay = v
        }

        ToggleRow {
            last: true
            text: qsTr("Reserve screen space")
            subtext: qsTr("Prevent maximized windows from covering the dock area (exclusive zone)")
            reset: ({ node: GlobalConfig.dock, setting: "reserveSpace" })
            checked: Config.dock.reserveSpace
            onToggled: GlobalConfig.dock.reserveSpace = checked
        }

        SectionHeader {
            text: qsTr("Dimensions & Sizing")
        }

        StepperRow {
            first: true
            label: qsTr("Icon size")
            subtext: qsTr("Size of application icons in the dock")
            reset: ({ node: GlobalConfig.dock, setting: "iconSize" })
            value: Config.dock.iconSize
            from: 24
            to: 72
            stepSize: 4
            onMoved: v => GlobalConfig.dock.iconSize = v
        }

        StepperRow {
            label: qsTr("Floating distance")
            subtext: qsTr("Margin separating the dock pill from the screen boundary")
            reset: ({ node: GlobalConfig.dock, setting: "floatingMargin" })
            value: Config.dock.floatingMargin
            from: 0
            to: 48
            stepSize: 2
            onMoved: v => GlobalConfig.dock.floatingMargin = v
        }

        StepperRow {
            label: qsTr("Inner padding")
            subtext: qsTr("Padding around icons inside the dock container")
            reset: ({ node: GlobalConfig.dock, setting: "padding" })
            value: Config.dock.padding
            from: 4
            to: 32
            stepSize: 2
            onMoved: v => GlobalConfig.dock.padding = v
        }

        StepperRow {
            last: true
            label: qsTr("Item spacing")
            subtext: qsTr("Distance between adjacent icons")
            reset: ({ node: GlobalConfig.dock, setting: "spacing" })
            value: Config.dock.spacing
            from: 2
            to: 24
            stepSize: 2
            onMoved: v => GlobalConfig.dock.spacing = v
        }

        SectionHeader {
            text: qsTr("Appearance & Magnification")
        }

        ToggleRow {
            first: true
            text: qsTr("Icon magnification on hover")
            subtext: qsTr("Smoothly magnify icons and their neighbours under the mouse pointer")
            reset: ({ node: GlobalConfig.dock, setting: "magnification" })
            checked: Config.dock.magnification
            onToggled: GlobalConfig.dock.magnification = checked
        }

        StepperRow {
            label: qsTr("Maximum magnification")
            subtext: qsTr("Peak scale multiplier for hovered dock icons")
            reset: ({ node: GlobalConfig.dock, setting: "maxMagnification" })
            value: Config.dock.maxMagnification
            from: 1.1
            to: 1.8
            stepSize: 0.05
            enabled: Config.dock.magnification
            opacity: enabled ? 1.0 : 0.5
            onMoved: v => GlobalConfig.dock.maxMagnification = v
        }

        SliderRow {
            label: qsTr("Background opacity")
            subtext: qsTr("Translucency of the frosted glass dock pill")
            valueLabel: Math.round(Config.dock.backgroundOpacity * 100) + "%"
            value: Config.dock.backgroundOpacity
            reset: ({ node: GlobalConfig.dock, setting: "backgroundOpacity" })
            onMoved: v => GlobalConfig.dock.backgroundOpacity = Math.round(v * 100) / 100
        }

        SelectRow {
            label: qsTr("Running indicator style")
            subtext: qsTr("Visual shape for active and running application indicators")
            menuItems: root.indicatorStyleItems
            active: {
                for (let i = 0; i < root.indicatorStyleItems.length; i++) {
                    if (root.indicatorStyleItems[i].value === Config.dock.indicatorStyle)
                        return root.indicatorStyleItems[i];
                }
                return root.indicatorStyleItems[0];
            }
            fallbackIcon: "more_horiz"
            onSelected: item => GlobalConfig.dock.indicatorStyle = item.value
        }

        ToggleRow {
            text: qsTr("Show running indicators")
            subtext: qsTr("Display pips or bars below running applications")
            reset: ({ node: GlobalConfig.dock, setting: "activeIndicators" })
            checked: Config.dock.activeIndicators
            onToggled: GlobalConfig.dock.activeIndicators = checked
        }

        ToggleRow {
            text: qsTr("Show unread badges")
            subtext: qsTr("Display notification count, progress, and urgency badges on app icons")
            reset: ({ node: GlobalConfig.dock, setting: "showBadges" })
            checked: Config.dock.showBadges
            onToggled: GlobalConfig.dock.showBadges = checked
        }

        ToggleRow {
            text: qsTr("Show app launcher icon")
            subtext: qsTr("Display an application launcher button directly on the dock")
            reset: ({ node: GlobalConfig.dock, setting: "showLauncherIcon" })
            checked: Config.dock.showLauncherIcon
            onToggled: GlobalConfig.dock.showLauncherIcon = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Recolor icons")
            subtext: qsTr("Apply system theme palette colors to monochrome and app icons")
            reset: ({ node: GlobalConfig.dock, setting: "recolourIcons" })
            checked: Config.dock.recolourIcons
            onToggled: GlobalConfig.dock.recolourIcons = checked
        }

        SectionHeader {
            text: qsTr("Window Management")
        }

        SelectRow {
            first: true
            label: qsTr("Window grouping")
            subtext: qsTr("How multiple windows of the same app share a dock icon")
            active: Config.dock.windowGrouping === DockWindowGrouping.Ungrouped ? root.windowGroupingItems[2] : Config.dock.windowGrouping === DockWindowGrouping.PinnedFirst ? root.windowGroupingItems[1] : root.windowGroupingItems[0]
            menuItems: root.windowGroupingItems
            fallbackIcon: "grid_view"
            onSelected: item => GlobalConfig.dock.windowGrouping = item.value
        }

        ToggleRow {
            text: qsTr("Filter by current desktop")
            subtext: qsTr("Only show applications and windows belonging to the active virtual workspace")
            reset: ({ node: GlobalConfig.dock, setting: "currentDesktopOnly" })
            checked: Config.dock.currentDesktopOnly
            onToggled: GlobalConfig.dock.currentDesktopOnly = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Preview window on desktop")
            subtext: qsTr("Highlight and show the window itself on the workspace while hovering over dock previews")
            reset: ({ node: GlobalConfig.dock, setting: "previewOnDesktop" })
            checked: Config.dock.previewOnDesktop
            onToggled: GlobalConfig.dock.previewOnDesktop = checked
        }
    }
}
