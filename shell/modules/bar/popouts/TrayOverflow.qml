pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar
import qs.modules.bar.components as BarComponents

// The tray's box: the icons that are not on the bar, laid out as one grid. The grid
// is four rows tall and as wide as the icons need, in whole columns, so it never
// turns into a strip of one row. Nothing is reserved, so the box is exactly the cells
// its icons need.
Item {
    id: root

    required property var popouts
    property real scaleOffset: 1.0
    property real fontScale: 1.0
    property bool _isSidebarOpen: false
    // The panel's own frame, tighter than a text popout's: the grid already spaces
    // the glyphs.
    readonly property real popoutMargin: Tokens.padding.small

    readonly property var items: TrayRegistry.overflowItems
    // Every widget the box holds, in the order the bar gives them: status icons and the
    // rest are one sequence, so a drag can put any of them in any cell.
    readonly property var widgets: BarWidgets.overflowWidgets(GlobalConfig.bar)

    // The grid is only as big as the icons in it: as square as it can be, never more
    // than four rows, and a column wider once those are full.
    readonly property int maxRows: 4
    readonly property int filled: root.items.length + root.widgets.length
    readonly property int columns: Math.max(1, Math.ceil(Math.sqrt(root.filled)), Math.ceil(root.filled / root.maxRows))
    readonly property int rows: Math.max(1, Math.ceil(root.filled / root.columns))

    readonly property real cell: 32 * root.scaleOffset * root.fontScale
    readonly property real gap: Tokens.spacing.extraSmall * root.scaleOffset
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
        const own = TrayDrag.toLocal(root.Window.window, x, y);
        const p = root.mapFromItem(null, own.x, own.y);
        return p.x >= 0 && p.y >= 0 && p.x <= root.width && p.y <= root.height;
    }

    // The cell a drop lands in, as the entry it holds: a tray icon answers with its
    // key, a widget with its id. The nearest cell answers when the pointer is between
    // cells, so an icon dropped onto the box always lands somewhere.
    function entryAt(x: real, y: real): var {
        const own = TrayDrag.toLocal(root.Window.window, x, y);
        let best = null;
        let bestDist = Infinity;
        for (let i = 0; i < grid.children.length; i++) {
            const child = grid.children[i];
            if (!child || child.width <= 0 || !child.visible)
                continue;

            const key = child.trayKey ?? "";
            const id = child.widgetId ?? child.id ?? "";
            if (key.length === 0 && (typeof id !== "string" || id.length === 0))
                continue;

            const origin = child.mapToItem(null, 0, 0);
            const dx = own.x - (origin.x + child.width / 2);
            const dy = own.y - (origin.y + child.height / 2);
            const dist = dx * dx + dy * dy;
            if (dist < bestDist) {
                bestDist = dist;
                best = key.length > 0 ? {
                    key: key
                } : {
                    id: id
                };
            }
        }
        return best;
    }

    function trayDrop(source: var, x: real, y: real): void {
        if (!source)
            return;

        // The cell the pointer is on decides the place; the last cell is a place too,
        // so an icon dropped past the end simply lands last.
        const target = root.entryAt(x, y);
        const id = source.kind === "icon" ? TrayRegistry.rowFor(source.key) : source.widgetId;
        BarPlacements.setPlacement(id, BarPlacements.trayZone, {
            beforeId: target?.id ?? "",
            beforeKey: target?.key ?? ""
        });
    }

    // The panel frames the grid; the box is exactly the cells it holds.
    implicitWidth: Math.max(root.gridWidth, grid.implicitWidth)
    implicitHeight: Math.max(root.gridHeight, grid.implicitHeight)
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

    Grid {
        id: grid

        anchors.centerIn: parent
        columns: root.columns
        spacing: root.gap
        // A widget drawn by the bar can be wider or taller than a cell; centred, its
        // glyph sits on the same optical line as the icons around it.
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        scale: root.targeted ? 1.06 : 1

        // Cells take their places rather than appearing where they end up, so a box that
        // grows reads as snapping to the next column. Cells are added again whenever the
        // list is rebuilt, so adding does not animate: a moved icon would otherwise look
        // like every icon in the box vanishing and coming back.
        move: Transition {
            Anim {
                properties: "x,y"
                easing: Tokens.anim.standardDecel
            }
        }

        Behavior on scale {
            Anim {}
        }

        Repeater {
            model: ScriptModel {
                values: root.items
            }

            delegate: Item {
                id: tile

                required property var modelData
                // What a drop read back from the cell: the key the tray orders by.
                readonly property string trayKey: TrayRegistry.keyOfItem(tile.modelData)

                implicitWidth: root.cell
                implicitHeight: root.cell

                BarComponents.TrayItem {
                    anchors.centerIn: parent
                    modelData: tile.modelData
                    popouts: root.popouts
                    isHorizontal: true
                    draggable: true
                }
            }
        }

        // Every widget the box holds, in the one order the bar gives them: a status icon
        // is one glyph and draws as a cell, anything else stays live and is drawn by the
        // same delegate the bar uses. One row of cells rather than one per kind is what
        // lets a drag put any of them in any cell.
        Repeater {
            model: ScriptModel {
                values: root.widgets
            }

            delegate: Item {
                id: widgetCell

                required property var modelData

                readonly property string widgetId: widgetCell.modelData.id
                readonly property bool isIcon: widgetCell.modelData.kind === "statusIcon"

                // A cell is always a cell: the grid is the icons it holds, and an entry
                // that has nothing to say is left out of the list rather than drawn as a
                // hole.
                implicitWidth: root.cell
                implicitHeight: root.cell

                BarComponents.StatusIcon {
                    id: icon

                    anchors.centerIn: parent
                    visible: widgetCell.isIcon
                    entryId: widgetCell.widgetId
                    popouts: root.popouts
                    draggable: true
                }

                BarComponents.BarWidgetCell {
                    anchors.centerIn: parent
                    visible: !widgetCell.isIcon
                    entry: widgetCell.modelData
                    popouts: root.popouts
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
}
