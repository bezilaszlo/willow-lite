import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

Scope {
    id: root
    property bool visible: false
    property var applications: []
    property var runningIds: []
    signal activate(var entry)
    signal dismissed()

    function appId(entry) { return entry.id || entry.desktopId || entry.execString || entry.name }

    PanelWindow {
        visible: root.visible
        anchors { left: true; right: true; bottom: true }
        implicitHeight: 600
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "willow-app-drawer"

        Rectangle {
            anchors.fill: parent
            color: ThemeStore.darkBackground
            radius: 26
            border.color: ThemeStore.muted
            border.width: 1
            Rectangle { width: 42; height: 4; radius: 2; color: ThemeStore.muted; anchors.horizontalCenter: parent.horizontalCenter; y: 12 }
            Column {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.topMargin: 30
                anchors.bottomMargin: 18
                spacing: 12
                Row {
                    width: parent.width
                    height: 34
                    Text { text: "apps"; color: ThemeStore.brightForeground; font.family: ThemeStore.fontFamily; font.pixelSize: 20; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: root.applications.length + " installed"; color: ThemeStore.darkForeground; font.family: ThemeStore.fontFamily; font.pixelSize: 11; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
                }
                Rectangle {
                    width: parent.width; height: 42; radius: 14
                    color: ThemeStore.background; border.color: search.activeFocus ? ThemeStore.accent : ThemeStore.muted
                    Text { anchors.left: parent.left; anchors.leftMargin: 13; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; color: ThemeStore.accent; font.pixelSize: 20 }
                    TextInput {
                        id: search
                        anchors.fill: parent; anchors.leftMargin: 40; anchors.rightMargin: 12
                        color: ThemeStore.foreground; font.family: ThemeStore.fontFamily; font.pixelSize: 13
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: appGrid.positionViewAtBeginning()
                        Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; text: "filter apps"; color: ThemeStore.darkForeground; font: search.font; visible: !search.text }
                    }
                }
                GridView {
                    id: appGrid
                    width: parent.width
                    height: parent.height - 112
                    cellWidth: Math.floor(width / 4)
                    cellHeight: 108
                    clip: true
                    model: root.applications.filter(entry => !entry.noDisplay && entry.name && (!search.text || entry.name.toLocaleLowerCase().includes(search.text.toLocaleLowerCase()) || (entry.genericName || "").toLocaleLowerCase().includes(search.text.toLocaleLowerCase())))
                    delegate: Item {
                        required property var modelData
                        width: appGrid.cellWidth
                        height: appGrid.cellHeight
                        Column {
                            anchors.centerIn: parent
                            spacing: 7
                            Rectangle {
                                width: 76; height: 76; radius: 23
                                color: ThemeStore.lighterBackground
                                border.color: tileMouse.pressed ? ThemeStore.accent : ThemeStore.muted
                                border.width: tileMouse.pressed ? 2 : 1
                                Image {
                                    id: appIcon
                                    anchors.fill: parent; anchors.margins: 15
                                    source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: (modelData.name || "?").slice(0, 1).toUpperCase()
                                    color: ThemeStore.accent; font.family: ThemeStore.fontFamily; font.pixelSize: 27
                                    visible: appIcon.status !== Image.Ready
                                }
                                Rectangle {
                                    visible: root.runningIds.includes(root.appId(modelData))
                                    width: 8; height: 8; radius: 4; color: ThemeStore.green
                                    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.rightMargin: 5; anchors.bottomMargin: 5
                                    border.color: ThemeStore.darkBackground; border.width: 1
                                }
                                MouseArea { id: tileMouse; anchors.fill: parent; onClicked: root.activate(modelData) }
                            }
                            Text {
                                width: appGrid.cellWidth - 8
                                text: modelData.name
                                color: ThemeStore.foreground; font.family: ThemeStore.fontFamily; font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                z: -1
                property real startY: 0
                onPressed: startY = mouse.y
                onReleased: if (mouse.y - startY > 80) root.dismissed()
            }
        }
    }
}
