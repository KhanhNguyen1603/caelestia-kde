pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components.controls
import "items"
import "services"

// An overview-style alternative to the carousel: windows fill a grid in reading
// order. `Windows.items` is kept most-recently-focused first (the active window
// moves to the front on every focus change), so the latest windows take the
// first cells. Selection still comes from Windows, so Alt+Tab cycling works the
// same in both layouts.
Item {
    id: root

    required property StyledTextField search
    required property var visibilities
    required property var panels
    required property var content

    readonly property string searchText: root.search.text.split(" ").slice(1).join(" ")

    readonly property var values: {
        const _ = Windows.items;
        return Windows.query(root.searchText);
    }

    // While searching, navigation stays inside the filtered list; otherwise it
    // follows the service so Alt+Tab moves the highlight.
    property int currentIndex: 0
    readonly property int activeIndex: root.searchText.trim() === "" ? Windows.selectedIndex : root.currentIndex
    readonly property string selectedAddress: root.values[root.activeIndex]?.address ?? ""

    readonly property real gap: Tokens.spacing.medium

    // Pick the column count that keeps cells closest to 16:9 for the available
    // area, then let the rows follow from the item count.
    readonly property int columns: {
        const n = root.values.length;
        if (n <= 1)
            return 1;
        const areaWidth = Math.max(1, root.width - Tokens.padding.large * 2);
        const areaHeight = Math.max(1, root.height - Tokens.padding.large * 2);
        return Math.max(1, Math.min(n, Math.round(Math.sqrt((n * areaWidth) / (areaHeight * 16 / 9)))));
    }
    readonly property int rows: root.columns > 0 ? Math.ceil(root.values.length / root.columns) : 0
    readonly property real cellWidth: root.columns > 0 ? Math.max(1, (root.width - Tokens.padding.large * 2 - (root.columns - 1) * root.gap) / root.columns) : 0
    readonly property real cellHeight: root.rows > 0 ? Math.max(1, (root.height - Tokens.padding.large * 2 - (root.rows - 1) * root.gap) / root.rows) : 0

    function incrementCurrentIndex(): void {
        if (root.searchText.trim() !== "") {
            if (root.values.length > 0)
                root.currentIndex = (root.currentIndex + 1) % root.values.length;
        } else {
            Windows.triggerCycleNext();
        }
    }

    function decrementCurrentIndex(): void {
        if (root.searchText.trim() !== "") {
            if (root.values.length > 0)
                root.currentIndex = (root.currentIndex - 1 + root.values.length) % root.values.length;
        } else {
            Windows.triggerCyclePrev();
        }
    }

    implicitWidth: Tokens.sizes.launcher.browseWidth * 1.35
    implicitHeight: Tokens.sizes.launcher.browseHeight * 0.85

    onSearchTextChanged: root.currentIndex = 0
    onValuesChanged: {
        if (root.currentIndex >= root.values.length)
            root.currentIndex = Math.max(0, root.values.length - 1);
    }

    Item {
        id: grid

        anchors.fill: parent
        anchors.margins: Tokens.padding.large

        Repeater {
            model: root.values

            delegate: WindowSwitcherTile {
                id: tile

                required property int index

                readonly property int column: tile.index % root.columns
                readonly property int row: Math.floor(tile.index / root.columns)

                x: tile.column * (root.cellWidth + root.gap)
                y: tile.row * (root.cellHeight + root.gap)
                width: root.cellWidth
                height: root.cellHeight
                selected: tile.modelData.address === root.selectedAddress
                list: root
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0)
                root.decrementCurrentIndex();
            else
                root.incrementCurrentIndex();
            wheel.accepted = true;
        }
    }
}
