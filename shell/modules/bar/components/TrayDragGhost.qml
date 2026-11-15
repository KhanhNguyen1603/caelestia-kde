pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// What a drag carries: one tile holding the part of the item that was under the
// pointer. A widget can be as long as the row it draws, so the snapshot is cropped
// to a square around the grab rather than carried at its full length; lifting a
// widget then reads as lifting an item, not as dragging a copy of the bar along.
// The item it came from stays where it was and fades, so both the thing being
// moved and the thing being left are visible at once.
Item {
    id: root

    property bool shown: false

    readonly property real pad: Math.round(Tokens.padding.medium)
    readonly property real side: Math.max(Math.min(TrayDrag.ghostWidth, TrayDrag.ghostHeight), Tokens.sizes.bar.innerWidth)

    width: root.side + root.pad * 2
    height: root.side + root.pad * 2

    visible: root.shown && TrayDrag.ghost !== null
    x: TrayDrag.pos.x - root.width / 2
    y: TrayDrag.pos.y - root.height / 2
    scale: TrayDrag.active ? 1.06 : 0.86
    opacity: TrayDrag.active ? 1 : 0

    Behavior on scale {
        Anim {}
    }

    Behavior on opacity {
        Anim {
            type: Anim.FastEffects
        }
    }

    Connections {
        function onActiveChanged(): void {
            if (TrayDrag.active) {
                root.shown = true;
            } else {
                releaseTimer.restart();
            }
        }

        target: TrayDrag
    }

    Timer {
        id: releaseTimer

        interval: Tokens.anim.durations.expressiveFastEffects
        onTriggered: root.shown = false
    }

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainer
        opacity: 0.9
    }

    Item {
        id: viewport

        anchors.fill: parent
        anchors.margins: root.pad
        clip: true

        Image {
            width: TrayDrag.ghostWidth
            height: TrayDrag.ghostHeight
            x: viewport.width / 2 - TrayDrag.ghostOffset.x
            y: viewport.height / 2 - TrayDrag.ghostOffset.y
            source: TrayDrag.ghost === null ? "" : TrayDrag.ghost.url
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }
}
