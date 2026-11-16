pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

/// Picks the moment keep-awake gives up: the day comes off the month grid, the time off the
/// two fields beside it. Confirming hands the moment to the service, which refuses one that
/// has already passed.
ColumnLayout {
    id: root

    required property PopoutState popouts

    property real scaleOffset: 1.0
    property real fontScale: 1.0
    property bool _isSidebarOpen: false

    property date viewDate: new Date()
    /// An hour ahead, to the minute: confirming without touching anything should still do
    /// something useful.
    property date pickedDate: {
        const when = new Date(Date.now() + 60 * 60 * 1000);
        when.setSeconds(0, 0);
        return when;
    }

    readonly property bool valid: root.pickedDate.getTime() > Date.now()

    function pad(value: int): string {
        return String(value).padStart(2, "0");
    }

    function summary(): string {
        return Qt.locale().toString(root.pickedDate, "ddd d MMM") + ", " + Time.clockTime(root.pickedDate);
    }

    function pick(date: date): void {
        const next = new Date(root.pickedDate.getTime());
        next.setFullYear(date.getFullYear(), date.getMonth(), date.getDate());
        root.pickedDate = next;
        // A trailing day belongs to the month it is shown in, so follow it there.
        if (date.getMonth() !== root.viewDate.getMonth() || date.getFullYear() !== root.viewDate.getFullYear())
            root.viewDate = new Date(date.getFullYear(), date.getMonth(), 1);
    }

    function setTime(hours: int, minutes: int): void {
        if (isNaN(hours) || isNaN(minutes))
            return;

        const next = new Date(root.pickedDate.getTime());
        next.setHours(Math.max(0, Math.min(23, hours)), Math.max(0, Math.min(59, minutes)), 0, 0);
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
                spacing: Tokens.spacing.small * root.scaleOffset

                TimeField {
                    value: root.pickedDate.getHours()
                    maximum: 23
                    onCommitted: value => root.setTime(value, root.pickedDate.getMinutes())
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: ":"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.medium
                }

                TimeField {
                    value: root.pickedDate.getMinutes()
                    maximum: 59
                    onCommitted: value => root.setTime(root.pickedDate.getHours(), value)
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: root.valid ? root.summary() : qsTr("That moment has already passed")
                    color: root.valid ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3error
                    font: Tokens.font.label.builders.small.size(Tokens.font.label.small.pointSize * root.fontScale).build()
                    wrapMode: Text.WordWrap
                }
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

    /// A two-digit hour or minute. The moment itself is the source of truth, so an edit that
    /// does not survive clamping is put back as it was.
    component TimeField: StyledTextField {
        id: field

        property int value
        property int maximum: 59

        signal committed(int value)

        Layout.preferredWidth: 64 * root.scaleOffset
        horizontalAlignment: TextInput.AlignHCenter
        type: StyledTextField.Boxed
        inputMethodHints: Qt.ImhDigitsOnly
        validator: IntValidator {
            bottom: 0
            top: field.maximum
        }

        onValueChanged: field.text = root.pad(field.value)
        Component.onCompleted: field.text = root.pad(field.value)
        onEditingFinished: {
            field.committed(parseInt(field.text, 10));
            field.text = root.pad(field.value);
        }
    }
}
