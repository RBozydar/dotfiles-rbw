function copyDefinedFields(source) {
    const copy = {};

    if (!source) return copy;

    for (const key in source) {
        if (source[key] !== undefined) copy[key] = source[key];
    }

    return copy;
}

function validateOutcomeStatus(status) {
    const allowed = {
        applied: true,
        noop: true,
        stale: true,
        rejected: true,
        failed: true,
    };

    if (!allowed[status]) throw new Error("Unknown operation outcome status: " + String(status));
}

function validateOperationOutcome(outcome) {
    if (!outcome || typeof outcome !== "object")
        throw new Error("Operation outcome must be an object");

    validateOutcomeStatus(outcome.status);

    if (outcome.code !== undefined && typeof outcome.code !== "string")
        throw new Error("Operation outcome code must be a string");
    if (outcome.reason !== undefined && typeof outcome.reason !== "string")
        throw new Error("Operation outcome reason must be a string");
    if (outcome.targetId !== undefined && typeof outcome.targetId !== "string")
        throw new Error("Operation outcome targetId must be a string");
    if (outcome.generation !== undefined && typeof outcome.generation !== "number")
        throw new Error("Operation outcome generation must be a number");
    if (outcome.meta !== undefined && typeof outcome.meta !== "object")
        throw new Error("Operation outcome meta must be an object");

    return outcome;
}

function createOperationOutcome(status, details) {
    const outcome = copyDefinedFields(details);
    outcome.status = status;
    return validateOperationOutcome(outcome);
}

function applied(details) {
    return createOperationOutcome("applied", details);
}

function noop(details) {
    return createOperationOutcome("noop", details);
}

function stale(details) {
    return createOperationOutcome("stale", details);
}

function rejected(details) {
    return createOperationOutcome("rejected", details);
}

function failed(details) {
    return createOperationOutcome("failed", details);
}
