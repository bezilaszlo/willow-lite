pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import "."

// Hyprland app overview. Window focus uses the compositor address because Toplevel.activate()
// is not implemented by the active Hyprland/Aquamarine stack.
Scope {
    id: root
    property bool visible: false
    property real progress: 0
    property bool tracking: false
    property real dragProgress: 0
    property bool recentsGesture: false
    property bool homeVisible: false
    property bool gestureEnabled: true
    property bool previewMode: false
    property var lastFocusedWindow: null
    property var previousWindow: null
    property var mruWindows: []
    signal homeRequested()
    signal drawerRequested()
    readonly property real gestureTravel: 280
    readonly property color ink: ThemeStore.darkBackground
    readonly property color panel: ThemeStore.background
    readonly property color edge: ThemeStore.muted
    readonly property color accent: ThemeStore.accent
    readonly property color paper: ThemeStore.foreground
    readonly property color quiet: ThemeStore.darkForeground

    Component.onCompleted: {
        if (!previewMode) {
            lastFocusedWindow = ToplevelManager.activeToplevel;
            refreshMru();
        }
    }
    function refreshMru() {
        const open = Hyprland.toplevels.values.slice();
        const live = mruWindows.filter(window => open.includes(window));
        for (const window of open)
            if (!live.includes(window)) live.push(window);
        const active = ToplevelManager.activeToplevel;
        if (active && live.includes(active)) {
            const index = live.indexOf(active);
            live.splice(index, 1);
            live.unshift(active);
        }
        mruWindows = live;
    }
    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            if (root.previewMode)
                return;
            const active = ToplevelManager.activeToplevel;
            if (active && active !== root.lastFocusedWindow)
                root.previousWindow = root.lastFocusedWindow;
            root.lastFocusedWindow = active;
            root.refreshMru();
        }
    }
    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() { if (!root.previewMode) root.refreshMru(); }
    }

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
        tracking = true;
        recentsGesture = false;
        dragProgress = 0;
        progressAnimation.stop();
    }
    function beginRecentsGesture(amount) {
        if (!visible)
            visible = true;
        recentsGesture = true;
        tracking = true;
        progress = Math.max(0, Math.min(1, amount));
        progressAnimation.stop();
    }
    function trackGesture(amount) {
        dragProgress = Math.max(0, Math.min(1, amount));
        if (recentsGesture)
            progress = Math.max(0, Math.min(1, amount));
    }
    function endGesture(commit) {
        tracking = false;
        if (recentsGesture) {
            recentsGesture = false;
            animateTo(commit ? 1 : 0);
        } else {
            visible = false;
            if (commit)
                homeRequested();
        }
    }
    function quickSwitch() {
        if (previewMode)
            return false;
        const window = previousWindow;
        if (!window || !window.wayland || !Hyprland.toplevels.values.includes(window))
            return false;
        focusWindow(window);
        return true;
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
        if (previewMode || !window || !window.wayland)
            return;
        const address = window.address;
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + address + '" })');
        close();
    }
    function closeWindow(window) {
        if (!previewMode && window && window.wayland)
            window.wayland.close();
    }
    function closeAll() {
        if (previewMode)
            return;
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
        Item {
            anchors.fill: parent
            visible: !root.previewMode && root.tracking && !root.recentsGesture && ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.wayland
            ScreencopyView {
                id: gestureCapture
                anchors.fill: parent
                captureSource: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.wayland : null
                live: false
                scale: 1 - Math.min(0.38, root.dragProgress * 0.38)
                transformOrigin: Item.Bottom
            }
            Connections {
                target: root
                function onTrackingChanged() {
                    if (root.tracking && ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.wayland)
                        gestureCapture.captureFrame();
                }
            }
        }
        MouseArea { anchors.fill: parent; onClicked: root.homeRequested() }

        Item {
            id: content
            anchors.fill: parent
            anchors.topMargin: 54
            anchors.bottomMargin: 28
            opacity: Math.min(1, root.progress * 1.7)
            scale: 0.965 + 0.035 * root.progress

            ListView {
                id: carousel
                anchors { top: parent.top; topMargin: 8; bottom: footer.top; bottomMargin: 14; left: parent.left; right: parent.right }
                orientation: ListView.Horizontal
                readonly property real cardStep: overlay.width * 0.62 + 28
                spacing: 0
                leftMargin: Math.max(0, (width - cardStep) / 2)
                rightMargin: Math.max(0, (width - cardStep) / 2)
                clip: true
                model: root.mruWindows.slice().reverse()
                currentIndex: count > 0 ? count - 1 : -1
                snapMode: ListView.SnapOneItem
                boundsBehavior: Flickable.StopAtBounds
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: Math.max(0, (width - cardStep) / 2)
                preferredHighlightEnd: preferredHighlightBegin + cardStep
                onCountChanged: if (count > 0 && root.visible) Qt.callLater(() => positionViewAtIndex(count - 1, ListView.Center))
                Component.onCompleted: if (root.visible && count > 0) Qt.callLater(() => positionViewAtIndex(count - 1, ListView.Center))
                Connections {
                    target: root
                    function onVisibleChanged() {
                        if (root.visible && carousel.count > 0)
                            Qt.callLater(() => carousel.positionViewAtIndex(carousel.count - 1, ListView.Center));
                    }
                }

                delegate: Item {
                    id: cardEntry
                    required property var modelData
                    required property int index
                    width: carousel.cardStep
                    height: carousel.height
                    property real swipeOffset: 0
                    transform: Translate { y: cardEntry.swipeOffset }
                    readonly property var app: modelData
                    readonly property var wayland: app.wayland
                    readonly property string appName: root.previewMode && app.previewName ? app.previewName : (wayland ? (wayland.appId || "Application") : "Closing app")
                    readonly property string title: root.previewMode && app.previewTitle ? app.previewTitle : (wayland ? (wayland.title || appName) : "")
                    z: index + 1

                    Item {
                        id: scaledCard
                        width: overlay.width
                        height: overlay.height
                        x: (cardEntry.width - width) / 2
                        y: (carousel.height - height) / 2 + 34
                        scale: 0.62
                        transformOrigin: Item.Center

                        Rectangle {
                            id: card
                            anchors.fill: parent
                            radius: 46
                            color: root.panel
                            border.color: root.edge
                            border.width: 1
                            clip: true
                            opacity: 1 - Math.min(0.42, Math.abs(cardEntry.swipeOffset) / 440)
                            Behavior on opacity { NumberAnimation { duration: 120 } }

                            ClippingRectangle {
                                id: preview
                                anchors.fill: parent
                                radius: 46
                                color: ThemeStore.darkerBackground
                                ScreencopyView {
                                    id: captureView
                                    anchors.fill: parent
                                    visible: !root.previewMode && cardEntry.wayland !== null
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
                                    visible: root.previewMode && !cardEntry.wayland
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Preview capture disabled"; color: root.quiet; font.family: ThemeStore.fontFamily; font.pixelSize: 15 }
                                }
                                MouseArea {
                                    id: cardSwipe
                                    anchors.fill: parent
                                    property real pressX: 0
                                    property real pressY: 0
                                    property double pressedAt: 0
                                    property bool horizontalMove: false
                                    onPressed: mouse => {
                                        pressX = mouse.x;
                                        pressY = mouse.y;
                                        pressedAt = Date.now();
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
                                        const elapsed = Math.max(1, Date.now() - pressedAt);
                                        const upwardSpeed = -dy / elapsed;
                                        if (!horizontalMove && dy < 0 && (-dy > height * 0.20 || upwardSpeed > 0.5))
                                            dismissCard.start();
                                        else {
                                            settleCard.start();
                                            if (Math.abs(dx) < 14 && Math.abs(dy) < 14)
                                                root.focusWindow(cardEntry.app);
                                        }
                                    }
                                    onCanceled: settleCard.start()
                                }
                                NumberAnimation { id: settleCard; target: cardEntry; property: "swipeOffset"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                                NumberAnimation {
                                    id: dismissCard
                                    target: cardEntry
                                    property: "swipeOffset"
                                    to: -overlay.height
                                    duration: 210
                                    easing.type: Easing.OutCubic
                                    onFinished: root.closeWindow(cardEntry.app)
                                }
                            }
                        }

                        Row {
                            x: 6
                            y: -66
                            spacing: 14
                            opacity: root.visible ? 1 : 0
                            Rectangle {
                                width: 46; height: 46; radius: 15
                                color: ThemeStore.lighterBackground
                                Text { anchors.centerIn: parent; text: cardEntry.appName.slice(0, 1).toUpperCase(); color: root.accent; font.family: ThemeStore.fontFamily; font.pixelSize: 20; font.weight: Font.Bold }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: cardEntry.appName
                                color: root.paper
                                font.family: ThemeStore.fontFamily
                                font.pixelSize: 26
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            Row {
                id: footer
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 36 }
                width: 132
                height: 46
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    visible: root.previewMode ? root.mruWindows.length > 0 : Hyprland.toplevels.values.length > 0
                    color: ThemeStore.lighterBackground
                    Text { anchors.centerIn: parent; text: "close all"; color: ThemeStore.brightForeground; font.family: ThemeStore.fontFamily; font.pixelSize: 15 }
                    MouseArea { anchors.fill: parent; onClicked: root.closeAll() }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: root.previewMode ? root.mruWindows.length === 0 : Hyprland.toplevels.values.length === 0
                text: "Nothing open yet"
                color: root.quiet
                font.family: ThemeStore.fontFamily
                font.pixelSize: 18
            }
        }
    }

    // The bottom-edge strip owns only its own touch surface; progress stays tied to the finger.
    PanelWindow {
        id: edge
        visible: root.gestureEnabled
        anchors { bottom: true; left: true; right: true }
        implicitHeight: 30
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "willow-edge"

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            width: root.tracking ? 132 : 94
            height: root.tracking ? 6 : 4
            radius: 4
            color: root.tracking ? root.accent : ThemeStore.foreground
            opacity: 0.72
            Behavior on width { NumberAnimation { duration: 120 } }
            Behavior on height { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            anchors.fill: parent
            property real startY: 0
            property real startX: 0
            property real lastY: 0
            property real lastX: 0
            property double lastAt: 0
            property double startedAt: 0
            property real velocityY: 0
            property real velocityX: 0
            property bool dragging: false
            property bool wasOpen: false
            property bool recentsStarted: false
            onPressed: mouse => {
                startY = mouse.y;
                startX = mouse.x;
                lastY = mouse.y;
                lastX = mouse.x;
                lastAt = Date.now();
                startedAt = lastAt;
                velocityY = 0;
                velocityX = 0;
                dragging = false;
                wasOpen = root.visible && !root.tracking;
                recentsStarted = false;
            }
            onPositionChanged: mouse => {
                const now = Date.now();
                const elapsed = Math.max(1, now - lastAt);
                const dx = mouse.x - startX;
                const dy = startY - mouse.y;
                velocityX = (mouse.x - lastX) / elapsed;
                velocityY = (lastY - mouse.y) / elapsed;
                lastX = mouse.x;
                lastY = mouse.y;
                lastAt = now;
                if (!dragging && (Math.abs(dx) > 10 || Math.abs(dy) > 10)) {
                    dragging = true;
                    if (!wasOpen)
                        root.beginGesture();
                }
                if (!dragging || wasOpen)
                    return;
                if (Math.abs(dx) > Math.abs(dy) * 1.2) {
                    recentsHold.stop();
                    root.trackGesture(0);
                    return;
                }
                if (dy > 110 && Math.abs(velocityY) < 0.12 && !recentsStarted)
                    recentsHold.restart();
                else if (Math.abs(velocityY) >= 0.12)
                    recentsHold.stop();
                if (recentsStarted)
                    root.trackGesture(dy / root.gestureTravel);
                else
                    root.dragProgress = Math.max(0, Math.min(1, dy / 620));
            }
            onReleased: mouse => {
                recentsHold.stop();
                if (!dragging)
                    return;
                const dx = mouse.x - startX;
                const dy = startY - mouse.y;
                const elapsed = Math.max(1, Date.now() - startedAt);
                const vx = dx / elapsed;
                const vy = dy / elapsed;
                if (wasOpen) {
                    if (dy < -40)
                        root.close();
                } else if (recentsStarted) {
                    root.endGesture(dy > 70 || root.progress > 0.32);
                } else if (Math.abs(dx) > Math.abs(dy) * 1.2) {
                    if (Math.abs(dx) > 130 || Math.abs(vx) > 0.45)
                        root.quickSwitch();
                    root.endGesture(false);
                } else {
                    const flick = dy > 150 || vy > 0.55;
                    if (flick) {
                        if (root.homeVisible)
                            root.drawerRequested();
                        else
                            root.endGesture(true);
                    } else {
                        root.endGesture(false);
                    }
                }
                dragging = false;
                recentsStarted = false;
            }
            onCanceled: {
                recentsHold.stop();
                if (dragging && !wasOpen)
                    root.endGesture(false);
                dragging = false;
                recentsStarted = false;
            }
            Timer {
                id: recentsHold
                interval: 150
                onTriggered: {
                    const travel = drag.startY - drag.lastY;
                    const stopped = Date.now() - drag.lastAt >= 100;
                    if (drag.pressed && travel > 110 && (stopped || Math.abs(drag.velocityY) < 0.12)) {
                        drag.recentsStarted = true;
                        root.beginRecentsGesture(travel / root.gestureTravel);
                    }
                }
            }
        }
    }
}
