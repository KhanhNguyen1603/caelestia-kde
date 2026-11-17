pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Notifications
import Caelestia
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services
import qs.utils

StyledRect {
    id: root

    required property NotifData modelData
    readonly property int urgency: root.modelData?.urgency ?? NotificationUrgency.Normal
    readonly property bool isCritical: root.urgency === NotificationUrgency.Critical
    readonly property bool isLow: root.urgency === NotificationUrgency.Low
    // Senders put an icon *name* here as often as a path, and the name need not exist: Signal
    // installs signal-desktop, so image://icon/signal resolves to nothing and Quickshell answers
    // with a 2px missing-icon placeholder, which is the blocky square that used to show. The
    // two-argument form returns empty for a miss so the icon falls back to the glyph below.
    readonly property string imagePath: {
        const img = modelData?.image ?? "";
        return img.startsWith("image://icon/") ? Quickshell.iconPath(img.slice("image://icon/".length), true) : img;
    }
    readonly property bool hasImage: root.imagePath !== ""
    readonly property bool hasAppIcon: (modelData?.appIcon.length ?? 0) > 0
    readonly property int nonAnimHeight: appName.height + summary.implicitHeight + (root.expanded ? Tokens.spacing.extraSmall * 2 + body.height + actions.height + actions.anchors.topMargin : Tokens.spacing.extraSmall + bodyPreview.height) + inner.anchors.margins * 2
    property bool expanded: Config.notifs.openExpanded
    readonly property bool hovered: cardMouse.containsMouse
    // A body that already fits the preview has nothing behind the chevron, so the chevron is
    // only offered when it would actually reveal something.
    readonly property bool disclosable: (root.modelData?.actions?.length ?? 0) > 0 || bodyPreview.truncated

    // A keyboard user gets the same hold the pointer gets, from the moment a control takes focus.
    function holdOpen(hold: bool): void {
        if (hold)
            root.modelData?.timer.stop();
        else if (!root.hovered)
            root.modelData?.timer.start();
    }

    // Muting removes every trace of the toast, so it has to say what it did somewhere else.
    function muteSender(): void {
        if (!root.modelData?.appName)
            return;

        Notifs.muteApp(root.modelData.appName);
        Toaster.toast(qsTr("Notifications off"), qsTr("%1 will stay quiet until you turn it back on").arg(root.modelData.appName), "notifications_off");
    }

    // Opaque rather than the translucent palette variant: a see-through card lets the backdrop
    // bleed into its rounded corners, which reads as a blurred edge no amount of antialiasing
    // fixes. A toast sits over whatever happens to be behind it, so it should not be porous.
    color: root.isCritical ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainer
    radius: Tokens.rounding.large
    implicitHeight: inner.implicitHeight
    // A rounded rectangle draws a hard-edged arc unless this is set, and a 16px corner over a
    // wallpaper is exactly where the stairsteps show. No layer here: a layered card is
    // rasterised into its own texture, which softens every edge instead of smoothing the arc.
    antialiasing: true

    // Assistive technology reads the toast as a message, not as an unlabelled panel.
    Accessible.role: Accessible.AlertMessage
    Accessible.name: root.modelData?.summaryPlain ?? ""
    Accessible.description: root.modelData?.bodyPlain ?? ""

    x: implicitWidth
    opacity: 0
    Component.onCompleted: {
        x = 0;
        opacity = 1;
        modelData?.lock(this);
    }
    Component.onDestruction: modelData?.unlock(this)

    Behavior on x {
        Anim {
            easing: Tokens.anim.emphasizedDecel
        }
    }

    Behavior on opacity {
        Anim {
            type: Anim.SlowEffects
        }
    }

    MouseArea {
        id: cardMouse

        property int startY
        property bool swiped: false

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.expanded && body.hoveredLink ? Qt.PointingHandCursor : pressed ? Qt.ClosedHandCursor : undefined
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        preventStealing: true

        onEntered: root.modelData.timer.stop()
        onExited: {
            if (!pressed)
                root.modelData.timer.start();
        }

        drag.target: parent
        drag.axis: Drag.XAxis

        onPressed: event => {
            root.modelData.timer.stop();
            startY = event.y;
            swiped = false;
            if (event.button === Qt.MiddleButton)
                root.modelData.close();
        }
        onReleased: event => {
            if (!containsMouse)
                root.modelData.timer.start();

            swiped = Math.abs(root.x) > drag.threshold;
            if (Math.abs(root.x) < root.implicitWidth * Config.notifs.clearThreshold)
                root.x = 0;
            else
                root.modelData.popup = false;
        }
        onPositionChanged: event => {
            if (pressed) {
                const diffY = event.y - startY;
                if (Math.abs(diffY) > Config.notifs.expandThreshold)
                    root.expanded = diffY > 0;
            }
        }
        onClicked: event => {
            if (!GlobalConfig.notifs.actionOnClick || event.button !== Qt.LeftButton || swiped || (root.expanded && body.hoveredLink))
                return;

            if (root.modelData.activate())
                root.modelData.popup = false;
        }

        Item {
            id: inner

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium

            implicitHeight: root.nonAnimHeight

            Behavior on implicitHeight {
                Anim {}
            }

            Loader {
                id: image

                asynchronous: true
                active: root.hasImage

                anchors.left: parent.left
                anchors.top: parent.top
                width: TokenConfig.sizes.notifs.image
                height: TokenConfig.sizes.notifs.image
                visible: root.hasImage || root.hasAppIcon

                sourceComponent: StyledClippingRect {
                    radius: Tokens.rounding.small
                    color: root.isCritical ? Colours.palette.m3error : root.isLow ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) : Colours.palette.m3secondaryContainer
                    implicitWidth: TokenConfig.sizes.notifs.image
                    implicitHeight: TokenConfig.sizes.notifs.image

                    // The hint arrives as an image://icon/<name> provider URL or a file path.
                    // A bare Image asks the provider before it has a size and gets its 2px
                    // fallback back, which is the blocky placeholder that used to appear here;
                    // CachingIconImage waits for a real size and picks the right renderer.
                    CachingIconImage {
                        anchors.fill: parent
                        implicitSize: TokenConfig.sizes.notifs.image
                        source: root.imagePath
                    }
                }
            }

            Loader {
                id: appIcon

                asynchronous: true
                active: root.hasAppIcon || !root.hasImage

                anchors.horizontalCenter: root.hasImage ? undefined : image.horizontalCenter
                anchors.verticalCenter: root.hasImage ? undefined : image.verticalCenter
                anchors.right: root.hasImage ? image.right : undefined
                anchors.bottom: root.hasImage ? image.bottom : undefined

                sourceComponent: StyledRect {
                    // Same silhouette as an attached image so the icon column does not change
                    // shape depending on which hint the sender happened to set.
                    radius: root.hasImage ? Tokens.rounding.extraSmall : Tokens.rounding.small
                    color: root.isCritical ? Colours.palette.m3error : root.isLow ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) : Colours.palette.m3secondaryContainer
                    implicitWidth: root.hasImage ? Tokens.sizes.notifs.badge : TokenConfig.sizes.notifs.image
                    implicitHeight: root.hasImage ? Tokens.sizes.notifs.badge : TokenConfig.sizes.notifs.image

                    Loader {
                        id: icon

                        asynchronous: true
                        active: root.hasAppIcon

                        anchors.centerIn: parent

                        width: Math.round(parent.width * 0.6)
                        height: Math.round(parent.width * 0.6)

                        sourceComponent: ColouredIcon {
                            anchors.fill: parent
                            source: Icons.getNotifAppIcon(root.modelData?.appIcon ?? "")
                            colour: root.isCritical ? Colours.palette.m3onError : root.isLow ? Colours.palette.m3onSurface : Colours.palette.m3onSecondaryContainer
                            layer.enabled: root.modelData?.appIcon?.endsWith("symbolic") ?? false
                        }
                    }

                    Loader {
                        asynchronous: true
                        active: !root.hasAppIcon
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: Centering.pixelAlign(parent.height, height)

                        sourceComponent: MaterialIcon {
                            text: root.modelData.materialIcon || Icons.getNotifIcon(root.modelData?.summary ?? "", root.urgency)
                            color: root.isCritical ? Colours.palette.m3onError : root.isLow ? Colours.palette.m3onSurface : Colours.palette.m3onSecondaryContainer
                            fontStyle: Tokens.font.icon.medium
                        }
                    }
                }
            }

            Shape {
                id: progressIndicator

                anchors.centerIn: appIcon
                width: appIcon.implicitWidth + progressShape.strokeWidth * 2
                height: appIcon.implicitHeight + progressShape.strokeWidth * 2
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    id: progressShape

                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    strokeWidth: 2
                    strokeColor: Colours.palette.m3primary

                    PathAngleArc {
                        id: progressArc

                        radiusX: progressIndicator.width / 2 - root.Tokens.padding.extraSmall / 2
                        centerX: progressIndicator.width / 2
                        radiusY: progressIndicator.height / 2 - root.Tokens.padding.extraSmall / 2
                        centerY: progressIndicator.height / 2

                        startAngle: -90
                        sweepAngle: ((root.modelData?.hints?.value ?? 0) / 100) * 360

                        Behavior on sweepAngle {
                            Anim {
                                easing: Tokens.anim.emphasizedDecel
                            }
                        }
                    }
                }
            }

            StyledText {
                id: appName

                anchors.top: parent.top
                anchors.left: image.right
                anchors.leftMargin: Tokens.spacing.medium

                animate: true
                text: appNameMetrics.elidedText
                maximumLineCount: 1
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            TextMetrics {
                id: appNameMetrics

                text: root.modelData?.appName ?? ""
                font: appName.font
                elide: Text.ElideRight
                elideWidth: (root.hovered ? muteBtn.x : closeBtn.x) - (time.visible ? time.width + timeSep.width + root.Tokens.spacing.small : 0) - appName.x - root.Tokens.spacing.small * 2
            }

            StyledText {
                id: summary

                anchors.top: appName.bottom
                anchors.topMargin: root.Tokens.spacing.extraSmall
                anchors.left: appName.left
                anchors.right: closeBtn.left
                anchors.rightMargin: root.Tokens.spacing.small

                animate: true
                text: root.modelData?.summaryPlain ?? ""
                textFormat: Text.PlainText
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
                font.pointSize: Tokens.font.body.large.pointSize * root.fontScale
                font.weight: Font.DemiBold
                height: implicitHeight

                states: State {
                    name: "expanded"
                    when: root.expanded

                    PropertyChanges {
                        summary.maximumLineCount: undefined
                        bodyPreview.anchors.topMargin: root.Tokens.spacing.extraSmall
                        body.anchors.topMargin: root.Tokens.spacing.extraSmall
                    }
                }

                transitions: Transition {
                    PropertyAction {
                        target: summary
                        property: "maximumLineCount"
                    }
                    Anim {
                        property: "topMargin"
                    }
                }

                Behavior on height {
                    Anim {}
                }
            }

            StyledText {
                id: timeSep

                visible: !(root.modelData?.fresh ?? true)
                anchors.top: parent.top
                anchors.left: appName.right
                anchors.leftMargin: Tokens.spacing.small

                text: "Ã¢â‚¬Â¢"
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }

            StyledText {
                id: time

                visible: timeSep.visible
                anchors.top: parent.top
                anchors.left: timeSep.right
                anchors.leftMargin: Tokens.spacing.small

                animate: true
                horizontalAlignment: Text.AlignLeft
                text: root.modelData?.timeStr ?? ""
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }

            // Everything the toast can do besides open sits on the header line and only shows
            // under the pointer, the way an OS toast keeps its body for the message. Real
            // buttons rather than bare state layers, so each is a labelled control a screen
            // reader can find and a keyboard can reach, not a shape only a pointer can hit.
            IconButton {
                id: muteBtn

                visible: root.hovered
                anchors.right: copyBtn.left
                anchors.rightMargin: Tokens.spacing.extraSmall
                anchors.top: parent.top
                anchors.topMargin: -Tokens.padding.extraSmall

                type: IconButton.Text
                isRound: true
                icon: "notifications_off"
                padding: Tokens.padding.extraSmall
                inactiveOnColour: root.isCritical ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                accessibleName: qsTr("Turn off notifications from %1").arg(root.modelData?.appName ?? "")
                onClicked: root.muteSender()
                onActiveFocusChanged: root.holdOpen(activeFocus)
            }

            IconButton {
                id: copyBtn

                visible: root.hovered
                anchors.right: closeBtn.left
                anchors.rightMargin: Tokens.spacing.extraSmall
                anchors.top: parent.top
                anchors.topMargin: -Tokens.padding.extraSmall

                type: IconButton.Text
                isRound: true
                icon: copyTimer.running ? "inventory" : "content_copy"
                padding: Tokens.padding.extraSmall
                inactiveOnColour: root.isCritical ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                accessibleName: qsTr("Copy the notification text")
                onClicked: {
                    if (root.modelData) {
                        Quickshell.clipboardText = root.modelData.body;
                        copyTimer.restart();
                    }
                }
                onActiveFocusChanged: root.holdOpen(activeFocus)

                Timer {
                    id: copyTimer

                    interval: 3000
                }
            }

            IconButton {
                id: closeBtn

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: -Tokens.padding.extraSmall

                type: IconButton.Text
                isRound: true
                icon: "close"
                padding: Tokens.padding.extraSmall
                inactiveOnColour: root.isCritical ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                accessibleName: qsTr("Dismiss notification")
                onClicked: root.modelData?.close()
                onActiveFocusChanged: root.holdOpen(activeFocus)
            }

            StyledText {
                id: bodyPreview

                anchors.left: summary.left
                anchors.right: expandBtn.left
                anchors.top: summary.bottom
                anchors.rightMargin: Tokens.spacing.small

                animate: true
                text: root.modelData.bodyPlain
                textFormat: Text.PlainText
                elide: Text.ElideRight
                maximumLineCount: 2
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium

                opacity: root.expanded ? 0 : 1

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            // The chevron lives at the end of the line it reveals instead of opposite the
            // header it does not touch, so the direction of the expansion matches the control.
            // Same IconButton as the corner controls, so both share the right edge.
            IconButton {
                id: expandBtn

                visible: root.disclosable
                anchors.right: parent.right
                anchors.verticalCenter: bodyPreview.verticalCenter

                type: IconButton.Text
                isRound: true
                icon: "expand_more"
                padding: Tokens.padding.extraSmall
                rotation: root.expanded ? 180 : 0
                inactiveOnColour: root.isCritical ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                accessibleName: root.expanded ? qsTr("Show less") : qsTr("Show more")
                onClicked: root.expanded = !root.expanded
                onActiveFocusChanged: root.holdOpen(activeFocus)

                Behavior on rotation {
                    Anim {}
                }
            }

            StyledText {
                id: body

                anchors.left: summary.left
                anchors.right: expandBtn.left
                anchors.top: summary.bottom
                anchors.rightMargin: Tokens.spacing.small

                animate: true
                textFormat: Text.StyledText
                text: root.modelData.bodyStyled
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                height: text ? implicitHeight : 0

                onLinkActivated: link => {
                    if (!root.expanded)
                        return;

                    Launch.openUrl(link);
                    root.modelData.popup = false;
                }

                opacity: root.expanded ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            Column {
                id: actions

                anchors.left: body.left
                anchors.right: body.right
                anchors.top: body.bottom
                anchors.topMargin: Tokens.spacing.small

                spacing: 0
                opacity: root.expanded ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                Repeater {
                    model: root.modelData?.actions ?? []

                    // An OS stacks actions as rows under a hairline. Chips read as in-app
                    // buttons, which is the one thing a toast's own actions are not.
                    Column {
                        required property var modelData

                        width: actions.width
                        spacing: 0

                        StyledRect {
                            width: parent.width
                            implicitHeight: 1
                            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
                        }

                        TextButton {
                            width: parent.width
                            isRound: false
                            inactiveColour: "transparent"
                            inactiveOnColour: root.isCritical ? Colours.palette.m3onSecondary : Colours.palette.m3onSurface
                            text: modelData.text
                            onClicked: modelData.invoke()

                            label.horizontalAlignment: Text.AlignLeft
                            label.anchors.left: left
                            label.anchors.right: right
                            label.anchors.verticalCenter: verticalCenter
                            label.anchors.centerIn: undefined
                            label.anchors.margins: Tokens.padding.medium
                            label.elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
