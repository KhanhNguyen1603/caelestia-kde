pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

/// The keep-awake widget's right-click menu: how long to stay awake, whether the display
/// stays lit with it, and a way into the page that holds the rest of its settings.
ColumnLayout {
    id: root

    required property PopoutState popouts

    property real scaleOffset: 1.0
    property real fontScale: 1.0
    property bool _isSidebarOpen: false
    /// The interval presets start collapsed, so the menu is the four modes and nothing else.
    property bool intervalExpanded: false

    readonly property var intervals: [
        { label: qsTr("30 minutes"), seconds: 1800 },
        { label: qsTr("1 hour"), seconds: 3600 },
        { label: qsTr("2 hours"), seconds: 7200 }
    ]

    function close(): void {
        root.popouts.hasCurrent = false;
    }

    function pick(seconds: int): void {
        IdleInhibitor.keepAwakeFor(seconds);
        root.close();
    }

    width: card.implicitWidth
    implicitWidth: card.implicitWidth
    spacing: Tokens.spacing.medium * root.scaleOffset

    StyledRect {
        id: card

        Layout.fillWidth: true
        implicitWidth: Math.max(260 * root.scaleOffset, rows.implicitWidth + Tokens.padding.medium * 2 * root.scaleOffset)
        implicitHeight: rows.implicitHeight + Tokens.padding.small * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: rows

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.small * root.scaleOffset
            spacing: 0

            MenuRow {
                label: qsTr("Keep awake on interval")
                checked: IdleInhibitor.mode === IdleInhibitor.modeInterval
                hasSubmenu: true
                submenuExpanded: root.intervalExpanded
                onActivated: root.intervalExpanded = !root.intervalExpanded
            }

            Repeater {
                model: root.intervalExpanded ? root.intervals : []

                delegate: MenuRow {
                    required property var modelData

                    indented: true
                    label: modelData.label
                    onActivated: root.pick(modelData.seconds)
                }
            }

            MenuRow {
                label: qsTr("Keep awake until expiration date and time")
                checked: IdleInhibitor.mode === IdleInhibitor.modeUntil
                hint: IdleInhibitor.mode === IdleInhibitor.modeUntil && IdleInhibitor.expiresAt ? Time.shortDateTime(IdleInhibitor.expiresAt) : ""
                onActivated: root.popouts.currentName = "keepawakeexpiry"
            }

            MenuRow {
                label: qsTr("Keep awake indefinitely")
                checked: IdleInhibitor.mode === IdleInhibitor.modeIndefinite
                onActivated: {
                    IdleInhibitor.setEnabled(true);
                    root.close();
                }
            }

            MenuRow {
                label: qsTr("Off (keep using the selected power plan)")
                checked: !IdleInhibitor.enabled
                onActivated: {
                    IdleInhibitor.setEnabled(false);
                    root.close();
                }
            }

            Separator {}

            MenuRow {
                label: qsTr("Keep screen on")
                // The compositor's idle inhibitor keeps the display lit as well as the
                // machine awake, so this states what the hold does rather than offering a
                // second thing to switch on — hence ticked and not selectable.
                hint: qsTr("Included")
                checked: true
                enabled: false
            }

            Separator {}

            MenuRow {
                label: qsTr("Settings")
                icon: "settings"
                onActivated: root.popouts.currentName = "keepawakecontext"
            }
        }
    }

    component Separator: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small * root.scaleOffset
        Layout.bottomMargin: Tokens.spacing.small * root.scaleOffset
        Layout.leftMargin: Tokens.padding.medium * root.scaleOffset
        Layout.rightMargin: Tokens.padding.medium * root.scaleOffset
        implicitHeight: 1
        color: Colours.palette.m3outlineVariant
    }

    /// One line of the menu. A leading slot holds either the tick of the current mode or a
    /// plain icon, and it is always the same width so the labels line up down the column.
    component MenuRow: StyledRect {
        id: row

        required property string label
        property string hint: ""
        property bool checked: false
        property string icon: ""
        property bool indented: false
        property bool hasSubmenu: false
        property bool submenuExpanded: false

        signal activated

        Layout.fillWidth: true
        implicitWidth: rowLayout.implicitWidth + Tokens.padding.medium * 2 * root.scaleOffset + (row.indented ? Tokens.padding.large * root.scaleOffset : 0)
        implicitHeight: rowLayout.implicitHeight + Tokens.padding.small * 2 * root.scaleOffset

        radius: Tokens.rounding.medium * root.scaleOffset
        color: "transparent"

        StateLayer {
            anchors.fill: parent
            radius: row.radius
            disabled: !row.enabled
            onClicked: row.activated()
        }

        RowLayout {
            id: rowLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: (Tokens.padding.medium + (row.indented ? Tokens.padding.large : 0)) * root.scaleOffset
            anchors.rightMargin: Tokens.padding.medium * root.scaleOffset
            spacing: Tokens.spacing.small * root.scaleOffset
            // A row that cannot be chosen still reads as a statement, so it is dimmed
            // rather than faded out.
            opacity: row.enabled ? 1 : 0.6

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                // A fixed slot, so a row with a tick and a row with an icon put their
                // labels at the same place.
                Layout.preferredWidth: Tokens.font.icon.small.pointSize * root.fontScale * 1.25
                text: row.checked ? "check" : row.icon
                color: Colours.palette.m3onSurface
                fontStyle: Tokens.font.icon.builders.small.size(Tokens.font.icon.small.pointSize * root.fontScale).build()
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                text: row.label
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                elide: Text.ElideRight
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: row.hint
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
            }

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                visible: row.hasSubmenu
                text: "chevron_right"
                color: Colours.palette.m3onSurfaceVariant
                rotation: row.submenuExpanded ? 90 : 0
                fontStyle: Tokens.font.icon.builders.small.size(Tokens.font.icon.small.pointSize * root.fontScale).build()

                Behavior on rotation {
                    Anim {}
                }
            }
        }
    }
}
