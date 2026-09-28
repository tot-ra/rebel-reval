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
  - Both belong to activation work, not this pass. **Closed by R-1036 below.**

## R-1036 - dressing density and built-density gap

Status: implemented, awaiting the same human art/historical sign-off as R-285.

### What changed

- **Built fabric.** 93 new `house` rows on the existing R-003 tiers plus seven reviewed rear-range
  styles (`house.rear.store.*` limestone storehouses, `house.rear.shed.*` log/plank sheds) and
  `house.lai.timber.east`. Frontages keep gable-to-street massing with the door on their lane; rear
  ranges stand at the back of the strip plots, which is the H04-H05 front-house / rear-service
  pattern the dossier describes.
  - North strip between the north seam and the precinct wall (craft booths, doors onto the garden path).
  - Pikk west and east middle frontages, Lai west frontages, and rear stores in the Pikk-Lai block.
  - Lai east frontage south of the merchant house, and a new `east_yard_lane` with strip plots on
    both sides between Lai and the east curtain.
  - An `intramural_wall_lane` inside the east curtain with east-facing booths.
  - Guild-lane frontage south of St Olaf's close, guild corner stores, and civic-lane rows north and
    south of the civic lane, set back from the south seam.
- **New lanes** (mud, like the other secondary lanes): `pikk_lai_cross_lane` along the line the
  watch patrol already walked, `east_yard_lane`, `intramural_wall_lane`.
- **Dressing.** 381 new props. Every ordinary plot gets two or three yard props behind the house,
  never on Pikk, Lai or a lane: merchant plots take goods pallets, crates, malt sacks, kegs, rope
  and sweeps; craft plots take fuel, hens, kitchen beds, cooper staves, charcoal, flax frames and
  hand tools; rear ranges take carts, hay, root cellars and lean-tos. St Michael's garden south of
  the precinct wall gains eight kitchen beds, four orchard rows and an almonry hen run.
- **Decals.** 169 view-only decals: door-threshold mud on the lanes, wet ground at tubs and sweeps,
  grime at privies, soot at charcoal heaps.
- Unchanged: St Michael's walled precinct and St Olaf's stone close (no new building intersects
  either), every stable ID, transition, spawn, anchor and patrol point, `active=false`, the signed
  bands, and `historical_band_grace` (no grace row added).

### Measurements (`MapCompositionAudit.measure`)

| Metric | Floor / band | Before | After |
|---|---|---|---|
| `built_density_pct` | 35-50 (HISTORICAL_AUDIT) | 18.9 | 35.1 |
| `props_per_1000` | >= 17.9 | 1.9 | 22.8 (426 dressing props / 18 647 walkable cells) |
| `decals_per_1000` | >= 3.1 | 0.0 | 9.1 |
| `distinct_prop_kinds` | >= 10 | 14 | 33 |
| `max_prop_kind_share_pct` | <= 35 | 17.8 | 9.4 (`barrels`) |
| `ground_cover_pct` | >= 20 | 25.3 | 28.7 |
| `max_identical_footprint_run` | <= 3 | 2 | 3 |
| `earth_pct` / `grass_pct` / `stone_pct` | 60-75 / 20-35 / 0-6 | 71.3 / 25.3 / 3.4 | 67.3 / 28.6 / 4.2 |
| `largest_empty_region_cells` | <= 22000 | 20093 | 15431 |

`tools/audit_map_composition.gd` reports `monastery_quarter: pass` and `DENSITY_JSON` status `pass`.

### Decisions

- **Density is measured over the whole map**, including the extramural wall road that the authoring
  contract keeps open. Intramural density is therefore higher than 35.1%, still inside the band.
- **No `pikk_east_plot_m3`.** St Olaf's footprint covers the Pikk spine at y 58-71, so walkers pass
  its east end at x 105-116. That strip stays open; the test pins x 106 for y 56-79.
- **Livestock.** The monastery row allows "at most one small livestock or tether group", so the
  yard kits carry no pigsties; hens are contained in runs.
- **`MAP_CHUNK_BOUNDARY_AMBIGUOUS`** warnings on new houses follow the R-285 decision above: the
  map is inactive and not chunked yet.
- The new frontages and rear ranges are generic ordinary fabric. No named 1343 owner or trade is
  claimed for any of them.

### Evidence

`tests/godot/test_monastery_quarter_prototype_map.gd::test_r1036_density_pass_meets_floors_and_keeps_precinct_close_and_routes_open`
asserts the built-density band, the WB-10 `sparse_urban` floors, the untouched precinct and close,
the Pikk bypass, and that every intramural anchor, patrol point and transition is reachable from the
inspection spawn. It fails on the pre-R-1036 map (18.9% built, WB-10 prop floor).

Day/night plates, captured with the R-285 shots plus three new ones through
`tools/godot_render.sh` (a `build/` copy of `tools/capture_monastery_fabric.gd` writing `r1036_*`, so
the R-285 plates stay as before-evidence):

- `docs/reports/images/monastery_fabric/r1036_{pikk_north,service_lane,vene_edge,precinct_and_frontage}_{day,night}.png`
- `docs/reports/images/monastery_fabric/r1036_{east_yard_lane,civic_lane,pikk_lai_block}_{day,night}.png`

## Evidence

Captured with `tools/godot_render.sh --script tools/capture_monastery_fabric.gd`:

- `docs/reports/images/monastery_fabric/r285_pikk_north_{day,night}.png`
- `docs/reports/images/monastery_fabric/r285_service_lane_{day,night}.png`
- `docs/reports/images/monastery_fabric/r285_vene_edge_{day,night}.png`
- `docs/reports/images/monastery_fabric/r285_precinct_and_frontage_{day,night}.png`

Night plates share the project-wide dark night grade, so their readability belongs with the lighting tasks.

Human sign-off on the day/night plates is still required before the parent P4-023 closes.
