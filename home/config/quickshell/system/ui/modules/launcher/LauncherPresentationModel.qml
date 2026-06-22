import "../../../core/selectors/launcher/select-launcher-sections.js" as LauncherSelectors
import QtQml

QtObject {
    id: root

    required property var launcherState
    required property int stateRevision
    property int highlightedIndex: 0
    readonly property var sections: {
        const _stateRevision = stateRevision;
        const results = launcherState && Array.isArray(launcherState.results) ? launcherState.results : [];
        return LauncherSelectors.selectLauncherSections(results, 6);
    }
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
