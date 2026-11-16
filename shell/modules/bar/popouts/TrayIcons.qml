pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.bar
import qs.modules.nexus

// What the bar shows, as one list: every icon it can draw, each with a single switch.
// Off is the only thing the list decides; an icon switched on lands in the tray's box,
// where dragging it is what puts it somewhere else on the bar.
ColumnLayout {
    id: root

    required property PopoutState popouts

    property real scaleOffset: 1.0
    property real fontScale: 1.0
    property bool _isSidebarOpen: false

    readonly property var rows: BarWidgets.placementRows(GlobalConfig.bar)
    // The tray's apps name and draw themselves; the bar's icons are named by the map the
    // settings pages read too.
    readonly property var trayItems: {
        const items = {};
        for (const item of TrayRegistry.entries ?? [])
            items[item.key] = item;
        return items;
    }
    readonly property real rowHeight: 30 * root.scaleOffset * root.fontScale

    function iconIdOf(row: var): string {
        const statusId = BarWidgets.statusIconId(row.id);
        return statusId.length > 0 ? statusId : row.id;
    }

    function nameOf(row: var): string {
        if (row.kind === "trayItem")
            return root.trayItems[row.key]?.title ?? row.key;
        return BarIconMeta.nameOf(root.iconIdOf(row));
    }

    function glyphOf(row: var): string {
        return row.kind === "trayItem" ? "" : BarIconMeta.iconOf(root.iconIdOf(row));
    }

    function pictureOf(row: var): string {
        const item = root.trayItems[row.key];
        return item ? Icons.getTrayIcon(item.key, item.icon) : "";
    }

    function isShown(row: var): bool {
        return row.place !== "off";
    }

    function setShown(row: var, shown: bool): void {
        BarWidgets.setShown(GlobalConfig.bar, row, shown);
    }

    width: Math.max(360 * root.scaleOffset, root._isSidebarOpen ? (Visibilities.sidebarWidthFor(Tokens.sizes.sidebar.width) * root.scaleOffset) - Tokens.padding.extraLargeIncreased : 0)
    implicitWidth: width
    spacing: Tokens.spacing.medium * root.scaleOffset

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: card.implicitHeight + Tokens.padding.medium * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: card

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium * root.scaleOffset
            spacing: Tokens.spacing.extraSmall * root.scaleOffset

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Show icons")
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
            }

            ListView {
                id: list

                readonly property int visibleRows: 10
                readonly property real wantedHeight: Math.max(0, Math.min(root.rows.length, list.visibleRows) * (root.rowHeight + list.spacing) - list.spacing)

                Layout.fillWidth: true
                // As tall as the icons it holds, up to ten whole rows: half a row at the
                // bottom would read as an icon cut off rather than as more below. The
                // maximum is what keeps the layout from growing the panel instead.
                Layout.preferredHeight: list.wantedHeight
                Layout.maximumHeight: list.wantedHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.rows
                spacing: Tokens.spacing.extraSmall * root.scaleOffset

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: list
                }

                delegate: RowLayout {
                    id: rowItem

                    required property var modelData

                    width: list.width
                    height: root.rowHeight
                    spacing: Tokens.spacing.small * root.scaleOffset

                    // The switch is set from the icon's own state and not bound to it: a
                    // click moves the switch first, and the answer that comes back is
                    // what leaves it where it belongs.
                    onModelDataChanged: showSwitch.checked = root.isShown(rowItem.modelData)

                    Item {
                        implicitWidth: root.rowHeight * 0.7
                        implicitHeight: root.rowHeight * 0.7
                        opacity: rowItem.modelData.active ? 1 : 0.5

                        MaterialIcon {
                            anchors.fill: parent
                            visible: rowItem.modelData.kind !== "trayItem"
                            text: root.glyphOf(rowItem.modelData)
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        Image {
                            anchors.fill: parent
                            visible: rowItem.modelData.kind === "trayItem"
                            source: root.pictureOf(rowItem.modelData)
                            sourceSize.width: width * 2
                            sourceSize.height: height * 2
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.nameOf(rowItem.modelData)
                        // An icon with nothing to say is dimmed rather than taken away:
                        // it is still the user's to switch on, and it appears when it
                        // has something to say.
                        color: rowItem.modelData.active ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                        font: Tokens.font.body.small
                    }

                    StyledSwitch {
                        id: showSwitch

                        Layout.alignment: Qt.AlignVCenter
                        Component.onCompleted: showSwitch.checked = root.isShown(rowItem.modelData)
                        onToggled: {
                            if (root.isShown(rowItem.modelData) !== showSwitch.checked)
                                root.setShown(rowItem.modelData, showSwitch.checked);
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.rows.length === 0
                text: qsTr("Nothing to place yet")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }
        }
    }

    // Where the order and the rest of the tray's options are, for the times this list is
    // not enough.
    StyledRect {
        Layout.fillWidth: true
        implicitWidth: settingsRow.implicitWidth + Tokens.padding.medium * 2 * root.scaleOffset
        implicitHeight: settingsRow.implicitHeight + Tokens.padding.small * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: "transparent"

        StateLayer {
            radius: parent.radius

            onClicked: {
                root.popouts.hasCurrent = false;
                WindowFactory.create(null, {
                    initialPageIdx: PageRegistry.indexForKey("panels"),
                    initialSubPageIdx: PageDictionary.subPageIdxFor("panels/taskbar/BarTray.qml")
                });
            }
        }

        RowLayout {
            id: settingsRow

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.medium * root.scaleOffset
            anchors.rightMargin: Tokens.padding.medium * root.scaleOffset
            spacing: Tokens.spacing.small * root.scaleOffset

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: "settings"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: qsTr("Tray settings")
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.small
            }
        }
    }
}
