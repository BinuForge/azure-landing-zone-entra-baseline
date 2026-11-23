#!/usr/bin/env bash
# Downloads an evidence pack from an evidence.yml or gateway-tests.yml run, verifies every file's attestation, and stages it
# under evidence/<label>/ on a new branch. Run locally; then commit and open a pull request.
#
#   bash .github/scripts/pull-evidence.sh <run-id> <label> [workflow file, default evidence.yml]
set -euo pipefail

RUN_ID="${1:?run id of the evidence workflow}"
LABEL="${2:?label used for that run}"
WORKFLOW="${3:-evidence.yml}"
REPO="${REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
DEST="evidence/$LABEL"

if [ -e "$DEST" ]; then
  echo "$DEST already exists." >&2
  exit 1
fi

git switch -c "evidence/$LABEL"
gh run download "$RUN_ID" --repo "$REPO" --name "evidence-$LABEL" --dir "$DEST"

# Each file must have been produced by this repository's evidence workflow, unchanged.
for file in "$DEST"/*; do
  gh attestation verify "$file" --repo "$REPO" \
    --signer-workflow "$REPO/.github/workflows/$WORKFLOW" > /dev/null
  echo "verified $file"
done

git add "$DEST"
echo
echo "Staged $DEST. Next: git commit -m \"docs(evidence): add $LABEL\", push, and open a pull request."
