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

### Decision matrix for the elevation authoring pass

The table below is the compact authoring contract. The detailed profile rows later in this report remain the source of truth for local coordinates and exact target values. `Protected IDs` are existing stable transition/building IDs that an elevation pass must preserve; the list intentionally names the route and landmark anchors most likely to be affected rather than introducing new IDs.

| Map | Historical source dossier(s) | Required profile kind(s) | Expected sign/direction | Target height band (world units) | Ditch/causeway involvement | Protected IDs |
|---|---|---|---|---:|---|---|
| `lower_town_slice` | `lower-town-street-plan`; `viru-vanaturg-paving-archaeology`; `walls-gates-towers` | flat datum; Pikk fall; south seam | ordinary Lower Town `0.0`; slight fall toward north harbour margin | `0.00..+0.20` | No new ditch profile in the active slice; do not import later Viru foregate relief | transitions `smithy_door_transition`, `viru_road_boundary`, `workers_outer_wall_road`, `to_reval_south`; buildings `viru_gate_north_tower`, `viru_gate_south_tower`, `st_catherines_church`, `kalev_smithy` |
| `market_civic_quarter` | `raekoja-plats-extents-1343`; `old-market-vanaturg`; `lower-town-street-plan` | forum area; east-throat fall; harbour-spine ramp | forum remains `0.0`; slight fall east and toward the wet north | `-0.10..+0.10` | No authored ditch; pre-barbican moat evidence remains a source constraint, not a new profile | transitions `to_reval_east`, `to_reval_north`, `to_reval_toompea`, `to_archbishops_garden`, `to_reval_south`, `to_town_hall`; buildings `town_hall_mass`, `church_silhouette`, `guild_frontage` |
| `monastery_quarter` | `walls-gates-towers`; `ecclesiastical-precinct-boundaries-1343`; `lower-town-street-plan` | inner datum; outer road seam; recessed ditch; causeway | district and road `0.0`; ditch below road; causeway rises toward road | `-0.50..0.00` | East outer-wall ditch is local; causeway interrupts it and must terminate before the outer transition | transitions `to_reval_north`, `to_reval_north_outer`, `to_reval_east_outer`, `to_reval_toompea`, `to_oleviste_church`; buildings `monastery_city_wall_east`, `st_michaels_convent`, `convent_chapel`, `st_olaf_silhouette` |
| `north_quarter` | `harbour-and-shoreline`; `walls-gates-towers`; `lower-town-street-plan` | Pikk fall; Coastal Gate sill; separate outer-road seam | inner gate is high relative to harbour; Pikk falls north; outer road stays low | `0.00..+0.60` | No ditch/causeway profile at the Coastal Gate; keep the gate descent separate from the outer road | transitions `to_reval_harbor`, `to_harbor_outer`, `to_monastery`, `to_monastery_outer`; buildings `coast_gate_west_tower`, `coast_gate_east_tower` |
| `south_quarter` | `walls-gates-towers`; `lower-town-street-plan`; `ecclesiastical-precinct-boundaries-1343` | flat datum; King-to-Karja fall; Karja glacis; garden seam | Lower Town baseline `0.0`; slight fall toward the southern/eastern low ground | `-0.40..0.00` | Karja glacis may read as low mud; ditch depth and causeway geometry remain unresolved | transitions `to_reval_center`, `to_reval_east`, `to_archbishops_garden`, `to_world_sacred_grove`; buildings `karja_gate_west_tower`, `karja_gate_east_tower`, `knights_hall` |
| `toompea_quarter` | `toompea-castle-and-upper-town`; `walls-gates-towers` | plateau area; two descent ramps; southern slope | plateau `+2.8`; both Jalg descents taper to the Lower Town seam | `0.00..+2.80` | No urban ditch in the profile; castle/moat fabric stays represented by existing structures, not a new vertical moat | transitions `to_reval_center`, `to_reval_north`, `to_archbishops_garden`, `to_world_padise`; buildings `pikk_jalg_gate_tower`, `luhike_gate_tower`, `castle_mass`, `cathedral_silhouette` |
| `archbishops_garden` | `toompea-castle-and-upper-town`; `ecclesiastical-precinct-boundaries-1343` | plateau area; Toompea seam; centre/south tapers | retain plateau `+2.8`; taper only at Lower Town openings | `0.00..+2.80` | No independent ditch/causeway; garden shares the plateau datum with Toompea | transitions `to_reval_toompea`, `to_reval_center`, `to_reval_south`; buildings `center_gate_north_tower`, `center_gate_south_tower`, `cathedral_garden_wall_north` |
| `reval_harbor_north` | `harbour-and-shoreline`; `harjapea-mouth-shoreline-gis`; `walls-gates-towers` | Coastal Gate ramp; quay-to-wet ramp; wet-margin area | descend from gate sill to low cargo ground and then to wet margin | `0.00..+0.60` | No modern quay or engineered basin; wet margin is irregular water/sand/mud/reed ground | transitions `to_reval_north`, `to_reval_north_outer`, `to_harbor_east`; buildings `great_coast_gate`, `cargo_shed_west`, `warehouse_mid` |
| `reval_harbor_east` | `harbour-and-shoreline`; `kalamaja-fishing-shore-1343`; `harjapea-mouth-shoreline-gis` | wet-margin area; shore track; village-edge taper | flat wet margin; only a slight dry-edge rise | `0.00..+0.05` | No cliff, ditch, causeway or modern quay; preserve the fishing shore as a low wet margin | transition `to_harbor_north`; buildings `fisher_hut_west`, `net_house_mid`, `boatwright_shed` |
| `viru_gate_foreland` | `docs/reports/pirita_1343_research.md`; RRMap source notes | **Separate future rural/world-edge profile, not an urban profile** | start at `0.0` if activated; do not back-propagate a rural grade into Lower Town | `0.00` baseline until separately authored | River crossing and meadow belong to the extramural profile decision; no city ditch/causeway relationship | transitions `to_reval_east`, `to_world_harju`; no urban landmark/building IDs are protected by this matrix |

