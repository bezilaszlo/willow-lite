import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    property bool visible: false

    signal restartRequested()
    signal shutdownRequested()
    signal cancelRequested()

    Theme { id: theme }

    PanelWindow {
        visible: root.visible
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusiveZone: 0
        color: "#bf071316"
        WlrLayershell.layer: WlrLayer.Top

        Rectangle {
            anchors.fill: parent
            color: "#bf071316"

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 40, 420)
                height: 390
                radius: 26
                color: theme.surface
                border.color: theme.border
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 12

                    Text {
                        width: parent.width
                        height: 52
                        text: "Power"
                        color: theme.textPrimary
                        font.pixelSize: 27
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    PowerAction {
                        width: parent.width
                        label: "Restart"
                        onClicked: root.restartRequested()
                    }

                    PowerAction {
                        width: parent.width
                        label: "Shut down"
                        destructive: true
                        onClicked: root.shutdownRequested()
                    }

                    PowerAction {
                        width: parent.width
                        label: "Cancel"
                        onClicked: root.cancelRequested()
                    }
                }
            }
        }
    }

    component PowerAction: Rectangle {
        id: action
        property string label: ""
        property bool destructive: false
        signal clicked()

        height: 78
        radius: 18
        color: pointer.pressed ? theme.surfacePressed : "#142b2d"
        border.color: action.destructive ? "#70443f" : theme.border
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: action.label
            color: action.destructive ? theme.danger : theme.textPrimary
            font.pixelSize: 19
            font.weight: Font.Medium
        }

        MouseArea {
            id: pointer
            anchors.fill: parent
            onClicked: action.clicked()
        }
    }
}
