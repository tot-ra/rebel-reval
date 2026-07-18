# Setup

Authoritative Godot version pin and editor installation for **Reval Rebel**.

## Pinned version

| Source | Value |
|--------|-------|
| [`.godot-version`](../.godot-version) | `4.7` |
| [`project.godot`](../project.godot) `config/features` | `4.7`, `GL Compatibility` |
| [`project.godot`](../project.godot) `config_version` | `5` (Godot 4.x project format) |

Use **Godot 4.7.x** editor builds. Install the latest **4.7** patch release from the official site unless a maintainer records a stricter patch pin. Do not open this repository in Godot 4.6 or earlier without an explicit migration task.

The project targets the **GL Compatibility** renderer (`renderer/rendering_method=gl_compatibility` in `project.godot`). Prefer the standard editor download that includes all renderers; avoid Forward+ only templates when choosing export binaries.

## Prerequisites

- Git
- macOS, Linux, or Windows workstation

## Clone

```bash
git clone <repository-url> rebel-reval
cd rebel-reval
```

## Install Godot 4.7

### All platforms

1. Open [Godot Engine downloads](https://godotengine.org/download).
2. Select **4.7** (latest **4.7.x** stable patch).
3. Download the **Standard** editor for your operating system (not the .NET build unless a future task requires C#).
4. Extract or install the editor to a stable location on disk.

### macOS

- Download the **macOS** `.dmg` or universal build.
- Move **Godot.app** to `/Applications` or another fixed path.
- First launch: if Gatekeeper blocks the app, open **System Settings -> Privacy & Security** and allow Godot, or right-click the app and choose **Open**.

Optional: add the editor binary to your `PATH`, for example:

```bash
sudo ln -sf /Applications/Godot.app/Contents/MacOS/Godot /usr/local/bin/godot
```

### Linux

- Download the **Linux** x86_64 binary (or arm64 if available for your machine).
- Extract the archive and place the `Godot_v4.7.x_*` binary in a directory on your `PATH`, or invoke it by absolute path.

Example:

```bash
chmod +x ~/bin/Godot_v4.7.*_linux.x86_64
~/bin/Godot_v4.7.*_linux.x86_64 --version
```

### Windows

- Download the **Windows** x86_64 `.exe` (or zip).
- Place `Godot_v4.7.x_win64.exe` in a fixed folder and optionally add that folder to your user `PATH`.

## Verify installation

The editor should report a **4.7.x** version:

```bash
godot --version
```

If `godot` is not on your `PATH`, run the equivalent command from the Godot binary you installed, for example on macOS:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --version
```

Expected output begins with `4.7.` (patch digit may vary).

Confirm the repository pin:

```bash
cat .godot-version
grep 'config/features' project.godot
```

Both should reference **4.7**.

## Open the project

1. Launch Godot **4.7.x**.
2. In the Project Manager, choose **Import** (first time) or **Edit** (subsequent opens).
3. Select [`project.godot`](../project.godot) at the repository root.
4. Wait for the editor to finish importing tracked assets (`.import` sidecars are committed; local `.godot/` cache is regenerated). See the tracked sidecar and cache rules in [`docs/reports/godot_import_cache_policy_p0_023.md`](./reports/godot_import_cache_policy_p0_023.md).

Run the game from the editor with **F5** or **Project -> Run**. The main scene is `res://scenes/menu/main_menu.tscn`.

## CI alignment

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) reads the same 4.7 family pin from `.godot-version` and checks `project.godot` `config/features` before running automation. The workflow installs Godot `4.7.1` with matching export templates, matching the recorded P0-017 baseline patch release.

The local equivalent of the CI validation job is:

```bash
godot --version
python3 --version
godot --headless --editor --quit
godot --headless --quit-after 5
godot --headless --quit-after 5 scenes/reval_east/reval_east.tscn
godot --headless --script tools/run_godot_tests.gd
python3 tools/generate_active_docs_report.py --check
python3 tools/generate_active_docs_report.py --fixture clean
python3 tools/generate_active_docs_report.py --fixture invalid  # expected to fail
python3 tools/validate_asset_sources.py
```

P1-002 adds a minimal repository-owned Godot headless harness. CI still keeps the main-scene startup smoke as parser/startup coverage, but invokes the real test command below instead of using startup smokes as a test substitute. The workflow also includes seeded negative checks for active links/canon, manifest coverage, parser diagnostics, and the Godot test harness so those failure classes are known to fail CI.

The local equivalent of the desktop export smoke is macOS-only today because `export_presets.cfg` contains only the `rr` macOS preset:

```bash
mkdir -p build && godot --headless --export-release "rr" ./build/rr.dmg
test -s ./build/rr.dmg
```

## CLI commands

The following copy-pasteable commands can be used for headless automation. They assume the `godot` binary is in your `PATH` and you are at the repository root.

### Headless import

To perform a clean import of all tracked assets without launching the editor UI:

```bash
godot --headless --editor --quit
```

Policy: keep source assets plus matching `*.import` sidecars tracked, but do not commit generated cache folders. Godot 4 regenerates `.godot/`; legacy `.import/` cache folders are also ignored. See [`docs/reports/godot_import_cache_policy_p0_023.md`](./reports/godot_import_cache_policy_p0_023.md).

### Startup / parser check

To verify that the project and its scripts parse without errors in headless mode:

```bash
godot --headless --check-only
```

As of the P0-017 baseline, `godot --headless --check-only` does not exit on this project (see [`docs/reports/known_runtime_defects.md`](./reports/known_runtime_defects.md) `DEF-001`). Until that is fixed, use this playable-room smoke command instead:

```bash
godot --headless --quit-after 5 scenes/reval_east/reval_east.tscn
```

Recorded results: [`docs/reports/startup_baseline.md`](./reports/startup_baseline.md).

### Tests

The project uses a minimal repository-owned headless harness rather than an external addon. The command recursively discovers `tests/godot/test_*.gd`, runs zero-argument `test_*` methods, reports `PASS` and `FAIL` lines, and exits nonzero on failures or harness errors.

```bash
godot --headless --script tools/run_godot_tests.gd
```

To add tests, create a script under `tests/godot/` named `test_<area>.gd`, extend `res://tests/godot/test_case.gd`, and add zero-argument methods named `test_<behavior>`. Use `before_each()` and `after_each()` for per-test setup when needed.

### Validation

Run the schema fixture checks, semantic validator tests, and complete example corpus validation:

```bash
python3 tools/validate_content_examples.py
python3 -m unittest tests.python.test_validate_content -v
python3 tools/validate_content.py content/examples/valid content/examples/support
```

`tools/validate_content.py` recursively validates JSON records and reports stable diagnostic codes for schema errors, references, reachability, duplicate IDs, unsupported conditions/effects, invalid inputs, and missing `res://` scene assets. CI invokes all three commands.

To run the active Markdown link and canon consistency report:

```bash
python3 tools/generate_active_docs_report.py --check
```

To regenerate the active Markdown report:

```bash
python3 tools/generate_active_docs_report.py
```

### Export

The repository contains one preset (`rr`) for macOS export. To build and launch the real release application with the branded Dock icon and without the editor's `(DEBUG)` wrapper:

```bash
tools/run_macos_release.sh
```

This requires the matching Godot 4.7 export templates. F5/F6 still runs an editor debug process by design, so use the launcher when validating the release presentation.

To perform only a headless export:

```bash
mkdir -p build && godot --headless --export-release "rr" ./build/rr.dmg
```
