# CO-01: Coastal ground materials (sand, shingle, mud, shore grass)

Board row: **R-948**. Priority: high. Depends on: none.

## Player-facing goal

Standing on the Kalamaja beach, the ground reads as wet-packed sand, dry drift sand, shingle and
churned mud with visible grain and relief, not as a flat tinted plane with speckles on it. The
surface holds up at gameplay camera distance and at a close third-person framing, and it does not
show an obvious repeating tile across the 125 m shore.

## Why this is needed

Measured on 2026-09-26:

- `sand` and `coast_sand` have **no texture**. `scripts/map/view3d/map_view_terrain_materials.gd:65`
  maps both to `PATTERN_SPECKLE`, a procedural pattern. A beach is 11.1% of Kalamaja's cells and much
  more than that of the screen, so a procedural speckle is the single largest material gap on the map.
- `grass`, `mud` and `limestone_rubble` ship **albedo only, 512x512**. `cobble`, `hay`, `stone` and
  `timber` already ship albedo + normal + roughness. The shore families are the ones missing relief.
- The existing plates were generated at 1024 through `tools/generate_leonardo_material.py` and landed
  at 512 (`assets/materials/pbr/grass/prompt.json` records `"width": 1024`), so resolution was lost
  in processing, not in generation.

## Deliverable

1. Four **new** three-map PBR families at **2048x2048**, seamless, generated through the existing
   Leonardo pipeline with a committed `prompt.json` per family, following the tone rules already
   recorded in the `grass` and `mud` prompts (Baltic 1343, overcast diffuse, no baked shadows):
   - `coast_sand` - damp wave-packed foreshore sand with shell fragments and ripple relief
   - `sand` - dry wind-drifted upper-beach sand with wind ripples and grass litter
   - `shore_shingle` - mixed pebble and gravel storm beach (new terrain-detail material, not a new
     `MapTypes` terrain ID)
   - `mud` - replacement for the existing albedo-only tidal/yard mud, with hoof and boot relief
2. Regenerate `grass` at 2048 with normal and roughness, keeping the existing prompt text and
   `Color8(79, 149, 79)` palette relationship from `OutdoorTerrainPalette`.
3. A **multi-scale detail blend** in `map_view_terrain_blend.gdshader`: each ground layer samples its
   albedo/normal/roughness at two world-space scales (roughly 1x and 0.17x) with a low-frequency mask
   so the 2048 tile does not read as a grid across a 144-cell band. One shared `detail_strength`
   uniform, exposed per terrain family, art-overridable per ADR 0018.
4. `map_view_terrain_materials.gd` drops `PATTERN_SPECKLE` for `TERRAIN_SAND` and
   `TERRAIN_COAST_SAND` and binds the new sets. The WS-08 wet-sand path
   (`sand_layer` / `coast_sand_layer` shader params, `map_view_terrain_materials.gd:257-260`) keeps
   working and now darkens a real albedo instead of a pattern.
5. `assets/SOURCES.csv` rows for every new PNG with tool, model version, prompt, seed and approval.

## Allowed files

- `assets/materials/pbr/coast_sand/*`, `assets/materials/pbr/sand/*`,
  `assets/materials/pbr/shore_shingle/*`, `assets/materials/pbr/mud/*`,
  `assets/materials/pbr/grass/*` (albedo, normal, roughness, `prompt.json`, `*.import`)
- `assets/SOURCES.csv`
- `scripts/map/view3d/map_view_terrain_materials.gd`
- `scripts/map/view3d/map_view_terrain_blend.gdshader`
- `scripts/map/view3d/map_view_material_patterns.gd` (only to retire the sand speckle entries)
- `tools/process_leonardo_terrain_textures.py` (only if 2048 output needs a flag)
- `tests/godot/test_terrain_material_channels.gd` (new), `tests/godot/test_r715_water_material_contract.gd`
- `tools/capture_co01_ground_materials.gd` (new)
- `docs/ART_BIBLE.md`, `docs/reports/co01_coastal_ground_materials.md`,
  `docs/reports/images/co01_*.png`, `TODO.md`

## Constraints and non-goals

- Do not add or rename a `MapTypes` terrain ID. `shore_shingle` is a material/detail family used by
  CO-02 scatter and by existing `stone`/`limestone_rubble` cells, not a new terrain.
- Do not touch water shaders, WS-08 swash logic, boats, map geometry or navigation.
- Do not replace `cobble`, `hay`, `stone`, `timber`, `plaster`, `roof_tile` or the building variants.
- Keep `OutdoorTerrainPalette` hues as the tint target so unrelated maps do not shift colour.
- Respect `docs/ASSET_STORAGE_POLICY.md`. If five 2048 three-map families breach the size budget,
  stop and record the number in the report rather than silently dropping to 1024.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_terrain_material_channels,test_r715_water_material_contract
python3 tools/validate_asset_sources.py
python3 tools/verify_asset_lint.py
python3 tools/verify_storage_hygiene.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

- `test_terrain_material_channels.gd` asserts that `sand`, `coast_sand`, `mud`, `grass` and
  `shore_shingle` each resolve albedo **and** normal **and** roughness at >= 2048 px, and that no
  ground terrain still resolves to `PATTERN_SPECKLE`.
- `tools/capture_co01_ground_materials.gd` through `tools/godot_render.sh`, on `reval_harbor_east`,
  clear noon and overcast: one gameplay-camera plate and one close plate per condition, before and
  after, on Compatibility and on `--rendering-method mobile --rendering-driver metal`. The after
  plates must show grain and relief and no visible tile grid across the shore band.
- `tools/run_performance_report.sh build/co01_perf.json --quick` stays inside the 16.67 ms budget.

## Doc updates

`docs/ART_BIBLE.md` ground-material section, new
`docs/reports/co01_coastal_ground_materials.md` with the plates and the storage numbers, `TODO.md`.

## TODO.md line

```
- [ ] R-948 | deps: none | deliverable: 2048 three-map PBR sets for coast_sand, sand, shore_shingle, mud and grass plus a two-scale anti-tiling detail blend, replacing the procedural sand speckle | allowed files: per docs/tasks/coast/CO-01_coastal_ground_materials.md | verify: `--filter=test_terrain_material_channels,test_r715_water_material_contract`; asset sources/lint/storage validators; Kalamaja gameplay and close plates before/after on Compatibility and Metal show grain, relief and no tile grid; quick performance report inside budget
```
