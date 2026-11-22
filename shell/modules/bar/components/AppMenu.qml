pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services
import qs.utils

StyledRect {
    id: root

    required property var bar

    readonly property var popouts: root.bar?.popouts ?? null
    readonly property bool isHorizontal: root.bar?.isHorizontal ?? false
    readonly property real rawScale: !isNaN(Config.bar.scale) ? Config.bar.scale : 1.0
    readonly property real scaleFactor: rawScale < 1.0 ? Math.sqrt(Math.max(0.1, rawScale)) : rawScale
    readonly property int barThickness: Math.round(Tokens.sizes.bar.innerWidth * scaleFactor)
    readonly property int baseThickness: Tokens.sizes.bar.innerWidth
    readonly property int effectiveThickness: rawScale < 1.0 ? baseThickness : barThickness
    readonly property int iconSize: Math.round(effectiveThickness * 0.44)
    readonly property int textSize: Math.round(effectiveThickness * 0.32)

    readonly property color colour: Colours.palette.m3onSurface
    readonly property int padding: Tokens.padding.small

    readonly property string screenName: root.bar?.screen?.name ?? ""
    readonly property var activeWindow: Kwin.openedApp(root.screenName)
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

    readonly property bool isCompact: Config.bar.appmenu.compact || !root.isHorizontal
    readonly property bool showTitle: Config.bar.appmenu.showTitle && !root.isCompact
    readonly property bool showIcon: Config.bar.appmenu.showIcon
    readonly property bool showChevron: Config.bar.appmenu.showChevron && !root.isCompact
    readonly property bool isPopoutOpen: Boolean(root.popouts?.hasCurrent && (root.popouts?.currentName === "appmenu" || root.popouts?.currentName === "appmenucontext"))
    readonly property string tooltipText: {
        if (!root.hasActiveWindow)
            return qsTr("App menu (Desktop)");
        return root.windowTitle.length > 0
            ? `${root.appName}: ${root.windowTitle}`
            : root.appName;
    }

    function requestIcon(): void {
        if (root.activeWindow && root.activeWindow.address)
            WinIcons.request(root.appClass, root.windowTitle, root.activeWindow.pid ?? 0, String(root.activeWindow.address));
    }

    function centerFor(): real {
        return root.isHorizontal
            ? root.mapToItem(null, root.implicitWidth / 2, 0).x
            : (root.mapToItem(null, 0, root.implicitHeight / 2).y ?? 0);
    }

    function openPopout(name: string): void {
        const popouts = root.popouts;
        if (!popouts)
            return;

        if (popouts.selectedClientAddress !== undefined)
            popouts.selectedClientAddress = root.activeWindow?.address ?? "";
        popouts.currentName = name;
        popouts.currentCenter = root.centerFor();
        popouts.hasCurrent = true;
        popouts.staysOpen = true;
    }

    visible: enabled && (!Config.bar.appmenu.autoHide || root.hasActiveWindow)
    radius: Tokens.rounding.full
    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, 0.45)
    implicitWidth: isHorizontal
        ? Math.max(root.effectiveThickness, (contentLayout.implicitWidth + root.padding * 2))
        : root.barThickness
    implicitHeight: isHorizontal
        ? root.barThickness
        : Math.max(root.effectiveThickness, (contentLayout.implicitHeight + root.padding * 2))

    onActiveWindowChanged: root.requestIcon()

    Component.onCompleted: root.requestIcon()

    StateLayer {
        anchors.fill: parent
        radius: root.radius
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            const popouts = root.popouts;
            if (!popouts)
                return;

            if (mouse.button === Qt.RightButton) {
                if (popouts.hasCurrent && popouts.currentName === "appmenucontext") {
                    popouts.hasCurrent = false;
                } else {
                    root.openPopout("appmenucontext");
                }
            } else if (mouse.button === Qt.MiddleButton) {
                if (root.desktopEntry) {
                    Launch.launchEntry(root.desktopEntry);
                } else if (root.appClass) {
                    const bin = root.appClass.split('.').pop() || root.appClass;
                    Launch.exec([bin]);
                }
            } else {
                if (popouts.hasCurrent && (popouts.currentName === "appmenu" || popouts.currentName === "appmenucontext")) {
                    popouts.hasCurrent = false;
                } else if (Config.bar.popouts.appmenu) {
                    root.openPopout("appmenu");
                }
            }
        }
    }

    RowLayout {
        id: contentLayout

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        Item {
            visible: root.showIcon
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: root.iconSize
            implicitHeight: root.iconSize

            MaterialIcon {
                visible: !root.hasActiveWindow
                anchors.centerIn: parent
                text: "monitor"
                color: root.colour
                fontStyle: Tokens.font.icon.builders.small.size(root.iconSize).build()
            }

            CachingIconImage {
                visible: root.hasActiveWindow && root.iconSource.length > 0
                anchors.centerIn: parent
                source: root.iconSource
                implicitSize: root.iconSize
                width: root.iconSize
                height: root.iconSize
            }
        }

        StyledText {
            id: appLabel

            visible: root.showTitle
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: Math.round(Config.bar.appmenu.maxTitleLength * Tokens.font.body.medium.pointSize * 0.75 * root.scaleFactor)
            elide: Text.ElideRight
            text: root.appName
            font: Tokens.font.label.large
            color: root.colour
        }

        MaterialIcon {
            visible: root.showChevron
            Layout.alignment: Qt.AlignVCenter
            text: "expand_more"
            color: Qt.alpha(root.colour, 0.7)
            fontStyle: Tokens.font.icon.builders.small.size(Math.round(root.iconSize * 0.75)).build()
            rotation: {
                let base = 0;
                switch (Config.bar.position) {
                case "bottom":
                    base = 180;
                    break;
                case "left":
                    base = 270;
                    break;
                case "right":
                    base = 90;
                    break;
                default:
                    base = 0;
                    break;
                }
                return base + (root.isPopoutOpen ? 180 : 0);
            }

            Behavior on rotation {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }

    Loader {
        asynchronous: true
        active: root.tooltipText.length > 0
        z: 10000
        width: 0
        height: 0

        sourceComponent: Component {
            Tooltip {
                parent: root.Window.contentItem
                target: root
                text: root.tooltipText
            }
        }
    }
}
