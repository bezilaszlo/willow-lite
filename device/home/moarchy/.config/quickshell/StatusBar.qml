import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    Theme { id: theme }

    property string clockText: "--:--"
    property string batteryText: "Battery unavailable"
    property string networkText: "Network unavailable"

    anchors { top: true; left: true; right: true }
    implicitHeight: 62
    exclusiveZone: implicitHeight
    color: theme.background
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "willow-status"

    Rectangle {
        anchors.fill: parent
        color: theme.background
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: theme.divider
        }
        Row {
            anchors.fill: parent
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            spacing: 13

            Text {
                width: 86
                height: parent.height
                text: root.clockText
                color: theme.textPrimary
                font.pixelSize: 19
                font.weight: Font.DemiBold
                verticalAlignment: Text.AlignVCenter
                Accessible.name: "Device time " + root.clockText
            }
            Rectangle { width: 1; height: 24; anchors.verticalCenter: parent.verticalCenter; color: theme.divider }
            Text {
                width: 110
                height: parent.height
                text: root.batteryText
                color: theme.textSecondary
                font.pixelSize: 13
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                Accessible.name: root.batteryText
            }
            Text {
                width: Math.max(80, parent.width - 86 - 1 - 110 - 3 * parent.spacing)
                height: parent.height
                text: root.networkText
                color: theme.textMuted
                font.pixelSize: 13
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                Accessible.name: root.networkText
            }
        }
    }
}
