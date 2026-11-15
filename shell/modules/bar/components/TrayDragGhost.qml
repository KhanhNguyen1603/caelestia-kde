pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Caelestia.Config
import qs.components
import qs.services

// What a drag carries: a snapshot of the item it lifted, drawn under the pointer
// with a shadow so it reads as lifted rather than as a second copy of the row. The
// item it came from stays where it was and fades, so both the thing being moved and
// the thing being left behind are visible at once.
Item {
    id: root

    property bool shown: false

    readonly property real pad: Math.round(Tokens.padding.medium)

    width: TrayDrag.ghostWidth + root.pad * 2
    height: TrayDrag.ghostHeight + root.pad * 2

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

    Image {
        id: snapshot

        anchors.fill: parent
        anchors.margins: root.pad
        source: TrayDrag.ghost === null ? "" : TrayDrag.ghost.url
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
    }

    MultiEffect {
        anchors.fill: snapshot
        source: snapshot
        shadowEnabled: true
        shadowColor: Qt.alpha("black", 0.45)
        shadowBlur: 0.7
        shadowVerticalOffset: 4
        autoPaddingEnabled: true
    }
}
