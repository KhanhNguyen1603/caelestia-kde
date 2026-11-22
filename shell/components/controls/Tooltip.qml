import QtQuick
import QtQuick.Controls
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services

Popup {
    id: root

    required property Item target
    required property string text
    property int delay: 500
    property int timeout: 0

    // A tooltip is a hint, not a paragraph: cap the content and wrap, so a long string
    // cannot draw itself off the edge of whatever it was anchored to. The floor keeps the
    // width inside the parent, which is what lets updatePosition clamp in one step.
    readonly property real _maxContentWidth: {
        const available = (root.parent ? root.parent.width : root.width) - Tokens.padding.medium * 4;
        return Math.max(Tokens.padding.medium, Math.min(available, 360));
    }

    property bool tooltipVisible: false
    property Timer showTimer: Timer {
        interval: root.delay
        onTriggered: root.tooltipVisible = true
    }
    property Timer hideTimer: Timer {
        interval: root.timeout
        onTriggered: root.tooltipVisible = false
    }

    function updatePosition() {
        if (!target || !parent)
            return;

        Qt.callLater(() => {
            if (!target || !parent || !tooltipRect)
                return;

            const targetPos = target.mapToItem(parent, 0, 0);
            const targetCenterX = targetPos.x + target.width / 2;

            // Get tooltip size (use width/height if available, otherwise implicit)
            const tooltipWidth = tooltipRect.width > 0 ? tooltipRect.width : tooltipRect.implicitWidth;
            const tooltipHeight = tooltipRect.height > 0 ? tooltipRect.height : tooltipRect.implicitHeight;

            let newX = targetCenterX - tooltipWidth / 2;

            let newY = targetPos.y - tooltipHeight - Tokens.spacing.small;

            const padding = Tokens.padding.medium;
            newX = CUtils.clamp(newX, padding, parent.width - tooltipWidth - padding);
            // Above the target by default; below it when there is no room above (a
            // top bar's widgets), so a tooltip never lands off the screen.
            if (newY < padding) {
                newY = CUtils.clamp(targetPos.y + target.height + Tokens.spacing.small, padding, parent.height - tooltipHeight - padding);
            }

            x = newX;
            y = newY;
        });
    }

    parent: {
        if (!target)
            return null;
        if (target.Window && target.Window.contentItem)
            return target.Window.contentItem;
        let p = target;
        while (p && p.parent) {
            const parentItem = p.parent;
            if (parentItem && parentItem.anchors && parentItem.anchors.fill) {
                return parentItem;
            }
            p = parentItem;
        }
        // Fallback
        return target.parent?.parent?.parent ?? target.parent?.parent ?? target.parent ?? target ?? null;
    }

    visible: tooltipVisible
    modal: false
    closePolicy: Popup.NoAutoClose
    padding: 0
    margins: 0
    background: Item {}

    onTooltipVisibleChanged: {
        if (tooltipVisible) {
            Qt.callLater(updatePosition);
        }
    }
    Component.onCompleted: {
        if (tooltipVisible) {
            updatePosition();
        }
    }

    enter: Transition {
        Anim {
            property: "opacity"
            from: 0
            to: 1
            type: Anim.FastEffects
        }
    }

    exit: Transition {
        Anim {
            property: "opacity"
            from: 1
            to: 0
            type: Anim.FastEffects
        }
    }

    contentItem: StyledRect {
        id: tooltipRect

        implicitWidth: Math.min(tooltipMetrics.width, root._maxContentWidth) + Tokens.padding.medium * 2
        implicitHeight: tooltipText.implicitHeight + Tokens.padding.large

        color: Colours.palette.m3surfaceContainerHighest
        radius: Tokens.rounding.medium
        antialiasing: true

        Elevation {
            anchors.fill: parent
            radius: parent.radius
            z: -1
            level: 3
        }

        // Measures the unwrapped string, so the rect can cap the text without the
        // text's own implicitWidth feeding back into the width that caps it.
        TextMetrics {
            id: tooltipMetrics

            font: tooltipText.font
            text: root.text
        }

        StyledText {
            id: tooltipText

            anchors.centerIn: parent

            width: Math.min(tooltipMetrics.width, root._maxContentWidth)
            wrapMode: Text.WordWrap
            text: root.text
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.small
        }
    }

    Connections {
        function onXChanged() {
            if (root.tooltipVisible)
                root.updatePosition();
        }
        function onYChanged() {
            if (root.tooltipVisible)
                root.updatePosition();
        }
        function onWidthChanged() {
            if (root.tooltipVisible)
                root.updatePosition();
        }
        function onHeightChanged() {
            if (root.tooltipVisible)
                root.updatePosition();
        }

        target: root.target
    }

    Connections {
        function onHoveredChanged() {
            if (target.hovered) {
                showTimer.start();
                if (timeout > 0) {
                    hideTimer.stop();
                    hideTimer.start();
                }
            } else {
                showTimer.stop();
                hideTimer.stop();
                tooltipVisible = false;
            }
        }

        target: root.target
    }
}
