import "../system/adapters/search/wallpaper-catalog-model.js" as WallpaperCatalogModel
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function test_parseFindOutput_collects_non_empty_lines() {
        const parsed = WallpaperCatalogModel.parseFindOutput("/home/rbw/Pictures/wallpapers/sunrise.png\n\n/usr/share/wallpapers/city.jpg\n");

        compare(parsed.length, 2);
        compare(parsed[0], "/home/rbw/Pictures/wallpapers/sunrise.png");
        compare(parsed[1], "/usr/share/wallpapers/city.jpg");
    }

    function test_normalizeEntries_filters_non_images_and_deduplicates() {
        const normalized = WallpaperCatalogModel.normalizeEntries(["/home/rbw/Pictures/wallpapers/sunrise.png", "/home/rbw/Pictures/wallpapers/sunrise.png", "/home/rbw/Pictures/wallpapers/readme.txt", "/home/rbw/Pictures/Wallpapers/night-sky.webp"], 20);

        compare(normalized.length, 2);
        compare(normalized[0].path, "/home/rbw/Pictures/Wallpapers/night-sky.webp");
        compare(normalized[1].path, "/home/rbw/Pictures/wallpapers/sunrise.png");
        compare(normalized[1].title, "sunrise");
    }

    function test_searchEntries_returns_dispatchable_wallpaper_action() {
        const entries = WallpaperCatalogModel.normalizeEntries(["/home/rbw/Pictures/wallpapers/sunrise.png", "/home/rbw/Pictures/wallpapers/evening.jpg"], 20);
        const results = WallpaperCatalogModel.searchEntries(entries, "sun", 10);

        verify(results.length >= 1);
        compare(results[0].provider, "wallpaper");
        compare(results[0].action.type, "shell.ipc.dispatch");
        compare(results[0].action.command, "wallpaper.set");
        compare(results[0].action.args[0], "/home/rbw/Pictures/wallpapers/sunrise.png");
    }

    function test_searchEntries_returns_empty_for_blank_query() {
        const entries = WallpaperCatalogModel.normalizeEntries(["/home/rbw/Pictures/wallpapers/sunrise.png"], 20);
        const results = WallpaperCatalogModel.searchEntries(entries, "", 10);

        compare(results.length, 0);
    }

    name: "WallpaperCatalogModelSlice"
}
