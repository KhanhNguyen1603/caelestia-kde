pragma Singleton

import QtQuick

// What an icon the bar can show is called and drawn as. The status icons are declared
// by the config and the icon widgets by the bar's own list, so neither carries a name
// of its own; the places that list them outside the editor ask here instead.
QtObject {
    id: root

    readonly property var statusIcons: ({
            lockStatus: { name: qsTr("Lock keys"), icon: "keyboard_capslock" },
            privacy: { name: qsTr("Privacy"), icon: "visibility_off" },
            kbLayout: { name: qsTr("Keyboard layout"), icon: "keyboard" },
            audio: { name: qsTr("Speakers"), icon: "volume_up" },
            microphone: { name: qsTr("Microphone"), icon: "mic" },
            network: { name: qsTr("Network"), icon: "wifi" },
            ethernet: { name: qsTr("Ethernet"), icon: "settings_ethernet" },
            bluetooth: { name: qsTr("Bluetooth"), icon: "bluetooth" },
            battery: { name: qsTr("Battery"), icon: "battery_full" },
            peripheralBattery: { name: qsTr("Device battery"), icon: "battery_5_bar" },
            nightlight: { name: qsTr("Night light"), icon: "bedtime" },
            notifications: { name: qsTr("Notifications"), icon: "notifications" }
        })

    // The bar's own icons: the widgets that sit beside the status icons rather than
    // being a piece of the bar of their own.
    readonly property var widgets: ({
            keepawake: { name: qsTr("Keep awake"), icon: "coffee" },
            updateIndicator: { name: qsTr("Updates"), icon: "update" }
        })

    function nameOf(id: string): string {
        return (root.statusIcons[id] ?? root.widgets[id] ?? { name: id }).name;
    }

    function iconOf(id: string): string {
        return (root.statusIcons[id] ?? root.widgets[id] ?? { icon: "widgets" }).icon;
    }
}
