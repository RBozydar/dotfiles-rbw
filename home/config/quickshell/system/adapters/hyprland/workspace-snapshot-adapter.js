function screenAt(screens, index) {
    return screens[index];
}

function indexForScreen(screens, targetScreen) {
    for (let index = 0; index < screens.length; index += 1) {
        if (screens[index] === targetScreen) return index;
    }

    return -1;
}

function workspaceOccupancy(workspaces) {
    const occupancy = {};

    for (let index = 0; index < workspaces.length; index += 1) {
        const workspace = workspaces[index];
        const windowCount =
            workspace.lastIpcObject && workspace.lastIpcObject.windows
                ? Number(workspace.lastIpcObject.windows)
                : 0;

        occupancy[workspace.id] = windowCount > 0;
    }

    return occupancy;
}

function screenKeyForScreen(screen, hyprland, fallbackIndex) {
    const monitor = hyprland.monitorFor(screen);

    if (monitor && monitor.name) return String(monitor.name);
    if (screen && screen.name) return String(screen.name);
    if (Number.isFinite(fallbackIndex) && fallbackIndex >= 0)
        return "unknown-screen-" + String(fallbackIndex);

    return "unknown-screen";
}

function createSnapshotForScreen(screen, hyprland, fallbackIndex) {
    const monitor = hyprland.monitorFor(screen);
    const workspaces = hyprland.workspaces.values;
    const occupancy = workspaceOccupancy(workspaces);
    const items = [];

    for (let workspaceId = 1; workspaceId <= 10; workspaceId += 1) {
        items.push({
            id: workspaceId,
            occupied: occupancy[workspaceId] === true,
        });
    }

    return {
        kind: "compositor.workspace_snapshot",
        screenKey: screenKeyForScreen(screen, hyprland, fallbackIndex),
        activeWorkspaceId:
            monitor && monitor.activeWorkspace
                ? Number(monitor.activeWorkspace.id)
                : Number(
                      hyprland.focusedWorkspace && hyprland.focusedWorkspace.id
                          ? hyprland.focusedWorkspace.id
                          : 1,
                  ),
        specialWorkspaceOpen: Boolean(
            monitor &&
            monitor.lastIpcObject &&
            monitor.lastIpcObject.specialWorkspace &&
            monitor.lastIpcObject.specialWorkspace.name,
        ),
        workspaces: items,
    };
}

function createSnapshotsForScreens(screens, hyprland) {
    const snapshots = [];

    for (let index = 0; index < screens.length; index += 1)
        snapshots.push(createSnapshotForScreen(screenAt(screens, index), hyprland, index));

    return snapshots;
}

function dispatchFocusWorkspace(command, dispatchFn) {
    const screenKey = String(command.payload.screenKey || "");
    const workspaceId = String(command.payload.workspaceId);

    if (screenKey.length > 0) dispatchFn("focusmonitor " + screenKey);

    dispatchFn("focusworkspaceoncurrentmonitor " + workspaceId);
}
