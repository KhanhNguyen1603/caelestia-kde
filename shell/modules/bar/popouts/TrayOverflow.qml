pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar
import qs.modules.bar.components as BarComponents

// The tray's box: the icons that are not on the bar and the widgets the tray owns.
// No text: the tiles are the whole content. The cells are square and the box is as
// many of them as the icons need, so it is always a square that grows and shrinks
// with what it holds.
Item {
    id: root

    required property var popouts
    property real scaleOffset: 1.0
    property real fontScale: 1.0
    property bool _isSidebarOpen: false

    readonly property var items: TrayRegistry.overflowItems
    readonly property var widgets: BarWidgets.overflowWidgets(GlobalConfig.bar)

    // ceil(sqrt(n)) columns is the smallest square that holds n cells: 1 icon is
    // a 1x1 box, 2 to 4 a 2x2, 5 to 9 a 3x3, and the box is that square whatever
    // the last row actually fills.
    readonly property int columns: Math.max(1, Math.ceil(Math.sqrt(Math.max(1, root.items.length))))
    readonly property real cell: 42 * root.scaleOffset * root.fontScale
    readonly property real gap: Tokens.spacing.small * root.scaleOffset
    readonly property real inset: Tokens.padding.medium * 2 * root.scaleOffset
    readonly property real gridWidth: root.columns * root.cell + Math.max(0, root.columns - 1) * root.gap
    readonly property real side: root.gridWidth + root.inset
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

    implicitWidth: Math.max(root.side, content.implicitWidth + root.inset)
    implicitHeight: Math.max(root.side, content.implicitHeight + root.inset)
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
            // The grid is told how wide it is: left to itself a layout hands it a
            // width, the columns follow that width, and the square never forms.
            Layout.preferredWidth: root.gridWidth
            Layout.preferredHeight: implicitHeight
            columns: root.columns
            spacing: Tokens.spacing.small * root.scaleOffset

            // An empty box still opens from the chevron, and a blank panel reads as
            // a mistake: one faint cell is the slot waiting to be filled.
            StyledRect {
                visible: root.items.length === 0 && root.widgets.length === 0
                implicitWidth: root.cell
                implicitHeight: root.cell
                radius: Tokens.rounding.medium * root.scaleOffset
                color: Qt.alpha(Colours.palette.m3onSurface, 0.06)
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
        }

        // Widgets are live here, and some of them are a row of icons rather than
        // one, so they keep their natural size instead of being squeezed into a
        // cell: they sit under the square on their own line.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: root.widgets.length > 0
            spacing: Tokens.spacing.small * root.scaleOffset

            Repeater {
                model: root.widgets
                delegate: root.popouts.trayWidgetDelegate
            }
        }
    }
}
