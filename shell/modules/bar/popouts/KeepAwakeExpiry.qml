pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

/// Picks the moment keep-awake gives up: the day off the month grid, the time off a slider a
/// quarter of an hour at a time. Confirming hands the moment to the service, which refuses
/// one that has already passed.
ColumnLayout {
    id: root

    required property PopoutState popouts

    property real scaleOffset: 1.0
    property real fontScale: 1.0
    property bool _isSidebarOpen: false

    property date viewDate: new Date()
    /// An hour ahead, to the quarter hour: confirming without touching anything should
    /// still do something useful.
    property date pickedDate: {
        const when = new Date(Date.now() + 60 * 60 * 1000);
        when.setMinutes(Math.ceil(when.getMinutes() / 15) * 15, 0, 0);
        return when;
    }

    readonly property bool valid: root.pickedDate.getTime() > Date.now()
    readonly property int minuteOfDay: root.pickedDate.getHours() * 60 + root.pickedDate.getMinutes()

    function pick(date: date): void {
        const next = new Date(root.pickedDate.getTime());
        next.setFullYear(date.getFullYear(), date.getMonth(), date.getDate());
        root.pickedDate = next;
        // A trailing day belongs to the month it is shown in, so follow it there.
        if (date.getMonth() !== root.viewDate.getMonth() || date.getFullYear() !== root.viewDate.getFullYear())
            root.viewDate = new Date(date.getFullYear(), date.getMonth(), 1);
    }

    function setMinuteOfDay(minutes: real): void {
        // Quarters are what a hold is ever picked to: half an hour, an hour, a night.
        const snapped = Math.min(24 * 60 - 15, Math.max(0, Math.round(minutes / 15) * 15));
        const next = new Date(root.pickedDate.getTime());
        next.setHours(Math.floor(snapped / 60), snapped % 60, 0, 0);
        root.pickedDate = next;
    }

    function confirm(): void {
        if (!root.valid)
            return;

        IdleInhibitor.keepAwakeUntil(root.pickedDate);
        root.popouts.hasCurrent = false;
    }

    width: card.implicitWidth
    implicitWidth: card.implicitWidth
    spacing: Tokens.spacing.medium * root.scaleOffset

    StyledRect {
        id: card

        Layout.fillWidth: true
        implicitWidth: 300 * root.scaleOffset
        implicitHeight: inner.implicitHeight + Tokens.padding.large * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: inner

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.large * root.scaleOffset
            spacing: Tokens.spacing.extraSmall * root.scaleOffset

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Keep awake until")
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.builders.medium.size(Tokens.font.body.medium.pointSize * root.fontScale).build()
            }

            CalendarMonth {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small * root.scaleOffset

                viewDate: root.viewDate
                highlightedDate: root.pickedDate
                selectable: true
                scaleOffset: root.scaleOffset
                fontScale: root.fontScale

                onMonthShifted: delta => root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() + delta, 1)
                onTodayRequested: root.viewDate = new Date()
                onDayClicked: date => root.pick(date)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.medium * root.scaleOffset
                spacing: Tokens.spacing.medium * root.scaleOffset

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: qsTr("Time")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.medium
                }

                CustomMouseArea {
                    Layout.fillWidth: true
                    implicitHeight: Tokens.padding.medium * 3 * root.scaleOffset

                    onWheel: event => root.setMinuteOfDay(root.minuteOfDay + (event.angleDelta.y > 0 ? 15 : -15))

                    StyledSlider {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: parent.implicitHeight

                        value: root.minuteOfDay / (24 * 60)
                        onInteraction: v => root.setMinuteOfDay(v * 24 * 60)
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.valid ? Time.shortDateTime(root.pickedDate) : qsTr("That moment has already passed")
                color: root.valid ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3error
                font: Tokens.font.label.builders.small.size(Tokens.font.label.small.pointSize * root.fontScale).build()
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small * root.scaleOffset
                spacing: Tokens.spacing.small * root.scaleOffset

                Item {
                    Layout.fillWidth: true
                }

                TextButton {
                    text: qsTr("Cancel")
                    type: TextButton.Text
                    onClicked: root.popouts.currentName = "keepawakemenu"
                }

                TextButton {
                    text: qsTr("Set")
                    type: TextButton.Filled
                    disabled: !root.valid
                    onClicked: root.confirm()
                }
            }
        }
    }
}
