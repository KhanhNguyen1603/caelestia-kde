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
    property bool showPasswordDialog: false
    property bool _isSidebarOpen: false

    readonly property var activeDeviceDetails: root.view === "wireless" ? Nmcli.wirelessDeviceDetails : Nmcli.ethernetDeviceDetails
    readonly property var activeDetails: {
        const d = root.activeDeviceDetails;
        if (!d || typeof d !== "object" || Object.keys(d).length === 0)
            return { visible: false, address: "", rows: [] };

        const dnsList = Array.isArray(d.dns) ? d.dns : [];
        return {
            visible: true,
            // The address heads the section, so it is not repeated as a row underneath.
            address: d.ipAddress ?? "",
            rows: [
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

            width: ListView.view.width
            implicitHeight: networkRow.implicitHeight + Tokens.padding.small * 2 * root.scaleOffset
            radius: Tokens.rounding.small * root.scaleOffset
            color: networkItem.modelData?.active ? Colours.tPalette.m3surfaceContainerHigh : "transparent"

            RowLayout {
                id: networkRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.medium * root.scaleOffset
                anchors.rightMargin: Tokens.padding.medium * root.scaleOffset
                spacing: Tokens.spacing.small * root.scaleOffset

                MaterialIcon {
                    text: Icons.getNetworkIcon(networkItem.modelData?.strength ?? 0)
                    color: networkItem.modelData?.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
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
                    color: networkItem.modelData?.active ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
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
                        text: networkItem.modelData?.active ? "check_circle" : "radio_button_unchecked"
                        color: networkItem.modelData?.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                        opacity: networkItem.loading ? 0 : 1
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
                            root.showPasswordDialog = true;
                            root.popouts.currentName = "wirelesspassword";
                        });

                    }
                }
            }
        }
    }

    StyledRect {
        visible: root.view === "wireless"

        Layout.topMargin: visible ? Tokens.spacing.small * root.scaleOffset : 0
        Layout.fillWidth: true
        implicitHeight: rescanBtn.implicitHeight + Tokens.padding.small * root.scaleOffset

        radius: Tokens.rounding.full * root.scaleOffset
        color: Colours.palette.m3primaryContainer

        StateLayer {
            color: Colours.palette.m3onPrimaryContainer
            disabled: Nmcli.scanning || !Nmcli.wifiEnabled
            onClicked: Nmcli.rescanWifi()
        }

        RowLayout {
            id: rescanBtn

            anchors.centerIn: parent
            spacing: Tokens.spacing.small * root.scaleOffset
            opacity: Nmcli.scanning ? 0 : 1

            MaterialIcon {
                id: scanIcon

                Layout.topMargin: Math.round(fontInfo.pointSize * 0.0575)
                animate: true
                text: "wifi_find"
                color: Colours.palette.m3onPrimaryContainer
                fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
            }

            StyledText {
                Layout.topMargin: -Math.round(scanIcon.fontInfo.pointSize * 0.0575)
                text: qsTr("Rescan networks")
                color: Colours.palette.m3onPrimaryContainer
                font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        CircularIndicator {
            anchors.centerIn: parent
            strokeWidth: Tokens.padding.extraSmall / 2 * root.scaleOffset
            bgColour: "transparent"
            implicitSize: parent.implicitHeight - Tokens.padding.large * root.scaleOffset
            running: Nmcli.scanning
        }
    }

    PopoutSection {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.padding.small * root.scaleOffset
        scaleOffset: root.scaleOffset
        fontScale: root.fontScale
        title: qsTr("VPN")
        summary: qsTr("%1 profiles").arg(Nmcli.vpnConnections.length)
        expanded: false

        ListView {
            id: vpnList

            model: Nmcli.vpnConnections

            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.extraSmall * root.scaleOffset
            Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset

            clip: true
            interactive: Nmcli.vpnConnections.length > 1
            boundsBehavior: Flickable.StopAtBounds
            spacing: Tokens.spacing.extraSmall * root.scaleOffset
            implicitHeight: Math.min(contentHeight, Tokens.sizes.bar.networkVpnListMaxHeight * root.scaleOffset)

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

        StyledText {
            visible: Nmcli.vpnConnections.length === 0
            Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset
            text: qsTr("No VPN profiles found")
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
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

    PopoutSection {
        visible: root.activeDetails.visible
        Layout.fillWidth: true
        Layout.topMargin: visible ? Tokens.padding.medium * root.scaleOffset : 0
        scaleOffset: root.scaleOffset
        fontScale: root.fontScale
        title: qsTr("Connection details")
        // The address is the part anyone opens this for, so it is on the shut header.
        summary: root.activeDetails.address
        expanded: false

        Repeater {
            model: root.activeDetails.rows

            RowLayout {
                required property var modelData

                visible: (modelData?.value ?? "") !== ""

                Layout.fillWidth: true
                Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset
                spacing: Tokens.spacing.small * root.scaleOffset

                StyledText {
                    text: modelData?.label ?? ""
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
    }

    Connections {
        function onActiveChanged(): void {
            if (root.showPasswordDialog && root.passwordNetwork && Nmcli.active && Nmcli.active.ssid === root.passwordNetwork.ssid) {
                root.showPasswordDialog = false;
                root.passwordNetwork = null;
            }
        }

        function onScanningChanged(): void {
            if (!Nmcli.scanning)
                scanIcon.rotation = 0;
        }

        target: Nmcli
    }

    Connections {
        function onCurrentNameChanged(): void {
            if (root.popouts.currentName !== "wirelesspassword" && root.showPasswordDialog) {
                root.showPasswordDialog = false;
                root.passwordNetwork = null;
            }
        }

        target: root.popouts
    }
}
