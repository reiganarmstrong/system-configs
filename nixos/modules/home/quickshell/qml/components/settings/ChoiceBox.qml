// Shared desktop dropdown: quiet field, checked options and a fitted menu.
import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Controls.Basic as Controls
import qs.components
import qs.services

Controls.ComboBox {
    id: control
    property var options: []
    readonly property real optionHeight: 36
    readonly property real naturalMenuWidth: options.reduce((width, option) => Math.max(width, metrics.advanceWidth(String(option)) + 70), 0)

    implicitWidth: 200
    implicitHeight: 36
    model: options
    font.family: Theme.font
    font.pointSize: Theme.textNormal
    hoverEnabled: true
    activeFocusOnTab: true
    wheelEnabled: false
    leftPadding: 12
    rightPadding: 38
    topPadding: 7
    bottomPadding: 7
    enabled: count > 0
    palette.text: Theme.colors.text
    palette.buttonText: Theme.colors.text
    palette.window: "#27272d"
    palette.highlight: "#45454e"
    palette.highlightedText: Theme.colors.text

    FontMetrics { id: metrics; font: control.font }
    contentItem: Text {
        text: control.currentIndex >= 0 ? control.displayText : control.count ? "Choose…" : "Unavailable"
        textFormat: Text.PlainText
        font: control.font
        color: control.currentIndex >= 0 ? Theme.colors.text : Theme.colors.textDim
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Icon {
        x: control.width - width - 12
        y: (control.height - height) / 2
        name: control.popup.visible ? "chevron-up" : "chevron-down"
        size: 14
        color: control.hovered || control.popup.visible ? Theme.colors.text : Theme.colors.textDim
    }
    background: Rectangle {
        radius: 9
        color: control.down || control.popup.visible ? "#3b3b43" : control.hovered ? "#38383f" : "#303037"
        border.width: 1
        border.color: Theme.withAlpha("#ffffff", control.popup.visible || control.hovered ? 0.18 : 0.10)
        Behavior on color { ColorAnimation { duration: Motion.ms(100) } }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: 12
            color: "transparent"
            border.width: 2
            border.color: "#5b9bff"
            visible: control.visualFocus && !control.popup.visible
        }
    }
    delegate: Controls.ItemDelegate {
        id: option
        required property var modelData
        required property int index
        width: menuList.width
        height: control.optionHeight
        padding: 0
        text: String(modelData)
        hoverEnabled: true
        highlighted: control.highlightedIndex === index
        contentItem: Item {
            Icon {
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                name: "check"
                size: 14
                color: Theme.colors.highlight
                visible: option.index === control.currentIndex
            }
            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 34
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: option.text
                textFormat: Text.PlainText
                font.family: control.font.family
                font.pointSize: control.font.pointSize
                font.weight: option.index === control.currentIndex ? Font.DemiBold : Font.Normal
                color: Theme.colors.text
                elide: Text.ElideRight
            }
        }
        background: Rectangle {
            radius: 7
            color: option.down ? "#30ffffff" : option.highlighted || option.hovered ? "#1bffffff" : "transparent"
        }
    }
    popup: Controls.Popup {
        id: menu
        property real heightLimit: 320
        readonly property real naturalHeight: control.count * (control.optionHeight + 2) + padding * 2
        width: Math.min(Math.max(control.width, control.naturalMenuWidth), 480, (control.Window.window?.width ?? 960) - 24)
        implicitHeight: Math.min(naturalHeight, heightLimit)
        padding: 6
        margins: 10
        // The field toggles on release. Closing on its press can finish the
        // exit animation first, making that same release reopen the menu.
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutsideParent
        onAboutToShow: {
            const origin = control.mapToItem(null, 0, 0);
            const window = control.Window.window;
            const below = Math.max(0, (window?.height ?? 680) - origin.y - control.height - 14);
            const above = Math.max(0, origin.y - 14);
            const upward = below < Math.min(naturalHeight, 320) && above > below;
            heightLimit = Math.max(40, Math.min(320, upward ? above : below));
            y = upward ? -implicitHeight - 6 : control.height + 6;
            x = Math.max(12 - origin.x, Math.min(control.width - width, (window?.width ?? 960) - 12 - origin.x - width));
        }
        onOpened: menuList.positionViewAtIndex(control.currentIndex, ListView.Contain)
        contentItem: ListView {
            id: menuList
            clip: true
            spacing: 2
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: Controls.ScrollBar {
                visible: menuList.contentHeight > menuList.height + 1
                policy: Controls.ScrollBar.AsNeeded
                padding: 0
                implicitWidth: 4
                contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.withAlpha("#ffffff", 0.30) }
                background: null
            }
        }
        background: Item {
            Rectangle {
                id: surface
                anchors.fill: parent
                radius: 12
                color: "#27272d"
                border.width: 1
                border.color: Theme.withAlpha("#ffffff", 0.14)
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: surface
                shadowEnabled: true
                shadowBlur: 0.6
                shadowVerticalOffset: 5
                shadowOpacity: 0.35
            }
        }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.ms(90) } }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Motion.ms(70) } }
    }
}
