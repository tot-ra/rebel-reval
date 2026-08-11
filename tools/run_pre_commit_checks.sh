#!/usr/bin/env bash
# Fast, path-aware gates that catch the CI failure classes most often introduced
# at commit time. Full Godot import/export/map suites stay manual / CI-only.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "${SKIP_PRE_COMMIT:-}" == "1" ]]; then
  echo "SKIP_PRE_COMMIT=1 set; skipping on-commit checks."
  exit 0
fi

MODE="${1:-staged}"
case "$MODE" in
  staged|all) ;;
  *)
    echo "Usage: $0 [staged|all]" >&2
    echo "Set SKIP_PRE_COMMIT=1 to bypass. Set PRE_COMMIT_FULL=1 to add heavier gates." >&2
    exit 2
    ;;
esac

STAGED_FILE="$(mktemp)"
trap 'rm -f "$STAGED_FILE"' EXIT

if [[ "$MODE" == "staged" ]]; then
  git diff --cached --name-only --diff-filter=ACMR >"$STAGED_FILE"
  if [[ ! -s "$STAGED_FILE" ]]; then
    echo "No staged files; nothing to check."
    exit 0
  fi
else
  git ls-files >"$STAGED_FILE"
fi

# Return 0 when any staged path equals a candidate or lives under a candidate prefix.
any_staged_path() {
  local candidate path
  for candidate in "$@"; do
    while IFS= read -r path; do
      if [[ "$path" == "$candidate" || "$path" == "$candidate"/* ]]; then
        return 0
      fi
    done <"$STAGED_FILE"
  done
  return 1
}

run_step() {
  local label="$1"
  shift
  echo "==> $label"
  "$@"
}

echo "Running on-commit checks (mode=$MODE)..."

# Whitespace / conflict markers on the commit payload (or whole tree in all mode).
if [[ "$MODE" == "staged" ]]; then
  run_step "staged whitespace (git diff --cached --check)" \
    git diff --cached --check
else
  run_step "tree whitespace (git diff --check)" \
    git diff --check
fi

# Cheap pin parity with CI's Godot version step when project metadata changes.
if any_staged_path ".godot-version" "project.godot" "export_presets.cfg"; then
  run_step "Godot version pin parity" bash -c '
    set -euo pipefail
    test "$(cat .godot-version)" = "4.7"
    grep -F "config/features=PackedStringArray(\"4.7\", \"GL Compatibility\")" project.godot >/dev/null
    grep -F "config/icon=\"res://scenes/menu/logo256.png\"" project.godot >/dev/null
    grep -F "application/icon=\"res://scenes/menu/logo256.png\"" export_presets.cfg >/dev/null
    grep -F "application/bundle_identifier=\"com.revalrebel.game\"" export_presets.cfg >/dev/null
  '
fi

GD_FILES=()
while IFS= read -r path; do
  case "$path" in
    *.gd) GD_FILES+=("$path") ;;
  esac
done <"$STAGED_FILE"

if [[ ${#GD_FILES[@]} -gt 0 ]]; then
  # Prefer the module entrypoint so user PATH does not need ~/Library/Python/.../bin.
  if python3 -c 'import gdtoolkit.linter' >/dev/null 2>&1; then
    run_step "gdlint staged GDScript (${#GD_FILES[@]} file(s))" \
      python3 -m gdtoolkit.linter "${GD_FILES[@]}"
  elif command -v gdlint >/dev/null 2>&1; then
    run_step "gdlint staged GDScript (${#GD_FILES[@]} file(s))" \
      gdlint "${GD_FILES[@]}"
  else
    echo "gdlint is required for staged .gd changes." >&2
    echo "Install with: python3 -m pip install --user 'gdtoolkit==4.5.0'" >&2
    exit 1
  fi
fi

if any_staged_path "content" \
  "tools/validate_content.py" \
  "tools/validate_content_examples.py" \
  "tests/python/test_validate_content.py"; then
  run_step "content schema examples" python3 tools/validate_content_examples.py
  run_step "content validator unit tests" \
    python3 -m unittest tests.python.test_validate_content -v
  run_step "content example corpus" \
    python3 tools/validate_content.py content/examples/valid content/examples/support
fi

if any_staged_path "assets/SOURCES.csv" \
  "tools/validate_asset_sources.py" \
  "tools/verify_asset_lint.py" \
  "tools/verify_storage_hygiene.py" \
  "docs/storage_binary_exceptions.json" \
  "docs/lfs_assets.json"; then
  run_step "asset provenance manifest" python3 tools/validate_asset_sources.py
  run_step "storage hygiene" python3 tools/verify_storage_hygiene.py
fi

# Active-doc check walks the live worktree. Trigger only on the report inputs /
# generator that CI treats as the contract, not on every docs/** edit, so an
# unrelated dirty report cannot block an otherwise scoped commit.
if any_staged_path "README.md" "AGENTS.md" "docs/CANON.md" \
  "docs/reports/active_markdown_report.md" \
  "tools/generate_active_docs_report.py"; then
  run_step "active Markdown links and canon" \
    python3 tools/generate_active_docs_report.py --check
fi

if any_staged_path "scripts/map" "content/maps" \
  "tools/run_map_pipeline_ci.sh" \
  "tools/validate_map_blueprints.gd" \
  "tools/verify_map_audit.py" \
  "tools/verify_map_activation.py" \
  "tools/verify_map_conversion_plan.py" \
  "docs/MAP_AUTHORING.md"; then
  if command -v godot >/dev/null 2>&1; then
    run_step "map blueprint validation" \
      godot --headless --path . --script tools/validate_map_blueprints.gd
  else
    echo "godot not on PATH; skipping map blueprint headless validation." >&2
    echo "Map changes still require the AGENTS.md pre-commit map gate before push." >&2
  fi
  run_step "map audit" python3 tools/verify_map_audit.py
  run_step "map activation" python3 tools/verify_map_activation.py
  run_step "map conversion plan" python3 tools/verify_map_conversion_plan.py
fi

if [[ "${PRE_COMMIT_FULL:-}" == "1" ]]; then
  if ! command -v godot >/dev/null 2>&1; then
    echo "PRE_COMMIT_FULL=1 requires godot on PATH." >&2
    exit 1
  fi
  run_step "full Godot headless suite" \
    tools/run_godot_checked.sh --require-test-summary full-suite \
    godot --headless --script tools/run_godot_tests.gd
fi

echo "On-commit checks passed."
