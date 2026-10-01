import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

Scope {
    id: root
    property bool visible: false
    property string clockText: "--:--"
    property string dateText: ""
    property string systemText: ""
    property string batteryText: ""
    property string networkText: ""
    property var runningApps: []
    property var frequentApps: []
    property var applications: []

    signal drawerRequested()
    signal terminalRequested()
    signal overviewRequested()
    signal keyboardRequested()
    signal dismissRequested()
    signal controlCenterRequested()
    signal appRequested(var entry)
    signal commandRequested(string text)

    function appName(app) { return typeof app === "string" ? app : (app.name || "App") }
    function resolvedSystemText() {
        if (systemText) return systemText
        return [batteryText, networkText].filter(value => value).join("  ")
    }
    function formattedDate() { return dateText.toLowerCase().replace(/\b([0-9])\b/g, "0$1") }
    function findApp(query) {
        const key = query.trim().toLocaleLowerCase()
        if (!key) return null
        return applications.find(entry => entry.name.toLocaleLowerCase() === key)
            || applications.find(entry => entry.name.toLocaleLowerCase().startsWith(key))
            || applications.find(entry => (entry.genericName || "").toLocaleLowerCase().includes(key))
            || null
    }

    PanelWindow {
        visible: root.visible
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: ThemeStore.background
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "willow-home"

        Item {
            anchors.fill: parent
            Canvas {
                anchors.fill: parent
                z: -2
                onPaint: {
                    const context = getContext("2d")
                    context.clearRect(0, 0, width, height)
                    for (let y = 9; y < height * 0.62; y += 27) {
                        context.globalAlpha = 0.17 * (1 - y / (height * 0.62))
                        for (let x = 13; x < width; x += 27) {
                            context.beginPath()
                            context.arc(x, y, 1.1, 0, Math.PI * 2)
                            context.fillStyle = ThemeStore.foreground
                            context.fill()
                        }
                    }
                    context.globalAlpha = 1
                }
                Connections {
                    target: ThemeStore
                    function onThemeNameChanged() { parent.requestPaint() }
                }
            }
            MouseArea {
                anchors.fill: parent
                z: -1
                property real startX: 0
                property real startY: 0
                onPressed: { startX = mouse.x; startY = mouse.y }
                onReleased: {
                    const dx = mouse.x - startX
                    const dy = mouse.y - startY
                    if (Math.abs(dy) > 70 && Math.abs(dy) > Math.abs(dx) * 1.2) {
                        if (dy < 0) root.drawerRequested()
                        else root.controlCenterRequested()
                    }
                }
            }
            Column {
                x: 24; y: 13
                spacing: 0
                Text {
                    text: root.clockText.includes(":") ? root.clockText.slice(0, root.clockText.indexOf(":")) : root.clockText
                    color: ThemeStore.brightForeground
                    font.family: ThemeStore.fontFamily; font.pixelSize: 206; font.weight: Font.Thin; font.letterSpacing: -15.45
                    height: 171; verticalAlignment: Text.AlignTop
                }
                Text {
                    text: root.clockText.includes(":") ? root.clockText.slice(root.clockText.indexOf(":") + 1) : ""
                    color: ThemeStore.accent
                    font.family: ThemeStore.fontFamily; font.pixelSize: 206; font.weight: Font.Thin; font.letterSpacing: -15.45
                    height: 171; verticalAlignment: Text.AlignTop
                }
            }
            Text {
                x: 34; y: 430
                text: root.formattedDate()
                color: ThemeStore.foreground
                font.family: ThemeStore.fontFamily
                font.pixelSize: 21
            }
            Text {
                x: 34; y: 469
                width: parent.width - 68
                text: root.resolvedSystemText()
                color: ThemeStore.darkForeground
                font.family: ThemeStore.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.bottomMargin: 40
                spacing: 14

                Flickable {
                    width: parent.width
                    height: 44
                    contentWidth: chips.width
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Row {
                        id: chips
                        spacing: 8
                        Repeater { model: root.runningApps.map(app => ({ app: app, running: true })); delegate: chipDelegate }
                        Repeater {
                            model: root.frequentApps.map(app => ({ app: app, running: false })); delegate: chipDelegate
                        }
                        Rectangle {
                            width: appsLabel.implicitWidth + 26; height: 38; radius: 19
                            color: ThemeStore.lighterBackground
                            border.color: ThemeStore.muted
                            Text { id: appsLabel; anchors.centerIn: parent; text: "apps ↑"; color: ThemeStore.accent; font.family: ThemeStore.fontFamily; font.pixelSize: 13 }
                            MouseArea { anchors.fill: parent; onClicked: root.drawerRequested() }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 58
                    radius: 18
                    color: ThemeStore.darkBackground
                    border.color: prompt.activeFocus ? ThemeStore.accent : ThemeStore.muted
                    border.width: prompt.activeFocus ? 2 : 1
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 17
                        anchors.rightMargin: 12
                        spacing: 10
                        Text { text: "❯"; color: ThemeStore.accent; font.family: ThemeStore.fontFamily; font.pixelSize: 19; anchors.verticalCenter: parent.verticalCenter }
                        TextInput {
                            id: prompt
                            width: parent.width - 50
                            height: parent.height
                            color: ThemeStore.brightForeground
                            font.family: ThemeStore.fontFamily
                            font.pixelSize: 15
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            clip: true
                            Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; text: "open an app or run a command"; color: ThemeStore.darkForeground; font: prompt.font; visible: !prompt.text && !prompt.activeFocus }
                            function submit() {
                                const typed = prompt.text.trim()
                                const entry = root.findApp(typed)
                                if (entry) root.appRequested(entry)
                                else if (typed) root.commandRequested(typed)
                                prompt.text = ""
                            }
                            Keys.onReturnPressed: submit()
                            Keys.onEnterPressed: submit()
                        }
                    }
                    MouseArea { anchors.fill: parent; z: -1; onClicked: prompt.forceActiveFocus() }
                }
            }
        }
    }

    Component {
        id: chipDelegate
        Rectangle {
            required property var modelData
            property var app: modelData.app
            property bool running: modelData.running
            width: label.implicitWidth + (running ? 31 : 24)
            height: 38
            radius: 19
            color: ThemeStore.lighterBackground
            border.color: ThemeStore.muted
            Row {
                anchors.centerIn: parent
                spacing: 7
                Rectangle { visible: parent.parent.running; width: 6; height: 6; radius: 3; color: ThemeStore.green; anchors.verticalCenter: parent.verticalCenter }
                Text { id: label; text: root.appName(parent.parent.app); color: ThemeStore.foreground; font.family: ThemeStore.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    const app = parent.app
                    const entry = app.desktopEntry || app.entry || root.findApp(root.appName(app))
                    if (entry) root.appRequested(entry)
                    else root.commandRequested(root.appName(app))
                }
            }
        }
    }
}
