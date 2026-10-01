import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "."

Scope {
    id: root

    // The controller creates the runtime marker before setting active.
    property bool active: false
    property bool powerMenuVisible: false
    property string clockText: "--:--"
    property string dateText: "Date unavailable"
    property string systemText: "System status unavailable"

    readonly property bool secure: sessionLock.secure
    readonly property bool awake: root.active && root.secure && !darkState
    readonly property bool dark: root.active && darkState

    property bool darkState: true
    property bool wasSecure: false
    property bool unlockAnimationRunning: false
    property bool gestureTracking: false
    property bool gestureWasDark: false
    property bool gestureInvalid: false
    property real gestureStartY: 0
    property real gestureLastY: 0
    property real gestureTravel: 0
    property real swipeOffset: 0
    property real surfaceHeight: 1170
    property real gestureVelocity: 0
    property double gestureLastTime: 0
    property var activePointIds: []
    property var brightnessQueue: []
    property string activeBrightnessAction: ""
    property bool restoreQueued: false

    signal unlocked()
    signal lockFailed()
    signal brightnessError(string message)
    signal restartRequested()
    signal shutdownRequested()
    signal cancelPowerMenuRequested()

    function beginLock() {
        root.wasSecure = false;
        root.unlockAnimationRunning = false;
        root.darkState = true;
        sessionLock.locked = true;
        acquireTimeout.restart();
    }

    function queueBrightness(action) {
        if (action === "restore") {
            if (root.restoreQueued)
                return;
            root.restoreQueued = true;
        }
        const queue = root.brightnessQueue.slice();
        queue.push(action);
        root.brightnessQueue = queue;
        root.runBrightnessQueue();
    }

    function runBrightnessQueue() {
        if (brightnessProcess.running || root.brightnessQueue.length === 0)
            return;
        const queue = root.brightnessQueue.slice();
        root.activeBrightnessAction = queue.shift();
        root.brightnessQueue = queue;
        brightnessProcess.command = ["/usr/local/bin/willow-lock-display", root.activeBrightnessAction];
        brightnessProcess.running = true;
    }

    function wake() {
        if (!root.active || !root.secure || !root.dark)
            return;
        root.queueBrightness("restore");
    }

    function dim() {
        if (!root.active || !root.secure || root.powerMenuVisible)
            return;
        root.darkState = true;
        root.queueBrightness("dim");
    }

    function startGesture(y) {
        if (!root.awake || root.powerMenuVisible)
            return;
        idleTimer.stop();
        root.gestureTracking = true;
        root.gestureInvalid = false;
        root.gestureStartY = y;
        root.gestureLastY = y;
        root.gestureTravel = 0;
        root.gestureVelocity = 0;
        root.gestureLastTime = Date.now();
    }

    function updateGesture(y) {
        if (!root.gestureTracking || root.gestureInvalid)
            return;
        const now = Date.now();
        const elapsed = now - root.gestureLastTime;
        if (elapsed > 0 && elapsed <= 100)
            root.gestureVelocity = (root.gestureLastY - y) / elapsed;
        else
            root.gestureVelocity = 0;
        root.gestureLastTime = now;
        root.gestureLastY = y;
        root.gestureTravel = root.gestureStartY - y;
        root.swipeOffset = -Math.max(0, Math.min(root.surfaceHeight, root.gestureTravel));
    }

    function finishGesture(y) {
        if (!root.gestureTracking || root.gestureInvalid) {
            root.gestureTracking = false;
            root.springBack();
            if (root.awake && !root.powerMenuVisible)
                idleTimer.restart();
            return;
        }
        root.updateGesture(y);
        root.gestureTracking = false;
        idleTimer.restart();
        if (root.gestureTravel > 200 || (root.gestureTravel > 80 && root.gestureVelocity > 0.5)) {
            root.unlockAnimationRunning = true;
            idleTimer.stop();
            unlockContent.start();
        } else {
            returnAnimation.start();
        }
    }

    function springBack() {
        root.gestureTracking = false;
        returnAnimation.start();
    }

    function addTouchPoints(points) {
        let ids = root.activePointIds.slice();
        for (const point of points) {
            if (ids.indexOf(point.pointId) === -1)
                ids.push(point.pointId);
        }
        root.activePointIds = ids;

        if (ids.length === 1 && !root.gestureInvalid) {
            root.gestureWasDark = root.dark;
            root.gestureStartY = points[0].y;
            if (!root.gestureWasDark)
                root.startGesture(points[0].y);
        } else {
            root.gestureInvalid = true;
            root.gestureTracking = false;
            root.springBack();
        }
    }

    function moveTouchPoints(points) {
        if (root.activePointIds.length !== 1 || points.length === 0)
            return;
        if (root.gestureWasDark) {
            if (Math.abs(points[0].y - root.gestureStartY) > 12)
                root.gestureInvalid = true;
            return;
        }
        root.updateGesture(points[0].y);
    }

    function removeTouchPoints(points) {
        const lastGesturePoint = points.length > 0 ? points[0] : null;
        let ids = root.activePointIds.slice();
        for (const point of points)
            ids = ids.filter(id => id !== point.pointId);

        if (root.activePointIds.length === 1 && ids.length === 0 && root.gestureWasDark) {
            if (!root.gestureInvalid)
                root.wake();
            root.gestureWasDark = false;
        } else if (root.activePointIds.length === 1 && ids.length === 0 && lastGesturePoint)
            root.finishGesture(lastGesturePoint.y);
        else if (ids.length === 0) {
            root.gestureTracking = false;
            root.springBack();
        }
        if (ids.length === 0) {
            root.gestureInvalid = false;
            root.gestureWasDark = false;
        }
        root.activePointIds = ids;
    }

    onActiveChanged: {
        if (root.active)
            root.beginLock();
        else {
            acquireTimeout.stop();
            idleTimer.stop();
            root.darkState = false;
            if (sessionLock.locked)
                sessionLock.unlock();
        }
    }

    onPowerMenuVisibleChanged: {
        if (root.powerMenuVisible) {
            idleTimer.stop();
            if (root.dark)
                root.wake();
        } else if (root.awake) {
            idleTimer.restart();
        }
    }

    Timer {
        id: acquireTimeout
        interval: 2500
        repeat: false
        onTriggered: {
            if (root.active && !root.secure) {
                if (sessionLock.locked)
                    sessionLock.unlock();
                root.lockFailed();
            }
        }
    }

    Timer {
        id: idleTimer
        interval: 8000
        repeat: false
        onTriggered: if (root.active && root.awake && !root.powerMenuVisible)
            root.dim();
    }

    Process {
        id: brightnessProcess
        command: ["/usr/local/bin/willow-lock-display", "status"]
        running: false
        onExited: exitCode => {
            const action = root.activeBrightnessAction;
            root.activeBrightnessAction = "";
            if (action === "restore")
                root.restoreQueued = false;

            if (exitCode === 0) {
                if (action === "dim")
                    root.darkState = true;
                else if (action === "restore") {
                    root.darkState = false;
                    if (!root.powerMenuVisible && root.active && sessionLock.locked)
                        idleTimer.restart();
                }
            } else if (action === "dim") {
                root.darkState = false;
                root.brightnessError("Could not dim the backlight; the lock remains visible.");
            } else if (action === "restore") {
                root.darkState = true;
                root.brightnessError("Could not restore the saved backlight level.");
            }

            Qt.callLater(root.runBrightnessQueue);
        }
    }

    WlSessionLock {
        id: sessionLock

        surface: Component {
            WlSessionLockSurface {
                id: lockSurface

                onHeightChanged: root.surfaceHeight = height

                color: root.dark ? "#000000" : ThemeStore.darkerBackground

                Item {
                    anchors.fill: parent

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
                                    fontSizeMode: Text.FixedSize
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

                        MultiPointTouchArea {
                            id: lockInput
                            anchors.fill: parent
                            enabled: root.active && root.secure && !root.powerMenuVisible
                            maximumTouchPoints: 5

                            onPressed: points => root.addTouchPoints(points)
                            onUpdated: points => root.moveTouchPoints(points)
                            onReleased: points => root.removeTouchPoints(points)
                            onCanceled: {
                                root.activePointIds = [];
                                root.gestureTracking = false;
                                root.gestureInvalid = false;
                                root.gestureWasDark = false;
                                root.springBack();
                                if (root.awake && !root.powerMenuVisible)
                                    idleTimer.restart();
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
                }
            }
        }

        onSecureChanged: {
            if (sessionLock.secure) {
                acquireTimeout.stop();
                root.wasSecure = true;
                root.darkState = true;
                root.queueBrightness("dim");
            }
        }

        onLockedChanged: {
            if (!sessionLock.locked && root.wasSecure) {
                root.wasSecure = false;
                root.darkState = false;
                root.queueBrightness("restore");
                root.unlocked();
            }
        }
    }

    NumberAnimation {
        id: returnAnimation
        target: root
        property: "swipeOffset"
        to: 0
        duration: 260
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: unlockContent
        target: root
        property: "swipeOffset"
        to: -root.surfaceHeight
        duration: 330
        easing.type: Easing.OutCubic
        onFinished: sessionLock.unlock()
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
