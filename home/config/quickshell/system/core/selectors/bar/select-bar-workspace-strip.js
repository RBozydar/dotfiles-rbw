function workspaceMapForSnapshot(snapshot) {
    const occupancy = {};

    if (!snapshot || !snapshot.workspaces) return occupancy;

    for (let index = 0; index < snapshot.workspaces.length; index += 1) {
        const workspace = snapshot.workspaces[index];
        occupancy[workspace.id] = workspace.occupied;
    }

    return occupancy;
}

function selectBarWorkspaceStrip(state, screenKey, workspaceCount) {
    const count = workspaceCount === undefined ? 10 : Number(workspaceCount);
    const snapshot = state && state.screens ? state.screens[screenKey] : null;
    const occupancy = workspaceMapForSnapshot(snapshot);
    const activeWorkspaceId = snapshot ? snapshot.activeWorkspaceId : 1;
    const buttons = [];

    for (let workspaceId = 1; workspaceId <= count; workspaceId += 1) {
        buttons.push({
            id: workspaceId,
            label: String(workspaceId),
            active: activeWorkspaceId === workspaceId,
            occupied: occupancy[workspaceId] === true,
        });
    }

    return {
        screenKey: screenKey === undefined ? "" : String(screenKey),
        activeWorkspaceId: activeWorkspaceId,
        specialWorkspaceOpen: snapshot ? snapshot.specialWorkspaceOpen : false,
        buttons: buttons,
    };
}
