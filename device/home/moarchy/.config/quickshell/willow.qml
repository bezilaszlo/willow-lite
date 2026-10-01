import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    property string clockText: "--:--"
    property string dateText: "Date unavailable"
    property string batteryText: "Battery unavailable"
    property string networkText: "Network unavailable"
    property bool keyboardVisible: false
    property bool keyboardStateReady: false
    property bool powerHoldTriggered: false
    property bool pressStartedWithMenu: false
    property bool powerButtonReady: false
    property bool homeInitiallyVisible: ToplevelManager.toplevels.values.length === 0
    property var keyboardActionQueue: []

    function updateClock() {
        const now = new Date();
        clockText = Qt.formatDateTime(now, "HH:mm");
        dateText = Qt.formatDateTime(now, "ddd d MMM");
    }
    function refreshStatus() {
        if (!statusRead.running)
            statusRead.running = true;
    }
    function showHome() {
        overview.close();
        powerMenu.visible = false;
        queueKeyboardAction("hide");
        home.visible = true;
    }
    function showOverview() {
        queueKeyboardAction("hide");
        home.visible = false;
        overview.open();
    }
    function toggleKeyboard() {
        queueKeyboardAction("toggle");
    }
    function closeKeyboardForBack() {
        queueKeyboardAction("hide");
    }
    function queueKeyboardAction(action) {
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
        keyboardAction.command = ["/usr/local/bin/willow-keyboard", action];
        keyboardAction.running = true;
    }

    Component.onCompleted: {
        updateClock();
        refreshStatus();
        keyboardState.running = true;
    }
    Timer {
        interval: 15000
        repeat: true
        running: true
        onTriggered: { root.updateClock(); root.refreshStatus(); }
    }
    Process {
        id: statusRead
        command: ["/usr/local/bin/willow-status"]
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
            }
        }
    }

    Process { id: terminal; command: ["foot"]; running: false }
    Process {
        id: keyboardState
        command: ["/usr/local/bin/willow-keyboard", "status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.keyboardVisible = text.trim() === "visible";
                root.keyboardStateReady = true;
            }
        }
    }
    Process {
        id: keyboardAction
        command: ["/usr/local/bin/willow-keyboard", "status"]
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
    Process { id: displayWake; command: ["/usr/local/bin/willow-power-action", "display-on"]; running: false }
    Process { id: displayToggle; command: ["/usr/local/bin/willow-power-action", "display-toggle"]; running: false }
    Process { id: restartRequest; command: ["/usr/local/bin/willow-power-action", "restart"]; running: false }
    Process { id: powerOff; command: ["/usr/local/bin/willow-power-action", "shutdown"]; running: false }

    Process {
        id: powerButton
        command: ["/usr/local/bin/willow-power-button"]
        running: true
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
                    root.pressStartedWithMenu = powerMenu.visible;
                    powerHold.start();
                } else if (data === "up" && root.powerButtonReady) {
                    powerHold.stop();
                    if (root.powerHoldTriggered)
                        return;
                    if (root.pressStartedWithMenu)
                        powerMenu.visible = false;
                    else
                        displayToggle.running = true;
                }
            }
        }
    }
    Timer {
        id: powerHold
        interval: 2000
        onTriggered: {
            root.powerHoldTriggered = true;
            displayWake.running = true;
            powerMenu.visible = true;
        }
    }

    StatusBar {
        clockText: root.clockText
        batteryText: root.batteryText
        networkText: root.networkText
    }
    HomeScreen {
        id: home
        visible: root.homeInitiallyVisible
        clockText: root.clockText
        dateText: root.dateText
        batteryText: root.batteryText
        networkText: root.networkText
        onTerminalRequested: { home.visible = false; terminal.running = true; }
        onOverviewRequested: root.showOverview()
        onKeyboardRequested: { home.visible = false; root.toggleKeyboard(); }
        onDismissRequested: home.visible = false
    }
    Overview {
        id: overview
        onHomeRequested: root.showHome()
    }
    PowerMenu {
        id: powerMenu
        onRestartRequested: { powerMenu.visible = false; restartRequest.running = true; }
        onShutdownRequested: { powerMenu.visible = false; powerOff.running = true; }
        onCancelRequested: powerMenu.visible = false
    }
    BackGesture {
        keyboardVisible: root.keyboardVisible
        keyboardStateReady: root.keyboardStateReady
        panels: [powerMenu, overview, home]
        onHideKeyboardRequested: root.closeKeyboardForBack()
    }

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() {
            if (ToplevelManager.toplevels.values.length === 0)
                home.visible = true;
        }
    }
}
