import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    // The hidden-icons box is opened deliberately, so it stays open until it is
    // dismissed instead of closing the moment the pointer leaves it.
    property bool trayPinned: false
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

    // The pin belongs to the box being open: once it closes, or another panel takes its
    // place, there is nothing left to keep open.
    onHasCurrentChanged: {
        if (!hasCurrent)
            trayPinned = false;
    }
    onCurrentNameChanged: {
        if (currentName !== "trayOverflow")
            trayPinned = false;
    }
}
