pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property int index
    required property string appId
    property var modelData: DockManager.modelDataMap[appId] || DockManager.modelDataArray[index]

    property real itemSize: 48
    property real iconSize: 32
    property bool recolourIcons: false
    property bool showBadges: true
    property bool activeIndicators: true
    property string indicatorStyle: "pill"
    readonly property real indicatorThickness: Math.max(2, Math.round(root.iconSize * 0.08 * root.currentScale))
    property string position: "bottom"
    property bool isHorizontal: root.position === "top" || root.position === "bottom"
    property real magnificationScale: 1.0
    property bool isHovered: false
    property string sourcePanel: "dockPanel"
    property var popouts: null
    property var listView: null

    property string launchingStyle: Config.dockPanel.launchingStyle ?? "circle"
    readonly property bool isLaunching: root.modelData ? Boolean(DockManager.launchingApps[root.modelData.appClass || root.modelData.id]) : false

    property string labelMode: root.sourcePanel === "dockPanel" ? Config.dockPanel.labelMode : "none"
    property bool fixedLabelWidth: root.sourcePanel === "dockPanel" ? Config.dockPanel.fixedLabelWidth : false
    property int labelWidth: root.sourcePanel === "dockPanel" ? Config.dockPanel.labelWidth : 0
    property int maxLabelWidth: root.sourcePanel === "dockPanel" ? Config.dockPanel.maxLabelWidth : 0
    property int labelSize: root.sourcePanel === "dockPanel" ? Config.dockPanel.labelSize : 12

    readonly property string labelText: {
        if (!root.modelData || root.labelMode === "none")
            return "";
        if (root.labelMode === "title") {
            const tops = root.modelData.toplevels ?? [];
            if (tops.length > 0) {
                for (let i = 0; i < tops.length; i++) {
                    if (tops[i].focused && tops[i].title)
                        return tops[i].title;
                }
                if (tops[0] && tops[0].title)
                    return tops[0].title;
            }
            return root.modelData.entry?.name || root.modelData.appClass || "";
        }
        if (root.labelMode === "name") {
            return root.modelData.entry?.name || root.modelData.appClass || "";
        }
        return "";
    }
    readonly property bool hasLabel: root.labelText.length > 0
    readonly property real calculatedLabelWidth: {
        if (!root.hasLabel)
            return 0;
        if (root.fixedLabelWidth)
            return Math.max(20, root.labelWidth);
        return Math.min(Math.max(20, root.maxLabelWidth), Math.ceil(labelMetrics.width));
    }

    readonly property real baseWidth: (root.isHorizontal && root.hasLabel)
        ? (root.itemSize + Tokens.spacing.small + root.calculatedLabelWidth + Tokens.padding.small)
        : root.itemSize
    readonly property real baseHeight: root.itemSize
    property real currentScale: root.magnificationScale

    signal activateRequested()

    // Both the item's own hover state and the state layer's enter report the
    // pointer arriving, so the decision to open the preview lives in one place.
    function openDockHover(): void {
        if (!root.popouts || root.popouts.hoverSuppressed)
            return;
        if (root.popouts.hasCurrent && root.popouts.currentName === "dockcontext")
            return;
        root.popouts.sourcePanel = root.sourcePanel;
        root.popouts.currentName = "dockhover";
        root.popouts.currentCenter = root.isHorizontal
            ? delegateItem.mapToItem(null, delegateItem.width / 2, 0).x
            : (delegateItem.mapToItem(null, 0, delegateItem.height / 2).y ?? 0);
        root.popouts.dockModel = root.modelData;
        root.popouts.hasCurrent = true;
    }

    onIsHoveredChanged: {
        if (root.isHovered)
            root.openDockHover();
    }

    width: root.isHorizontal ? Math.round(root.baseWidth * root.currentScale) : root.baseWidth
    height: !root.isHorizontal ? Math.round(root.baseHeight * root.currentScale) : root.baseHeight
    implicitWidth: root.width
    implicitHeight: root.height
    z: dragArea.held ? 999 : Math.round(root.currentScale * 100)

    states: [
        State {
            name: "bottom"
            when: root.position === "bottom"

            AnchorChanges {
                target: delegateItem
                anchors.top: undefined
                anchors.bottom: root.bottom
                anchors.left: undefined
                anchors.right: undefined
                anchors.horizontalCenter: root.horizontalCenter
                anchors.verticalCenter: undefined
            }

            AnchorChanges {
                target: indicatorContainer
                anchors.top: undefined
                anchors.bottom: delegateItem.bottom
                anchors.left: undefined
                anchors.right: undefined
                anchors.horizontalCenter: iconContainer.horizontalCenter
                anchors.verticalCenter: undefined
            }
        },
        State {
            name: "top"
            when: root.position === "top"

            AnchorChanges {
                target: delegateItem
                anchors.top: root.top
                anchors.bottom: undefined
                anchors.left: undefined
                anchors.right: undefined
                anchors.horizontalCenter: root.horizontalCenter
                anchors.verticalCenter: undefined
            }

            AnchorChanges {
                target: indicatorContainer
                anchors.top: delegateItem.top
                anchors.bottom: undefined
                anchors.left: undefined
                anchors.right: undefined
                anchors.horizontalCenter: iconContainer.horizontalCenter
                anchors.verticalCenter: undefined
            }
        },
        State {
            name: "left"
            when: root.position === "left"

            AnchorChanges {
                target: delegateItem
                anchors.top: undefined
                anchors.bottom: undefined
                anchors.left: root.left
                anchors.right: undefined
                anchors.horizontalCenter: undefined
                anchors.verticalCenter: root.verticalCenter
            }

            AnchorChanges {
                target: indicatorContainer
                anchors.top: undefined
                anchors.bottom: undefined
                anchors.left: delegateItem.left
                anchors.right: undefined
                anchors.horizontalCenter: undefined
                anchors.verticalCenter: iconContainer.verticalCenter
            }
        },
        State {
            name: "right"
            when: root.position === "right"

            AnchorChanges {
                target: delegateItem
                anchors.top: undefined
                anchors.bottom: undefined
                anchors.left: undefined
                anchors.right: root.right
                anchors.horizontalCenter: undefined
                anchors.verticalCenter: root.verticalCenter
            }

            AnchorChanges {
                target: indicatorContainer
                anchors.top: undefined
                anchors.bottom: undefined
                anchors.left: undefined
                anchors.right: delegateItem.right
                anchors.horizontalCenter: undefined
                anchors.verticalCenter: iconContainer.verticalCenter
            }
        }
    ]

    Behavior on currentScale {
        Anim {
            type: Anim.FastSpatial
        }
    }

    TextMetrics {
        id: labelMetrics

        font: labelTextItem.font
        text: root.labelText
    }

    DropArea {
        anchors.fill: parent
        anchors.margins: Tokens.padding.small

        onEntered: drag => {
            const from = drag.source.delegateIndex;
            const to = root.index;
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

        property int delegateIndex: root.index

        property bool isActive: {
            if (!root.modelData || !root.modelData.toplevels) return false;
            for (const top of root.modelData.toplevels) {
                if (top.focused || (DockManager.activeTop && DockManager.activeTop.address === top.address)) return true;
            }
            return false;
        }

        property bool hasWindows: (root.modelData?.toplevels?.length ?? 0) > 0

        readonly property var badge: {
            const dummy = LauncherEntry.revision;
            if (!root.modelData || !root.showBadges)
                return null;
            return LauncherEntry.forApp(root.modelData.appClass || root.modelData.id);
        }

        width: root.isHorizontal ? root.width : Math.round(root.baseWidth * root.currentScale)
        height: root.isHorizontal ? Math.round(root.baseHeight * root.currentScale) : root.height

        Drag.active: dragArea.held
        Drag.source: delegateItem
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        states: [
            State {
                when: dragArea.held

                ParentChange {
                    target: delegateItem
                    parent: root.listView || root.parent
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
            id: hoverHighlight

            anchors.fill: parent
            radius: Tokens.rounding.medium
            color: Colours.palette.m3onSurface
            opacity: root.isHovered ? 0.12 : 0

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
            showHoverBackground: false

            onEntered: root.openDockHover()
        }

        MouseArea {
            id: dragArea

            property bool held: false

            anchors.fill: parent
            drag.target: held ? delegateItem : null
            drag.axis: root.isHorizontal ? Drag.XAxis : Drag.YAxis
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onPressed: mouse => {
                held = true;
                DockManager.isDragging = true;
                stateLayer.press(mouse.x, mouse.y);
            }

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    if (root.modelData && root.modelData.isPinned && Tokens.anim.enabled) {
                        bounceAnim.start();
                    }
                    if (root.modelData) {
                        DockManager.activateEntry(root.modelData);
                    }
                    root.activateRequested();
                } else if (mouse.button === Qt.RightButton && root.popouts) {
                    root.popouts.sourcePanel = root.sourcePanel;
                    root.popouts.currentName = "dockcontext";
                    root.popouts.currentCenter = root.isHorizontal
                        ? delegateItem.mapToItem(null, delegateItem.width / 2, 0).x
                        : (delegateItem.mapToItem(null, 0, delegateItem.height / 2).y ?? 0);
                    root.popouts.dockModel = root.modelData;
                    root.popouts.hasCurrent = true;
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

            width: Math.round(root.itemSize * root.currentScale)
            height: Math.round(root.itemSize * root.currentScale)
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            transform: [
                Translate {
                    x: launchIndicator.bounceOffsetX
                    y: launchIndicator.bounceOffsetY
                },
                Scale {
                    origin.x: iconContainer.width / 2
                    origin.y: root.position === "top" ? 0 : iconContainer.height
                    xScale: launchIndicator.bounceScaleX
                    yScale: launchIndicator.bounceScaleY
                }
            ]

            CachingIconImage {
                id: icon

                anchors.centerIn: parent
                implicitSize: Math.round(root.iconSize * root.currentScale)
                width: Math.round(root.iconSize * root.currentScale)
                height: Math.round(root.iconSize * root.currentScale)
                source: root.modelData ? WinIcons.sourceFor(root.modelData.entry, root.modelData.appClass, root.modelData.iconName, root.modelData.pid ?? 0) : ""
                visible: !root.recolourIcons

                SequentialAnimation {
                    id: bounceAnim

                    NumberAnimation {
                        target: delegateItem
                        property: "scale"
                        to: 0.94
                        duration: Tokens.anim.durations.expressiveFastSpatial
                        easing: Tokens.anim.expressiveFastSpatial
                    }
                    NumberAnimation {
                        target: delegateItem
                        property: "scale"
                        to: 1
                        duration: Tokens.anim.durations.expressiveFastSpatial
                        easing: Tokens.anim.expressiveFastSpatial
                    }
                }
            }

            ColouredIcon {
                anchors.centerIn: parent
                implicitSize: Math.round(root.iconSize * root.currentScale)
                width: Math.round(root.iconSize * root.currentScale)
                height: Math.round(root.iconSize * root.currentScale)
                source: visible ? icon.source : ""
                colour: Colours.palette.m3secondary
                layer.enabled: visible
                visible: root.recolourIcons
            }
        }

        Text {
            id: labelTextItem

            visible: root.hasLabel && root.isHorizontal
            anchors.left: iconContainer.right
            anchors.leftMargin: Math.round(Tokens.spacing.small * root.currentScale)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(root.calculatedLabelWidth * root.currentScale)
            text: root.labelText
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: delegateItem.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurface
            font: Tokens.font.label.builders.medium.size(Math.max(6, Math.round(root.labelSize * root.currentScale))).build()
        }

        DockLaunchIndicator {
            id: launchIndicator

            anchors.centerIn: iconContainer
            width: Math.round(root.iconSize * root.currentScale)
            height: Math.round(root.iconSize * root.currentScale)
            isLaunching: root.isLaunching
            style: root.launchingStyle
            position: root.position
            currentScale: root.currentScale
        }

        StyledRect {
            id: countBadge

            readonly property int badgeHeight: Math.max(12, Math.round(root.iconSize * root.currentScale * 0.55))
            readonly property int dotSize: Math.max(6, Math.round(badgeHeight * 0.75))
            readonly property bool asDot: (delegateItem.badge?.count ?? 0) <= 0

            visible: root.showBadges && (delegateItem.badge?.countVisible ?? false)
            color: Colours.palette.m3error
            radius: Tokens.rounding.full
            width: asDot ? dotSize : Math.max(badgeHeight, badgeLabel.implicitWidth + Tokens.padding.extraSmall)
            height: asDot ? dotSize : badgeHeight
            anchors.right: iconContainer.right
            anchors.top: iconContainer.top
            anchors.rightMargin: Math.round((iconContainer.width - root.iconSize * root.currentScale) / 2) - Math.round(height * 0.25)
            anchors.topMargin: Math.round((iconContainer.height - root.iconSize * root.currentScale) / 2) - Math.round(height * 0.25)

            Text {
                id: badgeLabel

                anchors.centerIn: parent
                visible: !countBadge.asDot
                text: {
                    const count = delegateItem.badge?.count ?? 0;
                    if (count > 9999) return "9k+";
                    if (count > 999) return `${Math.floor(count / 1000)}k`;
                    return `${count}`;
                }
                color: Colours.palette.m3onError
                font: Tokens.font.label.builders.small.size(Math.max(6, Math.round(countBadge.badgeHeight * 0.62))).weight(Font.DemiBold).build()
            }
        }

        StyledRect {
            id: progressBar

            visible: root.showBadges && (delegateItem.badge?.progressVisible ?? false)
            anchors.top: iconContainer.bottom
            anchors.topMargin: Math.max(1, Math.round(1 * root.currentScale))
            anchors.horizontalCenter: iconContainer.horizontalCenter
            width: Math.round(root.iconSize * root.currentScale)
            height: Math.max(2, Math.round(3 * root.currentScale))
            radius: Tokens.rounding.full
            color: Qt.alpha(Colours.palette.m3onSurface, 0.15)

            StyledRect {
                width: Math.round(parent.width * (delegateItem.badge?.progress ?? 0))
                height: parent.height
                radius: parent.radius
                color: Colours.palette.m3primary
            }
        }

        Item {
            id: indicatorContainer

            visible: root.activeIndicators && delegateItem.hasWindows
            height: root.isHorizontal ? root.indicatorThickness : undefined
            width: !root.isHorizontal ? root.indicatorThickness : undefined

            ListView {
                id: indicatorList

                anchors.centerIn: parent
                spacing: Math.max(1, Math.round(root.iconSize * 0.05 * root.currentScale))
                orientation: root.isHorizontal ? ListView.Horizontal : ListView.Vertical
                interactive: false
                width: root.isHorizontal ? contentWidth : root.indicatorThickness
                height: root.isHorizontal ? root.indicatorThickness : contentHeight

                model: {
                    const dummy = DockManager.modelUpdateTrigger;
                    if (!root.modelData) return 0;
                    if (root.indicatorStyle === "bar") return 1;
                    return Math.min(3, root.modelData.toplevels.length);
                }

                delegate: Rectangle {
                    required property int index

                    readonly property real barLength: Math.max(4, Math.round(root.iconSize * 0.7 * root.currentScale))
                    readonly property real dotSize: Math.max(2, Math.round(root.iconSize * 0.1 * root.currentScale))
                    readonly property real pillActive: Math.max(4, Math.round(root.iconSize * 0.32 * root.currentScale))
                    readonly property real pillInactive: Math.max(2, Math.round(root.iconSize * 0.12 * root.currentScale))

                    width: {
                        if (root.indicatorStyle === "bar")
                            return root.isHorizontal ? barLength : root.indicatorThickness;
                        if (root.indicatorStyle === "dot")
                            return dotSize;
                        return root.isHorizontal ? ((index === 0 && delegateItem.isActive) ? pillActive : pillInactive) : root.indicatorThickness;
                    }
                    height: {
                        if (root.indicatorStyle === "bar")
                            return root.isHorizontal ? root.indicatorThickness : barLength;
                        if (root.indicatorStyle === "dot")
                            return dotSize;
                        return root.isHorizontal ? root.indicatorThickness : ((index === 0 && delegateItem.isActive) ? pillActive : pillInactive);
                    }
                    radius: root.indicatorStyle === "bar" ? Math.max(1, Math.round(root.indicatorThickness / 2)) : Tokens.rounding.full
                    color: delegateItem.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurface

                    Behavior on width {
                        Anim {
                            type: Anim.DefaultSpatial
                        }
                    }
                    Behavior on height {
                        Anim {
                            type: Anim.DefaultSpatial
                        }
                    }
                    Behavior on color {
                        CAnim {}
                    }
                }
            }
        }
    }
}
