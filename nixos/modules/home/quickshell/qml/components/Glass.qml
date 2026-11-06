// A frosted surface: translucent fill and a faint white rim. Hyprland blurs
// what is behind it through the layer rules in rules.lua.
import QtQuick
import qs.services

Rectangle {
    property real fillOpacity: Prefs.get("panelOpacity", Theme.opacity.panel)

    color: Theme.withAlpha(Theme.colors.panel, fillOpacity)
    radius: Theme.radius.panel
    border.width: 1
    border.color: Theme.rim
}
