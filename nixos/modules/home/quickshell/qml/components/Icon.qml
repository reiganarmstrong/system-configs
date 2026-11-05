// A Lucide icon by name, e.g. Icon { name: "wifi" }.
import QtQuick
import qs.services

Text {
    property string name
    property real size: 16

    text: Theme.glyph(name)
    font.family: Theme.iconFont
    font.pixelSize: size
    color: Theme.colors.text
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
