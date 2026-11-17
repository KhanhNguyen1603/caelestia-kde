pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property var popouts

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    implicitWidth: 32
    implicitHeight: 32

    MaterialIcon {
        anchors.centerIn: parent
        text: "sticky_note_2"
        fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
        color: Colours.palette.m3primary
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: {
            // The popout is opened by hover, so the click only makes sure it
            // is there (it stays open, moving the pointer away closes it).
            if (root.popouts.currentName !== "notes") {
                root.popouts.currentName = "notes";
                root.popouts.currentCenter = root.isHorizontal ? root.mapToItem(null, root.implicitWidth / 2, 0).x : (root.mapToItem(null, 0, root.implicitHeight / 2).y ?? 0);
                root.popouts.hasCurrent = true;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            root.popouts.currentName = "elementscontext";
            root.popouts.currentCenter = root.isHorizontal ? root.mapToItem(null, root.implicitWidth / 2, 0).x : (root.mapToItem(null, 0, root.implicitHeight / 2).y ?? 0);
            root.popouts.hasCurrent = true;
            mouse.accepted = true;
        }
    }
}
