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

            Item {
                id: delegateContainer

                required property int index
                required property string appId
                property var modelData: DockManager.modelDataMap[appId] || DockManager.modelDataArray[index]

                width: container.itemSize
                height: container.itemSize
                implicitWidth: width
                implicitHeight: height

                DropArea {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    onEntered: drag => {
                        const from = drag.source.delegateIndex;
                        const to = delegateContainer.index;
                        if (from !== undefined && to !== undefined && from !== to) {
                            DockManager.moveItem(from, to);
                        }
                    }
                    onDropped: drag => {
                        DockManager.saveNewOrder();
                    }
                }

                Item {
                    id: delegateItem

                    property int delegateIndex: delegateContainer.index

                    property bool isActive: {
                        const dummy = DockManager.modelUpdateTrigger;
                        if (!modelData) return false;
                        for (const top of modelData.toplevels) {
                            if (top.focused || (DockManager.activeTop && DockManager.activeTop.address === top.address)) return true;
                        }
                        return false;
                    }

                    property bool hasWindows: {
                        const dummy = DockManager.modelUpdateTrigger;
                        if (!modelData) return false;
                        return modelData.toplevels.length > 0;
                    }

                    readonly property var badge: {
                        const dummy = LauncherEntry.revision;
                        if (!modelData || !(Config.bar.dock.showBadges ?? true))
                            return null;
                        return LauncherEntry.forApp(modelData.id);
                    }

                    width: delegateContainer.width
                    height: delegateContainer.height

                    Drag.active: dragArea.held
                    Drag.source: delegateItem
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    states: [
                        State {
                            when: dragArea.held

                            ParentChange {
                                target: delegateItem
                                parent: listView
                            }
                            PropertyChanges {
                                target: delegateItem
                                opacity: 0.8
                                z: 999
                            }
                        }
                    ]

                    StyledRect {
                        anchors.fill: parent
                        radius: Tokens.rounding.medium
                        color: Colours.palette.m3onSurface
                        opacity: delegateItem.isActive ? 0.1 : 0

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }
                    }

                    StyledRect {
                        anchors.fill: parent
                        radius: Tokens.rounding.medium
                        color: Colours.palette.m3error
                        opacity: (delegateItem.badge?.urgent ?? false) ? 0.35 : 0

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }
                    }

                    StateLayer {
                        id: stateLayer

                        anchors.fill: parent
                        radius: Tokens.rounding.medium
                        acceptedButtons: Qt.NoButton

                        onEntered: {
                            if (bar.popouts.hasCurrent && bar.popouts.currentName === "dockcontext") return;
                            bar.popouts.sourcePanel = "bar";
                            bar.popouts.currentName = "dockhover";
                            bar.popouts.currentCenter = bar.isHorizontal ? delegateItem.mapToItem(null, delegateItem.width / 2, 0).x : (delegateItem.mapToItem(null, 0, delegateItem.height / 2).y ?? 0);
                            bar.popouts.dockModel = modelData;
                            bar.popouts.hasCurrent = true;
                        }
                    }

                    MouseArea {
                        id: dragArea

                        property bool held: false

                        anchors.fill: parent
                        drag.target: held ? delegateItem : null
                        drag.axis: bar.isHorizontal ? Drag.XAxis : Drag.YAxis
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        onPressed: mouse => {
                            held = true;
                            DockManager.isDragging = true;
                            stateLayer.press(mouse.x, mouse.y);
                        }

                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                if (modelData.isPinned && Tokens.anim.enabled) {
                                    bounceAnim.start();
                                }

                                DockManager.activateEntry(modelData);
                            } else if (mouse.button === Qt.RightButton) {
                                bar.popouts.sourcePanel = "bar";
                                bar.popouts.currentName = "dockcontext";
                                bar.popouts.currentCenter = bar.isHorizontal ? delegateItem.mapToItem(null, delegateItem.width / 2, 0).x : (delegateItem.mapToItem(null, 0, delegateItem.height / 2).y ?? 0);
                                bar.popouts.dockModel = modelData;
                                bar.popouts.hasCurrent = true;
                            }
                        }

                        onReleased: {
                            held = false;
                            DockManager.isDragging = false;
                            delegateItem.x = 0;
                            delegateItem.y = 0;
                            DockManager.saveNewOrder();
                        }

                        onCanceled: {
                            held = false;
                            DockManager.isDragging = false;
                            delegateItem.x = 0;
                            delegateItem.y = 0;
                        }
                    }

                    Item {
                        id: iconContainer

                        anchors.centerIn: parent
                        width: root.iconSize
                        height: root.iconSize
                        transform: [
                            Translate {
                                x: launchIndicator.bounceOffsetX
                                y: launchIndicator.bounceOffsetY
                            },
                            Scale {
                                origin.x: iconContainer.width / 2
                                origin.y: Config.bar.position === "top" ? 0 : iconContainer.height
                                xScale: launchIndicator.bounceScaleX
                                yScale: launchIndicator.bounceScaleY
                            }
                        ]

                        CachingIconImage {
                            id: icon

                            anchors.fill: parent
                            implicitSize: root.iconSize
                            source: modelData ? WinIcons.sourceFor(modelData.entry, modelData.appClass, modelData.iconName, modelData.pid ?? 0) : ""
                            visible: !(Config.bar.dock.recolourIcons ?? false)

                            SequentialAnimation {
                                id: bounceAnim

                                NumberAnimation { target: delegateItem; property: "scale"; to: 0.96; duration: Tokens.anim.durations.expressiveFastSpatial; easing: Tokens.anim.expressiveFastSpatial }
                                NumberAnimation { target: delegateItem; property: "scale"; to: 1; duration: Tokens.anim.durations.expressiveFastSpatial; easing: Tokens.anim.expressiveFastSpatial }
                            }
                        }

                        ColouredIcon {
                            anchors.fill: parent
                            implicitSize: root.iconSize
                            // hidden unless recolouring: skip the second decode and the colour analysis
                            source: visible ? icon.source : ""
                            colour: Colours.palette.m3secondary
                            layer.enabled: visible
                            visible: Config.bar.dock.recolourIcons ?? false
                        }
                    }

                    DockLaunchIndicator {
                        id: launchIndicator

                        anchors.centerIn: iconContainer
                        width: root.iconSize
                        height: root.iconSize
                        isLaunching: modelData ? Boolean(DockManager.launchingApps[modelData.appClass || modelData.id]) : false
                        style: Config.bar.dock.launchingStyle ?? "circle"
                        position: Config.bar.position
                        currentScale: 1.0
                    }

                    StyledRect {
                        id: countBadge

                        readonly property int badgeHeight: Math.max(12, Math.round(root.iconSize * 0.55))
                        readonly property int dotSize: Math.max(6, Math.round(badgeHeight * 0.75))
                        readonly property bool asDot: (delegateItem.badge?.count ?? 0) <= 0

                        visible: delegateItem.badge?.countVisible ?? false
                        color: Colours.palette.m3error
                        radius: Tokens.rounding.full
                        width: asDot ? dotSize : Math.max(badgeHeight, badgeLabel.implicitWidth + Tokens.padding.extraSmall)
                        height: asDot ? dotSize : badgeHeight
                        anchors.right: iconContainer.right
                        anchors.top: iconContainer.top
                        anchors.rightMargin: -Math.round(height * 0.25)
                        anchors.topMargin: -Math.round(height * 0.25)

                        Text {
                            id: badgeLabel

                            anchors.centerIn: parent
                            visible: !countBadge.asDot
                            text: {
                                const count = delegateItem.badge?.count ?? 0;
                                if (count > 9999)
                                    return "9k+";
                                if (count > 999)
                                    return `${Math.floor(count / 1000)}k`;
                                return `${count}`;
                            }
                            color: Colours.palette.m3onError
                            font: Tokens.font.label.builders.small.size(Math.max(6, Math.round(countBadge.badgeHeight * 0.62))).weight(Font.DemiBold).build()
                        }
                    }

                    StyledRect {
                        id: progressBar

                        visible: delegateItem.badge?.progressVisible ?? false
                        anchors.top: iconContainer.bottom
                        anchors.topMargin: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.iconSize
                        height: 3
                        radius: Tokens.rounding.full
                        color: Qt.alpha(Colours.palette.m3onSurface, 0.15)

                        StyledRect {
                            width: Math.round(parent.width * (delegateItem.badge?.progress ?? 0))
                            height: parent.height
                            radius: parent.radius
                            color: Colours.palette.m3primary
                        }
                    }

                    ListView {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 0
                        spacing: 2
                        orientation: ListView.Horizontal
                        interactive: false

                        height: 2
                        width: contentWidth

                        add: Transition {
                            Anim { property: "opacity"; from: 0; to: 1; type: Anim.FastEffects }
                            Anim { property: "scale"; from: 0.9; to: 1; type: Anim.FastSpatial }
                        }
                        remove: Transition {
                            Anim { property: "opacity"; from: 1; to: 0; type: Anim.FastEffects }
                            Anim { property: "y"; from: 0; to: -15; type: Anim.FastEffects }
                        }
                        addDisplaced: Transition {
                            Anim { properties: "x,y"; type: Anim.FastSpatial }
                        }
                        removeDisplaced: Transition {
                            Anim { properties: "x,y"; type: Anim.FastSpatial }
                        }

                        model: {
                            const dummy = DockManager.modelUpdateTrigger;
                            if (!modelData) return 0;
                            return Math.min(2, modelData.toplevels.length);
                        }

                        delegate: Rectangle {
                            required property int index

                            width: (index === 0 && delegateItem.isActive) ? 16 : 2

                                height: 2

                                radius: 1

                                color: delegateItem.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurface

                                Behavior on width { Anim { type: Anim.DefaultSpatial } }
                                Behavior on height { Anim { type: Anim.DefaultSpatial } }
                                Behavior on color { CAnim {} }
                                Behavior on scale { Anim { type: Anim.FastSpatial } }
                                Behavior on y { Anim { type: Anim.FastSpatial } }
                            }
                        }
                }
            }
        }
    }
}
