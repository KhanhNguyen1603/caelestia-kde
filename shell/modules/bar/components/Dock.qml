pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.components.widgets
import qs.services
import qs.utils

Item {
    id: root

    required property var bar

    property real spacing: Tokens.spacing.medium

    property real padding: Tokens.padding.medium

    readonly property real rawScale: !isNaN(Config.bar.scale) ? Config.bar.scale : 1.0
    readonly property real scaleFactor: rawScale < 1.0 ? Math.sqrt(Math.max(0.1, rawScale)) : rawScale
    readonly property int barThickness: Math.round(Tokens.sizes.bar.innerWidth * scaleFactor)
    readonly property int baseThickness: Tokens.sizes.bar.innerWidth
    readonly property int effectiveThickness: rawScale < 1.0 ? baseThickness : barThickness
    readonly property real configuredItemSize: Math.max(16, Math.min(effectiveThickness, Config.bar.dock.iconSize || 32))
    // Icon size of a dock item. Derived from the configured item size rather than the
    // delegate's laid-out width, which is still 0 while the delegate is being created.
    readonly property real iconSize: Math.round(configuredItemSize * 0.7 / 2) * 2

    function publishMinimizeGeometry(): void {
        const win = QsWindow.window;
        if (!win || listView.width <= 0 || listView.height <= 0)
            return;

        const origin = listView.mapToItem(null, 0, 0);
        DockManager.publishMinimizeGeometries(
            root,
            win,
            bar.isHorizontal,
            origin.x,
            origin.y,
            container.itemSize,
            root.spacing,
            bar.isHorizontal ? listView.width : listView.height,
            bar.isHorizontal ? listView.contentX : listView.contentY,
            Config.bar.position
        );
    }

    function handleWheel(angleDelta: point): void {
        scrollByWheel(angleDelta, Qt.point(0, 0));
    }

    function scrollByWheel(angleDelta: point, pixelDelta: point): void {
        if (DockManager.isDragging) return;

        const isH = bar.isHorizontal;
        const fullSpan = Math.max(isH ? listView.contentWidth : listView.contentHeight, container.__computedContentWidth);
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

        const step = container.itemSize + root.spacing;
        const scrollAmount = -(rawDelta / 120) * step;

        const current = scrollAnim.running ? scrollAnim.to : (isH ? listView.contentX : listView.contentY);
        const target = Math.max(0, Math.min(maxScroll, current + scrollAmount));

        scrollAnim.stop();
        scrollAnim.from = isH ? listView.contentX : listView.contentY;
        scrollAnim.to = target;
        scrollAnim.start();
    }

    function clampScroll(): void {
        const isH = bar.isHorizontal;
        const fullSpan = Math.max(isH ? listView.contentWidth : listView.contentHeight, container.__computedContentWidth);
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

    function handleHover(relPos: real, isHorizontal: bool): void {
        if (bar.popouts.hasCurrent && bar.popouts.currentName === "dockcontext") return;

        const itemSize = container.itemSize;
        const itemWidthWithSpacing = itemSize + spacing;
        const adjustedPos = isHorizontal ? relPos - container.x - padding : relPos - container.y - padding;
        const scrolled = isHorizontal ? listView.contentX : listView.contentY;
        const visibleSpan = isHorizontal ? listView.width : listView.height;

        if (adjustedPos < 0 || adjustedPos > visibleSpan) {
            bar.popouts.hasCurrent = false;
            return;
        }

        const index = Math.floor((adjustedPos + scrolled) / itemWidthWithSpacing);

        if (index >= 0 && index < DockManager.modelDataArray.length) {
            bar.popouts.currentName = "dockhover";
            const centerOffset = index * itemWidthWithSpacing + itemSize / 2 - scrolled;
            if (centerOffset < 0 || centerOffset > visibleSpan) {
                bar.popouts.hasCurrent = false;
                return;
            }
            const absoluteCenter = isHorizontal
                ? container.mapToItem(null, padding + centerOffset, 0).x
                : container.mapToItem(null, 0, padding + centerOffset).y;

            bar.popouts.sourcePanel = "bar";
            bar.popouts.currentCenter = absoluteCenter;
            bar.popouts.dockModel = DockManager.modelDataArray[index];
            bar.popouts.hasCurrent = true;
        }
    }

    implicitWidth: bar.isHorizontal ? container.width : container.implicitWidth
    implicitHeight: bar.isHorizontal ? container.implicitHeight : container.height

    Component.onCompleted: {
        if (root.bar && root.bar.screen) {
            DockManager.targetScreen = root.bar.screen.name;
            Visibilities.registerDock(root.bar.screen, root);
        }
    }

    Component.onDestruction: {
        if (root.bar && root.bar.screen)
            Visibilities.unregisterDock(root.bar.screen);
    }

    HoverHandler { id: dockHover }

    Timer {
        interval: 500
        repeat: true
        running: root.visible
        onTriggered: root.publishMinimizeGeometry()
    }

    Connections {
        function onIsHorizontalChanged(): void {
            scrollAnim.stop();
        }

        target: bar
    }

    StyledRect {
        id: container

        property int __itemCount: DockManager.count
        property real itemSize: root.configuredItemSize
        property real __computedContentWidth: __itemCount > 0 ? __itemCount * itemSize + (__itemCount - 1) * root.spacing : 0

        property string currentZone: {
            if (!bar) return "middle";
            if (bar.leftEntries.some(e => e.id === "dock")) return "left";
            if (bar.rightEntries.some(e => e.id === "dock")) return "right";
            return "middle";
        }

        property real availableSize: {
            if (!bar) return 9999;

            const W = bar.isHorizontal ? bar.width : bar.height;
            const spacing = Tokens.spacing.medium;
            const pad = bar.vPadding;

            let otherSize = 0;
            if (root.parent && root.parent.parent) {
                const layout = root.parent.parent;
                for (let i = 0; i < layout.children.length; i++) {
                    const child = layout.children[i];
                    if (child !== root.parent && child.visible) {
                        otherSize += (bar.isHorizontal ? child.implicitWidth : child.implicitHeight) + spacing;
                    }
                }
            }

            let result = 0;
            if (currentZone === "left") {
                const M = bar.middleZoneSize;
                const R = bar.rightZoneSize;
                let maxZone = W - 2*pad;
                if (M > 0) maxZone = W / 2 - M / 2 - spacing - pad;
                else if (R > 0) maxZone = W - R - spacing - 2*pad;

                result = Math.max(0, maxZone - otherSize);
            } else if (currentZone === "right") {
                const L = bar.leftZoneSize;
                const M = bar.middleZoneSize;
                let maxZone = W - 2*pad;
                if (M > 0) maxZone = W / 2 - M / 2 - spacing - pad;
                else if (L > 0) maxZone = W - L - spacing - 2*pad;

                result = Math.max(0, maxZone - otherSize);
            } else {
                const L = bar.leftZoneSize;
                const R = bar.rightZoneSize;
                let maxZone = W - 2*pad;
                if (L > 0) maxZone -= (L + spacing);
                if (R > 0) maxZone -= (R + spacing);

                result = Math.max(0, maxZone - otherSize);
            }

            return result;
        }

        property int maxHorizontalItems: Math.max(0, Math.floor((availableSize - padding * 2 - itemSize * 0.5) / (itemSize + spacing)))
        property real maxHorizontalSize: maxHorizontalItems >= 1 ? ((maxHorizontalItems + 0.5) * itemSize + maxHorizontalItems * spacing + padding * 2) : availableSize
        property int maxVerticalItems: Math.max(0, Math.floor((availableSize - padding * 2 - itemSize * 0.5) / (itemSize + spacing)))
        property real maxVerticalSize: maxVerticalItems >= 1 ? ((maxVerticalItems + 0.5) * itemSize + maxVerticalItems * spacing + padding * 2) : availableSize

        color: DockManager.count > 0 ? Colours.tPalette.m3surfaceContainer : Qt.alpha(Colours.tPalette.m3surfaceContainer, 0)
        radius: Tokens.rounding.full
        implicitWidth: bar.isHorizontal ? (__computedContentWidth + padding * 2) : bar.thickness
        implicitHeight: bar.isHorizontal ? bar.thickness : (__computedContentWidth + padding * 2)
        width: bar.isHorizontal ? Math.min(implicitWidth, maxHorizontalSize) : implicitWidth
        height: !bar.isHorizontal ? Math.min(implicitHeight, maxVerticalSize) : implicitHeight

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            enabled: DockManager.count > 0

            onClicked: mouse => {
                const popouts = root.bar?.popouts;
                if (!popouts)
                    return;
                popouts.sourcePanel = "bar";
                popouts.currentName = "dockbgcontext";
                popouts.currentCenter = bar.isHorizontal ? container.mapToItem(null, container.width / 2, 0).x : (container.mapToItem(null, 0, container.height / 2).y ?? 0);
                popouts.hasCurrent = true;
                mouse.accepted = true;
            }
        }

        Item {
            id: layout

            anchors.fill: parent

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
                property: bar.isHorizontal ? "contentX" : "contentY"
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

                anchors.centerIn: parent
                width: bar.isHorizontal ? (container.width - padding * 2) : container.itemSize
                height: bar.isHorizontal ? container.itemSize : (container.height - padding * 2)
                orientation: bar.isHorizontal ? ListView.Horizontal : ListView.Vertical
                spacing: root.spacing
                interactive: bar.isHorizontal ? contentWidth > width + 1 : contentHeight > height + 1
                clip: true

                onContentWidthChanged: root.clampScroll()
                onWidthChanged: root.clampScroll()
                onContentHeightChanged: root.clampScroll()
                onHeightChanged: root.clampScroll()

                add: Transition {
                    Anim { property: "scale"; from: 0.9; to: 1; type: Anim.FastSpatial }
                }
                remove: Transition {
                    Anim { property: "scale"; from: 1; to: 0.9; type: Anim.FastEffects }
                }

                move: Transition {
                    Anim { properties: "x,y"; type: Anim.FastSpatial }
                }
                moveDisplaced: Transition {
                    Anim { properties: "x,y"; type: Anim.FastSpatial }
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
                shouldBeActive: dockHover.hovered || listView.moving || scrollAnim.running
                anchors.left: listView.left
                anchors.right: listView.right
                anchors.bottom: listView.bottom
                anchors.bottomMargin: -root.padding + 2
                visible: bar.isHorizontal && listView.contentWidth > listView.width + 1
            }

            StyledScrollBar {
                flickable: listView
                orientation: Qt.Vertical
                size: listView.visibleArea.heightRatio
                position: listView.visibleArea.yPosition
                shouldBeActive: dockHover.hovered || listView.moving || scrollAnim.running
                anchors.top: listView.top
                anchors.bottom: listView.bottom
                anchors.right: listView.right
                anchors.rightMargin: -root.padding + 2
                visible: !bar.isHorizontal && listView.contentHeight > listView.height + 1
            }
        }

        Component {
            id: dockDelegate

            DockItem {
                id: itemDelegate

                itemSize: container.itemSize
                iconSize: root.iconSize
                recolourIcons: Config.bar.dock.recolourIcons
                showBadges: Config.bar.dock.showBadges
                launchingStyle: Config.bar.dock.launchingStyle ?? "circle"
                position: Config.bar.position
                isHorizontal: bar.isHorizontal
                sourcePanel: "bar"
                popouts: bar.popouts
                listView: listView
                isHovered: {
                    if (!dockHover.hovered)
                        return false;
                    const p = root.mapToItem(container, dockHover.point.position.x, dockHover.point.position.y);
                    const cursorPos = bar.isHorizontal ? p.x : p.y;
                    const origin = itemDelegate.mapToItem(container, 0, 0);
                    const itemStart = bar.isHorizontal ? origin.x : origin.y;
                    const itemSpan = bar.isHorizontal ? itemDelegate.width : itemDelegate.height;
                    const halfGap = root.spacing / 2;
                    return cursorPos >= (itemStart - halfGap) && cursorPos < (itemStart + itemSpan + halfGap);
                }
                magnificationScale: 1.0
            }
        }
    }
}
