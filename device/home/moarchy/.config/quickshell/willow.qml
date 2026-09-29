import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    Process {
        id: terminal
        command: ["foot"]
        running: false
    }

    Process {
        id: home
        command: ["pkill", "-x", "foot"]
        running: false
    }

    Process {
        id: keyboard
        command: ["pkill", "-RTMIN", "wvkbd-mobintl"]
        running: false
    }

    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 92
        exclusiveZone: implicitHeight
        color: "#111827"
        WlrLayershell.layer: WlrLayer.Top

        MouseArea {
            anchors.fill: parent
            property real pressX: 0
            onPressed: pressX = mouse.x
            onReleased: {
                const delta = mouse.x - pressX;
                if (delta < -110)
                    terminal.running = true;
                else if (delta > 110)
                    home.running = true;
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8
            z: 1

            Rectangle {
                width: 150
                height: parent.height
                radius: 14
                color: "#25324a"
                Text { anchors.centerIn: parent; text: "Willow Lite"; color: "#f8fafc"; font.pixelSize: 19 }
            }

            Rectangle {
                width: 110
                height: parent.height
                radius: 14
                color: "#315c96"
                Text { anchors.centerIn: parent; text: "Terminal"; color: "white"; font.pixelSize: 18 }
                MouseArea { anchors.fill: parent; onClicked: terminal.running = true }
            }

            Rectangle {
                width: 100
                height: parent.height
                radius: 14
                color: "#3d475b"
                Text { anchors.centerIn: parent; text: "Home"; color: "white"; font.pixelSize: 18 }
                MouseArea { anchors.fill: parent; onClicked: home.running = true }
            }

            Rectangle {
                width: 122
                height: parent.height
                radius: 14
                color: "#3d475b"
                Text { anchors.centerIn: parent; text: "Keyboard"; color: "white"; font.pixelSize: 17 }
                MouseArea { anchors.fill: parent; onClicked: keyboard.running = true }
            }
        }
    }
}
