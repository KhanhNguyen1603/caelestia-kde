pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Keep Awake")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Configuration")
        }

        SectionHeader {
            text: qsTr("Widget")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Auto-hide when inactive")
            subtext: qsTr("Hide the widget when Keep Awake is off")
            reset: ({ node: GlobalConfig.bar.keepawake, setting: "autoHide" })
            checked: Config.bar.keepawake.autoHide
            onToggled: {
                GlobalConfig.bar.keepawake.autoHide = checked;
                GlobalConfig.save();
            }
        }
    }
}
