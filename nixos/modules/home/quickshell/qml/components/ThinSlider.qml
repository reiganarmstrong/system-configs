// A native draggable slider with a generous target, thumb and keyboard input.
import QtQuick
import QtQuick.Controls.Basic as Controls
import qs.services

Item {
    id: slider
    property string startIcon
    property string endIcon
    property string accessibleName: "Level"
    property real value: 0
    readonly property bool pressed: control.pressed
    property alias wheelEnabled: control.wheelEnabled
    signal moved(real value)
    signal released()
    // The start icon doubles as a mute button where a page wants it.
    signal startIconClicked()
    implicitHeight: 28

    Icon {
        id: startGlyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        name: slider.startIcon
        size: 12
        visible: name !== ""
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: slider.startIconClicked()
        }
    }
    Icon {
        id: endGlyph
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        name: slider.endIcon
        size: 15
        visible: name !== ""
    }
    Controls.Slider {
        id: control
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: startGlyph.visible ? 25 : 0
        anchors.rightMargin: endGlyph.visible ? 27 : 0
        height: parent.height
        from: 0
        to: 1
        stepSize: 0.01
        live: true
        hoverEnabled: true
        wheelEnabled: true
        activeFocusOnTab: true
        Accessible.name: slider.accessibleName
        Binding on value {
            value: slider.value
            when: !control.pressed
            restoreMode: Binding.RestoreNone
        }
        onMoved: slider.moved(value)
        onPressedChanged: if (!pressed) slider.released()
        background: Rectangle {
            x: control.leftPadding
            y: (control.height - height) / 2
            width: control.availableWidth
            height: 6
            radius: 3
            color: Theme.withAlpha("#ffffff", 0.22)
            Rectangle {
                width: control.visualPosition * parent.width
                height: parent.height
                radius: 3
                color: Theme.colors.highlight
            }
        }
        handle: Rectangle {
            x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
            y: (control.height - height) / 2
            width: 16
            height: 16
            radius: 8
            color: "white"
            border.width: control.activeFocus ? 2 : 1
            border.color: control.activeFocus ? Theme.focusRing : "#40000000"
        }
        Keys.onPressed: event => {
            let next = value;
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) next -= 0.05;
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) next += 0.05;
            else if (event.key === Qt.Key_PageDown) next -= 0.1;
            else if (event.key === Qt.Key_PageUp) next += 0.1;
            else if (event.key === Qt.Key_Home) next = 0;
            else if (event.key === Qt.Key_End) next = 1;
            else return;
            value = Math.max(0, Math.min(1, next));
            slider.moved(value);
            event.accepted = true;
        }
    }
}
