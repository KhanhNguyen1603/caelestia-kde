pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.bar.popouts

Item {
    id: root

    required property ShellScreen screen
    Config.screen: screen.name
    required property var bar
    property var dockPanel: null
    required property real borderThickness
    required property DrawerVisibilities visibilities

    readonly property alias content: content
    readonly property var activePanel: {
        if (content.sourcePanel === "dockPanel")
            return (root.dockPanel && !root.dockPanel.disabled) ? root.dockPanel : root.bar;
        if (content.sourcePanel === "bar")
            return root.bar;
        if (content.isDockPanelPopout && root.dockPanel && !root.dockPanel.disabled)
            return root.dockPanel;
        return root.bar;
    }
    // Set while the popout is open over the notification stack. Panel backgrounds
    // are shared blobs drawn below every panel's content, so the popout gets an
    // opaque fill of its own to keep the notifications' text from showing through.
    property bool backed: false
    readonly property bool isHorizontal: activePanel.isHorizontal
    readonly property bool hovered: popoutsHover.hovered
    property real offsetScale: content.isDetached || content.hasCurrent ? 0 : 1

    readonly property real panelLeft: activePanel ? Math.round(activePanel.x - parent.leftMargin) : 0
    readonly property real panelRight: activePanel ? Math.round(activePanel.x + activePanel.width - parent.leftMargin) : parent.width
    readonly property real panelWidth: Math.max(1, panelRight - panelLeft)
    readonly property real panelCenterX: panelLeft + panelWidth / 2

    readonly property real panelTop: activePanel ? Math.round(activePanel.y - parent.topMargin) : 0
    readonly property real panelBottom: activePanel ? Math.round(activePanel.y + activePanel.height - parent.topMargin) : parent.height
    readonly property real panelHeight: Math.max(1, panelBottom - panelTop)
    readonly property real panelCenterY: panelTop + panelHeight / 2

    readonly property real effectivePanelRight: {
        let r = panelRight;
        if (activePanel === bar && root.visibilities.sidebar && !content.underSidebar) {
            const sideR = parent.width - Visibilities.sidebarWidthFor(Tokens.sizes.sidebar.width) - Tokens.spacing.extraLarge;
            r = Math.min(r, sideR);
        }
        return r;
    }
    readonly property real effectivePanelWidth: Math.max(1, effectivePanelRight - panelLeft)
    readonly property real effectivePanelCenterX: panelLeft + effectivePanelWidth / 2

    readonly property bool isLampActive: !content.isDetached && (isHorizontal ? (effectivePanelWidth < content.nonAnimWidth) : (panelHeight < content.nonAnimHeight))
    readonly property real lampScaleX: (isLampActive && isHorizontal && content.nonAnimWidth > 0) ? (width / content.nonAnimWidth) : 1
    readonly property real lampScaleY: (isLampActive && !isHorizontal && content.nonAnimHeight > 0) ? (height / content.nonAnimHeight) : 1

    // Where x is heading; x itself animates towards it.
    readonly property real targetX: {
        if (content.isDetached)
            return (parent.width - content.nonAnimWidth) / 2;
        if (isHorizontal) {
            if (activePanel === bar && content.sidebarOpen && !content.isDockPopout)
                return parent.width - content.nonAnimWidth;

            // An item left of the open sidebar gets its popout kept clear of it, so
            // the sidebar doesn't have to be pushed out of the way.
            const idealX = content.currentCenter - parent.leftMargin - content.nonAnimWidth / 2;
            if (effectivePanelWidth >= content.nonAnimWidth) {
                const minX = Math.max(0, panelLeft);
                const maxX = Math.min(parent.width - content.nonAnimWidth, effectivePanelRight - content.nonAnimWidth);
                if (minX <= maxX)
                    return Math.max(minX, Math.min(idealX, maxX));
                return minX;
            }
            return Math.max(0, Math.min(parent.width - content.nonAnimWidth, effectivePanelCenterX - content.nonAnimWidth / 2));
        }
        if (activePanel.position === "right")
            return parent.width - implicitWidth;
        return 0;
    }

    readonly property real targetY: {
        if (content.isDetached)
            return (parent.height - content.nonAnimHeight) / 2;
        if (isHorizontal) {
            if (activePanel.position === "bottom")
                return parent.height - implicitHeight;
            return 0;
        }

        const idealY = content.currentCenter - parent.topMargin - content.nonAnimHeight / 2;
        if (panelHeight >= content.nonAnimHeight) {
            const minY = Math.max(0, panelTop);
            const maxY = Math.min(parent.height - content.nonAnimHeight, panelBottom - content.nonAnimHeight);
            if (minY <= maxY)
                return Math.max(minY, Math.min(idealY, maxY));
            return minY;
        }
        return Math.max(0, Math.min(parent.height - content.nonAnimHeight, panelCenterY - content.nonAnimHeight / 2));
    }

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: {
        if (isHorizontal) {
            if (isLampActive)
                return Math.round(content.nonAnimWidth - (content.nonAnimWidth - effectivePanelWidth) * offsetScale);
            return content.implicitWidth;
        }
        return content.implicitWidth * (1 - offsetScale);
    }
    implicitHeight: {
        if (isHorizontal)
            return content.implicitHeight * (1 - offsetScale);
        if (isLampActive)
            return Math.round(content.nonAnimHeight - (content.nonAnimHeight - panelHeight) * offsetScale);
        return content.implicitHeight;
    }

    x: {
        if (isLampActive && isHorizontal)
            return Math.round(targetX + (panelLeft - targetX) * offsetScale);
        return targetX;
    }
    y: {
        if (isLampActive && !isHorizontal)
            return Math.round(targetY + (panelTop - targetY) * offsetScale);
        return targetY;
    }

    onOffsetScaleChanged: {
        if (offsetScale >= 1 && !content.hasCurrent)
            content.sourcePanel = "";
    }

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on x {
        enabled: (content.isDetached || isHorizontal) && !root.isLampActive

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        enabled: (content.isDetached || (!isHorizontal && root.offsetScale < 1)) && !root.isLampActive

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    StyledRect {
        anchors.fill: parent
        z: -1
        visible: root.backed
        radius: Surface.panelRounding
        // The opaque palette: the transparent one would let the text through.
        color: GlobalConfig.appearance.pitchBlack ? "#000000" : Colours.palette.m3surface

        // Clicks and hovers on the popout's padding must not reach the notification below.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onWheel: wheel => wheel.accepted = true
        }
    }

    HoverHandler {
        id: popoutsHover
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale
        visibilities: root.visibilities
        isPanelHorizontal: root.isHorizontal
        underSidebar: root.activePanel === root.bar && (!root.isHorizontal || content.currentCenter - root.parent.leftMargin >= root.parent.width - Visibilities.sidebarWidthFor(Tokens.sizes.sidebar.width))

        anchors.leftMargin: root.activePanel.position === "left" ? (-implicitWidth - 5) * root.offsetScale : 0
        anchors.rightMargin: root.activePanel.position === "right" ? (-implicitWidth - 5) * root.offsetScale : 0
        anchors.topMargin: root.activePanel.position === "top" ? (-implicitHeight - 5) * root.offsetScale : 0
        anchors.bottomMargin: root.activePanel.position === "bottom" ? (-implicitHeight - 5) * root.offsetScale : 0

        transform: Scale {
            xScale: root.lampScaleX
            yScale: root.lampScaleY
            origin.x: (content.width || root.implicitWidth) / 2
            origin.y: (content.height || root.implicitHeight) / 2
        }

        states: [
            State {
                name: "left"
                when: root.activePanel.position === "left"

                AnchorChanges {
                    target: content
                    anchors.left: parent.left
                    anchors.right: undefined
                    anchors.top: undefined
                    anchors.bottom: undefined
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: undefined
                }
            },
            State {
                name: "right"
                when: root.activePanel.position === "right"

                AnchorChanges {
                    target: content
                    anchors.left: undefined
                    anchors.right: parent.right
                    anchors.top: undefined
                    anchors.bottom: undefined
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: undefined
                }
            },
            State {
                name: "top"
                when: root.activePanel.position === "top"

                AnchorChanges {
                    target: content
                    anchors.left: undefined
                    anchors.right: undefined
                    anchors.top: parent.top
                    anchors.bottom: undefined
                    anchors.verticalCenter: undefined
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            },
            State {
                name: "bottom"
                when: root.activePanel.position === "bottom"

                AnchorChanges {
                    target: content
                    anchors.left: undefined
                    anchors.right: undefined
                    anchors.top: undefined
                    anchors.bottom: parent.bottom
                    anchors.verticalCenter: undefined
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        ]
    }
}
