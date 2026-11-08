// A full-width glass tile with a bold title over a thin slider.
import QtQuick
import qs.components
import qs.services

GlassTile {
    id: tile

    property string title
    property string detail
    property alias startIcon: slider.startIcon
    property alias endIcon: slider.endIcon
    property alias value: slider.value
    property alias sliderEnabled: slider.enabled
    // When openable, the title row opens a details page (with a chevron).
    property bool openable: false
    signal moved(real value)
    signal titleClicked()
    signal opened()
    signal startIconClicked()

    implicitHeight: 70
    radius: 22

    MouseArea {
        id: titleArea
        width: parent.width
        height: 30
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.openable ? tile.opened() : tile.titleClicked()
    }
    ChevronHint {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: titleLabel.verticalCenter
        width: 24
        height: 24
        visible: tile.openable
        revealOnHover: false
        hovered: titleArea.containsMouse
    }
    Label {
        id: titleLabel
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 14
        anchors.topMargin: 10
        text: tile.title
        weight: Font.Bold
        size: Theme.textSmall
    }
    Label {
        anchors.right: parent.right
        anchors.rightMargin: tile.openable ? 40 : 14
        anchors.baseline: titleLabel.baseline
        width: Math.min(implicitWidth, tile.width - titleLabel.implicitWidth - 52)
        horizontalAlignment: Text.AlignRight
        text: tile.detail
        dim: true
        size: Theme.textSmall
    }

    ThinSlider {
        id: slider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.bottomMargin: 8
        accessibleName: tile.title
        opacity: enabled ? 1 : 0.5
        onStartIconClicked: tile.startIconClicked()
        onMoved: v => tile.moved(v)
        onReleased: Brightness.flush()
    }
}
