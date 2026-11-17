pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.Blobs
import qs.components
import qs.components.controls
import qs.components.misc
import qs.services
import qs.utils
import qs.modules.nexus
import qs.modules.nexus.common

FloatingWindow {
    id: root

    readonly property var entries: entriesModel.list
    readonly property var history: entriesModel.list.slice().sort((a, b) => b.revision - a.revision)
    readonly property int unreadCount: entriesModel.list.filter(entry => !root.acknowledged.includes(entry.revision)).length
    readonly property string latestRelease: root.history.length > 0 ? root.history[0].version : ""
    // A dot on every row marks nothing, so the dots only appear once part of the release is read.
    readonly property bool partlyRead: root.unreadCount > 0 && root.unreadCount < root.entries.length

    property var acknowledged: []
    property bool showAfterUpdate: true
    property bool stateResolved: false
    property bool resolved: false
    property bool loaded: false
    property bool shown: false
    property bool hasAnimated: false
    property string expandedId: ""

    function isUnread(entry: var): bool {
        return !root.acknowledged.includes(entry.revision);
    }

    function isVideo(url: var): bool {
        if (!url)
            return false;
        const lower = String(url).toLowerCase();
        return lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv") || lower.endsWith(".avi") || lower.endsWith(".mov");
    }

    // Only an entry with media has anything the row cannot show.
    function isExpandable(entry: var): bool {
        if (!entry)
            return false;
        return !!entry.mediaUrl;
    }

    function releaseDate(version: var): string {
        for (const entry of root.entries) {
            if (entry.version !== version)
                continue;
            if (!entry.date)
                break;
            const parts = String(entry.date).split("-");
            if (parts.length !== 3)
                return String(entry.date);
            return Qt.formatDate(new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])), "d MMM yyyy");
        }
        return "";
    }

    function releaseCount(version: var): int {
        return root.entries.filter(entry => entry.version === version).length;
    }

    function acknowledge(revisions: var): void {
        const next = root.acknowledged.slice();
        for (const revision of revisions)
            if (!next.includes(revision))
                next.push(revision);
        if (next.length === root.acknowledged.length)
            return;
        root.acknowledged = next;
        root.saveState();
    }

    function acknowledgeAll(): void {
        root.acknowledge(root.entries.map(entry => entry.revision));
    }

    function toggleEntry(entry: var): void {
        if (!entry)
            return;
        root.acknowledge([entry.revision]);
        if (root.isExpandable(entry))
            root.expandedId = root.expandedId === entry.id ? "" : entry.id;
    }

    function saveState(): void {
        stateFile.setText(JSON.stringify({
            "schemaVersion": 1,
            "acknowledged": root.acknowledged,
            "showAfterUpdate": root.showAfterUpdate
        }));
    }

    function resolveState(): void {
        if (root.resolved || !root.stateResolved)
            return;
        root.resolved = true;

        root.loaded = true;
        if (root.unreadCount > 0 && root.showAfterUpdate)
            root.reveal(true);
        else
            root.applyVisibility();
    }

    function reveal(animate: bool): void {
        if (!animate || !Tokens.anim.enabled)
            root.hasAnimated = true;
        root.shown = true;
        root.applyVisibility();
    }

    function skipIntro(): void {
        if (root.hasAnimated)
            return;
        startupTimer.stop();
        holdTimer.stop();
        root.hasAnimated = true;
    }

    // Closing is the acknowledgement. It used to write nothing, so a user who dismissed the
    // window was handed the same release again at the next login.
    function close(): void {
        root.acknowledgeAll();
        root.shown = false;
        root.applyVisibility();
    }

    function toggle(): void {
        if (root.visible)
            root.close();
        else
            root.reveal(false);
    }

    function applyVisibility(): void {
        root.visible = root.loaded && root.shown;
    }

    color: Colours.tPalette.m3surface
    surfaceFormat.opaque: false
    title: qsTr("What's New in Caelestia")

    implicitWidth: 680
    implicitHeight: 620
    minimumSize.width: 680
    minimumSize.height: 480

    onVisibleChanged: {
        if (!root.visible && root.shown) {
            root.shown = false;
            root.acknowledgeAll();
        }
    }

    BackgroundEffect.blurRegion: Region {
        Region { x: -10; y: -10; width: 1; height: 1 }
        Region { item: (GlobalConfig.appearance.transparency.enabled && GlobalConfig.appearance.blur) ? container : null }
    }

    Entries {
        id: entriesModel
    }

    FileView {
        id: stateFile

        printErrors: false
        path: `${Paths.state}/whatsnew.json`

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.acknowledged = Array.isArray(data.acknowledged) ? data.acknowledged : [];
                root.showAfterUpdate = data.showAfterUpdate !== false;
            } catch (e) {
                console.warn("WhatsNewWindow: ignoring unreadable state: " + e);
                root.acknowledged = [];
            }
            root.stateResolved = true;
            root.resolveState();
        }

        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn("WhatsNewWindow: could not read state: " + err);
            root.stateResolved = true;
            root.resolveState();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "whatsnew"
        description: qsTr("What's New")
        onPressed: root.toggle()
    }

    IpcHandler {
        function open(): void {
            root.reveal(false);
        }

        function toggle(): void {
            root.toggle();
        }

        target: "whatsnew"
    }

    Item {
        id: container

        anchors.fill: parent

        Keys.onEscapePressed: root.hasAnimated ? root.close() : root.skipIntro()

        BlobGroup {
            id: blobGroup

            smoothing: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainerLow
        }

        BlobInvertedRect {
            anchors.fill: parent
            group: blobGroup
            opacity: Colours.tPalette.m3surfaceContainerLow.a
            radius: Tokens.rounding.large
            borderLeft: Tokens.padding.medium
            borderRight: Tokens.padding.medium
            borderTop: Tokens.padding.medium
            borderBottom: Tokens.padding.medium
        }

        Item {
            id: content

            readonly property real headerHeight: 56
            readonly property real blockHeight: 90.38 + Tokens.spacing.large + titleText.implicitHeight + versionText.implicitHeight
            readonly property real titleBlockWidth: Math.max(titleText.implicitWidth, versionText.implicitWidth)

            anchors.fill: parent
            anchors.margins: Tokens.padding.large

            Item {
                id: logoItem

                width: 128
                height: 90.38
                transformOrigin: Item.TopLeft
                scale: root.hasAnimated ? 64 / 128 : 1
                x: root.hasAnimated ? (content.width - (64 + Tokens.spacing.medium + content.titleBlockWidth)) / 2 : (content.width - width) / 2
                y: root.hasAnimated ? (content.headerHeight - 45.19) / 2 : (content.height - content.blockHeight) / 2 - 40

                Behavior on x {
                    Anim {
                        type: Anim.SlowSpatial
                    }
                }

                Behavior on y {
                    Anim {
                        type: Anim.SlowSpatial
                    }
                }

                Behavior on scale {
                    Anim {
                        type: Anim.SlowSpatial
                    }
                }

                AnimatedLogo {
                    id: logoAnim

                    anchors.fill: parent
                }
            }

            StyledText {
                id: titleText

                text: qsTr("What's New in Caelestia")
                font: Tokens.font.title.builders.large.weight(Font.Medium).build()
                color: Colours.palette.m3onSurface
                x: root.hasAnimated ? logoItem.x + 64 + Tokens.spacing.medium : (content.width - implicitWidth) / 2
                y: root.hasAnimated ? (content.headerHeight - implicitHeight) / 2 : (content.height - content.blockHeight) / 2 - 40 + 90.38 + Tokens.spacing.large

                Behavior on x {
                    Anim {
                        type: Anim.SlowSpatial
                    }
                }

                Behavior on y {
                    Anim {
                        type: Anim.SlowSpatial
                    }
                }
            }

            StyledText {
                id: versionText

                text: {
                    const version = CUtils.version ? `v${CUtils.version}` : "";
                    const date = root.releaseDate(root.latestRelease);
                    if (!date)
                        return version;
                    return version ? `${version} \u00b7 ${date}` : date;
                }
                font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                color: Colours.palette.m3onSurfaceVariant
                opacity: root.hasAnimated ? 0 : 1
                x: root.hasAnimated ? titleText.x : (content.width - implicitWidth) / 2
                y: titleText.y + titleText.implicitHeight

                Behavior on x {
                    Anim {
                        type: Anim.SlowSpatial
                    }
                }
            }

            Timer {
                id: startupTimer

                interval: 2300
                running: root.shown && !root.hasAnimated && !holdTimer.running && Tokens.anim.enabled

                onTriggered: holdTimer.start()
            }

            // The animation finishes on its own but the header holds its centred place for a
            // beat before the window rearranges. Moving the logo and title to the top on the
            // frame the animation stops reads as the hand-off arriving too early.
            Timer {
                id: holdTimer

                interval: 1000

                onTriggered: root.hasAnimated = true
            }

            TextButton {
                id: skipButton

                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: qsTr("Skip")
                type: TextButton.Text
                opacity: root.hasAnimated ? 0 : 1
                visible: opacity > 0
                activeFocusOnTab: true

                onClicked: root.skipIntro()

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }
            }

            ListView {
                id: featuresList

                anchors.top: parent.top
                anchors.topMargin: content.headerHeight + Tokens.spacing.large
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: footer.top
                anchors.bottomMargin: Tokens.spacing.medium

                opacity: root.hasAnimated ? 1 : 0
                visible: opacity > 0
                clip: true
                spacing: Tokens.spacing.medium
                model: root.history
                currentIndex: -1
                keyNavigationEnabled: true
                focus: root.hasAnimated

                Keys.onReturnPressed: root.toggleEntry(featuresList.currentItem ? featuresList.currentItem.entry : null)
                Keys.onEnterPressed: root.toggleEntry(featuresList.currentItem ? featuresList.currentItem.entry : null)

                ScrollBar.vertical: StyledScrollBar {
                    flickable: featuresList
                    policy: ScrollBar.AlwaysOn
                }

                delegate: EntryRow {}

                Behavior on opacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }
            }

            RowLayout {
                id: footer

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 56
                spacing: Tokens.spacing.medium

                opacity: root.hasAnimated ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }

                StyledText {
                    text: qsTr("Show after updates")
                    font: Tokens.font.body.builders.medium.build()
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledSwitch {
                    id: showSwitch

                    text: qsTr("Show after updates")
                    checked: root.showAfterUpdate

                    onToggled: {
                        root.showAfterUpdate = showSwitch.checked;
                        root.saveState();
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                TextButton {
                    text: qsTr("Got it")
                    type: TextButton.Filled
                    activeFocusOnTab: true

                    onClicked: root.close()
                }
            }
        }
    }

    component EntryRow: Item {
        id: row

        required property var modelData
        required property int index

        readonly property var entry: row.modelData
        readonly property bool expandable: root.isExpandable(row.entry)
        readonly property bool expanded: root.expandedId !== "" && root.expandedId === (row.entry ? row.entry.id : "")
        readonly property bool hasMedia: !!row.entry && !!row.entry.mediaUrl
        readonly property string release: row.entry ? row.entry.version : ""
        readonly property bool firstOfRelease: row.index === 0 || root.history[row.index - 1].version !== row.release

        width: ListView.view ? ListView.view.width : 0
        height: body.implicitHeight
        activeFocusOnTab: row.expandable

        Accessible.role: Accessible.ListItem
        Accessible.name: row.entry ? row.entry.title : ""
        Accessible.description: row.entry ? row.entry.description : ""
        Accessible.focusable: true
        Accessible.onPressAction: root.toggleEntry(row.entry)

        Keys.onReturnPressed: root.toggleEntry(row.entry)
        Keys.onEnterPressed: root.toggleEntry(row.entry)
        Keys.onSpacePressed: root.toggleEntry(row.entry)

        Behavior on height {
            Anim {
                type: Anim.SlowSpatial
            }
        }

        Column {
            id: body

            width: parent.width
            spacing: Tokens.spacing.small

            RowLayout {
                width: body.width - Tokens.padding.small
                visible: row.firstOfRelease
                spacing: Tokens.spacing.small

                StyledText {
                    text: row.release
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: root.releaseDate(row.release)
                    font: Tokens.font.body.builders.small.build()
                    color: Colours.palette.m3onSurfaceVariant
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: qsTr("%1 changes").arg(root.releaseCount(row.release))
                    font: Tokens.font.body.builders.small.build()
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            StyledRect {
                id: card

                width: body.width - Tokens.padding.small
                height: cardColumn.implicitHeight + Tokens.padding.large * 2
                radius: Tokens.rounding.medium
                color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                antialiasing: true
                border.width: row.activeFocus || (featuresList.activeFocus && row.ListView.isCurrentItem) ? 2 : 0
                border.color: Colours.palette.m3primary

                Behavior on height {
                    Anim {
                        type: Anim.SlowSpatial
                    }
                }

                StateLayer {
                    anchors.fill: parent
                    topLeftRadius: parent.radius
                    topRightRadius: parent.radius
                    bottomLeftRadius: parent.radius
                    bottomRightRadius: parent.radius

                    onClicked: root.toggleEntry(row.entry)
                }

                ColumnLayout {
                    id: cardColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        StyledRect {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            Layout.alignment: Qt.AlignTop
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3secondaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: row.entry && row.entry.icon ? row.entry.icon : "new_releases"
                                color: Colours.palette.m3onSecondaryContainer
                                fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                                grade: 25
                                fill: 1
                            }

                            StyledRect {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                width: 10
                                height: 10
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3primary
                                visible: root.partlyRead && root.isUnread(row.entry)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: row.entry ? row.entry.title : ""
                                font: Tokens.font.body.builders.large.weight(Font.DemiBold).build()
                                color: Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: row.entry ? row.entry.description : ""
                                font: Tokens.font.body.builders.small.build()
                                color: Colours.palette.m3onSurfaceVariant
                                wrapMode: Text.WordWrap
                            }
                        }

                        MaterialIcon {
                            Layout.alignment: Qt.AlignTop
                            visible: row.hasMedia
                            text: "expand_more"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                            rotation: row.expanded ? 180 : 0

                            Behavior on rotation {
                                Anim {
                                    type: Anim.SlowSpatial
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: media.visible ? 240 : 0
                        visible: row.expanded && row.hasMedia

                        StyledRect {
                            id: media

                            anchors.fill: parent
                            radius: Tokens.rounding.small
                            color: Colours.palette.m3surface
                            opacity: 0.5
                            visible: row.entry && !row.entry.mediaTransparent
                        }

                        AnimatedImage {
                            id: still

                            anchors.fill: parent
                            anchors.margins: Tokens.padding.small
                            source: visible ? entriesModel.mediaSource(row.entry) : ""
                            visible: row.expanded && row.hasMedia && !root.isVideo(row.entry.mediaUrl)
                            fillMode: Image.PreserveAspectFit
                            playing: visible
                        }

                        VideoOutput {
                            id: vidOut

                            anchors.fill: parent
                            anchors.margins: Tokens.padding.small
                            visible: row.expanded && row.hasMedia && root.isVideo(row.entry.mediaUrl)
                            fillMode: VideoOutput.PreserveAspectFit
                        }

                        AudioOutput {
                            id: aOut

                            muted: true
                        }

                        MediaPlayer {
                            id: mediaPlayer

                            videoOutput: vidOut
                            audioOutput: aOut
                            source: vidOut.visible ? entriesModel.mediaSource(row.entry) : ""
                            loops: MediaPlayer.Infinite

                            onSourceChanged: {
                                if (vidOut.visible)
                                    mediaPlayer.play();
                            }
                        }
                    }

                    IconTextButton {
                        Layout.alignment: Qt.AlignLeft
                        visible: row.entry && row.entry.settingsPage !== undefined
                        icon: "settings"
                        text: qsTr("Open in Settings")

                        onClicked: {
                            const pageKey = row.entry.settingsPage;
                            const subPage = row.entry.settingsSubPage ?? PageRegistry.defaultSubPageForKey(pageKey);
                            WindowFactory.create(null, {
                                initialPageIdx: pageKey,
                                initialSubPage: subPage
                            });
                            root.close();
                        }
                    }
                }
            }
        }
    }
}
