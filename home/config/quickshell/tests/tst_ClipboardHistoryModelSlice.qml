import "../system/adapters/search/clipboard-history-model.js" as ClipboardHistoryModel
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function test_parseListOutput_parses_id_and_preview_lines() {
        const parsed = ClipboardHistoryModel.parseListOutput("330\talpha\n329\tbeta\ninvalid");

        compare(parsed.length, 2);
        compare(parsed[0].id, "330");
        compare(parsed[0].preview, "alpha");
        compare(parsed[1].id, "329");
    }

    function test_parseListOutput_filters_non_numeric_ids() {
        const parsed = ClipboardHistoryModel.parseListOutput("abc\tnope\n42\tok");

        compare(parsed.length, 1);
        compare(parsed[0].id, "42");
    }

    function test_searchEntries_matches_preview_and_sets_history_action() {
        const results = ClipboardHistoryModel.searchEntries([
            {
                id: "330",
                preview: "project architecture plan"
            },
            {
                id: "329",
                preview: "other"
            }
        ], "arch", 10);

        verify(results.length >= 1);
        compare(results[0].provider, "clipboard");
        compare(results[0].action.type, "clipboard.copy_history_entry");
        compare(results[0].action.targetId, "330");
    }

    function test_searchEntries_returns_empty_for_blank_query() {
        const results = ClipboardHistoryModel.searchEntries([
            {
                id: "330",
                preview: "project architecture plan"
            }
        ], "", 10);

        compare(results.length, 0);
    }

    name: "ClipboardHistoryModelSlice"
}
