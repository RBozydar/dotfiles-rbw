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

    name: "LauncherScoringPolicySlice"
}
