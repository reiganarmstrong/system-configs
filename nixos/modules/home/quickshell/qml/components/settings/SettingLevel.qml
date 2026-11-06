import QtQuick
import qs.components
import qs.services

SettingRow {
    id: row
    property real value: 0
    property real minimum: 0
    property real maximum: 1
    property string suffix: "%"
    property int decimals: 0
    property real multiplier: 100
    signal moved(real value)
    Row {
        spacing: 10
        ThinSlider {
            width: 190
            accessibleName: row.title
            value: (row.value - row.minimum) / (row.maximum - row.minimum)
            onMoved: v => row.moved(row.minimum + v * (row.maximum - row.minimum))
            onReleased: Brightness.flush()
        }
        Label {
            width: 48
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: (row.value * row.multiplier).toFixed(row.decimals) + row.suffix
            dim: true
            size: Theme.textSmall
        }
    }
}
