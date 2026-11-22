pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus
import qs.modules.windowinfo

Item {
    id: root

    required property ShellScreen screen
    required property real offsetScale
    required property DrawerVisibilities visibilities
    Config.screen: root.screen.name
    readonly property alias content: content
    readonly property alias winfo: winfo
    readonly property real nonAnimWidth: content.shouldBeActive ? content.implicitWidth : winfo.shouldBeActive ? winfo.implicitWidth : content.implicitWidth
    readonly property real nonAnimHeight: content.shouldBeActive ? content.implicitHeight : winfo.shouldBeActive ? winfo.implicitHeight : content.implicitHeight
    readonly property Item current: (content.item as Content)?.current ?? null
    readonly property bool isDetached: detachedMode.length > 0
    readonly property bool sidebarOpen: popoutState.sidebarOpen
    // Right-click menus are transient. The type is keyed on currentName so it
    // survives the close animation; isContextPopout also requires one to be open.
    readonly property bool currentIsContext: (content.item as Content)?.currentIsContext ?? false
    // A popout that draws its own surface asks the drawer for nothing behind it.
    readonly property bool currentOwnsSurface: (content.item as Content)?.currentOwnsSurface ?? false
    // An open popout sits where a name drawn over a bar icon would land, so the names stay
    // back while one is open. The tray's box draws its own surface and hangs clear of the
    // bar, so it is no reason to keep them back.
    readonly property bool blocksHoverNames: hasCurrent && !currentOwnsSurface
    readonly property bool isContextPopout: hasCurrent && currentIsContext
    // Popouts excluded from pushing the notification column / sidebar out of the
    // way (Panels.qml) and from visually merging with the sidebar (ContentWindow.qml):
    // hover previews and context menus are transient, so shoving panels around for
    // them feels jittery. The clock popout is deliberately NOT here — the calendar
    // is a real panel-sized popout and displaces notifications like audio/network do.
    readonly property bool isDockPopout: currentName === "dockhover" || currentName === "greeter" || currentName === "activewindow" || currentName === "appmenu" || currentName === "github" || currentIsContext
    property alias currentName: popoutState.currentName
    property alias hasCurrent: popoutState.hasCurrent
    property alias sourcePanel: popoutState.sourcePanel
    // Whether the current popout was opened to be picked from, so the bar and the overlay
    // agree that it is not to be closed by the pointer moving away.
    property alias staysOpen: popoutState.staysOpen
    property alias dockModel: popoutState.dockModel
    property alias tasksModel: popoutState.tasksModel
    property alias selectedClientAddress: popoutState.selectedClientAddress
    property alias currentCenter: popoutState.currentCenter
    property bool isPanelHorizontal: true
    readonly property bool isDockPanelPopout: sourcePanel === "dockPanel" || (sourcePanel === "" && (currentName === "osiconcontext" || currentName === "dockcontext" || currentName === "dockbgcontext" || currentName === "dockhover"))
    // Set by ClipWrapper: whether the current bar item sits under the sidebar,
    // which can be narrower than the bar's right side now that it is resizable.
    property bool underSidebar: true
    property string detachedMode
    readonly property QtObject dummy: QtObject {}
    property int animLength: dummy.Tokens.anim.durations.expressiveDefaultSpatial
    property var animCurve: dummy.Tokens.anim.expressiveDefaultSpatial

    function setAnims(detach: bool): void {
        const type = `expressive${detach ? "Slow" : "Default"}Spatial`;
        animLength = dummy.Tokens.anim.durations[type];
        animCurve = dummy.Tokens.anim[type];
    }
    function detach(mode: string): void {
        setAnims(true);
        if (mode === "winfo") {
            detachedMode = mode;
            focus = true;
        } else {
            WindowFactory.create(null, {
                initialPageIdx: mode,
                initialSubPage: PageRegistry.defaultSubPageForKey(mode)
            });
            close();
        }
        setAnims(false);
    }
    function close(): void {
        hasCurrent = false;
        detachedMode = "";
    }

    implicitWidth: nonAnimWidth
    implicitHeight: nonAnimHeight
    focus: hasCurrent
    Keys.onEscapePressed: {
        if (currentName === "wirelesspassword" && content.item) {
            const passwordPopout = (content.item as Content)?.children.find(c => c.name === "wirelesspassword");
            if (passwordPopout && passwordPopout.item) {
                passwordPopout.item.closeDialog();
                return;
            }
        }
        close();
    }
    Keys.onPressed: event => {
        if (currentName === "wirelesspassword") {
            event.accepted = false;
        }
    }

    PopoutState {
        id: popoutState

        // Only attach to the sidebar when the popout would open below it anyway;
        // otherwise it would end up away from the item that opened it.
        sidebarOpen: root.visibilities.sidebar && root.underSidebar
        isHorizontal: root.isPanelHorizontal
        onDetachRequested: mode => root.detach(mode)
    }
    HyprlandFocusGrab {
        active: root.isDetached
        windows: [QsWindow.window]
        onCleared: root.close()
    }
    Binding {
        when: root.isDetached || (root.hasCurrent && root.currentName === "wirelesspassword")
        target: QsWindow.window
        property: "WlrLayershell.keyboardFocus"
        value: WlrKeyboardFocus.OnDemand
    }
    Comp {
        id: content

        shouldBeActive: root.hasCurrent && !root.detachedMode
        anchors.fill: parent
        sourceComponent: Content {
            popouts: popoutState
            visibilities: root.visibilities
        }
    }
    Comp {
        id: winfo

        shouldBeActive: root.detachedMode === "winfo"
        anchors.centerIn: parent
        sourceComponent: WindowInfo {
            clientAddress: popoutState.selectedClientAddress
        }
        onShouldBeActiveChanged: {
            if (!shouldBeActive) {
                popoutState.selectedClientAddress = "";
            }
        }
    }
    Behavior on implicitWidth {
        Anim {
            duration: root.animLength
            easing: root.animCurve
        }
    }
    Behavior on implicitHeight {
        enabled: root.offsetScale < 1

        Anim {
            duration: root.animLength
            easing: root.animCurve
        }
    }

    component Comp: Loader {
        id: comp

        property bool shouldBeActive

        active: false
        opacity: 0
        states: State {
            name: "active"
            when: comp.shouldBeActive

            PropertyChanges {
                comp.opacity: 1
                comp.active: true
            }
        }
        transitions: [
            Transition {
                from: ""
                to: "active"

                SequentialAnimation {
                    PropertyAction {
                        property: "active"
                    }
                    Anim {
                        type: Anim.DefaultEffects
                        property: "opacity"
                    }
                }
            },
            Transition {
                from: "active"
                to: ""

                SequentialAnimation {
                    Anim {
                        type: Anim.FastEffects
                        property: "opacity"
                    }
                    PropertyAction {
                        property: "active"
                    }
                }
            }
        ]
    }
}
