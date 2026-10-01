import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    property bool powerHoldTriggered: false
    property bool pressStartedWithMenu: false
    property bool powerButtonReady: false

    Process {
        id: powerButton
        command: ["/usr/local/bin/willow-power-button"]
        running: true
        onExited: {
            powerButtonReady = false;
            powerHold.stop();
        }
        stdout: SplitParser {
            onRead: data => {
                if (data === "ready") {
                    powerButtonReady = true;
                } else if (data === "down" && powerButtonReady) {
                    powerHoldTriggered = false;
                    pressStartedWithMenu = powerMenu.visible;
                    powerHold.start();
                } else if (data === "up" && powerButtonReady) {
                    powerHold.stop();
                    if (powerHoldTriggered) {
                        return;
                    } else if (pressStartedWithMenu) {
                        powerMenu.visible = false;
                    } else {
                        displayToggle.running = true;
                    }
                }
            }
        }
    }

    Timer {
        id: powerHold
        interval: 2000
        onTriggered: {
            powerHoldTriggered = true;
            displayWake.running = true;
            powerMenu.visible = true;
        }
    }

    Process {
        id: displayWake
        command: ["/usr/local/bin/willow-power-action", "display-on"]
        running: false
    }

    Process {
        id: displayToggle
        command: ["/usr/local/bin/willow-power-action", "display-toggle"]
        running: false
    }

    Process {
        id: restartRequest
        command: ["/usr/local/bin/willow-power-action", "restart"]
        running: false
    }

    Process {
        id: powerOff
        command: ["/usr/local/bin/willow-power-action", "shutdown"]
        running: false
    }

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
                width: 120
                height: parent.height
                radius: 14
                color: "#25324a"
                Text { anchors.centerIn: parent; text: "Willow Lite"; color: "#f8fafc"; font.pixelSize: 17 }
            }

            Rectangle {
                width: 100
                height: parent.height
                radius: 14
                color: "#315c96"
                Text { anchors.centerIn: parent; text: "Terminal"; color: "white"; font.pixelSize: 17 }
                MouseArea { anchors.fill: parent; onClicked: { recents.visible = false; terminal.running = true } }
            }

            Rectangle {
                width: 90
                height: parent.height
                radius: 14
                color: recents.visible ? "#5b7fb8" : "#3d475b"
                Text { anchors.centerIn: parent; text: "Apps"; color: "white"; font.pixelSize: 17 }
                MouseArea { anchors.fill: parent; onClicked: recents.visible = !recents.visible }
            }

            Rectangle {
                width: 80
                height: parent.height
                radius: 14
                color: "#3d475b"
                Text { anchors.centerIn: parent; text: "Home"; color: "white"; font.pixelSize: 16 }
                MouseArea { anchors.fill: parent; onClicked: { recents.visible = false; home.running = true } }
            }

            Rectangle {
                width: 102
                height: parent.height
                radius: 14
                color: "#3d475b"
                Text { anchors.centerIn: parent; text: "Keyboard"; color: "white"; font.pixelSize: 15 }
                MouseArea { anchors.fill: parent; onClicked: keyboard.running = true }
            }
        }
    }

    PanelWindow {
        id: powerMenu
        visible: false
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: "#d9111827"
        WlrLayershell.layer: WlrLayer.Overlay

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 440)
            height: 410
            radius: 24
            color: "#1e293b"
            border.color: "#475569"
            border.width: 2

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14

                Text {
                    width: parent.width
                    height: 52
                    text: "Power"
                    color: "#f8fafc"
                    font.pixelSize: 28
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    width: parent.width
                    height: 76
                    radius: 16
                    color: "#315c96"
                    Text {
                        anchors.centerIn: parent
                        text: "Restart"
                        color: "white"
                        font.pixelSize: 22
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            powerMenu.visible = false;
                            restartRequest.running = true;
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 76
                    radius: 16
                    color: "#7f1d1d"
                    Text { anchors.centerIn: parent; text: "Shut down"; color: "white"; font.pixelSize: 22 }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            powerMenu.visible = false;
                            powerOff.running = true;
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 76
                    radius: 16
                    color: "#3d475b"
                    Text { anchors.centerIn: parent; text: "Cancel"; color: "white"; font.pixelSize: 22 }
                    MouseArea { anchors.fill: parent; onClicked: powerMenu.visible = false }
                }
            }
        }
    }

    // Recents: one card per open window; swipe sideways or tap x to close, tap to switch.
    PanelWindow {
        id: recents
        visible: false
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        margins.top: 92
        exclusiveZone: 0
        color: "#f0111827"
        WlrLayershell.layer: WlrLayer.Top

        Row {
            id: header
            x: 16
            y: 12
            width: parent.width - 32
            height: 56

            Text {
                width: parent.width - 150
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: "Open apps"
                color: "#f8fafc"
                font.pixelSize: 22
            }

            Rectangle {
                width: 150
                height: parent.height
                radius: 14
                color: "#7f1d1d"
                visible: list.count > 0
                Text { anchors.centerIn: parent; text: "Close all"; color: "white"; font.pixelSize: 17 }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        const windows = ToplevelManager.toplevels.values.slice();
                        for (const w of windows)
                            w.close();
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: "No open apps"
            color: "#94a3b8"
            font.pixelSize: 20
        }

        ListView {
            id: list
            anchors {
                top: header.bottom
                topMargin: 12
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                leftMargin: 16
                rightMargin: 16
            }
            clip: true
            spacing: 12
            model: ToplevelManager.toplevels

            delegate: Item {
                id: entry
                required property var modelData
                width: list.width
                height: 108

                Rectangle {
                    id: card
                    width: parent.width
                    height: parent.height
                    radius: 18
                    color: entry.modelData.activated ? "#315c96" : "#25324a"
                    opacity: 1 - Math.min(1, Math.abs(x) / width)

                    Behavior on x { enabled: !swipe.drag.active; NumberAnimation { duration: 160 } }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 20
                        width: parent.width - 100
                        spacing: 4
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: entry.modelData.appId || "app"
                            color: "#f8fafc"
                            font.pixelSize: 20
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: entry.modelData.title
                            color: "#cbd5e1"
                            font.pixelSize: 15
                        }
                    }

                    MouseArea {
                        id: swipe
                        anchors.fill: parent
                        drag.target: card
                        drag.axis: Drag.XAxis
                        onClicked: {
                            entry.modelData.activate();
                            recents.visible = false;
                        }
                        onReleased: {
                            if (Math.abs(card.x) > card.width * 0.35) {
                                card.x = card.x < 0 ? -card.width : card.width;
                                entry.modelData.close();
                                restore.restart();
                            } else {
                                card.x = 0;
                            }
                        }
                    }

                    // An app that ignores close stays open, so bring its card back.
                    Timer { id: restore; interval: 800; onTriggered: card.x = 0 }

                    Rectangle {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                        width: 64
                        height: 64
                        radius: 32
                        color: "#3d475b"
                        Text { anchors.centerIn: parent; text: "\u00d7"; color: "white"; font.pixelSize: 34 }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                entry.modelData.close();
                                restore.restart();
                            }
                        }
                    }
                }
            }
        }
    }
}
