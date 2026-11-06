pragma Singleton
import QtQuick
// Keep the production duration policy without requiring a running Quickshell session.
QtObject {
    property bool reduced: false
    function ms(duration) { return reduced ? 0 : duration; }
}
