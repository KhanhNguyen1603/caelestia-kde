pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    required property DrawerVisibilities visibilities
    property bool expanded: false

    readonly property var active: Timers.activeTimer
    readonly property bool ringing: Timers.ringing
    readonly property bool activePaused: Timers.paused(root.active)
    readonly property real activeProgress: Timers.progress(root.active)
    readonly property int activeTotal: root.active ? Number(root.active.total ?? 0) : 0
    readonly property int typedSeconds: Timers.parseDigits(digitsField.text)
    readonly property string stateLabel: {
        if (root.ringing)
            return qsTr("Time is up");
        if (root.active === null)
            return qsTr("Nothing running");
        if (root.activePaused)
            return qsTr("Paused");
        if (String(root.active.message ?? "").length > 0)
            return String(root.active.message);
        return qsTr("Counting down");
    }
    readonly property string primaryLabel: root.activePaused ? qsTr("Resume") : (root.active === null || root.ringing ? qsTr("Start") : qsTr("Pause"))
    readonly property bool primaryEnabled: root.activePaused || (root.active !== null && !root.ringing) || (root.active === null && root.typedSeconds > 0)

    readonly property real collapsedHeight: header.implicitHeight + progress.height + content.spacing + Tokens.padding.large * 2
    readonly property real expandedHeight: header.implicitHeight + progress.height + content.spacing * 2 + bodyLayout.implicitHeight + Tokens.padding.large * 2
    readonly property real nonAnimHeight: root.expanded ? expandedHeight : collapsedHeight

    function begin(seconds: int): void {
        if (seconds <= 0)
            return;

        Timers.start(seconds, messageField.text);
        digitsField.text = "";
        messageField.text = "";
    }

    function beginTyped(): void {
        root.begin(root.typedSeconds);
    }

    function primaryAction(): void {
        if (root.activePaused) {
            Timers.resume(root.active.id);
            return;
        }
        if (root.active === null) {
            root.beginTyped();
            return;
        }
        if (!root.ringing)
            Timers.pause(root.active.id);
    }

    Layout.fillWidth: true
    implicitHeight: nonAnimHeight
    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    Behavior on implicitHeight {
        Anim {}
    }

    Connections {
        function onUtilitiesChanged(): void {
            if (!root.visibilities.utilities)
                root.expanded = false;
        }

        target: root.visibilities
    }

    StateLayer {
        anchors.fill: parent
        radius: root.radius
        onClicked: root.expanded = !root.expanded
    }

    ColumnLayout {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        RowLayout {
            id: header

            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: icon.implicitHeight + Tokens.padding.large

                radius: Tokens.rounding.full
                color: root.ringing ? Colours.palette.m3error : (root.active !== null ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer)

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    text: "timer"
                    color: root.ringing ? Colours.palette.m3onError : (root.active !== null ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer)
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Timers")
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.stateLabel
                    color: root.ringing ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                text: root.active === null ? qsTr("--:--") : Timers.formatted(root.active)
                color: root.ringing ? Colours.palette.m3error : (root.active === null ? Colours.palette.m3outlineVariant : (root.activePaused ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3primary))
                font: Tokens.font.headline.small

                Component.onCompleted: font.features = { "tnum": 1 }
            }
        }

        StyledRect {
            id: progress

            Layout.fillWidth: true
            implicitHeight: 4
            radius: Tokens.rounding.full
            color: Colours.palette.m3surfaceVariant
            opacity: root.activeTotal > 0 ? 1 : 0

            StyledRect {
                width: root.activeProgress * parent.width
                height: parent.height
                radius: parent.radius
                color: root.ringing ? Colours.palette.m3error : Colours.palette.m3primary

                Behavior on width {
                    Anim {
                        type: Anim.FastEffects
                    }
                }
            }
        }

        ColumnLayout {
            id: bodyLayout

            Layout.fillWidth: true
            visible: opacity > 0
            opacity: root.expanded ? 1 : 0
            spacing: Tokens.spacing.small

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledTextField {
                    id: digitsField

                    Layout.preferredWidth: 96
                    horizontalAlignment: TextInput.AlignHCenter
                    placeholderText: qsTr("300 = 3:00")
                    onAccepted: root.beginTyped()
                }

                StyledTextField {
                    id: messageField

                    Layout.fillWidth: true
                    horizontalAlignment: TextInput.AlignLeft
                    placeholderText: qsTr("What is it for?")
                    onAccepted: root.beginTyped()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                TextButton {
                    text: qsTr("Reset")
                    type: TextButton.Text
                    disabled: Timers.count === 0
                    onClicked: Timers.clear()
                }

                Item {
                    Layout.fillWidth: true
                }

                TextButton {
                    text: root.primaryLabel
                    type: TextButton.Filled
                    disabled: !root.primaryEnabled
                    onClicked: root.primaryAction()
                }
            }

            Repeater {
                model: Timers.others

                delegate: StyledRect {
                    id: timerRow

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: timerLayout.implicitHeight + Tokens.padding.small * 2

                    radius: Tokens.rounding.medium
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                    RowLayout {
                        id: timerLayout

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.small
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "timer"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            text: Timers.formatted(timerRow.modelData)
                            color: Timers.paused(timerRow.modelData) ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                            font: Tokens.font.title.small

                            Component.onCompleted: font.features = { "tnum": 1 }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: timerRow.modelData.message || qsTr("Timer")
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        IconButton {
                            icon: Timers.paused(timerRow.modelData) ? "play_arrow" : "pause"
                            onClicked: Timers.toggle(timerRow.modelData.id)
                            Accessible.name: Timers.paused(timerRow.modelData) ? qsTr("Resume this timer") : qsTr("Pause this timer")
                        }

                        IconButton {
                            id: pinBtn

                            icon: "push_pin"
                            isToggle: true
                            checked: Timers.pinnedId === timerRow.modelData.id
                            onClicked: {
                                Timers.pin(timerRow.modelData.id);
                                pinBtn.internalChecked = Timers.pinnedId === timerRow.modelData.id;
                            }
                            Accessible.name: checked ? qsTr("Unpin this timer") : qsTr("Pin this timer")
                        }

                        IconButton {
                            icon: "close"
                            onClicked: Timers.cancel(timerRow.modelData.id)
                            Accessible.name: qsTr("Cancel this timer")
                        }
                    }
                }
            }
        }
    }
}
