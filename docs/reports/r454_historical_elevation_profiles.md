# R-454a - Historical elevation profile matrix

## Status and decision

This report freezes the historical elevation targets for the nine urban exterior RRMaps. It is a documentation-only contract. It does not add `elevation`, `grade`, `area`, or `ramp` statements to the RRMaps and does not change runtime code.

The matrix distinguishes three different things that must not be conflated:

1. **Authored runtime datum**: the value currently present in the RRMap header and compiled into `MapDefinition.ground_elevation`.
2. **R-454 target**: the conservative view-layer value that a later authoring pass may implement through the typed elevation API.
3. **Historical constraint**: the source-backed relationship or bounded range in metres. A historical metre range is not itself a runtime world-unit value.

The existing code contract remains authoritative:

- RRMap cell coordinates are used below exactly as authored. They are not multiplied by `cell_size`.
- `cell_size=32` describes the pixel plane used for cell placement. It is not an elevation scale.
- Elevation is view-only, in 3D world units. It does not change 2D collision, navigation, transition placement, stable IDs, or save identity.
- `ground_elevation` is limited to `0..8` world units. Profile heights and deltas are limited to the existing `-8..8` validation range.
- Map-edge tapering must bring a profile to the shared transition seam. A profile must not create a visible step at an inter-map opening.

The target values below are intentionally conservative implementation values. They are not a claim that a surveyed 1343 digital elevation model exists. Where the dossiers provide only a relative relationship, the target is marked `plausible composite` or `authoring target` rather than `attested`.

## Scope

### Included maps

| Map | RRMap dimensions | Current scope | Current authored datum | Matrix role |
|---|---:|---|---:|---|
| `lower_town_slice` | `152 x 128` | production, active | `0.0` implicit | Active Lower Town slice, shared low-town datum |
| `market_civic_quarter` | `114 x 128` | prototype, inactive | `0.0` implicit | Raekoja/forum and civic throat |
| `monastery_quarter` | `260 x 112` | prototype, inactive | `0.0` implicit | St. Olaf/Cistercian precinct and eastern ditch |
| `north_quarter` | `260 x 140` | prototype, inactive | `0.0` implicit | Pikk merchant strip and Coastal Gate approach |
| `south_quarter` | `336 x 96` | prototype, inactive | `0.0` implicit | Karja, Rataskaevu, Harju and southern seam |
| `toompea_quarter` | `144 x 192` | prototype, inactive | `2.8` authored | Toompea plateau and the two descents |
| `archbishops_garden` | `144 x 48` | prototype, inactive | `2.8` authored | Plateau garden and lower-town gate seams |
| `reval_harbor_north` | `160 x 108` | prototype, inactive | `0.0` implicit | Coastal Gate merchant landing |
| `reval_harbor_east` | `144 x 80` | prototype, inactive | `0.0` implicit | Kalamaja/Kalarand fishing shore |

`R-455` remains a useful implementation baseline: it records the existing `2.8` Toompea datum, but also records that authored grade profiles are absent from the target fixtures. This report closes the historical decision gap without pretending that R-455 runtime acceptance has already passed.

### Explicit exclusion: `viru_gate_foreland`

`viru_gate_foreland.rrmap` is **excluded** from the nine-map urban exterior matrix.

It is an inactive prototype (`scope=prototype active=false`, `168 x 120`) for a rural/eastern road, river meadow, Pirita bridge and farmstead. Its stable transition from `lower_town_slice` is retained as an external seam, but the map is not a Lower Town urban exterior and does not belong in the city elevation baseline. It should receive a separate extramural/world-edge profile decision if it is activated.

This exclusion also keeps the harbour pair historically coherent. The harbour dossiers explicitly treat `reval_harbor_north` as the Coastal Gate merchant landing and `reval_harbor_east` as the Kalamaja/Kalarand fishing shore; they do not make Pirita the 1343 Reval harbour.

### Other exclusions

- Interior maps and room scenes, including the forge, churches and halls.
- World maps and rural locations outside the nine urban exterior RRMaps.
- Modern filled harbour ground, later quays, Fat Margaret, later barbicans and other post-1343 fortification fabric.
- Absolute archaeological street altitudes where the cited dossier only provides relative depth or a later comparison.

## Confidence and value notation

The matrix uses the project evidence vocabulary:

