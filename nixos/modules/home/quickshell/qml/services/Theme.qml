pragma Singleton
// The shared theme from Nix (theme.json), plus helpers for colours and icons.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var data: JSON.parse(themeFile.text())
    readonly property var icons: JSON.parse(iconFile.text())

    readonly property var colors: data.colors
    readonly property var radius: data.radius
    readonly property var spacing: data.spacing
    readonly property var opacity: data.opacity
    readonly property string font: data.fonts.ui
    readonly property string iconFont: data.fonts.icons
    readonly property string wallpaper: data.wallpaper
    readonly property var user: data.user

    // Point sizes, scaled from the theme's base size.
    readonly property real textSmall: data.fonts.size * 0.85
    readonly property real textNormal: data.fonts.size
    readonly property real textLarge: data.fonts.size * 1.2

    // Glass fills: the panel colour and white at the theme's opacities.
    readonly property color panelFill: withAlpha(colors.panel, Prefs.get("panelOpacity", opacity.panel))
    readonly property color tileFill: withAlpha(colors.tile, opacity.tile)
    readonly property color tileFillHover: withAlpha(colors.tile, opacity.tile * 1.8)
    readonly property color rim: withAlpha("#ffffff", opacity.border)

    function withAlpha(hex: string, alpha: real): color {
        const c = Qt.color(hex);
        return Qt.rgba(c.r, c.g, c.b, alpha);
    }

    function glyph(name: string): string {
        return icons[name] ?? "";
    }

    FileView {
        id: themeFile
        path: Quickshell.shellDir + "/theme.json"
        blockLoading: true
    }

    FileView {
        id: iconFile
        path: Quickshell.shellDir + "/icons.json"
        blockLoading: true
    }
}
