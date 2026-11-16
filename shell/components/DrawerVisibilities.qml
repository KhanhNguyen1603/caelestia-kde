import Quickshell

PersistentProperties {
    property bool bar
    property bool dock
    property bool osd
    property bool session
    property bool launcher
    property bool dashboard
    property bool utilities
    property bool sidebar
    property bool sidebarSuspended
    property bool overview
    property bool skipLauncherAnim: false

    onDockChanged: console.log("[dock-debug] DrawerVisibilities dock changed to:", dock)
}
