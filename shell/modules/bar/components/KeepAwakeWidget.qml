pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.modules.bar.popouts as BarPopouts

StyledRect {
    id: root

    required property var popouts

    property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    implicitWidth: isHorizontal ? Tokens.sizes.bar.innerWidth : Tokens.sizes.bar.innerWidth
    implicitHeight: isHorizontal ? Tokens.sizes.bar.innerWidth : Tokens.sizes.bar.innerWidth

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, 0)
    radius: Tokens.rounding.full

    visible: enabled && (!Config.bar.keepawake.autoHide || IdleInhibitor.enabled)

    MouseArea {
        id: clickArea

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: {
            if (mouse.button === Qt.LeftButton) {
                IdleInhibitor.setEnabled(!IdleInhibitor.enabled);
            } else if (mouse.button === Qt.RightButton) {
                root.popouts.currentName = "keepawakemenu";
                root.popouts.currentCenter = root.isHorizontal ? root.mapToItem(null, root.implicitWidth / 2, 0).x : (root.mapToItem(null, 0, root.implicitHeight / 2).y ?? 0);
                root.popouts.hasCurrent = true;
            }
            mouse.accepted = true;
        }
    }

    Item {
        id: content

        anchors.centerIn: parent

        width: root.isHorizontal ? Tokens.sizes.bar.innerWidth : Tokens.sizes.bar.innerWidth
        height: root.isHorizontal ? Tokens.sizes.bar.innerWidth : Tokens.sizes.bar.innerWidth

        MaterialIcon {
            id: icon

            anchors.centerIn: parent
            text: "coffee"
            // No chip behind it: the glyph itself carries the state, filled while awake.
            color: IdleInhibitor.enabled ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            fill: IdleInhibitor.enabled ? 1 : 0
            fontStyle: Tokens.font.icon.builders.medium.build()
        }

        Loader {
            id: activeChip

            sourceComponent: StyledRect {
                implicitWidth: text.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: text.implicitHeight + Tokens.padding.small

                radius: Tokens.rounding.full
                color: Colours.palette.m3primary

                StyledText {
                    id: text

                    anchors.centerIn: parent
                    text: {
                        if (!IdleInhibitor.enabled)
                            return qsTr("Inactive");
                        if (IdleInhibitor.expiresAt)
                            return qsTr("Until %1").arg(Time.clockTime(IdleInhibitor.expiresAt));
                        return qsTr("Active since %1").arg(Time.clockTime(IdleInhibitor.enabledSince));
                    }
                    color: Colours.palette.m3onPrimary
                    font: Tokens.font.body.builders.small.size(Math.round(Tokens.font.body.small.pointSize * 0.9)).build()
                }
            }

            active: IdleInhibitor.enabled && Config.bar.keepawake.showActiveChip
            anchors.top: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: IdleInhibitor.enabled ? Tokens.spacing.small : 0
            opacity: IdleInhibitor.enabled ? 1 : 0
            scale: IdleInhibitor.enabled ? 1 : 0.5

            Behavior on opacity {
                Anim { type: Anim.StandardSmall }
            }

            Behavior on scale {
                Anim { type: Anim.StandardSmall }
            }
        }
    }
}
