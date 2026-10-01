pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

Scope {
    id: root

    property bool visible: false
    property real offset: -sheet.height
    property string clockText: "--:--"
    property string dateText: ""
    property string batteryText: "Battery unavailable"
    property string networkText: "Offline"
    property string networkAddress: ""
    property int brightness: 0
    property int maximumBrightness: 0
    property bool brightnessAvailable: false
    property bool keyboardVisible: false
    property string keyboardMode: "manual"
    property bool portraitLocked: true
    readonly property real sheetHeight: Math.min(730, output.height > 0 ? output.height : 1170)

    signal brightnessRequested(int value)
    signal keyboardModeRequested(string mode)
    signal keyboardVisibilityRequested()
    signal rotationRequested()
    signal screenshotRequested()
    signal restartRequested()
    signal shutdownRequested()

    function open() {
        visible = true;
        offset = -sheet.height;
        slide.to = 0;
        slide.start();
    }
    function close() {
        slide.to = -sheet.height;
        slide.start();
    }
    function finishClose() {
        if (offset <= -sheet.height + 1)
            visible = false;
    }
    function setBrightnessFromX(x) {
        if (!root.brightnessAvailable || root.maximumBrightness <= 0)
            return;
        const ratio = Math.max(0, Math.min(1, (x - brightnessTrack.x) / brightnessTrack.width));
        root.brightnessRequested(Math.round(ratio * root.maximumBrightness));
    }

    PanelWindow {
        id: overlay
        visible: root.visible
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "willow-control-center"

        Rectangle {
            anchors.fill: parent
            color: "#b8000000"
            opacity: Math.max(0, 1 + root.offset / Math.max(1, sheet.height))
            MouseArea { anchors.fill: parent; onClicked: root.close() }
        }

        Item {
            id: sheet
            width: parent.width
            height: root.sheetHeight
            y: root.offset

            Rectangle {
                anchors.fill: parent
                radius: 34
                color: ThemeStore.darkBackground
                border.color: ThemeStore.muted
                border.width: 1
            }

            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 13
                width: 44
                height: 4
                radius: 2
                color: ThemeStore.darkForeground
            }

            MouseArea {
                id: dragHandle
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 38
                property real startY: 0
                property real distance: 0
                onPressed: mouse => { startY = mouse.y; distance = 0; }
                onPositionChanged: mouse => {
                    distance = mouse.y - startY;
                    if (distance < -10) {
                        slide.stop();
                        root.offset = Math.max(-sheet.height, distance);
                    }
                }
                onReleased: {
                    if (distance < -100)
                        root.close();
                    else {
                        slide.to = 0;
                        slide.start();
                    }
                }
            }

            Column {
                id: header
                x: 28
                y: 50
                spacing: 0
                Text {
                    text: root.clockText
                    color: ThemeStore.brightForeground
                    font.family: ThemeStore.fontFamily
                    font.pixelSize: 38
                    font.weight: Font.ExtraLight
                    font.letterSpacing: -1.5
                }
                Text {
                    text: root.dateText
                    color: ThemeStore.darkForeground
                    font.family: ThemeStore.fontFamily
                    font.pixelSize: 14
                }
            }

            Rectangle {
                id: closeButton
                x: parent.width - width - 24
                y: 52
                width: 48
                height: 48
                radius: 24
                color: closeTap.pressed ? ThemeStore.selection : ThemeStore.lighterBackground
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: ThemeStore.foreground
                    font.family: ThemeStore.fontFamily
                    font.pixelSize: 24
                }
                MouseArea { id: closeTap; anchors.fill: parent; onClicked: root.close() }
            }

            Flickable {
                id: content
                x: 24
                y: 145
                width: parent.width - 48
                height: parent.height - 190
                clip: true
                contentHeight: contentColumn.height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: contentColumn
                    width: content.width
                    spacing: 18

                    Rectangle {
                        width: parent.width
                        height: 108
                        radius: 22
                        color: ThemeStore.lighterBackground
                        border.color: ThemeStore.selection

                        Column {
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 17 }
                            spacing: 8
                            Item {
                                width: parent.width
                                height: 17
                                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "BRIGHTNESS"; color: ThemeStore.darkForeground; font.family: ThemeStore.fontFamily; font.pixelSize: 11; font.letterSpacing: 1.1 }
                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.brightnessAvailable && root.maximumBrightness > 0
                                          ? Math.round(root.brightness * 100 / root.maximumBrightness) + "%"
                                          : "unavailable"
                                    color: ThemeStore.foreground
                                    font.family: ThemeStore.fontFamily
                                    font.pixelSize: 12
                                }
                            }
                            Rectangle {
                                id: brightnessTrack
                                width: parent.width
                                height: 48
                                radius: 22
                                color: ThemeStore.selection
                                clip: true
                                Rectangle {
                                    width: root.brightnessAvailable && root.maximumBrightness > 0
                                           ? brightnessTrack.width * root.brightness / root.maximumBrightness : 0
                                    height: parent.height
                                    radius: parent.radius
                                    color: ThemeStore.accent
                                    opacity: 0.88
                                }
                                Row {
                                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 19; rightMargin: 18 }
                                    spacing: 11
                                    Text { text: "☼"; color: ThemeStore.darkBackground; font.family: ThemeStore.fontFamily; font.pixelSize: 22; font.weight: Font.Bold }
                                    Text {
                                        text: root.brightnessAvailable ? "Drag to adjust" : "Brightness control unavailable"
                                    color: root.brightnessAvailable ? ThemeStore.darkBackground : ThemeStore.foreground
                                        font.family: ThemeStore.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        width: parent.width - 42
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.brightnessAvailable
                                    onPressed: mouse => root.setBrightnessFromX(mouse.x)
                                    onPositionChanged: mouse => { if (pressed) root.setBrightnessFromX(mouse.x); }
                                }
                            }
                        }
                    }

                    Grid {
                        width: parent.width
                        columns: 2
                        spacing: 10

                        component Tile: Rectangle {
                            id: tile
                            required property string title
                            required property string detail
                            property bool selected: false
                            property bool enabledAction: true
                            signal clicked()
                            width: (parent.width - 10) / 2
                            height: 80
                            radius: 21
                            color: tile.enabledAction
                                   ? (tile.selected ? ThemeStore.accent : ThemeStore.lighterBackground)
                                   : ThemeStore.darkBackground
                            border.color: tile.selected ? ThemeStore.accent : ThemeStore.selection
                            opacity: tile.enabledAction ? 1 : 0.7
                            Column {
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 12 }
                                spacing: 4
                                Text {
                                    width: parent.width
                                    text: tile.title
                                    color: tile.selected && tile.enabledAction ? ThemeStore.darkBackground : ThemeStore.brightForeground
                                    font.family: ThemeStore.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: tile.detail
                                    color: tile.selected && tile.enabledAction ? ThemeStore.darkBackground : ThemeStore.darkForeground
                                    font.family: ThemeStore.fontFamily
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea { anchors.fill: parent; enabled: tile.enabledAction; onClicked: tile.clicked() }
                        }

                        Tile {
                            title: "USB network"
                            detail: root.networkAddress.length ? root.networkAddress : root.networkText
                            selected: root.networkText.toLowerCase().indexOf("usb") !== -1
                            enabledAction: false
                        }
                        Tile { title: "Wi-Fi"; detail: "No Wi-Fi driver"; enabledAction: false }
                        Tile {
                            title: "Keyboard"
                            detail: root.keyboardMode + " · " + (root.keyboardVisible ? "shown" : "hidden")
                            selected: root.keyboardVisible
                            onClicked: root.keyboardModeRequested(root.keyboardMode === "auto" ? "manual" : "auto")
                        }
                        Tile { title: "Portrait locked"; detail: "Auto unavailable"; enabledAction: false }
                    }

                    Column {
                        width: parent.width
                        spacing: 10
                        Item {
                            width: parent.width
                            height: 18
                            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "THEME"; color: ThemeStore.darkForeground; font.family: ThemeStore.fontFamily; font.pixelSize: 11; font.letterSpacing: 1.1 }
                            Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: ThemeStore.themeName.replace("-", " "); color: ThemeStore.foreground; font.family: ThemeStore.fontFamily; font.pixelSize: 12; elide: Text.ElideRight; width: parent.width * 0.57; horizontalAlignment: Text.AlignRight }
                        }
                        Grid {
                            width: parent.width
                            columns: 5
                            spacing: 12
                            Repeater {
                                model: ThemeStore.themeNames
                                delegate: Rectangle {
                                    required property string modelData
                                    readonly property var palette: ThemeStore.palettes[modelData]
                                    width: (parent.width - 48) / 5
                                    height: 48
                                    radius: 18
                                    color: palette ? palette.background : ThemeStore.background
                                    border.color: modelData === ThemeStore.themeName ? (palette ? palette.accent : ThemeStore.accent) : ThemeStore.selection
                                    border.width: modelData === ThemeStore.themeName ? 2 : 1
                                    Rectangle { anchors.centerIn: parent; width: 12; height: 12; radius: 6; color: parent.palette ? parent.palette.accent : ThemeStore.accent }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: ThemeStore.setTheme(modelData)
                                    }
                                    Accessible.name: "Theme " + modelData
                                    Accessible.role: Accessible.Button
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 10
                        component Action: Rectangle {
                            id: action
                            required property string label
                            signal clicked()
                            width: (parent.width - 20) / 3
                            height: 72
                            radius: 20
                            color: pointer.pressed ? ThemeStore.selection : ThemeStore.lighterBackground
                            border.color: ThemeStore.selection
                            Text { anchors.centerIn: parent; text: action.label; color: ThemeStore.foreground; font.family: ThemeStore.fontFamily; font.pixelSize: 12; font.weight: Font.Medium }
                            MouseArea { id: pointer; anchors.fill: parent; onClicked: action.clicked() }
                        }
                        Action { label: "Screenshot"; onClicked: { root.close(); root.screenshotRequested(); } }
                        Action { label: "Restart"; onClicked: { root.close(); root.restartRequested(); } }
                        Action { label: "Shut down"; onClicked: { root.close(); root.shutdownRequested(); } }
                    }
                }
            }

            Text {
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 10 }
                text: "SWIPE UP TO CLOSE"
                color: ThemeStore.darkForeground
                font.family: ThemeStore.fontFamily
                font.pixelSize: 9
                font.letterSpacing: 1
            }
        }
    }

    NumberAnimation {
        id: slide
        target: root
        property: "offset"
        duration: 330
        easing.type: Easing.OutCubic
        onFinished: root.finishClose()
    }

    // Available width/height are fixed to the 540x1170 phone in this shell.
    QtObject { id: output; readonly property real height: 1170 }
}
