// Bar tooltips need their own popup window: an inline tooltip is constrained
// to the 34px bar and can cover the button it describes.
import QtQuick
import QtQuick.Controls.Basic as Controls
import qs.services

Controls.ToolTip {
    id: tip
    popupType: Controls.Popup.Window
    y: parent.height + 6
    delay: 600
    closePolicy: Controls.Popup.NoAutoClose
    font.family: Theme.font
    font.pointSize: Theme.textSmall
    padding: 8
    contentItem: Text {
        text: tip.text
        font: tip.font
        color: Theme.colors.text
    }
    background: Rectangle {
        color: "#202023"
        radius: 6
        border.width: 1
        border.color: Theme.rim
    }
}
