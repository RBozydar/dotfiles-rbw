import "../system/adapters/search/desktop-app-catalog-model.js" as DesktopAppCatalogModel
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function sampleCatalog() {
        return [
            {
                desktopId: "firefox.desktop",
                name: "Firefox",
                iconName: "firefox",
                genericName: "Web Browser",
                comment: "Browse the web",
                exec: "firefox",
                keywords: ["browser", "web"],
                sourcePriority: 0
            },
            {
                desktopId: "org.gnome.Nautilus.desktop",
                name: "Files",
                iconName: "org.gnome.Nautilus",
                genericName: "File Manager",
                comment: "Browse files",
                exec: "nautilus --new-window",
                keywords: ["files", "folders"],
                sourcePriority: 1
            }
        ];
    }

    function test_parseCatalogJson_returns_empty_list_for_invalid_json() {
        const parsed = DesktopAppCatalogModel.parseCatalogJson("{invalid");

        verify(Array.isArray(parsed));
        compare(parsed.length, 0);
    }

    function test_normalizeCatalogEntries_deduplicates_by_desktop_id() {
        const normalized = DesktopAppCatalogModel.normalizeCatalogEntries([
            {
                desktopId: "firefox.desktop",
                name: "Firefox",
                exec: "firefox"
            },
            {
                desktopId: "firefox.desktop",
                name: "Firefox Duplicate",
                exec: "firefox"
            }
        ]);

        compare(normalized.length, 1);
        compare(normalized[0].name, "Firefox");
    }

    function test_searchCatalogEntries_matches_app_name_and_keywords() {
        const resultsByName = DesktopAppCatalogModel.searchCatalogEntries(sampleCatalog(), "fire");
        const resultsByKeyword = DesktopAppCatalogModel.searchCatalogEntries(sampleCatalog(), "folders");

        verify(resultsByName.length >= 1);
        compare(resultsByName[0].id, "app:firefox.desktop");
        compare(resultsByName[0].action.type, "app.launch");
        compare(resultsByName[0].iconName, "firefox");
        compare(resultsByName[0].detail, "Browse the web");

        verify(resultsByKeyword.length >= 1);
        compare(resultsByKeyword[0].id, "app:org.gnome.Nautilus.desktop");
    }

    function test_searchCatalogEntries_sorts_exact_match_first() {
        const results = DesktopAppCatalogModel.searchCatalogEntries(sampleCatalog(), "files");

        verify(results.length >= 1);
        compare(results[0].id, "app:org.gnome.Nautilus.desktop");
    }

    name: "DesktopAppCatalogModelSlice"
}
