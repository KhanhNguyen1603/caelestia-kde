pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Images
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")

    property bool hasSkwd: false
    property bool skwdChecked: false
    property bool previousWallpaperEnabledState: false
    readonly property bool previewing: previewPath !== ""
    readonly property string current: previewing ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    // How many variant swaps the scheme has asked for inside the current window. See
    // applyVariantForCurrentMode: a pair that feeds its own mode back would swap forever.
    property int variantFlips: 0
    property real variantFlipWindow: 0
    property var videoThumbs: ({})
    property var videoThumbsPending: ({})
    property var videoThumbsHifi: ({})
    property var videoThumbsHifiPending: ({})

    property string currentMediaFilter: "All"

    property var filteredList: {
        const res = wallpapers.entries || [];
        if (currentMediaFilter === "Image") {
            return res.filter(w => !Images.isVideo(w.relativePath) && !Images.isAnimated(w.relativePath));
        } else if (currentMediaFilter === "Video") {
            return res.filter(w => Images.isVideo(w.relativePath));
        } else if (currentMediaFilter === "Animated") {
            return res.filter(w => Images.isAnimated(w.relativePath));
        }
        return res;
    }

    readonly property var categories: {
        let dummy = root.list;
        const baseDir = Paths.wallsdir;
        let cats = [];
        for (let i = 0; i < root.list.length; i++) {
            let p = root.list[i].parentDir;
            if (p !== baseDir) {
                let cat = p.slice(baseDir.length + 1);
                if (cat.includes("/")) cat = cat.slice(0, cat.indexOf("/"));
                if (!cats.includes(cat)) cats.push(cat);
            }
        }
        return ["Main"].concat(cats.sort());
    }

    readonly property var grouped: {
        let dummy = root.list;
        const baseDir = Paths.wallsdir;
        let grp = { "Main": [] };
        for (let i = 0; i < root.list.length; i++) {
            let w = root.list[i];
            let p = w.parentDir;
            if (p === baseDir) {
                grp["Main"].push(w);
            } else {
                let cat = p.slice(baseDir.length + 1);
                if (cat.includes("/")) cat = cat.slice(0, cat.indexOf("/"));
                if (!grp[cat]) grp[cat] = [];
                grp[cat].push(w);
            }
        }
        return grp;
    }

    function getCategoryFor(w: FileSystemEntry): string {
        let category = w.parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category;
    }

    function setRandom(): void {
        if (!root.list || root.list.length === 0) return;
        let idx = Math.floor(Math.random() * root.list.length);
        if (root.list.length > 1 && root.list[idx].path === actualCurrent)
            idx = (idx + 1) % root.list.length;
        setWallpaper(root.list[idx].path);
    }

    function setNextSequential(): void {
        if (!root.list || root.list.length === 0) return;
        let idx = -1;
        for (let i = 0; i < root.list.length; i++) {
            if (root.list[i].path === actualCurrent) {
                idx = i;
                break;
            }
        }
        idx = (idx + 1) % root.list.length;
        setWallpaper(root.list[idx].path);
    }

    function next(): void {
        if (GlobalConfig.background.slideshowRandom) {
            setRandom();
        } else {
            setNextSequential();
        }
    }

    function getVariantForMode(path: string, lightMode: bool): string {
        if (!path)
            return path;

        // 1. Standard KDE Wallpaper Package: contents/images (light) <-> contents/images_dark (dark)
        if (lightMode && path.includes("/contents/images_dark/")) {
            const candidate = path.replace("/contents/images_dark/", "/contents/images/");
            if (IUtils.fileExists(candidate))
                return candidate;
        } else if (!lightMode && path.includes("/contents/images/")) {
            const candidate = path.replace("/contents/images/", "/contents/images_dark/");
            if (IUtils.fileExists(candidate))
                return candidate;
        }

        // 2. Common light/dark filename suffix conventions
        const pairs = [
            ["_dark.", "_light."],
            ["-dark.", "-light."],
            [".dark.", ".light."],
            ["_night.", "_day."],
            ["-night.", "-day."],
            [".night.", ".day."]
        ];

        for (let i = 0; i < pairs.length; i++) {
            const darkPat = pairs[i][0];
            const lightPat = pairs[i][1];
            if (lightMode && path.includes(darkPat)) {
                const candidate = path.replace(darkPat, lightPat);
                if (IUtils.fileExists(candidate))
                    return candidate;
            } else if (!lightMode && path.includes(lightPat)) {
                const candidate = path.replace(lightPat, darkPat);
                if (IUtils.fileExists(candidate))
                    return candidate;
            }
        }

        return path;
    }

    /// Swap the stored wallpaper for the sibling that matches the current mode. Runs only once
    /// the scheme is on disk: `currentLight` still holds its default until then, and choosing a
    /// variant on that default applied the dark one on every boot before the light scheme landed.
    function applyVariantForCurrentMode(): void {
        if (!Colours.schemeLoaded || !actualCurrent)
            return;

        const target = getVariantForMode(actualCurrent, Colours.currentLight);
        if (!target || target === actualCurrent)
            return;

        // Swapping the image re-derives the scheme, and a pair whose images derive the opposite
        // mode from their name would then swap back: a ping-pong, not a mode change. Three swaps
        // in a row is that ping-pong, so stop following the scheme until it settles by itself.
        const now = Date.now();
        if (now - variantFlipWindow > 10000) {
            variantFlipWindow = now;
            variantFlips = 0;
        }
        if (++variantFlips > 3)
            return;

        root.applyWallpaper(target);
    }

    function setWallpaper(path: string): void {
        // An explicit choice is not the scheme pushing a sibling at us: let the guard start over.
        variantFlips = 0;
        root.applyWallpaper(getVariantForMode(path, Colours.currentLight));
    }

    /// Apply a wallpaper that already names the right variant for the current mode. Private:
    /// the mode is resolved in one place, so a caller that resolved it cannot have it resolved
    /// a second time against a different flag and land on the opposite image.
    function applyWallpaper(path: string): void {
        if (previewing && path !== actualCurrent)
            previewColoursState.hold();
        actualCurrent = path;
        if (Images.isVideo(path)) {
            const thumb = thumbFor(path);
            const hifi = thumbHifi(path);
            const target = hifi !== "" ? hifi : thumb;
            if (target !== "") {
                const script = 'caelestia wallpaper -f "$1" --apply-path "$2" ' + Colours.smartArg.join(" ") + '; printf "%s" "$2" > "$3"';
                Quickshell.execDetached(["sh", "-c", script, "--", thumb !== "" ? thumb : target, path, root.currentNamePath]);
                syncPlasmaWallpaper(target);
            } else {
                Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" > "$2"', "--", path, root.currentNamePath]);
            }
        } else {
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", path, ...Colours.smartArg]);
            syncPlasmaWallpaper(path);
        }
    }

    function shellOwnsWallpaper(): bool {
        if (GlobalConfig.background.disableQuickshellDesktop)
            return false;
        const engine = Config.background.wallpaperEngine;
        return engine === "quickshell" || (engine !== "skwd/plasma" && engine !== "plasma" && !root.hasSkwd);
    }

    /// The desktop keeps the wallpaper of whichever plugin Plasma has active, and only the image
    /// plugin reads what is written below. skwd's plugin renders the wallpaper skwd recorded
    /// instead, and only its daemon keeps that record current: with the daemon stopped the two
    /// drifted apart and a session came back painted over twice. Any other plugin is the user's
    /// own choice and is left alone.
    function syncPlasmaWallpaper(imagePath: string): void {
        if (!imagePath)
            return;
        const ownPlugin = (root.skwdChecked && !root.hasSkwd && root.shellOwnsWallpaper()) ? 'if (d.wallpaperPlugin === "org.skwd.wall.plasma") d.wallpaperPlugin = "org.kde.image";' : "";
        const script = 'var allDesktops = desktops();' +
            'for (var i = 0; i < allDesktops.length; i++) {' +
            '    var d = allDesktops[i];' +
            ownPlugin +
            '    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];' +
            '    d.writeConfig("Image", "file://" + ' + JSON.stringify(imagePath) + ');' +
            '}';
        Quickshell.execDetached(["qdbus6", "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript", script]);

        if (GlobalConfig.lock.syncWallpaper)
            Quickshell.execDetached(["kwriteconfig6", "--file", "kscreenlockerrc", "--group", "Greeter", "--group", "Wallpaper", "--group", "org.kde.image", "--group", "General", "--key", "Image", "file://" + imagePath]);
    }

    function preview(path: string): void {
        if (!previewing) {
            previousWallpaperEnabledState = GlobalConfig.background.wallpaperEnabled;
            GlobalConfig.background.wallpaperEnabled = true;
        }

        previewPath = path;
        previewColourOf(path);
    }

    function previewColourOf(path: string): void {
        if (Colours.scheme !== "dynamic")
            return;
        previewColoursState.show(thumbFor(path));
    }

    function stopPreview(): void {
        if (previewing) {
            GlobalConfig.background.wallpaperEnabled = previousWallpaperEnabledState;
        }

        previewPath = "";
        previewColoursState.stop();
    }

    function getThumbnailPath(path: string): string {
        if (Images.isVideo(path)) {
            return `${Paths.cache}/wallpapers/${CUtils.sha256(path)}/first_frame.png`;
        }
        return path;
    }

    function getThumbnailHifiPath(path: string): string {
        if (Images.isVideo(path)) {
            return `${Paths.cache}/wallpapers/${CUtils.sha256(path)}/first_frame_hifi.png`;
        }
        return path;
    }

    function thumb(path: string): string {
        return thumbFor(path);
    }

    function thumbHifi(path: string): string {
        return thumbForHifi(path);
    }

    function thumbFor(path: string): string {
        const p = String(path || "").replace(/^file:\/\//, "");
        if (p === "" || !Images.isVideo(p))
            return p;
        if (root.videoThumbs[p])
            return root.videoThumbs[p];
        requestVideoThumb(p);
        return "";
    }

    function thumbForHifi(path: string): string {
        const p = String(path || "").replace(/^file:\/\//, "");
        if (p === "" || !Images.isVideo(p))
            return p;
        if (root.videoThumbsHifi[p])
            return root.videoThumbsHifi[p];
        requestVideoThumbHifi(p);
        return "";
    }

    function requestVideoThumb(path: string): void {
        if (root.videoThumbsPending[path] || root.videoThumbs[path])
            return;
        const pending = root.videoThumbsPending;
        pending[path] = true;
        root.videoThumbsPending = pending;

        const out = getThumbnailPath(path);
        const script = 'out="$1"; src="$2"; [ -s "$out" ] || { mkdir -p "$(dirname "$out")"; ' +
                       'stem="$(basename "${src%.*}")"; ' +
                       'skwd="${XDG_CACHE_HOME:-$HOME/.cache}/skwd-wall-v2/video-thumbs/${stem}.webp"; ' +
                       'if [ -s "$skwd" ]; then cp "$skwd" "$out"; else ' +
                       'ffmpeg -y -loglevel error -i "$src" -vf "thumbnail,scale=640:-1" -frames:v 1 "$out" >/dev/null 2>&1; fi; }; ' +
                       'printf "%s" "$src" > "$(dirname "$out")/source_path"; ' +
                       '[ -s "$out" ] && printf %s "$out"';
        const qml = 'import QtQuick\nimport Quickshell.Io\n' +
            'Process {\n' +
            '    id: p\n' +
            '    command: ' + JSON.stringify(["sh", "-c", script, "--", out, path]) + '\n' +
            '    stdout: StdioCollector { onStreamFinished: root.onVideoThumb(' + JSON.stringify(path) + ', (text || "").trim(), p); }\n' +
            '    onExited: code => { if (code !== 0) p.destroy(); }\n' +
            '}';
        try {
            const o = Qt.createQmlObject(qml, root, "videoThumbProc");
            o.running = true;
        } catch (e) {
            Logger.log("[wallpapers] video thumbnail error: " + e.message);
        }
    }

    function requestVideoThumbHifi(path: string): void {
        if (root.videoThumbsHifiPending[path] || root.videoThumbsHifi[path])
            return;
        const pending = root.videoThumbsHifiPending;
        pending[path] = true;
        root.videoThumbsHifiPending = pending;

        const out = getThumbnailHifiPath(path);
        const script = 'out="$1"; src="$2"; [ -s "$out" ] || { mkdir -p "$(dirname "$out")"; ' +
                       'ffmpeg -y -loglevel error -i "$src" -vf "thumbnail" -frames:v 1 "$out" >/dev/null 2>&1; }; ' +
                       'printf "%s" "$src" > "$(dirname "$out")/source_path"; ' +
                       '[ -s "$out" ] && printf %s "$out"';
        const qml = 'import QtQuick\nimport Quickshell.Io\n' +
            'Process {\n' +
            '    id: p\n' +
            '    command: ' + JSON.stringify(["sh", "-c", script, "--", out, path]) + '\n' +
            '    stdout: StdioCollector { onStreamFinished: root.onVideoThumbHifi(' + JSON.stringify(path) + ', (text || "").trim(), p); }\n' +
            '    onExited: code => { if (code !== 0) p.destroy(); }\n' +
            '}';
        try {
            const o = Qt.createQmlObject(qml, root, "videoThumbHifiProc");
            o.running = true;
        } catch (e) {
            Logger.log("[wallpapers] video hifi thumbnail error: " + e.message);
        }
    }

    function onVideoThumb(path: string, out: string, proc: var): void {
        if (out !== "") {
            const m = root.videoThumbs;
            m[path] = out;
            root.videoThumbs = Object.assign({}, m);
            if (path === root.actualCurrent) {
                const script = 'caelestia wallpaper -f "$1" --apply-path "$2" ' + Colours.smartArg.join(" ") + '; printf "%s" "$2" > "$3"';
                Quickshell.execDetached(["sh", "-c", script, "--", out, path, root.currentNamePath]);
                if (!root.videoThumbsHifi[path])
                    syncPlasmaWallpaper(out);
            }
            if (path === root.previewPath && root.previewing)
                root.previewColourOf(path);
        }
        const pending = root.videoThumbsPending;
        delete pending[path];
        root.videoThumbsPending = pending;
        if (proc)
            proc.destroy();
    }

    function onVideoThumbHifi(path: string, out: string, proc: var): void {
        if (out !== "") {
            const m = root.videoThumbsHifi;
            m[path] = out;
            root.videoThumbsHifi = Object.assign({}, m);
            if (path === root.actualCurrent) {
                syncPlasmaWallpaper(out);
            }
        }
        const pending = root.videoThumbsHifiPending;
        delete pending[path];
        root.videoThumbsHifiPending = pending;
        if (proc)
            proc.destroy();
    }

    function applyWallpaperEngine(): void {
        if (GlobalConfig.background.disableQuickshellDesktop)
            return;

        const engine = Config.background.wallpaperEngine;
        if (engine === "quickshell") {
            GlobalConfig.background.wallpaperEnabled = true;
        } else if (engine === "skwd/plasma" || engine === "plasma") {
            GlobalConfig.background.wallpaperEnabled = false;
        } else {
            GlobalConfig.background.wallpaperEnabled = !root.hasSkwd;
        }

        for (let i = 0; i < Quickshell.screens.length; i++) {
            const sConf = GlobalConfig.forScreen(Quickshell.screens[i].name);
            if (sConf)
                sConf.background.resetOption("wallpaperEnabled");
        }

        if (root.shellOwnsWallpaper() && root.actualCurrent)
            root.syncPlasmaWallpaper(root.actualCurrent);
    }

    list: filteredList
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        target: "wallpaper"
    }

    FileView {
        path: root.currentNamePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let wall = text().trim();
            if (!wall) {
                wall = root.fallback;
                Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...Colours.smartArg]);
            }
            if (Images.isVideo(root.actualCurrent) && (wall === root.getThumbnailPath(root.actualCurrent) || wall === root.getThumbnailHifiPath(root.actualCurrent))) {
                return;
            }
            root.actualCurrent = wall;
            if (!Images.isVideo(wall)) {
                syncPlasmaWallpaper(wall);
            } else {
                const hifi = thumbHifi(wall);
                if (hifi)
                    syncPlasmaWallpaper(hifi);
                else {
                    const thumb = thumbFor(wall);
                    if (thumb)
                        syncPlasmaWallpaper(thumb);
                }
            }
            // The stored image is the variant that was right for the mode when it was applied, so
            // it only needs swapping out if the mode moved while the shell was off.
            root.applyVariantForCurrentMode();
        }
        onLoadFailed: {
            root.actualCurrent = root.fallback;
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...Colours.smartArg]);
            syncPlasmaWallpaper(root.fallback);
        }
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Files
        nameFilters: Images.validImageExtensions.concat(Images.validVideoExtensions).map(e => `*.${e}`)
    }

    PreviewColours {
        id: previewColoursState
    }

    Settings {
        property alias mediaFilter: root.currentMediaFilter

        category: "Wallpapers"
    }

    Connections {
        function onWallpaperEngineChanged(): void {
            root.applyWallpaperEngine();
        }

        target: Config.background
    }

    Connections {
        function onCurrentLightChanged(): void {
            root.applyVariantForCurrentMode();
        }

        // A scheme that was not on disk yet when the wallpaper was read leaves the split
        // untested; this is the call that applies it once the file is there.
        function onSchemeLoadedChanged(): void {
            if (Colours.schemeLoaded)
                root.applyVariantForCurrentMode();
        }

        target: Colours
    }

    Process {
        id: skwdWallCheckProcess

        running: true
        command: ["systemctl", "--user", "is-active", "--quiet", "skwd-walld.service"]

        onExited: code => {
            const hasSkwd = (code === 0);
            root.hasSkwd = hasSkwd;
            root.skwdChecked = true;
            root.applyWallpaperEngine();
        }
    }
}
