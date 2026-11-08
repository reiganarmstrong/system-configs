import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.components
import qs.components.settings
import qs.services

Column {
    required property var host
    spacing: 10
    SettingLevel {
        title: "Panel opacity"
        detail: "More opaque panels show less of the wallpaper."
        value: host.pref("panelOpacity", 0.55)
        minimum: 0.35
        maximum: 1
        onMoved: v => host.set("panelOpacity", Math.round(v * 100) / 100)
    }
    SettingToggle {
        title: "Reduce motion"
        detail: "Disable popup and panel transitions. Window animations are set in Hyprland's config."
        checked: host.pref("reduceMotion", false)
        onToggled: v => host.set("reduceMotion", v)
    }
    SettingToggle {
        title: "24-hour clock"
        checked: host.pref("clock24h", false)
        onToggled: v => host.set("clock24h", v)
    }
    SettingToggle {
        title: "Show seconds"
        checked: host.pref("showSeconds", false)
        onToggled: v => host.set("showSeconds", v)
    }
    SettingToggle {
        title: "Battery percentage"
        checked: host.pref("showBatteryPercent", true)
        onToggled: v => host.set("showBatteryPercent", v)
    }
    SettingAction {
        title: "Wallpaper"
        detail: host.pref("wallpaper", "") ? host.pref("wallpaper", "").split("/").pop() : "Default desktop wallpaper"
        buttonText: "Choose…"
        onActivated: wallpaperPicker.open()
    }
    SettingAction {
        title: "Restore default wallpaper"
        buttonText: "Restore"
        enabled: host.pref("wallpaper", "") !== ""
        onActivated: host.set("wallpaper", "")
    }
    SettingRow {
        title: "Theme"
        detail: "Dark · " + Theme.font + " · " + Theme.data.icons.replace(/-/g, " ") + " icons\nFonts and the dark system theme are shared by your VM and laptop configuration."
    }
}
