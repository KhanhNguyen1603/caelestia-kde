pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<MenuItem> scaleItems: [
        MenuItem {
            text: "100%"
            value: "1"
        },
        MenuItem {
            text: "125%"
            value: "1.25"
        },
        MenuItem {
            text: "150%"
            value: "1.5"
        },
        MenuItem {
            text: "160%"
            value: "1.6"
        },
        MenuItem {
            text: "170%"
            value: "1.7"
        },
        MenuItem {
            text: "175%"
            value: "1.75"
        },
        MenuItem {
            text: "200%"
            value: "2"
        },
        MenuItem {
            text: "250%"
            value: "2.5"
        },
        MenuItem {
            text: "300%"
            value: "3"
        }
    ]

    readonly property list<MenuItem> rotationItems: [
        MenuItem {
            text: qsTr("Normal")
            value: 1
        },
        MenuItem {
            text: qsTr("Left")
            value: 2
        },
        MenuItem {
            text: qsTr("Upside down")
            value: 4
        },
        MenuItem {
            text: qsTr("Right")
            value: 8
        }
    ]

    /// The density worth scaling to, which depends on how far the screen sits: a 13.5" laptop
    /// is read from about 40 cm, a 27" monitor from about 70 cm, and a desktop is drawn for
    /// 96 dpi at 63 cm, so the same pixels-per-inch wants a different scale on each.
    function targetDpi(diagonalInches: real): real {
        const distance = Math.max(30, 40 + 2.2 * (diagonalInches - 13.5));
        return 96 * 63 / distance;
    }

    /// A scale or rotation the menu does not list leaves `active` empty on purpose: the
    /// button then shows what the screen really is instead of the nearest preset.
    function scaleItem(output: var): MenuItem {
        const value = String(output.scale);
        return root.scaleItems.find(item => item.value === value) ?? null;
    }

    function rotationItem(output: var): MenuItem {
        return root.rotationItems.find(item => item.value === output.rotation) ?? null;
    }

    function currentMode(output: var): var {
        return Displays.modesFor(output).find(mode => String(mode.id) === String(output.currentModeId)) ?? null;
    }

    function currentModeLabel(output: var): string {
        const mode = root.currentMode(output);
        return mode ? Displays.modeLabel(mode) : qsTr("Unknown mode");
    }

    /// The preset the panel's own density asks for, so the interface keeps the size it has on
    /// a screen that dense instead of shrinking on a finer one. A panel that does not report
    /// its size has no recommendation to offer.
    function recommendedScaleItem(output: var): MenuItem {
        const mode = root.currentMode(output);
        const sizeMm = output?.sizeMM;
        const pixels = mode ? Math.hypot(mode.size.width, mode.size.height) : 0;
        const millimetres = sizeMm ? Math.hypot(sizeMm.width, sizeMm.height) : 0;
        if (pixels === 0 || millimetres === 0)
            return null;

        const inches = millimetres / 25.4;
        const ideal = pixels / inches / root.targetDpi(inches);
        let best = root.scaleItems[0];
        for (let i = 1; i < root.scaleItems.length; i++) {
            const candidate = root.scaleItems[i];
            if (Math.abs(Number(candidate.value) - ideal) < Math.abs(Number(best.value) - ideal))
                best = candidate;
        }
        return best;
    }

    title: qsTr("Displays")

    // The layout can be changed from System Settings while Nexus is closed, so the page
    // asks KScreen again when it is shown instead of trusting what it read last time.
    Component.onCompleted: Displays.refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StyledText {
            Layout.fillWidth: true
            visible: !Displays.available
            text: qsTr("This machine has no kscreen-doctor, so the shell can neither read nor change the screen setup. Install Plasma's kscreen package to manage displays here.")
            color: Colours.palette.m3onSurfaceVariant
            font: NexusStyle.secondaryFont
            wrapMode: Text.Wrap
        }

        Repeater {
            model: Displays.connected

            delegate: ColumnLayout {
                id: outputSection

                required property var modelData
                required property int index

                readonly property var output: outputSection.modelData

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    first: index === 0
                    text: outputSection.output.enabled ? outputSection.output.name : qsTr("%1 (off)").arg(outputSection.output.name)
                }

                ToggleRow {
                    first: true
                    text: qsTr("Enabled")
                    subtext: Displays.enabled.length > 1 || !outputSection.output.enabled ? qsTr("Drives a picture for this screen") : qsTr("The last enabled screen has to stay on")
                    checked: outputSection.output.enabled
                    enabled: Displays.enabled.length > 1 || !outputSection.output.enabled
                    onToggled: Displays.setEnabled(outputSection.output.name, checked)
                }

                NavRow {
                    icon: "aspect_ratio"
                    label: qsTr("Resolution & refresh rate")
                    status: root.currentModeLabel(outputSection.output)
                    onClicked: {
                        root.nState.selectedOutput = outputSection.output.name;
                        root.nState.openSubPage("displayModes");
                    }
                }

                SelectRow {
                    label: qsTr("Scale")
                    subtext: qsTr("How large everything is drawn")
                    menuItems: root.scaleItems
                    active: root.scaleItem(outputSection.output)
                    recommended: root.recommendedScaleItem(outputSection.output)
                    fallbackText: `${Math.round(outputSection.output.scale * 100)}%`
                    onSelected: item => Displays.setScale(outputSection.output.name, Number(item.value))
                }

                SelectRow {
                    label: qsTr("Rotation")
                    subtext: qsTr("Turn the picture to match how the screen stands")
                    menuItems: root.rotationItems
                    active: root.rotationItem(outputSection.output)
                    fallbackText: Displays.rotationName(outputSection.output.rotation)
                    last: !Displays.supportsHdr(outputSection.output)
                    onSelected: item => Displays.setRotation(outputSection.output.name, item.value)
                }

                ToggleRow {
                    last: true
                    visible: Displays.supportsHdr(outputSection.output)
                    text: qsTr("HDR")
                    subtext: qsTr("High dynamic range, and the wide colour gamut that goes with it")
                    checked: outputSection.output.hdr
                    onToggled: Displays.setHdr(outputSection.output.name, checked)
                }
            }
        }

        SectionHeader {
            text: qsTr("Input")
        }

        NavRow {
            first: true
            icon: "mouse"
            label: qsTr("Mouse & touchpad")
            status: qsTr("Speed, tap to click, natural scrolling")
            onClicked: Launch.kcm("kcm_touchpad")
        }

        NavRow {
            last: true
            icon: "keyboard"
            label: qsTr("Keyboard")
            status: qsTr("Repeat rate, layouts, advanced settings")
            onClicked: Launch.kcm("kcm_keyboard")
        }
    }
}
