pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Caelestia
import Caelestia.Config
import qs.components.misc

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    readonly property MprisPlayer active: (props.manualActive && list.includes(props.manualActive)) ? props.manualActive : (list.find(p => getIdentity(p) === GlobalConfig.services.defaultPlayer) ?? list.find(p => p.isPlaying) ?? list[0] ?? null)
    property alias manualActive: props.manualActive

    readonly property list<string> appVolumePlayers: ["Spotify", "Fastpotify", "YouTube Music"]

    property string lastNowPlayingKey: ""

    property string fetchedArtUrl: ""
    readonly property string activeArtUrl: active ? (getArtUrl(active) || fetchedArtUrl) : ""

    onActiveChanged: {
        lastNowPlayingKey = "";
        fetchArtwork();
    }

    property string lastFetchedArtist: ""
    property string lastFetchedTitle: ""

    function fetchArtwork() {
        const player = root.active;
        if (!player) {
            fetchedArtUrl = "";
            lastFetchedArtist = "";
            lastFetchedTitle = "";
            return;
        }

        // YouTube and Spotify ALREADY provide their own cover art; they must NEVER call iTunes API
        const identity = getIdentity(player).toLowerCase();
        if (identity.includes("youtube") || identity.includes("spotify")) {
            fetchedArtUrl = "";
            lastFetchedArtist = "";
            lastFetchedTitle = "";
            return;
        }

        // If player already has art, no need to fetch online
        if (getArtUrl(player) !== "") {
            fetchedArtUrl = "";
            lastFetchedArtist = "";
            lastFetchedTitle = "";
            return;
        }

        const artist = player.trackArtist ? player.trackArtist.trim() : "";
        const title = player.trackTitle ? player.trackTitle.trim() : "";
        if (title === "") {
            fetchedArtUrl = "";
            lastFetchedArtist = "";
            lastFetchedTitle = "";
            return;
        }

        if (artist === lastFetchedArtist && title === lastFetchedTitle) {
            return;
        }

        lastFetchedArtist = artist;
        lastFetchedTitle = title;
        fetchedArtUrl = "";

        // Clean parentheses, brackets, and common suffixes like remix, official video, etc.
        let cleanTitle = title.replace(/\s*[\(\[][^\)\]]*[\)\]]/g, "");
        cleanTitle = cleanTitle.replace(/\s*[-–—]?\s*(remix|official video|official audio|lyric video|lyrics video|lyrics|video|music video|audio)\s*$/i, "");
        cleanTitle = cleanTitle.trim();
        if (cleanTitle === "") cleanTitle = title;

        // Ignore artist if it is empty or is generic "unknown"
        const isArtistValid = (artist !== "" && !artist.toLowerCase().includes("unknown"));
        const searchTerm = isArtistValid ? (artist + " " + cleanTitle) : cleanTitle;

        const xhr = new XMLHttpRequest();
        const query = encodeURIComponent(searchTerm);
        const url = "https://itunes.apple.com/search?term=" + query + "&limit=1&entity=song";

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        const response = JSON.parse(xhr.responseText);
                        if (response.results && response.results.length > 0) {
                            const rawUrl = response.results[0].artworkUrl100 || "";
                            if (rawUrl !== "") {
                                fetchedArtUrl = rawUrl;
                            }
                        }
                    } catch (e) {
                        console.warn("Error parsing iTunes artwork search response:", e);
                    }
                }
            }
        }
        xhr.open("GET", url);
        xhr.send();
    }

    function getIdentity(player: MprisPlayer): string {
        if (!player)
            return "";
        const alias = GlobalConfig.services.playerAliases.values.find(a => a.from === player.identity);
        if (alias)
            return alias.to;
        if (player.identity === "com.github.th-ch.youtube-music" || player.identity === "com.github.th_ch.youtube_music")
            return "YouTube Music";
        return player.identity;
    }

    function playerMatchesSource(player: MprisPlayer, name: string): bool {
        if (!player || !name)
            return false;
        const target = String(name).trim().toLowerCase();
        if (!target)
            return false;

        const friendly = root.getIdentity(player).toLowerCase();
        const raw = String(player.identity ?? "").toLowerCase();
        const entry = String(player.entry ?? "").toLowerCase();

        if (friendly.includes(target) || raw.includes(target) || entry.includes(target))
            return true;

        const cleanTarget = target.replace(/[^a-z0-9]/g, "");
        if (cleanTarget) {
            const cleanFriendly = friendly.replace(/[^a-z0-9]/g, "");
            const cleanRaw = raw.replace(/[^a-z0-9]/g, "");
            const cleanEntry = entry.replace(/[^a-z0-9]/g, "");

            if (cleanFriendly.includes(cleanTarget) || cleanRaw.includes(cleanTarget) || cleanEntry.includes(cleanTarget))
                return true;

            if ((cleanTarget === "youtubemusic" && cleanFriendly === "ytmusic") ||
                (cleanTarget === "ytmusic" && (cleanFriendly === "youtubemusic" || cleanRaw.includes("youtube"))))
                return true;
        }

        return false;
    }

    function supportsAppVolume(player: MprisPlayer): bool {
        if (!player)
            return false;
        return root.appVolumePlayers.some(n => root.playerMatchesSource(player, n));
    }

    // First playing player not matching one of the given excluded source
    // names (empty list follows the active player), or null when every
    // player is excluded. Prefers currently-playing players over paused ones.
    function sourcePlayer(ignored: var): MprisPlayer {
        if (props.manualActive && root.list.includes(props.manualActive))
            return props.manualActive;
        const excluded = ignored || [];
        if (excluded.length === 0)
            return root.active;
        const list = root.list || [];
        let firstKept = null;
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (excluded.some(n => root.playerMatchesSource(p, String(n))))
                continue;
            if (p.isPlaying)
                return p;
            if (!firstKept)
                firstKept = p;
        }
        return firstKept;
    }

    // A display name cut into comparable tokens: lowercased, ".desktop" and
    // "-desktop" tails dropped, split on anything that is not a letter or digit.
    function nameTokens(name: var): var {
        const ignored = new Set(["org", "mpris", "mediaplayer2", "com", "github", "instance", "desktop", "application"]);
        return String(name ?? "").toLowerCase().replace(/\.desktop$/g, "").replace(/-desktop$/g, "").split(/[^a-z0-9]+/).filter(t => t.length > 0 && !ignored.has(t));
    }

    // Process id from an MPRIS bus name (chromium.instance<PID>), or "" when none carries one.
    function instancePid(name: var): string {
        const m = String(name ?? "").match(/(?:^|\.)instance(\d+)(?:$|\.)/i) || String(name ?? "").match(/_(\d+)$/);
        return m ? m[1] : "";
    }

    // Whether a PipeWire stream belongs to an MPRIS player. Compares the
    // stream name, process binary, application name, node name, and icon against
    // the player identity, desktopEntry, dbusName, and friendly name.
    function streamMatches(player: var, streamName: var, binary: var, appName: var, processId: var, nodeName: var, iconName: var): bool {
        if (!player)
            return false;
        const identity = String(player.identity ?? "");
        const desktopEntry = String(player.desktopEntry ?? "");
        const dbusName = String(player.dbusName ?? "");
        const friendly = String(root.getIdentity(player) ?? "");
        if (!identity && !desktopEntry && !dbusName && !friendly)
            return false;

        const pid = instancePid(dbusName) || instancePid(desktopEntry);
        if (pid && String(processId ?? "") === pid)
            return true;

        const playerTokens = [
            ...nameTokens(identity),
            ...nameTokens(desktopEntry),
            ...nameTokens(dbusName),
            ...nameTokens(friendly)
        ];
        const streamTokens = [
            ...nameTokens(streamName),
            ...nameTokens(binary),
            ...nameTokens(appName),
            ...nameTokens(nodeName),
            ...nameTokens(iconName)
        ];
        if (playerTokens.some(t => streamTokens.includes(t)))
            return true;

        const playerNames = [identity, desktopEntry, dbusName, friendly]
            .filter(n => n.length > 0)
            .map(n => n.toLowerCase());
        const streamNames = [streamName, binary, appName, nodeName, iconName]
            .filter(n => String(n ?? "").length > 0)
            .map(n => String(n).toLowerCase());
        return streamNames.some(sn => playerNames.some(pn => sn.includes(pn) || pn.includes(sn)));
    }

    // The PipeWire stream belonging to a player, or null when none matches.
    // Checks distinct appStreams first, then raw streams, falling back to the
    // sole active appStream when only one app is outputting audio.
    function playerStream(player: var, audio: var): var {
        if (!player || !audio)
            return null;

        const appStreams = audio.appStreams ?? [];
        const matchApp = appStreams.find(s => {
            const props = s.properties ?? {};
            return root.streamMatches(
                player,
                audio.getStreamName(s),
                (props["application.process.binary"] ?? "").toString(),
                (props["application.name"] ?? props["app.name"] ?? "").toString(),
                (props["application.process.id"] ?? "").toString(),
                (props["node.name"] ?? "").toString(),
                (props["application.icon-name"] ?? "").toString()
            );
        });
        if (matchApp)
            return matchApp;

        const streams = audio.streams ?? [];
        const matchRaw = streams.find(s => {
            if (audio.getStreamName(s) === audio.selfAppName)
                return false;
            const props = s.properties ?? {};
            return root.streamMatches(
                player,
                audio.getStreamName(s),
                (props["application.process.binary"] ?? "").toString(),
                (props["application.name"] ?? props["app.name"] ?? "").toString(),
                (props["application.process.id"] ?? "").toString(),
                (props["node.name"] ?? "").toString(),
                (props["application.icon-name"] ?? "").toString()
            );
        });
        if (matchRaw)
            return matchRaw;

        if (appStreams.length === 1)
            return appStreams[0];

        return null;
    }

    // Effective volume for scroll control: matching PipeWire stream app volume first,
    // then the global sink.
    function playerVolume(player: var, stream: var, audio: var): real {
        if (stream && audio)
            return stream?.audio?.volume ?? audio.getAppVolume(stream);
        if (root.supportsAppVolume(player) && player?.volume !== undefined && player?.volume !== null)
            return player.volume;
        return audio?.volume ?? 0;
    }

    function setPlayerVolume(player: var, stream: var, audio: var, v: real): void {
        const clamped = Math.max(0, Math.min(GlobalConfig.services.maxVolume, v));
        if (stream && audio) {
            audio.setAppVolume(stream, clamped);
        } else if (root.supportsAppVolume(player) && player && player.volume !== undefined) {
            player.volume = clamped;
        } else if (audio) {
            audio.setVolume(clamped);
        }
    }

    function getArtUrl(player: MprisPlayer): string {
        if (!player)
            return "";
        if (player.trackArtUrl && String(player.trackArtUrl).trim() !== "")
            return String(player.trackArtUrl).trim();

        const url = String(player.metadata["xesam:url"] ?? player.metadata["mpris:artUrl"] ?? "");
        const ytMatch = url.match(/(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?|shorts)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})/i);
        if (ytMatch && ytMatch[1]) {
            return "https://img.youtube.com/vi/" + ytMatch[1] + "/hqdefault.jpg";
        }

        return "";
    }

    // Quickshell only emits postTrackChanged when trackid/url/title change, so late
    // artist updates (common with mpv-mpris + yt-dlp player) never retrigger it. Watch
    // title/artist too and toast once both are usable.
    function maybeToastNowPlaying(): void {
        if (!GlobalConfig.utilities.toasts.nowPlaying)
            return;

        const player = root.active;
        if (!player)
            return;

        const title = player.trackTitle ?? "";
        const artist = player.trackArtist ?? "";
        if (!title || !artist)
            return;

        const key = `${getIdentity(player)}\0${player.uniqueId}\0${title}\0${artist}`;
        if (key === lastNowPlayingKey)
            return;

        lastNowPlayingKey = key;
        Toaster.toast(qsTr("Now Playing"), qsTr("%1 - %2").arg(artist).arg(title), "music_note");
    }

    onListChanged: {
        if (props.manualActive && !list.includes(props.manualActive))
            props.manualActive = null;
    }
    Connections {
        function onPostTrackChanged(): void {
            root.fetchArtwork();
            root.maybeToastNowPlaying();
        }

        function onTrackTitleChanged(): void {
            root.fetchArtwork();
            root.maybeToastNowPlaying();
        }

        function onTrackArtistChanged(): void {
            root.fetchArtwork();
            root.maybeToastNowPlaying();
        }

        target: root.active
    }

    PersistentProperties {
        id: props

        property MprisPlayer manualActive

        reloadableId: "players"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaToggle"
        description: qsTr("Toggle media playback")
        onPressed: {
            const active = root.active;
            if (active && active.canTogglePlaying)
                active.togglePlaying();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaPrev"
        description: qsTr("Previous track")
        onPressed: {
            const active = root.active;
            if (active && active.canGoPrevious)
                active.previous();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaNext"
        description: qsTr("Next track")
        onPressed: {
            const active = root.active;
            if (active && active.canGoNext)
                active.next();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaStop"
        description: qsTr("Stop media playback")
        onPressed: root.active?.stop()
    }

    IpcHandler {
        function getActive(prop: string): string {
            const active = root.active;
            return active ? active[prop] ?? qsTr("Invalid property") : qsTr("No active player");
        }

        function list(): string {
            return root.list.map(p => root.getIdentity(p)).join("\n");
        }

        function play(): void {
            const active = root.active;
            if (active?.canPlay)
                active.play();
        }

        function pause(): void {
            const active = root.active;
            if (active?.canPause)
                active.pause();
        }

        function playPause(): void {
            const active = root.active;
            if (active?.canTogglePlaying)
                active.togglePlaying();
        }

        function previous(): void {
            const active = root.active;
            if (active?.canGoPrevious)
                active.previous();
        }

        function next(): void {
            const active = root.active;
            if (active?.canGoNext)
                active.next();
        }

        function stop(): void {
            root.active?.stop();
        }

        target: "mpris"
    }
}