- **Attested constraint**: directly supported by the cited dossier or archaeological finding, but still not necessarily a measured gameplay coordinate.
- **Partial**: some archaeological or documentary support exists, but the exact extent, date or geometry is incomplete.
- **Plausible composite**: a bounded reconstruction assembled from surviving alignment, historical topography and project map decisions.
- **Authoring target**: a deliberately conservative gameplay value chosen to express the constraint. It is not an archaeological measurement.
- **Unknown**: no defensible historical number is available. Keep the seam flat or preserve the existing authored datum until new evidence arrives.

Profile notation:

```text
profile_id | local geometry | target heights in world units | historical constraint | evidence
```

For ramps, the first endpoint is the higher/inland/plateau endpoint unless the row says otherwise. For areas, the rectangle or centre/radius is the authored cell-space coverage, not a world-space rectangle.

## Frozen matrix

### 1. `lower_town_slice`

**Local datum:** `0.0` ordinary Lower Town street plane. The RRMap currently has no explicit elevation profile.

| Profile ID | Local cell-space endpoints/area | R-454 target | Historical/source label | Confidence |
|---|---|---|---|---|
| `r454.lt.lowtown_datum` | area `x=0..152, y=0..128`, excluding gate/transition tapers | `0.0` | baseline authoring target; no absolute 1343 street altitude claimed | unknown, keep flat |
| `r454.lt.pikk_to_harbourward` | ramp along authored Pikk segment `(26,0) -> (26,55)` | `+0.20 -> 0.00` | Lower Town rises away from the wet north margin; the project street plan gives a bounded `1-2 m` harbourward fall for the Pikk merchant block | plausible composite |
| `r454.lt.viru_karja_spines` | authored road junction `(0,55) -> (64,55) -> (64,127)` | `0.00` with no additional historical grade | preserve the active slice's readable road junction; no source supports a second numeric slope here | unknown, flat target |
| `r454.lt.south_boundary` | seam strip around `anchor karja_gate_south (62,121)` and `transition to_reval_south (59..73,126)` | `0.00` at opening | shared Lower Town seam; southern/eastern low-ground and ditch relationships remain unresolved | partial seam rule |

The authored `road.pikk`, `road.viru` and `road.karja` strokes are the geometric evidence for these local paths. The `viru_gate` and `viru_foregate` structures do not justify assigning a later foregate elevation to the 1343 street plane. The historical dossier says that the main Viru gate may be present or unfinished and that the familiar round foregate towers are later fabric.

### 2. `market_civic_quarter`

**Local datum:** `0.0` at the forum. The forum is open ground and should not be turned into a bowl by an unsupported absolute height.

| Profile ID | Local cell-space endpoints/area | R-454 target | Historical/source label | Confidence |
|---|---|---|---|---|
| `r454.market.forum_datum` | `terrain forum.ground x=24..68, y=31..66` | `0.00` | Raekoja plats as the civic open-ground reserve; no absolute 1343 street altitude | attested function, unknown absolute |
| `r454.market.east_throat_fall` | ramp along `street.east_market_throat (64,52) -> (112,53)` | `0.00 -> -0.10` | east throat narrows and becomes a through-lane toward the Viru/Vene convergence; small fall is a readability target, not a measured value | plausible composite |
| `r454.market.south_yards` | `terrain south.yards.west/east`, approximately `x=4..114, y=105..111` | `0.00` | rear yards and southern approaches have no published numeric grade | unknown, flat target |
| `r454.market.harbour_spine` | ramp along `street.pikk_harbour_spine (39,0) -> (48,31)` | `+0.10 -> 0.00` | Pikk remains the harbour-facing merchant spine; only the relative direction is supported | plausible composite |

The forum-to-throat rule follows `raekoja-plats-extents-1343.md` and `old-market-vanaturg.md`: the forum is the attested market reserve, while the eastern neck is a lane transition rather than a second square. The `0.10` and `0.00` values are authored targets and must not be described as metre readings.

### 3. `monastery_quarter`

**Local datum:** `0.0` inner district plane. This map has explicit water and causeway terrain, but no authored vertical profile.

