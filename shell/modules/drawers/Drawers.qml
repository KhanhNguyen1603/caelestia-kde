pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

Variants {
    model: Screens.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        Component.onCompleted: console.log("[dock-debug] Drawers.qml scope completed for screen:", scope.modelData?.name, "dock:", content.dock)

        Exclusions {
            screen: scope.modelData
            bar: content.bar
            dock: content.dock
            visibilities: content.visibilities
        }

        ContentWindow {
            id: content

            screen: scope.modelData
        }
    }
}
