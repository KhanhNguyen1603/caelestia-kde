import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledSwitch {
    id: root

    property string subtext
    property var reset
    property bool beta: false
    property alias first: bg.first
    property alias last: bg.last
    property alias isSelected: bg.isSelected
    readonly property alias bg: bg

    Layout.fillWidth: true

    horizontalPadding: Tokens.padding.largeIncreased
    verticalPadding: Tokens.padding.medium
    font: Tokens.font.body.small

    implicitWidth: implicitContentWidth + implicitIndicatorWidth + horizontalPadding * 2
    implicitHeight: Math.max(implicitContentHeight, implicitIndicatorHeight) + verticalPadding * 2
    cLayer: 2

    indicator.anchors.verticalCenter: verticalCenter
    indicator.anchors.right: right
    indicator.anchors.rightMargin: resetBtn.visible ? resetBtn.width + resetBtn.anchors.rightMargin + Tokens.spacing.small : root.horizontalPadding

    onPressed: stateLayer.press(stateLayer.mouseX, stateLayer.mouseY)

    background: ConnectedRect {
        id: bg

        StateLayer {
            id: stateLayer

            disabled: !root.enabled
            manualPressOverride: root.pressed
            manualHoverOverride: bg.isSelected
        }
    }

    contentItem: Item {
        anchors.left: parent.left
        anchors.right: root.indicator.left
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: Tokens.spacing.medium

        implicitWidth: column.implicitWidth
        implicitHeight: column.implicitHeight

        Column {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            RowLayout {
                id: labelRow

                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Tokens.spacing.small

                StyledText {
                    id: label

                    Layout.fillWidth: true

                    text: root.text
                    font: root.font
                    color: root.enabled ? Colours.palette.m3onSurface : Colours.disabledContent
                    elide: Text.ElideRight
                }

                StyledRect {
                    visible: root.beta
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: betaLabel.implicitWidth + Tokens.padding.small * 2
                    implicitHeight: betaLabel.implicitHeight + Tokens.padding.extraSmall
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3secondaryContainer

                    StyledText {
                        id: betaLabel

                        anchors.centerIn: parent
                        text: qsTr("Beta")
                        color: Colours.palette.m3onSecondaryContainer
                        font: Tokens.font.label.small
                    }
                }
            }

            StyledText {
                anchors.left: parent.left
                anchors.right: parent.right

                visible: root.subtext
                text: root.subtext
                color: root.enabled ? Colours.palette.m3onSurfaceVariant : Colours.disabledContent
                font: NexusStyle.secondaryFont
                wrapMode: Text.Wrap
            }
        }
    }

    SettingResetButton {
        id: resetBtn

        // Same right inset as SliderRow/StepperRow so reset icons line up
        // in one column across every row type.
        anchors.right: parent.right
        anchors.rightMargin: Tokens.padding.medium
        anchors.verticalCenter: parent.verticalCenter
        options: root.reset
    }
}
