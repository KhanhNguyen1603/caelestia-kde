pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
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
import qs.modules.nexus

ColumnLayout {
    id: root

    required property PopoutState popouts

    property real scaleOffset: 1.0
    property real fontScale: 1.0
    property bool _isSidebarOpen: false
    property bool wsMenuOpen: false

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
    readonly property var desktopEntry: DockManager.resolveEntry(root.appClass)?.entry ?? null
    readonly property string appName: {
        if (!root.hasActiveWindow)
            return qsTr("Desktop");
        if (root.desktopEntry?.name)
            return root.desktopEntry.name;
        if (root.appClass) {
            const base = root.appClass.split('.').pop() || root.appClass;
            return base.charAt(0).toUpperCase() + base.slice(1);
        }
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
    readonly property int currentWsId: {
        if (root.activeWindow?.workspace?.id !== undefined && root.activeWindow.workspace.id !== -1)
            return root.activeWindow.workspace.id;
        return Kwin.activeWsId;
    }
    readonly property string workspaceLabel: {
        const id = root.currentWsId;
        const wsObj = (Kwin.workspaces || []).find(w => w.index === id || w.id === id);
        if (wsObj && wsObj.name && isNaN(wsObj.name))
            return wsObj.name;
        return (id !== undefined && id > 0) ? qsTr("Workspace %1").arg(id) : qsTr("Workspace 1");
    }
    readonly property var workspacesList: (Kwin.workspaces && Kwin.workspaces.length > 0) ? Kwin.workspaces : [{ id: "1", name: "1", index: 1, active: true }]

    function requestIcon(): void {
        if (root.activeWindow && root.activeWindow.address)
            WinIcons.request(root.appClass, root.windowTitle, root.activeWindow.pid ?? 0, String(root.activeWindow.address));
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

    function selectWorkspace(wsId: int): void {
        if (root.hasActiveWindow) {
            Kwin.setWindowDesktop(root.activeWindow.address, wsId);
        }
        Kwin.setDesktop(wsId);
        root.wsMenuOpen = false;
        root.popouts.hasCurrent = false;
    }

    onActiveWindowChanged: root.requestIcon()

    onAppNamesChanged: root.loadRecents()

    onVisibleChanged: {
        if (!visible)
            root.wsMenuOpen = false;
    }

    Component.onCompleted: {
        root.loadRecents();
        root.requestIcon();
    }

    width: Math.max(300 * scaleOffset, _isSidebarOpen ? (Visibilities.sidebarWidthFor(Tokens.sizes.sidebar.width) * scaleOffset) - Tokens.padding.extraLargeIncreased : 0)
    spacing: Tokens.spacing.medium * scaleOffset

    StyledRect {
        id: headerCard

        Layout.fillWidth: true
        implicitHeight: headerLayout.implicitHeight + Tokens.padding.medium * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Colours.tPalette.m3surfaceContainer
        clip: !root.wsMenuOpen
        z: root.wsMenuOpen ? 200 : 1

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
                            font: Tokens.font.title.builders.small.size(Tokens.font.title.small.pointSize * root.fontScale).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        Item {
                            id: wsSelectorContainer

                            implicitWidth: wsSelectorBtn.implicitWidth
                            implicitHeight: wsSelectorBtn.implicitHeight

                            StyledRect {
                                id: wsSelectorBtn

                                implicitWidth: wsTriggerRow.implicitWidth + Tokens.padding.small * 2 * root.scaleOffset
                                implicitHeight: wsTriggerRow.implicitHeight + Tokens.padding.extraSmall * 2 * root.scaleOffset
                                radius: Tokens.rounding.full
                                color: root.wsMenuOpen ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh

                                RowLayout {
                                    id: wsTriggerRow

                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.extraSmall * root.scaleOffset

                                    StyledText {
                                        id: wsText

                                        Layout.maximumWidth: 140 * root.scaleOffset
                                        elide: Text.ElideRight
                                        text: root.workspaceLabel
                                        font: Tokens.font.label.builders.small.size(Tokens.font.label.small.pointSize * root.fontScale).build()
                                        color: root.wsMenuOpen ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                                    }

                                    MaterialIcon {
                                        text: "expand_more"
                                        fontStyle: Tokens.font.icon.builders.small.size(14 * root.scaleOffset).build()
                                        color: root.wsMenuOpen ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                                        rotation: root.wsMenuOpen ? 180 : 0

                                        Behavior on rotation {
                                            Anim {
                                                type: Anim.DefaultEffects
                                            }
                                        }
                                    }
                                }

                                StateLayer {
                                    anchors.fill: parent
                                    radius: wsSelectorBtn.radius
                                    onClicked: root.wsMenuOpen = !root.wsMenuOpen
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.hasActiveWindow ? (root.windowTitle.length > 0 ? root.windowTitle : root.appName) : qsTr("Active desktop workspace")
                        font: Tokens.font.body.builders.small.size(Tokens.font.body.small.pointSize * root.fontScale).build()
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

        MouseArea {
            id: wsMenuDismissArea

            visible: root.wsMenuOpen
            z: 998
            width: root.width
            height: root.height
            x: -headerCard.x
            y: -headerCard.y
            onClicked: root.wsMenuOpen = false
        }

        TransformWatcher {
            id: wsWatcher

            a: headerCard
            b: wsSelectorBtn
        }

        StyledRect {
            id: wsMenuDropdown

            readonly property real entryHeight: Math.round(32 * root.scaleOffset)
            readonly property real entrySpacing: Tokens.spacing.extraSmall * root.scaleOffset
            readonly property int maxVisibleEntries: 3
            readonly property int entryCount: root.workspacesList.length
            readonly property int visibleEntries: Math.min(entryCount, maxVisibleEntries)
            readonly property real visibleListHeight: entryCount > 0 ? (visibleEntries * entryHeight + (visibleEntries - 1) * entrySpacing) : 0

            visible: root.wsMenuOpen
            z: 999
            x: {
                wsWatcher.transform;
                const pt = wsSelectorBtn.mapToItem(headerCard, wsSelectorBtn.width, 0);
                return Math.max(0, (pt ? pt.x : 0) - width);
            }
            y: {
                wsWatcher.transform;
                const pt = wsSelectorBtn.mapToItem(headerCard, 0, wsSelectorBtn.height);
                return (pt ? pt.y : 0) + Tokens.spacing.extraSmall * root.scaleOffset;
            }
            implicitWidth: Math.max(
                160 * root.scaleOffset,
                wsSelectorBtn.implicitWidth + 36 * root.scaleOffset
            )
            implicitHeight: visibleListHeight + Tokens.padding.small * 2 * root.scaleOffset
            radius: Tokens.rounding.medium * root.scaleOffset
            color: Colours.tPalette.m3surfaceContainerHighest
            border.color: Colours.palette.m3outlineVariant
            border.width: 1

            Connections {
                function onWsMenuOpenChanged(): void {
                    if (root.wsMenuOpen && wsMenuDropdown.entryCount > wsMenuDropdown.maxVisibleEntries) {
                        Qt.callLater(() => {
                            const list = root.workspacesList || [];
                            const idx = list.findIndex((w, i) => (w.index ?? (i + 1)) === root.currentWsId);
                            if (idx > 0) {
                                const targetY = Math.max(0, Math.min(
                                    wsFlickable.contentHeight - wsFlickable.height,
                                    idx * (wsMenuDropdown.entryHeight + wsMenuDropdown.entrySpacing)
                                ));
                                wsFlickable.contentY = targetY;
                            } else {
                                wsFlickable.contentY = 0;
                            }
                        });
                    }
                }

                target: root
            }

            Flickable {
                id: wsFlickable

                anchors.fill: parent
                anchors.margins: Tokens.padding.small * root.scaleOffset
                contentWidth: width
                contentHeight: wsItemsCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                WheelHandler {
                    acceptedModifiers: Qt.NoModifier
                    onWheel: event => {
                        if (wsFlickable.contentHeight > wsFlickable.height) {
                            wsFlickable.contentY = Math.max(0, Math.min(wsFlickable.contentHeight - wsFlickable.height, wsFlickable.contentY - event.angleDelta.y));
                        }
                    }
                }

                ScrollBar.vertical: StyledScrollBar {
                    flickable: wsFlickable
                }

                Column {
                    id: wsItemsCol

                    width: wsFlickable.width - (wsMenuDropdown.entryCount > wsMenuDropdown.maxVisibleEntries ? (Tokens.padding.small * root.scaleOffset) : 0)
                    spacing: wsMenuDropdown.entrySpacing

                    Repeater {
                        model: root.workspacesList

                        StyledRect {
                            id: wsItemPill

                            required property var modelData
                            required property int index

                            readonly property int wsId: modelData.index ?? (index + 1)
                            readonly property bool isSelected: root.currentWsId === wsId

                            width: parent.width
                            height: wsMenuDropdown.entryHeight
                            implicitHeight: wsMenuDropdown.entryHeight
                            radius: Tokens.rounding.full
                            color: isSelected ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh

                            RowLayout {
                                id: wsItemContent

                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.medium * root.scaleOffset
                                anchors.rightMargin: Tokens.padding.medium * root.scaleOffset
                                spacing: Tokens.spacing.extraSmall * root.scaleOffset

                                StyledText {
                                    id: wsItemText

                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: {
                                        if (wsItemPill.modelData.name && isNaN(wsItemPill.modelData.name))
                                            return wsItemPill.modelData.name;
                                        return qsTr("Workspace %1").arg(wsItemPill.wsId);
                                    }
                                    font: Tokens.font.label.builders.small.size(Tokens.font.label.small.pointSize * root.fontScale).build()
                                    color: wsItemPill.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                }

                                MaterialIcon {
                                    visible: wsItemPill.isSelected
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "check"
                                    fontStyle: Tokens.font.icon.builders.small.size(14 * root.scaleOffset).build()
                                    color: Colours.palette.m3onPrimary
                                }
                            }

                            StateLayer {
                                anchors.fill: parent
                                radius: wsItemPill.radius
                                onClicked: root.selectWorkspace(wsItemPill.wsId)
                            }
                        }
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
                        elide: Text.ElideRight
                        text: qsTr("Open application menu")
                        font: Tokens.font.body.builders.medium.size(Tokens.font.body.medium.pointSize * root.fontScale).build()
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
                        if (root.desktopEntry) {
                            Launch.launchEntry(root.desktopEntry);
                        } else if (root.appClass) {
                            const bin = root.appClass.split('.').pop() || root.appClass;
                            Launch.exec([bin]);
                        }
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
                        elide: Text.ElideRight
                        text: qsTr("Open new window")
                        font: Tokens.font.body.builders.medium.size(Tokens.font.body.medium.pointSize * root.fontScale).build()
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
                        elide: Text.ElideRight
                        text: qsTr("Show all windows")
                        font: Tokens.font.body.builders.medium.size(Tokens.font.body.medium.pointSize * root.fontScale).build()
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
                elide: Text.ElideRight
                text: qsTr("Windows (%1)").arg(root.allAppWindows.length)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.builders.medium.size(Tokens.font.label.medium.pointSize * root.fontScale).build()
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
                            font: Tokens.font.body.builders.small.size(Tokens.font.body.small.pointSize * root.fontScale).build()
                            color: winRow.isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            visible: winRow.modelData?.workspace?.id !== undefined && winRow.modelData?.workspace?.id !== -1
                            text: qsTr("W%1").arg(winRow.modelData?.workspace?.id ?? "")
                            font: Tokens.font.label.builders.small.size(Tokens.font.label.small.pointSize * root.fontScale).build()
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
                elide: Text.ElideRight
                text: qsTr("Recent files")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.builders.medium.size(Tokens.font.label.medium.pointSize * root.fontScale).build()
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
                            font: Tokens.font.body.builders.small.size(Tokens.font.body.small.pointSize * root.fontScale).build()
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
                elide: Text.ElideRight
                text: qsTr("Quick actions")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.builders.medium.size(Tokens.font.label.medium.pointSize * root.fontScale).build()
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
                        elide: Text.ElideRight
                        text: qsTr("Open applications launcher")
                        font: Tokens.font.body.builders.medium.size(Tokens.font.body.medium.pointSize * root.fontScale).build()
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
                        WindowFactory.create();
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
                        elide: Text.ElideRight
                        text: qsTr("System settings")
                        font: Tokens.font.body.builders.medium.size(Tokens.font.body.medium.pointSize * root.fontScale).build()
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
                        Visibilities.toggleLauncher("wallpaper");
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
                        elide: Text.ElideRight
                        text: qsTr("Change wallpaper")
                        font: Tokens.font.body.builders.medium.size(Tokens.font.body.medium.pointSize * root.fontScale).build()
                        color: Colours.palette.m3onSurface
                    }
                }
            }
        }
    }
}
