import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "willow-screenshot"

        Rectangle {
            anchors.fill: parent
            color: "#c8fff4"
            opacity: 0
            SequentialAnimation on opacity {
                NumberAnimation { to: 0.42; duration: 70; easing.type: Easing.OutCubic }
                NumberAnimation { to: 0; duration: 220; easing.type: Easing.OutCubic }
            }
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 20 }
            height: 76
            radius: 24
            color: "#14282b"
            border.color: "#35645e"
            border.width: 1
            Row {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                Rectangle { width: 42; height: 42; radius: 15; color: "#24483f"; anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "✓"; color: "#75e0c1"; font.pixelSize: 21 }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Screenshot saved"; color: "#f3f7f5"; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Text { text: (Quickshell.env("WILLOW_SCREENSHOT") || "").split("/").pop(); color: "#a6bbb7"; font.pixelSize: 12; elide: Text.ElideMiddle }
                }
            }
            SequentialAnimation on opacity {
                PauseAnimation { duration: 1250 }
                NumberAnimation { to: 0; duration: 230 }
                ScriptAction { script: Qt.quit() }
            }
        }
    }
}
