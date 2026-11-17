pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

QtObject {
    readonly property string assetDir: "../../assets/whatsnew/"

    readonly property var list: [
        {
            "id": "unified_tray",
            "revision": 90,
            "version": "2.7.5",
            "date": "2026-11-17",
            "icon": "grid_view",
            "title": qsTr("One System Tray"),
            "settingsPage": "panels",
            "settingsSubPage": "barTray",
            "description": qsTr("Icons and bar widgets share one tray, with a box for the ones that do not fit and drag and drop between them.")
        },
        {
            "id": "lockscreen_frost",
            "revision": 91,
            "version": "2.7.5",
            "date": "2026-11-17",
            "icon": "blur_on",
            "title": qsTr("Frosted Lock Screen"),
            "description": qsTr("The lock screen thaws in through a frosted copy of the desktop instead of cutting to black first.")
        },
        {
            "id": "launcher_greeting",
            "revision": 92,
            "version": "2.7.5",
            "date": "2026-11-17",
            "icon": "waving_hand",
            "title": qsTr("A Greeting in the Launcher"),
            "description": qsTr("The modern launcher greets you by name, and the avatar floats without a card behind it.")
        },
        {
            "id": "keepawake_expiry",
            "revision": 93,
            "version": "2.7.5",
            "date": "2026-11-17",
            "icon": "timer",
            "title": qsTr("Keep Awake Expiry"),
            "settingsPage": "panels",
            "settingsSubPage": "barKeepAwake",
            "description": qsTr("Choose how long Keep Awake lasts from the widget menu, and see when it runs out.")
        }
    ]

    function mediaSource(entry: var): url {
        if (!entry || !entry.mediaUrl)
            return "";
        if (entry.mediaUrl.startsWith("root:"))
            return Qt.resolvedUrl(`${Quickshell.shellDir}${entry.mediaUrl.slice("root:".length)}`);
        return Qt.resolvedUrl(`${assetDir}${entry.mediaUrl}`);
    }
}
