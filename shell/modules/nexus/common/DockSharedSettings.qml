pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components.controls

Singleton {
    id: root

    readonly property list<MenuItem> launchingStyleItems: [
        MenuItem {
            property string value: "circle"

            text: qsTr("Circular Spinner")
        },
        MenuItem {
            property string value: "bounce"

            text: qsTr("Elastic Bounce")
        },
        MenuItem {
            property string value: "pulse"

            text: qsTr("Breathing Glow / Aura")
        },
        MenuItem {
            property string value: "orbit"

            text: qsTr("Orbiting Satellite")
        },
        MenuItem {
            property string value: "dots"

            text: qsTr("Pulsing Wave Dots")
        }
    ]

    readonly property list<MenuItem> windowGroupingItems: [
        MenuItem {
            property int value: DockWindowGrouping.Combined

            text: qsTr("Group all windows")
        },
        MenuItem {
            property int value: DockWindowGrouping.PinnedFirst

            text: qsTr("Pinned icon holds first window")
        },
        MenuItem {
            property int value: DockWindowGrouping.Ungrouped

            text: qsTr("No grouping")
        }
    ]
}
