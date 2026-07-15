# Setup

Authoritative Godot version pin and editor installation for **Reval Rebel**.

## Pinned version

| Source | Value |
|--------|-------|
| [`.godot-version`](../.godot-version) | `4.4` |
| [`project.godot`](../project.godot) `config/features` | `4.4`, `GL Compatibility` |
| [`project.godot`](../project.godot) `config_version` | `5` (Godot 4.x project format) |

Use **Godot 4.4.x** editor builds. Install the latest **4.4** patch release from the official site unless a maintainer records a stricter patch pin. Do not open this repository in Godot 4.3 or earlier, or in Godot 4.5+ without an explicit migration task.

The project targets the **GL Compatibility** renderer (`renderer/rendering_method=gl_compatibility` in `project.godot`). Prefer the standard editor download that includes all renderers; avoid Forward+ only templates when choosing export binaries.

## Prerequisites

- Git
- macOS, Linux, or Windows workstation

## Clone

```bash
git clone <repository-url> rebel-reval
cd rebel-reval
```

## Install Godot 4.4

### All platforms

1. Open [Godot Engine downloads](https://godotengine.org/download).
2. Select **4.4** (latest **4.4.x** stable patch).
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
- Extract the archive and place the `Godot_v4.4.x_*` binary in a directory on your `PATH`, or invoke it by absolute path.

Example:

```bash
chmod +x ~/bin/Godot_v4.4.*_linux.x86_64
~/bin/Godot_v4.4.*_linux.x86_64 --version
```

### Windows

- Download the **Windows** x86_64 `.exe` (or zip).
- Place `Godot_v4.4.x_win64.exe` in a fixed folder and optionally add that folder to your user `PATH`.

## Verify installation

The editor should report a **4.4.x** version:

```bash
godot --version
```

If `godot` is not on your `PATH`, run the equivalent command from the Godot binary you installed, for example on macOS:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --version
```

Expected output begins with `4.4.` (patch digit may vary).

Confirm the repository pin:

```bash
cat .godot-version
grep 'config/features' project.godot
```

Both should reference **4.4**.

## Open the project

1. Launch Godot **4.4.x**.
2. In the Project Manager, choose **Import** (first time) or **Edit** (subsequent opens).
3. Select [`project.godot`](../project.godot) at the repository root.
4. Wait for the editor to finish importing tracked assets (`.import` sidecars are committed; local `.godot/` cache is regenerated).

Run the game from the editor with **F5** or **Project -> Run**. The main scene is `res://scenes/menu/main_menu.tscn`.

## CI alignment

No CI workflow pins a different Godot version today. When **P1-001** adds CI, it must read the same pin from `.godot-version` and `project.godot` `config/features`.

## CLI commands

The following copy-pasteable commands can be used for headless automation. They assume the `godot` binary is in your `PATH` and you are at the repository root.

### Headless import

To perform a clean import of all tracked assets without launching the editor UI:

```bash
godot --headless --editor --quit
```

### Startup / parser check

To verify that the project and its scripts parse without errors in headless mode:

```bash
godot --headless --check-only
```

### Tests

There is **no** test harness configured in the repository yet. Automated tests (like GUT or scene transition tests) are pending **P1-002**.

### Validation

To run the active Markdown link and canon consistency report:

```bash
python3 tools/generate_active_docs_report.py --check
```

To regenerate the active Markdown report:

```bash
python3 tools/generate_active_docs_report.py
```

### Export

The repository contains one preset (`rr`) for macOS export. To perform a headless export:

```bash
mkdir -p build && godot --headless --export-release "rr" ./build/rr.dmg
```
