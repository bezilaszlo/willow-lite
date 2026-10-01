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
    property string batteryText: "Battery unavailable"
    property string networkText: "Network unavailable"
    property string dateText: "Date unavailable"
    property string systemText: "System status unavailable"

    readonly property bool secure: sessionLock.secure
    readonly property bool awake: root.active && root.secure && !darkState
    readonly property bool dark: root.active && darkState

    property bool darkState: true
    property int restoreBrightness: 2047
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
    property int touchPressCount: 0
    property int touchMoveCount: 0
    property int touchReleaseCount: 0
    property int touchCancelCount: 0
    property real lastTouchX: -1
    property real lastTouchY: -1
    property var brightnessQueue: []
    property string activeBrightnessAction: ""
    property bool restoreQueued: false

    signal unlocked()
    signal lockFailed()
    signal brightnessError(string message)
    signal diagnosticEvent(string name, string detail)
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
        root.diagnosticEvent("brightness.started", root.activeBrightnessAction);
        root.brightnessQueue = queue;
        brightnessProcess.command = root.activeBrightnessAction === "restore"
            ? ["/usr/local/bin/willow-lock-display", "restore", String(root.restoreBrightness)]
            : ["/usr/local/bin/willow-lock-display", root.activeBrightnessAction];
        brightnessProcess.running = true;
    }

    function wake() {
        if (!root.active || !root.secure || !root.dark)
            return;
        diagnosticEvent("brightness.request", "restore");
        root.queueBrightness("restore");
    }

    function dim() {
        if (!root.active || !root.secure || root.powerMenuVisible)
            return;
        diagnosticEvent("brightness.request", "dim");
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
            if (root.gestureWasDark)
                root.wake();
            else
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
        diagnosticEvent("lock.active", String(root.active));
        if (root.active)
            root.beginLock();
        else {
            acquireTimeout.stop();
            idleTimer.stop();
            root.darkState = false;
            if (sessionLock.locked)
                sessionLock.locked = false;
        }
    }

    onDarkStateChanged: diagnosticEvent("lock.dark", String(root.darkState));
    onAwakeChanged: diagnosticEvent("lock.awake", String(root.awake));

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
                    sessionLock.locked = false;
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
            root.diagnosticEvent("brightness.finished", action + " rc=" + exitCode
                + " dark=" + root.darkState + " secure=" + root.secure);
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

                LockScreenContent {
                    anchors.fill: parent
                    dark: root.dark
                    awake: root.awake
                    powerMenuVisible: root.powerMenuVisible
                    clockText: root.clockText
                    batteryText: root.batteryText
                    networkText: root.networkText
                    dateText: root.dateText
                    systemText: root.systemText
                    swipeOffset: root.swipeOffset
                    onRestartRequested: root.restartRequested()
                    onShutdownRequested: root.shutdownRequested()
                    onCancelPowerMenuRequested: root.cancelPowerMenuRequested()
                }

                MultiPointTouchArea {
                    anchors.fill: parent
                    enabled: root.active && root.secure && !root.powerMenuVisible
                    maximumTouchPoints: 5

                    onPressed: points => {
                        root.touchPressCount++;
                        if (points.length > 0) {
                            root.lastTouchX = points[0].x;
                            root.lastTouchY = points[0].y;
                        }
                        root.addTouchPoints(points);
                    }
                    onUpdated: points => {
                        root.touchMoveCount++;
                        if (points.length > 0) {
                            root.lastTouchX = points[0].x;
                            root.lastTouchY = points[0].y;
                        }
                        root.moveTouchPoints(points);
                    }
                    onReleased: points => {
                        root.touchReleaseCount++;
                        if (points.length > 0) {
                            root.lastTouchX = points[0].x;
                            root.lastTouchY = points[0].y;
                        }
                        root.removeTouchPoints(points);
                    }
                    onCanceled: {
                        root.touchCancelCount++;
                        root.activePointIds = [];
                        root.gestureTracking = false;
                        root.gestureInvalid = false;
                        root.gestureWasDark = false;
                        root.springBack();
                        if (root.awake && !root.powerMenuVisible)
                            idleTimer.restart();
                    }
                }
            }
        }

        onSecureChanged: {
            if (sessionLock.secure) {
                root.diagnosticEvent("lock.secure", "true");
                acquireTimeout.stop();
                root.wasSecure = true;
                root.darkState = true;
                root.queueBrightness("dim");
            }
        }

        onLockedChanged: {
            root.diagnosticEvent("lock.protocol-locked", String(sessionLock.locked));
            if (!sessionLock.locked && root.wasSecure) {
                root.wasSecure = false;
                const restoreNeeded = root.darkState;
                root.darkState = false;
                if (restoreNeeded)
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
        onFinished: sessionLock.locked = false
    }

}
