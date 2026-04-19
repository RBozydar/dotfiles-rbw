function cloneWorkspaceItems(workspaces) {
    const next = [];

    for (let index = 0; index < workspaces.length; index += 1) next.push(workspaces[index]);

    return next;
}

function validateWorkspaceItem(item) {
    if (!item || typeof item !== "object") throw new Error("Workspace item must be an object");
    if (typeof item.id !== "number") throw new Error("Workspace item id must be a number");
    if (typeof item.occupied !== "boolean")
        throw new Error("Workspace item occupied must be a boolean");

    return item;
}

function validateWorkspaceSnapshot(snapshot) {
    if (!snapshot || typeof snapshot !== "object")
        throw new Error("Workspace snapshot must be an object");
    if (snapshot.kind !== "compositor.workspace_snapshot")
        throw new Error("Workspace snapshot kind must be compositor.workspace_snapshot");
    if (typeof snapshot.screenKey !== "string")
        throw new Error("Workspace snapshot screenKey must be a string");
    if (typeof snapshot.activeWorkspaceId !== "number")
        throw new Error("Workspace snapshot activeWorkspaceId must be a number");
    if (typeof snapshot.specialWorkspaceOpen !== "boolean")
        throw new Error("Workspace snapshot specialWorkspaceOpen must be a boolean");
    if (!Array.isArray(snapshot.workspaces))
        throw new Error("Workspace snapshot workspaces must be an array");

    for (let index = 0; index < snapshot.workspaces.length; index += 1)
        validateWorkspaceItem(snapshot.workspaces[index]);

    return snapshot;
}

function createWorkspaceSnapshot(fields) {
    const workspaces = [];

    for (let index = 0; index < fields.workspaces.length; index += 1)
        workspaces.push(validateWorkspaceItem(fields.workspaces[index]));

    return validateWorkspaceSnapshot({
        kind: "compositor.workspace_snapshot",
        screenKey: String(fields.screenKey),
        activeWorkspaceId: Number(fields.activeWorkspaceId),
        specialWorkspaceOpen: Boolean(fields.specialWorkspaceOpen),
        workspaces: cloneWorkspaceItems(workspaces),
    });
}

function validateFocusWorkspaceCommand(command) {
    if (!command || typeof command !== "object")
        throw new Error("Focus workspace command must be an object");
    if (command.type !== "compositor.focus_workspace")
        throw new Error("Focus workspace command type must be compositor.focus_workspace");
    if (!command.payload || typeof command.payload.screenKey !== "string")
        throw new Error("Focus workspace command payload.screenKey must be a string");
    if (typeof command.payload.workspaceId !== "number")
        throw new Error("Focus workspace command payload.workspaceId must be a number");

    return command;
}

function createFocusWorkspaceCommand(screenKey, workspaceId) {
    return validateFocusWorkspaceCommand({
        type: "compositor.focus_workspace",
        payload: {
            screenKey: String(screenKey),
            workspaceId: Number(workspaceId),
        },
    });
}
