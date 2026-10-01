import QtQuick
import "."

Item {
    id: root

    property bool dark: false
    property bool awake: true
    property bool powerMenuVisible: false
    property string clockText: "--:--"
    property string dateText: "Date unavailable"
    property string systemText: "System status unavailable"
    property real swipeOffset: 0

    signal restartRequested()
    signal shutdownRequested()
    signal cancelPowerMenuRequested()

    Rectangle {
        anchors.fill: parent
        color: root.dark ? "#000000" : ThemeStore.darkerBackground
    }

    Item {
        width: parent.width
        height: parent.height
        y: root.swipeOffset

        Item {
            x: 24
            y: 112
            width: parent.width - 68
            height: 342
            visible: root.awake

            Column {
                anchors.fill: parent
                spacing: 0

                Text {
                    width: parent.width
                    height: 171
                    text: root.clockText.length >= 5 ? root.clockText.slice(0, 2) : root.clockText
                    color: ThemeStore.brightForeground
                    font.family: ThemeStore.fontFamily
                    font.pixelSize: 206
                    font.weight: Font.Thin
                    font.letterSpacing: -15.45
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    height: 171
                    text: root.clockText.length >= 5 ? root.clockText.slice(3, 5) : ""
                    color: ThemeStore.accent
                    font.family: ThemeStore.fontFamily
                    font.pixelSize: 206
                    font.weight: Font.Thin
                    font.letterSpacing: -15.45
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }
        }

        Text {
            x: 34
            y: 477
            width: parent.width - 68
            visible: root.awake
            text: root.dateText.toLowerCase()
            color: ThemeStore.foreground
            font.family: ThemeStore.fontFamily
            font.pixelSize: 21
            elide: Text.ElideRight
        }

        Text {
            x: 34
            y: 514
            width: parent.width - 68
            text: root.systemText
            color: ThemeStore.darkForeground
            font.family: ThemeStore.fontFamily
            font.pixelSize: 13
            elide: Text.ElideRight
            visible: root.awake
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 54
            spacing: 12
            visible: root.awake && !root.powerMenuVisible

            Text {
                text: "↑"
                color: ThemeStore.accent
                font.family: ThemeStore.fontFamily
                font.pixelSize: 19
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "swipe up to unlock"
                color: ThemeStore.darkForeground
                font.family: ThemeStore.fontFamily
                font.pixelSize: 13
                font.letterSpacing: 1.0
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.powerMenuVisible && root.awake
            color: "#99000000"
            z: 4

            MouseArea {
                anchors.fill: parent
                onClicked: root.cancelPowerMenuRequested()
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 40, 420)
                height: 326
                radius: 28
                color: ThemeStore.lighterBackground
                border.color: ThemeStore.muted
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 10

                    Text {
                        width: parent.width
                        height: 48
                        text: "Power"
                        color: ThemeStore.brightForeground
                        font.family: ThemeStore.fontFamily
                        font.pixelSize: 26
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    LockPowerAction {
                        width: parent.width
                        label: "Restart"
                        onClicked: root.restartRequested()
                    }

                    LockPowerAction {
                        width: parent.width
                        label: "Shut down"
                        destructive: true
                        onClicked: root.shutdownRequested()
                    }

                    LockPowerAction {
                        width: parent.width
                        label: "Cancel"
                        onClicked: root.cancelPowerMenuRequested()
                    }
                }
            }
        }
    }

    component LockPowerAction: Rectangle {
        id: action
        property string label: ""
        property bool destructive: false
        signal clicked()

        height: 72
        radius: 18
        color: pointer.pressed ? ThemeStore.selection : ThemeStore.background
        border.color: action.destructive ? ThemeStore.red : ThemeStore.muted
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: action.label
            color: action.destructive ? ThemeStore.red : ThemeStore.brightForeground
            font.family: ThemeStore.fontFamily
            font.pixelSize: 17
        }

        MouseArea {
            id: pointer
            anchors.fill: parent
            onClicked: action.clicked()
        }
    }
}
