// Preview-only recents fixture. Uses the production Overview card component,
// with inert sample metadata and no compositor toplevel or capture source.
import QtQuick
import Quickshell
import "../device/home/moarchy/.config/quickshell" as WillowShell

ShellRoot {
    id: fixture

    readonly property var sampleApps: [
        { wayland: null, previewName: "Terminal", previewTitle: "~/Work/willow-lite" },
        { wayland: null, previewName: "Browser", previewTitle: "Willow Lite · Design notes" },
        { wayland: null, previewName: "Files", previewTitle: "Home" }
    ]

    WillowShell.Overview {
        id: overview
        visible: false
        previewMode: true
        gestureEnabled: false
    }

    Timer {
        interval: 100
        repeat: false
        running: true
        onTriggered: {
            overview.mruWindows = fixture.sampleApps;
            overview.progress = 1;
            overview.visible = true;
        }
    }
}
