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
    readonly property real textSmall: textNormal * 0.85
    readonly property real textNormal: data.fonts.size * Prefs.get("textScale", 1)
    readonly property real textLarge: textNormal * 1.2

    // Glass fills: the panel colour and white at the theme's opacities.
    readonly property color panelFill: withAlpha(colors.panel, Prefs.get("panelOpacity", opacity.panel))
    readonly property color tileFill: withAlpha(colors.tile, opacity.tile)
    readonly property color tileFillHover: withAlpha(colors.tile, opacity.tile * 1.8)
    readonly property color rim: withAlpha("#ffffff", opacity.border)

    // Graphite interaction greys. Hover and selection are neutral lifts of
    // the charcoal glass, never a hue, so nothing in the shell turns blue.
    readonly property color hoverFill: withAlpha("#ffffff", 0.07)
    readonly property color pressFill: withAlpha("#ffffff", 0.12)
    readonly property color selectFill: withAlpha("#ffffff", 0.13)
    readonly property color focusRing: withAlpha("#ffffff", 0.45)

    // The bar is a solid strip; popups and banners hang just below it.
    readonly property int barHeight: 34
    readonly property color barFill: "#000000"
    readonly property int popupGap: 6
    readonly property int popupTop: barHeight + popupGap

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
