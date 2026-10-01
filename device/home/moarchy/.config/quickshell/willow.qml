import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "."

ShellRoot {
    id: root
    readonly property string sourceRoot: Quickshell.env("WILLOW_SOURCE_ROOT") || ""
    readonly property bool previewMode: sourceRoot.length > 0
    readonly property string previewState: previewMode ? (Quickshell.env("WILLOW_PREVIEW_STATE") || "home") : ""
    property string clockText: "--:--"
    property string dateText: "Date unavailable"
    property string batteryText: "Battery unavailable"
    property string networkText: "Network unavailable"
    property string networkAddress: ""
    property string systemText: "System status unavailable"
    property bool keyboardVisible: false
    property bool keyboardStateReady: false
    property string keyboardMode: "manual"
    property bool powerHoldTriggered: false
    property bool pressStartedWithMenu: false
    property bool powerButtonReady: false
    property bool recoveringLock: false
    property bool lockRecoveryBlocked: false
    property bool homeInitiallyVisible: ToplevelManager.toplevels.values.length === 0
    property var keyboardActionQueue: []
    property var applications: []
    property var runningApps: []
    property int brightness: 0
    property int maximumBrightness: 0
    property bool brightnessAvailable: false
    property int pendingBrightness: -1
    property string pillMessage: ""

    function helperPath(name) {
        return previewMode ? sourceRoot + "/device/usr/local/bin/" + name : "/usr/local/bin/" + name;
    }
    function requestPowerAction(action) {
        if (previewMode) {
            pillMessage = action === "restart" ? "Restart is disabled in preview" : "Power off is disabled in preview";
            return;
        }
        if (action === "restart") restartRequest.running = true;
        else powerOff.running = true;
    }

    function updateClock() {
        const now = new Date();
        clockText = Qt.formatDateTime(now, "HH:mm");
        dateText = Qt.formatDateTime(now, "ddd d MMM");
    }
    function refreshStatus() {
        if (previewMode)
            return;
        if (!statusRead.running)
            statusRead.running = true;
    }
    function refreshApplications() {
        applications = DesktopEntries.applications.values
            .filter(entry => !entry.noDisplay && entry.name)
            .sort((a, b) => a.name.localeCompare(b.name));
        const windows = ToplevelManager.toplevels.values;
        runningApps = windows.map(window => {
            const wayland = window.wayland;
            const appId = wayland ? (wayland.appId || "") : "";
            const entry = applications.find(candidate => candidate.id === appId
                || candidate.desktopId === appId
                || (candidate.id && candidate.id.replace(/\.desktop$/, "") === appId)) || null;
            return { id: entry ? (entry.id || entry.desktopId || appId) : appId,
                name: entry ? entry.name : (wayland ? (wayland.title || appId || "Application") : "Application"),
                address: window.address, entry: entry, window: window };
        });
        systemText = batteryText + " · " + (networkAddress || networkText) + " · " + windows.length + " open";
    }
    function openControlCenter() {
        if (lock.active)
            return;
        if (keyboardMode === "manual")
            queueKeyboardAction("hide");
        drawer.visible = false;
        overview.close();
        controlCenter.open();
    }
    function closeControlCenter() { controlCenter.close(); }
    function showHome() {
        if (lock.active)
            return;
        overview.close();
        controlCenter.close();
        drawer.visible = false;
        powerMenu.visible = false;
        if (keyboardMode === "manual")
            queueKeyboardAction("hide");
        home.visible = true;
    }
    function showOverview() {
        if (lock.active)
            return;
        controlCenter.close();
        drawer.visible = false;
        if (keyboardMode === "manual")
            queueKeyboardAction("hide");
        home.visible = false;
        overview.open();
    }
    function openDrawer() {
        if (lock.active)
            return;
        if (keyboardMode === "manual")
            queueKeyboardAction("hide");
        controlCenter.close();
        overview.close();
        drawer.visible = true;
    }
    function selectKeyboardMode(mode) {
        if (previewMode) {
            pillMessage = "Keyboard mode is disabled in preview";
            return;
        }
        keyboardStateReady = false;
        keyboardModeAction.command = [helperPath("willow-keyboard"), "mode", mode];
        keyboardModeAction.running = true;
    }
    function closeKeyboardForBack() {
        queueKeyboardAction("hide");
    }
    function beginLock() {
        if (previewMode) {
            pillMessage = "Lock action is disabled in preview";
            return;
        }
        if (lock.active || lockMarker.running)
            return;
        powerMenu.visible = false;
        controlCenter.close();
        drawer.visible = false;
        overview.close();
        home.visible = false;
        queueKeyboardAction("hide");
        lockMarker.command = [helperPath("willow-session-lock-state"), "locked"];
        lockMarker.running = true;
    }
    function launchCommand(text) {
        if (previewMode) {
            pillMessage = "Commands are disabled in preview";
            return;
        }
        const query = text.trim().toLocaleLowerCase();
        if (!query)
            return;
        const entry = applications.find(candidate => candidate.name.toLocaleLowerCase() === query
            || (candidate.genericName && candidate.genericName.toLocaleLowerCase() === query));
        if (entry) {
            entry.execute();
            home.visible = false;
        } else {
            Quickshell.execDetached(["foot", "sh", "-lc", text]);
            home.visible = false;
        }
    }
    function reloadBrightness() {
        if (!brightnessRead.running)
            brightnessRead.running = true;
    }
    function setBrightness(value) {
        if (previewMode) {
            pillMessage = "Brightness writes are disabled in preview";
            return;
        }
        pendingBrightness = value;
        brightnessDebounce.restart();
    }
    function runBrightnessWrite() {
        if (pendingBrightness < 0 || brightnessWrite.running)
            return;
        const value = pendingBrightness;
        pendingBrightness = -1;
        brightnessWrite.command = [helperPath("willow-brightness"), String(value)];
        brightnessWrite.running = true;
    }
    function queueKeyboardAction(action) {
        if (previewMode) {
            pillMessage = "Keyboard actions are disabled in preview";
            return;
        }
        const queue = keyboardActionQueue.slice();
        queue.push(action);
        keyboardActionQueue = queue;
        if (!keyboardAction.running)
            startNextKeyboardAction();
    }
    function startNextKeyboardAction() {
        if (keyboardActionQueue.length === 0)
            return;
        const queue = keyboardActionQueue.slice();
        const action = queue.shift();
        keyboardActionQueue = queue;
        keyboardAction.command = [helperPath("willow-keyboard"), action];
        keyboardAction.running = true;
    }

    Component.onCompleted: {
        updateClock();
        refreshApplications();
        if (previewMode) {
            Qt.callLater(() => {
                if (previewState === "drawer") {
                    drawer.visible = true;
                } else if (previewState === "recents") {
                    home.visible = false;
                    overview.open();
                } else if (previewState === "control") {
                    controlCenter.open();
                }
            });
        } else {
            refreshStatus();
            keyboardState.running = true;
            brightnessRead.running = true;
            lockState.running = true;
        }
    }
    Timer {
        interval: 15000
        repeat: true
        running: true
        onTriggered: { root.updateClock(); root.refreshStatus(); root.refreshApplications(); }
    }
    Process {
        id: statusRead
        command: [root.helperPath("willow-status")]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const values = {};
                for (const line of text.trim().split("\n")) {
                    const separator = line.indexOf("=");
                    if (separator > 0)
                        values[line.slice(0, separator)] = line.slice(separator + 1);
                }
                root.batteryText = values.battery && values.battery !== "unavailable" ? values.battery : "Battery unavailable";
                root.networkText = values.network === "offline" ? "Offline" : (values.network || "Network unavailable");
                root.networkAddress = values.address && values.address !== "unavailable" ? values.address : "";
                root.refreshApplications();
            }
        }
    }

    Process { id: terminal; command: ["foot"]; running: false }
    Process {
        id: keyboardState
        command: [root.helperPath("willow-keyboard"), "status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const values = {};
                for (const line of text.trim().split("\n")) {
                    const separator = line.indexOf("=");
                    if (separator > 0)
                        values[line.slice(0, separator)] = line.slice(separator + 1);
                }
                if (!values.mode || !values.visible || values.visible === "unknown") {
                    root.keyboardStateReady = false;
                    return;
                }
                root.keyboardMode = values.mode;
                root.keyboardVisible = values.visible === "visible";
                root.keyboardStateReady = true;
            }
        }
    }
    Process {
        id: keyboardAction
        command: [root.helperPath("willow-keyboard"), "status"]
        running: false
        onExited: {
            Qt.callLater(() => {
                if (root.keyboardActionQueue.length > 0)
                    root.startNextKeyboardAction();
                else
                    keyboardState.running = true;
            });
        }
    }
    Timer {
        interval: root.keyboardMode === "auto" ? 650 : 5000
        repeat: true
        running: true
        onTriggered: if (!keyboardState.running) keyboardState.running = true
    }
    Process {
        id: keyboardModeAction
        command: [root.helperPath("willow-keyboard"), "mode", "status"]
        running: false
        onExited: Qt.callLater(() => { if (!keyboardState.running) keyboardState.running = true; });
    }
    Process {
        id: lockState
        command: [root.helperPath("willow-session-lock-state"), "status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const state = text.trim();
                if (state === "locked") {
                    root.recoveringLock = true;
                    lock.active = true;
                } else if (state !== "unlocked") {
                    // An unreadable or malformed marker is not evidence that unlocking is safe.
                    root.recoveringLock = true;
                    root.lockRecoveryBlocked = true;
                    lock.active = true;
                    lockMarker.running = true;
                }
            }
        }
    }
    Process {
        id: lockMarker
        command: [root.helperPath("willow-session-lock-state"), "locked"]
        running: false
        onExited: {
            if (exitCode === 0)
                lock.active = true;
            else
                root.pillMessage = "Lock could not start";
        }
    }
    Process {
        id: unlockMarker
        command: [root.helperPath("willow-session-lock-state"), "unlocked"]
        running: false
    }
    Process {
        id: recoveryBrightness
        command: [root.helperPath("willow-lock-display"), "restore"]
        running: false
    }
    Process {
        id: brightnessRead
        command: [root.helperPath("willow-lock-display"), "status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const values = {};
                for (const pair of text.trim().split(/\s+/)) {
                    const parts = pair.split("=");
                    if (parts.length === 2) values[parts[0]] = parts[1];
                }
                const current = Number(values.brightness);
                const maximum = Number(values.max);
                root.brightnessAvailable = Number.isFinite(current) && Number.isFinite(maximum) && maximum > 0;
                root.brightness = root.brightnessAvailable ? current : 0;
                root.maximumBrightness = root.brightnessAvailable ? maximum : 0;
            }
        }
    }
    Process {
        id: brightnessWrite
        command: [root.helperPath("willow-brightness"), "0"]
        running: false
        onExited: {
            if (exitCode !== 0) root.pillMessage = "Brightness change failed";
            else root.reloadBrightness();
            Qt.callLater(() => root.runBrightnessWrite());
        }
    }
    Timer { id: brightnessDebounce; interval: 100; onTriggered: root.runBrightnessWrite() }
    Process { id: restartRequest; command: ["/usr/local/bin/willow-power-action", "restart"]; running: false }
    Process { id: powerOff; command: ["/usr/local/bin/willow-power-action", "shutdown"]; running: false }

    Process {
        id: powerButton
        command: [root.helperPath("willow-power-button")]
        running: !root.previewMode
        onExited: {
            root.powerButtonReady = false;
            powerHold.stop();
        }
        stdout: SplitParser {
            onRead: data => {
                if (data === "ready") {
                    root.powerButtonReady = true;
                } else if (data === "down" && root.powerButtonReady) {
                    root.powerHoldTriggered = false;
                    root.pressStartedWithMenu = lock.active ? lock.powerMenuVisible : powerMenu.visible;
                    powerHold.start();
                } else if (data === "up" && root.powerButtonReady) {
                    powerHold.stop();
                    if (root.powerHoldTriggered)
                        return;
                    if (root.pressStartedWithMenu) {
                        if (lock.active) lock.powerMenuVisible = false;
                        else powerMenu.visible = false;
                    }
                    else
                        root.beginLock();
                }
            }
        }
    }
    Timer {
        id: powerHold
        interval: 2000
        onTriggered: {
            root.powerHoldTriggered = true;
            if (lock.active) {
                lock.wake();
                lock.powerMenuVisible = true;
            } else {
                powerMenu.visible = true;
            }
        }
    }

    StatusBar {
        clockText: root.clockText
        batteryText: root.batteryText
        networkText: root.networkText
        pillMessage: root.pillMessage
        home: home.visible
        onControlCenterRequested: root.openControlCenter()
        onPillActivated: root.openControlCenter()
    }
    HomeScreen {
        id: home
        visible: root.homeInitiallyVisible
        clockText: root.clockText
        dateText: root.dateText
        batteryText: root.batteryText
        networkText: root.networkText
        systemText: root.systemText
        runningApps: root.runningApps
        applications: root.applications
        onTerminalRequested: {
            if (root.previewMode) root.pillMessage = "App launch is disabled in preview";
            else { home.visible = false; terminal.running = true; }
        }
        onOverviewRequested: root.showOverview()
        onKeyboardRequested: {
            if (root.keyboardMode === "manual") root.queueKeyboardAction("show");
        }
        onDrawerRequested: root.openDrawer()
        onControlCenterRequested: root.openControlCenter()
        onAppRequested: entry => {
            if (root.previewMode) root.pillMessage = "App launch is disabled in preview";
            else { entry.execute(); home.visible = false; }
        }
        onRunningAppRequested: app => {
            if (root.previewMode) {
                root.pillMessage = "App focus is disabled in preview";
                return;
            }
            if (app.window && app.window.wayland)
                overview.focusWindow(app.window);
            else
                overview.open();
            home.visible = false;
        }
        onCommandRequested: text => root.launchCommand(text)
        onDismissRequested: home.visible = false
    }
    Overview {
        id: overview
        homeVisible: home.visible
        gestureEnabled: !lock.active
        previewMode: root.previewMode
        onHomeRequested: root.showHome()
        onDrawerRequested: root.openDrawer()
    }
    AppDrawer {
        id: drawer
        applications: root.applications
        runningIds: root.runningApps.map(app => app.id)
        onActivate: entry => {
            if (root.previewMode) root.pillMessage = "App launch is disabled in preview";
            else { entry.execute(); drawer.visible = false; home.visible = false; }
        }
        onDismissed: drawer.visible = false
    }
    ControlCenter {
        id: controlCenter
        visible: false
        clockText: root.clockText
        dateText: root.dateText
        batteryText: root.batteryText
        networkText: root.networkText
        networkAddress: root.networkAddress
        brightness: root.brightness
        maximumBrightness: root.maximumBrightness
        brightnessAvailable: root.brightnessAvailable
        keyboardVisible: root.keyboardVisible
        keyboardMode: root.keyboardMode
        onBrightnessRequested: value => root.setBrightness(value)
        onKeyboardModeRequested: mode => root.selectKeyboardMode(mode)
        onKeyboardVisibilityRequested: root.queueKeyboardAction(root.keyboardVisible ? "hide" : "show")
        onScreenshotRequested: {
            if (root.previewMode) root.pillMessage = "Screenshot is disabled in preview";
            else Quickshell.execDetached([root.helperPath("willow-screenshot")]);
        }
        onRestartRequested: root.requestPowerAction("restart")
        onShutdownRequested: root.requestPowerAction("shutdown")
    }
    PowerMenu {
        id: powerMenu
        onRestartRequested: { powerMenu.visible = false; root.requestPowerAction("restart"); }
        onShutdownRequested: { powerMenu.visible = false; root.requestPowerAction("shutdown"); }
        onCancelRequested: powerMenu.visible = false
    }
    LockScreen {
        id: lock
        active: false
        clockText: root.clockText
        dateText: root.dateText
        systemText: root.systemText
        onUnlocked: {
            root.recoveringLock = false;
            root.lockRecoveryBlocked = false;
            unlockMarker.running = true;
            active = false;
        }
        onLockFailed: {
            // The marker is the crash-recovery gate. Keep it for every failed lock attempt;
            // clearing it here could expose the session after a shell restart.
            root.recoveringLock = true;
            root.lockRecoveryBlocked = true;
            recoveryBrightness.running = true;
            root.pillMessage = "Session lock unavailable; recovery required";
        }
        onBrightnessError: message => root.pillMessage = message
        onRestartRequested: root.requestPowerAction("restart")
        onShutdownRequested: root.requestPowerAction("shutdown")
        onCancelPowerMenuRequested: lock.powerMenuVisible = false
    }
    Connections {
        target: lock
        function onSecureChanged() {
            if (lock.secure) {
                root.recoveringLock = false;
                root.lockRecoveryBlocked = false;
            }
        }
    }
    PanelWindow {
        visible: root.lockRecoveryBlocked
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: ThemeStore.darkerBackground
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "willow-lock-recovery"
        Column {
            anchors.centerIn: parent
            width: parent.width - 64
            spacing: 18
            Text {
                width: parent.width
                text: "Session lock recovery failed"
                color: ThemeStore.brightForeground
                font.family: ThemeStore.fontFamily
                font.pixelSize: 23
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                width: parent.width
                text: "Session access remains blocked. Reconnect over SSH and restart the shell session to retry; do not clear the lock marker manually."
                color: ThemeStore.foreground
                font.family: ThemeStore.fontFamily
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
    BackGesture {
        keyboardVisible: root.keyboardVisible
        keyboardStateReady: root.keyboardStateReady
        enabled: !lock.active
        previewMode: root.previewMode
        escapeEnabled: !home.visible && !!ToplevelManager.activeToplevel
        panels: [powerMenu, controlCenter, drawer, overview]
        onHideKeyboardRequested: root.closeKeyboardForBack()
    }

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() {
            root.refreshApplications();
            if (ToplevelManager.toplevels.values.length === 0) {
                if (!lock.active) home.visible = true;
            } else if (home.visible) {
                home.visible = false;
            }
        }
    }
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.refreshApplications(); }
    }
}
