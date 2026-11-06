pragma Singleton
import QtQuick
// Only visual tokens are substituted. The dropdown, popup and input handlers are real.
QtObject {
    readonly property string font: "DejaVu Sans"
    readonly property string iconFont: font
    readonly property real textNormal: 11
    readonly property var colors: ({text: "white", textDim: "gray", highlight: "#0088ff"})
    function glyph(name) { return name === "check" ? "✓" : "⌄"; }
    function withAlpha(value, alpha) {
        const c = Qt.color(value);
        return Qt.rgba(c.r, c.g, c.b, alpha);
    }
}