| Profile ID | Local cell-space endpoints/area | R-454 target | Historical/source label | Confidence |
|---|---|---|---|---|
| `r454.monastery.inner_datum` | area `x=0..220, y=0..112` | `0.00` | packed-earth urban precinct; no absolute grade source | unknown, flat target |
| `r454.monastery.outer_road` | `terrain outer_wall.road x=232..252, y=0..112` | `0.00` | extramural road seam toward the harbour/Workers' District; preserve travel continuity | plausible composite seam |
| `r454.monastery.east_ditch` | `terrain outer_wall.ditch x=228..232, y=8..104` | `-0.35` visual target, acceptable `-0.20..-0.50` | water-filled outer-wall ditch is source-backed; ditch depth is not published | partial presence, authoring target depth |
| `r454.monastery.causeway` | `terrain outer_wall.causeway x=228..232, y=40..52` | `-0.10` and no step into `outer_wall.road` | authored causeway interrupts the ditch; exact raised surface height is unknown | plausible composite |
| `r454.monastery.north_inner_gate` | opening `transition to_reval_north (98..110,0)` and outer opening `(228..236,0)` | `0.00` at both seams | ordinary inner and outer road seams; do not turn the northern boundary into an unsupported cliff | partial seam rule |

The ditch row is intentionally labelled as a visual target. The project source supports the presence of a water ditch and a short causeway, not a defensible 1343 metre depth. R-455's existing ditch readability blocker remains open until a rendered mesh/camera acceptance test proves that the recessed water reads correctly.

### 4. `north_quarter`

**Local datum:** `0.0` at the ordinary inner Lower Town plane. The north edge at the Coastal Gate is the one urban-to-harbour high sill in this matrix.

| Profile ID | Local cell-space endpoints/area | R-454 target | Historical/source label | Confidence |
|---|---|---|---|---|
| `r454.north.pikk_harbour_fall` | ramp along `anchor from_reval_harbor (104,13) -> anchor pikk_street_spine (104,70)` | `+0.20 -> +0.10` | Pikk block falls toward the harbour lowland; project dossier bounds the block-scale change at `1-2 m` | plausible composite |
| `r454.north.coastal_gate_sill` | gate approach and northern opening around `x=98..115, y=0..13`, including `transition to_reval_harbor (103..110,0)` | `+0.60` at the gate sill | Coastal Gate is reported `5-8 m` above historical harbour ground on a sandstone cliff | attested relationship, authored target |
| `r454.north.outer_wall_road` | `terrain outer_wall.road x=232..252, y=0..140` | `0.00` | outer travel road is a separate low seam; avoid importing the inner gate cliff into the extramural road | plausible composite seam |
| `r454.north.monastery_seam` | openings `(98..110,136)` and `(228..236,136)` | `0.00` at the lower-town seam | preserve north-to-monastery continuity; no source establishes a southern district grade | unknown seam |

The `+0.60` value is a conservative view target for the 5-8 m historical relationship. It is not a conversion claim. A later implementation may choose another value inside the declared acceptance band if it preserves the ordering `gate sill > Pikk block > harbour wet ground`.

### 5. `south_quarter`

**Local datum:** `0.0` Lower Town plane. Southern and eastern ditches/causeways are explicitly uncertain in the historical record.

| Profile ID | Local cell-space endpoints/area | R-454 target | Historical/source label | Confidence |
|---|---|---|---|---|
| `r454.south.lower_town_datum` | area `x=144..336, y=0..96` around Rataskaevu, Niguliste, King Street and Karja | `0.00` | ordinary Lower Town baseline; no absolute southern altitude | unknown, flat target |
| `r454.south.king_to_karja` | ramp along `king_street (213,0) -> (240,71)` | `0.00 -> -0.10` | route continuity only; the dossiers do not give a measured 1343 grade | plausible composite |
| `r454.south.karja_glacis` | `terrain karja_glacis x=219..267, y=84..96` | `-0.25` visual target, acceptable `-0.10..-0.40` | muddy low approach outside/near Karja Gate; ditch and causeway treatment remain uncertain | authoring target, low confidence |
| `r454.south.garden_seam` | `transition to_archbishops_garden (24..34,0)` | `0.00` at the Lower Town opening | the lower-town side of the garden descent must meet the shared seam | partial seam rule |

This map is deliberately conservative. A future archaeological or map-authoring decision may add a local ditch ramp, but this report does not upgrade the `karja_glacis` mud band into an attested moat depth.

### 6. `toompea_quarter`

**Local datum:** existing authored `ground_elevation=2.8`. This is the only plateau datum in the current nine-map set besides `archbishops_garden`.

