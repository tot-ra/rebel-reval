# ADR 0025: Architectural asset pipeline, fidelity tiers and budgets

## Status

**Proposed, 2026-09-27. Awaiting maintainer acceptance.** Task: AR-02 (board R-960). Gates AR-04
(R-962) and every AR production task downstream of it (R-963..R-971). **AR-04 is blocked: no kit,
assembler or landmark code or asset may land until this line records the maintainer's acceptance
with an ISO date**, per the `AGENTS.md` scope-change rule.

Numbering: the AR pack was written against "ADR 0022", but 0022 went to realistic human characters
on 2026-09-26, 0023 to terrain relief (WB-01) and 0024 is reserved for the `.rrmap` v2 semantic layer
(WB-09). This record is therefore **0025**. Every AR contract that says "ADR 0022 budget" means this
file.

**Amended by [ADR 0032](0032-bespoke-landmark-sites-in-the-city.md), 2026-10-07:** tier B (bespoke
landmarks) is accepted for the seamless city. The K-tier kit assembly of the retired district maps
(AR-04..AR-06 as written) is removed from scope; any kit work must be re-scoped to city houses by a
new task.

## Context

The maintainer's 2026-09-26 review found the built fabric "too simplistic" and "too generic", with
Witcher 3 / Kingdom Come: Deliverance as the target
([ADR 0022](0022-realistic-human-characters.md) sets the same realistic, historically accurate baseline
for humans). The measured baseline is in
[`docs/tasks/architecture/README.md`](../tasks/architecture/README.md):

- 362 `house` records across 29 maps. 319 of them (88%) are a procedural box plus gable. 43 in
  `lower_town_slice` use 6 authored monoliths (`merchant_stone`, `merchant_timber`, `craft_boda` and
  their variants) stretched by non-uniform scale and told apart by a tint.
- The six monoliths are 9,268-15,656 triangles each, 1.0-1.6 MiB on disk, with up to 21 embedded
  512 px textures and 9-11 materials each.
- Churches, convents, the town hall, keeps and every wall tower are about 54k of GDScript that
  assembles boxes and cylinders at runtime. They reference no asset.
- AR-03 (R-961) has already given every wall and roof a 512 px albedo + normal + ORM set with
  anti-tiling from the procedurally generated `assets/materials/pbr/building_variants/` library
  (137 PNG files, about 19 MiB). The minimum tier turns the anti-tiling blend off (R-995).
