import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    property string sourcePanel: ""
    property var dockModel: null
    property var tasksModel: null
    property string selectedClientAddress: ""
    property bool sidebarOpen: false
    property bool isHorizontal: true

    signal detachRequested(mode: string)
}
