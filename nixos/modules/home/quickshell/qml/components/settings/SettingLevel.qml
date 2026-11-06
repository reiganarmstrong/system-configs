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
            id: valueText
            // Wide enough for the largest value at any text size, so the slider does not shift.
            width: Math.max(48, Math.ceil(widest.advanceWidth))
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: (row.value * row.multiplier).toFixed(row.decimals) + row.suffix
            dim: true
            size: Theme.textSmall
            TextMetrics {
                id: widest
                font: valueText.font
                text: (Math.max(Math.abs(row.minimum), Math.abs(row.maximum)) * row.multiplier).toFixed(row.decimals) + row.suffix
            }
        }
    }
}
