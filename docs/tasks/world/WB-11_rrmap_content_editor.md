# WB-11: `.rrmap` content editor - paint, place, sculpt, preview, round trip

Board row: **R-983**. Priority: high. Depends on: **R-981**.

## Player-facing goal

None directly. A human can lay out a district by hand in an afternoon, see it in 3D as they work,
and hand the same file to an agent afterwards.

## Why this is needed

`addons/rrmap/` is 2258 lines and it is an **alignment** editor: `map_alignment_canvas.gd`,
`map_alignment_editor_model.gd`, `map_alignment_workspace.gd`, documented in
`docs/MAP_ALIGNMENT_EDITOR.md`. It positions whole maps relative to each other. It cannot paint a
terrain rect, move a building, place a prop, or author relief.

Every piece needed to change that already exists and is unused for this purpose:
`MapRrmapParser` and `MapRrmapSerializer` give a round trip, `MapBlueprintCompiler` gives a
compiled definition with diagnostics, `MapBlueprintEditorPreview` and
`MapBlueprintPreviewOverlay` give a preview surface, and `MapViewMeshBuilder` gives the 3D result.
The consequence of the gap is visible in the baseline: hand-editing coordinates in a text file is
why the districts have 89 buildings and 39 props.

## Deliverable

A content-editing mode in `addons/rrmap/`, on the same editor main screen, with:

1. **A grid canvas** showing terrain, buildings, props, anchors, transitions and relief, with
   layer toggles, snapping to the authored cell grid, and stable IDs visible on selection.
2. **Terrain painting** with rect, stroke and flood tools, writing `terrain`, `terrain_rects` and
   `stroke` statements.
3. **Placement and editing** of buildings, props, decals, anchors, signs and transitions by drag,
   with inspector fields for every attribute the grammar allows and the R-981 `desc=` field
   required before a new plot can be committed.
4. **Relief sculpting** for the R-974 primitives - hill, ridge, ditch, terrace, cliff, noise - with
   a height readout under the cursor and a slope overlay that shades anything above the R-975
   walkable maximum.
5. **Plot authoring** as the primary urban tool once R-981 lands: place a plot with frontage, depth,
   wealth and age, and see the expanded prefab immediately.
6. **Live diagnostics.** `MapBlueprintCompiler` runs on edit; every `MapBlueprintDiagnostic` is
   listed and clicking it selects and frames the offending element. Errors block save.
7. **Live 3D preview** in a docked viewport driven by the same compiled `MapDefinition` the runtime
   uses, so what the author sees is what ships.
8. **Safe save.** Writes through `MapRrmapSerializer`. Unchanged statements must be byte-identical,
   comments and authored ordering preserved, and no stable ID may be renamed or reordered by a
   save. A save that would change an ID is refused with the reason.

## Allowed files

`addons/rrmap/rrmap_plugin.gd`, `addons/rrmap/plugin.cfg`,
`addons/rrmap/content_editor_workspace.gd`, `addons/rrmap/content_editor_canvas.gd`,
`addons/rrmap/content_editor_model.gd`, `addons/rrmap/content_editor_inspector.gd`,
`addons/rrmap/content_editor_relief_tool.gd`, `addons/rrmap/content_editor_preview_3d.gd`,
matching `.uid` sidecars, `scripts/map/map_blueprint_editor_preview.gd`,
`scripts/map/map_blueprint_preview_overlay.gd`, `scripts/map/rrmap/map_rrmap_serializer.gd`,
`tests/godot/test_rrmap_content_editor.gd` and its `.uid`,
`docs/MAP_EDITOR.md`, `docs/MAP_ALIGNMENT_EDITOR.md`, `docs/MAP_AUTHORING.md`,
`docs/reports/images/map_editor/`, `docs/tasks/world/WB-11_rrmap_content_editor.md`, `TODO.md`.

## Constraints and non-goals

Editor-only: nothing here may be loaded by the running game, and no runtime script may gain an
editor dependency. Do not replace or regress the existing alignment workspace; it stays as a second
mode. The `.rrmap` text file remains the authoritative source - the editor is a view over it, never
a parallel binary format, and hand-editing must remain fully supported. No terrain sculpting outside
the R-974 primitives. This row must not change any production map.

## Verification

- `godot --headless --path . --script tools/run_godot_tests.gd` with
  `test_rrmap_content_editor.gd` exercising the model headlessly, asserting: load then save with no
  edit is byte-identical for all 29 maps, including comments and ordering; each tool emits exactly
  the expected statement; a save that would rename or reorder a stable ID is refused; errors block
  save; undo and redo restore the exact prior text.
- A recorded editing session, as screenshots or a clip: paint terrain, place a plot, sculpt a ridge,
  fix a live diagnostic, save, then load the saved map in game and show it matches the preview.
- `godot --headless --path . --script tools/validate_map_blueprints.gd` on a map created entirely in
  the editor, with zero errors.
- `python3 tools/verify_map_audit.py`, `verify_map_conversion_plan.py`,
  `generate_active_docs_report.py --check`, `git diff --check`
- The editor opens through `tools/godot_render.sh` conventions; no test may open a visible window.

## Doc updates

New `docs/MAP_EDITOR.md` covering the workflow and every tool.
`docs/MAP_AUTHORING.md` points authors at the editor first and text editing second.
`docs/MAP_ALIGNMENT_EDITOR.md` notes the two modes.
