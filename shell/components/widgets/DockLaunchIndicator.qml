pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    property bool isLaunching: false
    property string style: "circle"
    property string position: "bottom"
    property real currentScale: 1.0
    property color accentColor: Colours.palette.m3primary

    readonly property real bounceOffsetX: {
        if (!root.isLaunching || root.style !== "bounce") return 0;
        if (root.position === "left") return Math.round(root.bounceVal);
        if (root.position === "right") return -Math.round(root.bounceVal);
        return 0;
    }

    readonly property real bounceOffsetY: {
        if (!root.isLaunching || root.style !== "bounce") return 0;
        if (root.position === "top") return Math.round(root.bounceVal);
        if (root.position === "bottom") return -Math.round(root.bounceVal);
        return 0;
    }

    readonly property real bounceScaleX: (root.isLaunching && root.style === "bounce") ? root.squashX : 1.0
    readonly property real bounceScaleY: (root.isLaunching && root.style === "bounce") ? root.squashY : 1.0

    property real bounceVal: 0
    property real squashX: 1.0
    property real squashY: 1.0

    onIsLaunchingChanged: {
        if (!root.isLaunching) {
            root.bounceVal = 0;
            root.squashX = 1.0;
            root.squashY = 1.0;
        }
    }

    Loader {
        id: circleLoader

        anchors.centerIn: parent
        width: Math.round(parent.width + 4)
        height: Math.round(parent.height + 4)
        active: root.isLaunching && (root.style === "circle" || root.style === "spinner")
        sourceComponent: CircularIndicator {
            anchors.fill: parent
            running: true
            strokeWidth: Math.max(2, Math.round(2.5 * root.currentScale))
            fgColour: root.accentColor
            bgColour: Qt.alpha(root.accentColor, 0.2)
        }
    }

    Item {
        id: pulseItem

        property real pulseScale: 1.0
        property real pulseOpacity: 0.3

        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        visible: root.isLaunching && root.style === "pulse"
        z: -1

        SequentialAnimation {
            running: pulseItem.visible && Tokens.anim.enabled
            loops: Animation.Infinite

            ParallelAnimation {
                NumberAnimation {
                    target: pulseItem
                    property: "pulseScale"
                    to: 1.28
                    duration: 750
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: pulseItem
                    property: "pulseOpacity"
                    to: 0.75
                    duration: 750
                    easing.type: Easing.InOutSine
                }
            }

            ParallelAnimation {
                NumberAnimation {
                    target: pulseItem
                    property: "pulseScale"
                    to: 0.98
                    duration: 750
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: pulseItem
                    property: "pulseOpacity"
                    to: 0.25
                    duration: 750
                    easing.type: Easing.InOutSine
                }
            }
        }

        StyledRect {
            anchors.centerIn: parent
            width: Math.round(parent.width * pulseItem.pulseScale)
            height: Math.round(parent.height * pulseItem.pulseScale)
            radius: Tokens.rounding.full
            color: Qt.alpha(root.accentColor, pulseItem.pulseOpacity * 0.35)
            border.color: Qt.alpha(root.accentColor, pulseItem.pulseOpacity * 0.75)
            border.width: Math.max(1, Math.round(1.5 * root.currentScale))
        }

        StyledRect {
            anchors.centerIn: parent
            width: Math.round(parent.width * (0.85 + (pulseItem.pulseScale - 1.0) * 0.4))
            height: Math.round(parent.height * (0.85 + (pulseItem.pulseScale - 1.0) * 0.4))
            radius: Tokens.rounding.full
            color: Qt.alpha(root.accentColor, pulseItem.pulseOpacity * 0.2)
        }
    }

    Item {
        id: orbitItem

        anchors.centerIn: parent
        width: Math.round(parent.width + 10 * root.currentScale)
        height: Math.round(parent.height + 10 * root.currentScale)
        visible: root.isLaunching && root.style === "orbit"

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: "transparent"
            border.color: Qt.alpha(root.accentColor, 0.2)
            border.width: 1
        }

        Item {
            id: orbitSpinner

            anchors.fill: parent

            RotationAnimation {
                target: orbitSpinner
                property: "rotation"
                running: orbitItem.visible && Tokens.anim.enabled
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 1200
            }

            StyledRect {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: -Math.round(height / 2)
                width: Math.max(5, Math.round(6 * root.currentScale))
                height: width
                radius: Tokens.rounding.full
                color: root.accentColor
                border.color: Colours.palette.m3surface
                border.width: 1
            }
        }
    }

    Item {
        id: dotsItem

        property real wavePhase: 0

        anchors.horizontalCenter: (root.position === "top" || root.position === "bottom") ? parent.horizontalCenter : undefined
        anchors.verticalCenter: (root.position === "left" || root.position === "right") ? parent.verticalCenter : undefined
        anchors.top: root.position === "bottom" ? parent.bottom : undefined
        anchors.bottom: root.position === "top" ? parent.top : undefined
        anchors.left: root.position === "right" ? parent.right : undefined
        anchors.right: root.position === "left" ? parent.left : undefined
        anchors.topMargin: root.position === "bottom" ? Math.round(2 * root.currentScale) : 0
        anchors.bottomMargin: root.position === "top" ? Math.round(2 * root.currentScale) : 0
        anchors.leftMargin: root.position === "right" ? Math.round(2 * root.currentScale) : 0
        anchors.rightMargin: root.position === "left" ? Math.round(2 * root.currentScale) : 0
        width: dotsRow.width
        height: dotsRow.height
        visible: root.isLaunching && root.style === "dots"

        NumberAnimation {
            target: dotsItem
            property: "wavePhase"
            running: dotsItem.visible && Tokens.anim.enabled
            loops: Animation.Infinite
            from: 0
            to: 6.2831853
            duration: 1100
        }

        Row {
            id: dotsRow

            spacing: Math.max(2, Math.round(3 * root.currentScale))

            Repeater {
                model: 3

                StyledRect {
                    id: dot

                    required property int index
                    readonly property real phaseOffset: index * 0.8
                    readonly property real waveVal: Math.sin(dotsItem.wavePhase + phaseOffset)

                    width: Math.max(3, Math.round(4.5 * root.currentScale))
                    height: width
                    radius: Tokens.rounding.full
                    color: root.accentColor
                    opacity: 0.35 + 0.65 * ((waveVal + 1) / 2)
                    transform: Translate {
                        y: -Math.round(2.5 * root.currentScale * Math.max(0, dot.waveVal))
                    }
                }
            }
        }
    }

    StyledRect {
        id: bounceLaunchPip

        anchors.horizontalCenter: (root.position === "top" || root.position === "bottom") ? parent.horizontalCenter : undefined
        anchors.verticalCenter: (root.position === "left" || root.position === "right") ? parent.verticalCenter : undefined
        anchors.top: root.position === "bottom" ? parent.bottom : undefined
        anchors.bottom: root.position === "top" ? parent.top : undefined
        anchors.left: root.position === "right" ? parent.right : undefined
        anchors.right: root.position === "left" ? parent.left : undefined
        anchors.topMargin: root.position === "bottom" ? Math.round(2 * root.currentScale) : 0
        anchors.bottomMargin: root.position === "top" ? Math.round(2 * root.currentScale) : 0
        anchors.leftMargin: root.position === "right" ? Math.round(2 * root.currentScale) : 0
        anchors.rightMargin: root.position === "left" ? Math.round(2 * root.currentScale) : 0
        width: Math.max(4, Math.round(5 * root.currentScale))
        height: width
        radius: Tokens.rounding.full
        color: root.accentColor
        visible: root.isLaunching && root.style === "bounce"
        opacity: 0.4 + 0.6 * (1.0 - Math.min(1.0, root.bounceVal / Math.max(1, 14 * root.currentScale)))
    }

    SequentialAnimation {
        id: bounceLoop

        running: root.isLaunching && root.style === "bounce" && Tokens.anim.enabled
        loops: Animation.Infinite

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "bounceVal"
                to: Math.round(14 * root.currentScale)
                duration: 320
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "squashX"
                to: 0.94
                duration: 200
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "squashY"
                to: 1.08
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "bounceVal"
                to: 0
                duration: 280
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: root
                property: "squashX"
                to: 1.0
                duration: 280
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: root
                property: "squashY"
                to: 1.0
                duration: 280
                easing.type: Easing.InQuad
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "squashX"
                to: 1.12
                duration: 70
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "squashY"
                to: 0.88
                duration: 70
                easing.type: Easing.OutQuad
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "squashX"
                to: 1.0
                duration: 90
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "squashY"
                to: 1.0
                duration: 90
                easing.type: Easing.OutQuad
            }
        }

        PauseAnimation {
            duration: 80
        }
    }
}
