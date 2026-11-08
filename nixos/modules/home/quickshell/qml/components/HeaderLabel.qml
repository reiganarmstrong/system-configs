// A bold heading for a layout row. Its line box is padded so the box's
// centre is the centre of the capitals rather than of ascent plus descent;
// centring it in a row then lines the letters up with a switch or button.
import QtQuick

Label {
    id: label

    readonly property real capOffset: {
        const caps = metrics.tightBoundingRect("H");
        return (metrics.ascent - caps.height - metrics.descent) / 2;
    }

    weight: Font.Bold
    topPadding: Math.max(0, -2 * capOffset)
    bottomPadding: Math.max(0, 2 * capOffset)

    FontMetrics {
        id: metrics
        font: label.font
    }
}