| Profile ID | Local cell-space endpoints/area | R-454 target | Historical/source label | Confidence |
|---|---|---|---|---|
| `r454.toompea.plateau_datum` | plateau area approximately `x=4..112, y=12..174`; use centre `(60,96)`, radius `62` for a typed area profile | `+2.80` | Toompea is a limestone tableland roughly `20-30 m` above Lower Town; current RRMap already authors `2.8` | attested relative relief, authored datum |
| `r454.toompea.pikk_jalg_descent` | ramp along `stroke pikk_jalg (143,34) -> (78,108)`; plateau endpoint `(78,108)` to gate endpoint `(143,34)` | `+2.80 -> 0.00` at the Lower Town seam | Pikk Jalg is a controlled descent from the plateau; both hill gates are wooden in 1343 | attested route, plausible exact grade |
| `r454.toompea.luhike_jalg_descent` | ramp along `stroke luhike_jalg (143,165) -> (78,108)`; plateau endpoint `(78,108)` to gate endpoint `(143,165)` | `+2.80 -> 0.00` at the Lower Town seam | Lühike Jalg is the second controlled ascent/descent; exact 1343 slope is not surveyed here | attested route, plausible exact grade |
| `r454.toompea.southern_slope` | `stroke south_slope (29,189) -> (40,150)` and `terrain southern_slope x=18..40, y=156..192` | `+0.80 -> 0.00` toward the outer boundary | southern slope is authored geometry; exact cliff/terrace profile is unresolved | plausible composite, low confidence |

The `2.8` value must remain a gameplay-scale plateau datum, not a statement that Toompea is exactly `2.8 m` high. The historical dossier supplies the `20-30 m` relative relief and the route logic; the RRMap supplies the existing implementation value.

### 7. `archbishops_garden`

**Local datum:** existing authored `ground_elevation=2.8`, continuous with the Toompea plateau. The garden is a small exterior segment, not a separate absolute elevation system.

| Profile ID | Local cell-space endpoints/area | R-454 target | Historical/source label | Confidence |
|---|---|---|---|---|
| `r454.garden.plateau_datum` | garden/orchard area `x=0..144, y=0..48`; centre `(72,24)`, radius `72` | `+2.80` | garden occupies the Toompea/Upper Town plateau; current RRMap already authors `2.8` | partial relative placement, authored datum |
| `r454.garden.toompea_seam` | opening `transition to_reval_toompea (24..34,0)` | `+2.80` on the garden side, taper to `0.00` at the shared edge only if the paired Toompea profile owns the descent | preserve plateau continuity; do not create a step between the two plateau maps | partial seam rule |
| `r454.garden.center_gate_taper` | `transition to_reval_center (142..144,5..13)` and `anchor from_reval_center (136,9)` | `+2.80 -> 0.00` across the edge taper | garden-to-Lower-Town gate seam; exact grade is not measured | plausible composite |
| `r454.garden.south_gate_taper` | `transition to_reval_south (24..34,46)` and `anchor from_reval_south (29,42)` | `+2.80 -> 0.00` across the edge taper | garden descent toward the southern district; exact grade is unknown | plausible composite |

The current map-edge taper is preferable to inventing a separate garden cliff. Any later explicit ramp must preserve the same seam result at the three transitions.

### 8. `reval_harbor_north`

**Local datum:** `0.0` low wet harbour ground. The northern water band is not a flat modern quay.

| Profile ID | Local cell-space endpoints/area | R-454 target | Historical/source label | Confidence |
|---|---|---|---|---|
| `r454.harbor_n.coastal_gate_ramp` | ramp from `anchor from_reval_north (103,102)` / `anchor coast_gate (92,95)` to `anchor quay_plaza (70,72)` | `+0.60 -> +0.10` | Coastal Gate stands `5-8 m` above historical harbour ground; descent is steep, approximately gate-to-water scale rather than a flat plaza | attested relationship, authored target |
| `r454.harbor_n.quay_to_wet_margin` | ramp `(70,72) -> (70,54)` ending at the sand/mud band | `+0.10 -> 0.00` | low wet cargo ground, short timber landings, open roadstead; exact shore line is reconstructed | plausible composite |
| `r454.harbor_n.wet_margin` | area covering `terrain water.shallow y=46..54`, `shore.sand y=54..63` and `shore.mud` bands, with shore tiles allowed to vary | `0.00` | irregular medieval sand/mud/reed margin; reconstructed shoreline, not modern engineered quay | partial/plausible composite |
| `r454.harbor_n.harbor_east_seam` | `transition to_harbor_east (0..4,67..75)` to `anchor from_harbor_east (5,70)` | `0.00` | two low wet-margin prototypes meet at the Kalamaja/harbour seam | plausible seam |

