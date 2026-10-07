# Urban-form task pack (streets, block form, landmark placement, seam continuity, hinterland)

Status: proposed task pack, 2026-09-30, raised by the maintainer after playing the districts.
High priority. Task board epic **R-1108**, rows **R-1109**..**R-1136** (the board allocated refs
with gaps because another session was creating rows at the same time; the row table below is the
authority for which ref belongs to which `UF-NN`). `UF-NN` ids are local names only, like `WB-NN`
in [`../world/README.md`](../world/README.md), `AR-NN` in
[`../architecture/README.md`](../architecture/README.md), `CO-NN` in
[`../coast/README.md`](../coast/README.md) and `WS-NN` in
[`../water_sky/README.md`](../water_sky/README.md).

The maintainer's words, and what each one turned out to mean in the repository:

> "Some districts feel like its just a matrix of houses, without any human design or streets. Need
> historically accurate streets."

> "We also need to rework maps to better fit each other."

> "Where is Niguliste or Oleviste. Or Toompea with its elevation."

> "We should not wait between moving between maps" - in Tallinn **and the surrounding areas**.

> "Think of Witcher 3 and KCD2 in its level of work."

This pack owns urban **form**: the street network, how blocks and building frontage derive from it,
whether that form continues across a streaming seam, and where the town's named buildings stand. It
does not own terrain relief, the streaming runtime, plot composition, dressing density, or what a
building is made of - those already have owners. See [Ownership seam](#ownership-seam).

## Measured baseline (2026-09-30)

### 1. There is no such thing as a street

The `.rrmap` grammar has 23 statement kinds. Counted directly from `content/maps/*.rrmap`:

```
anchor building camera decal elevation_area elevation_ramp exclude fade landmark map patrol
prop rrmap sign source spawn stroke style surroundings terrain terrain_rects transition wall
```

None of them is a street. A "street" in Reval Rebel today is whatever `terrain_rects` and `stroke`
leave over between individually placed `building` rows. There is therefore nothing that can be
checked: not that a lane is continuous, not that it keeps its width, not that it reaches a gate, not
that houses line it, not that it has a surface. `lower_town_slice` carries **97 `building` rows
against 63 `style` rows**, and the styles are generated variant names
(`house.east.h104.40`, `house.east.h104.41`, ...) differing by roof and wall colour. Buildings are
placed at absolute cells, so nothing ties a house to a street, and nothing notices when their
origins fall on a regular pitch. That is the mechanical cause of "a matrix of houses".

**UF-01**, **UF-03**, **UF-04** fix the representation; **UF-05**..**UF-07** re-author the maps.

### 2. There is no street register

`docs/HISTORICAL_AUDIT.md` mentions street names only in passing prose. Occurrence counts across
the whole 94 kB document: Viru 16, Karja 11, Pikk 7, Harju 5, Uus 4, Lai 3, Rataskaevu 2, Kuninga 2,
Vene 1, Suur-Karja 1, Müürivahe 1, Dunkri 1. There is no table, no trace, no width, no surface, and
no attestation status for any of them. A map author has nothing to author *from*.

**UF-02** produces the register. Everything that places a street depends on it.

### 3. Nothing checks that two maps fit each other

`MapAlignmentMath` checks that a seam's span and origin agree
(`MAP_WORLD_SEAM_SPAN_MISMATCH`, `MAP_WORLD_SEAM_ORIGIN_CONFLICT`), and the WB pack proved
navigation and residency across a seam (R-1039, R-1041, R-1043, R-1054). Nothing checks what is
*authored* on either side: ground height, street axis, street width, paving surface, the building
line, or a wall or ditch run. Two districts can stream into one continuous space and still show a
step in the ground and a street that jumps sideways.

**UF-08** adds that gate.

### 4. Niguliste does not exist, and nothing noticed

The town's named buildings are in three different states at once, and nothing in the repository knows
which state each one is in.

**Already rendered by a dedicated procedural builder.**
`scripts/map/view3d/map_view_mesh_builder_building_registry.gd` routes seven styles
(`house.town_hall`, `house.church`, `house.cathedral`, `house.guild`, `house.gatehouse`,
`house.hospital`, `house.convent.precinct`) and nine primitives (`town_hall_1343`,
`holy_spirit_chapel_1343`, `st_michaels_precinct_1343`, `st_michaels_chapel_1343`,
`st_michaels_service_wing_1343`, `stone_church`, `stone_hall`, `monastic_range`, `gatehouse`) to
exceptional builders. `map_view_mesh_builder_churches.gd` recognises `st_olaf_silhouette` by id and
assembles `st_olaf_1343` from boxes and extrusions with a west tower, four vault buttresses and five
lancets. So the Town Hall, Holy Spirit, St Olaf's and St Michael's convent **are** placed.

**Placed, but wearing an ordinary house style.** `st_catherines_church` sits in
`lower_town_slice.rrmap` with `style=house.south.h192.05` - one of the generated variant styles used
for anonymous houses - beside the `katariina_kaik` anchor. The flagship Dominican church is a
recoloured box.

**Absent, while the world already points at it.** St Nicholas' has no `building`, no `landmark`, no
primitive, no renderer entry and no anchor anywhere. Meanwhile `south_quarter.rrmap` authors
`niguliste_close`, `niguliste_lane`, `niguliste_row` and `niguliste_chapter_house`, and
`market_civic_quarter.rrmap` carries `niguliste_corner_house` and
`sign.niguliste "to st nicholas"`. There is a churchyard with no church and a signpost pointing at
nothing. St Nicholas' also appears in `docs/data/landmark_integrations.json` as narrative rows
(`beat.landmark.tallinn.st_nicholas_church_niguliste_kirik`).

The 41 `landmark_*` ids that do exist in the maps are mostly rural features
(`landmark_ancient_oak`, `landmark_bog_causeway`, `landmark_threshing_barn`) plus gate arches. No
register enumerates the town's named buildings with their implementation state, so a parish church
that does not exist is invisible to every gate in the repository.

**UF-09** adds the register and its check. The models themselves belong to the Historical landmark
remodel pack raised the same day (epic **R-1121**); **UF-10** supplies the map placement that its
LM-08 row depends on, and **UF-11**/**UF-12** cover only the landmarks that pack does not name. See
[Ownership seam](#ownership-seam).

### 5. Seamlessness stops at the town wall by design

ADR 0019 is Accepted and its membership census
([`../../SEAMLESS_STREAMING_PLAN.md`](../../SEAMLESS_STREAMING_PLAN.md)) assigns all 29 maps to
exactly one kind: 10 streamed (`reval_outdoor`), 9 interiors on doors, 10 travel. **Every** `world.*`
map is travel-only, and a validator is specified to *reject* a travel transition authored as a
physical seam. So "no waiting between maps" is currently scoped to inside Reval only. Extending it
past the wall is a scope change, not a bug.

**UF-14** decides it; **UF-15** builds it.

### 6. The relief chain was standing on an unaccepted ADR - resolved 2026-09-30

`docs/adr/0023-terrain-relief-as-gameplay.md` Status read **"Proposed, 2026-09-26. Awaiting
maintainer acceptance"**, and its own text said "No relief code may land until this line records the
maintainer's acceptance with an ISO date." Meanwhile R-974 (relief compiler) and R-975 (relief
gameplay) were in review and R-1003 / R-1022 / R-1023 / R-1024 had landed relief-dependent water
changes. Toompea is still authored at `elevation=2.8` (about 2.4 m) for a hill that stands 20-30 m
over the Lower Town.

**Decision: ADR 0023 is `Accepted, Artjom Kurapov, 2026-09-30`** (UF-00 / R-1109, closed). The
`Accept` row of the UF-00 outcome matrix is in force: R-973 closes its decision gate, R-974 and R-975
continue to their own acceptance, R-976 follows R-975, and **UF-07 / R-1116** is released from this
gate once R-1113 and R-976 are done. The inherited ADR blocker also clears on R-981, R-983, R-985,
R-986, R-1122 and R-1133. No implementation, Canon or QA evidence is waived, and the sequencing
breach is recorded in the ADR rather than excused.

## Rows

| Row | Board | Deps | Theme | Summary |
|---|---|---|---|---|
| ~~UF-00~~ | **R-1109** | none | Governance | **Done 2026-09-30** - ADR 0023 accepted by Artjom Kurapov; breach recorded, UF-07 released from the ADR gate |
| UF-01 | **R-1110** | none | Streets | ADR 0026: streets are an authored network, not the gap between buildings |
| UF-02 | **R-1111** | none | History | 1343 Reval street, lane and open-space register with attestation |
| UF-03 | **R-1112** | R-1110 | Streets | `street` primitive, compiled `StreetNetwork`, street diagnostics |
| UF-04 | **R-1113** | R-1112, R-1111 | Streets | Frontage binding, block subdivision, anti-grid regularity gate |
| UF-05 | **R-1114** | R-1113, R-1111 | Maps | Street network on `lower_town_slice` and `market_civic_quarter` |
| UF-06 | **R-1115** | R-1114 | Maps | Street network on the monastery, north and south quarters |
| UF-07 | **R-1116** | R-1113, R-976, R-1109 | Maps | Toompea ramps and plateau streets on real relief |
| UF-08 | **R-1117** | R-1114, R-980 | Seamless | Seam form-continuity gate: height, street, surface, frontage, wall |
| UF-09 | **R-1118** | R-1111 | Landmarks | 1343 landmark placement register and its fail-closed gate |
| UF-10 | **R-1119** | R-1118, R-1114, R-1134, R-1123 | Landmarks | Place St Nicholas' on the map: record, anchor, churchyard, truthful signpost. Model is LM-08 |
| UF-11 | **R-1120** | R-1118, R-1115, R-1123 | Landmarks | St Olaf's and the Great Guild 1343 exteriors. Town Hall and Holy Spirit moved to LM |
| UF-12 | **R-1122** | R-1116, R-1118, R-1123, R-1128 | Landmarks | The Dome Church, plus relief bedding for the whole Toompea compound. Castle moved to LM-04 |
| ~~UF-13~~ | ~~**R-1125**~~ | - | Landmarks | **Cancelled** - St Catherine's is LM-02 and St Michael's is LM-05 |
| UF-14 | **R-1129** | R-980 | Seamless | ADR 0027: a second streaming group for the Reval hinterland. **Scope approved 2026-09-30**; [ADR 0027](../../adr/0027-reval-hinterland-streaming-group.md) written 2026-10-07. In-place building interiors are [ADR 0028](../../adr/0028-seamless-building-interiors.md) |
| UF-15 | **R-1133** | R-1129, R-980, R-1213, R-1215, R-1216, R-1217 | Seamless | Hinterland connective maps and the second world layout. Not claimable until a Dev owner is named on R-1217 (ADR 0027 section 4) |
| UF-15a | **R-1213** | R-1129, R-1166 | Maps | Harju Gate aperture on the `south_quarter` south curtain - no map has one today |
| UF-15b | **R-1215** | R-1129, R-951 | Maps | Landward aperture on `reval_harbor_east`, which today has only `to_harbor_north` |
| UF-15c | **R-1216** | R-1129 | Maps | Viru-road junction aperture on `world.sojamae` |
| UF-15d | **R-1217** | R-1129 | Seamless | Multi-group world layout and allowlisted gate bridges in the layout tool (**Dev owner required**) |
| UF-16 | **R-1136** | R-1114, R-1115 | Quality | District master plans and a street-legibility visual gate |

Ordering note: **UF-01**, **UF-02** and **UF-14** have no dependencies inside this pack and can start
immediately. UF-00 is closed. UF-14 no longer waits on the maintainer for the *decision* - the scope
was approved on 2026-09-30 - but it still has to author the ADR, the census amendment and the budget
tables, and it still depends on R-980. UF-02 is pure research and unblocks the whole map chain, so it
should start first among the agent rows.

## Scope discipline

Three rows are scope changes under `AGENTS.md` and ship an ADR before any code:

- **UF-01** (R-1110) - a new authoring primitive. [ADR 0026](../../adr/0026-streets-as-authored-network.md)
  is **Proposed, 2026-09-30**. Named WB-09 owner agreement to retiring R-981's independent
  free-form geometry and named maintainer approval/acceptance remain pending. UF-03 is blocked.
- **UF-14** (R-1129) - a second streaming group past the town wall. Reserves **ADR 0027**. The
  maintainer **approved the scope on 2026-09-30**, including the equivalent-cost removal of WB-11
  deliverables 4 and 7 (interactive relief sculpting, docked live 3D preview). Writing the ADR with
  `Accepted, Artjom Kurapov, 2026-09-30` is now documentation of a decision already taken; it is not
  permission to widen the membership beyond the recommendation.
- **UF-00** (R-1109) - not a new scope change, but it unblocked one that already shipped code.
  Closed: ADR 0023 accepted 2026-09-30.

ADR numbers as of 2026-09-30: **0023 is merged and accepted**, **0024 is reserved by WB-09**
(R-981, `.rrmap` v2 semantic layer), 0025 is merged (AR-02, architectural asset pipeline). A number
reserved in prose is not a lock: before writing a reserved ADR, run `ls docs/adr/` and
`grep -rn "ADR 00NN" docs/tasks project task board`, take the next free number, and sweep every contract and
`TODO.md` row that cites the old one in the same commit.

The asset freeze (**P0-040**) applies to UF-11 and UF-12, which add production art. Each names its exact
files and needs `assets/SOURCES.csv` rows.

No row in this pack may begin implementation before its ADR is merged or human-approved.

## Ownership seam

Four packs were raised from the same complaint about how the world looks, from different layers.
They must not be merged, and the boundary has to stay sharp.

| Concern | Owner |
|---|---|
| What a building is **made of** - bays, storeys, gables, openings, pitches, PBR surfaces, the modular kit | **AR-04**..**AR-12** |
| Building **appearance** repetition: distinct silhouettes, nearest identical neighbour, part reuse | **AR-13** |
| **Where a street is**, its identity, trace, width, surface, class, and continuity | **UF-01**..**UF-07** |
| How buildings **line a street**: frontage binding, block subdivision, placement regularity | **UF-04** |
| How buildings sit on a **plot**: depth, rear service range, yard, plot wall, gate | **WB-13** |
| **Terrain** relief and what stands on it | **WB-01**..**WB-04** |
| **Dressing and ground** density: props, decals, vegetation, ground cover | **WB-10** |
| **Streaming runtime** and loading screens inside Reval | **WB-05**..**WB-08** |
| **Streaming membership** past the town wall, and the maps that make it contiguous | **UF-14**, **UF-15** |
| Cross-seam continuity of **authored form** | **UF-08** |
| **Named landmark** register: existence, implementation state, 1343 phase, anchor binding | **UF-09** |
| Placing a named landmark on a map: `.rrmap` record, anchor, close, signage, layout rebuild | **UF-10** |
| A named landmark's 1343 **model**, massing and weathering | **LM-01**..**LM-08** (epic R-1121) |
| Landmarks the LM pack does not name (St Olaf's, the Great Guild, the Dome Church) | **UF-11**, **UF-12** |
| The **Kalamaja shore** itself, its ground materials, debris and level ladder | **CO-01**..**CO-04** |
| **Authoring surface**: `.rrmap` v2 and the editor | **WB-09**, **WB-11** |

Interlocks that will bite if ignored:

- **UF-01 and WB-09 (R-981).** WB-09 plans a `.rrmap` v2 semantic layer with plots. UF-01 must name
  the overlap explicitly and shrink one of the two: the agreed position is that UF-03 owns the street
  geometry vocabulary and WB-09 consumes it rather than inventing a second one. UF-01 amends
  `../world/WB-09_rrmap_v2_semantic_layer.md` in the same change.
- **UF-04 and WB-13 (R-985).** WB-13 composes the plot a house stands on; UF-04 decides which street
  that plot faces and how the frontage varies. UF-04 must adopt WB-13's tier vocabulary verbatim if
  WB-13 lands first, and must not invent a parallel one.
- **UF-04 and AR-13 (R-971).** AR-13 measures building *appearance* repetition. UF-04 measures
  *placement* regularity. Both write a verifier and both have thresholds; they must stay separate
  files with separate budget JSONs, and neither may assert the other's metric.
- **UF-05, WB-14 (R-986) and AR-05 (R-964).** All three change `lower_town_slice`. Run UF-05 **first**
  so density and material work lands on a real street plan, then WB-14, then AR-05's renderer work.
  Never concurrently: all three demand a clean `git diff --stat content/maps/`.
- **UF-06 and R-285.** R-285 (monastery ordinary fabric) is in review on `monastery_quarter`. Do not
  land both at once.
- **UF-07 and WB-04 (R-976).** WB-04 authors the relief field; UF-07 authors the ways that climb it.
  UF-07 must not edit relief to make a ramp fit - it raises a WB-04 amendment instead.
- **UF-10..UF-12 and the Historical landmark remodel pack (epic R-1121, rows R-1123..R-1135).** That
  pack was raised the same day, from the same maintainer session, and it owns the 1343 dossier, the
  model and the weathering for St Catherine's (LM-02), Holy Spirit (LM-03), the Toompea castle
  (LM-04), St Michael's (LM-05), the Karja Gate (LM-06), the wall and drum towers (LM-07),
  St Nicholas' (LM-08) and the Town Hall (R-1135), through the LM-01 weathering kit
  (`map_view_landmark_weathering.gd`). This pack therefore keeps the register, the map placement that
  LM-08 asks for, and only the landmarks LM does not name. No row here authors a parallel wear system
  or a second renderer for a landmark LM already builds. UF-13 was cancelled as a full duplicate.
- **UF-12 and AR-09 (R-967).** AR-09 builds the Toompea architectural kit; UF-12 places the cathedral
  and owns the compound's relief bedding. UF-12 consumes AR-09's kit if it lands first.
- **UF-15 and CO-04 (R-951).** CO-04 owns the Kalamaja shore's level ladder. UF-15 owns the maps that
  connect the shore to the town. CO-04 lands first, or UF-15 consumes it by explicit agreement
  recorded in both contracts.
- **UF-16 and the world-building visual gate.** `tools/verify_world_building_visual_gate.py` already
  exists and is shared. UF-16 extends it; it does not fork it.

## Reference bar

Kingdom Come: Deliverance and The Witcher 3 are cited only as a target for street legibility,
irregularity and landmark dominance. Neither justifies scope by itself; every row above still carries
its own gate and its own verification command.
