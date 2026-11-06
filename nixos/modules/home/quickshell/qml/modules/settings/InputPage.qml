import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.components
import qs.components.settings
import qs.services

Column {
    required property var host
    spacing: 10
    SettingChoice {
        title: "Keyboard layout"
        options: ["English (US)", "English (UK)", "German", "French", "Spanish", "US + UK"]
        values: ["us", "gb", "de", "fr", "es", "us,gb"]
        value: host.pref("keyboardLayout", "us")
        onChosen: v => host.set("keyboardLayout", v)
    }
    SettingChoice {
        title: "Caps Lock behavior"
        options: ["Caps Lock", "Escape", "Control", "Swap Caps Lock and Escape"]
        values: ["", "caps:escape", "ctrl:nocaps", "caps:swapescape"]
        value: host.pref("capsLock", "")
        onChosen: v => host.set("capsLock", v)
    }
    SettingLevel {
        title: "Key repeat rate"
        value: host.pref("repeatRate", 25)
        minimum: 5
        maximum: 60
        multiplier: 1
        suffix: "/s"
        onMoved: v => host.set("repeatRate", Math.round(v))
    }
    SettingLevel {
        title: "Key repeat delay"
        value: host.pref("repeatDelay", 600)
        minimum: 150
        maximum: 1000
        multiplier: 1
        suffix: " ms"
        onMoved: v => host.set("repeatDelay", Math.round(v / 10) * 10)
    }
    SettingToggle {
        title: "Left-handed mouse"
        detail: "Swap the primary and secondary pointer buttons."
        checked: host.pref("leftHanded", false)
        onToggled: v => host.set("leftHanded", v)
    }
    SettingLevel {
        title: "Pointer speed"
        value: host.pref("pointerSpeed", 0)
        minimum: -1
        maximum: 1
        multiplier: 1
        decimals: 2
        suffix: ""
        onMoved: v => host.set("pointerSpeed", Math.round(v * 100) / 100)
    }
    SettingChoice {
        title: "Pointer acceleration"
        options: ["Adaptive", "Off (flat)"]
        values: ["adaptive", "flat"]
        value: host.pref("pointerAcceleration", "adaptive")
        onChosen: v => host.set("pointerAcceleration", v)
    }
    SettingToggle {
        title: "Mouse natural scrolling"
        checked: host.pref("naturalScroll", false)
        onToggled: v => host.set("naturalScroll", v)
    }
    SettingLevel {
        title: "Scroll speed"
        value: host.pref("scrollFactor", 1)
        minimum: 0.2
        maximum: 3
        multiplier: 1
        decimals: 1
        suffix: "×"
        onMoved: v => host.set("scrollFactor", Math.round(v * 10) / 10)
    }
    SettingToggle {
        title: "Touchpad natural scrolling"
        checked: host.pref("touchpadNaturalScroll", true)
        onToggled: v => host.set("touchpadNaturalScroll", v)
    }
    SettingToggle {
        title: "Tap to click"
        checked: host.pref("tapToClick", true)
        onToggled: v => host.set("tapToClick", v)
    }
    SettingToggle {
        title: "Disable touchpad while typing"
        checked: host.pref("disableWhileTyping", true)
        onToggled: v => host.set("disableWhileTyping", v)
    }
    SettingToggle {
        title: "Two-finger right-click"
        checked: host.pref("twoFingerClick", true)
        onToggled: v => host.set("twoFingerClick", v)
    }
    SettingToggle {
        title: "Focus follows pointer"
        detail: "Off keeps focus on the window you clicked."
        checked: host.pref("focusFollowsMouse", false)
        onToggled: v => host.set("focusFollowsMouse", v)
    }
    SettingRow {
        title: "Window shortcuts"
        detail: "Super+Space  Search apps\nSuper+,  Settings\nSuper+S  Control center\nSuper+T  Terminal\nSuper+Q  Close window\nSuper+F  Full screen\nSuper+V  Float window\nSuper+arrows  Focus window\nSuper+Shift+arrows  Move window\nSuper+1…0  Switch workspace\nSuper+Shift+1…0  Move to workspace\nSuper+drag  Move window\nSuper+right-drag  Resize window\nSuper+L  Lock\n\nSuper is the Windows key on most keyboards and Command through VNC."
    }
}
