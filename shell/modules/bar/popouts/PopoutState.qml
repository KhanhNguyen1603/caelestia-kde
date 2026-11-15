import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    property var dockModel: null
    property var tasksModel: null
    // The bar hands the hidden-icons box the delegate that draws a widget, so the
    // widgets in the box are live. An empty tile until the bar binds the real one.
    property Component trayWidgetDelegate: Component {
        Item {}
    }
    property string selectedClientAddress: ""
    property bool sidebarOpen: false
    property bool isHorizontal: true

    signal detachRequested(mode: string)
}
