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

    readonly property var rows: BarPlacements.rows
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

    // The rows live in a list model that is updated in place. Handing the view a new
    // array instead would throw every row away on any change the config makes, and a
    // switch drawn from nothing animates on its way to where it already was.
    function syncRows(): void {
        const rows = root.rows;
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i];
            const fields = {
                kind: row.kind,
                rowId: row.id,
                key: row.key ?? "",
                place: row.place,
                active: row.active,
                label: root.nameOf(row),
                glyph: root.glyphOf(row),
                picture: root.pictureOf(row)
            };
            const shown = i < rowModel.count ? rowModel.get(i) : null;
            if (!shown || shown.rowId !== fields.rowId || shown.kind !== fields.kind) {
                if (shown)
                    rowModel.set(i, fields);
                else
                    rowModel.append(fields);
                continue;
            }
            for (const name in fields) {
                if (shown[name] !== fields[name])
                    rowModel.setProperty(i, name, fields[name]);
            }
        }
        while (rowModel.count > rows.length)
            rowModel.remove(rowModel.count - 1);
    }

    function setShown(id: string, shown: bool): void {
        BarPlacements.setShown(id, shown);
    }

    onRowsChanged: root.syncRows()

    // Wide enough for an app's own title next to its switch: eliding "cachy update
    // updates available" to "cachy update upd…" says nothing.
    width: Math.max(360 * root.scaleOffset, root._isSidebarOpen ? (Visibilities.sidebarWidthFor(Tokens.sizes.sidebar.width) * root.scaleOffset) - Tokens.padding.extraLargeIncreased : 0)
    implicitWidth: width
    spacing: Tokens.spacing.medium * root.scaleOffset

    Component.onCompleted: root.syncRows()

    ListModel {
        id: rowModel
    }

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
                readonly property real wantedHeight: Math.max(0, Math.min(rowModel.count, list.visibleRows) * (root.rowHeight + list.spacing) - list.spacing)

                Layout.fillWidth: true
                // As tall as the icons it holds, up to ten whole rows: half a row at the
                // bottom would read as an icon cut off rather than as more below. The
                // maximum is what keeps the layout from growing the panel instead.
                Layout.preferredHeight: list.wantedHeight
                Layout.maximumHeight: list.wantedHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: rowModel
                spacing: Tokens.spacing.extraSmall * root.scaleOffset

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: list
                }

                delegate: RowLayout {
                    id: rowItem

                    required property string kind
                    required property string rowId
                    required property string key
                    required property string place
                    required property bool active
                    required property string label
                    required property string glyph
                    required property string picture

                    width: list.width
                    height: root.rowHeight
                    spacing: Tokens.spacing.small * root.scaleOffset

                    Item {
                        implicitWidth: root.rowHeight * 0.7
                        implicitHeight: root.rowHeight * 0.7
                        opacity: rowItem.active ? 1 : 0.5

                        MaterialIcon {
                            anchors.fill: parent
                            visible: rowItem.kind !== "trayItem"
                            text: rowItem.glyph
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        Image {
                            anchors.fill: parent
                            visible: rowItem.kind === "trayItem"
                            source: rowItem.picture
                            sourceSize.width: width * 2
                            sourceSize.height: height * 2
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: rowItem.label
                        // An icon with nothing to say is dimmed rather than taken away:
                        // it is still the user's to switch on, and it appears when it
                        // has something to say.
                        color: rowItem.active ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                        font: Tokens.font.body.small
                    }

                    StyledSwitch {
                        id: showSwitch

                        Layout.alignment: Qt.AlignVCenter
                        // Bound, so a switch is drawn where the icon is before anything
                        // can animate: a click breaks the binding, and the row it writes
                        // is where the answer comes back.
                        checked: rowItem.place !== "off"
                        onToggled: root.setShown(rowItem.rowId, showSwitch.checked)
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: rowModel.count === 0
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
                    initialPageIdx: "panels",
                    initialSubPage: "barTray"
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
