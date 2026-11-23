import QtQuick
import QtTest
import qs.modules.drawers as Drawers
import Quickshell
import Quickshell.Io
import qs.services

ShellRoot {
    id: root

    readonly property string fullscreenOutputs: Quickshell.screens
        .filter(screen => Kwin.hasFullscreenOn(screen.name)).map(screen => screen.name).sort().join(",") || "none"
    readonly property double loadedAt: Date.now()

    Window { title: "Fullscreen test game"; visibility: Window.FullScreen }
    Window { title: "Fullscreen test app"; visible: true; width: 320; height: 240 }

    Drawers.ContentWindow { id: drawer; screen: Quickshell.screens[0] }
    TestCase { id: input; when: false }

    function findItem(item: Item, matches: var): var {
        if (matches(item))
            return item;
        for (const child of item.children) {
            const match = findItem(child, matches);
            if (match)
                return match;
        }
        return null;
    }

    IpcHandler {
        target: "test"
        function ready(): bool {
            return Kwin.windowList.filter(w => w.title.startsWith("Fullscreen test ")).length === 2;
        }
        function openLauncher(): void { drawer.visibilities.launcher = true; }
        function launcherReady(): bool {
            return drawer.visibilities.launcher && drawer.bar.shouldBeVisible && drawer.contentItem.Window.active;
        }
        function crossDock(): bool {
            const dockItem = root.findItem(drawer.bar, item => item.modelData?.isPinned === true && item.visible);
            if (!dockItem)
                return false;
            input.mouseMove(drawer.contentItem, drawer.width / 2, drawer.height / 2);
            input.mouseMove(dockItem, dockItem.width / 2, dockItem.height / 2);
            return true;
        }
        function clickAudio(): bool {
            const audio = root.findItem(drawer.bar, item => item.iconId === "audio" && item.visible);
            if (!audio)
                return false;
            input.mouseClick(audio, audio.width / 2, audio.height / 2, Qt.LeftButton);
            return true;
        }
        function audioOpen(): bool {
            return !drawer.visibilities.launcher && drawer.bar.popouts.hasCurrent
                && drawer.bar.popouts.currentName === "audio" && !drawer.hasFullscreen;
        }
        function dockPreview(): bool {
            return drawer.bar.popouts.hasCurrent && drawer.bar.popouts.currentName === "dockhover";
        }
        function suppressed(): bool { return drawer.hasFullscreen && !drawer.bar.popouts.hasCurrent; }
        // The bar clips its items while it slides in, and a clipped item takes no hover.
        function barOpen(): bool {
            return drawer.bar.shouldBeVisible && drawer.bar.height >= drawer.bar.contentWidth && drawer.fsTransitionProg === 0;
        }
        function outputs(): string { return root.fullscreenOutputs; }
        function loadedAt(): string { return String(root.loadedAt); }
        function outsideOpen(): bool { return Kwin.windowList.some(w => w.title === "Outside game"); }
    }
}
