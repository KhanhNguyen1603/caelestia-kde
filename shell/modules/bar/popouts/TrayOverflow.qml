pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar
import qs.modules.bar.components as BarComponents

// The tray's box: the icons that are not on the bar, as square tiles. The grid is
// four rows tall and as wide as the icons need, in whole columns, so it never turns
// into a strip of one row. Slots that are still free are drawn faint, which is what
// makes the box read as a grid icons drop into rather than as a gap.
Item {
    id: root

    required property var popouts
    property real scaleOffset: 1.0
    property real fontScale: 1.0
    property bool _isSidebarOpen: false

    readonly property var items: TrayRegistry.overflowItems
    readonly property var widgets: BarWidgets.overflowWidgets(GlobalConfig.bar)
    // A widget that is one icon is a cell like the tray icons are. The rest are live
    // widgets, some of them a row of icons rather than one, so they keep their
    // natural size on their own line under the square.
    readonly property var cellWidgets: root.widgets.filter(widget => widget.kind === "statusIcon")
    readonly property var rowWidgets: root.widgets.filter(widget => widget.kind !== "statusIcon")

    // The grid is only as big as the icons in it: as square as it can be, never more
    // than four rows, and a column wider once those are full. Nothing is reserved, so
    // the box is exactly the cells its icons need.
    readonly property int maxRows: 4
    readonly property int filled: root.items.length + root.cellWidgets.length
    readonly property int columns: Math.max(1, Math.ceil(Math.sqrt(root.filled)), Math.ceil(root.filled / root.maxRows))
    readonly property int rows: Math.max(1, Math.ceil(root.filled / root.columns))

    readonly property real cell: 42 * root.scaleOffset * root.fontScale
    readonly property real gap: Tokens.spacing.small * root.scaleOffset
    readonly property real inset: Tokens.padding.medium * root.scaleOffset
    readonly property real gridWidth: root.columns * root.cell + (root.columns - 1) * root.gap
    readonly property real gridHeight: root.rows * root.cell + (root.rows - 1) * root.gap
    // The box leans in when a drag is over it, so it is obvious the icon will land
    // here rather than being dropped somewhere else.
    readonly property bool targeted: TrayDrag.active && root.trayDropAt(TrayDrag.window, TrayDrag.pos.x, TrayDrag.pos.y)

    // A drag that starts on the bar is lifted from the bar's window and released
    // over the popout's, so the move has to work across the two: they are compared by
    // screen, and only when both report one, which keeps another output's box from
    // answering for this one.
    function onDragScreen(window: var): bool {
        const mine = root.Window.window;
        if (!window || !mine)
            return false;
        return !window.screen || !mine.screen || window.screen === mine.screen;
    }

    function trayDropAt(window: var, x: real, y: real): bool {
        if (!root.visible || !root.onDragScreen(window))
            return false;
        const p = root.mapFromItem(null, x, y);
        return p.x >= 0 && p.y >= 0 && p.x <= root.width && p.y <= root.height;
    }

    function trayDrop(source: var): void {
        if (!source)
            return;
        if (source.kind === "widget")
            BarWidgets.setInTray(GlobalConfig.bar, source.widgetId);
        else if (source.kind === "icon")
            TrayRegistry.sendToBox(source.key);
    }

    implicitWidth: Math.max(root.gridWidth, content.implicitWidth) + root.inset * 2
    implicitHeight: Math.max(root.gridHeight, content.implicitHeight) + root.inset * 2
    width: implicitWidth
    height: implicitHeight

    Component.onCompleted: TrayDrag.register(root)

    Component.onDestruction: TrayDrag.unregister(root)

    Behavior on implicitWidth {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    ColumnLayout {
        id: content

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium * root.scaleOffset
        scale: root.targeted ? 1.06 : 1

        Behavior on scale {
            Anim {}
        }

        Grid {
            id: grid

            Layout.alignment: Qt.AlignHCenter
            // The grid is told how wide and tall it is: left to itself a layout hands
            // it a size, the columns follow that size, and the grid never forms.
            Layout.preferredWidth: root.gridWidth
            Layout.preferredHeight: root.gridHeight
            columns: root.columns
            spacing: root.gap

            // Tiles take their places rather than appearing where they end up, so a
            // box that grows reads as snapping to the next column.
            add: Transition {
                Anim {
                    properties: "scale"
                    from: 0
                    to: 1
                    easing: Tokens.anim.standardDecel
                }
            }

            move: Transition {
                Anim {
                    properties: "scale"
                    to: 1
                    easing: Tokens.anim.standardDecel
                }
                Anim {
                    properties: "x,y"
                }
            }

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

            Repeater {
                model: root.cellWidgets

                delegate: StyledRect {
                    id: cellTile

                    required property var modelData

                    implicitWidth: root.cell
                    implicitHeight: root.cell
                    radius: Tokens.rounding.medium * root.scaleOffset
                    color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                    BarComponents.StatusIcon {
                        anchors.centerIn: parent
                        entryId: cellTile.modelData.id
                        popouts: root.popouts
                        draggable: true
                    }
                }
            }

            // An empty box still opens from the chevron, and a blank panel reads as a
            // mistake: one faint cell stands in for the icons that will fill it.
            Repeater {
                model: root.filled === 0 ? 1 : 0

                delegate: StyledRect {
                    implicitWidth: root.cell
                    implicitHeight: root.cell
                    radius: Tokens.rounding.medium * root.scaleOffset
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.06)
                }
            }
        }

        // Widgets are live here, and some of them are a row of icons rather than
        // one, so they keep their natural size instead of being squeezed into a
        // cell: they sit under the grid on their own line.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: root.rowWidgets.length > 0
            spacing: Tokens.spacing.small * root.scaleOffset

            Repeater {
                model: root.rowWidgets
                delegate: root.popouts.trayWidgetDelegate
            }
        }
    }
}
