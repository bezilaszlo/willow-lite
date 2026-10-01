pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Hyprland app overview. Window focus uses the compositor address because Toplevel.activate()
// is not implemented by the active Hyprland/Aquamarine stack.
Scope {
    id: root
    Theme { id: theme }
    property bool visible: false
    property real progress: 0
    property bool tracking: false
    signal homeRequested()
    readonly property real gestureTravel: 280
    readonly property color ink: theme.background
    readonly property color panel: theme.surface
    readonly property color edge: theme.border
    readonly property color accent: theme.accent
    readonly property color paper: theme.textPrimary
    readonly property color quiet: theme.textSecondary

    function open() {
        visible = true;
        tracking = false;
        animateTo(1);
    }
    function close() {
        tracking = false;
        animateTo(0);
    }
    function toggle() {
        if (visible && progress > 0.5)
            close();
        else
            open();
    }
    function beginGesture() {
        if (!visible) {
            visible = true;
            progress = 0;
        }
        progressAnimation.stop();
        tracking = true;
    }
    function trackGesture(amount) { progress = Math.max(0, Math.min(1, amount)); }
    function endGesture(commit) {
        tracking = false;
        animateTo(commit ? 1 : 0);
    }
    function animateTo(target) {
        progressAnimation.stop();
        if (progress === target) {
            if (target === 0)
                visible = false;
            return;
        }
        progressAnimation.to = target;
        progressAnimation.start();
    }
    function focusWindow(window) {
        if (!window || !window.wayland)
            return;
        const address = window.address;
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + address + '" })');
        close();
    }
    function closeWindow(window) {
        if (window && window.wayland)
            window.wayland.close();
    }
    function closeAll() {
        const current = Hyprland.toplevels.values.slice();
        for (const window of current)
            closeWindow(window);
        close();
    }

    NumberAnimation {
        id: progressAnimation
        target: root
        property: "progress"
        duration: 230
        easing.type: Easing.OutCubic
        onFinished: if (root.progress === 0 && !root.tracking) root.visible = false
    }

    PanelWindow {
        id: overlay
        visible: root.visible
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "willow-overview"

        Rectangle {
            anchors.fill: parent
            color: root.ink
            opacity: 0.96 * root.progress
        }
        MouseArea { anchors.fill: parent; onClicked: root.close() }

        Item {
            id: content
            anchors.fill: parent
            anchors.topMargin: 54
            anchors.bottomMargin: 28
            opacity: Math.min(1, root.progress * 1.7)
            scale: 0.965 + 0.035 * root.progress

            Column {
                id: heading
                x: 28
                y: 8
                spacing: 6
                Text { text: "Recent apps"; color: root.paper; font.pixelSize: 31; font.weight: Font.Medium }
                Text { text: Hyprland.toplevels.values.length + " open"; color: root.quiet; font.pixelSize: 15 }
            }

            ListView {
                id: carousel
                anchors { top: heading.bottom; topMargin: 28; bottom: footer.top; bottomMargin: 14; left: parent.left; right: parent.right }
                orientation: ListView.Horizontal
                spacing: 16
                clip: true
                model: Hyprland.toplevels
                snapMode: ListView.SnapOneItem
                boundsBehavior: Flickable.StopAtBounds
                preferredHighlightBegin: 26
                preferredHighlightEnd: width - 26
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveDuration: 190

                delegate: Item {
                    id: cardEntry
                    required property var modelData
                    width: Math.min(overlay.width - 56, 470)
                    height: carousel.height
                    property real swipeOffset: 0
                    transform: Translate { y: cardEntry.swipeOffset }
                    readonly property var app: modelData
                    readonly property var wayland: app.wayland
                    readonly property string appName: wayland ? (wayland.appId || "Application") : "Closing app"
                    readonly property string title: wayland ? (wayland.title || appName) : ""

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        radius: 28
                        color: root.panel
                        border.color: root.edge
                        border.width: 1
                        clip: true
                        opacity: 1 - Math.min(0.42, Math.abs(cardEntry.swipeOffset) / 440)
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 17
                            spacing: 14

                            Row {
                                width: parent.width
                                height: 54
                                spacing: 12
                                Rectangle {
                                    width: 46; height: 46; radius: 16
                                    color: "#24483f"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { anchors.centerIn: parent; text: cardEntry.appName.slice(0, 1).toUpperCase(); color: root.accent; font.pixelSize: 22; font.weight: Font.DemiBold }
                                }
                                Column {
                                    width: parent.width - 112
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { width: parent.width; text: cardEntry.appName; color: root.paper; font.pixelSize: 16; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                    Text { width: parent.width; text: cardEntry.title; color: root.quiet; font.pixelSize: 13; elide: Text.ElideRight }
                                }
                                Rectangle {
                                    width: 44; height: 44; radius: 15
                                    color: closeTap.pressed ? "#452c32" : "#26363d"
                                    Text { anchors.centerIn: parent; text: "×"; color: root.paper; font.pixelSize: 24 }
                                    MouseArea { id: closeTap; anchors.fill: parent; onClicked: root.closeWindow(cardEntry.app) }
                                }
                            }

                            ClippingRectangle {
                                id: preview
                                width: parent.width
                                height: Math.max(260, parent.height - 126)
                                radius: 20
                                color: "#0b1217"
                                ScreencopyView {
                                    id: captureView
                                    anchors.fill: parent
                                    visible: cardEntry.wayland !== null
                                    captureSource: cardEntry.wayland
                                    live: false
                                }
                                Component.onCompleted: if (root.visible && cardEntry.wayland) captureView.captureFrame()
                                Connections {
                                    target: root
                                    function onVisibleChanged() {
                                        if (root.visible && cardEntry.wayland)
                                            captureView.captureFrame();
                                    }
                                }
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    visible: !cardEntry.wayland
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Preview unavailable"; color: root.quiet; font.pixelSize: 15 }
                                }
                                MouseArea {
                                    id: cardSwipe
                                    anchors.fill: parent
                                    property real pressX: 0
                                    property real pressY: 0
                                    property bool horizontalMove: false
                                    onPressed: mouse => {
                                        pressX = mouse.x;
                                        pressY = mouse.y;
                                        horizontalMove = false;
                                    }
                                    onPositionChanged: mouse => {
                                        const dx = mouse.x - pressX;
                                        const dy = mouse.y - pressY;
                                        if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 14)
                                            horizontalMove = true;
                                        if (!horizontalMove)
                                            cardEntry.swipeOffset = Math.min(0, dy);
                                    }
                                    onReleased: mouse => {
                                        const dx = mouse.x - pressX;
                                        const dy = mouse.y - pressY;
                                        cardEntry.swipeOffset = 0;
                                        if (!horizontalMove && pressY - mouse.y > height * 0.24)
                                            root.closeWindow(cardEntry.app);
                                        else if (Math.abs(dx) < 14 && Math.abs(dy) < 14)
                                            root.focusWindow(cardEntry.app);
                                    }
                                    onCanceled: cardEntry.swipeOffset = 0
                                }
                            }
                        }
                    }
                }
            }

            Row {
                id: footer
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                width: Math.min(parent.width - 56, 370)
                height: 58
                spacing: 12
                Rectangle {
                    width: parent.width - 142; height: parent.height; radius: 20
                    color: "#19342f"; border.color: "#2d6558"
                    Text { anchors.centerIn: parent; text: "Home"; color: root.accent; font.pixelSize: 16; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; onClicked: root.homeRequested() }
                }
                Rectangle {
                    width: 130; height: parent.height; radius: 20
                    visible: Hyprland.toplevels.values.length > 0
                    color: "#2b2424"; border.color: "#51403e"
                    Text { anchors.centerIn: parent; text: "Close all"; color: "#efb0a5"; font.pixelSize: 14; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; onClicked: root.closeAll() }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: Hyprland.toplevels.values.length === 0
                text: "Nothing open yet"
                color: root.quiet
                font.pixelSize: 18
            }
        }
    }

    // The bottom-edge strip owns only its own touch surface; progress stays tied to the finger.
    PanelWindow {
        id: edge
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "willow-edge"
        mask: Region { item: gestureBand }

        Item {
            id: gestureBand
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 30
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            width: root.tracking ? 132 : 94
            height: root.tracking ? 6 : 4
            radius: 4
            color: root.tracking ? root.accent : "#d9e6e2"
            opacity: 0.72
            Behavior on width { NumberAnimation { duration: 120 } }
            Behavior on height { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            anchors.fill: parent
            property real startY: 0
            property bool dragging: false
            property bool wasOpen: false
            onPressed: mouse => {
                startY = mouse.y;
                dragging = false;
                wasOpen = root.visible && !root.tracking;
                console.log("willow-bottom down y=" + Math.round(mouse.y));
            }
            onPositionChanged: mouse => {
                const travel = startY - mouse.y;
                if (!dragging && Math.abs(travel) > 10) {
                    dragging = true;
                    console.log("willow-bottom drag travel=" + Math.round(travel) + " wasOpen=" + wasOpen);
                    if (!wasOpen)
                        root.beginGesture();
                }
                if (dragging && !wasOpen)
                    root.trackGesture(travel / root.gestureTravel);
            }
            onReleased: mouse => {
                if (!dragging)
                    return;
                const travel = startY - mouse.y;
                if (wasOpen) {
                    if (travel < -40)
                        root.close();
                } else {
                    root.endGesture(travel > root.gestureTravel * 0.3);
                }
                console.log("willow-bottom up travel=" + Math.round(travel) + " wasOpen=" + wasOpen);
                dragging = false;
            }
            onCanceled: {
                if (dragging && !wasOpen)
                    root.endGesture(false);
                dragging = false;
            }
        }
    }
}
