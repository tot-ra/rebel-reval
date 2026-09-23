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
PYTHON_MODULES_FILE="$(mktemp)"
trap 'rm -f "$STAGED_FILE" "$PYTHON_MODULES_FILE"' EXIT

if [[ "$MODE" == "staged" ]]; then
  git diff --cached --name-only --diff-filter=ACMR >"$STAGED_FILE"
  if [[ ! -s "$STAGED_FILE" ]]; then
    echo "No staged files; nothing to check."
    exit 0
  fi
else
  git ls-files >"$STAGED_FILE"
fi

STAGED_PATHS=()
while IFS= read -r path; do
  STAGED_PATHS+=("$path")
done <"$STAGED_FILE"

# Return 0 when any staged path equals a candidate or lives under a candidate prefix.
any_staged_path() {
  local candidate path
  for candidate in "$@"; do
    for path in "${STAGED_PATHS[@]}"; do
      if [[ "$path" == "$candidate" || "$path" == "$candidate"/* ]]; then
        return 0
      fi
    done
  done
  return 1
}

run_step() {
  local label="$1"
  shift
  echo "==> $label"
  "$@"
}

# Prefer GODOT_BIN, then PATH, then the standard macOS editor app. The map and
# focused Godot gates used to require `godot` on PATH, which silently skipped
# validation on typical macOS checkouts.
resolve_godot() {
  if [[ -n "${GODOT_BIN:-}" && -x "${GODOT_BIN}" ]]; then
    printf '%s\n' "$GODOT_BIN"
    return 0
  fi
  if command -v godot >/dev/null 2>&1; then
    command -v godot
    return 0
  fi
  if [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
    printf '%s\n' /Applications/Godot.app/Contents/MacOS/Godot
    return 0
  fi
  return 1
}

queue_python_module() {
  local module="$1"
  printf '%s\n' "$module" >>"$PYTHON_MODULES_FILE"
}

# Map a staged path onto its conventional unittest module when one exists.
# tools/foo.py and tools/a/foo.py both resolve to tests.python.test_foo.
queue_python_module_for_path() {
  local path="$1"
  local base module_file
  case "$path" in
    tests/python/test_*.py)
      queue_python_module "tests.python.$(basename "$path" .py)"
      ;;
    tools/*.py|tools/*/*.py)
      base="$(basename "$path" .py)"
      module_file="tests/python/test_${base}.py"
      if [[ -f "$module_file" ]]; then
        queue_python_module "tests.python.test_${base}"
      fi
      ;;
  esac
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
if any_staged_path ".godot-version" "project.godot" "export_presets.cfg" \
  "tests/python/test_project_configuration.py"; then
  run_step "Godot version pin parity" bash -c '
    set -euo pipefail
    test "$(cat .godot-version)" = "4.7"
    grep -F "config/features=PackedStringArray(\"4.7\", \"GL Compatibility\")" project.godot >/dev/null
    grep -F "config/icon=\"res://scenes/menu/logo256.png\"" project.godot >/dev/null
    grep -F "application/icon=\"res://scenes/menu/logo256.png\"" export_presets.cfg >/dev/null
    grep -F "application/bundle_identifier=\"com.revalrebel.game\"" export_presets.cfg >/dev/null
  '
  queue_python_module "tests.python.test_project_configuration"
fi

if any_staged_path "export_presets.cfg" \
  "docs/data/shipped_resource_manifest.json" \
  "tools/verify_shipped_resources.py" \
  "tools/pck_inventory.py" \
  "tests/python/test_verify_shipped_resources.py"; then
  queue_python_module "tests.python.test_verify_shipped_resources"
  run_step "shipped resource verifier" python3 tools/verify_shipped_resources.py --check
fi

if any_staged_path "tools/run_pre_commit_checks.sh" \
  "tools/install_git_hooks.sh" \
  "tools/git-hooks" \
  ".pre-commit-config.yaml" \
  "tests/python/test_pre_commit_hooks.py"; then
  queue_python_module "tests.python.test_pre_commit_hooks"
fi

if any_staged_path "test_commands.sh" \
  "tools/run_performance_report.sh" \
  "tests/python/test_test_commands.py"; then
  queue_python_module "tests.python.test_test_commands"
fi

if any_staged_path "content/saves" \
  "tests/python/test_campaign_save_fixtures.py"; then
  queue_python_module "tests.python.test_campaign_save_fixtures"
fi

if any_staged_path "tools/verify_clean_checkout_load.sh" \
  "tests/python/test_verify_clean_checkout_load.py"; then
  queue_python_module "tests.python.test_verify_clean_checkout_load"
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
  queue_python_module "tests.python.test_validate_content"
  run_step "content example corpus" \
    python3 tools/validate_content.py content/examples/valid content/examples/support
  if any_staged_path "content/demo"; then
    run_step "demo content corpus" \
      python3 tools/validate_content.py content/demo content/examples/support content/examples/valid
  fi
fi

if any_staged_path "assets/SOURCES.csv" \
  "tools/validate_asset_sources.py" \
  "tools/verify_asset_lint.py" \
  "tools/verify_storage_hygiene.py" \
  "docs/storage_binary_exceptions.json" \
  "docs/lfs_assets.json"; then
  run_step "asset provenance manifest" python3 tools/validate_asset_sources.py
  run_step "storage hygiene" python3 tools/verify_storage_hygiene.py
  run_step "asset lint" python3 tools/verify_asset_lint.py
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
  GODOT_BIN_RESOLVED=""
  if GODOT_BIN_RESOLVED="$(resolve_godot)"; then
    run_step "map blueprint validation" \
      "$GODOT_BIN_RESOLVED" --headless --path . --script tools/validate_map_blueprints.gd
  else
    echo "godot not on PATH and GODOT_BIN unset; skipping map blueprint headless validation." >&2
    echo "Map changes still require the AGENTS.md pre-commit map gate before push." >&2
  fi
  run_step "map audit" python3 tools/verify_map_audit.py
  run_step "map activation" python3 tools/verify_map_activation.py
  run_step "map conversion plan" python3 tools/verify_map_conversion_plan.py
fi

# Path-matched Python tests only in staged mode. Walking every tracked file in
# `all` mode would collect live-inventory modules that still fail on baseline
# scene or fingerprint drift; keep those in dedicated CI/manual jobs.
if [[ "$MODE" == "staged" ]]; then
  for path in "${STAGED_PATHS[@]}"; do
    queue_python_module_for_path "$path"
  done
fi

if [[ -s "$PYTHON_MODULES_FILE" ]]; then
  PYTHON_MODULES=()
  while IFS= read -r module; do
    [[ -n "$module" ]] || continue
    PYTHON_MODULES+=("$module")
  done < <(sort -u "$PYTHON_MODULES_FILE")
  if [[ ${#PYTHON_MODULES[@]} -gt 0 ]]; then
    run_step "path-aware Python unit tests (${#PYTHON_MODULES[@]} module(s))" \
      python3 -m unittest "${PYTHON_MODULES[@]}" -v
  fi
fi

# When the only staged GDScript files are Godot harness tests, run that focused
# filter instead of waiting for PRE_COMMIT_FULL or CI.
if [[ ${#GD_FILES[@]} -gt 0 ]]; then
  FOCUSED_STEMS=()
  ONLY_GODOT_TESTS=1
  for path in "${GD_FILES[@]}"; do
    case "$path" in
      tests/godot/test_*.gd)
        FOCUSED_STEMS+=("$(basename "$path" .gd)")
        ;;
      *)
        ONLY_GODOT_TESTS=0
        ;;
    esac
  done
  if [[ "$ONLY_GODOT_TESTS" -eq 1 && ${#FOCUSED_STEMS[@]} -gt 0 ]]; then
    if GODOT_BIN_RESOLVED="$(resolve_godot)"; then
      FOCUSED_FILTER="$(IFS=','; echo "${FOCUSED_STEMS[*]}")"
      run_step "focused Godot tests ($FOCUSED_FILTER)" \
        tools/run_godot_checked.sh --require-test-summary pre-commit-focused \
        "$GODOT_BIN_RESOLVED" --headless --script tools/run_godot_tests.gd -- \
        "--filter=$FOCUSED_FILTER"
    else
      echo "godot not available; skipping focused Godot tests for staged tests/godot files." >&2
    fi
  fi
fi

if [[ "${PRE_COMMIT_FULL:-}" == "1" ]]; then
  if ! GODOT_BIN_RESOLVED="$(resolve_godot)"; then
    echo "PRE_COMMIT_FULL=1 requires godot on PATH, GODOT_BIN, or the macOS Godot.app." >&2
    exit 1
  fi
  run_step "full Godot headless suite" \
    tools/run_godot_checked.sh --require-test-summary full-suite \
    "$GODOT_BIN_RESOLVED" --headless --script tools/run_godot_tests.gd
fi

echo "On-commit checks passed."
