pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

// "Create New" panel: pick a file or folder type, choose a name and place at the clicked spot.
Item {
    id: root

    property var controller: null
    property bool open: false
    property point at
    property var cell: null

    property string selectedType: "text_file"
    property bool isFolder: false

    readonly property var creationTypes: [
        {
            type: "folder",
            name: qsTr("Folder"),
            defaultName: qsTr("New Folder"),
            ext: "",
            icon: "folder",
            isFolder: true
        },
        {
            type: "text_file",
            name: qsTr("Text File"),
            defaultName: "New Document.txt",
            ext: ".txt",
            icon: "description",
            isFolder: false
        },
        {
            type: "markdown_file",
            name: qsTr("Markdown"),
            defaultName: "document.md",
            ext: ".md",
            icon: "markdown",
            isFolder: false
        },
        {
            type: "custom_file",
            name: qsTr("New File"),
            defaultName: "New File",
            ext: "",
            icon: "draft",
            isFolder: false
        }
    ]

    Timer {
        id: focusTimer

        interval: 50
        onTriggered: {
            nameField.forceActiveFocus();
            const dot = nameField.text.lastIndexOf(".");
            if (dot > 0 && !root.isFolder) {
                nameField.select(0, dot);
            } else {
                nameField.selectAll();
            }
        }
    }

    onOpenChanged: {
        if (open) {
            focusTimer.restart();
        }
    }

    Keys.onEscapePressed: root.open = false

    function openAt(x: real, y: real, target: var): void {
        at = Qt.point(x, y);
        cell = target;
        selectType("text_file");
        open = true;
        focusTimer.restart();
    }

    function selectType(t: string): void {
        selectedType = t;
        const info = creationTypes.find(item => item.type === t) ?? creationTypes[1];
        isFolder = info.isFolder;
        const candidate = root.controller?.uniqueDesktopName(info.defaultName) ?? info.defaultName;
        nameField.text = candidate;
        if (open) {
            focusTimer.restart();
        }
    }

    function createCurrent(): void {
        const text = nameField.text.trim();
        if (!text)
            return;
        root.open = false;
        root.controller?.createNewItem(text, isFolder, root.cell);
    }

    anchors.fill: parent
    visible: open || panel.opacity > 0

    MouseArea {
        anchors.fill: parent
        enabled: root.open
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.open = false
    }

    Elevation {
        id: panel

        x: Math.max(Tokens.padding.large, Math.min(root.width - width - Tokens.padding.large, root.at.x))
        y: Math.max(Tokens.padding.large, Math.min(root.height - height - Tokens.padding.large, root.at.y))
        width: 360
        height: content.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.large
        level: 2
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.9
        transformOrigin: Item.TopLeft

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.FastSpatial
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
        }

        StyledRect {
            anchors.fill: parent
            radius: parent.radius
            color: GlobalConfig.appearance.pitchBlack ? "#000000" : Colours.palette.m3surfaceContainerLow

            ColumnLayout {
                id: content

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: qsTr("Create New")
                        font: Tokens.font.title.medium
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    IconButton {
                        icon: "close"
                        type: ButtonBase.Text
                        onClicked: root.open = false
                    }
                }

                GridLayout {
                    columns: 2
                    rowSpacing: Tokens.spacing.small
                    columnSpacing: Tokens.spacing.small
                    Layout.fillWidth: true

                    Repeater {
                        model: root.creationTypes

                        StyledRect {
                            id: card

                            required property var modelData

                            readonly property bool isSelected: card.modelData.type === root.selectedType

                            Layout.fillWidth: true
                            implicitHeight: 48
                            radius: Tokens.rounding.medium
                            color: isSelected ? Colours.palette.m3secondaryContainer : (cardArea.containsMouse ? Colours.palette.m3surfaceContainerHigh : Colours.palette.m3surfaceContainer)
                            border.width: isSelected ? 2 : 0
                            border.color: Colours.palette.m3primary

                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Tokens.padding.large
                                anchors.rightMargin: Tokens.padding.large
                                spacing: Tokens.spacing.medium

                                MaterialIcon {
                                    text: card.modelData.icon
                                    color: card.isSelected ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                    fontStyle: Tokens.font.icon.builders.large.build()
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                StyledText {
                                    text: card.modelData.name
                                    font: Tokens.font.body.medium
                                    color: card.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            MouseArea {
                                id: cardArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectType(card.modelData.type)
                                onDoubleClicked: {
                                    root.selectType(card.modelData.type);
                                    root.createCurrent();
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledTextField {
                        id: nameField

                        Layout.fillWidth: true
                        placeholderText: qsTr("File or folder name...")
                        focus: true
                        onAccepted: root.createCurrent()
                        Keys.onEscapePressed: root.open = false
                    }

                    IconTextButton {
                        icon: "check"
                        text: qsTr("Create")
                        type: ButtonBase.Filled
                        onClicked: root.createCurrent()
                    }
                }
            }
        }
    }
}
