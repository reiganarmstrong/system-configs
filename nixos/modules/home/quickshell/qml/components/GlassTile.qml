// A raised glass tile inside a panel: lit from the top, with a faint rim.
import QtQuick
import qs.services

Rectangle {
    property bool hovered: false
    // Lighter overall, for "on" states drawn in white.
    property bool solid: false

    radius: Theme.radius.tile
    border.width: 1
    border.color: Theme.withAlpha("#ffffff", solid ? 0 : 0.16)
    gradient: Gradient {
        GradientStop {
            position: 0
            color: solid ? Theme.colors.accent : Theme.withAlpha("#ffffff", hovered ? 0.2 : 0.15)
        }
        GradientStop {
            position: 1
            color: solid ? Theme.colors.accent : Theme.withAlpha("#ffffff", hovered ? 0.12 : 0.07)
        }
    }
}
