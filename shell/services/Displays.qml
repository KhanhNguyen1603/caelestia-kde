pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/// KScreen owns the outputs. The shell reads its JSON and hands every change back to
/// `kscreen-doctor`, in the same one-shot form System Settings uses, so the two can never
/// disagree about the layout: there is no second copy of the screen setup to keep in step.
Singleton {
    id: root

    property var outputs: []
    /// False when KScreen could not be asked at all: an empty list would otherwise read as
    /// "no screens" rather than "kscreen is not installed".
    property bool available: true
    /// Which panels advertise an HDR transfer function, keyed by output name. KScreen stores
    /// whatever it is asked for, so the capability has to come from the panel's own EDID.
    property var panels: ({})

    readonly property var connected: root.outputs.filter(output => output.connected)
    readonly property var enabled: root.connected.filter(output => output.enabled)

    /// KScreen reports the rotation as a power of two; the CLI takes these names.
    readonly property var rotations: ({ 1: "none", 2: "left", 4: "inverted", 8: "right" })

    /// How long a new layout is given before it is undone by itself.
    readonly property int revertSeconds: 10
    property int revertSecondsLeft: 0
    /// A layout change can make the screen unreadable, taking the controls that would undo
    /// it out of reach, so what was there before is held on to until the user says they can
    /// still see well enough to keep the change. The countdown is the whole of that state:
    /// while it is above zero, there is something to keep.
    readonly property bool awaitingKeep: root.revertSecondsLeft > 0
    /// The settings that put the layout back; empty when nothing is provisional.
    property list<string> previousLayout: []

    /// KWin resets a panel to full brightness whenever its colour mode or resolution
    /// changes, so everything that writes the layout announces it and lets brightness be
    /// put back afterwards.
    signal layoutApplied

    /// HDR is offered only for a panel that advertises an HDR transfer function, so the
    /// switch is not there to be flipped on a screen that cannot show the result.
    function supportsHdr(output: var): bool {
        return root.panels[output?.name]?.hdr === true;
    }

    function outputFor(name: string): var {
        return root.outputs.find(output => output.name === name) ?? null;
    }

    /// The modes worth offering, largest and fastest first, so the current one sits near
    /// the top of the menu instead of buried in the order the driver reports.
    function modesFor(output: var): var {
        return (output?.modes ?? []).slice().sort((a, b) => b.size.width * b.size.height - a.size.width * a.size.height || b.refreshRate - a.refreshRate);
    }

    function modeLabel(mode: var): string {
        return `${mode.size.width} x ${mode.size.height} · ${Math.round(mode.refreshRate)} Hz`;
    }

    function rotationName(rotation: int): string {
        return root.rotations[rotation] ?? "none";
    }

    /// The layout and the panels behind it are independent questions, so they are asked at
    /// the same time rather than one after the other.
    function refresh(): void {
        readProcess.running = false;
        readProcess.running = true;

        panelsProcess.running = false;
        panelsProcess.running = true;
    }

    function apply(settings: list<string>): void {
        if (settings.length === 0)
            return;

        // The layout the change is about to replace is what an unanswered prompt puts back,
        // so it comes from the layout KScreen last confirmed, and stays put while a prompt is
        // still open on an earlier change.
        if (root.previousLayout.length === 0)
            root.previousLayout = root.layoutSettings();

        root.revertSecondsLeft = root.revertSeconds;
        revertTimer.restart();

        writeProcess.command = ["kscreen-doctor", ...settings];
        writeProcess.running = true;
    }

    /// The layout as it stands, in the same one-shot form that changes it.
    function layoutSettings(): list<string> {
        const settings = [];
        for (const output of root.connected) {
            settings.push(`output.${output.name}.${output.enabled ? "enable" : "disable"}`);
            if (!output.enabled)
                continue;
            settings.push(`output.${output.name}.mode.${output.currentModeId}`);
            settings.push(`output.${output.name}.scale.${output.scale}`);
            settings.push(`output.${output.name}.rotation.${root.rotationName(output.rotation)}`);
            if (root.supportsHdr(output))
                settings.push(`output.${output.name}.hdr.${output.hdr ? "enable" : "disable"}`, `output.${output.name}.wcg.${output.wcg ? "enable" : "disable"}`);
        }
        return settings;
    }

    function keepLayout(): void {
        revertTimer.stop();
        root.revertSecondsLeft = 0;
        root.previousLayout = [];
    }

    function revertLayout(): void {
        revertTimer.stop();
        root.revertSecondsLeft = 0;

        const previous = root.previousLayout;
        root.previousLayout = [];
        if (previous.length === 0)
            return;

        writeProcess.command = ["kscreen-doctor", ...previous];
        writeProcess.running = true;
    }

    function setEnabled(name: string, on: bool): void {
        root.apply([`output.${name}.${on ? "enable" : "disable"}`]);
    }

    function setMode(name: string, modeId: string): void {
        root.apply([`output.${name}.mode.${modeId}`]);
    }

    function setScale(name: string, scale: real): void {
        root.apply([`output.${name}.scale.${scale}`]);
    }

    function setRotation(name: string, rotation: int): void {
        root.apply([`output.${name}.rotation.${root.rotationName(rotation)}`]);
    }

    /// The wide colour gamut goes with HDR rather than on its own, which is what KDE's own
    /// switch does: HDR content is graded in BT.2020, so enabling one without the other is
    /// a half-applied change.
    function setHdr(name: string, on: bool): void {
        root.apply([`output.${name}.hdr.${on ? "enable" : "disable"}`, `output.${name}.wcg.${on ? "enable" : "disable"}`]);
    }

    Component.onCompleted: root.refresh()

    Process {
        id: readProcess

        command: ["kscreen-doctor", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.outputs = JSON.parse(text).outputs ?? [];
                    root.available = true;
                } catch (error) {
                    root.outputs = [];
                    root.available = false;
                }
            }
        }

        onExited: code => {
            if (code !== 0) {
                root.outputs = [];
                root.available = false;
            }
        }
    }

    Process {
        id: panelsProcess

        command: ["python3", Quickshell.shellPath("scripts/panel_capabilities.py")]

        stdout: StdioCollector {
            onStreamFinished: {
                let reports = [];
                try {
                    reports = JSON.parse(text);
                } catch (error) {
                    // An unreadable EDID is not an error worth a page of its own: the HDR
                    // row simply stays away, because nothing claimed the screen can do it.
                    reports = [];
                }

                const panels = {};
                for (const report of reports)
                    panels[report.output] = report;
                root.panels = panels;
            }
        }
    }

    Process {
        id: writeProcess

        // KScreen answers the read with the layout it just applied, so the page shows what
        // really happened rather than what was asked for.
        onExited: {
            root.refresh();
            root.layoutApplied();
        }
    }

    Timer {
        id: revertTimer

        interval: 1000
        repeat: true

        onTriggered: {
            root.revertSecondsLeft -= 1;
            if (root.revertSecondsLeft <= 0)
                root.revertLayout();
        }
    }
}
