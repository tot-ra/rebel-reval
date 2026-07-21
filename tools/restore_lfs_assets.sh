#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCOPE="${1:-runtime}"
REMOTE="${LFS_REMOTE:-origin}"

case "$SCOPE" in
  runtime|archive|research|narrative|all) ;;
  *)
    echo "Usage: $0 [runtime|archive|research|narrative|all]" >&2
    exit 2
    ;;
esac

if ! command -v git-lfs >/dev/null 2>&1 && ! git lfs version >/dev/null 2>&1; then
  echo "Git LFS is required. Install it, then run: git lfs install" >&2
  exit 1
fi

git -C "$ROOT_DIR" lfs install --local >/dev/null
include_paths="$(python3 "$ROOT_DIR/tools/manage_lfs_assets.py" paths \
  --root "$ROOT_DIR" --scope "$SCOPE" --separator comma)"
if [[ -z "$include_paths" ]]; then
  echo "No Git LFS objects are registered for scope: $SCOPE"
  exit 0
fi

# Command-line includes intentionally override .lfsconfig, whose default skips
# inactive corpora so normal clones only download runtime inputs.
git -C "$ROOT_DIR" lfs pull "$REMOTE" --include="$include_paths" --exclude=""
python3 "$ROOT_DIR/tools/manage_lfs_assets.py" verify \
  --root "$ROOT_DIR" --scope "$SCOPE" --require-materialized
