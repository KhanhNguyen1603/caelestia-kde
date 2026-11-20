pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    property int categoryIdx: -1
    property string key: ""
    property string label: ""
    property string icon: ""
    property string description: ""
    property string defaultPage: ""
    // A category that is one page: its entry opens that page instead of a list of one.
    property bool singlePage: false
    default property list<Page> pages
}
