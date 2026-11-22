pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.modules.bar
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("App menu")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("General Settings")
        }

        ToggleRow {
            first: true
            text: qsTr("Enable component")
            subtext: qsTr("Display the focused application's menu in the bar")
            checked: BarPlacements.placementOf("appmenu") !== "off"
            reset: ({
                customGet: () => BarPlacements.placementOf("appmenu") !== "off",
                customDef: false,
                customSet: v => {
                    BarPlacements.setShown("appmenu", v);
                    GlobalConfig.save();
                }
            })
            onToggled: {
                BarPlacements.setShown("appmenu", checked);
                GlobalConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Show application icon")
            subtext: qsTr("Display the active app's icon in the bar component")
            reset: ({ node: GlobalConfig.bar.appmenu, setting: "showIcon" })
            checked: Config.bar.appmenu.showIcon
            onToggled: {
                GlobalConfig.bar.appmenu.showIcon = checked;
                GlobalConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Show application name")
            subtext: qsTr("Display the name of the currently focused application")
            reset: ({ node: GlobalConfig.bar.appmenu, setting: "showTitle" })
            checked: Config.bar.appmenu.showTitle
            onToggled: {
                GlobalConfig.bar.appmenu.showTitle = checked;
                GlobalConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Show dropdown indicator")
            subtext: qsTr("Show an arrow chevron indicating a menu dropdown")
            reset: ({ node: GlobalConfig.bar.appmenu, setting: "showChevron" })
            checked: Config.bar.appmenu.showChevron
            onToggled: {
                GlobalConfig.bar.appmenu.showChevron = checked;
                GlobalConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Compact mode")
            subtext: qsTr("Show only the app icon for a minimal footprint")
            reset: ({ node: GlobalConfig.bar.appmenu, setting: "compact" })
            checked: Config.bar.appmenu.compact
            onToggled: {
                GlobalConfig.bar.appmenu.compact = checked;
                GlobalConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Auto-hide")
            subtext: qsTr("Hide the widget when no application window is active")
            reset: ({ node: GlobalConfig.bar.appmenu, setting: "autoHide" })
            checked: Config.bar.appmenu.autoHide
            onToggled: {
                GlobalConfig.bar.appmenu.autoHide = checked;
                GlobalConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Enable popout")
            subtext: qsTr("Show the application menu panel on click")
            reset: ({ node: GlobalConfig.bar.popouts, setting: "appmenu" })
            checked: Config.bar.popouts.appmenu
            onToggled: {
                GlobalConfig.bar.popouts.appmenu = checked;
                GlobalConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("Display")
        }

        StepperRow {
            first: true
            last: true
            label: qsTr("Max title length")
            subtext: qsTr("Maximum characters to display for the application name")
            reset: ({ node: GlobalConfig.bar.appmenu, setting: "maxTitleLength" })
            value: Config.bar.appmenu.maxTitleLength
            from: 10
            to: 60
            stepSize: 1
            onMoved: v => {
                GlobalConfig.bar.appmenu.maxTitleLength = Math.round(v);
                GlobalConfig.save();
            }
        }
    }
}
