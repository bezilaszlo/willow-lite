// Frame pacing probe: animate a full-screen layer for a few seconds, print frame statistics, quit.
// Run with `qs -p tests/fps-probe.qml` inside the session; WILLOW_FPS_SECONDS overrides the 6 s run.
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        id: window
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "#0b1120"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "willow-fps-probe"

        readonly property real seconds: Number(Quickshell.env("WILLOW_FPS_SECONDS") || 6)
        property var times: []

        Repeater {
            model: 12
            Rectangle {
                required property int index
                width: window.width * 0.8
                height: 64
                radius: 20
                x: (window.width - width) / 2 + Math.sin(clock.elapsed * 2 + index) * window.width * 0.08
                y: 60 + index * (window.height - 120) / 12
                color: Qt.hsla(index / 12, 0.55, 0.5, 0.85)
                scale: 0.9 + 0.1 * Math.sin(clock.elapsed * 3 + index)
            }
        }

        Text {
            anchors.centerIn: parent
            text: "fps probe " + Math.round(clock.fps)
            color: "white"
            font.pixelSize: 28
        }

        FrameAnimation {
            id: clock
            property real elapsed: 0
            property real fps: 0
            running: true
            onTriggered: {
                elapsed += frameTime;
                if (elapsed > 0.5)
                    window.times.push(frameTime * 1000);
                fps = smoothFrameTime > 0 ? 1 / smoothFrameTime : 0;
                if (elapsed >= window.seconds + 0.5) {
                    running = false;
                    const sorted = window.times.slice().sort((a, b) => a - b);
                    const total = window.times.reduce((a, b) => a + b, 0);
                    const pick = p => sorted[Math.min(sorted.length - 1, Math.floor(p * sorted.length))];
                    const slow = window.times.filter(t => t > 25).length;
                    console.log("FPS_PROBE frames=" + sorted.length + " fps=" + (1000 * sorted.length / total).toFixed(1)
                        + " median_ms=" + pick(0.5).toFixed(2) + " p95_ms=" + pick(0.95).toFixed(2)
                        + " max_ms=" + sorted[sorted.length - 1].toFixed(2) + " over25ms=" + slow
                        + " size=" + window.width + "x" + window.height);
                    Qt.quit();
                }
            }
        }
    }
}
