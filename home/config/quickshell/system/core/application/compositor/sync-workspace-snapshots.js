function syncWorkspaceSnapshots(deps, store, snapshots) {
    const validatedSnapshots = [];

    for (let index = 0; index < snapshots.length; index += 1)
        validatedSnapshots.push(deps.validateWorkspaceSnapshot(snapshots[index]));

    const outcome = deps.outcomes.applied({
        code: "compositor.workspace_snapshot_applied",
        targetId: "compositor.workspace_snapshot",
        meta: {
            screenCount: validatedSnapshots.length,
        },
    });

    store.applySnapshots(validatedSnapshots, outcome);
    return outcome;
}

function focusWorkspace(deps, command) {
    deps.validateFocusWorkspaceCommand(command);
    deps.dispatchFocusWorkspace(command);

    return deps.outcomes.applied({
        code: "compositor.focus_workspace_dispatched",
        targetId: command.payload.screenKey,
        meta: {
            workspaceId: command.payload.workspaceId,
        },
    });
}