The `+0.60` gate target is deliberately below the Toompea plateau datum and is not a claim that `0.60 world units = 6 m`. The historical statement is the ordering and bounded 5-8 m relationship; the authored value is a readable implementation target.

The water, sand, mud, reed and timber pier bands are the stronger evidence for this map than any exact vertical number. The harbour dossiers reject a continuous dressed-stone quay, later fill and a modern straight shoreline.

### 9. `reval_harbor_east`

**Local datum:** `0.0` Kalamaja/Kalarand wet-margin plane. No cliff or deep urban grade is justified.

| Profile ID | Local cell-space endpoints/area | R-454 target | Historical/source label | Confidence |
|---|---|---|---|---|
| `r454.harbor_e.kalarand_shore` | shore/mud band `x=0..144, y=32..55`; centre `(72,44)`, radius `72` | `0.00` | low-density fishing shore, sand/mud/reed margin and short timber landings | plausible composite |
| `r454.harbor_e.shore_track` | authored `stroke shore_track (0,50) -> (143,49)` | `0.00` | beach track follows the irregular shore; no numeric grade source | unknown, flat target |
| `r454.harbor_e.village_edge` | `stroke village_track (18,64) -> (94,51)` and `terrain village.grass y=55..80` | `0.00 -> +0.05` | slight dry edge above the wet margin is a readability target only | plausible composite, low confidence |
| `r454.harbor_e.north_seam` | `transition to_harbor_north (140..144,47..55)` | `0.00` | low-water harbour seam; preserve the shared wet-margin datum | plausible seam |

The map remains a conservative reconstruction. The project dossiers support a medieval fishing-village identity and three short beach landings, but not a measured 1343 plot plan or a formal stone quay elevation.

## Cross-map transition rules

The following rules are part of the frozen matrix. They apply whether the later implementation uses a `grade`, `elevation_area`, `elevation_ramp`, or only the existing map-edge taper.

| Seam | Local opening IDs | Required relationship |
|---|---|---|
| Lower Town to market/civic network | `lower_town_slice` `to_reval_center`, `market_civic_quarter` centre-facing openings and forum lanes | ordinary Lower Town seam is `0.00`; no step between forum, Pikk, Viru and Karja routes |
| `north_quarter` to `reval_harbor_north` inner gate | `north_quarter.to_reval_harbor (103..110,0)` and `reval_harbor_north.from_reval_north (103,102)` | pair at the Coastal Gate sill, target `+0.60` at the gate, then descend inside harbour to `+0.10` quay and `0.00` wet margin |
| `north_quarter` to `reval_harbor_north` outer road | `north_quarter.to_harbor_outer (228..236,0)` and `reval_harbor_north.from_reval_north_outer (135,102)` | separate low travel seam at `0.00`; do not inherit the inner cliff ramp |
| `monastery_quarter` to `north_quarter` | inner openings near `(98..110,0/136)` and outer road openings near `(228..236,0/136)` | preserve `0.00` urban/outer-road continuity; ditch is local to the monastery side and must not cross the opening as a water step |
| `monastery_quarter` to Toompea | `monastery_quarter.to_reval_toompea (0..3,28..40)` and `toompea_quarter.to_reval_north (142,28..40)` | Toompea profile descends to `0.00` at the Lower Town gate; the monastery side remains `0.00` |
| Toompea to centre | `toompea_quarter.to_reval_center (142,161..169)` and centre destination seam | plateau remains `+2.80` away from the descent, but gate seam is `0.00` |
| Toompea/Garden plateau | `toompea_quarter.to_archbishops_garden` and `archbishops_garden.to_reval_toompea` | both sides retain `+2.80` plateau continuity; taper only at the eventual lower-town opening, not between the two plateau maps |
| Garden to centre/south | `archbishops_garden.to_reval_center` and `to_reval_south` | garden side may read as plateau, but every paired Lower Town opening ends at `0.00` |
| `reval_harbor_north` to `reval_harbor_east` | `to_harbor_east (0..4,67..75)` and `to_harbor_north (140..144,47..55)` | both are low wet-margin maps; seam is `0.00`, with no cliff or modern quay step |
| Lower Town to `viru_gate_foreland` | `lower_town_slice.to_viru_road_boundary (145..149,51..54)` | excluded from this matrix; if activated later, start a separate rural road profile at `0.00` and do not back-propagate it into the urban datum |

