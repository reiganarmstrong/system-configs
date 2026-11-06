// A hairline divider across the full width.
import QtQuick
import qs.services

Rectangle {
    width: parent ? parent.width : 0
    height: 1
    color: Theme.withAlpha("#ffffff", 0.1)
}
