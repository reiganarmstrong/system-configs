// A media seek bar: follows drags live, but only reports a seek on release,
// because many players stutter when seeked continuously.
import QtQuick
import QtQuick.Controls.Basic as Controls
import qs.services

Item {
    id: scrubber

    property real value: 0
    property bool seekable: true
    readonly property alias pressed: control.pressed
    readonly property real shownValue: control.value
    signal moved(real value)
    signal committed(real value)

    implicitHeight: 20
    opacity: seekable ? 1 : 0.5

    Controls.Slider {
        id: control
        anchors.fill: parent
        from: 0
        to: 1
        live: true
        enabled: scrubber.seekable
        hoverEnabled: true
        wheelEnabled: false
        padding: 0

        Binding on value {
            value: scrubber.value
            when: !control.pressed && !hold.running
            restoreMode: Binding.RestoreNone
        }
        onMoved: scrubber.moved(value)
        onPressedChanged: {
            if (!pressed) {
                hold.restart();
                scrubber.committed(value);
            }
        }

        // Hold the dropped position briefly while the player catches up.
        Timer {
            id: hold
            interval: 600
        }

        background: Rectangle {
            y: (control.height - height) / 2
            width: control.availableWidth
            height: control.pressed ? 6 : 4
            radius: height / 2
            color: Theme.withAlpha("#ffffff", 0.22)
            Behavior on height { NumberAnimation { duration: Motion.ms(100) } }

            Rectangle {
                width: control.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: Theme.colors.highlight
            }
        }
        handle: Rectangle {
            x: control.visualPosition * (control.availableWidth - width)
            y: (control.height - height) / 2
            width: 12
            height: 12
            radius: 6
            color: "white"
            visible: scrubber.seekable
            opacity: control.hovered || control.pressed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.ms(100) } }
        }
    }
}