### Transition implementation constraints

1. A transition rectangle is a seam, not a new elevation feature. Its endpoint must be inside the map-edge taper or an explicit profile endpoint.
2. Inner and outer openings that share a wall must not share a profile accidentally. The Coastal Gate inner descent and the monastery/north outer travel road are separate historical and gameplay surfaces.
3. The east monastery ditch remains recessed locally. It must terminate before the outer transition and before the causeway road seam.
4. Toompea and the garden can share the existing `2.8` datum. They must not export `2.8` into the Lower Town maps through a transition opening.
5. No profile may use `cell_size=32` as a vertical multiplier.
6. If new evidence changes a target, update the profile row and its confidence/source label before changing an RRMap. Runtime changes must then be covered by the R-455 readability and mesh-alignment gates.

## Evidence register

Primary project sources used for the freeze:

- `history/dossiers/topography/lower-town-street-plan.md`: surviving street directions are alignment evidence, not a measured 1343 cadastre; Pikk is the harbour spine and the project Block B gives a bounded `1-2 m` fall toward the harbour lowland.
- `history/dossiers/topography/harbour-and-shoreline.md`: two harbour zones, Coastal Gate `5-8 m` above historical harbour ground, approximately `100 m` gate-to-open-water relationship, irregular sand/mud/reed margin and no modern continuous quay.
- `history/dossiers/topography/harjapea-mouth-shoreline-gis.md`: wet-margin confidence classes, Coastal Gate cliff step, Kalamaja reconstructed shore and explicit warning that no surveyed 1343 coastline exists.
- `history/dossiers/topography/walls-gates-towers.md`: wet/low north and southeast ground, mid-century gate circuit, unfinished/partial Viru status and exclusion of later foregates.
- `history/dossiers/architecture/toompea-castle-and-upper-town.md`: Toompea plateau roughly `20-30 m` above Lower Town, three cliff sides and Pikk Jalg/Lühike Jalg controlled descents.
- `history/dossiers/topography/raekoja-plats-extents-1343.md`: forum as open ground, relative-only archaeological street levels, pre-barbican moat and plank-on-fill possibilities near the Viru apron.
- `history/dossiers/topography/old-market-vanaturg.md`: forum-to-east-throat relationship and the distinction between the attested market and later Vana Turg fabric.
- `history/dossiers/topography/kalamaja-fishing-shore-1343.md`: bounded reconstruction for the northwest fishing shore, net yards and timber beach decks.
- `docs/reports/reval_harbour_1343_research.md`: conservative map translation for the two harbour prototypes and explicit rejection of Pirita as the Reval harbour pair.
- `docs/reports/r455_city_elevation_readability.md`: current runtime status, including `2.8` Toompea datum and the blocked authored-grade/readability gates.

Runtime/authoring references checked for units and semantics:

- `docs/MAP_AUTHORING.md`, especially the `elevation` contract and compiler version note.
- `scripts/map/map_blueprint.gd`: typed `grade`, `elevation_area` and `elevation_ramp` authoring methods.
- `scripts/map/map_definition.gd`: view-only profile validation and world-unit bounds.
- `content/maps/*.rrmap`: exact dimensions, terrain regions, anchors, spawns and transition rectangles recorded in the matrix.

## Acceptance checklist for the later implementation pass

- [ ] Keep this report as the historical source of truth for profile IDs and target relationships.
- [ ] Add runtime profiles only through the typed elevation API or its RRMap grammar extension; do not add raw runtime dictionaries.
- [ ] Preserve every existing map, anchor, spawn and transition ID.
- [ ] Verify all profile coordinates remain in local cell space and all values pass the existing world-unit validators.
- [ ] Verify paired transition openings have no visible vertical step.
- [ ] Run the focused R-455 suite and a rendered player-eye/top-down capture before claiming elevation readability acceptance.
- [ ] Keep `viru_gate_foreland` outside the urban matrix unless a separate activation decision changes its scope.
