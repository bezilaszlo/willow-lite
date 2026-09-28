import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property int lastCell: 0
    property string lastPosition: "Tap a numbered cell"

    Process {
        id: tapLog
        command: ["logger", "-t", "willow-touch-calibration", ""]
        running: false
    }

    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        color: "#111827"
        WlrLayershell.layer: WlrLayer.Overlay

        Grid {
            anchors.fill: parent
            columns: 3
            rows: 3

            Repeater {
                model: 9

                Rectangle {
                    required property int index
                    width: parent.width / 3
                    height: parent.height / 3
                    color: root.lastCell === index + 1 ? "#315c96" : (index % 2 ? "#25324a" : "#1b2638")
                    border.color: "#94a3b8"
                    border.width: 2

                    Text {
                        anchors.centerIn: parent
                        text: index + 1
                        color: "#f8fafc"
                        font.pixelSize: Math.min(parent.width, parent.height) / 3
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            z: 1
            text: root.lastPosition
            color: "#f8fafc"
            font.pixelSize: 20
            visible: root.lastCell === 0
        }

        MultiPointTouchArea {
            anchors.fill: parent

            onPressed: function(points) {
                if (points.length === 0)
                    return;

                const entries = [];
                for (let i = 0; i < points.length; ++i) {
                    const p = points[i];
                    const col = Math.min(2, Math.floor(p.x / width * 3));
                    const row = Math.min(2, Math.floor(p.y / height * 3));
                    const cell = row * 3 + col + 1;
                    root.lastCell = cell;
                    entries.push(`id=${p.pointId} cell=${cell} x=${Math.round(p.x)} y=${Math.round(p.y)}`);
                }
                root.lastPosition = `${entries.join("; ")} width=${Math.round(width)} height=${Math.round(height)}`;
                tapLog.command = ["logger", "-t", "willow-touch-calibration", root.lastPosition];
                tapLog.running = true;
            }
        }
    }
}
