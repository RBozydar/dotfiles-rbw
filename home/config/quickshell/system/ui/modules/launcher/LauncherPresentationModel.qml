import "../../../core/selectors/launcher/select-launcher-sections.js" as LauncherSelectors
import QtQml

QtObject {
    id: root

    required property var store
    property int highlightedIndex: 0
    readonly property var sections: LauncherSelectors.selectLauncherSections(store ? store.state.results : [], 6)
    readonly property int totalItemCount: LauncherSelectors.countLauncherItems(sections)

    function resetSurfaceState() {
        highlightedIndex = 0;
    }

    function moveHighlight(delta) {
        if (totalItemCount <= 0) {
            highlightedIndex = 0;
            return;
        }
        const nextIndex = highlightedIndex + Number(delta);
        if (nextIndex < 0)
            highlightedIndex = 0;
        else if (nextIndex >= totalItemCount)
            highlightedIndex = totalItemCount - 1;
        else
            highlightedIndex = nextIndex;
    }
}