`viru_gate_foreland` is listed here so the scope decision is explicit. It is not one of the nine urban exterior maps and must not silently inherit the Lower Town or harbour profile.

### Flat interior and developer-only map inventory

The current `content/maps` inventory contains five non-exterior room maps. They remain flat because their transitions are door or room seams, not authored terrain relief. This is an explicit inventory, not a blanket exclusion: if a room later gains a staircase or vertical gameplay layer, that must be a separate decision and must not reuse an exterior profile ID.

| Map | RRMap dimensions | Scope / active | Flat target | Protected transition IDs | Protected building / room IDs | Reason |
|---|---:|---|---:|---|---|---|
| `kalev_smithy` | `26 x 14` | production / active | `0.00` | `door_courtyard`, `smithy_start_spawn` | `kalev_smithy`, `interior_window.north_forge`, `interior_window.north_living` | Forge and living bay are interior room geometry; the door transition owns the exterior seam. |
| `town_hall` | `40 x 24` | prototype / inactive | `0.00` | `to_reval_center` | `town_hall` exterior door contract, `council_dais_block`, `burghers_pillar_north`, `burghers_pillar_south` | Interior room sequence; the 1343 hall footprint is a separate exterior landmark in the civic map. |
| `holy_spirit_church` | `30 x 22` | prototype / inactive, developer-only | `0.00` | `to_reval_center` | `altar_block`, `interior_window.north_center`, `interior_window.north_east` | Church greybox has no defensible historical vertical datum in this task. |
| `oleviste_church` | `36 x 24` | prototype / inactive, developer-only | `0.00` | `to_reval_monastery` | `wall_north`, `wall_south_west`, `wall_south_east`, `altar_block` | Interior greybox; preserve the room shell and its monastery door seam. |
| `st_olafs_guild_hall` | `32 x 20` | prototype / inactive, developer-only | `0.00` | `to_reval_center` | `wall_north`, `wall_south_west`, `wall_south_east`, `dais_block` | Interior greybox; no exterior terrain profile belongs in the hall. |

The remaining `content/maps/world_*.rrmap` files are rural/world maps, not interior or developer-only room maps. They are outside this urban matrix and this flat-room inventory. Their terrain decisions remain owned by their separate world-map scope.

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
