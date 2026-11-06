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
        title: "Brightness"
        detail: Brightness.available ? "Built-in display backlight" : "This display has no adjustable backlight."
        enabled: Brightness.available
        value: Brightness.level
        minimum: 0.01
        onMoved: v => Brightness.set(v)
    }
    Repeater {
        model: Prefs.monitors
        Column {
            id: displayCard
            required property var modelData
            width: parent.width
            spacing: 10
            // The exact current mode is sent unchanged; listed modes that only
            // differ from it by rounding are the same mode and are not repeated.
            readonly property string currentMode: modelData.width + "x" + modelData.height + "@" + modelData.refreshRate.toFixed(5)
            property string mode: currentMode
            property real scale: modelData.scale
            property int rotation: modelData.transform
            readonly property var modes: [currentMode, ...[...new Set(modelData.availableModes.map(m => m.replace("Hz", "")))].filter(m => {
                    const [size, rate] = m.split("@");
                    return size !== modelData.width + "x" + modelData.height || Math.abs(Number(rate) - modelData.refreshRate) >= 0.05;
                })]
            function modeLabel(m) {
                const [size, rate] = m.split("@");
                return size.replace("x", " × ") + " · " + Number(rate).toFixed(2) + " Hz";
            }
            SettingRow {
                title: displayCard.modelData.name
                detail: displayCard.modelData.description + "\n" + displayCard.modelData.width + " × " + displayCard.modelData.height + " at " + displayCard.modelData.refreshRate.toFixed(2) + " Hz"
            }
            SettingChoice {
                title: "Resolution & refresh"
                enabled: !Prefs.system.fixedDisplayMode
                detail: Prefs.system.fixedDisplayMode ? "VNC resolution is fixed. Use Scale to change the desktop size." : ""
                choiceWidth: 230
                options: displayCard.modes.map(m => displayCard.modeLabel(m))
                values: displayCard.modes
                value: displayCard.mode
                onChosen: v => displayCard.mode = v
            }
            SettingChoice {
                title: "Scale"
                options: ["75%", "100%", "125%", "150%", "175%", "200%", "250%", "300%"]
                values: [0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3]
                value: displayCard.scale
                onChosen: v => displayCard.scale = v
            }
            SettingChoice {
                title: "Rotation"
                options: ["Normal", "90°", "180°", "270°"]
                values: [0, 1, 2, 3]
                value: displayCard.rotation
                onChosen: v => displayCard.rotation = v
            }
            SettingAction {
                title: "Apply display changes"
                detail: "Keep the new settings within 15 seconds, or they will revert."
                buttonText: "Preview"
                enabled: Prefs.previewSeconds === 0
                onActivated: Prefs.displayPreview({
                    output: displayCard.modelData.name,
                    mode: displayCard.mode,
                    scale: displayCard.scale,
                    transform: displayCard.rotation
                })
            }
        }
    }
    SettingAction {
        title: "Arrange displays"
        enabled: !Prefs.system.fixedDisplayMode
        detail: Prefs.system.fixedDisplayMode ? "This VM has one fixed virtual monitor." : "Position multiple monitors. Arrangement changes last for this session."
        onActivated: host.launch(["wdisplays"])
    }
    SettingAction {
        title: "Refresh displays"
        detail: "Detect newly connected monitors."
        buttonText: "Refresh"
        onActivated: Prefs.refresh()
    }
}
