import QtQuick
import qs.components.settings
import qs.services

Column {
    id: page
    required property var host
    // Candidates are the apps that declare each type, as GIO resolves them,
    // plus the current handler so it is always visible.
    readonly property var info: SettingsAdmin.get("defaults", {})
    readonly property var types: [
        {
            key: "browser",
            title: "Web browser"
        },
        {
            key: "files",
            title: "File manager"
        },
        {
            key: "text",
            title: "Text editor"
        },
        {
            key: "pdf",
            title: "PDF documents"
        },
        {
            key: "audio",
            title: "Music and audio"
        },
        {
            key: "video",
            title: "Video"
        },
        {
            key: "mail",
            title: "Email links"
        }
    ]
    spacing: 10
    Component.onCompleted: SettingsAdmin.refresh("defaults")
    Repeater {
        model: page.types
        SettingChoice {
            required property var modelData
            readonly property var kind: page.info[modelData.key] ?? null
            readonly property var candidates: kind?.apps ?? []
            title: modelData.title
            detail: !kind ? "Loading…" : candidates.length ? "" : "No installed application opens this type. Add one in Applications."
            options: candidates.map(a => a.name)
            values: candidates.map(a => a.id)
            value: kind?.current ?? ""
            choiceWidth: 260
            enabled: candidates.length > 0 && !SettingsAdmin.mutating
            onChosen: value => SettingsAdmin.request("default-app", {
                    kind: modelData.key,
                    id: value
                })
        }
    }
}
