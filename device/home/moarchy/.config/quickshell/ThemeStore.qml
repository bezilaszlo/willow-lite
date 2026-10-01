pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var palettes: ({
        "tokyo-night": { mode:"dark", accent:"#7aa2f7", selection:"#292e42", muted:"#414868", background:"#1a1b26", dark_background:"#13141c", darker_background:"#0e0e14", lighter_background:"#24283b", foreground:"#a9b1d6", dark_foreground:"#565f89", bright_foreground:"#c0caf5", red:"#f7768e", yellow:"#e0af68", green:"#9ece6a", cyan:"#449dab", blue:"#7aa2f7", magenta:"#ad8ee6" },
        "catppuccin": { mode:"dark", accent:"#89b4fa", selection:"#45475a", muted:"#585b70", background:"#1e1e2e", dark_background:"#161622", darker_background:"#101019", lighter_background:"#313244", foreground:"#cdd6f4", dark_foreground:"#6c7086", bright_foreground:"#cdd6f4", red:"#f38ba8", yellow:"#f9e2af", green:"#a6e3a1", cyan:"#94e2d5", blue:"#89b4fa", magenta:"#f5c2e7" },
        "gruvbox": { mode:"dark", accent:"#7daea3", selection:"#504945", muted:"#665c54", background:"#282828", dark_background:"#1e1e1e", darker_background:"#161616", lighter_background:"#3c3836", foreground:"#d4be98", dark_foreground:"#7c6f64", bright_foreground:"#d4be98", red:"#ea6962", yellow:"#d8a657", green:"#a9b665", cyan:"#89b482", blue:"#7daea3", magenta:"#d3869b" },
        "everforest": { mode:"dark", accent:"#7fbbb3", selection:"#3d484d", muted:"#475258", background:"#2d353b", dark_background:"#21272c", darker_background:"#181d20", lighter_background:"#343f44", foreground:"#d3c6aa", dark_foreground:"#4f585e", bright_foreground:"#d3c6aa", red:"#e67e80", yellow:"#dbbc7f", green:"#a7c080", cyan:"#83c092", blue:"#7fbbb3", magenta:"#d699b6" },
        "kanagawa": { mode:"dark", accent:"#dcd7ba", selection:"#363646", muted:"#54546D", background:"#1f1f28", dark_background:"#17171e", darker_background:"#111116", lighter_background:"#223249", foreground:"#dcd7ba", dark_foreground:"#727169", bright_foreground:"#dcd7ba", red:"#c34043", yellow:"#c0a36e", green:"#76946a", cyan:"#6a9589", blue:"#7e9cd8", magenta:"#957fb8" },
        "osaka-jade": { mode:"dark", accent:"#509475", selection:"#32473B", muted:"#53685B", background:"#111c18", dark_background:"#0c1512", darker_background:"#090f0d", lighter_background:"#23372B", foreground:"#C1C497", dark_foreground:"#81B8A8", bright_foreground:"#F7E8B2", red:"#FF5345", yellow:"#459451", green:"#549e6a", cyan:"#2DD5B7", blue:"#509475", magenta:"#D2689C" },
        "ristretto": { mode:"dark", accent:"#f38d70", selection:"#403e41", muted:"#72696a", background:"#2c2525", dark_background:"#211b1b", darker_background:"#181414", lighter_background:"#3d2f2a", foreground:"#e6d9db", dark_foreground:"#72696a", bright_foreground:"#e6d9db", red:"#fd6883", yellow:"#f9cc6c", green:"#adda78", cyan:"#85dacc", blue:"#f38d70", magenta:"#a8a9eb" },
        "nord": { mode:"dark", accent:"#81a1c1", selection:"#434c5e", muted:"#4c566a", background:"#2e3440", dark_background:"#222730", darker_background:"#191c23", lighter_background:"#3b4252", foreground:"#d8dee9", dark_foreground:"#667080", bright_foreground:"#d8dee9", red:"#bf616a", yellow:"#ebcb8b", green:"#a3be8c", cyan:"#88c0d0", blue:"#81a1c1", magenta:"#b48ead" },
        "matte-black": { mode:"dark", accent:"#e68e0d", selection:"#2a2a2a", muted:"#333333", background:"#121212", dark_background:"#0d0d0d", darker_background:"#090909", lighter_background:"#1e1e1e", foreground:"#bebebe", dark_foreground:"#555555", bright_foreground:"#bebebe", red:"#D35F5F", yellow:"#b91c1c", green:"#FFC107", cyan:"#bebebe", blue:"#e68e0d", magenta:"#D35F5F" },
        "rose-pine": { mode:"light", accent:"#56949f", selection:"#dfdad9", muted:"#cecacd", background:"#faf4ed", dark_background:"#ede7e1", darker_background:"#e1dbd5", lighter_background:"#f2e9e1", foreground:"#575279", dark_foreground:"#9893a5", bright_foreground:"#575279", red:"#b4637a", yellow:"#ea9d34", green:"#286983", cyan:"#d7827e", blue:"#56949f", magenta:"#907aa9" }
    })
    readonly property var themeNames: Object.keys(palettes)
    property string themeName: "tokyo-night"
    readonly property var palette: palettes[themeName] || palettes["tokyo-night"]
    readonly property color background: palette.background
    readonly property color darkBackground: palette.dark_background
    readonly property color darkerBackground: palette.darker_background
    readonly property color lighterBackground: palette.lighter_background
    readonly property color foreground: palette.foreground
    readonly property color darkForeground: palette.dark_foreground
    readonly property color brightForeground: palette.bright_foreground
    readonly property color muted: palette.muted
    readonly property color selection: palette.selection
    readonly property color accent: palette.accent
    readonly property color red: palette.red
    readonly property color yellow: palette.yellow
    readonly property color green: palette.green
    readonly property color cyan: palette.cyan
    readonly property color blue: palette.blue
    readonly property color magenta: palette.magenta
    readonly property string fontFamily: regularFont.name || "JetBrains Mono"
    readonly property int space1: 4
    readonly property int space2: 8
    readonly property int space3: 12
    readonly property int space4: 16
    readonly property int space5: 24
    readonly property int radiusSmall: 10
    readonly property int radiusMedium: 18
    readonly property int radiusLarge: 26

    function setTheme(name) {
        if (!palettes[name] || themeName === name) return
        themeName = name
        themeFile.setText(JSON.stringify({ themeName: name }))
    }

    FileView {
        id: themeFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickshell/willow-theme.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const stored = JSON.parse(text())
                if (root.palettes[stored.themeName]) root.themeName = stored.themeName
            } catch (e) {}
        }
    }

    FontLoader { id: regularFont; source: "fonts/JetBrainsMono-Regular.ttf" }
    FontLoader { source: "fonts/JetBrainsMono-Thin.ttf" }
}
