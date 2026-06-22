import "../system/core/policies/launcher/launcher-scoring-policy.js" as LauncherScoringPolicy
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function createItem(id, title, score) {
        return {
            id: id,
            title: title,
            subtitle: "",
            detail: "",
            iconName: "",
            provider: "apps",
            score: score,
            action: {
                type: "app.launch",
                targetId: "sample.desktop"
            }
        };
    }

    function test_scoreLauncherItems_preserves_text_match_priority() {
        const items = [createItem("app:firefox.desktop", "Firefox", 100), createItem("app:files.desktop", "Files", 120)];
        const scored = LauncherScoringPolicy.scoreLauncherItems(items, "fire", {
            nowIso: "2026-04-17T12:00:00.000Z"
        });

        compare(scored.length, 2);
        compare(scored[0].id, "app:firefox.desktop");
        verify(scored[0].scoreMeta.queryTitleBoost > 0);
    }

    function test_scoreLauncherItems_applies_usage_signal_boosts() {
        const items = [createItem("app:wezterm.desktop", "WezTerm", 100), createItem("app:kitty.desktop", "Kitty", 100)];
        const scored = LauncherScoringPolicy.scoreLauncherItems(items, "", {
            nowIso: "2026-04-17T12:00:00.000Z",
            usageByItemId: {
                "app:kitty.desktop": {
                    count: 3,
                    lastUsedAt: "2026-04-17T11:30:00.000Z"
                }
            }
        });

        compare(scored.length, 2);
        compare(scored[0].id, "app:kitty.desktop");
        verify(scored[0].scoreMeta.usageFrequencyBoost > 0);
        verify(scored[0].scoreMeta.usageRecencyBoost > 0);
        compare(scored[1].scoreMeta.usageFrequencyBoost, 0);
    }

    function test_scoreLauncherItems_can_disable_personalization_boosts() {
        const items = [createItem("app:wezterm.desktop", "WezTerm", 100)];
        const scored = LauncherScoringPolicy.scoreLauncherItems(items, "", {
            nowIso: "2026-04-17T12:00:00.000Z",
            personalizationEnabled: false,
            usageByItemId: {
                "app:wezterm.desktop": {
                    count: 8,
                    lastUsedAt: "2026-04-17T11:30:00.000Z"
                }
            }
        });

        compare(scored.length, 1);
        compare(scored[0].scoreMeta.personalizationEnabled, false);
        compare(scored[0].scoreMeta.usageFrequencyBoost, 0);
        compare(scored[0].scoreMeta.usageRecencyBoost, 0);
        compare(scored[0].score, 100);
    }

    function test_scoreLauncherItems_preserves_optional_display_metadata() {
        const item = createItem("app:firefox.desktop", "Firefox", 100);
        item.detail = "Web Browser";
        item.iconName = "firefox";

        const scored = LauncherScoringPolicy.scoreLauncherItems([item], "fire");

        compare(scored.length, 1);
        compare(scored[0].detail, "Web Browser");
        compare(scored[0].iconName, "firefox");
    }

    function test_scoreLauncherItems_preserves_pin_metadata() {
        const item = {
            id: "ipc:settings.reload",
            title: "settings.reload",
            subtitle: "Reload settings",
            provider: "commands",
            score: 400,
            pinned: true,
            pinOrder: 2,
            action: {
                type: "shell.ipc.dispatch",
                command: "settings.reload",
                args: []
            }
        };
        const scored = LauncherScoringPolicy.scoreLauncherItems([item], "set", {
            nowIso: "2026-04-20T12:00:00.000Z"
        });

        compare(scored.length, 1);
        compare(scored[0].pinned, true);
        compare(scored[0].pinOrder, 2);
    }

    function test_scoreLauncherItems_prefers_exact_app_match_over_file_candidates() {
        const items = [
            {
                id: "file:/home/rbw/.config/mozilla/firefox",
                title: "firefox",
                subtitle: "/home/rbw/.config/mozilla",
                provider: "files",
                score: 1180,
                action: {
                    type: "file.open",
                    targetId: "/home/rbw/.config/mozilla/firefox"
                }
            },
            {
                id: "app:firefox.desktop",
                title: "Firefox",
                subtitle: "Web Browser",
                provider: "apps",
                score: 1060,
                action: {
                    type: "app.launch",
                    targetId: "firefox.desktop"
                }
            }
        ];
        const scored = LauncherScoringPolicy.scoreLauncherItems(items, "firefox", {
            nowIso: "2026-04-20T12:00:00.000Z"
        });

        compare(scored.length, 2);
        compare(scored[0].id, "app:firefox.desktop");
        verify(Number(scored[0].scoreMeta.providerIntentBoost) > 0);
        verify(Number(scored[1].scoreMeta.providerIntentBoost) < 0);
    }

    function test_scoreLauncherItems_prefers_files_for_path_like_queries() {
        const items = [
            {
                id: "file:/home/rbw/projects/readme.md",
                title: "readme.md",
                subtitle: "/home/rbw/projects",
                provider: "files",
                score: 300,
                action: {
                    type: "file.open",
                    targetId: "/home/rbw/projects/readme.md"
                }
            },
            {
                id: "app:readme.desktop",
                title: "Readme",
                subtitle: "Tool",
                provider: "apps",
                score: 300,
                action: {
                    type: "app.launch",
                    targetId: "readme.desktop"
                }
            }
        ];
        const scored = LauncherScoringPolicy.scoreLauncherItems(items, "/home/rbw/pro", {
            nowIso: "2026-04-20T12:00:00.000Z"
        });

        compare(scored.length, 2);
        compare(scored[0].provider, "files");
        verify(Number(scored[0].scoreMeta.providerIntentBoost) > 0);
    }

    name: "LauncherScoringPolicySlice"
}
