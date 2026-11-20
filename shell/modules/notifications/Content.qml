pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.effects
import qs.components.widgets
import qs.services

Item {
    id: root

    /// How much room the panels open beside the stack leave it, measured by the window
    /// that owns all of them.
    property real room: Number.POSITIVE_INFINITY
    readonly property int padding: Tokens.padding.large
    readonly property int clampedPadding: CUtils.clamp(padding - Config.border.thickness, 0, padding)

    /// Nothing to show: the stack is not there at all, rather than a strip of padding.
    readonly property bool empty: list.count === 0
    /// The width the screen leaves us. A stack wider than the display is a stack off the
    /// display, so the cards give way on a narrow screen instead of hanging over the edge.
    readonly property real availableWidth: (QsWindow.window as QsWindow)?.screen.width ?? 0

    /// How tall the notifications themselves want to be.
    readonly property real contentHeight: {
        if (root.empty)
            return 0;

        const count = list.count;
        let height = (count - 1) * Tokens.spacing.medium;
        for (let i = 0; i < count; i++)
            height += (list.itemAtIndex(i) as NotifWrapper)?.nonAnimHeight ?? 0;

        return height;
    }

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.left: {
        const pos = GlobalConfig.notifs.position;
        if (pos === "auto")
            return Config.bar.position === "right" ? parent.left : undefined;
        const h = pos.split("-")[1];
        return (h === "left" || h === "center") ? parent.left : undefined;
    }
    anchors.right: {
        const pos = GlobalConfig.notifs.position;
        if (pos === "auto")
            return Config.bar.position !== "right" ? parent.right : undefined;
        const h = pos.split("-")[1];
        return h === "right" ? parent.right : undefined;
    }

    implicitWidth: root.availableWidth > 0 ? Math.min(Tokens.sizes.notifs.width, root.availableWidth - Tokens.padding.extraLarge * 2) : Tokens.sizes.notifs.width
    /// And how tall it may be: the panels beside it only leave so much, and a stack that
    /// does not fit waits rather than drawing half a notification.
    implicitHeight: root.empty ? 0 : Math.min(root.contentHeight + root.padding + root.clampedPadding, root.room)

    ClippingWrapperRectangle {
        anchors.fill: parent
        anchors.margins: root.padding
        anchors.topMargin: root.clampedPadding
        anchors.rightMargin: root.clampedPadding

        color: "transparent"
        radius: Tokens.rounding.large

        StyledListView {
            id: list

            model: ScriptModel {
                values: Notifs.list.filter(n => n.popup && !n.closed).slice(0, Math.max(0, Math.floor(GlobalConfig.notifs.maxPopups)))
            }

            anchors.fill: parent

            orientation: Qt.Vertical
            spacing: 0
            cacheBuffer: (QsWindow.window as QsWindow)?.screen.height ?? 0

            delegate: NotifWrapper {}

            move: Transition {
                Anim {
                    property: "y"
                }
            }

            displaced: Transition {
                Anim {
                    property: "y"
                }
            }

            ExtraIndicator {
                anchors.top: parent.top
                extra: {
                    const count = list.count;
                    if (count === 0)
                        return 0;

                    const scrollY = list.contentY;

                    let height = 0;
                    for (let i = 0; i < count; i++) {
                        height += ((list.itemAtIndex(i) as NotifWrapper)?.nonAnimHeight ?? 0) + Tokens.spacing.medium;

                        if (height - Tokens.spacing.medium >= scrollY)
                            return i;
                    }

                    return count;
                }
            }

            ExtraIndicator {
                anchors.bottom: parent.bottom
                extra: {
                    const count = list.count;
                    if (count === 0)
                        return 0;

                    const scrollY = list.contentHeight - (list.contentY + list.height);

                    let height = 0;
                    for (let i = count - 1; i >= 0; i--) {
                        height += ((list.itemAtIndex(i) as NotifWrapper)?.nonAnimHeight ?? 0) + Tokens.spacing.medium;

                        if (height - Tokens.spacing.medium >= scrollY)
                            return count - i - 1;
                    }

                    return 0;
                }
            }
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }

    component NotifWrapper: Item {
        id: wrapper

        required property NotifData modelData
        required property int index
        readonly property alias nonAnimHeight: notif.nonAnimHeight
        property int idx

        onIndexChanged: {
            if (index !== -1)
                idx = index;
        }

        implicitWidth: notif.implicitWidth
        implicitHeight: notif.implicitHeight + (idx === 0 ? 0 : Tokens.spacing.medium)

        ListView.onRemove: removeAnim.start()

        SequentialAnimation {
            id: removeAnim

            PropertyAction {
                target: wrapper
                property: "ListView.delayRemove"
                value: true
            }
            PropertyAction {
                target: wrapper
                property: "enabled"
                value: false
            }
            PropertyAction {
                target: wrapper
                property: "implicitHeight"
                value: 0
            }
            PropertyAction {
                target: wrapper
                property: "z"
                value: 1
            }
            ParallelAnimation {
                Anim {
                    target: notif
                    property: "x"
                    to: (notif.x >= 0 ? root.implicitWidth : -root.implicitWidth) * 2
                    duration: Tokens.anim.durations.normal
                    easing: Tokens.anim.emphasized
                }
                Anim {
                    target: notif
                    property: "opacity"
                    to: 0
                    duration: Tokens.anim.durations.normal
                }
            }
            PropertyAction {
                target: wrapper
                property: "ListView.delayRemove"
                value: false
            }
        }

        // No cast shadow: the shell's other floating surfaces are flat against the wallpaper, and
        // a RectangularShadow here read as a black border around the card.
        // A plain clip, not a ClippingRectangle: the latter renders its child through a shader
        // to cut a rounded region, and the card already draws its own corners. That extra
        // surface was resampling the whole card, which is what softened every edge.
        Item {
            id: clip

            anchors.top: parent.top
            anchors.topMargin: wrapper.idx === 0 ? 0 : Tokens.spacing.medium
            implicitWidth: notif.implicitWidth
            implicitHeight: notif.implicitHeight
            clip: true

            Notification {
                id: notif

                modelData: wrapper.modelData
                implicitWidth: root.implicitWidth - root.padding - root.clampedPadding
            }
        }
    }

    component Anim: NumberAnimation {
        duration: Tokens.anim.durations.expressiveDefaultSpatial
        easing: Tokens.anim.expressiveDefaultSpatial
    }
}
