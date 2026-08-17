#!/usr/bin/env bash
set -euo pipefail

# Run the Lower Town load contract from a detached Git worktree so unrelated
# working-tree edits and generated .godot state cannot hide a broken checkout.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
FILTER="test_lower_town_slice_map,test_map_view_3d_core,test_map_view_3d_mesh,test_map_view_3d_runtime"
SOURCE_REV="$(git -C "$ROOT" rev-parse --verify HEAD)"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/reval-clean-checkout-load.XXXXXX")"
CHECKOUT="$TEMP_ROOT/checkout"
LOG_DIR="${GODOT_LOG_DIR:-$TEMP_ROOT/logs}"
CURRENT_STAGE="setup"
WORKTREE_ADDED=false

cleanup() {
	local status=$?
	if [[ "$WORKTREE_ADDED" == true ]]; then
		git -C "$ROOT" worktree remove --force "$CHECKOUT" >/dev/null 2>&1 || rm -rf "$CHECKOUT"
	fi
	rm -rf "$TEMP_ROOT"
	if [[ "$status" -ne 0 ]]; then
		echo "Clean-checkout load gate failed during: $CURRENT_STAGE" >&2
	fi
	exit "$status"
}
trap cleanup EXIT

run_stage() {
	local stage="$1"
	shift
	CURRENT_STAGE="$stage"
	echo "[clean-checkout-load] $stage"
	"$@"
}

mkdir -p "$LOG_DIR"
run_stage "create detached clean checkout at $SOURCE_REV" \
	git -C "$ROOT" worktree add --detach "$CHECKOUT" "$SOURCE_REV"
WORKTREE_ADDED=true

# CI starts from LFS pointers. Materialize only runtime inputs required by the
# import and MapView3D tests; the repository-owned helper also verifies hashes.
run_stage "restore runtime Git LFS assets" \
	"$CHECKOUT/tools/restore_lfs_assets.sh" runtime

# The checked runner rejects parser/load/resource diagnostics and requires the
# harness summary, while retaining only the documented DEF-002 shutdown noise.
run_stage "import clean checkout" \
env GODOT_LOG_DIR="$LOG_DIR" "$CHECKOUT/tools/run_godot_checked.sh" \
	clean-checkout-import -- "$GODOT_BIN" --headless --path "$CHECKOUT" --editor --import --quit

run_stage "load Lower Town and MapView3D dependencies" \
env GODOT_LOG_DIR="$LOG_DIR" "$CHECKOUT/tools/run_godot_checked.sh" \
	--require-test-summary clean-checkout-mapview -- "$GODOT_BIN" --headless \
	--path "$CHECKOUT" --script res://tools/run_godot_tests.gd -- \
	"--filter=$FILTER"

echo "Clean-checkout Lower Town load gate passed at $SOURCE_REV"
echo "Godot test filter: $FILTER"
