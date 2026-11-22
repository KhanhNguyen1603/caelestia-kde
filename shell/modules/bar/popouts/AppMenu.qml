pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property PopoutState popouts

    property real scaleOffset: 1.0
    property real fontScale: 1.0
    property bool _isSidebarOpen: false

    readonly property string targetAddress: root.popouts?.selectedClientAddress ?? ""
    readonly property var activeWindow: {
        if (root.targetAddress) {
            const found = (Kwin.windowList || []).find(w => w.address === root.targetAddress);
            if (found && !found.minimized)
                return found;
        }
        return Kwin.openedApp(Kwin.activeOutputName || "");
    }
    readonly property bool hasActiveWindow: Boolean(activeWindow && activeWindow.address)
    readonly property string appClass: activeWindow?.class || ""
    readonly property string windowTitle: activeWindow?.title || ""
    readonly property var desktopEntry: DockManager.resolveEntry(root.appClass)
    readonly property string appName: {
        if (!root.hasActiveWindow)
            return qsTr("Desktop");
        if (root.desktopEntry?.name)
            return root.desktopEntry.name;
        if (root.appClass)
            return root.appClass.charAt(0).toUpperCase() + root.appClass.slice(1);
        return qsTr("App Menu");
    }

    readonly property string iconSource: {
        if (!root.hasActiveWindow)
            return "";
        if (root.desktopEntry) {
            const src = WinIcons.sourceFor(root.desktopEntry, root.appClass, root.activeWindow?.iconName ?? "", root.activeWindow?.pid ?? 0);
            if (src)
                return src;
        }
        if (root.activeWindow) {
            const src = WinIcons.sourceForClient(root.activeWindow);
            if (src)
                return src;
        }
        return Icons.getAppIcon(root.appClass, "application-x-executable");
    }

    readonly property var appNames: [root.appClass, root.desktopEntry?.id, activeWindow?.class].filter(name => typeof name === "string" && name.length > 0)
    readonly property var allAppWindows: {
        if (!root.hasActiveWindow || !root.appClass)
            return [];
        return (Kwin.windowList || []).filter(w => w && (w.class === root.appClass || (root.desktopEntry && Kwin.windowMatchesApp(w, [root.desktopEntry.id]))));
    }
    readonly property bool hasMultipleWindows: allAppWindows.length > 1
    readonly property bool hasNativeMenu: Boolean(activeWindow?.menuService && activeWindow?.menuObject)
    readonly property string workspaceLabel: {
        if (!activeWindow || !activeWindow.workspace)
            return "";
        const id = activeWindow.workspace.id;
        return (id !== undefined && id !== -1) ? qsTr("Workspace %1").arg(id) : "";
    }

    function loadRecents(): void {
        Recents.load(root.appNames);
    }

    function openRecent(entry: var): void {
        Launch.exec(["xdg-open", entry.path]);
        root.popouts.hasCurrent = false;
    }

    function triggerNativeMenu(): void {
        const center = root.popouts.currentCenter;
        const x = root.popouts.isHorizontal ? Math.round(center) : Math.round(root.width);
        const y = root.popouts.isHorizontal ? Math.round(Tokens.sizes.bar.innerWidth) : Math.round(center);
        Kwin.showAppMenu(root.activeWindow?.menuService ?? "", root.activeWindow?.menuObject ?? "", x, y, 0);
        root.popouts.hasCurrent = false;
    }

    onActiveWindowChanged: {
        if (root.activeWindow && root.activeWindow.address) {
            WinIcons.request(root.appClass, root.windowTitle, root.activeWindow.pid ?? 0, String(root.activeWindow.address));
        }
    }

    onAppNamesChanged: root.loadRecents()

    Component.onCompleted: {
        root.loadRecents();
        if (root.activeWindow && root.activeWindow.address) {
            WinIcons.request(root.appClass, root.windowTitle, root.activeWindow.pid ?? 0, String(root.activeWindow.address));
        }
    }

    width: Math.max(300 * scaleOffset, _isSidebarOpen ? (Visibilities.sidebarWidthFor(Tokens.sizes.sidebar.width) * scaleOffset) - Tokens.padding.extraLargeIncreased : 0)
    spacing: Tokens.spacing.medium * scaleOffset

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: headerLayout.implicitHeight + Tokens.padding.medium * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: headerLayout

            width: parent.width - Tokens.padding.medium * 2 * root.scaleOffset
            x: Tokens.padding.medium * root.scaleOffset
            y: Tokens.padding.medium * root.scaleOffset
            spacing: Tokens.spacing.small * root.scaleOffset

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium * root.scaleOffset

                Item {
                    implicitWidth: 44 * root.scaleOffset
                    implicitHeight: 44 * root.scaleOffset

                    MaterialIcon {
                        visible: !root.hasActiveWindow
                        anchors.centerIn: parent
                        text: "monitor"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.builders.small.size(36 * root.scaleOffset).build()
                    }

                    CachingIconImage {
                        visible: root.hasActiveWindow && root.iconSource.length > 0
                        anchors.centerIn: parent
                        source: root.iconSource
                        implicitSize: 44 * root.scaleOffset
                        width: 44 * root.scaleOffset
                        height: 44 * root.scaleOffset
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            Layout.fillWidth: true
                            text: root.appName
                            font: Tokens.font.title.small
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledRect {
                            visible: root.workspaceLabel.length > 0
                            implicitWidth: wsText.implicitWidth + Tokens.padding.small * 2 * root.scaleOffset
                            implicitHeight: wsText.implicitHeight + Tokens.padding.extraSmall * root.scaleOffset
                            radius: Tokens.rounding.full
                            color: Colours.tPalette.m3surfaceContainerHigh

                            StyledText {
                                id: wsText

                                anchors.centerIn: parent
                                text: root.workspaceLabel
                                font: Tokens.font.label.small
                                color: Colours.palette.m3primary
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.hasActiveWindow ? (root.windowTitle.length > 0 ? root.windowTitle : root.appName) : qsTr("Active desktop workspace")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                visible: root.hasActiveWindow
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall * root.scaleOffset

                StyledRect {
                    id: minBtn

                    Layout.fillWidth: true
                    implicitHeight: 32 * root.scaleOffset
                    radius: Tokens.rounding.small * root.scaleOffset
                    color: Colours.tPalette.m3surfaceContainerHigh

                    StateLayer {
                        anchors.fill: parent
                        radius: minBtn.radius
                        onClicked: {
                            Kwin.minimizeWindow(root.activeWindow.address);
                            root.popouts.hasCurrent = false;
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "minimize"
                        color: Colours.palette.m3onSurface
                        fontStyle: Tokens.font.icon.builders.small.size(18 * root.scaleOffset).build()
                    }
                }

                StyledRect {
                    id: maxBtn

                    Layout.fillWidth: true
                    implicitHeight: 32 * root.scaleOffset
                    radius: Tokens.rounding.small * root.scaleOffset
                    color: Colours.tPalette.m3surfaceContainerHigh

                    StateLayer {
                        anchors.fill: parent
                        radius: maxBtn.radius
                        onClicked: {
                            const isMax = Boolean(root.activeWindow.maximized);
                            Kwin.maximizeWindow(root.activeWindow.address, !isMax, !isMax);
                            root.popouts.hasCurrent = false;
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: root.activeWindow?.maximized ? "fullscreen_exit" : "crop_square"
                        color: Colours.palette.m3onSurface
                        fontStyle: Tokens.font.icon.builders.small.size(18 * root.scaleOffset).build()
                    }
                }

                StyledRect {
                    id: fsBtn

                    Layout.fillWidth: true
                    implicitHeight: 32 * root.scaleOffset
                    radius: Tokens.rounding.small * root.scaleOffset
                    color: Colours.tPalette.m3surfaceContainerHigh

                    StateLayer {
                        anchors.fill: parent
                        radius: fsBtn.radius
                        onClicked: {
                            const isFs = Boolean(root.activeWindow.fullscreen);
                            Kwin.setFullscreen(root.activeWindow.address, !isFs);
                            root.popouts.hasCurrent = false;
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: root.activeWindow?.fullscreen ? "close_fullscreen" : "fullscreen"
                        color: Colours.palette.m3onSurface
                        fontStyle: Tokens.font.icon.builders.small.size(18 * root.scaleOffset).build()
                    }
                }

                StyledRect {
                    id: closeBtn

                    Layout.fillWidth: true
                    implicitHeight: 32 * root.scaleOffset
                    radius: Tokens.rounding.small * root.scaleOffset
                    color: Qt.alpha(Colours.palette.m3error, 0.15)

                    StateLayer {
                        anchors.fill: parent
                        radius: closeBtn.radius
                        onClicked: {
                            Kwin.closeWindow(root.activeWindow.address);
                            root.popouts.hasCurrent = false;
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "close"
                        color: Colours.palette.m3error
                        fontStyle: Tokens.font.icon.builders.small.size(18 * root.scaleOffset).build()
                    }
                }
            }
        }
    }

    StyledRect {
        visible: root.hasActiveWindow
        Layout.fillWidth: true
        implicitHeight: actionsLayout.implicitHeight + Tokens.padding.medium * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: actionsLayout

            width: parent.width - Tokens.padding.medium * 2 * root.scaleOffset
            x: Tokens.padding.medium * root.scaleOffset
            y: Tokens.padding.medium * root.scaleOffset
            spacing: Tokens.spacing.extraSmall * root.scaleOffset

            StyledRect {
                id: nativeMenuRow

                visible: root.hasNativeMenu
                Layout.fillWidth: true
                implicitHeight: 36 * root.scaleOffset
                radius: Tokens.rounding.small * root.scaleOffset
                color: "transparent"

                StateLayer {
                    anchors.fill: parent
                    radius: nativeMenuRow.radius
                    onClicked: root.triggerNativeMenu()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.small * root.scaleOffset
                    anchors.rightMargin: Tokens.padding.small * root.scaleOffset
                    spacing: Tokens.spacing.small * root.scaleOffset

                    MaterialIcon {
                        text: "menu"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.builders.small.size(20 * root.scaleOffset).build()
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Open application menu")
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3primary
                    }

                    MaterialIcon {
                        text: "chevron_right"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.builders.small.size(18 * root.scaleOffset).build()
                    }
                }
            }

            StyledRect {
                id: newWinRow

                Layout.fillWidth: true
                implicitHeight: 36 * root.scaleOffset
                radius: Tokens.rounding.small * root.scaleOffset
                color: "transparent"

                StateLayer {
                    anchors.fill: parent
                    radius: newWinRow.radius
                    onClicked: {
                        if (root.desktopEntry)
                            Launch.launchEntry(root.desktopEntry);
                        else if (root.appClass)
                            Launch.exec([root.appClass]);
                        root.popouts.hasCurrent = false;
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.small * root.scaleOffset
                    anchors.rightMargin: Tokens.padding.small * root.scaleOffset
                    spacing: Tokens.spacing.small * root.scaleOffset

                    MaterialIcon {
                        text: "add_box"
                        color: Colours.palette.m3onSurface
                        fontStyle: Tokens.font.icon.builders.small.size(20 * root.scaleOffset).build()
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Open new window")
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurface
                    }
                }
            }

            StyledRect {
                id: allWinsRow

                visible: root.allAppWindows.length > 0
                Layout.fillWidth: true
                implicitHeight: 36 * root.scaleOffset
                radius: Tokens.rounding.small * root.scaleOffset
                color: "transparent"

                StateLayer {
                    anchors.fill: parent
                    radius: allWinsRow.radius
                    onClicked: {
                        Visibilities.showAppWindows(root.appNames);
                        root.popouts.hasCurrent = false;
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.small * root.scaleOffset
                    anchors.rightMargin: Tokens.padding.small * root.scaleOffset
                    spacing: Tokens.spacing.small * root.scaleOffset

                    MaterialIcon {
                        text: "view_quilt"
                        color: Colours.palette.m3onSurface
                        fontStyle: Tokens.font.icon.builders.small.size(20 * root.scaleOffset).build()
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Show all windows")
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurface
                    }
                }
            }
        }
    }

    StyledRect {
        visible: root.hasMultipleWindows
        Layout.fillWidth: true
        implicitHeight: winSwitcherLayout.implicitHeight + Tokens.padding.medium * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: winSwitcherLayout

            width: parent.width - Tokens.padding.medium * 2 * root.scaleOffset
            x: Tokens.padding.medium * root.scaleOffset
            y: Tokens.padding.medium * root.scaleOffset
            spacing: Tokens.spacing.extraSmall * root.scaleOffset

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.padding.extraSmall * root.scaleOffset
                text: qsTr("Windows (%1)").arg(root.allAppWindows.length)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            Repeater {
                model: ScriptModel {
                    values: [...root.allAppWindows]
                }

                delegate: StyledRect {
                    id: winRow

                    required property var modelData

                    readonly property bool isCurrent: modelData && root.activeWindow && modelData.address === root.activeWindow.address

                    Layout.fillWidth: true
                    implicitHeight: 36 * root.scaleOffset
                    radius: Tokens.rounding.small * root.scaleOffset
                    color: winRow.isCurrent ? Colours.tPalette.m3surfaceContainerHigh : "transparent"

                    StateLayer {
                        anchors.fill: parent
                        radius: winRow.radius
                        onClicked: {
                            Kwin.focusWindow(winRow.modelData.address);
                            root.popouts.hasCurrent = false;
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.small * root.scaleOffset
                        anchors.rightMargin: Tokens.padding.small * root.scaleOffset
                        spacing: Tokens.spacing.small * root.scaleOffset

                        MaterialIcon {
                            text: winRow.isCurrent ? "radio_button_checked" : "radio_button_unchecked"
                            color: winRow.isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.builders.small.size(16 * root.scaleOffset).build()
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: (winRow.modelData?.title && winRow.modelData.title.length > 0) ? winRow.modelData.title : root.appName
                            font: Tokens.font.body.small
                            color: winRow.isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            visible: winRow.modelData?.workspace?.id !== undefined && winRow.modelData?.workspace?.id !== -1
                            text: qsTr("W%1").arg(winRow.modelData?.workspace?.id ?? "")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        MaterialIcon {
                            text: "close"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.builders.small.size(16 * root.scaleOffset).build()

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    mouse.accepted = true;
                                    Kwin.closeWindow(winRow.modelData.address);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    StyledRect {
        visible: Recents.entries.length > 0 && root.hasActiveWindow
        Layout.fillWidth: true
        implicitHeight: recentLayout.implicitHeight + Tokens.padding.medium * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: recentLayout

            width: parent.width - Tokens.padding.medium * 2 * root.scaleOffset
            x: Tokens.padding.medium * root.scaleOffset
            y: Tokens.padding.medium * root.scaleOffset
            spacing: Tokens.spacing.extraSmall * root.scaleOffset

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.padding.extraSmall * root.scaleOffset
                text: qsTr("Recent files")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            Repeater {
                model: ScriptModel {
                    values: [...Recents.entries]
                }

                delegate: StyledRect {
                    id: recentRow

                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 32 * root.scaleOffset
                    radius: Tokens.rounding.small * root.scaleOffset
                    color: "transparent"

                    StateLayer {
                        anchors.fill: parent
                        radius: recentRow.radius
                        onClicked: root.openRecent(recentRow.modelData)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.small * root.scaleOffset
                        anchors.rightMargin: Tokens.padding.small * root.scaleOffset
                        spacing: Tokens.spacing.small * root.scaleOffset

                        MaterialIcon {
                            text: "description"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.builders.small.size(16 * root.scaleOffset).build()
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: recentRow.modelData?.name ?? ""
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    StyledRect {
        visible: !root.hasActiveWindow
        Layout.fillWidth: true
        implicitHeight: desktopLayout.implicitHeight + Tokens.padding.medium * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: desktopLayout

            width: parent.width - Tokens.padding.medium * 2 * root.scaleOffset
            x: Tokens.padding.medium * root.scaleOffset
            y: Tokens.padding.medium * root.scaleOffset
            spacing: Tokens.spacing.extraSmall * root.scaleOffset

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.padding.extraSmall * root.scaleOffset
                text: qsTr("Quick actions")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            StyledRect {
                id: launcherRow

                Layout.fillWidth: true
                implicitHeight: 36 * root.scaleOffset
                radius: Tokens.rounding.small * root.scaleOffset
                color: "transparent"

                StateLayer {
                    anchors.fill: parent
                    radius: launcherRow.radius
                    onClicked: {
                        Visibilities.toggleLauncher("");
                        root.popouts.hasCurrent = false;
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.small * root.scaleOffset
                    anchors.rightMargin: Tokens.padding.small * root.scaleOffset
                    spacing: Tokens.spacing.small * root.scaleOffset

                    MaterialIcon {
                        text: "apps"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.builders.small.size(20 * root.scaleOffset).build()
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Open applications launcher")
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurface
                    }
                }
            }

            StyledRect {
                id: nexusRow

                Layout.fillWidth: true
                implicitHeight: 36 * root.scaleOffset
                radius: Tokens.rounding.small * root.scaleOffset
                color: "transparent"

                StateLayer {
                    anchors.fill: parent
                    radius: nexusRow.radius
                    onClicked: {
                        Visibilities.toggleNexus();
                        root.popouts.hasCurrent = false;
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.small * root.scaleOffset
                    anchors.rightMargin: Tokens.padding.small * root.scaleOffset
                    spacing: Tokens.spacing.small * root.scaleOffset

                    MaterialIcon {
                        text: "settings"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.builders.small.size(20 * root.scaleOffset).build()
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("System settings")
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurface
                    }
                }
            }

            StyledRect {
                id: wallpaperRow

                Layout.fillWidth: true
                implicitHeight: 36 * root.scaleOffset
                radius: Tokens.rounding.small * root.scaleOffset
                color: "transparent"

                StateLayer {
                    anchors.fill: parent
                    radius: wallpaperRow.radius
                    onClicked: {
                        Visibilities.toggleLauncher("wallpapers");
                        root.popouts.hasCurrent = false;
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.small * root.scaleOffset
                    anchors.rightMargin: Tokens.padding.small * root.scaleOffset
                    spacing: Tokens.spacing.small * root.scaleOffset

                    MaterialIcon {
                        text: "wallpaper"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.builders.small.size(20 * root.scaleOffset).build()
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Change wallpaper")
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurface
                    }
                }
            }
        }
    }
}
