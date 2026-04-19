import "../../../core/selectors/bar/select-bar-workspace-strip.js" as BarSelectors
import QtQml

QtObject {
    id: root

    required property var bridge
    required property var screen
    readonly property int storeRevision: bridge ? bridge.storeRevision : 0
    readonly property string screenKey: bridge ? bridge.screenKey(screen) : ""
    readonly property var workspaceStrip: {
        const revision = storeRevision;
        return BarSelectors.selectBarWorkspaceStrip(bridge ? bridge.store.state : null, screenKey, 10);
    }

    function focusWorkspace(workspaceId) {
        if (!bridge)
            return;

        bridge.focusWorkspaceForScreen(screen, workspaceId);
    }
}
