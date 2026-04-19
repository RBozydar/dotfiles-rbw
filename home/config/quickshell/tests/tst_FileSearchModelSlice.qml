import "../system/adapters/search/file-search-model.js" as FileSearchModel
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function test_parseFdOutput_parses_and_deduplicates_paths() {
        const parsed = FileSearchModel.parseFdOutput("/home/rbw/repo/docs/todo.md\n/home/rbw/repo/src/main.cpp\n/home/rbw/repo/docs/todo.md\n");

        compare(parsed.length, 2);
        compare(parsed[0].path, "/home/rbw/repo/docs/todo.md");
        compare(parsed[1].name, "main.cpp");
    }

    function test_searchEntries_matches_paths_and_sets_file_open_action() {
        const results = FileSearchModel.searchEntries(["/home/rbw/repo/docs/architecture.md", "/home/rbw/repo/src/main.cpp"], "arch", 10);

        verify(results.length >= 1);
        compare(results[0].provider, "files");
        compare(results[0].action.type, "file.open");
        compare(results[0].action.targetId, "/home/rbw/repo/docs/architecture.md");
    }

    function test_searchEntries_returns_empty_for_blank_query() {
        const results = FileSearchModel.searchEntries(["/home/rbw/repo/docs/architecture.md"], "", 10);

        compare(results.length, 0);
    }

    name: "FileSearchModelSlice"
}
