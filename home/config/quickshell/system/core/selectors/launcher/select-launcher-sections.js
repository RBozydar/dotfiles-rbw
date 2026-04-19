function selectLauncherSections(items, perSectionLimit) {
    const limit = perSectionLimit === undefined ? 6 : Number(perSectionLimit);
    const sectionsByProvider = {};
    const order = [];

    for (let index = 0; index < items.length; index += 1) {
        const item = items[index];
        const provider = item.provider;

        if (!sectionsByProvider[provider]) {
            sectionsByProvider[provider] = {
                id: provider,
                title: provider,
                items: [],
            };
            order.push(provider);
        }

        if (sectionsByProvider[provider].items.length < limit)
            sectionsByProvider[provider].items.push(item);
    }

    const sections = [];

    for (let index = 0; index < order.length; index += 1)
        sections.push(sectionsByProvider[order[index]]);

    return sections;
}

function countLauncherItems(sections) {
    let count = 0;

    for (let index = 0; index < sections.length; index += 1) count += sections[index].items.length;

    return count;
}
