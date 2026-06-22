#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(dirname "$script_dir")
latest_review="$root_dir/.review/latest.json"
evidence_path="$root_dir/.review/evidence/codex-secondary.json"
reviewer="Codex local evidence refresh"
model="codex-local-refresh"
status="pass-with-risks"
summary="Refreshed secondary review evidence to match the current diff fingerprint."

usage() {
	printf '%s\n' "usage: $(basename "$0") [--evidence <path>] [--reviewer <name>] [--model <name>] [--status <pass|pass-with-risks|blocker>] [--summary <text>]" >&2
}

while [ "$#" -gt 0 ]; do
	case "$1" in
	--evidence)
		shift
		[ "$#" -gt 0 ] || {
			usage
			exit 1
		}
		evidence_path=$1
		;;
	--reviewer)
		shift
		[ "$#" -gt 0 ] || {
			usage
			exit 1
		}
		reviewer=$1
		;;
	--model)
		shift
		[ "$#" -gt 0 ] || {
			usage
			exit 1
		}
		model=$1
		;;
	--status)
		shift
		[ "$#" -gt 0 ] || {
			usage
			exit 1
		}
		status=$1
		;;
	--summary)
		shift
		[ "$#" -gt 0 ] || {
			usage
			exit 1
		}
		summary=$1
		;;
	--help | -h)
		usage
		exit 0
		;;
	*)
		usage
		exit 1
		;;
	esac
	shift
done

case "$status" in
pass | pass-with-risks | blocker)
	;;
*)
	printf '%s\n' "refresh-review-evidence: invalid status '$status'" >&2
	exit 1
	;;
esac

if ! command -v node >/dev/null 2>&1; then
	printf '%s\n' "refresh-review-evidence: node is required" >&2
	exit 1
fi

mkdir -p "$(dirname "$evidence_path")"

printf '%s\n' "refresh-review-evidence: generating latest review fingerprint"
"$script_dir/review.sh" --classify-only >/dev/null

if [ ! -f "$latest_review" ]; then
	printf '%s\n' "refresh-review-evidence: missing $latest_review" >&2
	exit 1
fi

LATEST_REVIEW="$latest_review" \
	EVIDENCE_PATH="$evidence_path" \
	REVIEWER_NAME="$reviewer" \
	MODEL_NAME="$model" \
	REVIEW_STATUS="$status" \
	REVIEW_SUMMARY="$summary" \
	node <<'EOF'
const fs = require("node:fs");
const path = require("node:path");

const latestReviewPath = process.env.LATEST_REVIEW;
const evidencePath = process.env.EVIDENCE_PATH;
const reviewer = process.env.REVIEWER_NAME;
const model = process.env.MODEL_NAME;
const status = process.env.REVIEW_STATUS;
const summary = process.env.REVIEW_SUMMARY;

const latest = JSON.parse(fs.readFileSync(latestReviewPath, "utf8"));
if (!latest.changeFingerprint || typeof latest.changeFingerprint !== "string") {
    throw new Error("latest review is missing a valid changeFingerprint");
}

const payload = {
    reviewer,
    model,
    reviewedAt: new Date().toISOString(),
    summary,
    changeFingerprint: latest.changeFingerprint,
    status,
};

fs.mkdirSync(path.dirname(evidencePath), { recursive: true });
fs.writeFileSync(evidencePath, JSON.stringify(payload, null, 2) + "\n");
console.log("refresh-review-evidence: wrote " + evidencePath);
console.log("refresh-review-evidence: fingerprint " + latest.changeFingerprint);
EOF
