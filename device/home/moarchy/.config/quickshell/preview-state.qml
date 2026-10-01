import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Isolated visual-state harness. Run only inside scripts/preview-phone.sh with
// WILLOW_SOURCE_ROOT and the repository's preview-config XDG_CONFIG_HOME.
ShellRoot {
    id: root
    readonly property string state: Quickshell.env("WILLOW_PREVIEW_STATE") || "home"
    readonly property string clockText: Qt.formatDateTime(new Date(), "HH:mm")
    readonly property string dateText: Qt.formatDateTime(new Date(), "ddd d MMM")
    readonly property var applications: DesktopEntries.applications.values
        .filter(entry => !entry.noDisplay && entry.name)
        .sort((a, b) => a.name.localeCompare(b.name))
    readonly property var previewWindows: [
        { wayland: null, previewName: "Files", previewTitle: "Home" },
        { wayland: null, previewName: "Browser", previewTitle: "Willow Lite · Design notes" },
        { wayland: null, previewName: "Terminal", previewTitle: "~/Work/willow-lite" }
    ]

    StatusBar {
        shown: root.state !== "lock"
        clockText: root.clockText
        batteryText: "Battery unavailable"
        networkText: "Network unavailable"
        home: root.state === "home"
    }
    HomeScreen {
        visible: root.state === "home" || root.state === "drawer" || root.state === "control"
        clockText: root.clockText
        dateText: root.dateText
        systemText: "Battery unavailable · Network unavailable · " + ToplevelManager.toplevels.values.length + " open"
        batteryText: "Battery unavailable"
        networkText: "Network unavailable"
        applications: root.applications
    }
    AppDrawer {
        visible: root.state === "drawer"
        applications: root.applications
    }
    Overview {
        visible: root.state === "recents"
        gestureEnabled: false
        previewMode: true
        progress: root.state === "recents" ? 1 : 0
        mruWindows: root.state === "recents" ? root.previewWindows : []
    }
    ControlCenter {
        visible: false
        clockText: root.clockText
        dateText: root.dateText
        batteryText: "Battery unavailable"
        networkText: "Network unavailable"
        brightnessAvailable: false
        Component.onCompleted: if (root.state === "control") open()
    }
    PanelWindow {
        visible: root.state === "lock"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "willow-preview-lock-visual"
        LockScreenContent {
            anchors.fill: parent
            clockText: root.clockText
            dateText: root.dateText
            systemText: "Battery unavailable   Network unavailable   " + ToplevelManager.toplevels.values.length + " apps open"
        }
    }
}
