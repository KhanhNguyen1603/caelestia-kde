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
    property string position: "bottom"
    property bool isHorizontal: root.position === "top" || root.position === "bottom"
    property real magnificationScale: 1.0
    property string sourcePanel: "dockPanel"
    property var popouts: null
    property var listView: null

    property string labelMode: Config.dockPanel.labelMode
    property bool fixedLabelWidth: Config.dockPanel.fixedLabelWidth
    property int labelWidth: Config.dockPanel.labelWidth
    property int maxLabelWidth: Config.dockPanel.maxLabelWidth
    property int labelSize: Config.dockPanel.labelSize

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

    signal activateRequested()

    width: (root.isHorizontal && root.hasLabel)
        ? (root.itemSize + Tokens.spacing.small + root.calculatedLabelWidth + Tokens.padding.small)
        : root.itemSize
    height: root.itemSize
    implicitWidth: root.width
    implicitHeight: root.height

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
            const dummy = DockManager.modelUpdateTrigger;
            if (!root.modelData) return false;
            for (const top of root.modelData.toplevels) {
                if (top.focused || (DockManager.activeTop && DockManager.activeTop.address === top.address)) return true;
            }
            return false;
        }

        property bool hasWindows: {
            const dummy = DockManager.modelUpdateTrigger;
            if (!root.modelData) return false;
            return root.modelData.toplevels.length > 0;
        }

        readonly property var badge: {
            const dummy = LauncherEntry.revision;
            if (!root.modelData || !root.showBadges)
                return null;
            return LauncherEntry.forApp(root.modelData.id);
        }

        width: root.width
        height: root.height
        scale: root.magnificationScale

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

        Behavior on scale {
            Anim {
                type: Anim.FastSpatial
            }
        }

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
                if (!root.popouts) return;
                if (root.popouts.hasCurrent && root.popouts.currentName === "dockcontext") return;
                root.popouts.sourcePanel = root.sourcePanel;
                root.popouts.currentName = "dockhover";
                root.popouts.currentCenter = root.isHorizontal
                    ? delegateItem.mapToItem(null, delegateItem.width / 2, 0).x
                    : (delegateItem.mapToItem(null, 0, delegateItem.height / 2).y ?? 0);
                root.popouts.dockModel = root.modelData;
                root.popouts.hasCurrent = true;
            }
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

            width: root.itemSize
            height: root.height
            anchors.left: parent.left
            anchors.top: parent.top

            CachingIconImage {
                id: icon

                anchors.centerIn: parent
                implicitSize: root.iconSize
                width: root.iconSize
                height: root.iconSize
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
                implicitSize: root.iconSize
                width: root.iconSize
                height: root.iconSize
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
            anchors.leftMargin: Tokens.spacing.small
            anchors.verticalCenter: parent.verticalCenter
            width: root.calculatedLabelWidth
            text: root.labelText
            elide: Text.ElideRight
            color: delegateItem.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurface
            font: Tokens.font.label.builders.medium.size(Math.max(6, root.labelSize)).build()
        }

        Loader {
            anchors.fill: icon
            active: root.modelData ? (DockManager.launchingApps[root.modelData.appClass || root.modelData.id] || false) : false
            sourceComponent: CircularIndicator {
                running: true
                strokeWidth: 2
            }
        }

        StyledRect {
            id: countBadge

            readonly property int badgeHeight: Math.max(12, Math.round(root.iconSize * 0.55))
            readonly property int dotSize: Math.max(6, Math.round(badgeHeight * 0.75))
            readonly property bool asDot: (delegateItem.badge?.count ?? 0) <= 0

            visible: root.showBadges && (delegateItem.badge?.countVisible ?? false)
            color: Colours.palette.m3error
            radius: Tokens.rounding.full
            width: asDot ? dotSize : Math.max(badgeHeight, badgeLabel.implicitWidth + Tokens.padding.extraSmall)
            height: asDot ? dotSize : badgeHeight
            anchors.right: icon.right
            anchors.top: icon.top
            anchors.rightMargin: -Math.round(height * 0.25)
            anchors.topMargin: -Math.round(height * 0.25)

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
            anchors.top: icon.bottom
            anchors.topMargin: 1
            anchors.horizontalCenter: iconContainer.horizontalCenter
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

        Item {
            id: indicatorContainer

            visible: root.activeIndicators && delegateItem.hasWindows
            anchors {
                bottom: (root.position === "bottom" || root.position === "top") ? (root.position === "top" ? undefined : parent.bottom) : undefined
                top: root.position === "top" ? parent.top : undefined
                left: root.position === "left" ? parent.left : undefined
                right: root.position === "right" ? parent.right : undefined
                horizontalCenter: (root.isHorizontal && !root.hasLabel) ? parent.horizontalCenter : undefined
                verticalCenter: !root.isHorizontal ? parent.verticalCenter : undefined
            }
            x: (root.isHorizontal && root.hasLabel) ? Math.round((root.itemSize - width) / 2) : 0
            height: root.isHorizontal ? 4 : undefined
            width: !root.isHorizontal ? 4 : undefined

            ListView {
                id: indicatorList

                anchors.centerIn: parent
                spacing: 2
                orientation: root.isHorizontal ? ListView.Horizontal : ListView.Vertical
                interactive: false
                width: root.isHorizontal ? contentWidth : 4
                height: root.isHorizontal ? 4 : contentHeight

                model: {
                    const dummy = DockManager.modelUpdateTrigger;
                    if (!root.modelData) return 0;
                    if (root.indicatorStyle === "bar") return 1;
                    return Math.min(3, root.modelData.toplevels.length);
                }

                delegate: Rectangle {
                    required property int index

                    width: {
                        if (root.indicatorStyle === "bar")
                            return root.isHorizontal ? Math.round(root.itemSize * 0.6) : 3;
                        if (root.indicatorStyle === "dot")
                            return 4;
                        return root.isHorizontal ? ((index === 0 && delegateItem.isActive) ? 14 : 5) : 3;
                    }
                    height: {
                        if (root.indicatorStyle === "bar")
                            return root.isHorizontal ? 3 : Math.round(root.itemSize * 0.6);
                        if (root.indicatorStyle === "dot")
                            return 4;
                        return root.isHorizontal ? 3 : ((index === 0 && delegateItem.isActive) ? 14 : 5);
                    }
                    radius: root.indicatorStyle === "bar" ? 1 : Tokens.rounding.full
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
