pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root
    property var panels: []
    property bool keyboardVisible: false
    property bool keyboardStateReady: false
    property int bandWidth: 24
    property int commitDistance: 72
    readonly property color accent: "#55d6c2"
    signal hideKeyboardRequested()

    function back() {
        if (root.keyboardVisible || !root.keyboardStateReady) {
            root.hideKeyboardRequested();
            return;
        }
        for (const panel of root.panels) {
            if (panel && panel.visible) {
                if (typeof panel.close === "function")
                    panel.close();
                else
                    panel.visible = false;
                return;
            }
        }
        if (ToplevelManager.activeToplevel)
            Quickshell.execDetached(["wtype", "-k", "Escape"]);
    }

    component Edge: PanelWindow {
        id: edge
        required property bool leftSide
        anchors { top: true; bottom: true; left: leftSide; right: !leftSide }
        implicitWidth: root.bandWidth + 40
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "willow-back"
        mask: Region { item: band }

        Item {
            id: band
            x: edge.leftSide ? 0 : edge.width - root.bandWidth
            width: root.bandWidth
            height: edge.height
        }
        MouseArea {
            id: drag
            anchors.fill: parent
            property real startX: 0
            property real startY: 0
            property real inward: 0
            property real drift: 0
            property real releaseProgress: 0
            property real settleFactor: 0
            property bool releaseArmed: false
            property bool settling: false
            readonly property real progress: Math.max(0, Math.min(1, inward / root.commitDistance))
            readonly property bool armed: inward >= root.commitDistance && inward > drift
            onPressed: mouse => { startX = mouse.x; startY = mouse.y; inward = 0; drift = 0; }
            onPositionChanged: mouse => {
                inward = (edge.leftSide ? 1 : -1) * (mouse.x - startX);
                drift = Math.abs(mouse.y - startY);
            }
            onReleased: {
                releaseProgress = progress;
                releaseArmed = armed;
                settling = true;
                settleFactor = 1;
                if (armed) root.back();
                inward = 0;
                settle.start();
            }
            onCanceled: {
                releaseProgress = progress;
                releaseArmed = false;
                settling = true;
                settleFactor = 1;
                inward = 0;
                settle.start();
            }
            NumberAnimation {
                id: settle
                target: drag
                property: "settleFactor"
                from: 1
                to: 0
                duration: 170
                easing.type: Easing.OutCubic
                onFinished: drag.settling = false
            }
        }
        Rectangle {
            readonly property real progressShown: drag.pressed ? drag.progress : drag.releaseProgress * drag.settleFactor
            readonly property real shown: progressShown * (width + 8)
            visible: (drag.pressed && drag.progress > 0) || drag.settling
            width: 44; height: 44; radius: 22
            x: edge.leftSide ? shown - width : edge.width - shown
            y: Math.max(0, Math.min(edge.height - height, drag.startY - height / 2))
            color: drag.armed || (!drag.pressed && drag.releaseArmed) ? root.accent : "#c91b302e"
            scale: drag.armed || (!drag.pressed && drag.releaseArmed) ? 1.05 : 0.92
            Behavior on scale { NumberAnimation { duration: 110 } }
            opacity: drag.pressed ? 1 : (drag.settling ? drag.settleFactor : 0)
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Text { anchors.centerIn: parent; text: edge.leftSide ? "‹" : "›"; color: "#071316"; font.pixelSize: 30; font.weight: Font.Medium }
        }
    }

    Edge { id: leftEdge; leftSide: true }
    Edge { leftSide: false }
}
