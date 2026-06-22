import "../system/core/application/integrations/wallpaper-workflow.js" as WallpaperWorkflowUseCases
import QtQuick 2.15
import QtTest 1.3

TestCase {
    name: "WallpaperWorkflowSlice"

    function test_appendWallpaperHistoryEntry_tracks_cursor_and_deduplicates_tail() {
        let state = WallpaperWorkflowUseCases.createWallpaperHistoryState({
            limit: 5
        });
        state = WallpaperWorkflowUseCases.appendWallpaperHistoryEntry(state, "/wallpapers/a.png", "wallpaper.set", "2026-04-19T10:00:00.000Z");
        state = WallpaperWorkflowUseCases.appendWallpaperHistoryEntry(state, "/wallpapers/a.png", "wallpaper.set", "2026-04-19T10:00:10.000Z");

        compare(state.entries.length, 1);
        compare(state.cursor, 0);
        compare(state.entries[0].path, "/wallpapers/a.png");
        compare(state.entries[0].at, "2026-04-19T10:00:10.000Z");
    }

    function test_appendWallpaperHistoryEntry_trims_forward_history_when_cursor_is_behind() {
        let state = WallpaperWorkflowUseCases.createWallpaperHistoryState({
            limit: 8
        });
        state = WallpaperWorkflowUseCases.appendWallpaperHistoryEntry(state, "/wallpapers/a.png", "set", "2026-04-19T10:00:00.000Z");
        state = WallpaperWorkflowUseCases.appendWallpaperHistoryEntry(state, "/wallpapers/b.png", "set", "2026-04-19T10:00:01.000Z");
        state = WallpaperWorkflowUseCases.appendWallpaperHistoryEntry(state, "/wallpapers/c.png", "set", "2026-04-19T10:00:02.000Z");
        state = WallpaperWorkflowUseCases.setWallpaperHistoryCursor(state, 1);
        state = WallpaperWorkflowUseCases.appendWallpaperHistoryEntry(state, "/wallpapers/d.png", "set", "2026-04-19T10:00:03.000Z");

        compare(state.entries.length, 3);
        compare(state.entries[0].path, "/wallpapers/a.png");
        compare(state.entries[1].path, "/wallpapers/b.png");
        compare(state.entries[2].path, "/wallpapers/d.png");
        compare(state.cursor, 2);
    }

    function test_peekWallpaperHistoryPrevious_and_next_follow_cursor() {
        let state = WallpaperWorkflowUseCases.createWallpaperHistoryState({
            entries: [
                {
                    path: "/wallpapers/a.png",
                    at: "2026-04-19T10:00:00.000Z",
                    source: "set"
                },
                {
                    path: "/wallpapers/b.png",
                    at: "2026-04-19T10:00:01.000Z",
                    source: "set"
                },
                {
                    path: "/wallpapers/c.png",
                    at: "2026-04-19T10:00:02.000Z",
                    source: "set"
                }
            ],
            cursor: 2,
            limit: 6
        });

        const previous = WallpaperWorkflowUseCases.peekWallpaperHistoryPrevious(state);
        compare(previous.movable, true);
        compare(previous.cursor, 1);
        compare(previous.path, "/wallpapers/b.png");

        state = WallpaperWorkflowUseCases.setWallpaperHistoryCursor(state, previous.cursor);

        const next = WallpaperWorkflowUseCases.peekWallpaperHistoryNext(state);
        compare(next.movable, true);
        compare(next.cursor, 2);
        compare(next.path, "/wallpapers/c.png");
    }

    function test_chooseRandomWallpaperPath_skips_current_when_multiple_candidates() {
        const catalogEntries = [
            {
                path: "/wallpapers/a.png"
            },
            {
                path: "/wallpapers/b.png"
            },
            {
                path: "/wallpapers/c.png"
            }
        ];

        const path = WallpaperWorkflowUseCases.chooseRandomWallpaperPath(catalogEntries, "/wallpapers/a.png", 0.0);
        verify(path !== "/wallpapers/a.png");
        verify(path === "/wallpapers/b.png" || path === "/wallpapers/c.png");
    }

    function test_describeWallpaperHistory_reports_navigation_flags() {
        const state = WallpaperWorkflowUseCases.createWallpaperHistoryState({
            entries: [
                {
                    path: "/wallpapers/a.png",
                    at: "2026-04-19T10:00:00.000Z",
                    source: "set"
                },
                {
                    path: "/wallpapers/b.png",
                    at: "2026-04-19T10:00:01.000Z",
                    source: "set"
                }
            ],
            cursor: 0,
            limit: 10
        });
        const snapshot = WallpaperWorkflowUseCases.describeWallpaperHistory(state, 10);

        compare(snapshot.kind, "wallpaper.workflow.history_snapshot");
        compare(snapshot.totalEntries, 2);
        compare(snapshot.cursor, 0);
        compare(snapshot.currentPath, "/wallpapers/a.png");
        compare(snapshot.hasPrevious, false);
        compare(snapshot.hasNext, true);
        compare(snapshot.entries.length, 2);
    }
}
