pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus

// A strip that needs no aiming, in place of the chevron the tray used to carry:
// it lights up when the pointer reaches the end of the bar.
Item {
    id: root

    property bool isHorizontal: true
    property int thickness: Tokens.sizes.bar.innerWidth

    readonly property int desktopPageIdx: PageRegistry.indexForKey("desktop")
    readonly property bool showing: Kwin.showingDesktop

    property bool hovered: false

    // The strip is thin on purpose; the item around it is wider so it is still easy
    // to hit once the pointer is anywhere near the end of the bar.
    implicitWidth: root.isHorizontal ? Tokens.padding.medium : root.thickness
    implicitHeight: root.isHorizontal ? root.thickness : Tokens.padding.medium

    StyledRect {
        id: strip

        readonly property real across: root.hovered || area.pressed ? Tokens.padding.small : Tokens.padding.extraSmall

        anchors.centerIn: parent
        implicitWidth: root.isHorizontal ? strip.across : root.thickness - Tokens.spacing.large
        implicitHeight: root.isHorizontal ? root.thickness - Tokens.spacing.large : strip.across
        radius: Tokens.rounding.full
        color: Qt.alpha(Colours.palette.m3onSurface, root.showing ? 0.32 : root.hovered ? 0.22 : 0.1)

        Behavior on implicitWidth {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Behavior on implicitHeight {
            Anim {
                type: Anim.FastSpatial
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Show desktop")
        Accessible.description: qsTr("Minimize every window to show the desktop")

        onEntered: root.hovered = true
        onExited: root.hovered = false

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                WindowFactory.create(null, {
                    initialPageIdx: root.desktopPageIdx
                });
                return;
            }
            Kwin.setShowingDesktop(!Kwin.showingDesktop);
        }
    }
}
