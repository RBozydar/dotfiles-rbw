var exampleCatalog = [
    {
        desktopId: "foot.desktop",
        title: "Foot",
        subtitle: "Terminal emulator",
        provider: "apps",
        score: 120,
    },
    {
        desktopId: "org.gnome.Nautilus.desktop",
        title: "Files",
        subtitle: "File manager",
        provider: "apps",
        score: 90,
    },
    {
        desktopId: "firefox.desktop",
        title: "Firefox",
        subtitle: "Web browser",
        provider: "apps",
        score: 110,
    },
];

function matchesQuery(entry, query) {
    const normalizedQuery = String(query || "")
        .toLowerCase()
        .trim();

    if (!normalizedQuery) return true;

    return (
        entry.title.toLowerCase().indexOf(normalizedQuery) >= 0 ||
        entry.subtitle.toLowerCase().indexOf(normalizedQuery) >= 0
    );
}

function search(command) {
    const results = [];
    const query = command.payload.query;

    for (let index = 0; index < exampleCatalog.length; index += 1) {
        const entry = exampleCatalog[index];

        if (!matchesQuery(entry, query)) continue;

        results.push({
            id: "app:" + entry.desktopId,
            title: entry.title,
            subtitle: entry.subtitle,
            provider: entry.provider,
            score: entry.score,
            action: {
                type: "app.launch",
                targetId: entry.desktopId,
            },
        });
    }

    return results;
}