- Draw-call work in July took the Lower Town probe from 15,933 to 1,789 draw calls by merging
  static view geometry per material (`MapViewStaticBatcher`).
  [`docs/PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md).

Three questions are open, and each one changes the shape of every AR production task: where the
kit/bespoke line falls, what may enter `assets/` from outside the project, and what a building may
cost. [AR-01](../reports/reval_architecture_typology_1343.md) (R-959) is the dimension source. It
defines eleven building families and deliberately leaves door and window metres, per-cover roof
pitches and the timber bay module **unknown**.

The known failure mode is **P0-209b**. The procedural Blender mammals passed every technical test,
then the maintainer rejected them visually, and the replacement task had to start again from scratch.
Buildings fill far more of the screen than animals, so the same failure costs more here.

## Decision

### 1. Tier split per AR-01 family

Two tiers. Architecture tiers are **independent of the character tiers** in
[ADR 0016](0016-tiered-character-fidelity.md). They do not mirror them.

- **K (kit-assembled).** Ordinary fabric: high count, high reuse. Built only from AR-04 parts by a
  deterministic assembler. Two size classes: **K-S** (small) and **K-L** (large).
- **B (bespoke).** Landmarks: low count, and the silhouette carries the district. Each is authored as
  its own model or model set against AR-01 cards and measured plans. A bespoke set may reuse kit
  parts for its secondary geometry, but its primary mass must be unique geometry.

| AR-01 family | Tier | Size / note | Owner |
|---|---|---|---|
| 1 Stone merchant (Diele) house | K | K-L | AR-05, AR-06 |
| 2 Timber / timber-frame merchant house | K | K-L | AR-05, AR-06 |
| 3 Horizontal-log dwelling | K | K-S | AR-05, AR-12 |
| 4 Craft *boda* / booth | K | K-S | AR-05, AR-06 |
| 5 Service and yard fabric | K | K-S | AR-05 |
| 6 Lower Town ecclesiastical (St Nicholas, St Olaf, Holy Spirit, St Catherine) | B | one set per church | AR-07, AR-10 |
| 7 Cistercian ranges (St Michael, Padise) | B | Church, claustral and stone-hall masses are B. Subordinate timber service ranges may be K-L with set-specific presets and count against K budgets. | AR-07, AR-08 |
| 8 Toompea elite | Split | St Mary's construction phase and the Small Castle are B. Vassal curiae, canon lodgings and service wings are K-L with Toompea presets (no Lower Town hoist or hatch defaults). | AR-09 |
| 9 Civic | Split | Town Hall 1343, Holy Spirit almshouse and the weighhouse are B. Guild frontage and the hoist warehouse are K-L. | AR-10 |
| 10 Fortification | B | Towers and gates are B models. Repeatable curtain runs, wall-walk and parapet are **B-modules**: bespoke family modules repeated along the fortification registry, with their own budget row. | AR-11 |
| 11 Rural and coastal | K | Dwellings, barns, sheds and camp fabric are K-S or K-L. The watermill and the post windmill are B (count of one each per map). | AR-12 |

The maintainer may move this line at acceptance. AR-04..AR-12 follow whatever this table says when
the Status line changes.

### 2. Provenance

**Meshes.**

- All K parts and every B primary mass are **authored in-house** by deterministic, checked-in
  generator scripts under `tools/` (Blender headless). They are rebuildable from source with
  a recorded checksum, and every file gets a `assets/SOURCES.csv` row.
- **External meshes** may ship in `assets/` only as **ornament on B models**: capitals, corbels,
  tracery fragments, ironwork, ridge crests, carved doors. They must be **CC0 or CC-BY 4.0**.
  Non-commercial, no-derivatives, editorial and marketplace licences that forbid redistribution in
  a source repository are rejected. Every external mesh must be reworked:
  - rescaled to the AR-01 module;
  - retopologised within the budget;
  - re-UV'd onto the shared surface library.

  External geometry is capped at **20% of a B model's LOD0 triangles**. CC-BY sources also get a
  `docs/THIRD_PARTY_NOTICES.md` entry.
- **Image-to-3D output** (Hunyuan3D, Leonardo or ComfyUI 3D routes) and commercial architecture kits
  **may not ship as building geometry**. They may be kept as blockout or reference under `generated/`
  only. This is the P0-209b precedent applied up front.

**Textures.**

- The procedural AR-03 library stays the default and does **not** have to be replaced.
- CC0 photo-scanned surfaces (for example ambientCG or Poly Haven) are allowed for tileable surface
  families. CC-BY 4.0 is allowed with a notice entry.
- AI-generated textures are allowed only for tileable albedo detail and landmark ornament atlases,
  and only when they are:
  - made seamless;
  - recorded with prompt, model and seed in the provenance row, per
    [`docs/TEXTURE_AI_GENERATION.md`](../TEXTURE_AI_GENERATION.md);
  - covered by the visual review in Decision 5.

### 3. Budgets

Triangle counts are measured on the exported runtime mesh (all primitives, indexed). "Distance" is
Godot's `visibility_range` distance in world units (1 unit = 0.87 m, `METERS_PER_WORLD_UNIT`).
LODs are **authored meshes switched by `visibility_range_begin/end`** with a 3.0-unit margin and fade
disabled, because fade is not dependable in GL Compatibility. Import-generated mesh LOD may exist as
a supplement, but it does not count towards this contract.

**Triangles and switch distances (recommended tier):**

| Tier | LOD0 max | LOD1 max | LOD2 max | LOD0 -> LOD1 | LOD1 -> LOD2 | Far |
|---|---:|---:|---:|---:|---:|---|
| K-S (assembled building) | 6,000 | 2,000 | 400 | 30 | 70 | camera far |
| K-L (assembled building) | 14,000 | 4,500 | 900 | 40 | 90 | camera far |
| B model | 60,000 | 18,000 | 4,000 | 60 | 140 | never culled inside its map |
| B set, all models of one theme resident together | 180,000 | - | - | - | - | - |
| B-module (fortification run, at most 10 units long) | 3,000 | 900 | 150 | 40 | 90 | camera far |
| K part (single kit part) | 1,500 | 500 | none (LOD2 is a whole-building proxy) | - | - | - |

- **LOD2 content.** A K LOD2 is one merged silhouette proxy per building: plinth, walls, gable and
  roof planes, with no openings. A B LOD2 keeps the skyline features: towers, gable steps and the
  roof ridge.
- **Minimum tier.** All switch distances are multiplied by **0.6**. Triangle caps do not change.
- **Grandfathering.** The six existing monoliths are exempt until AR-06 retires them.
  `merchant_timber_log` (15,656 triangles) is over the K-L cap today.

**Textures.**

| Surface kind | Max size | Channels | Rule |
|---|---|---|---|
| Tileable surface family (AR-03 library) | 1024 x 1024 (512 today) | albedo sRGB, normal (OpenGL +Y), ORM (R AO, G roughness, B metallic) | Shared by every building. Imported VRAM-compressed with mipmaps. |
| B ornament / trim atlas | 2048 x 2048 | Same three | At most **one** atlas set per B model. |
| K part | **none embedded** | - | A part declares a surface family. It never bakes a material or an image. For `assets/buildings/kit/**`, GLB `images` count = 0. |

The minimum tier has no separate texture set. It relies on mipmaps and the R-995 anti-tiling
switch.

**Materials.**

- **Kit building.** At most **6** material slots per assembled K building: primary wall, secondary
  wall/trim, timber, roof, openings/iron, plinth. Every slot resolves to a **shared** material from
  `MapViewBuildingMaterials`, keyed by (surface family, stem, quality tier).
- **Per-instance variation.** Tint, wear and age go through instance shader parameters, MultiMesh
  custom data or vertex colour, **never** a duplicated `Material` resource. The 96 houses of
  `north_quarter` must therefore share their materials.
- **B model.** At most **8** slots per B model: shared library materials plus the one atlas.
- **Per map.** At most **64** distinct building materials per resident map view, counting K and B
  together.

**Frame cost** (gameplay camera path of the quick performance report, same host and tier, before and
after):

| Measure | Recommended | Minimum |
|---|---:|---:|
| Frame p95 regression attributable to an AR task | <= +10% | <= +10% |
| Building draw calls (render-probe census) | <= 450 | <= 300 |
| Building primitives submitted per frame | <= 2.0 M | <= 0.8 M |
| One building's assembly work unit (WB-07 staged assembly) | <= 4.0 ms | <= 4.0 ms |

The 4.0 ms figure is `world_host/location_assembly_frame_budget_ms`. Numbers measured on the
development host are instrumentation. Minimum-tier acceptance on the declared Intel UHD 620 target
stays **BLOCKED on R-653**, and no AR task may claim it from another host.

**On-disk** (runtime `assets/`, consistent with
[`docs/ASSET_STORAGE_POLICY.md`](../ASSET_STORAGE_POLICY.md) and P0-183):

| Scope | Max |
|---|---:|
| Any single building GLB | 6 MiB, below the 10 MiB LFS line; P0-183 already treats about 9.5 MiB as oversized |
| Any single texture file | 4 MiB |
| AR-04 kit library, `assets/buildings/kit/**` | 24 MiB |
| Each B set (AR-07, AR-08, AR-09, AR-10, AR-11, AR-12 bespoke part) | 12 MiB |
| All of `assets/buildings/**` after the pack | 96 MiB |

AR-06 deletes the six stretched monoliths and their textures (about 11.3 MiB) when it retires them.
No AR file may need LFS. A file that would need LFS is over budget.

### 4. Instancing and streaming contract

- **Pure function.** Kit assembly is a function of (compiled `MapDefinition` fingerprint, building
  stable ID, map seed, AR-01 family, K preset). The same input always produces the same parts and
  transforms.
- **Disposable output.** Assembled geometry is view output, exactly like terrain and navigation
  nodes in [`docs/MAP_AUTHORING.md`](../MAP_AUTHORING.md). It is:
  - never persisted;
  - never saved;
  - never keyed by node path, instance ID or chunk coordinate.
- **Not blueprint-visible.** Kit parts are **not** `MapBlueprint` prefabs. WB-13 places the plot and
  AR-05 decides what stands on it. Nothing in this ADR adds an `.rrmap` statement.
- **Explicit registry.** The part catalogue is an explicit registry
  (`architecture_kit_catalogue.gd`), never a filesystem walk.
- **Collision and navigation** stay authored on the 2D plane from the building footprint. A new
  model may not change a footprint, an ID, walkability or a navigation region.
- **Ground contact.** The plinth meets the compiled ground height from
  [ADR 0023](0023-terrain-relief-as-gameplay.md), or the current near-flat ground until WB-04 lands.
- **Batching.** Within one resident chunk:
  - a (part, LOD) pair placed **4 or more** times is drawn by one `MultiMeshInstance3D` per
    (part, LOD, material slot);
  - everything else is merged per material by `MapViewStaticBatcher`.
- **Chunk boundaries.** A building that spans a chunk boundary stays one complete instance under
  `MapObjectChunkStreamer` (existing rule, [ADR 0010](0010-large-map-runtime-chunking.md)). It is
  never clipped or duplicated.
- **Staged assembly.** Assembly of one building is one resumable WB-07 work unit.

### 5. Visual acceptance protocol

No AR production task closes on green tests. Tests prove budgets, determinism and IDs. They cannot
prove the building looks right, as P0-209b showed. Every AR production task runs this protocol,
unchanged:

1. **Capture tool.** The task's own capture tool renders **real maps** that the set is placed on.
   Showcase scenes alone do not count.
2. **Framings.** Fixed camera transforms recorded in the task report:
   - default third-person camera ([ADR 0015](0015-default-third-person-camera.md)) at 6 and at
     12 units from the subject;
   - one street-axis view down the longest run of the set;
   - one far district view at the maximum orthographic zoom.
3. **Conditions.** Clear noon, dusk, moonlit night with torches, and overcast rain.
4. **Renderers and tiers.** Both quality tiers (`minimum`, `recommended`), on GL Compatibility and
   on Metal.
5. **Before/after pairs** from the identical transform. PNG, 1280 x 720, under
   `docs/reports/images/arNN_*`, within the 1.5 MiB active-plate soft cap.
6. **LOD clip.** One 10 s dolly clip through both LOD switch distances.
7. **Review sheet.** `docs/reports/arNN_visual_review.md` answers each of these checks, per plate
   group, with pass/fail and a sentence:
   1. Silhouette reads as its AR-01 family and differs from its neighbours at 12 units.
   2. No stretched texels, visible tiling seam or repeated-decal run.
   3. Plinth meets the ground. Nothing floats or sinks.
   4. No visible LOD pop in the clip.
   5. No excluded later feature from the AR-01 / `HISTORICAL_AUDIT` exclusion lists.
   6. Stone, lime render, timber, thatch and tile read as different materials under both clear and
      overcast light.
   7. Night: the set stays readable against the ADR 0018 item 7 value floor.
8. **Human sign-off.** The **maintainer or a human reviewer the maintainer names in the sheet**
   records `accept`, `amend` or `reject` with an ISO date. Agent reviewers may pre-screen but cannot
   accept.
9. **Reject means replace.** A `reject` replaces the failing geometry. It does not polish it
   (P0-209b). The task stays open.

### 6. Scope trade

The pack (AR-03..AR-13) is about 300 estimated hours. To pay for it:

- **Deferred: AR-09 (R-967), AR-10 (R-968), AR-11 (R-969) and AR-12 (R-970).** None of them may
  start until AR-05, AR-06, AR-07 and AR-08 have each passed Decision 5. They move out of the current
  wave to wave 3. This takes about 140 estimated hours out of the current wave. Lower Town, the
  Monastery District and Padise (the sets the maintainer named) go first.
- **Removed: P0-194** (refresh the stale PartBuilder full-body and townswoman closeups in
  `docs/CHARACTER_REALISM_BACKLOG.md`). ADR 0022 rebuilds every human on MPFB, so those plates would
  be recaptured against bodies that are being retired. On acceptance, P0-194 closes as superseded.

The maintainer may pick a different trade at acceptance from the candidates the AR-02 contract
lists: P0-180/P0-182 audio reduction, P0-185 view3d extractions, P0-198 ambient NPC gestures.

### 7. Relation to other ADRs

- **[ADR 0016](0016-tiered-character-fidelity.md)**: not amended. Architecture tiers are separate
  from character tiers and share no caps.
- **[ADR 0018](0018-saturated-hdr-fantasy-anime-visual-direction.md)**: already superseded by
  ADR 0022. Buildings follow the ADR 0022 realistic baseline. Only the ADR 0018 item 7 readability
  floor carries over, and Decision 5 check 7 uses it.
- **[ADR 0009](0009-map-blueprint-authoring-architecture.md)**: not amended. Kit parts are not
  blueprint-visible (Decision 4).
- **[ADR 0010](0010-large-map-runtime-chunking.md)**, **[ADR 0019](0019-seamless-contiguous-location-streaming.md)**,
  **[ADR 0023](0023-terrain-relief-as-gameplay.md)**: consumed as they stand.

## Alternatives

- **Pure in-house procedural for everything, landmarks included.** This is the current GDScript
  landmark builders, extended. Rejected: it is exactly what produced "a set of blocks" for the
  convent, and every new landmark costs a new builder with no reusable asset.
- **Licensed commercial medieval kit as the base for ordinary fabric.** Rejected: such kits are
  usually later Gothic or Central European. They carry Fachwerk and glazing defaults that AR-01
  excludes for 1343 Reval, and marketplace licences usually forbid redistribution in a source
  repository.
- **Image-to-3D for buildings.** Rejected: same failure mode as P0-209b, and there is no control
  over bay rhythm, module or IDs.
- **Keep whole-house monoliths and add more of them.** Rejected: 319 houses cannot be served by
  hand-built monoliths without stretching, and stretching is root cause 4 in the pack baseline.
- **Mirror the ADR 0016 character tiers.** Rejected: buildings are static, batched and far more
  numerous. The cost model is draw calls and materials, not skinning.

## Consequences

- AR-04 may start only after acceptance. It builds to the K part budget and emits no embedded
  textures.
- AR-05..AR-12 cite this ADR's tables for their budget lines. Their "within the ADR 0022 budget"
  wording means this file.
- Decision 3 is machine-checked by [`tools/architecture_budgets.py`](../../tools/architecture_budgets.py)
  (R-1064), invoked from `tools/verify_asset_lint.py`. It covers K/B triangle
  caps per LOD, LOD1/LOD2 siblings, zero embedded images in kit parts, material
  slot counts, and file/set byte caps. Tiers are path- or manifest-declared.
  The three pre-kit GLBs under `assets/buildings/facades/` stay grandfathered
  until AR-04 rebuilds them as kit parts. AR-13 adds the per-map variety gate
  on top.
- AR-09..AR-12 are wave 3 and wait on Decision 5 passes for AR-05..AR-08. P0-194 is superseded.
- The six stretched monoliths are grandfathered only until AR-06.
- Minimum-hardware acceptance of any building budget stays blocked on R-653. Development-host
  numbers are recorded as instrumentation, never as proof.
