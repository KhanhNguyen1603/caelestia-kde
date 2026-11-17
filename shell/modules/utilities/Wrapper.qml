pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.modules.sidebar as Sidebar
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property Sidebar.Wrapper sidebar
    required property BarPopouts.Wrapper popouts
    property real horizontalStretch
    property matrix4x4 deformMatrix
    readonly property PersistentProperties props: PersistentProperties {
        property bool recordingListExpanded: false
        property bool screenshotListExpanded: false
        property bool quickShareListExpanded: false
        property bool quickShareDeviceSelectorOpen: false
        property string quickShareConfirmDeletePath: ""
        property real quickShareConfirmDeleteTimestamp: 0
        property string captureMode
        property string recordingConfirmDelete
        property string recordingMode

        reloadableId: "utilities"
    }
    readonly property bool shouldBeActive: visibilities.utilities && Config.utilities.enabled && !(visibilities.session && Config.session.enabled) && !visibilities.overview
    // The content is anchored to the top and left only, so the room this wrapper reserves
    // has to carry both sides of the inset: half of it is the margin the content is placed
    // at, the other half is what closes the gap at the bottom and the right. Reserving
    // `margins` plus a clamped remainder made those two edges tighter than the first two
    // as soon as a border was configured.
    readonly property real panelInset: Tokens.padding.large
    readonly property real totalPadding: root.panelInset * 2
    readonly property real nonAnimHeight: ((content.item as Content)?.nonAnimHeight ?? 0) + totalPadding
    property real offsetScale: shouldBeActive ? 0 : 1
    property real sidebarLerp

    visible: offsetScale < 1
    anchors.bottomMargin: Config.bar.position === "bottom" ? 0 : (-implicitHeight - 5) * offsetScale
    anchors.topMargin: Config.bar.position === "bottom" ? (-implicitHeight - 5) * offsetScale : 0
    implicitHeight: content.implicitHeight + totalPadding
    implicitWidth: sidebar.width * (1 - sidebar.offsetScale) * horizontalStretch * sidebarLerp + Tokens.sizes.utilities.width * (1 - sidebarLerp)
    opacity: 1 - offsetScale
    states: State {
        name: "attachedToSidebar"
        when: root.visibilities.sidebar

        PropertyChanges {
            root.sidebarLerp: 1
        }
    }
    transitions: [
        Transition {
            from: ""

            Anim {
                property: "sidebarLerp"
                duration: Tokens.anim.durations.expressiveDefaultSpatial / 2
                easing: Tokens.anim.standardAccel
            }
        },
        Transition {
            to: ""

            Anim {
                property: "sidebarLerp"
                duration: Tokens.anim.durations.expressiveDefaultSpatial / 2
                easing: Tokens.anim.standardDecel
            }
        }
    ]

    Behavior on offsetScale {
        Anim {}
    }
    Loader {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: root.panelInset
        asynchronous: true
        active: true
        onStatusChanged: {
            if (status === Loader.Error) {
                if (asynchronous) {
                    console.error("[Preload Failsafe] Utilities failed to load asynchronously. Retrying synchronously...");
                    active = false;
                    asynchronous = false;
                    Qt.callLater(() => { active = true; });
                } else {
                    console.error("[Preload Failsafe] Utilities failed to load synchronously! Giving up.");
                }
            } else if (status === Loader.Ready) {
                console.log("[Preload] Utilities loaded successfully.");
            }
        }
        sourceComponent: Content {
            implicitWidth: root.implicitWidth - root.totalPadding
            props: root.props
            visibilities: root.visibilities
            popouts: root.popouts
            deformMatrix: root.deformMatrix
        }
    }
}
