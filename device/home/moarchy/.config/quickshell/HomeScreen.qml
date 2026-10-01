import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    Theme { id: theme }

    property bool visible: false
    property string clockText: "Time unavailable"
    property string dateText: "Date unavailable"
    property string batteryText: "Battery unavailable"
    property string networkText: "Network unavailable"
    property var applications: []

    signal terminalRequested()
    signal overviewRequested()
    signal keyboardRequested()
    signal dismissRequested()

    function refreshApplications() {
        applications = DesktopEntries.applications.values
            .filter(entry => !entry.noDisplay && entry.name)
            .sort((a, b) => a.name.localeCompare(b.name));
    }

    Component.onCompleted: refreshApplications()
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.refreshApplications(); }
    }

    PanelWindow {
        visible: root.visible
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top

        Rectangle {
            anchors.fill: parent
            color: theme.background

            Rectangle {
                x: 0
                y: 0
                width: parent.width
                height: 5
                color: theme.accent
            }

            Column {
                anchors.fill: parent
                anchors.leftMargin: 28
                anchors.rightMargin: 28
                anchors.topMargin: 22
                anchors.bottomMargin: 28
                spacing: 0

                Text {
                    width: parent.width
                    text: root.clockText
                    color: theme.textPrimary
                    font.pixelSize: 46
                    font.weight: Font.Light
                    font.letterSpacing: -1.5
                    elide: Text.ElideRight
                    topPadding: 22
                }

                Text {
                    width: parent.width
                    text: root.dateText
                    color: theme.textMuted
                    font.pixelSize: 15
                    topPadding: 2
                }

                Row {
                    width: parent.width
                    height: 28
                    spacing: 14

                    Text {
                        text: root.batteryText
                        color: theme.textSecondary
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }

                    Rectangle { width: 3; height: 3; radius: 2; color: theme.textMuted; anchors.verticalCenter: parent.verticalCenter }

                    Text {
                        width: parent.width - 140
                        text: root.networkText
                        color: theme.textSecondary
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                }

                Row {
                    width: parent.width
                    height: 62
                    spacing: 12
                    Rectangle {
                        width: (parent.width - parent.spacing) / 2
                        height: 54
                        radius: 18
                        color: recentTap.pressed ? theme.surfacePressed : theme.surface
                        border.color: theme.border
                        Text { anchors.centerIn: parent; text: "Recent apps"; color: theme.textPrimary; font.pixelSize: 15; font.weight: Font.Medium }
                        MouseArea { id: recentTap; anchors.fill: parent; onClicked: root.overviewRequested() }
                    }
                    Rectangle {
                        width: (parent.width - parent.spacing) / 2
                        height: 54
                        radius: 18
                        color: keyboardTap.pressed ? theme.surfacePressed : theme.surface
                        border.color: theme.border
                        Text { anchors.centerIn: parent; text: "Keyboard"; color: theme.textPrimary; font.pixelSize: 15; font.weight: Font.Medium }
                        MouseArea { id: keyboardTap; anchors.fill: parent; onClicked: root.keyboardRequested() }
                    }
                }

                Text {
                    width: parent.width
                    text: "Applications"
                    color: theme.textPrimary
                    font.pixelSize: 21
                    font.weight: Font.Medium
                    bottomPadding: 18
                }

                GridView {
                    id: grid
                    width: parent.width
                    height: Math.max(104, parent.height - 446)
                    cellWidth: Math.floor(width / 2)
                    cellHeight: 104
                    clip: true
                    model: root.applications

                    delegate: Rectangle {
                        id: appTile
                        required property var modelData
                        width: grid.cellWidth - 8
                        height: 90
                        radius: 20
                        color: appTap.pressed ? theme.surfacePressed : theme.surface
                        border.color: appTap.pressed ? theme.accent : theme.border
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.margins: 13
                            spacing: 11
                            Rectangle {
                                id: appIconTile
                                width: 44; height: 44; radius: 15
                                color: "#1d3b38"
                                anchors.verticalCenter: parent.verticalCenter
                                Image {
                                    id: appIcon
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    source: appTile.modelData.icon ? Quickshell.iconPath(appTile.modelData.icon, true) : ""
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: (appTile.modelData.name || "?").slice(0, 1).toUpperCase()
                                    color: theme.accent
                                    font.pixelSize: 20
                                    font.weight: Font.DemiBold
                                    visible: appIcon.status !== Image.Ready
                                }
                            }
                            Column {
                                width: parent.width - 55
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text {
                                    width: parent.width
                                    text: appTile.modelData.name
                                    color: theme.textPrimary
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: appTile.modelData.genericName || appTile.modelData.comment || "Application"
                                    color: theme.textMuted
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        Accessible.name: appTile.modelData.name
                        Accessible.role: Accessible.Button
                        MouseArea {
                            id: appTap
                            anchors.fill: parent
                            onClicked: {
                                appTile.modelData.execute();
                                root.dismissRequested();
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 66
                    visible: ToplevelManager.toplevels.values.length > 0
                    radius: 20
                    color: theme.surface
                    border.color: theme.border
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 18
                        spacing: 10

                        Text {
                            width: parent.width - 42
                            text: "Return to the open window"
                            color: theme.textSecondary
                            font.pixelSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "↗"
                            color: theme.accent
                            font.pixelSize: 23
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.dismissRequested()
                    }
                }
            }
        }
    }
}
