pragma ComponentBehavior: Bound

import QtQuick

// One entry drawn on its own. The tray's box holds widgets too, and the bar's chooser
// picks on a model's roles rather than on an entry, so the entry goes through a one-row
// model here first. There is no bar behind the box, and the widgets it can hold are the
// ones that draw themselves without one.
Item {
    id: root

    required property var entry
    property var bar: null
    property var popouts: null

    // The chooser's item, parented here rather than to the repeater, so the host takes the
    // size of the icon that came back.
    readonly property var child: inner.count > 0 ? inner.itemAt(0) : null

    implicitWidth: root.child ? root.child.implicitWidth : 0
    implicitHeight: root.child ? root.child.implicitHeight : 0

    Repeater {
        id: inner

        model: root.entry ? [root.entry] : []

        delegate: BarWidgetDelegate {
            bar: root.bar
            popouts: root.popouts
        }
    }
}
