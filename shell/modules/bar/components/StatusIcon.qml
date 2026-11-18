pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.bar

// One status icon: the same glyph icon the rest of the tray uses, so it lifts, names
// itself and opens its menu the way every other icon on the bar does.
BarIcon {
    id: root

    property var bar

    readonly property string iconId: BarWidgets.statusIconId(root.entryId)
    readonly property color colour: Colours.palette.m3secondary
    readonly property string popoutName: {
        switch (root.iconId) {
        case "lockStatus":
            return "lockstatus";
        case "kbLayout":
            return "kblayout";
        case "microphone":
            return "audio";
        default:
            return root.iconId;
        }
    }

    // Hovering says what the icon is; the menu is the right button's job. The name comes
    // from BarIconMeta so the tooltip and the settings list cannot drift apart.
    tooltip: BarIconMeta.nameOf(root.iconId)

    onActivated: {
        if (root.iconId === "notifications") {
            // Hovering the bell may have opened the small notification popout already;
            // leaving it open on top of the sidebar makes both panels jitter.
            if (root.popouts)
                root.popouts.hasCurrent = false;

            const vis = root.bar?.visibilities ?? Visibilities.getForActive();
            vis.sidebar = !vis.sidebar;
            return;
        }

        // Hover popouts are a convenience, not the only way in: a click opens the same
        // popout when they are disabled.
        root.openPopout(root.popoutName);
    }

    onContextMenuRequested: root.openPopout("statusiconscontext")

    glyphComponent: {
        switch (root.iconId) {
        case "lockStatus":
            return lockstatusComp;
        case "privacy":
            return privacyComp;
        case "audio":
            return audioComp;
        case "microphone":
            return microphoneComp;
        case "kbLayout":
            return kblayoutComp;
        case "network":
            return networkComp;
        case "ethernet":
            return ethernetComp;
        case "bluetooth":
            return bluetoothComp;
        case "battery":
            return batteryComp;
        case "peripheralBattery":
            return peripheralBatteryComp;
        case "nightlight":
            return nightlightComp;
        case "notifications":
            return notificationsComp;
        default:
            return null;
        }
    }

    Component {
        id: lockstatusComp

        GridLayout {
            columns: root.isHorizontal ? -1 : 1
            rows: root.isHorizontal ? 1 : -1
            flow: root.isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
            columnSpacing: 0
            rowSpacing: 0

            Item {
                implicitWidth: root.isHorizontal ? (Kwin.capsLock ? capslockIcon.implicitWidth : 0) : capslockIcon.implicitWidth
                implicitHeight: root.isHorizontal ? capslockIcon.implicitHeight : (Kwin.capsLock ? capslockIcon.implicitHeight : 0)

                MaterialIcon {
                    id: capslockIcon

                    anchors.centerIn: parent

                    scale: Kwin.capsLock ? 1 : 0.5
                    opacity: Kwin.capsLock ? 1 : 0

                    text: "keyboard_capslock_badge"
                    fontScale: root.iconScale
                    color: root.colour

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    Behavior on scale {
                        Anim {}
                    }
                }

                Behavior on implicitHeight {
                    enabled: !root.isHorizontal

                    Anim {}
                }

                Behavior on implicitWidth {
                    enabled: root.isHorizontal

                    Anim {}
                }
            }

            Item {
                Layout.topMargin: !root.isHorizontal && Kwin.capsLock && Kwin.numLock ? Tokens.spacing.medium / 2 : 0
                Layout.leftMargin: root.isHorizontal && Kwin.capsLock && Kwin.numLock ? Tokens.spacing.medium / 2 : 0

                implicitWidth: root.isHorizontal ? (Kwin.numLock ? numlockIcon.implicitWidth : 0) : numlockIcon.implicitWidth
                implicitHeight: root.isHorizontal ? numlockIcon.implicitHeight : (Kwin.numLock ? numlockIcon.implicitHeight : 0)

                MaterialIcon {
                    id: numlockIcon

                    anchors.centerIn: parent

                    scale: Kwin.numLock ? 1 : 0.5
                    opacity: Kwin.numLock ? 1 : 0

                    text: "looks_one"
                    fontScale: root.iconScale
                    color: root.colour

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    Behavior on scale {
                        Anim {}
                    }
                }

                Behavior on implicitHeight {
                    enabled: !root.isHorizontal

                    Anim {}
                }

                Behavior on implicitWidth {
                    enabled: root.isHorizontal

                    Anim {}
                }
            }
        }
    }

    Component {
        id: audioComp

        MaterialIcon {
            animate: true
            text: Icons.getVolumeIcon(Audio.volume, Audio.muted)
            fontScale: root.iconScale
            color: root.colour
        }
    }

    Component {
        id: microphoneComp

        MaterialIcon {
            animate: true
            text: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
            fontScale: root.iconScale
            color: root.colour
        }
    }

    Component {
        id: privacyComp

        MaterialIcon {
            animate: true
            text: Privacy.microphoneApps.length > 0 ? "mic" : "videocam"
            fontScale: root.iconScale
            color: root.colour
        }
    }

    Component {
        id: kblayoutComp

        StyledText {
            animate: true
            text: Kwin.kbLayout
            color: root.colour
            font: Tokens.font.mono.builders.medium.scale(root.iconScale).build()
        }
    }

    Component {
        id: networkComp

        MaterialIcon {
            animate: true
            text: Nmcli.active ? Icons.getNetworkIcon(WifiSignal.strength) : "wifi_off"
            fontScale: root.iconScale
            color: root.colour
        }
    }

    Component {
        id: ethernetComp

        MaterialIcon {
            animate: true
            text: "cable"
            fontScale: root.iconScale
            color: root.colour
        }
    }

    Component {
        id: bluetoothComp

        GridLayout {
            columns: root.isHorizontal ? -1 : 1
            rows: root.isHorizontal ? 1 : -1
            flow: root.isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
            columnSpacing: Tokens.spacing.medium / 2
            rowSpacing: Tokens.spacing.medium / 2

            MaterialIcon {
                visible: !Bluetooth.defaultAdapter?.enabled || !Bluetooth.devices.values.some(d => d.state !== BluetoothDeviceState.Disconnected) // qmllint disable unresolved-type
                animate: true
                text: {
                    if (!Bluetooth.defaultAdapter?.enabled) // qmllint disable unresolved-type
                        return "bluetooth_disabled";
                    return "bluetooth";
                }
                fontScale: root.iconScale
                color: root.colour
            }

            Repeater {
                model: ScriptModel {
                    values: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected) // qmllint disable unresolved-type
                }

                MaterialIcon {
                    id: device

                    required property BluetoothDevice modelData

                    // Neither connected nor gone: connecting or disconnecting. The dimmed
                    // icon carries that state on its own, so the pulse below is
                    // reinforcement rather than the only thing saying it.
                    readonly property bool pending: modelData?.state !== BluetoothDeviceState.Connected // qmllint disable unresolved-type

                    animate: true
                    text: Icons.getBluetoothIcon(modelData?.icon)
                    color: device.pending ? Qt.alpha(root.colour, 0.5) : root.colour
                    fill: 1
                    fontScale: root.iconScale

                    SequentialAnimation on opacity {
                        running: device.pending && Tokens.anim.enabled
                        alwaysRunToEnd: true
                        loops: Animation.Infinite

                        Anim {
                            from: 1
                            to: 0
                            duration: Tokens.anim.durations.large
                            easing: Tokens.anim.standardAccel
                        }
                        Anim {
                            from: 0
                            to: 1
                            duration: Tokens.anim.durations.large
                            easing: Tokens.anim.standardDecel
                        }
                    }
                }
            }
        }
    }

    Component {
        id: batteryComp

        MaterialIcon {
            animate: true
            text: {
                if (!UPower.displayDevice.isLaptopBattery) {
                    if (PowerProfiles.profile === PowerProfile.PowerSaver)
                        return "energy_savings_leaf";
                    if (PowerProfiles.profile === PowerProfile.Performance)
                        return "rocket_launch";
                    return "balance";
                }
                return Icons.getBatteryIcon(UPower.displayDevice.percentage, [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state));
            }
            color: !UPower.onBattery || UPower.displayDevice.percentage > 0.2 ? root.colour : Colours.palette.m3error
            fill: 1
            fontScale: root.iconScale
        }
    }

    Component {
        id: peripheralBatteryComp

        GridLayout {
            id: peripheralColumn

            readonly property var excluded: Config.bar.status.peripheralBatteryExcluded

            columns: root.isHorizontal ? -1 : 1
            rows: root.isHorizontal ? 1 : -1
            flow: root.isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
            columnSpacing: Tokens.spacing.medium / 2
            rowSpacing: Tokens.spacing.medium / 2

            Repeater {
                model: ScriptModel {
                    values: UPower.devices.values.filter(d => !d.isLaptopBattery && d.type !== UPowerDeviceType.LinePower && d.isPresent && !peripheralColumn.excluded.some(e => e === d.model || e === d.nativePath)) // qmllint disable unresolved-type
                }

                MaterialIcon {
                    required property UPowerDevice modelData

                    animate: true
                    text: {
                        if (modelData.state === UPowerDeviceState.Charging || modelData.state === UPowerDeviceState.PendingCharge)
                            return "battery_charging_full";
                        if (modelData.state === UPowerDeviceState.FullyCharged)
                            return "battery_full";
                        return Icons.getBatteryIcon(modelData.percentage, false);
                    }
                    color: modelData.percentage > 0.2 ? root.colour : Colours.palette.m3error
                    fill: 1
                    fontScale: root.iconScale
                }
            }
        }
    }

    Component {
        id: nightlightComp

        MaterialIcon {
            animate: true
            text: "bedtime"
            fontScale: root.iconScale
            color: root.colour
        }
    }

    Component {
        id: notificationsComp

        MaterialIcon {
            text: {
                if (Notifs.quiet)
                    return "notifications_off";
                if (Notifs.openCount > 0)
                    return "notifications_unread";
                return "notifications";
            }
            fontScale: root.iconScale
            color: root.colour
        }
    }
}
