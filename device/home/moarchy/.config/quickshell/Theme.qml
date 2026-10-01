import QtQuick
import "."

// Compatibility facade for the Sway shell; redesigned components import
// ThemeStore directly so every surface observes one persisted palette.
QtObject {
    readonly property color background: ThemeStore.background
    readonly property color darkBackground: ThemeStore.darkBackground
    readonly property color darkerBackground: ThemeStore.darkerBackground
    readonly property color lighterBackground: ThemeStore.lighterBackground
    readonly property color foreground: ThemeStore.foreground
    readonly property color darkForeground: ThemeStore.darkForeground
    readonly property color brightForeground: ThemeStore.brightForeground
    readonly property color muted: ThemeStore.muted
    readonly property color selection: ThemeStore.selection
    readonly property color accent: ThemeStore.accent
    readonly property color red: ThemeStore.red
    readonly property color yellow: ThemeStore.yellow
    readonly property color green: ThemeStore.green
    readonly property color cyan: ThemeStore.cyan
    readonly property color blue: ThemeStore.blue
    readonly property color magenta: ThemeStore.magenta

    // Names retained for legacy components in willow-sway.qml.
    readonly property color surface: lighterBackground
    readonly property color surfacePressed: selection
    readonly property color border: muted
    readonly property color divider: muted
    readonly property color textPrimary: brightForeground
    readonly property color textSecondary: foreground
    readonly property color textMuted: darkForeground
    readonly property color danger: red
}
