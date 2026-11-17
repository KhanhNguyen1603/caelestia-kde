import QtQuick
import qs.services

QtObject {
    id: root

    property string currentName
    property bool hasCurrent
    // Where the open popout is centred along the bar. It lives with the state rather than
    // on the bar's wrapper because the tray's box hands its icons this object, and an icon
    // opens its menu through the same path the bar's own icons use.
    property real currentCenter
    // A popout opened as a place to pick from stays open until it is dismissed, rather
    // than closing the moment the pointer leaves it. It says so here instead of being
    // pinned by name, so any popout opened that way is kept open by the same rule.
    property bool staysOpen: false
    property var dockModel: null
    property var tasksModel: null
    property string selectedClientAddress: ""
    property bool sidebarOpen: false
    property bool isHorizontal: true

    property Connections _focusWatch: Connections {
        // A window taking the focus is the click that landed somewhere else. Opening a
        // popout over the desktop leaves no window focused, so an empty one is not a
        // dismissal.
        function onActiveWindowChanged(): void {
            if (root.hasCurrent && root.staysOpen && Kwin.activeWindow?.class)
                root.hasCurrent = false;
        }

        target: Kwin
    }

    signal detachRequested(mode: string)

    // Staying open belongs to the popout itself: once it closes, or another one takes its
    // place, there is nothing left to keep open.
    onHasCurrentChanged: {
        // A bar panel opening takes the screen from whatever transient surface was over it,
        // and the launcher is the one that used to be left half covered.
        if (hasCurrent)
            Visibilities.closeTransients("popouts");
        if (!hasCurrent)
            root.staysOpen = false;
    }
    onCurrentNameChanged: root.staysOpen = false
}
