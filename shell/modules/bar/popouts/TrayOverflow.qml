pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar.components as BarComponents

// The tray's overflow panel: the icons that are not pinned to the bar. Dragging
// an icon between here and the tray changes its TrayRegistry state, which is the
// same setting the tray page writes.
Item {
    id: root

    required property var popouts
    property real scaleOffset: 1.0
    property real fontScale: 1.0
    property bool _isSidebarOpen: false

    readonly property var items: TrayRegistry.overflowItems
    readonly property int columns: Math.max(1, Math.min(6, Math.ceil(Math.sqrt(root.items.length))))
    readonly property real cell: 42 * root.scaleOffset
    readonly property real gridWidth: root.columns * root.cell + Math.max(0, root.columns - 1) * Tokens.spacing.small * root.scaleOffset
    readonly property real preferredWidth: Math.max(280 * root.scaleOffset, Math.min(520 * root.scaleOffset, root.gridWidth + Tokens.padding.large * 2 * root.scaleOffset))

    implicitWidth: root.preferredWidth
    implicitHeight: layout.implicitHeight
    width: implicitWidth
    height: implicitHeight

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.small * root.scaleOffset

        StyledText {
            Layout.leftMargin: Tokens.padding.small * root.scaleOffset
            text: qsTr("Hidden icons")
            font: Tokens.font.title.small
            color: Colours.palette.m3onSurface
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small * root.scaleOffset
            Layout.rightMargin: Tokens.padding.small * root.scaleOffset
            text: qsTr("Drag icons here to take them off the bar.")
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurfaceVariant
            wrapMode: Text.WordWrap
        }

        Grid {
            id: grid

            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small * root.scaleOffset
            Layout.rightMargin: Tokens.padding.small * root.scaleOffset
            columns: root.columns
            spacing: Tokens.spacing.small * root.scaleOffset

            Repeater {
                model: root.items

                delegate: StyledRect {
                    id: tile

                    required property var modelData

                    implicitWidth: root.cell
                    implicitHeight: root.cell
                    radius: Tokens.rounding.medium * root.scaleOffset
                    color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                    BarComponents.TrayItem {
                        anchors.centerIn: parent
                        modelData: tile.modelData
                        popouts: root.popouts
                        isHorizontal: true
                        draggable: true
                    }
                }
            }
        }

        StyledText {
            visible: root.items.length === 0

            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small * root.scaleOffset
            text: qsTr("No hidden icons")
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurfaceVariant
        }
    }

    // A bar icon dropped anywhere on this panel leaves the bar. Which state it
    // lands in depends on whether compact mode is what was hiding it.
    DropArea {
        anchors.fill: parent
        keys: ["trayIcon"]

        onDropped: drop => {
            const source = drop.source;
            if (source && source.key)
                TrayRegistry.setState(source.key, Config.bar.tray.compact ? "collapsed" : "hidden");
            TrayRegistry.draggingIcon = false;
        }
    }
}
