pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

QtObject {
    readonly property string assetDir: "../../assets/whatsnew/"

    readonly property var list: [
        {
            "id": "floating_dock",
            "revision": 94,
            "version": "2.7.6",
            "date": "2026-11-23",
            "icon": "dock",
            "title": qsTr("A Dock You Can Shape"),
            "settingsPage": "panels",
            "settingsSubPage": "barDock",
            "description": qsTr("Pin apps to a dock that floats clear of the screen edge, with its own length, icon size, labels and launch indicator.")
        },
        {
            "id": "app_menu",
            "revision": 95,
            "version": "2.7.6",
            "date": "2026-11-23",
            "icon": "menu",
            "title": qsTr("App Menu in the Bar"),
            "settingsPage": "panels",
            "settingsSubPage": "barAppMenu",
            "description": qsTr("Show the focused app's menu and icon in the bar, and open a workspace picker from its popout.")
        },
        {
            "id": "window_switcher_grid",
            "revision": 96,
            "version": "2.7.6",
            "date": "2026-11-23",
            "icon": "grid_view",
            "title": qsTr("Alt+Tab as a Grid"),
            "settingsPage": "panels",
            "settingsSubPage": "tabSwitcher",
            "description": qsTr("Switch the window switcher to a grid, keeping each preview's shape and place from the overview.")
        },
        {
            "id": "updates_page",
            "revision": 97,
            "version": "2.7.6",
            "date": "2026-11-23",
            "icon": "system_update",
            "title": qsTr("Updates in One Place"),
            "settingsPage": "updates",
            "description": qsTr("Run an update in place and follow its stages, with the status card and history on the same page.")
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
