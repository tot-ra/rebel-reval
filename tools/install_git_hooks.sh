#!/usr/bin/env bash
# Install repository on-commit checks into .git/hooks without disturbing Git LFS.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_SRC="$ROOT_DIR/tools/git-hooks/pre-commit"
HOOK_DST="$ROOT_DIR/.git/hooks/pre-commit"

if [[ ! -d "$ROOT_DIR/.git" ]]; then
  echo "Not a git checkout: $ROOT_DIR" >&2
  exit 1
fi

if [[ ! -f "$HOOK_SRC" ]]; then
  echo "Missing hook source: $HOOK_SRC" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/.git/hooks"

# Keep LFS hooks present first; they own post-* / pre-push. Install our
# pre-commit afterward so a future LFS hook set cannot clobber it.
if command -v git-lfs >/dev/null 2>&1 || git -C "$ROOT_DIR" lfs version >/dev/null 2>&1; then
  git -C "$ROOT_DIR" lfs install --local >/dev/null
fi

cp "$HOOK_SRC" "$HOOK_DST"
chmod +x "$HOOK_DST" "$ROOT_DIR/tools/run_pre_commit_checks.sh" "$HOOK_SRC"

# Ensure core.hooksPath is unset/default so .git/hooks is used. A custom hooksPath
# would hide both this pre-commit and the LFS hooks installed above.
if git -C "$ROOT_DIR" config --local --get core.hooksPath >/dev/null 2>&1; then
  echo "Warning: core.hooksPath is set locally; Git will not use .git/hooks/pre-commit." >&2
  echo "Unset it with: git config --local --unset core.hooksPath" >&2
fi

echo "Installed on-commit hook: .git/hooks/pre-commit"
echo "Manual run: tools/run_pre_commit_checks.sh staged"
echo "Bypass once: SKIP_PRE_COMMIT=1 git commit ..."
