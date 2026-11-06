// A small rotating arc for "working…" states; static dots with Reduce Motion.
import QtQuick
import qs.services

Item {
    id: spinner
    property real size: 14
    property color color: Theme.colors.textDim

    implicitWidth: size
    implicitHeight: size

    Icon {
        id: glyph
        anchors.centerIn: parent
        name: Motion.reduced ? "ellipsis" : "loader-circle"
        size: spinner.size
        color: spinner.color

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: spinner.visible && !Motion.reduced
        }
    }
}
