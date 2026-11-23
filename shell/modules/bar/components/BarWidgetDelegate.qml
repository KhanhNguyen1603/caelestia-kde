pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.Services
import qs.services
import qs.modules.bar
import qs.modules.bar.components
import qs.modules.bar.components.performance
import qs.modules.bar.components.workspaces

DelegateChooser {
    id: root

    property var bar: null
    property var popouts: bar ? bar.popouts : null

    function applyBoxContext(widget: var): void {
        if (!widget)
            return;

        const context = {
            popouts: root.popouts,
            visibilities: Visibilities.getForActive()
        };
        for (const name in context)
            if (widget.hasOwnProperty(name))
                widget[name] = context[name];
    }

    role: "kind"

    DelegateChoice {
        roleValue: "logo"
        delegate: WrappedLoader {
            sourceComponent: OsIcon {
                bar: root.bar
            }
        }
    }
    DelegateChoice {
        roleValue: "workspaces"
        delegate: WrappedLoader {
            sourceComponent: Workspaces {
                bar: root.bar
                screen: root.bar ? root.bar.screen : null
            }
        }
    }
    DelegateChoice {
        roleValue: "appmenu"
        delegate: WrappedLoader {
            sourceComponent: AppMenu {
                bar: root.bar
            }
        }
    }
    DelegateChoice {
        roleValue: "dock"
        delegate: WrappedLoader {
            sourceComponent: Dock {
                bar: root.bar
            }
        }
    }
    DelegateChoice {
        roleValue: "greeter"
        delegate: WrappedLoader {
            sourceComponent: Greeter {
                bar: root.bar
            }
        }
    }
    DelegateChoice {
        roleValue: "tray"
        delegate: WrappedLoader {
            id: trayLoader

            sourceComponent: Tray {
                popouts: root.popouts
                showTrayIcons: trayLoader.systemTray ? root.bar.systemTrayShowsIcons : true
                widgetEntries: trayLoader.systemTray ? root.bar.systemTrayEntries : []
                widgetDelegate: trayLoader.systemTray ? root : null
            }
        }
    }
    DelegateChoice {
        roleValue: "clock"
        delegate: WrappedLoader {
            sourceComponent: Clock {
                bar: root.bar
            }
        }
    }
    DelegateChoice {
        roleValue: "trayItem"
        delegate: WrappedLoader {
            id: trayItemLoader

            readonly property string trayKey: TrayRegistry.keyOfRow(trayItemLoader.id)

            sourceComponent: TrayItem {
                modelData: TrayRegistry.itemOf(trayItemLoader.trayKey)
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "statusIcon"
        delegate: WrappedLoader {
            id: statusLoader

            sourceComponent: StatusIcon {
                entryId: statusLoader.widgetId
                popouts: root.popouts
                bar: root.bar
                draggable: statusLoader.draggable
            }
        }
    }
    DelegateChoice {
        roleValue: "kbLayoutIndicator"
        delegate: WrappedLoader {
            visible: enabled && (Kwin.kbLayout || "").length > 0
            sourceComponent: KbLayoutIndicator {
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "notificationsIndicator"
        delegate: WrappedLoader {
            sourceComponent: NotificationsIndicator {}
        }
    }
    DelegateChoice {
        roleValue: "updateIndicator"
        delegate: WrappedLoader {
            visible: enabled && GlobalConfig.general.checkUpdates
            sourceComponent: UpdateIndicator {
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "perfCpu"
        delegate: WrappedLoader {
            visible: enabled && Cpu.name.length > 0
            sourceComponent: PerfCpu {
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "perfMemory"
        delegate: WrappedLoader {
            visible: enabled && Memory.total > 1
            sourceComponent: PerfMemory {
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "perfStorage"
        delegate: WrappedLoader {
            visible: enabled && Storage.disks.length > 0
            sourceComponent: PerfStorage {
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "perfNetwork"
        delegate: WrappedLoader {
            sourceComponent: PerfNetwork {
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "perfGpu"
        delegate: WrappedLoader {
            visible: enabled && Gpu.type !== Gpu.None
            sourceComponent: PerfGpu {
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "perfBattery"
        delegate: WrappedLoader {
            visible: enabled && UPower.displayDevice.isLaptopBattery
            sourceComponent: PerfBattery {
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "github"
        delegate: WrappedLoader {
            // A failed fetch is not a missing token, so only the token decides this.
            visible: enabled && !GithubStore.tokenMissing
            sourceComponent: GithubActivity {
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "media"
        delegate: WrappedLoader {
            sourceComponent: Media {
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "notes"
        delegate: WrappedLoader {
            sourceComponent: Notes {
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "weather"
        delegate: WrappedLoader {
            sourceComponent: WeatherWidget {
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "performance"
        delegate: WrappedLoader {
            sourceComponent: PerformanceWidget {
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "shortcuts"
        delegate: WrappedLoader {
            sourceComponent: ShortcutsWidget {
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "screencapture"
        delegate: WrappedLoader {
            sourceComponent: ScreenCaptureWidget {
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "keepawake"
        delegate: WrappedLoader {
            sourceComponent: KeepAwakeWidget {
                popouts: root.popouts
            }
        }
    }
    DelegateChoice {
        roleValue: "power"
        delegate: WrappedLoader {
            sourceComponent: Power {
                visibilities: root.bar ? root.bar.visibilities : Visibilities.getForActive()
            }
        }
    }
    // Fallback for plugin-provided widgets: DelegateChooser needs a
    // static choice per id, so unknown ids resolve their component at
    // runtime from the plugin registry.
    DelegateChoice {
        delegate: WrappedLoader {
            source: BarWidgetRegistry.widget(id)?.componentUrl ?? ""

            onItemChanged: {
                if (root.bar)
                    root.bar.applyWidgetContext(item);
                else
                    root.applyBoxContext(item);
            }
        }
    }

    // A widget the registry names draws itself once the loader has it, so the entry the
    // bar hands the view is what decides.
    component WrappedLoader: Loader {
        id: wrapper

        required enabled
        required property string id
        required property int index

        // Filled from the entry the registry hands the view. `systemTray` marks
        // the synthetic tray container, and `zone` tells a widget whether it is
        // being drawn inside it.
        required property bool systemTray
        required property string zone

        // Anything the tray draws can be dragged into its hidden-icons box, and
        // anything in the box can be dragged back. The widget itself is untouched:
        // the gesture is recognised over it, so a click still reaches the widget.
        required property bool draggable
        required property string kind
        readonly property string widgetId: id
        readonly property bool dragging: trayDrag.active

        asynchronous: false
        Layout.alignment: (root.bar ? root.bar.isHorizontal : true) ? Qt.AlignVCenter : Qt.AlignHCenter
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.maximumWidth: implicitWidth
        Layout.maximumHeight: implicitHeight
        Layout.minimumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight

        // Fading only once the ghost exists keeps the snapshot clean and means the
        // widget never disappears before there is something under the pointer.
        opacity: wrapper.dragging && TrayDrag.ghost !== null ? 0.35 : 1

        visible: enabled
        active: enabled

        TrayDragGesture {
            id: trayDrag

            widgetId: wrapper.widgetId
            // Widgets drawn as a bar icon lift themselves, so the wrapper that draws
            // them stays out of the way; the rest are lifted whole.
            enabled: wrapper.draggable && !BarWidgets.dragsItself(wrapper.kind)
        }
    }
}
