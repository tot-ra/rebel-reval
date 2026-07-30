#!/usr/bin/env bash
# P4-044: accept the exact P4-013 Act 1 package without rewriting package inputs.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_PATH="$ROOT_DIR/docs/data/act1_release_manifest.json"
BUILD_DIR="$ROOT_DIR/build/act1"
DMG_PATH="$BUILD_DIR/rr.dmg"
APP_PATH="$BUILD_DIR/Reval Rebel.app"
FINGERPRINT_PATH="$BUILD_DIR/package_fingerprint.json"
SHA_SIDECAR="$BUILD_DIR/PACKAGE_SHA256.txt"
MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/reval-rebel-p4-044.XXXXXX")"
LAUNCH_LOG="$(mktemp "${TMPDIR:-/tmp}/reval-rebel-p4-044-launch.XXXXXX")"
PRESERVE_LOG=0
TIMEOUT_SENTINEL="$(mktemp "${TMPDIR:-/tmp}/reval-rebel-p4-044-timeout.XXXXXX")"
SKIP_BINARY_SMOKE="${SKIP_BINARY_SMOKE:-0}"
APP_PID=""
WATCHDOG_PID=""
readonly PASS_MARKER="P3-012_PACKAGED_PLATFORM_PASS"
readonly FAIL_MARKER="P3-012_PACKAGED_PLATFORM_FAIL"
readonly SMOKE_TIMEOUT_SECONDS=90
# WHY: Compatibility packaged exit still emits DEF-002 resource/RID leaks plus
# ParticlesShaderGLES3 never-freed noise (same family as P4-012-N01). These are
# not gameplay failures when P3-012_PACKAGED_PLATFORM_PASS is present.
readonly DEF_002_ERROR='^[[:space:]]*ERROR: ([0-9]+ resources still in use at exit \(run with --verbose for details\)\.|[0-9]+ RID allocations of type .+ were leaked at exit\.|[0-9]+ shaders of type .+ were never freed|Pages in use exist at exit in PagedAllocator: .+)$'
readonly FAILURE_PATTERN='SCRIPT ERROR|Parse Error|^[[:space:]]*ERROR:|Resource file not found|Failed loading resource|Can.t open file'

if [[ -n "${GODOT_BIN:-}" ]]; then
  GODOT="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
  GODOT="$(command -v godot)"
elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
else
  echo "Godot 4.7 was not found. Set GODOT_BIN to the Godot executable." >&2
  exit 1
fi

cleanup() {
  if [[ -n "$WATCHDOG_PID" ]]; then
    kill "$WATCHDOG_PID" 2>/dev/null || true
  fi
  if [[ -n "$APP_PID" ]]; then
    kill "$APP_PID" 2>/dev/null || true
  fi
  hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
  rmdir "$MOUNT_DIR" 2>/dev/null || true
  if [[ "$PRESERVE_LOG" == "1" ]]; then
    echo "Act 1 packaged smoke log preserved at: $LAUNCH_LOG" >&2
  else
    rm -f "$LAUNCH_LOG" "$LAUNCH_LOG.unexpected"
  fi
  rm -f "$TIMEOUT_SENTINEL"
}
trap cleanup EXIT

cd "$ROOT_DIR"
rm -f "$TIMEOUT_SENTINEL"

echo "==> P4-044 package SHA / fingerprint bind"
python3 - <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(".").resolve()
manifest = json.loads((root / "docs/data/act1_release_manifest.json").read_text())
fingerprint = json.loads((root / "build/act1/package_fingerprint.json").read_text())
sidecar = (root / "build/act1/PACKAGE_SHA256.txt").read_text().strip().split()[0]
expected = str(manifest["package_sha256"])
fp_sha = str(fingerprint.get("package_sha256", ""))
dmg = root / "build/act1/rr.dmg"
errors = []
if expected != sidecar:
    errors.append(f"manifest sha {expected} != PACKAGE_SHA256.txt {sidecar}")
if expected != fp_sha:
    errors.append(f"manifest sha {expected} != package_fingerprint.json {fp_sha}")
if int(manifest.get("package_bytes", -1)) != int(fingerprint.get("package_bytes", -2)):
    errors.append("manifest package_bytes does not match fingerprint")
if str(fingerprint.get("task_id", "")) != "P4-013":
    errors.append("fingerprint task_id must remain P4-013")
if str(manifest.get("package_task_id", "")) != "P4-013":
    errors.append("manifest package_task_id must bind P4-013")
if not dmg.is_file() or dmg.stat().st_size <= 0:
    errors.append(f"missing Act 1 package: {dmg}")
else:
    actual = hashlib.sha256(dmg.read_bytes()).hexdigest()
    if actual != expected:
        errors.append(f"live DMG sha {actual} != expected {expected}")
    if dmg.stat().st_size != int(manifest["package_bytes"]):
        errors.append("live DMG byte size does not match manifest package_bytes")
if errors:
    print("P4-044 package bind failed:", file=sys.stderr)
    for err in errors:
        print(f"  - {err}", file=sys.stderr)
    raise SystemExit(1)
print(f"P4-044 package bind OK sha256={expected}")
PY

