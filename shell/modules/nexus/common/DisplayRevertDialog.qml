pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.nexus.common

// A scale or mode that cannot be read leaves the controls that would undo it somewhere the
// user cannot reach, so the change is taken back on its own unless it is kept in time.
NexusDialog {
    id: root

    dismissible: false
    title: qsTr("Keep this display setup?")
    message: qsTr("Going back to the setup that was there before in %1 seconds unless this one is kept.").arg(Displays.revertSecondsLeft)
    confirmText: qsTr("Keep")
    cancelText: qsTr("Revert")

    onConfirmed: Displays.keepLayout()
    onCancelled: Displays.revertLayout()
}
