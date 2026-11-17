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
    // The box is its own surface, the same wash the tray's pill is drawn in, so it reads
    // as one panel whether it hangs over the bar or past it. Its frame is only the room
    // the glyphs need to not sit under the pointer's edge.
    readonly property real popoutMargin: Tokens.padding.small
    // It draws that surface itself, so the drawer puts nothing behind it: a plate or a
    // blur of its own would only show at the edges, offset from the panel they back.
    readonly property bool popoutOwnSurface: true

    readonly property var items: TrayRegistry.overflowItems
    // The icon under the pointer and what it is called. The box is a popout of its own,
    // and a tooltip is a window: one opened over a box this small takes the hover away
    // from the icon it was describing, so the name and the icon take turns appearing for
    // as long as the pointer rests. The box draws the name instead, on the icon itself.
    property Item hoveredItem: null
    property string hoveredLabel: ""
    // Every widget the box holds, in the order the bar gives them: status icons and the
    // rest are one sequence, so a drag can put any of them in any cell.
    readonly property var widgets: BarWidgets.overflowWidgets(GlobalConfig.bar)

    // The grid is as square as the icons in it, never more than four rows, and a column
    // wider once those are full. A box is a place to put things, so it keeps room for a
    // few before it holds any: one icon should not leave a hole the size of one icon.
    readonly property int maxRows: 4
    readonly property int minColumns: 3
    readonly property int minRows: 2
    readonly property int filled: root.items.length + root.widgets.length
    readonly property int columns: Math.max(root.minColumns, Math.ceil(Math.sqrt(root.filled)), Math.ceil(root.filled / root.maxRows))
    readonly property int rows: Math.max(root.minRows, Math.ceil(root.filled / root.columns))

    readonly property real cell: 34 * root.scaleOffset * root.fontScale
    readonly property real gap: Tokens.spacing.small * root.scaleOffset
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

    function setHoveredIcon(icon: var, hovered: bool): void {
        if (hovered) {
            root.hoveredItem = icon;
            root.hoveredLabel = icon.tooltip;
        } else if (root.hoveredItem === icon) {
            root.hoveredItem = null;
            root.hoveredLabel = "";
        }
    }

    // The panel frames the grid; the box is exactly the cells it holds. Measuring the
    // grid instead would let whatever a cell holds set the size, and one wide widget put
    // in a cell would open the box halfway across the screen.
    implicitWidth: root.gridWidth
    implicitHeight: root.gridHeight
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

    // The box draws its own panel, so the glyphs sit on one surface instead of the bar's
    // colour above and the desktop below. It is mixed from the opaque palette: it hangs
    // over the desktop, where the transparent one would barely show.
    StyledRect {
        anchors.fill: parent
        z: -1
        radius: Tokens.rounding.large * root.scaleOffset
        color: Qt.alpha(Colours.palette.m3surfaceContainer, 0.92)
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
                    insidePopout: true

                    onHoveredChanged: root.setHoveredIcon(this, hovered)
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
                    insidePopout: true

                    onHoveredChanged: root.setHoveredIcon(this, hovered)
                }

                // A cell is one cell whatever it holds: a widget drawn wider than that
                // is fitted into it, the way a thumbnail is, rather than being allowed
                // to push the box open.
                BarComponents.BarWidgetCell {
                    readonly property real fit: Math.min(1, root.cell / Math.max(1, implicitWidth, implicitHeight))

                    anchors.centerIn: parent
                    visible: !widgetCell.isIcon
                    entry: widgetCell.modelData
                    popouts: root.popouts
                    scale: fit
                }
            }
        }

        // An empty box is just the room it keeps: a cell standing in for the icons that
        // will fill it reads as something to press, and there is nothing there to press.
    }

    // What the pointer is over, in words, on the icon it is over. It is drawn rather than
    // floated: see hoveredItem. Clamped inside the box, because the box is a surface and
    // its content is cut to it.
    StyledRect {
        id: nameTag

        readonly property var origin: root.hoveredItem ? root.mapFromItem(root.hoveredItem, 0, 0) : null

        z: 10
        visible: root.hoveredLabel.length > 0 && root.hoveredItem !== null
        implicitWidth: nameText.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: nameText.implicitHeight + Tokens.padding.small * 2
        x: nameTag.origin ? Math.min(Math.max(nameTag.origin.x + (root.hoveredItem.width - nameTag.width) / 2, Tokens.padding.small), Math.max(Tokens.padding.small, root.width - nameTag.width - Tokens.padding.small)) : 0
        y: {
            if (!nameTag.origin)
                return 0;
            const above = nameTag.origin.y - nameTag.height - Tokens.spacing.extraSmall;
            const below = nameTag.origin.y + root.hoveredItem.height + Tokens.spacing.extraSmall;
            const wanted = above >= Tokens.padding.small ? above : below;
            return Math.min(Math.max(wanted, Tokens.padding.small), Math.max(Tokens.padding.small, root.height - nameTag.height - Tokens.padding.small));
        }
        radius: Tokens.rounding.medium
        color: Colours.palette.m3surfaceContainerHighest

        StyledText {
            id: nameText

            anchors.centerIn: parent
            text: root.hoveredLabel
            color: Colours.palette.m3onSurface
            font: Tokens.font.label.small
        }
    }
}
