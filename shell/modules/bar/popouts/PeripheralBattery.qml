pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    readonly property var excluded: Config.bar.status.peripheralBatteryExcluded

    property real scaleOffset: 1.0
    property real fontScale: 1.0
    property bool _isSidebarOpen: false

    spacing: Tokens.spacing.small * scaleOffset

    Repeater {
        model: ScriptModel {
            values: UPower.devices.values.filter(d => !d.isLaptopBattery && d.type !== UPowerDeviceType.LinePower && d.isPresent && !root.excluded.some(e => e === d.model || e === d.nativePath))
        }

        RowLayout {
            id: peripheralRow

            required property UPowerDevice modelData

            Layout.fillWidth: true
            spacing: Tokens.spacing.small * root.scaleOffset

            MaterialIcon {
                text: {
                    const t = peripheralRow.modelData.type;
                    if (t === UPowerDeviceType.Mouse || t === UPowerDeviceType.Touchpad)
                        return "mouse";
                    if (t === UPowerDeviceType.Keyboard)
                        return "keyboard";
                    if (t === UPowerDeviceType.Headset || t === UPowerDeviceType.Headphones)
                        return "headphones";
                    if (t === UPowerDeviceType.GamingInput)
                        return "sports_esports";
                    if (t === UPowerDeviceType.Pen)
                        return "stylus";
                    if (t === UPowerDeviceType.Speakers || t === UPowerDeviceType.OtherAudio)
                        return "speaker";
                    if (t === UPowerDeviceType.Phone)
                        return "smartphone";
                    return "battery_full";
                }
                color: Colours.palette.m3onSurface
                fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
            }

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: (peripheralRow.modelData.model || "Device") + ": " + Math.round(peripheralRow.modelData.percentage * 100) + "%"
                font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
            }
        }
    }
}
