pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property string title
    // The one fact worth having while the section is shut: an address, a profile count. It
    // sits beside the title so a collapsed section still answers the question it was opened
    // for, and the section does not have to be expanded to read it.
    property string summary: ""
    property bool expanded: false
    property real scaleOffset: 1.0
    property real fontScale: 1.0
    property real minHeaderHeight: 36
    property real headerRightMargin: Tokens.padding.extraSmall * scaleOffset
    default property alias content: contentColumn.data

    Layout.fillWidth: true
    spacing: Tokens.spacing.extraSmall * root.scaleOffset

    Item {
        id: sectionHeader

        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(titleRow.implicitHeight + Tokens.padding.small * 2 * root.scaleOffset, root.minHeaderHeight * root.scaleOffset)

        RowLayout {
            id: titleRow

            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.small * root.scaleOffset
            anchors.rightMargin: root.headerRightMargin
            spacing: Tokens.spacing.small * root.scaleOffset

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.weight: Font.Medium
                font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
            }

            StyledText {
                visible: root.summary !== ""
                Layout.maximumWidth: titleRow.width * 0.55
                text: root.summary
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
            }

            MaterialIcon {
                text: "expand_more"
                rotation: root.expanded ? 180 : 0
                color: Colours.palette.m3onSurfaceVariant
                fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale

                Behavior on rotation {
                    Anim {
                        type: Anim.StandardSmall
                    }
                }
            }
        }

        StateLayer {
            anchors.fill: parent
            radius: Tokens.rounding.medium * root.scaleOffset
            showHoverBackground: false
            onClicked: root.expanded = !root.expanded
        }
    }

    Item {
        id: contentWrapper

        Layout.fillWidth: true
        Layout.preferredHeight: root.expanded ? (contentColumn.implicitHeight + Tokens.spacing.extraSmall * root.scaleOffset) : 0
        implicitHeight: Layout.preferredHeight
        clip: true

        Behavior on Layout.preferredHeight {
            Anim {}
        }

        ColumnLayout {
            id: contentColumn

            width: parent.width
            y: Tokens.spacing.extraSmall * root.scaleOffset
            spacing: Tokens.spacing.extraSmall * root.scaleOffset
            opacity: root.expanded ? 1.0 : 0.0

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }
}
