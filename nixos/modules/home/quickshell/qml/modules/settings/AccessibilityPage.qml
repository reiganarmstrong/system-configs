import QtQuick
import qs.components.settings
import qs.services

Column {
    required property var host
    spacing: 10
    SettingChoice {
        title: "Interface text size"
        detail: "Scale desktop and GTK interface text. Terminal and webpage zoom are controlled by those apps."
        options: ["85%", "100%", "115%", "125%", "150%"]
        values: [0.85, 1, 1.15, 1.25, 1.5]
        value: Prefs.get("textScale", 1)
        onChosen: v => Prefs.set("textScale", v)
    }
    SettingChoice {
        title: "Pointer size"
        options: ["Small · 16", "Default · 24", "Large · 32", "40", "48", "Extra large · 64"]
        values: [16, 24, 32, 40, 48, 64]
        value: Prefs.get("cursorSize", 24)
        onChosen: v => Prefs.set("cursorSize", v)
    }
    SettingToggle {
        title: "Reduce motion"
        detail: "Disable desktop animation and popup transitions."
        checked: Prefs.get("reduceMotion", false)
        onToggled: v => Prefs.set("reduceMotion", v)
    }
    SettingToggle {
        title: "Left-handed mouse"
        checked: Prefs.get("leftHanded", false)
        onToggled: v => Prefs.set("leftHanded", v)
    }
    SettingAction {
        title: "Keyboard and touchpad"
        detail: "Repeat timing, Caps Lock behavior, scrolling and pointer sensitivity."
        buttonText: "Configure"
        onActivated: ShellState.openSettings("input")
    }
    SettingRow {
        title: "Additional assistive technology"
        detail: "Screen reading, magnification and sticky keys need compositor-specific integration. They are not enabled by these appearance controls."
    }
}
