pragma Singleton
// Animation durations that collapse to zero when Reduce Motion is on.
import QtQuick
import Quickshell
import qs.services

Singleton {
    readonly property bool reduced: Prefs.get("reduceMotion", false)
    function ms(duration: int): int {
        return reduced ? 0 : duration;
    }
}
