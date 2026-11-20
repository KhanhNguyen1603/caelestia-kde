pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.components.containers
import qs.services

Scope {
    id: root

    readonly property int frostDuration: 220
    readonly property string wallpaper: Wallpapers.current || Wallpapers.fallback

    property bool frosted: false
    property var pending: null

    function frost(onFrosted: var): void {
        root.pending = onFrosted;
        root.frosted = true;
        frostTimer.restart();
    }

    function clear(): void {
        root.pending = null;
        root.frosted = false;
        frostTimer.stop();
        clearTimer.stop();
    }

    Timer {
        id: frostTimer

        interval: root.frostDuration
        onTriggered: {
            const next = root.pending;
            root.pending = null;
            if (next)
                next();
            clearTimer.restart();
        }
    }

    Timer {
        id: clearTimer

        interval: 1500
        onTriggered: root.frosted = false
    }

    Variants {
        model: Screens.screens

        StyledWindow {
            id: win

            required property ShellScreen modelData

            screen: modelData
            name: "lock-frost"
            WlrLayershell.namespace: "overlay"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            visible: root.frosted || veil.opacity > 0.01

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            mask: Region {}

            Item {
                id: veil

                anchors.fill: parent
                opacity: root.frosted ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.frostDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Image {
                    anchors.fill: parent
                    source: root.wallpaper.startsWith("file://") ? root.wallpaper : `file://${root.wallpaper}`
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1
                        blurMax: 64
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Colours.palette.m3scrim
                    opacity: 0.3
                }
            }
        }
    }
}
