import "../system/adapters/search/emoji-catalog-model.js" as EmojiCatalogModel
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function sampleCatalog() {
        return [
            {
                emoji: "😀",
                description: "grinning face",
                category: "Smileys & Emotion",
                aliases: ["grinning"],
                tags: ["smile", "happy"]
            },
            {
                emoji: "🚀",
                description: "rocket",
                category: "Travel & Places",
                aliases: ["rocket"],
                tags: ["ship", "launch"]
            }
        ];
    }

    function test_parseEmojiCatalogJson_returns_empty_for_invalid_json() {
        const parsed = EmojiCatalogModel.parseEmojiCatalogJson("{invalid");

        verify(Array.isArray(parsed));
        compare(parsed.length, 0);
    }

    function test_normalizeEmojiEntries_deduplicates_ids() {
        const normalized = EmojiCatalogModel.normalizeEmojiEntries([
            {
                emoji: "😀",
                description: "grinning face",
                aliases: ["grinning"]
            },
            {
                emoji: "😀",
                description: "grinning duplicate",
                aliases: ["grinning"]
            }
        ]);

        compare(normalized.length, 1);
        compare(normalized[0].emoji, "😀");
    }

    function test_searchEmojiEntries_matches_alias_and_sets_copy_action() {
        const results = EmojiCatalogModel.searchEmojiEntries(sampleCatalog(), "grin", 10);

        verify(results.length >= 1);
        compare(results[0].provider, "emoji");
        compare(results[0].action.type, "clipboard.copy_text");
        compare(results[0].action.targetId, "😀");
    }

    function test_searchEmojiEntries_supports_colon_prefixed_query() {
        const results = EmojiCatalogModel.searchEmojiEntries(sampleCatalog(), ":rocket", 10);

        verify(results.length >= 1);
        compare(results[0].action.targetId, "🚀");
    }

    name: "EmojiCatalogModelSlice"
}
