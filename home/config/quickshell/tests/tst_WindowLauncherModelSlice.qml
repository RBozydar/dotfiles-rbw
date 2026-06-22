import "../system/adapters/search/window-launcher-model.js" as WindowLauncherModel
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function sampleSnapshot() {
        return {
            focusedAddress: "0x2",
            entries: [
                {
                    address: "0x1",
                    title: "Firefox Developer",
                    className: "firefox",
                    workspaceId: 2,
                    workspaceName: "2",
                    focusHistoryId: 4
                },
                {
                    address: "0x2",
                    title: "Ghostty",
                    className: "ghostty",
                    workspaceId: 1,
                    workspaceName: "1",
                    focusHistoryId: 0
                }
            ]
        };
    }

    function findById(items, id) {
        for (let index = 0; index < items.length; index += 1) {
            if (items[index].id === id)
                return items[index];
        }

        return null;
    }

    function test_searchWindowSnapshot_returns_focus_actions_with_expected_metadata() {
        const items = WindowLauncherModel.searchWindowSnapshot(sampleSnapshot(), "", 24, {
            focusCommand: "window_switcher.focus"
        });

        verify(Array.isArray(items));
        compare(items.length, 2);
        compare(items[0].id, "win:0x2");
        compare(items[0].provider, "windows");
        compare(items[0].action.type, "shell.ipc.dispatch");
        compare(items[0].action.command, "window_switcher.focus");
        compare(items[0].action.args.length, 1);
        compare(items[0].action.args[0], "0x2");
    }

    function test_searchWindowSnapshot_filters_using_multi_term_query() {
        const items = WindowLauncherModel.searchWindowSnapshot(sampleSnapshot(), "fire dev", 24, {
            focusCommand: "window_switcher.focus"
        });

        compare(items.length, 1);
        compare(items[0].id, "win:0x1");
        verify(String(items[0].subtitle || "").indexOf("firefox") >= 0);
    }

    function test_searchWindowSnapshot_limits_results_and_dedupes_duplicate_addresses() {
        const snapshot = sampleSnapshot();
        snapshot.entries.push({
            address: "0x2",
            title: "Duplicate Ghostty",
            className: "ghostty",
            workspaceId: 1,
            workspaceName: "1",
            focusHistoryId: 3
        });
        snapshot.entries.push({
            address: "0x9",
            title: "Files",
            className: "org.gnome.Nautilus",
            workspaceId: 3,
            workspaceName: "3",
            focusHistoryId: 2
        });

        const items = WindowLauncherModel.searchWindowSnapshot(snapshot, "", 2, {
            focusCommand: "window_switcher.focus"
        });

        compare(items.length, 2);
        compare(items[0].id, "win:0x2");
        compare(items[1].id, "win:0x9");
        verify(findById(items, "win:0x2") !== null);
        verify(findById(items, "win:0x1") === null);
    }

    name: "WindowLauncherModelSlice"
}
