# ADR 0032: Bespoke landmark sites in the seamless city

## Status

**Accepted, Artjom Kurapov, 2026-10-07.** Maintainer request in session: "a system to have custom
3D models for buildings placed in the game ... historically accurate famous buildings and places we
have in Tallinn", internally navigable, and detailed enough to read well from the top-down camera
(reference: a town-square concept with a custom well, market stalls, banners, custom roof and
arches).

Maintainer decisions recorded at acceptance (2026-10-07):

- **Scope removal:** all three candidates under [Scope cost](#scope-cost) are removed.
- **Period rule:** strict spring 1343 (decision 5). The concept's arcade, crenellations and tower on
  the council hall are not modelled.
- **Authoring:** interim GDScript ports of the existing 1343 landmark models first, each replaced
  later by a Blender-headless generated GLB (decision 3).
- **First site:** `site.raekoja_plats`.

Depends on [ADR 0025](0025-architectural-asset-pipeline.md) (architectural asset pipeline, tiers and
budgets), which is still *Proposed* as a whole. Accepting this ADR accepts 0025's **B tier**
(bespoke landmarks: provenance, budgets, review) for the seamless city of
[ADR 0031](0031-continuous-reval-city-plan.md). Units here are metres (the city uses 1 m per world
unit; 0025's tables are written for 0.87 m units and apply unchanged in metres).

## Context

- Every building in the city is a generic shell from its plot footprint
  (`CityBuildingBuilder`, documented in
  [`SEAMLESS_CITY.md`](../SYSTEMS/SEAMLESS_CITY.md#how-buildings-are-built)). Churches, the council
  hall and the castle are massing boxes with lancets. From the top-down camera all of them read as
  the same building at different sizes.
- The district maps already had hand-built 1343 landmark models: `map_view_town_hall_model.gd`,
  `map_view_st_olaf_model.gd`, `map_view_mesh_builder_churches.gd`, the wells
  (`map_view_well_models.gd`), market stalls, carts, banners. The city does not use them.
- Interiors are generic too: one room per footprint, floor level with the highest ground under it.
  On Toompea that put St Mary's west door 5.2 m above Kiriku plats on a stair. That bug is fixed in
  the generic compiler (levelled terraces for churches, chapels and the hall, 2026-10-07), but a
  terrace does not make a cathedral.
- Navigation is a logic plane (`CharacterBody2D`, 32 px per metre) with authored collision, not
  navigation derived from meshes ([`MAP_AUTHORING.md`](../MAP_AUTHORING.md)). A custom model must
  therefore bring its walk data with it.
- The game is set in spring 1343. Several famous Tallinn looks are later:
  - the town hall arcade (1402–04) and tower (1370s–1400s);
  - St Olaf's spire (15th century);
  - the Great Guild hall (1407–17);
  - Fat Margaret and Kiek in de Kök (15th century).

  The dossiers record what stood in 1343
  ([`raekoja-plats-extents-1343.md`](../../history/dossiers/topography/raekoja-plats-extents-1343.md),
  [`churches-and-religious-houses.md`](../../history/dossiers/religion/churches-and-religious-houses.md)).

## Decision

### 1. A site is the authored unit

A **site** is one famous building or place together with its surroundings: the building or
buildings, its ground, its interior, its square and its dressing. Examples are
`site.raekoja_plats` (forum and council hall), `site.kiriku_plats` (Toompea church square and
St Mary's) and `site.st_olaf`.

Each site has one manifest, `content/world/reval_city/sites/<site>.json`. Every site is registered
explicitly in `content/world/reval_city/sites/registry.json`, which both the compiler and the runtime
(`CitySiteRegistry`) read; sites are never discovered by walking the filesystem. The manifest fields
are:

| Field | Meaning |
|---|---|
| `id`, `name_1343`, `confidence`, `sources` | Stable ID, period name, confidence label, dossier links |
| `replaces` | Plan building IDs the site removes from the generic builder (by stable ID) |
| `anchor` | Georeferenced position in plan metres and a rotation; the model's local origin |
| `terrace` | Ground the site needs: a polygon, its level (or per-vertex levels), the blend width; the compiler writes it into the heightfield |
| `visual` | The view: `{"kind": "scene", "path": "res://assets/buildings/landmarks/<site>/<site>.tscn"}` or, as an interim, `{"kind": "builder", "script": "res://scripts/city/sites/<site>_builder.gd"}` |
| `walk` | Logic-plane data in site-local metres (below) |
| `rooms` | Interior regions: floor level, which view nodes hide while Kalev is inside (roof, ceiling, upper level), camera occluder volumes |
| `doors` | Door leaves: hinge, width, height, swing, style; driven by `CityDoors` |
| `dressing` | Props from a prop catalogue (well, stalls with awnings, barrels, carts, banners, lanterns, pillory, scaffold), each with an ID and a transform |
| `anchors` | Gameplay anchors (NPC posts, interaction points, quest anchors) with stable IDs |
| `minimap` | Footprint and fill colour painted into `minimap.png` |

### 2. Navigation is authored data, checked against the model

`walk` holds:

- `solid`: polygons Kalev cannot enter, such as piers, buttresses and the well;
- `walls`: wall segments with thickness, and door gaps by door ID;
- `floors`: polygons with a floor height or a height function, for nave, aisles, porch and dais;
- `ramps`: stairs as ramps between floor heights.

`CityPlan.walk_height` and `building_at` consult site floors before the generic rules.

A validator (`tools/validate_city_sites.gd`, headless) rejects a site when:

- a door does not connect the outside to a floor;
- a floor is unreachable;
- a wall crosses a door gap;
- the visual mesh and the `walls` disagree by more than 0.25 m in a top-down raster comparison.

The model is never used for collision directly.

### 3. Visual source follows ADR 0025 tier B

- **Final models** are authored in-house by checked-in, deterministic Blender-headless generator
  scripts under `tools/assets/landmarks/`. They export GLB under
  `assets/buildings/landmarks/<site>/`, with a `SOURCES.csv` row, LOD0/1/2 and ADR 0025 budgets:
  - LOD0 ≤ 60k triangles;
  - ≤ 8 material slots;
  - ≤ 12 MiB per set.
- **Interim** builders are GDScript on the city's mesh tools. Porting the existing 1343 district
  models (town hall, St Olaf, churches, wells, stalls) to metres is the first step, so every site is
  visible early.
- Image-to-3D output and commercial kits may be used as blockout and reference only, never shipped
  (0025 decision 2, the P0-209b precedent).
- Roofs, upper floors and ceilings are separate, named nodes so they can be hidden for the top-down
  and first-person cameras while Kalev is inside, as generic houses already do.

### 4. Detail aimed at the top-down camera

Sites carry what reads from above:

- distinct roof forms and colours, crests, dormers and ridge tiles;
- stepped or crenellated gables where attested;
- paving patterns, gutters and well heads;
- awnings, banners, carts and goods.

The splat painting of a site (cobble pattern, wear lines and puddle hollows) comes from its manifest.

### 5. Period rule

Sites show the building as it stood in **spring 1343**, per the dossiers and `docs/CANON.md`
confidence labels. A later feature may be shown only as a **presentation choice the maintainer
records in the manifest**, as ADR 0031 did for the finished south walls and the Viru towers
(`"presentation": [...]` with the date and reason). The default is the dossier.

### 6. Integration

- The compiler (`build_reval_city_plan.py`):
  - reads the site manifests;
  - drops the `replaces` buildings from the generic set;
  - applies the `terrace`;
  - keeps trees, shrubs and grass off the site;
  - paints the minimap and splat.
- At runtime `CityWorld3D` instantiates each site's `visual` at its anchor. The site's walls, solids
  and door gaps join `CityCollisionBuilder`, its doors join `CityDoors` and its rooms join the
  roof-lifting logic. Dressing comes from the prop catalogue, and anchors are exposed to quests and
  NPC placement (`CityNpcs`).
- A site is all-or-nothing. A manifest that fails validation is skipped with an error, and the
  generic buildings it would replace stay.

### 7. First sites, in order

1. `site.raekoja_plats`: the 1343 council hall (one storey, no arcade or tower unless a
   presentation choice is recorded), the forum paving, a well, market stalls, the pillory per
   `forum-pillory-placement-1337.md`, banners.
2. `site.kiriku_plats`: St Mary's (Toomkirik) in its Gothic nave rebuild with scaffolding and a
   masons' yard, and the church square.
3. `site.st_olaf`: hall church with the massive unfinished west tower (port of the existing model).
4. `site.st_nicholas`, `site.holy_spirit` (church and almshouse), `site.st_catherine` (Dominican
   friary).
5. `site.st_michael` (Cistercian nunnery), `site.toompea_castle` (small castle and courtyard).
6. Gates as sites: `site.viru_gate`, `site.coastal_gate`, replacing the generic gate houses.

Each site is its own task with allowed files, the validator, a walk-in test (every door, every
floor), and top-down, street and interior review plates compared against its dossier.

## Alternatives

- **Hand-place GLBs with mesh collision.** This breaks the logic-plane architecture. Collision from
  render meshes is noisy for a character capsule and would not drive the roof-lifting, door or
  minimap systems. Rejected.
- **Keep improving the generic builder** (more parameters per landmark). It cannot produce towers,
  aisles, arcades or scaffolds, and every parameter becomes a special case. Rejected for landmarks;
  the generic builder stays for ordinary houses.
- **Image-to-3D landmark meshes.** Fast, but ADR 0025 forbids shipping them, and the P0-209b animals
  showed the cost of a visual rejection after technical acceptance. Allowed as blockout only.
- **One giant hand-made city model.** Loses georeferencing, stable IDs and the ability to rebuild the
  plan. Rejected.

## Consequences

- The city gains a second content type next to the compiled plan. Sites are versioned data plus a
  model, and the compiler and runtime must both honour `replaces` and `terrace`.
- `CityPlan` walk and floor queries become two-stage (site floors, then generic rules). Generic
  houses are unaffected.
- Per-site review cost is real: each site needs its dossier check, its validator pass and a
  maintainer visual sign-off (ADR 0014 authorial gates).
- Performance: each site counts against ADR 0025's B budgets. The city's current frame-time problem
  (the runtime and NPC rigs, see `SEAMLESS_CITY.md`) must be fixed first or in parallel, or detailed
  sites will make it worse.

## Scope cost

AGENTS.md requires removing scope of equivalent cost. **All three were removed at acceptance
(2026-10-07):**

- **ADR 0025 kit tier for the district maps (AR-04..AR-06 as written).** The districts are retired
  from play by ADR 0031, so kit-assembling their 362 houses no longer reaches the player. The kit
  work would be re-scoped to city houses later or dropped.
- **District-map migration and parity work** in `docs/MAP_CONVERSION_PLAN.md` for the redirected
  districts (`lower_town_slice`, `market_civic_quarter`, `north_quarter`, `monastery_quarter`,
  `south_quarter`, `toompea_quarter`, `archbishops_garden`).
- **ADR 0028 in-place interiors for the district maps** (scene-swap interiors stay where they are),
  since city sites carry their interiors in place by construction.