echo "==> P4-044 repository-side release contracts"
python3 tools/report_act1_traversal.py --check
python3 tools/report_accessibility_checklist.py --check
python3 tools/report_slice_third_party.py --check
python3 tools/report_act1_content_budget.py --check
python3 -m unittest tests.python.test_act1_release_candidate -v

echo "==> P4-044 Godot release acceptance + Act 1 traversal"
tools/run_godot_checked.sh --require-test-summary p4-044-release-acceptance -- \
  "$GODOT" --headless --path "$ROOT_DIR" --script tools/run_godot_tests.gd -- \
  --filter=test_act1_release_acceptance
tools/run_godot_checked.sh --require-test-summary p4-044-act1-traversal -- \
  "$GODOT" --headless --path "$ROOT_DIR" --script tools/run_godot_tests.gd -- \
  --filter=test_act1_traversal

if [[ "$SKIP_BINARY_SMOKE" == "1" ]]; then
  echo "SKIP_BINARY_SMOKE=1 set; skipping clean-install Act 1 DMG smoke."
  echo "P4-044 repository-side Act 1 release checks passed."
  exit 0
fi

if [[ ! -s "$DMG_PATH" ]]; then
  echo "Missing or empty Act 1 package: $DMG_PATH" >&2
  exit 1
fi
if [[ ! -f "$FINGERPRINT_PATH" || ! -f "$SHA_SIDECAR" || ! -f "$MANIFEST_PATH" ]]; then
  echo "Missing Act 1 fingerprint / SHA / release manifest sidecars." >&2
  exit 1
fi

echo "==> Mounting Act 1 DMG for clean-install smoke"
hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_DIR" -quiet
SOURCE_APP="$MOUNT_DIR/Reval Rebel.app"
if [[ ! -d "$SOURCE_APP" ]]; then
  echo "Act 1 export did not contain Reval Rebel.app." >&2
  exit 1
fi
# WHY: extract to a temp app so we prove clean install from the DMG, not the
# already-unpacked build tree left behind by P4-013 packaging.
CLEAN_APP="$(mktemp -d "${TMPDIR:-/tmp}/reval-rebel-p4-044-app.XXXXXX")/Reval Rebel.app"
ditto "$SOURCE_APP" "$CLEAN_APP"
hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
rmdir "$MOUNT_DIR" 2>/dev/null || true

BINARY="$CLEAN_APP/Contents/MacOS/Reval Rebel"
if [[ ! -x "$BINARY" ]]; then
  echo "Packaged binary missing: $BINARY" >&2
  exit 1
fi

echo "==> Running Act 1 packaged install/start/save/load/exit smoke"
"$BINARY" -- --verify-packaged-platform >"$LAUNCH_LOG" 2>&1 &
APP_PID=$!
(
  sleep "$SMOKE_TIMEOUT_SECONDS"
  if kill -0 "$APP_PID" 2>/dev/null; then
    touch "$TIMEOUT_SENTINEL"
    kill "$APP_PID" 2>/dev/null || true
  fi
) &
WATCHDOG_PID=$!

set +e
wait "$APP_PID"
LAUNCH_EXIT=$?
set -e
APP_PID=""
kill "$WATCHDOG_PID" 2>/dev/null || true
wait "$WATCHDOG_PID" 2>/dev/null || true
WATCHDOG_PID=""
cat "$LAUNCH_LOG"

rm -rf "$(dirname "$CLEAN_APP")"

if [[ -e "$TIMEOUT_SENTINEL" ]]; then
  PRESERVE_LOG=1
  echo "Act 1 packaged platform smoke exceeded ${SMOKE_TIMEOUT_SECONDS}s." >&2
  exit 1
fi
if grep -q "compiled without support for path overrides" "$LAUNCH_LOG"; then
  echo "Act 1 packaged smoke incorrectly used a path override." >&2
  exit 1
fi
if [[ "$LAUNCH_EXIT" -ne 0 ]]; then
  echo "Act 1 packaged smoke failed with exit $LAUNCH_EXIT." >&2
  exit "$LAUNCH_EXIT"
fi
if grep -q "$FAIL_MARKER" "$LAUNCH_LOG"; then
  echo "Act 1 packaged smoke printed its failure marker." >&2
  exit 1
fi
if ! grep -q "$PASS_MARKER" "$LAUNCH_LOG"; then
  echo "Act 1 packaged smoke exited without the required pass marker." >&2
  exit 1
fi
UNEXPECTED_LOG="${LAUNCH_LOG}.unexpected"
grep -Ev "$DEF_002_ERROR" "$LAUNCH_LOG" > "$UNEXPECTED_LOG" || true
if grep -Eiq "$FAILURE_PATTERN" "$UNEXPECTED_LOG"; then
  echo "Act 1 packaged smoke emitted an unexpected engine or script error." >&2
  grep -Ein "$FAILURE_PATTERN" "$UNEXPECTED_LOG" >&2 || true
  rm -f "$UNEXPECTED_LOG"
  exit 1
fi
rm -f "$UNEXPECTED_LOG"

echo "P4-044 Act 1 release acceptance smoke passed against $DMG_PATH"
echo "Acceptance report: docs/reports/p4_044_act1_release_acceptance.md"
