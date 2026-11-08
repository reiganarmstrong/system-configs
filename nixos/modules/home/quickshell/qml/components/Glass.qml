// A frosted surface: translucent fill and a faint white rim. The window it
// sits in asks niri to blur behind it with a BackgroundEffect region.
import QtQuick
import qs.services

Rectangle {
    property real fillOpacity: Prefs.get("panelOpacity", Theme.opacity.panel)

    color: Theme.withAlpha(Theme.colors.panel, fillOpacity)
    radius: Theme.radius.panel
    border.width: 1
    border.color: Theme.rim
}
