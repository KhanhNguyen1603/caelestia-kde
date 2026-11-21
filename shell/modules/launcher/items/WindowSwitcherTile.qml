pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.images
import qs.services
import qs.modules.launcher.services

// A window in the grid layout: its preview fills the rect the layout engine
// assigned, with the title and close button appearing on hover or selection.
Item {
    id: root

    required property var modelData
    required property var list
    property bool selected: false

    readonly property real windowAspect: {
        const size = root.modelData?.size;
        if (size && size.length >= 2) {
            const w = size[0];
            const h = size[1];
            if (w > 0 && h > 0)
                return w / h;
        }
        return 16.0 / 9.0;
    }

    function activate(): void {
        Kwin.focusWindow(root.modelData.address);
        root.list.visibilities.launcher = false;
    }

    // Unlike activate(), stays in the switcher rather than closing the launcher.
    function closeWindow(): void {
        Windows.closeWindow(root.modelData.address);
    }

    z: root.selected ? 1 : 0

    Component.onCompleted: {
        if (root.modelData)
            WinIcons.request(root.modelData.class, root.modelData.title, root.modelData.pid ?? 0, root.modelData.address ? String(root.modelData.address) : "");
    }

    HoverHandler {
        id: tileHover
    }

    StateLayer {
        anchors.fill: previewBox
        radius: previewBox.radius
        onClicked: root.activate()
    }

    StyledClippingRect {
        id: previewBox

        anchors.fill: parent
        radius: Tokens.rounding.medium

        WindowPreview {
            anchors.fill: parent
            address: root.modelData?.address ?? ""
            fallbackIcon: root.modelData ? WinIcons.sourceForClient(root.modelData) : ""
            sourceAspect: root.windowAspect
        }
    }

    StyledRect {
        anchors.fill: previewBox
        radius: previewBox.radius
        border.width: root.selected ? 2 : 0
        border.color: Colours.palette.m3primary

        Behavior on border.width {
            Anim { type: Anim.FastEffects }
        }
    }

    StyledRect {
        id: caption

        anchors.left: previewBox.left
        anchors.right: previewBox.right
        anchors.bottom: previewBox.bottom
        anchors.margins: Tokens.padding.small
        height: label.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.small
        color: Colours.palette.m3surfaceContainer
        opacity: root.selected || tileHover.hovered ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            Anim {}
        }

        StyledText {
            id: label

            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            text: {
                const title = root.modelData?.title || "";
                if (root.modelData?.minimized)
                    return `(${title})`;
                return title;
            }
            font: Tokens.font.body.small
        }
    }

    StyledRect {
        anchors.top: previewBox.top
        anchors.right: previewBox.right
        anchors.margins: Tokens.padding.small
        implicitWidth: closeIcon.implicitHeight + Tokens.padding.small * 2
        implicitHeight: closeIcon.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.small
        color: Colours.tPalette.m3surfaceVariant
        opacity: tileHover.hovered ? 1 : 0
        visible: opacity > 0.01
        z: 2

        Behavior on opacity {
            Anim {}
        }

        StateLayer {
            anchors.fill: parent
            radius: Tokens.rounding.small
            onClicked: root.closeWindow()
        }

        MaterialIcon {
            id: closeIcon

            anchors.centerIn: parent
            text: "close"
        }
    }
}
