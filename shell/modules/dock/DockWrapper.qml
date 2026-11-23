pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.widgets
import qs.services
import qs.utils

Item {
    id: root

    required property ShellScreen screen
    Config.screen: screen.name
    required property DrawerVisibilities visibilities
    required property bool fullscreen
    property var popouts: null

    readonly property bool disabled: !Config.dockPanel.enabled || Strings.testRegexList(Config.dockPanel.excludedScreens, screen.name)
    readonly property string position: Config.dockPanel.position
    readonly property bool isIsland: Config.dockPanel.islands
    readonly property bool isHorizontal: root.position === "top" || root.position === "bottom"
    readonly property int padding: Config.dockPanel.padding
    readonly property int spacing: Config.dockPanel.spacing
    readonly property real iconSize: Math.max(12, Config.dockPanel.iconSize)
    readonly property real itemSize: Math.max(8, Math.max(Config.dockPanel.size, root.iconSize))
    readonly property bool hasLauncher: Config.dockPanel.showLauncherIcon
    readonly property int itemCount: DockManager.count + (hasLauncher ? 1 : 0)
    readonly property real computedContentSpan: {
        if (itemCount <= 0)
            return 0;
        const listSpan = listView ? (root.isHorizontal ? listView.contentWidth : listView.contentHeight) : 0;
        if (listSpan > 0)
            return listSpan + (root.hasLauncher ? (root.itemSize + root.spacing) : 0);
        return itemCount * root.itemSize + (itemCount - 1) * root.spacing;
    }
    readonly property int contentThickness: root.itemSize + root.padding * 2
    readonly property int islandMargin: isIsland ? Config.dockPanel.floatingMargin : 0
    readonly property bool dodgeEnabled: Config.dockPanel.dodgeWindows && !Config.dockPanel.persistent && !disabled
    readonly property rect dodgeRect: {
        const ox = screen.x ?? 0;
        const oy = screen.y ?? 0;
        const totalDepth = contentThickness + islandMargin;
        if (position === "top")
            return Qt.rect(ox, oy, screen.width, totalDepth);
        if (position === "bottom")
            return Qt.rect(ox, oy + screen.height - totalDepth, screen.width, totalDepth);
        if (position === "left")
            return Qt.rect(ox, oy, totalDepth, screen.height);
        return Qt.rect(ox + screen.width - totalDepth, oy, totalDepth, screen.height);
    }
    readonly property var _dodgeWatchWindowList: (true) ? Kwin.windowList : null
    readonly property var _dodgeWatchActiveWindow: (true) ? Kwin.activeWindow : null
    readonly property int _dodgeWatchActiveId: (true) ? Kwin.activeWsId : -1
    readonly property var _dodgeWatchActiveByOutput: (true) ? Kwin.activeByOutput : null
    readonly property bool dodging: {
        void _dodgeWatchWindowList;
        void _dodgeWatchActiveWindow;
        void _dodgeWatchActiveId;
        void _dodgeWatchActiveByOutput;
        return dodgeEnabled && Kwin.hasWindowOverlapping(screen.name, dodgeRect.x, dodgeRect.y, dodgeRect.width, dodgeRect.height, Config.dockPanel.dodgeFocusedOnly);
    }

    readonly property bool keptOpen: (Config.dockPanel.persistent || dodgeEnabled) && !dodging
    readonly property int exclusiveZone: Config.dockPanel.reserveSpace && !disabled && !dodgeEnabled && (Config.dockPanel.persistent || visibilities.dockPanel) ? (contentThickness + islandMargin) : (isIsland ? 0 : Config.border.thickness)
    readonly property int visualThickness: !disabled && (Config.dockPanel.persistent || visibilities.dockPanel || shouldBeVisible || root.visible) ? (contentThickness + islandMargin) : (isIsland ? 0 : Config.border.thickness)
    readonly property bool popoutActiveOnDock: Boolean(popouts && (popouts.hasCurrent || popouts.offsetScale < 0.99) && (popouts.sourcePanel === "dockPanel" || (popouts.sourcePanel === "" && popouts.isDockPanelPopout)))
    readonly property int magReach: 0
    readonly property bool shouldBeVisible: !fullscreen && !disabled && !visibilities.overview && (keptOpen || visibilities.dockPanel || hovered || popoutActiveOnDock || (hasLauncher && visibilities.launcher))
    property bool pointerInReach: false
    property bool revealActive: false
    readonly property bool hovered: revealActive || dockHoverTracker.hovered
    readonly property bool isLauncherHovered: {
        if (!root.hasLauncher || !dockHoverTracker.hovered)
            return false;
        const p = hoverArea.mapToItem(launcherButton, dockHoverTracker.point.position.x, dockHoverTracker.point.position.y);
        const margin = root.spacing / 2;
        return p.x >= -margin && p.x <= launcherButton.width + margin
            && p.y >= -margin && p.y <= launcherButton.height + margin;
    }
    readonly property int fullLength: (isHorizontal ? screen.width : screen.height) - (isIsland ? Config.dockPanel.floatingMargin * 2 : 0)
    readonly property int defaultLength: Math.min(fullLength, Math.max(root.itemSize + root.padding * 2, Math.round(computedContentSpan + root.padding * 2)))
    readonly property int fixedLength: Math.round(fullLength * Math.max(5, Math.min(100, Config.dockPanel.length)) / 100)
    readonly property int clampedLength: Config.dockPanel.fixedLength ? fixedLength : defaultLength
    readonly property int clampedThickness: Math.max(Config.border.minThickness, isHorizontal ? implicitHeight : implicitWidth)
    readonly property int clampedWidth: isHorizontal ? clampedLength : clampedThickness
    readonly property int clampedHeight: isHorizontal ? clampedThickness : clampedLength

    function publishMinimizeGeometry(): void {
        const win = QsWindow.window;
        if (!win || listView.width <= 0 || listView.height <= 0)
            return;

        const origin = listView.mapToItem(null, 0, 0);
        DockManager.publishMinimizeGeometries(
            root,
            win,
            root.isHorizontal,
            origin.x,
            origin.y,
            root.itemSize,
            root.spacing,
            root.isHorizontal ? listView.width : listView.height,
            root.isHorizontal ? listView.contentX : listView.contentY,
            root.position
        );
    }

    function scrollByWheel(angleDelta: point, pixelDelta: point): void {
        if (DockManager.isDragging) return;

        const isH = root.isHorizontal;
        const fullSpan = Math.max(isH ? listView.contentWidth : listView.contentHeight, root.computedContentSpan);
        const viewSpan = isH ? listView.width : listView.height;
        const maxScroll = Math.max(0, fullSpan - viewSpan);
        if (maxScroll <= 0) return;

        const rawDelta = isH
            ? (Math.abs(angleDelta.x) > Math.abs(angleDelta.y) ? angleDelta.x : angleDelta.y)
            : (Math.abs(angleDelta.y) > Math.abs(angleDelta.x) ? angleDelta.y : angleDelta.x);

        const rawPixel = isH
            ? (Math.abs(pixelDelta.x) > Math.abs(pixelDelta.y) ? pixelDelta.x : pixelDelta.y)
            : (Math.abs(pixelDelta.y) > Math.abs(pixelDelta.x) ? pixelDelta.y : pixelDelta.x);

        if (rawPixel !== 0) {
            scrollAnim.stop();
            const current = isH ? listView.contentX : listView.contentY;
            const target = Math.max(0, Math.min(maxScroll, current - rawPixel));
            if (isH) listView.contentX = target;
            else listView.contentY = target;
            root.publishMinimizeGeometry();
            return;
        }

        if (rawDelta === 0) return;

        const step = root.itemSize + root.spacing;
        const scrollAmount = -(rawDelta / 120) * step;

        const current = scrollAnim.running ? scrollAnim.to : (isH ? listView.contentX : listView.contentY);
        const target = Math.max(0, Math.min(maxScroll, current + scrollAmount));

        scrollAnim.stop();
        scrollAnim.from = isH ? listView.contentX : listView.contentY;
        scrollAnim.to = target;
        scrollAnim.start();
    }

    function clampScroll(): void {
        const isH = root.isHorizontal;
        const fullSpan = Math.max(isH ? listView.contentWidth : listView.contentHeight, root.computedContentSpan);
        const viewSpan = isH ? listView.width : listView.height;
        const maxScroll = Math.max(0, fullSpan - viewSpan);
        if (isH) {
            if (listView.contentX > maxScroll)
                listView.contentX = maxScroll;
        } else {
            if (listView.contentY > maxScroll)
                listView.contentY = maxScroll;
        }
    }

    onPointerInReachChanged: {
        if (pointerInReach) {
            unhoverTimer.stop();
            if (Config.dockPanel.autoHideDelay > 0 && !hovered)
                revealDelayTimer.restart();
            else
                revealActive = true;
        } else {
            revealDelayTimer.stop();
            if (revealActive && !dockHoverTracker.hovered)
                unhoverTimer.restart();
        }
    }

    onIsLauncherHoveredChanged: {
        if (isLauncherHovered && root.popouts && root.popouts.hasCurrent && root.popouts.currentName === "dockhover")
            root.popouts.hasCurrent = false;
    }

    width: clampedWidth
    height: clampedHeight
    clip: false
    visible: !visibilities.overview && (isHorizontal ? height > Math.max(Config.border.thickness, Config.border.minThickness) : width > Math.max(Config.border.thickness, Config.border.minThickness))
    implicitWidth: isHorizontal ? 0 : (fullscreen ? 0 : Config.border.thickness)
    implicitHeight: isHorizontal ? (fullscreen ? 0 : Config.border.thickness) : 0

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            target: root
            implicitWidth: root.isHorizontal ? 0 : root.contentThickness
            implicitHeight: root.isHorizontal ? root.contentThickness : 0
        }
    }
    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: root.isHorizontal ? "implicitHeight" : "implicitWidth"
                type: Anim.DefaultSpatial
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: root.isHorizontal ? "implicitHeight" : "implicitWidth"
                type: Anim.Emphasized
            }
        }
    ]


    Item {
        id: content

        anchors.fill: parent

        Item {
            id: container

            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                enabled: DockManager.count > 0

                onClicked: mouse => {
                    if (!root.popouts)
                        return;
                    root.popouts.sourcePanel = "dockPanel";
                    root.popouts.currentName = "dockbgcontext";
                    root.popouts.currentCenter = root.isHorizontal
                        ? container.mapToItem(null, mouse.x, 0).x
                        : (container.mapToItem(null, 0, mouse.y).y ?? 0);
                    root.popouts.hasCurrent = true;
                    mouse.accepted = true;
                }
            }

            Item {
                id: hoverArea

                z: 1000
                anchors.fill: parent

                HoverHandler {
                    id: dockHoverTracker
                }
            }

            Item {
                id: innerArea

                anchors.fill: parent
                anchors.margins: root.padding

                Item {
                    id: launcherButton

                    visible: root.hasLauncher
                    width: root.itemSize
                    height: root.itemSize
                    anchors {
                        left: root.isHorizontal ? parent.left : undefined
                        top: !root.isHorizontal ? parent.top : undefined
                        verticalCenter: root.isHorizontal ? parent.verticalCenter : undefined
                        horizontalCenter: !root.isHorizontal ? parent.horizontalCenter : undefined
                    }

                    StateLayer {
                        id: launcherState

                        anchors.fill: parent
                        radius: Tokens.rounding.medium
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onEntered: {
                            if (root.popouts && root.popouts.hasCurrent && root.popouts.currentName === "dockhover")
                                root.popouts.hasCurrent = false;
                        }

                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                if (!root.popouts)
                                    return;
                                if (root.popouts.hasCurrent && root.popouts.currentName === "osiconcontext") {
                                    root.popouts.hasCurrent = false;
                                } else {
                                    root.popouts.sourcePanel = "dockPanel";
                                    root.popouts.currentName = "osiconcontext";
                                    root.popouts.currentCenter = root.isHorizontal
                                        ? launcherButton.mapToItem(null, launcherButton.width / 2, 0).x
                                        : (launcherButton.mapToItem(null, 0, launcherButton.height / 2).y ?? 0);
                                    root.popouts.hasCurrent = true;
                                }
                                return;
                            }
                            Visibilities.toggleLauncher("");
                        }
                    }

                    Loader {
                        anchors.centerIn: parent
                        sourceComponent: {
                            if (SysInfo.isDefaultLogo) {
                                return caelestiaLogo;
                            } else if (GlobalConfig.general.logo && GlobalConfig.general.logo !== "caelestia") {
                                return customIcon;
                            } else {
                                return distroIcon;
                            }
                        }
                    }

                    Component {
                        id: caelestiaLogo

                        Logo {
                            width: root.iconSize
                            height: root.iconSize
                        }
                    }

                    Component {
                        id: distroIcon

                        ColouredIcon {
                            source: SysInfo.osLogo
                            implicitSize: root.iconSize
                            colour: Colours.palette.m3tertiary
                        }
                    }

                    Component {
                        id: customIcon

                        Loader {
                            sourceComponent: SysInfo.recolourCustomLogo ? colouredIconComponent : iconImageComponent
                        }
                    }

                    Component {
                        id: colouredIconComponent

                        ColouredIcon {
                            source: SysInfo.osLogo
                            implicitSize: Math.round(root.iconSize * (SysInfo.customLogoSize / 100))
                            colour: Colours.palette.m3tertiary
                        }
                    }

                    Component {
                        id: iconImageComponent

                        IconImage {
                            source: SysInfo.osLogo
                            implicitWidth: Math.round(root.iconSize * (SysInfo.customLogoSize / 100))
                            implicitHeight: Math.round(root.iconSize * (SysInfo.customLogoSize / 100))
                        }
                    }
                }

                WheelHandler {
                    id: wheelHandler

                    target: null
                    orientation: Qt.Vertical | Qt.Horizontal

                    onWheel: event => {
                        root.scrollByWheel(event.angleDelta, event.pixelDelta);
                    }
                }

                NumberAnimation {
                    id: scrollAnim

                    target: listView
                    property: root.isHorizontal ? "contentX" : "contentY"
                    duration: Tokens.anim.durations.expressiveFastSpatial
                    easing: Tokens.anim.expressiveFastSpatial

                    onRunningChanged: {
                        if (!running) {
                            root.publishMinimizeGeometry();
                        }
                    }
                }

                ListView {
                    id: listView

                    anchors {
                        left: (root.isHorizontal && launcherButton.visible) ? launcherButton.right : parent.left
                        leftMargin: (root.isHorizontal && launcherButton.visible) ? root.spacing : 0
                        top: (!root.isHorizontal && launcherButton.visible) ? launcherButton.bottom : parent.top
                        topMargin: (!root.isHorizontal && launcherButton.visible) ? root.spacing : 0
                        right: parent.right
                        bottom: parent.bottom
                    }
                    orientation: root.isHorizontal ? ListView.Horizontal : ListView.Vertical
                    spacing: root.spacing
                    interactive: root.isHorizontal ? contentWidth > width + 1 : contentHeight > height + 1
                    clip: false

                    onContentWidthChanged: root.clampScroll()
                    onWidthChanged: root.clampScroll()
                    onContentHeightChanged: root.clampScroll()
                    onHeightChanged: root.clampScroll()

                    add: Transition {
                        Anim {
                            property: "scale"
                            from: 0.9
                            to: 1
                            type: Anim.FastSpatial
                        }
                    }
                    remove: Transition {
                        Anim {
                            property: "scale"
                            from: 1
                            to: 0.9
                            type: Anim.FastEffects
                        }
                    }
                    move: Transition {
                        Anim {
                            properties: "x,y"
                            type: Anim.FastSpatial
                        }
                    }
                    moveDisplaced: Transition {
                        Anim {
                            properties: "x,y"
                            type: Anim.FastSpatial
                        }
                    }

                    model: DelegateModel {
                        id: visualModel

                        model: DockManager.listModel
                        delegate: dockDelegate
                    }
                }

                StyledScrollBar {
                    flickable: listView
                    orientation: Qt.Horizontal
                    size: listView.visibleArea.widthRatio
                    position: listView.visibleArea.xPosition
                    shouldBeActive: dockHoverTracker.hovered || listView.moving || scrollAnim.running
                    anchors.left: listView.left
                    anchors.right: listView.right
                    anchors.bottom: listView.bottom
                    anchors.bottomMargin: -2
                    visible: root.isHorizontal && listView.contentWidth > listView.width + 1
                }

                StyledScrollBar {
                    flickable: listView
                    orientation: Qt.Vertical
                    size: listView.visibleArea.heightRatio
                    position: listView.visibleArea.yPosition
                    shouldBeActive: dockHoverTracker.hovered || listView.moving || scrollAnim.running
                    anchors.top: listView.top
                    anchors.bottom: listView.bottom
                    anchors.right: listView.right
                    anchors.rightMargin: -2
                    visible: !root.isHorizontal && listView.contentHeight > listView.height + 1
                }
            }
        }
    }

    Component {
        id: dockDelegate

        DockItem {
            id: itemDelegate

            itemSize: root.itemSize
            iconSize: root.iconSize
            recolourIcons: Config.dockPanel.recolourIcons
            showBadges: Config.dockPanel.showBadges
            activeIndicators: Config.dockPanel.activeIndicators
            indicatorStyle: Config.dockPanel.indicatorStyle
            position: root.position
            isHorizontal: root.isHorizontal
            sourcePanel: "dockPanel"
            popouts: root.popouts
            listView: listView
            labelMode: Config.dockPanel.labelMode
            fixedLabelWidth: Config.dockPanel.fixedLabelWidth
            labelWidth: Config.dockPanel.labelWidth
            maxLabelWidth: Config.dockPanel.maxLabelWidth
            labelSize: Config.dockPanel.labelSize
            isHovered: {
                if (!dockHoverTracker.hovered)
                    return false;
                const p = hoverArea.mapToItem(container, dockHoverTracker.point.position.x, dockHoverTracker.point.position.y);
                const crossPos = root.isHorizontal ? p.y : p.x;
                const crossMax = root.isHorizontal ? container.height : container.width;
                if (crossPos < 0 || crossPos > crossMax)
                    return false;
                const cursorPos = root.isHorizontal ? p.x : p.y;
                const origin = itemDelegate.mapToItem(container, 0, 0);
                const itemStart = root.isHorizontal ? origin.x : origin.y;
                const itemSpan = root.isHorizontal ? itemDelegate.width : itemDelegate.height;
                const halfGap = root.spacing / 2;
                return cursorPos >= (itemStart - halfGap) && cursorPos < (itemStart + itemSpan + halfGap);
            }
            magnificationScale: {
                if (!Config.dockPanel.magnification || !dockHoverTracker.hovered)
                    return 1.0;
                const p = hoverArea.mapToItem(container, dockHoverTracker.point.position.x, dockHoverTracker.point.position.y);
                const crossPos = root.isHorizontal ? p.y : p.x;
                const crossMax = root.isHorizontal ? container.height : container.width;
                if (crossPos < 0 || crossPos > crossMax)
                    return 1.0;
                const cursorPos = root.isHorizontal ? p.x : p.y;
                const origin = itemDelegate.mapToItem(container, 0, 0);
                const itemStart = root.isHorizontal ? origin.x : origin.y;
                const itemSpan = root.isHorizontal ? itemDelegate.width : itemDelegate.height;
                const itemEnd = itemStart + itemSpan;
                let dist = 0;
                if (cursorPos < itemStart)
                    dist = itemStart - cursorPos;
                else if (cursorPos > itemEnd)
                    dist = cursorPos - itemEnd;
                else
                    dist = 0;

                const reach = (root.itemSize + root.spacing) * 2.2;
                if (dist >= reach) return 1.0;
                const factor = (1.0 + Math.cos((dist / reach) * Math.PI)) / 2.0;
                return 1.0 + (Config.dockPanel.maxMagnification - 1.0) * factor;
            }
        }
    }

    Timer {
        id: revealDelayTimer

        interval: Math.max(0, Config.dockPanel.autoHideDelay)
        onTriggered: root.revealActive = true
    }

    Timer {
        id: unhoverTimer

        interval: 400
        onTriggered: {
            if (!root.pointerInReach && !dockHoverTracker.hovered)
                root.revealActive = false;
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: root.visible && DockManager.count > 0
        onTriggered: root.publishMinimizeGeometry()
    }

    Connections {
        function onHoveredChanged(): void {
            if (dockHoverTracker.hovered) {
                unhoverTimer.stop();
            } else if (!root.pointerInReach && root.revealActive) {
                unhoverTimer.restart();
            }
        }

        target: dockHoverTracker
    }

    Connections {
        function onShowOnHoverChanged(): void {
            if (!Config.dockPanel.showOnHover) {
                revealDelayTimer.stop();
                root.revealActive = false;
            }
        }

        target: Config.dockPanel
    }
}
