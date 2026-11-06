// Selection follows history updates until the user navigates explicitly.
import QtQuick

QtObject {
    id: selection
    property var items: []
    property bool active: false
    property string selectedId: ""
    property bool followNewest: true
    readonly property int selectedIndex: items.findIndex(item => item.id === selectedId)
    onActiveChanged: if (active) reset()
    onItemsChanged: if (followNewest || !items.some(item => item.id === selectedId)) selectFirst()
    function selectFirst(): void { selectedId = items[0]?.id ?? ""; }
    function reset(): void {
        followNewest = true;
        selectFirst();
    }
    function move(delta: int): void {
        followNewest = false;
        const index = Math.max(0, Math.min(items.length - 1, selectedIndex + delta));
        selectedId = items[index]?.id ?? "";
    }
}
