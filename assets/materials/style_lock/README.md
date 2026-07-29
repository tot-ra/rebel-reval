# Style-lock sample textures (P0-051)

Eight accepted seamless reference albedos for the programmatic 3D isometric presentation. Specification, prompts, post-grade, and acceptance rubric live in [`docs/MATERIAL_STYLE_LOCK_KIT.md`](../../docs/MATERIAL_STYLE_LOCK_KIT.md).

These files are **not wired into the runtime** until P0-053. P0-052 placeholder materials remain active.

| File | Material family |
|---|---|
| `stone.png` | Cut limestone |
| `plaster.png` | Lime plaster infill |
| `timber.png` | Structural timber |
| `roof_tile.png` | Clay roof tiles |
| `mud.png` | Packed earth |
| `cobble.png` | Cobblestone |
| `hay.png` | Dry straw |
| `water.png` | Still water |

Provenance rows: `assets/SOURCES.csv` (`assets.materials.style_lock.*`).

## PBR texture sets (P0-130)

High-quality PBR texture sets (albedo + normal + roughness) for the six primary material
families live under `assets/materials/pbr/<family>/`. See
[`docs/TEXTURE_AI_GENERATION.md`](../../docs/TEXTURE_AI_GENERATION.md) for full prompts
and provenance.

| Family | Files |
|--------|-------|
| `stone` | `stone_albedo.png`, `stone_normal.png`, `stone_roughness.png` |
| `plaster` | `plaster_albedo.png`, `plaster_normal.png`, `plaster_roughness.png` |
| `timber` | `timber_albedo.png`, `timber_normal.png`, `timber_roughness.png` |
| `hay` | `hay_albedo.png`, `hay_normal.png`, `hay_roughness.png` |
| `roof_tile` | `roof_tile_albedo.png`, `roof_tile_normal.png`, `roof_tile_roughness.png` |
| `cobble` | `cobble_albedo.png`, `cobble_normal.png`, `cobble_roughness.png` |
