# R-285 / P4-023b - Monastery District ordinary fabric pass

Status: implemented, awaiting human art/historical sign-off of the captures.
Map: `content/maps/monastery_quarter.rrmap` (`scope=prototype active=false`, stays inactive).

## What changed

- 37 ordinary strip-plot houses on the R-003 tiers (`merchant_stone`, `merchant_timber`,
  `craft_boda`), all gable-to-street with the door onto their lane:
  - Pikk north and south frontages lean `merchant_stone` with tile roofs, with timber fronts between them.
  - Lai frontages mix `merchant_timber` (plaster/plank, shingle) and `craft_boda` booths behind the workshops.
  - A new mud `rear_service_lane` carries `craft_boda` renter booths between the Lai yards and the east curtain.
  - A civic-lane row south of the guild lane, and craft booths in and beside the Vene lane loop.
- Rear-yard mud ground, wattle plot edges, yard gates, privies, firewood, lean-tos, wash tubs,
  herb racks and three extra yard trees. No fence crosses Pikk, Lai, a lane, or a patrol corridor.
- St Michael's precinct interior, St Olaf's close, and every stable ID, transition, spawn,
  anchor and patrol point are unchanged.
- `docs/data/monastery_quarter_authoring_contract.json` names the extramural wall verge and road
  (`outer_wall_verge_and_road`, cells 228-259) as owned open ground. This follows the
  `north_quarter` contract precedent.
- The `historical_band_grace.monastery_quarter` row is removed. The signed H04-H05/H14 bands were not lowered.

## P1-036 measurements (`MapCompositionAudit.measure`)

| Metric | Band | Before | After |
|---|---|---|---|
| `max_style_share_pct` | <= 55 | 55.17 | 36.36 |
| `largest_empty_region_cells` | <= 22000 | 25774 | 20093 (23309 without the outer-road contract) |
| `earth_pct` | 60-75 | in band | 71.3 |
| `grass_pct` | 20-35 | in band | 25.3 |
| `stone_pct` | 0-6 | in band | 3.4 |
| `cobblestone_pct` | <= 3 | in band | 1.5 |
| elevation range | >= 0.3 | 1.48 | 1.42 |

The composition audit now reports `monastery_quarter: pass` with no grace entry.

## Decisions

- **Outer road exclusion.** The strip east of the curtain wall is the travel-only extramural road
  and wet ditch, not district fabric. Excluding it matches `north_quarter`. The St Michael precinct
  is *not* excluded: the new houses alone reduce the region by 2465 cells.
- **`MAP_CHUNK_BOUNDARY_AMBIGUOUS` warnings.** Some new houses cross future 16x16 chunk lines, like
  most existing houses on every district map. The map is inactive and not chunked yet, so these are
  accepted until chunk ownership is authored for activation.
- **Known gaps (not enforced for this prototype card):**
  - Built density is 18.9%, below the dossier's 35-50% band. The card does not enforce `built_density_pct`.
  - The WB-10 `sparse_urban` dressing contract still reports `props_per_1000` 1.9 (needs >= 17.9)
    and no decals. It runs in report mode for prototype maps.
  - Both belong to activation work, not this pass.

## Evidence

Captured with `tools/godot_render.sh --script tools/capture_monastery_fabric.gd`:

- `docs/reports/images/monastery_fabric/r285_pikk_north_{day,night}.png`
- `docs/reports/images/monastery_fabric/r285_service_lane_{day,night}.png`
- `docs/reports/images/monastery_fabric/r285_vene_edge_{day,night}.png`
- `docs/reports/images/monastery_fabric/r285_precinct_and_frontage_{day,night}.png`

Night plates share the project-wide dark night grade, so their readability belongs with the lighting tasks.

Human sign-off on the day/night plates is still required before the parent P4-023 closes.
