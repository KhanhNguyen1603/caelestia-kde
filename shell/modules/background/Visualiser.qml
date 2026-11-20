pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.Components
import Caelestia.Services
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    readonly property bool windowHidesVisualiser: (Kwin.showingDesktop, Kwin.windowList, Kwin.activeWsId, Kwin.activeByOutput, Kwin.windowHidesDesktopWidgets(root.screen ? root.screen.name : "", Config.background.visualiser.hideOnAllMonitors))
    readonly property bool shouldBeActive: Config.background.wallpaperEnabled
        && !ContextMenuStore.editMode
        && !Config.background.disableQuickshellDesktop
        && Config.background.visualiser.enabled
        && !Audio.muted
        && !(GameMode.enabled && GlobalConfig.utilities.gameMode.disableVisualizer)
        && (!Config.background.visualiser.autoHide || !windowHidesVisualiser)
    readonly property var barWrapper: {
        const name = root.screen ? root.screen.name : undefined;
        return name ? Visibilities.bars.get(name) : undefined;
    }
    readonly property int barExclusiveZone: barWrapper ? barWrapper.visualThickness : 0
    readonly property real fallbackMargin: Tokens.padding.large + Tokens.spacing.small
    property real offset: shouldBeActive ? 0 : screen.height * 0.2

    opacity: shouldBeActive ? 1 : 0
    visible: opacity > 0

    Loader {
        asynchronous: true
        anchors.fill: parent
        anchors.topMargin: root.offset
        anchors.bottomMargin: -root.offset
        active: root.opacity > 0

        sourceComponent: Item {
            ServiceRef {
                service: Audio.cava
            }

            VisualiserBars {
                id: bars

                anchors.fill: parent
                anchors.margins: Config.border.thickness
                anchors.leftMargin: Config.bar.position === "left" ? (root.barExclusiveZone + root.fallbackMargin) : root.fallbackMargin
                anchors.rightMargin: Config.bar.position === "right" ? (root.barExclusiveZone + root.fallbackMargin) : root.fallbackMargin
                anchors.topMargin: Config.bar.position === "top" ? root.barExclusiveZone : Config.border.thickness
                anchors.bottomMargin: Config.bar.position === "bottom" ? root.barExclusiveZone : Config.border.thickness
                values: Audio.cava?.values ?? []
                sideWidth: 0.4
                primaryColor: Qt.alpha(Colours.palette.m3primary, 0.7)
                secondaryColor: Qt.alpha(Colours.palette.m3inversePrimary, 0.7)
                rounding: Tokens.rounding.medium
                spacing: Tokens.spacing.extraSmall
                animationDuration: Tokens.anim.durations.expressiveDefaultEffects

                Behavior on anchors.leftMargin {
                    Anim {}
                }

                Behavior on anchors.rightMargin {
                    Anim {}
                }

                Behavior on anchors.topMargin {
                    Anim {}
                }

                Behavior on anchors.bottomMargin {
                    Anim {}
                }
            }

            FrameAnimation {
                running: root.opacity > 0 && !bars.settled && (Audio.cava?.values?.length ?? 0) > 0 && Tokens.anim.enabled
                onTriggered: bars.advance(frameTime)
            }
        }
    }

    Behavior on offset {
        Anim {}
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
