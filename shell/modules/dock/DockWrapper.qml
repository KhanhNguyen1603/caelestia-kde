pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property ShellScreen screen
    Config.screen: screen.name
    required property DrawerVisibilities visibilities
    required property bool fullscreen
    readonly property bool disabled: !Config.dockPanel.enabled || Strings.testRegexList(Config.dockPanel.excludedScreens, screen.name)
    readonly property string position: Config.dockPanel.position
    readonly property int padding: Math.max(Tokens.padding.small, Config.border.thickness)
    readonly property int contentWidth: Math.max(Config.dockPanel.size, Tokens.sizes.bar.innerWidth) + padding * 2
    readonly property bool dodgeEnabled: Config.dockPanel.dodgeWindows && !Config.dockPanel.persistent && !disabled
    readonly property rect dodgeRect: {
        const ox = screen.x ?? 0;
        const oy = screen.y ?? 0;
        if (position === "top")
            return Qt.rect(ox, oy, screen.width, contentWidth);
        if (position === "bottom")
            return Qt.rect(ox, oy + screen.height - contentWidth, screen.width, contentWidth);
        if (position === "left")
            return Qt.rect(ox, oy, contentWidth, screen.height);
        return Qt.rect(ox + screen.width - contentWidth, oy, contentWidth, screen.height);
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
    readonly property int exclusiveZone: Config.dockPanel.reserveSpace && !disabled && !dodgeEnabled && (Config.dockPanel.persistent || visibilities.dockPanel) ? contentWidth : Config.border.thickness
    readonly property int visualThickness: !disabled && (Config.dockPanel.persistent || visibilities.dockPanel) ? contentWidth : Config.border.thickness
    readonly property bool shouldBeVisible: !fullscreen && !disabled && !visibilities.overview && (keptOpen || visibilities.dockPanel || hovered)
    property bool pointerInReach: false
    property bool revealActive: false
    readonly property bool hovered: revealActive || dockHover.hovered
    readonly property bool isHorizontal: root.position === "top" || root.position === "bottom"
    readonly property int defaultLength: Math.min(isHorizontal ? screen.width - 40 : screen.height - 40, Math.max(200, content.childrenRect.width > 0 ? content.childrenRect.width + padding * 2 : 400))
    readonly property int clampedLength: defaultLength
    readonly property int clampedThickness: Math.max(Config.border.minThickness, isHorizontal ? implicitHeight : implicitWidth)
    readonly property int clampedWidth: isHorizontal ? clampedLength : clampedThickness
    readonly property int clampedHeight: isHorizontal ? clampedThickness : clampedLength

    onPointerInReachChanged: {
        if (pointerInReach) {
            unhoverTimer.stop();
            if (Config.dockPanel.autoHideDelay > 0 && !hovered)
                revealDelayTimer.restart();
            else
                revealActive = true;
        } else {
            revealDelayTimer.stop();
            if (revealActive && !dockHover.hovered)
                unhoverTimer.restart();
        }
    }

    width: clampedWidth
    height: clampedHeight
    clip: true
    visible: isHorizontal ? height > Config.border.thickness : width > Config.border.thickness
    implicitWidth: isHorizontal ? 0 : (fullscreen ? 0 : Config.border.thickness)
    implicitHeight: isHorizontal ? (fullscreen ? 0 : Config.border.thickness) : 0

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            target: root
            implicitWidth: root.isHorizontal ? 0 : root.contentWidth
            implicitHeight: root.isHorizontal ? root.contentWidth : 0
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
            if (!root.pointerInReach && !dockHover.hovered)
                root.revealActive = false;
        }
    }

    HoverHandler {
        id: dockHover

        onHoveredChanged: {
            if (hovered) {
                unhoverTimer.stop();
            } else if (!root.pointerInReach && root.revealActive) {
                unhoverTimer.restart();
            }
        }
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
