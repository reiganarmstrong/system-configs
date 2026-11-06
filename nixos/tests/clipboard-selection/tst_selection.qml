import QtQuick
import QtTest

Item {
    ClipboardSelection { id: selection }
    TestCase {
        name: "ClipboardSelection"
        when: windowShown
        function cleanup() { selection.active = false; selection.items = []; }
        function test_delayed_refresh_selects_newest() {
            selection.items = [{id: "older"}];
            selection.active = true;
            compare(selection.selectedId, "older");
            wait(20);
            selection.items = [{id: "newest"}, {id: "older"}];
            compare(selection.selectedIndex, 0, "Refresh left the stale cached entry selected");
            compare(selection.selectedId, "newest");
        }
        function test_empty_cache_then_load_selects_newest() {
            selection.active = true;
            selection.items = [{id: "newest"}, {id: "older"}];
            compare(selection.selectedIndex, 0);
        }
        function test_navigation_survives_refresh() {
            selection.items = [{id: "newest"}, {id: "older"}];
            selection.active = true;
            selection.move(1);
            selection.items = [{id: "arrived"}, {id: "newest"}, {id: "older"}];
            compare(selection.selectedId, "older");
            compare(selection.selectedIndex, 2);
        }
        function test_reopen_returns_to_newest() {
            selection.items = [{id: "newest"}, {id: "older"}];
            selection.active = true;
            selection.move(1);
            selection.active = false;
            selection.active = true;
            compare(selection.selectedIndex, 0);
        }
        function test_search_reset_follows_first_match() {
            selection.items = [{id: "newest"}, {id: "older"}];
            selection.active = true;
            selection.move(1);
            selection.reset();
            selection.items = [{id: "match"}, {id: "older"}];
            compare(selection.selectedId, "match");
        }
        function test_deleted_selection_falls_back_to_first() {
            selection.items = [{id: "newest"}, {id: "older"}];
            selection.active = true;
            selection.move(1);
            selection.items = [{id: "newest"}];
            compare(selection.selectedIndex, 0);
        }
    }
}
