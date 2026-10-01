import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

PanelWindow {
    id: root
    property string clockText: "--:--"
    property string batteryText: "Battery unavailable"
    property string networkText: "Network unavailable"
    property string pillMessage: ""
    property bool home: false
    property bool shown: true
    signal controlCenterRequested()
    signal pillActivated()

    visible: root.shown

    function compactNetwork() {
        const value = networkText.toLowerCase()
        if (value.includes("usb")) return "usb"
        if (value.includes("unavailable")) return "net ?"
        return networkText.length > 12 ? networkText.slice(0, 11) + "…" : networkText
    }
    function compactBattery() {
        const match = batteryText.match(/[0-9]+%/)
        return match ? match[0] : (batteryText.toLowerCase().includes("unavailable") ? "--" : batteryText)
    }

    anchors { top: true; left: true; right: true }
    implicitHeight: 40
    exclusiveZone: implicitHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "willow-status"

    Item {
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: ThemeStore.background }
        Row {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 16
            Text {
                visible: !root.home
                width: 100
                height: parent.height
                text: root.clockText
                color: ThemeStore.brightForeground
                font.family: ThemeStore.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
            }
            Item { width: parent.width - 290; height: parent.height }
            Row {
                height: parent.height
                spacing: 11
                Text {
                    text: root.compactNetwork()
                    color: ThemeStore.foreground
                    font.family: ThemeStore.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    width: 115
                    height: parent.height
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    text: root.compactBattery()
                    color: ThemeStore.brightForeground
                    font.family: ThemeStore.fontFamily
                    font.pixelSize: 11
                    width: 64
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
        Rectangle {
            id: notchPill
            width: root.pillMessage ? 168 : 30
            height: root.pillMessage ? 30 : 27
            radius: 16
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            color: "#000000"
            border.color: root.pillMessage ? ThemeStore.muted : "#000000"
            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            Text {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                text: root.pillMessage
                color: ThemeStore.brightForeground
                font.family: ThemeStore.fontFamily
                font.pixelSize: 10
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                opacity: root.pillMessage ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
            MouseArea { anchors.fill: parent; onClicked: root.pillActivated() }
        }
        MouseArea {
            anchors.fill: parent
            z: -1
            property real startY: 0
            property real startX: 0
            onPressed: { startY = mouse.y; startX = mouse.x }
            onReleased: {
                const dy = mouse.y - startY
                const dx = Math.abs(mouse.x - startX)
                if (dy > 50 && dy > dx) root.controlCenterRequested()
            }
        }
    }
}
