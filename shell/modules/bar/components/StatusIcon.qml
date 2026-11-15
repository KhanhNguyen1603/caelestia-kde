pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.bar

// One status icon. Each icon is a bar widget of its own instead of a cell in a
// shared row, so the bar can drag them one at a time and the hidden-icons box can
// hold a single one.
Item {
    id: root

    required property string entryId
    property var popouts
    property var bar
    property bool draggable: false

    readonly property string iconId: BarWidgets.statusIconId(root.entryId)
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

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property real rawScale: !isNaN(Config.bar.scale) ? Config.bar.scale : 1.0
    readonly property real scaleFactor: rawScale < 1.0 ? Math.sqrt(Math.max(0.1, rawScale)) : rawScale
    readonly property int barThickness: Math.round(Tokens.sizes.bar.innerWidth * scaleFactor)
    readonly property color colour: Colours.palette.m3secondary
    readonly property bool dragging: dragGesture.active

    function openPopout(): void {
        const popouts = root.popouts;
        if (!popouts)
            return;

        if (popouts.hasCurrent && popouts.currentName === root.popoutName) {
            popouts.hasCurrent = false;
            return;
        }

        popouts.currentName = root.popoutName;
        popouts.currentCenter = root.isHorizontal ? root.mapToItem(null, root.width / 2, 0).x : root.mapToItem(null, 0, root.height / 2).y;
        popouts.hasCurrent = true;
    }

    function openContextMenu(): void {
        const popouts = root.popouts;
        if (!popouts)
            return;

        if (popouts.hasCurrent && popouts.currentName === "statusiconscontext") {
            popouts.hasCurrent = false;
            return;
        }

        popouts.currentName = "statusiconscontext";
        popouts.currentCenter = root.isHorizontal ? root.mapToItem(null, root.width / 2, 0).x : root.mapToItem(null, 0, root.height / 2).y;
        popouts.hasCurrent = true;
    }

    implicitWidth: root.isHorizontal ? loader.implicitWidth : root.barThickness
    implicitHeight: root.isHorizontal ? root.barThickness : loader.implicitHeight
    // Fading only once the ghost exists keeps the snapshot clean and means the icon
    // never disappears before there is something under the pointer to replace it.
    opacity: root.dragging && TrayDrag.ghost !== null ? 0.35 : 1

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    // Each icon is lifted on its own, so it carries the gesture instead of leaving
    // it to the wrapper the bar draws it in.
    TrayDragGesture {
        id: dragGesture

        widgetId: root.entryId
        enabled: root.draggable
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.openContextMenu();
                return;
            }

            if (root.iconId === "notifications") {
                // Hovering the bell may have opened the small notification popout
                // already; leaving it open on top of the sidebar makes both panels
                // jitter.
                if (root.popouts)
                    root.popouts.hasCurrent = false;

                const vis = root.bar?.visibilities ?? Visibilities.getForActive();
                vis.sidebar = !vis.sidebar;
                return;
            }

            // Hover popouts are a convenience, not the only way in: a click opens
            // the same popout when they are disabled.
            root.openPopout();
        }
    }

    Loader {
        id: loader

        anchors.centerIn: parent

        sourceComponent: {
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
            color: root.colour
        }
    }

    Component {
        id: microphoneComp

        MaterialIcon {
            animate: true
            text: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
            color: root.colour
        }
    }

    Component {
        id: privacyComp

        MaterialIcon {
            animate: true
            text: Privacy.microphoneApps.length > 0 ? "mic" : "videocam"
            color: root.colour
        }
    }

    Component {
        id: kblayoutComp

        StyledText {
            animate: true
            text: Kwin.kbLayout
            color: root.colour
            font: Tokens.font.mono.medium
        }
    }

    Component {
        id: networkComp

        MaterialIcon {
            animate: true
            text: Nmcli.active ? Icons.getNetworkIcon(WifiSignal.strength) : "wifi_off"
            color: root.colour
        }
    }

    Component {
        id: ethernetComp

        MaterialIcon {
            animate: true
            text: "cable"
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
                }
            }
        }
    }

    Component {
        id: nightlightComp

        MaterialIcon {
            animate: true
            text: "bedtime"
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
            color: root.colour
        }
    }
}
