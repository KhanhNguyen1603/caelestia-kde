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
    /// One of `running`, `paused`, `rang` or `idle`. Every label and button below reads it
    /// rather than re-deciding what state the timer is in.
    readonly property string mode: root.active ? String(root.active.state) : "idle"
    readonly property real activeProgress: Timers.progress(root.active)
    readonly property int activeTotal: root.active ? Number(root.active.total ?? 0) : 0
    readonly property int typedSeconds: Timers.parseKeypad(digitsField.text)
    readonly property string stateLabel: {
        switch (root.mode) {
        case "rang":
            return qsTr("Time is up");
        case "paused":
            return qsTr("Paused");
        case "running":
            return String(root.active.message ?? "").length > 0 ? String(root.active.message) : qsTr("Counting down");
        default:
            return qsTr("Nothing running");
        }
    }
    readonly property string primaryLabel: root.mode === "paused" ? qsTr("Resume") : (root.mode === "running" ? qsTr("Pause") : qsTr("Start"))
    readonly property bool primaryEnabled: root.mode === "paused" || root.mode === "running" || root.typedSeconds > 0

    /// The header and the progress line are always there; only the body comes and goes, so
    /// the card is the chrome plus whatever the body measures at the moment.
    readonly property real chromeHeight: header.implicitHeight + progress.implicitHeight + content.spacing
    readonly property real collapsedHeight: root.chromeHeight + Tokens.padding.large * 2
    readonly property real expandedHeight: root.collapsedHeight + bodyLayout.implicitHeight + content.spacing
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
        switch (root.mode) {
        case "paused":
            Timers.resume(root.active.id);
            return;
        case "running":
            Timers.pause(root.active.id);
            return;
        case "idle":
            root.beginTyped();
            return;
        }
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
                color: root.mode === "rang" ? Colours.palette.m3error : (root.mode === "idle" ? Colours.palette.m3secondaryContainer : Colours.palette.m3primary)

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    text: "timer"
                    color: root.mode === "rang" ? Colours.palette.m3onError : (root.mode === "idle" ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onPrimary)
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
                    color: root.mode === "rang" ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                text: root.mode === "idle" ? qsTr("--:--") : Timers.formatted(root.active)
                color: root.mode === "rang" ? Colours.palette.m3error : (root.mode === "idle" ? Colours.palette.m3outlineVariant : (root.mode === "paused" ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3primary))
                font: Tokens.font.headline.small
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
                color: root.mode === "rang" ? Colours.palette.m3error : Colours.palette.m3primary

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

                delegate: TimerRow {
                    timer: modelData
                }
            }
        }
    }

    component TimerRow: StyledRect {
        id: row

        required property var timer

        readonly property bool paused: String(row.timer.state) === "paused"

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
                text: Timers.formatted(row.timer)
                color: row.paused ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                font: Tokens.font.title.small
            }

            StyledText {
                Layout.fillWidth: true
                text: row.timer.message || qsTr("Timer")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            IconButton {
                icon: row.paused ? "play_arrow" : "pause"
                onClicked: Timers.toggle(row.timer.id)
                Accessible.name: row.paused ? qsTr("Resume this timer") : qsTr("Pause this timer")
            }

            IconButton {
                id: pinBtn

                icon: "push_pin"
                isToggle: true
                checked: Timers.pinnedId === row.timer.id
                onClicked: {
                    Timers.pin(row.timer.id);
                    pinBtn.internalChecked = Timers.pinnedId === row.timer.id;
                }
                Accessible.name: checked ? qsTr("Unpin this timer") : qsTr("Pin this timer")
            }

            IconButton {
                icon: "close"
                onClicked: Timers.cancel(row.timer.id)
                Accessible.name: qsTr("Cancel this timer")
            }
        }
    }
}
