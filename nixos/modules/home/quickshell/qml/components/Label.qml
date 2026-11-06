// Interface text in the theme font.
import QtQuick
import qs.services

Text {
    property bool dim: false
    property real size: Theme.textNormal
    property int weight: Font.Medium

    color: dim ? Theme.colors.textDim : Theme.colors.text
    font.family: Theme.font
    font.pointSize: size
    font.weight: weight
    textFormat: Text.PlainText
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
