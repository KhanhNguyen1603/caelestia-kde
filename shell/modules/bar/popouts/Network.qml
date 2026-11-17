pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property PopoutState popouts

    property string view: "wireless"
    property var passwordNetwork: null
    /// Which section is showing: `""`, `"details"`, `"vpn"` or `"password"`. One value rather
    /// than a flag each, so two of them cannot be open at once — and the rows they hang off
    /// are rebuilt whenever the scan reorders the list, so this is the popout's state.
    property string openSection: ""
    property bool _isSidebarOpen: false

    readonly property var activeDeviceDetails: root.view === "wireless" ? Nmcli.wirelessDeviceDetails : Nmcli.ethernetDeviceDetails
    readonly property var activeDetails: {
        const d = root.activeDeviceDetails;
        if (!d || typeof d !== "object" || Object.keys(d).length === 0)
            return { visible: false, rows: [] };

        const dnsList = Array.isArray(d.dns) ? d.dns : [];
        return {
            visible: true,
            rows: [
                { label: qsTr("IP address"), value: d.ipAddress ?? "" },
                { label: qsTr("Subnet mask"), value: d.subnet ?? "" },
                { label: qsTr("Gateway"), value: d.gateway ?? "" },
                { label: qsTr("DNS"), value: dnsList.join(", ") },
                { label: qsTr("MAC address"), value: d.macAddress ?? "" }
            ]
        };
    }

    property real scaleOffset: 1.0
    property real fontScale: 1.0

    // Both device lists cap at the same four and a half rows. A popout that grew with every
    // visible access point pushed the rescan button and the sections below it off the panel;
    // the half row is what says there is more, and the list scrolls to reach it. The row
    // height is measured from the list rather than assumed, so it holds at any font scale.
    function listHeight(list: var): real {
        if (list.count <= 1)
            return list.contentHeight;

        const rowHeight = (list.contentHeight - list.spacing * (list.count - 1)) / list.count;
        return Math.min(list.contentHeight, rowHeight * 4.5 + list.spacing * 4);
    }

    spacing: Tokens.spacing.medium * scaleOffset
    // With the sidebar open, match its width so the popout joins it (like the
    // narrower popouts do) instead of sticking out past it.
    width: _isSidebarOpen ? Math.max(300 * scaleOffset, (Visibilities.sidebarWidthFor(Tokens.sizes.sidebar.width) * scaleOffset) - Tokens.padding.extraLargeIncreased) : 400 * scaleOffset

    RowLayout {
        Layout.topMargin: Tokens.padding.small * root.scaleOffset
        Layout.leftMargin: Tokens.padding.small * root.scaleOffset
        Layout.rightMargin: Tokens.padding.small * root.scaleOffset
        Layout.fillWidth: true
        spacing: Tokens.spacing.small * root.scaleOffset

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Network")
            font.weight: 500
            font.pointSize: Tokens.font.title.small.pointSize * root.fontScale
        }

        // The count belongs beside the title it counts, not on a row of its own: it is the
        // only thing that row carried, and a popout is short on rows.
        StyledText {
            visible: root.view === "wireless"
            text: qsTr("%1 networks").arg(Nmcli.networks.length)
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
        }

        StyledText {
            visible: root.view === "ethernet"
            text: qsTr("%1 devices").arg(Nmcli.ethernetDevices.length)
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
        }

        // The profiles are a header button rather than a section: a section spent a row
        // whether or not it was open, and the list only matters while someone is picking one.
        IconButton {
            visible: root.view === "wireless" && Nmcli.vpnConnections.length > 0
            icon: "vpn_key"
            font: Tokens.font.icon.medium
            type: IconButton.Tonal
            isRound: true
            isToggle: true
            checked: root.openSection === "vpn"
            accessibleName: qsTr("Show VPN profiles")
            inactiveColour: Colours.tPalette.m3surfaceContainerHigh
            inactiveOnColour: Colours.palette.m3onSurfaceVariant
            onClicked: root.openSection = root.openSection === "vpn" ? "" : "vpn"
        }

        // Rescanning is a small, repeatable action that belongs beside the settings that own
        // it, not a full-width button that costs the popout a row every time it is shown.
        Item {
            visible: root.view === "wireless"

            implicitWidth: scanButton.implicitWidth
            implicitHeight: scanButton.implicitHeight
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight

            IconButton {
                id: scanButton

                anchors.fill: parent
                opacity: Nmcli.scanning ? 0 : 1
                icon: "wifi_find"
                font: Tokens.font.icon.medium
                type: IconButton.Tonal
                isRound: true
                accessibleName: qsTr("Rescan networks")
                inactiveColour: Colours.tPalette.m3surfaceContainerHigh
                inactiveOnColour: Colours.palette.m3onSurfaceVariant
                disabled: Nmcli.scanning || !Nmcli.wifiEnabled
                onClicked: Nmcli.rescanWifi()

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            CircularIndicator {
                anchors.fill: parent
                visible: Nmcli.scanning
                strokeWidth: Tokens.padding.extraSmall / 2 * root.scaleOffset
                bgColour: "transparent"
                running: Nmcli.scanning
            }
        }

        IconButton {
            icon: "settings"
            font: Tokens.font.icon.medium
            type: IconButton.Tonal
            isRound: true
            inactiveColour: Colours.tPalette.m3surfaceContainerHigh
            inactiveOnColour: Colours.palette.m3onSurfaceVariant
            onClicked: root.popouts.detachRequested("network")
        }
    }

    StyledRect {
        Layout.fillWidth: true
        implicitWidth: cardLayout.implicitWidth + Tokens.padding.medium * 2 * root.scaleOffset
        implicitHeight: cardLayout.implicitHeight + Tokens.padding.medium * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: cardLayout

            width: parent.width - Tokens.padding.medium * 2 * root.scaleOffset
            x: Tokens.padding.medium * root.scaleOffset
            y: Tokens.padding.medium * root.scaleOffset
            spacing: Tokens.spacing.small * root.scaleOffset

            // The list is capped at four and a half rows: a popout that grew with every visible access
            // point pushed the rescan button and the sections below it off the panel. The half row is
            // what says there is more below, and the list scrolls to reach it.
            ListView {
                id: networkList

                visible: root.view === "wireless"
                Layout.fillWidth: true
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                spacing: Tokens.spacing.extraSmall * root.scaleOffset
                implicitHeight: root.listHeight(networkList)
                model: ScriptModel {
                    values: [...Nmcli.networks].sort((a, b) => {
                        if (a.active !== b.active)
                            return b.active - a.active;
                        return b.strength - a.strength;
                    })
                }

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: networkList
                }

                delegate: StyledRect {
                    id: networkItem

                    required property Nmcli.AccessPoint modelData
                    readonly property bool isConnecting: Nmcli.connectingSsid === modelData?.ssid
                    readonly property bool loading: networkItem.isConnecting
                    readonly property bool active: networkItem.modelData?.active ?? false
                    // The details hang off the row they describe, and only the network in use has any.
                    readonly property bool disclosable: networkItem.active && root.activeDetails.visible
                    readonly property bool disclosed: networkItem.disclosable && root.openSection === "details"

                    width: ListView.view.width
                    implicitHeight: networkColumn.implicitHeight + Tokens.padding.small * 2 * root.scaleOffset
                    radius: Tokens.rounding.small * root.scaleOffset
                    color: networkItem.active ? Colours.tPalette.m3surfaceContainerHigh : "transparent"

                    ColumnLayout {
                        id: networkColumn

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.small * root.scaleOffset
                        spacing: Tokens.spacing.extraSmall * root.scaleOffset
                        // The chevron below carries its own press area, and it can only sit above
                        // the row's press area if the column it belongs to does.
                        z: 1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small * root.scaleOffset

                            MaterialIcon {
                                text: Icons.getNetworkIcon(networkItem.modelData?.strength ?? 0)
                                color: networkItem.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                            }

                            MaterialIcon {
                                visible: networkItem.modelData?.isSecure ?? false
                                text: "lock"
                                color: Colours.palette.m3onSurfaceVariant
                                fontStyle.pointSize: Tokens.font.icon.small.pointSize * root.fontScale
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                elide: Text.ElideRight
                                text: networkItem.modelData?.ssid ?? ""
                                color: networkItem.active ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                                font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
                            }

                            RowLayout {
                                spacing: Tokens.spacing.small * root.scaleOffset

                                // The chevron keeps its own press area: a ripple stretched across
                                // the tick beside it grew from the middle of the pair instead of
                                // from the arrow the press was actually about.
                                Item {
                                    visible: networkItem.disclosable
                                    Layout.preferredWidth: Tokens.font.icon.medium.pointSize * root.scaleOffset
                                    Layout.preferredHeight: width

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "expand_more"
                                        rotation: networkItem.disclosed ? 180 : 0
                                        color: Colours.palette.m3primary
                                        fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                                        opacity: networkItem.loading ? 0 : 1

                                        Behavior on rotation {
                                            Anim {
                                                type: Anim.StandardSmall
                                            }
                                        }
                                    }

                                    StateLayer {
                                        anchors.fill: parent
                                        radius: Tokens.rounding.full
                                        showHoverBackground: false
                                        disabled: networkItem.loading
                                        onClicked: root.openSection = root.openSection === "details" ? "" : "details"
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: Tokens.font.icon.medium.pointSize * root.scaleOffset
                                    Layout.preferredHeight: width

                                    CircularIndicator {
                                        anchors.fill: parent
                                        running: networkItem.loading
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: networkItem.active ? "check_circle" : "radio_button_unchecked"
                                        color: networkItem.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                        fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                                        opacity: networkItem.loading ? 0 : 1
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            visible: networkItem.disclosed
                            Layout.fillWidth: true
                            Layout.leftMargin: Math.round((Tokens.font.icon.medium.pointSize + Tokens.spacing.small) * root.scaleOffset)
                            Layout.bottomMargin: Tokens.padding.extraSmall * root.scaleOffset
                            spacing: Tokens.spacing.extraSmall * root.scaleOffset

                            Repeater {
                                model: networkItem.disclosed ? root.activeDetails.rows : []

                                RowLayout {
                                    required property var modelData

                                    visible: (modelData?.value ?? "") !== ""

                                    Layout.fillWidth: true
                                    spacing: Tokens.spacing.small * root.scaleOffset

                                    StyledText {
                                        text: modelData?.label ?? ""
                                        color: Colours.palette.m3onSurfaceVariant
                                        font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignRight
                                        text: modelData?.value ?? ""
                                        color: Colours.palette.m3onSurfaceVariant
                                        elide: Text.ElideRight
                                        font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
                                    }
                                }
                            }
                        }
                    }

                    StateLayer {
                        anchors.fill: parent
                        radius: networkItem.radius
                        disabled: networkItem.loading || !Nmcli.wifiEnabled

                        onClicked: {
                            if (networkItem.modelData?.active) {
                                Nmcli.disconnectFromNetwork();
                            } else if (networkItem.modelData) {
                                NetworkConnection.handleConnect(networkItem.modelData, null, network => {
                                    const networkSnapshot = {
                                        ssid: network.ssid,
                                        bssid: network.bssid || "",
                                        isSecure: network.isSecure ?? true,
                                        strength: network.strength ?? 0
                                    };
                                    NetworkConnection.passwordNetwork = networkSnapshot;
                                    root.passwordNetwork = networkSnapshot;
                                    root.openSection = "password";
                                    root.popouts.currentName = "wirelesspassword";
                                });

                            }
                        }
                    }
                }
            }

            // The profiles hang under the button that opens them and cost nothing while it is
            // shut, which is what the section they used to live in could not say.
            ListView {
                id: vpnList

                visible: root.view === "wireless" && root.openSection === "vpn"
                model: Nmcli.vpnConnections
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.padding.extraSmall * root.scaleOffset
                Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                spacing: Tokens.spacing.extraSmall * root.scaleOffset
                implicitHeight: visible ? Math.min(contentHeight, Tokens.sizes.bar.networkVpnListMaxHeight * root.scaleOffset) : 0

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: vpnList
                }

                add: Transition {
                    Anim {
                        property: "opacity"
                        from: 0
                        to: 1
                        type: Anim.FastEffects
                    }
                    Anim {
                        property: "y"
                        type: Anim.FastSpatial
                    }
                }
                remove: Transition {
                    Anim {
                        property: "opacity"
                        to: 0
                        type: Anim.FastEffects
                    }
                }
                move: Transition {
                    Anim {
                        property: "y"
                        type: Anim.FastSpatial
                    }
                }
                displaced: Transition {
                    Anim {
                        property: "y"
                        type: Anim.FastSpatial
                    }
                }

                delegate: StyledRect {
                    id: vpnItem

                    required property var modelData
                    readonly property bool loading: Nmcli.vpnPendingConnection === modelData?.name

                    width: ListView.view.width
                    implicitHeight: vpnRow.implicitHeight + Tokens.padding.small * 2 * root.scaleOffset
                    radius: Tokens.rounding.small * root.scaleOffset
                    color: vpnItem.modelData?.connected ? Colours.tPalette.m3surfaceContainerHigh : "transparent"

                    RowLayout {
                        id: vpnRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.padding.medium * root.scaleOffset
                        anchors.rightMargin: Tokens.padding.medium * root.scaleOffset
                        spacing: Tokens.spacing.small * root.scaleOffset

                        MaterialIcon {
                            text: "vpn_key"
                            color: vpnItem.modelData?.connected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            elide: Text.ElideRight
                            text: vpnItem.modelData?.name ?? ""
                            color: vpnItem.modelData?.connected ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                            font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
                        }

                        Item {
                            Layout.preferredWidth: Tokens.font.icon.medium.pointSize * root.scaleOffset
                            Layout.preferredHeight: width

                            CircularIndicator {
                                anchors.fill: parent
                                running: vpnItem.loading
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: vpnItem.modelData?.connected ? "check_circle" : "radio_button_unchecked"
                                color: vpnItem.modelData?.connected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                                opacity: vpnItem.loading ? 0 : 1
                            }
                        }
                    }

                    StateLayer {
                        anchors.fill: parent
                        radius: vpnItem.radius
                        disabled: vpnItem.loading

                        onClicked: {
                            if (vpnItem.modelData?.connected) {
                                Nmcli.disconnectVpn(vpnItem.modelData.name, () => {});
                            } else if (vpnItem.modelData?.name) {
                                Nmcli.connectVpn(vpnItem.modelData.name, () => {});
                            }
                        }
                    }
                }
            }

            ListView {
                id: ethernetList

                visible: root.view === "ethernet"
                Layout.fillWidth: true
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                spacing: Tokens.spacing.extraSmall * root.scaleOffset
                implicitHeight: root.listHeight(ethernetList)
                model: ScriptModel {
                    values: [...Nmcli.ethernetDevices].sort((a, b) => {
                        if (a.connected !== b.connected)
                            return b.connected - a.connected;
                        return (a.iface || "").localeCompare(b.iface || "");
                    })
                }

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: ethernetList
                }

                delegate: StyledRect {
                    id: ethernetItem

                    required property Nmcli.EthernetDevice modelData
                    readonly property bool loading: false

                    width: ListView.view.width
                    implicitHeight: ethernetRow.implicitHeight + Tokens.padding.small * 2 * root.scaleOffset
                    radius: Tokens.rounding.small * root.scaleOffset
                    color: ethernetItem.modelData?.connected ? Colours.tPalette.m3surfaceContainerHigh : "transparent"

                    RowLayout {
                        id: ethernetRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.padding.medium * root.scaleOffset
                        anchors.rightMargin: Tokens.padding.medium * root.scaleOffset
                        spacing: Tokens.spacing.small * root.scaleOffset

                        MaterialIcon {
                            text: "cable"
                            color: ethernetItem.modelData?.connected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            elide: Text.ElideRight
                            text: ethernetItem.modelData?.iface || qsTr("Unknown")
                            color: ethernetItem.modelData?.connected ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                            font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
                        }

                        Item {
                            Layout.preferredWidth: Tokens.font.icon.medium.pointSize * root.scaleOffset
                            Layout.preferredHeight: width

                            CircularIndicator {
                                anchors.fill: parent
                                running: ethernetItem.loading
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: ethernetItem.modelData?.connected ? "check_circle" : "radio_button_unchecked"
                                color: ethernetItem.modelData?.connected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                                opacity: ethernetItem.loading ? 0 : 1
                            }
                        }
                    }

                    StateLayer {
                        anchors.fill: parent
                        radius: ethernetItem.radius
                        disabled: ethernetItem.loading

                        onClicked: {
                            if (ethernetItem.modelData?.connected && ethernetItem.modelData?.connection) {
                                Nmcli.disconnectEthernet(ethernetItem.modelData.connection, () => {});
                            } else if (ethernetItem.modelData) {
                                Nmcli.connectEthernet(ethernetItem.modelData.connection || "", ethernetItem.modelData.iface || "", () => {});
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        function onActiveChanged(): void {
            if (root.openSection === "password" && root.passwordNetwork && Nmcli.active && Nmcli.active.ssid === root.passwordNetwork.ssid) {
                root.openSection = "";
                root.passwordNetwork = null;
            }
        }

        target: Nmcli
    }

    Connections {
        function onCurrentNameChanged(): void {
            if (root.popouts.currentName !== "wirelesspassword" && root.openSection === "password") {
                root.openSection = "";
                root.passwordNetwork = null;
            }
        }

        target: root.popouts
    }
}
