# Compact map authoring

This document defines the production authoring contract for programmatic maps. It is normative for new map work and should be read with [ADR 0009](adr/0009-map-blueprint-authoring-architecture.md) and [ADR 0010](adr/0010-large-map-runtime-chunking.md). The parser, typed blueprint model, compiler, registry audit, representative parity migration, editor preview, and chunk-safe persistence boundary are implemented. Unmigrated maps may continue to construct `MapDefinition` directly until they are migrated one at a time under the gates below.

## Goals

- Give humans and AI agents a compact, typed vocabulary that expresses intent instead of runtime dictionaries.
- Keep the existing `MapDefinition` contract stable for builders, navigation, collisions, transitions, audits, and the 2D and 3D views.
- Make repeated structures reusable without hiding their local geometry or gameplay IDs.
- Produce deterministic, reviewable output with actionable validation errors and stable fingerprints.
- Preserve exact author control for exceptional composition without adding a general raw-data back door.
- Keep generated Godot nodes disposable and keep large-map chunking independent from semantic authoring.
- Support incremental migration with mechanical and visual parity evidence.

Non-goals for the first implementation are a visual level editor, a new runtime map contract, a custom YAML/JSON grammar, arbitrary procedural generation, seamless-world streaming, and a universal raw `Dictionary` escape hatch.

## City terrain presentation in RRMap

City surface detail is automatic and requires no scene nodes, imported meshes, or
per-map installation. Paint the normal terrain IDs in `.rrmap`; the 3D view uses a
cheap seamless material in top-down mode and builds range-limited micro geometry
only in first-person mode:

```text
terrain market_street cobblestone 12 18 30 5 order=10
terrain guild_lawn grass 12 24 18 8 order=11 style=veg.grass.flowers
style veg.grass.flowers style_variant=grass.flowers
```

`cobblestone` and `castle_paving` receive rounded paving. `grass`, `meadow`,
`forest_floor`, and `bog` receive mixed blade grass, seed heads, clover, and ferns.
Use an optional vegetation style (`grass.short`, `grass.tall`, `grass.flowers`,
`grass.dry`, `grass.mossy`, `grass.clover`, or `grass.fern`) to bias the mix. The
RRMap editor/plugin only needs to be enabled as documented in
[`MAP_ALIGNMENT_EDITOR.md`](MAP_ALIGNMENT_EDITOR.md); runtime detail remains a
derived view and never changes collision, navigation, or the map fingerprint.

## Architecture and terminology

```text
human or AI author
        |
        v
MapBlueprint factory        <- source of truth
  metadata + primitives
  prefab instances
  exact placements
  allowlisted overrides
        |
        v
MapBlueprintCompiler
  source validation
  prefab expansion
  stable-ID resolution
  coordinate conversion
  canonical ordering
  fingerprinting
        |
        v
MapDefinition               <- existing runtime contract
        |
        +--> MapBuilder / navigation / collision / gameplay
        +--> 2D and 3D renderers
        +--> runtime node assembly
        +--> optional runtime chunk index
```

| Term | Meaning |
|---|---|
| **MapBlueprint** | The human/AI-authored semantic source for one map. Initially this is a typed GDScript factory using named APIs, not a raw nested dictionary. |
| **MapBlueprintCompiler** | A pure compiler that validates and expands a blueprint into the existing `MapDefinition` runtime contract. |
| **MapDefinition** | The current runtime data consumed by map builders and systems. It is compiler output for migrated maps, not the preferred authoring surface. |
| **Primitive** | The smallest supported semantic operation, such as a terrain rectangle, wall run, prop, transition, or anchor. |
| **Prefab** | A reusable composition of primitives in a named local cell coordinate system. A prefab contains no absolute map position. |
| **Instance** | One placement of a prefab with an explicit stable instance ID, origin, and optional supported transform and overrides. |
| **Local ID** | A stable ID inside a prefab, such as `door.front` or `prop.anvil`. |
| **Resolved ID** | The map-wide ID derived from an instance ID and local ID, such as `smithy/door.front`. |
| **Exact placement** | A first-class primitive placed directly in map cell space when a prefab would not improve reuse. |
| **Override** | A narrow, validated change to one named prefab child field after expansion. |
| **Generated nodes** | Terrain, geometry, collision, navigation, markers, and view nodes assembled from a compiled definition. They are never source of truth. |
| **Chunk** | A runtime partition used for loading or rendering. It is not a blueprint namespace or gameplay identity. |

`MapBlueprint`, `MapBlueprintCompiler`, `MapPrefabPackage`, `MapPrefab`, and `MapTransform` are implemented typed GDScript APIs. Prefab packages are registered explicitly on each blueprint; the compiler never discovers packages by filesystem order.

## Coordinate and unit rules

- Author semantic layout in integer **cells**. The project default is `MapTypes.DEFAULT_CELL_SIZE`, currently 32 world pixels per cell.
- The gameplay plane remains orthogonal X/Y per [ADR 0002](adr/0002-orthogonal-three-quarter-perspective.md). The view layer may present that plane isometrically.
- Rectangle origins use the north-west cell and sizes are positive. Bounds are half-open: `[position, position + size)`.
- A point-like primitive occupies an explicit cell or cell-relative offset. The compiler performs all conversion to `Vector2`, `Rect2`, and other world-space runtime values.
- Do not mix cells and world pixels in a blueprint. A rare non-grid visual offset must use a field whose unit is explicit in its name and schema, for example `visual_offset_px`; it must not alter gameplay collision or navigation silently.
- Array order is semantic only where the primitive says so, such as terrain paint layers or patrol points. Otherwise the compiler canonicalizes output independently of declaration order.

## Supported primitive vocabulary

The initial vocabulary must cover the existing runtime contract without exposing arbitrary runtime dictionaries. The exact typed API may evolve during implementation, but these capabilities and semantics are required.

| Primitive or metadata | Required author intent | Compiles to |
|---|---|---|
| `map` metadata | `map_id`, canonical location, scope, active flag, seed, palette, size, base terrain, source references | Top-level `MapDefinition` fields |
| `terrain_rect` | Terrain ID, cell rectangle, explicit layer/order when overlaps matter | `zones` |
| `structure_rect` | Stable ID, supported building/structure kind, cell footprint, style parameters | `buildings` |
| `wall_run` | Stable ID, endpoints or cell rectangle, thickness, openings, style | One or more canonical `buildings` entries |
| `prop` | Stable ID, supported prop kind, cell placement, optional facing/style | `props` |
| `player_spawn` | Named or primary spawn placement | `player_spawn` and any supported spawn metadata |
| `transition` | Stable ID, cell rectangle, destination scene/spawn IDs, optional local spawn metadata, and optional `building_id` for a door attached to a facade | `transitions` |
| `interaction_anchor` | Stable ID, cell placement, optional kind | `interaction_anchors` |
| `patrol_path` | Stable ID and ordered cell points | `patrols` |
| `excluded_rect` | Cell rectangle blocked from traversal | `excluded_areas` |
| `fade_rect` | Cell rectangle for roof or foreground fade | `fade_volumes` |
| `direction_sign` | Stable association, text, placement, outgoing direction | `direction_signs` |
| `view_landmark` | Stable ID, supported view-only kind, placement and dimensions | `view_landmarks` |
| `surroundings` | Explicit per-side view continuation (`town`, `water`, `woodland`) | `surroundings_sides` |
| `camera_bounds` | Optional cell rectangle, otherwise full map bounds | `camera_bounds` |
| `prefab_instance` | Stable instance ID, prefab ID/version, origin, supported transform, overrides | Expanded primitives in the fields above |

New reusable behavior must be added as a reviewed typed primitive with validation, compilation, and tests. Do not bypass the vocabulary with a generic `raw_definition_entry` or embedded `MapDefinition` dictionary.

For an enterable building, keep the transition rectangle on the walkable approach and set `building_id=<stable building id>`. The 2D trigger remains independently sized for reliable traversal, while the 3D renderer snaps the entrance to the nearest aligned facade and suppresses conflicting procedural facade details. Omit `building_id` for interior wall doors and freestanding gates.

## Stable-ID rules

Stable IDs connect map geometry to content, saves, transitions, audits, captures, and tests. Treat them as public API.

1. `map_id` is globally unique and immutable after external references exist. Prefer the existing map ID when migrating.
2. Every semantic object that can be referenced, overridden, audited, saved, or reported receives an explicit ID. Terrain paint fragments need IDs only when they are referenced or overridden.
3. IDs use lowercase ASCII segments with digits, `_`, `.`, or `-`. `/` is reserved for prefab namespace composition. Do not derive IDs from display text.
4. IDs describe identity or role, for example `gate.viru`, `anchor.forge`, or `stall.fish`, not array position or incidental coordinates such as `prop_12_7`.
5. IDs are unique after prefab expansion across all referenceable map objects. The compiler rejects duplicates across categories unless the schema explicitly defines a shared object.
6. A prefab declares immutable local child IDs. An instance with ID `smithy` resolves local ID `door.front` to `smithy/door.front`. Nested namespaces compose in the same order.
7. Moving, rotating, reflecting, reordering, or overriding an object does not change its ID. Runtime chunk assignment also never changes it.
8. Deleting or renaming an externally referenced ID is a migration. Update all references atomically or provide a documented alias at the runtime/content boundary when that boundary supports aliases.
9. The compiler may create internal fragments, such as wall segments around an opening, only from a documented deterministic suffix of the owning stable ID. Internal fragments must not become gameplay references.

## Deterministic generation requirements

Given the same blueprint semantic content, compiler version, primitive/prefab library versions, and seed, compilation must produce semantically identical output and the same canonical fingerprint on every supported platform.

- No wall-clock time, global random state, filesystem enumeration order, scene-tree state, editor metadata, locale, or platform-dependent path is an input.
- Random variation uses an explicit seed and stable per-object derivation from IDs. Adding an unrelated object must not reshuffle existing object variation.
- Prefab expansion order and generated suffixes are specified. Never use hash-map iteration order or declaration index as identity.
- Canonical output ordering is documented and covered by tests. Ordered semantics, such as paint precedence and patrol paths, preserve explicit author order; unordered collections sort by resolved stable ID and a defined tie-breaker.
- Numeric transforms are exact for supported grid operations. Canonical fingerprint input does not depend on `str(Dictionary)` or locale-sensitive float formatting.
- The fingerprint covers all runtime-relevant semantics and excludes comments, source formatting, generated scene node names, and chunk assignment.
- Compiling twice in one process and in fresh processes must match. A compile-check mode must fail if a checked-in generated artifact, if any, is stale.

## Prefabs and local coordinates

- A prefab has a stable prefab ID and, once compatibility requires it, an explicit schema/version.
- Prefab geometry is authored relative to local cell origin `(0, 0)`. Prefabs do not know the destination map, absolute world pixels, scene paths, or runtime chunk.
- Every referenceable child has a stable local ID. Prefab internals may refer to siblings by local ID; the compiler resolves those references after namespacing.
- Instances provide an explicit stable instance ID and map-cell origin. Supported transforms should be limited initially to integer translation and orthogonal rotations/reflections that can be represented exactly on the cell grid.
- Transform order is fixed: resolve prefab defaults, apply the instance transform in local space, translate to the map origin, then apply allowlisted overrides and validate final bounds/references.
- Nested prefabs are allowed only if cycle detection, maximum expansion depth, deterministic namespace composition, and diagnostics are implemented. Otherwise they must be rejected in the first version.
- A prefab may supply defaults, but it must not silently choose map-wide IDs, destinations, activation state, or content references.
- If a reusable composition requires many per-instance structural overrides, create a clearer prefab variant or use explicit primitives. Do not turn overrides into a second programming language.

## Escape hatches: explicit placement and overrides

Compact authoring must not prevent exact layouts.

### Explicit placement

Use a supported primitive directly in map coordinates for unique geometry, a landmark, a one-off transition, or composition that is clearer without a prefab. Exact placement is normal authoring, not an error. It still uses typed fields, cell units, stable IDs, validation, canonical ordering, and the compiler.

### Prefab overrides

An override targets one resolved prefab child by local stable ID and changes only allowlisted fields, for example:

- terrain/style/material variant;
- facing, dimensions, or height within primitive constraints;
- enabled/disabled state for an optional child;
- destination IDs or text deliberately left as prefab parameters;
- an explicit cell-relative placement adjustment when the primitive supports it.

The compiler rejects unknown targets, duplicate/conflicting overrides, type changes, ID mutation, raw runtime fields, and overrides that leave geometry or references invalid. Overrides apply after expansion and transforms, before final validation and fingerprinting.

There is no generic raw dictionary escape hatch. If neither a primitive, exact placement, nor a narrow override can express a requirement, extend the reviewed primitive vocabulary and its tests.

## Authoring example

The final method names may change during implementation, but intended source shape is compact and typed:

```gdscript
class_name ExampleSmithyBlueprint
extends RefCounted

static func create() -> MapBlueprint:
    var map := MapBlueprint.new(
        &"lower_town_smithy_example",
        &"loc.kalev_smithy",
        Vector2i(50, 28),
        MapTypes.TERRAIN_GRASS,
    )
    map.scope = &"prototype"
    map.active = false
    map.seed = 42042
    map.palette = &"clean_painted"
    map.add_source_reference("scenes/revel-map.jpg")

    map.terrain_rect(&"street", MapTypes.TERRAIN_COBBLESTONE, Rect2i(8, 0, 30, 4))
    map.prefab_instance(
        &"smithy",
        &"building.smithy_small",
        Vector2i(10, 8),
        MapTransform.IDENTITY,
        {
            &"door.front": {"destination_scene_id": &"lower_town_slice"},
            &"prop.anvil": {"style_variant": &"worn"},
        },
    )
    map.prop(&"well", MapTypes.PROP_KIND_WELL, Vector2i(30, 19))
    map.transition(&"gate.north", Rect2i(20, 0, 2, 1), &"lower_town_slice", &"smithy_gate")
    map.interaction_anchor(&"anchor.delivery", Vector2i(24, 15))
    map.player_spawn(&"spawn.main", Vector2i(22, 16))
    return map
```

The compiler, not the author, converts cells to world units, expands `smithy/door.front` and `smithy/prop.anvil`, emits canonical `MapDefinition` arrays, and computes the fingerprint.

A unique layout should remain explicit rather than hiding behind a single-use prefab:

```gdscript
map.structure_rect(&"wall.courtyard_west", &"wall", Rect2i(8, 8, 1, 10))
map.fade_rect(&"fade.south_roof", Rect2i(9, 17, 8, 2))
map.view_landmark(&"landmark.gate_arch", &"gate_arch", Rect2i(19, 7, 4, 1))
```

### Migrated map excerpt (`lower_town_slice`)

Production Lower Town authoring compiles through `LowerTownSliceBlueprint` and the thin `LowerTownSliceDefinition.create()` adapter. Terrain paint order is preserved with grouped `terrain_rects` batches; structures use named styles plus a compact placement table; gameplay routes, transitions, and landmarks stay explicit.

```gdscript
static func create() -> MapBlueprint:
    var map := MapBlueprint.new(&"lower_town_slice", &"loc.lower_town_slice", Vector2i(176, 112), MapTypes.TERRAIN_DIRT)
    map.scope = &"production"
    map.active = true
    map.palette = &"clean_painted"
    _define_styles(map)
    _add_terrain(map)
    _add_structures(map)
    _add_landmarks_props_routes(map)
    map.surroundings([&"north", &"west"])
    return map

static func _add_terrain(map: MapBlueprint) -> void:
    map.terrain_rects(&"terrain.00", MapTypes.TERRAIN_GRASS, [Rect2i(66, 0, 22, 50), Rect2i(0, 50, 88, 6), ...], 0, 0)
    map.terrain_rects(&"terrain.01", MapTypes.TERRAIN_WATER, [Rect2i(70, 0, 3, 16), Rect2i(70, 14, 5, 2), ...], 0, 9)
    map.terrain_rects(&"terrain.02", MapTypes.TERRAIN_DIRT, [Rect2i(66, 19, 22, 3), Rect2i(36, 50, 3, 6)], 0, 22)
```

## Reusable prefab packages

A `MapPrefabPackage` owns versioned, package-local prefabs. Maps register a package explicitly with `use_prefab_package()` and refer to a prefab by qualified ID such as `urban.house_row`. Every instance has a stable map-local ID; `street.houses/house.west` is derived from instance and local IDs, never an array index. The reviewed example library is `scripts/map/prefabs/urban_prefab_package.gd` and includes `urban.house_row`, `urban.wall_tower_segment`, and nested `urban.gate_composition`. It is example content only and does not migrate Lower Town.

Parameters must be declared with a type and default. Values use `MapPrefab.parameter()` references. Supplying an unknown parameter or a value of the wrong declared type is an error. Nested instances are allowed, but direct or indirect recursion and nesting deeper than 32 levels are rejected.

Deterministic evaluation order is normative:

1. Resolve declared parameter defaults, then supplied instance parameter values.
2. Expand local primitives and nested instances. Nested transforms apply from the innermost instance outward.
3. For each transform, mirror local X, then local Y, then rotate clockwise by `0`, `90`, `180`, or `270` degrees. Transform occupied integer cells around local `(0, 0)`.
4. Translate transformed cells by the instance origin.
5. Apply prefab-child inline values, then the nearest instance override, then each containing-instance override from inner to outer, then map-level `override_object()`.
6. Validate allowlisted fields, IDs, references, final map bounds, and canonical output.

Orientation fields transform with geometry: cardinal `door_side`, `facing`, and `direction` values rotate/reflect; `ridge_axis` and `passage_axis` swap axes on quarter turns. Overrides occur after transforms, so an override states the final map-space orientation. Override targets are local semantic paths such as `house.middle` or `east/tower`, never indices.

### Concise AI-generation examples

```gdscript
var map := MapBlueprint.new(&"new_quarter", &"loc.new_quarter", Vector2i(80, 50), MapTypes.TERRAIN_GRASS)
map.use_prefab_package(UrbanPrefabPackage.create())
map.prefab_instance(
    &"street.houses",
    UrbanPrefabPackage.HOUSE_ROW,
    Vector2i(8, 12),
    MapTransform.new(90, true), # mirror X, then rotate clockwise
    {&"roof_color": Color(0.28, 0.12, 0.10)},
    {&"house.middle": {"door_side": &"east"}}, # final map-space side
)
map.prefab_instance(
    &"gate.north",
    UrbanPrefabPackage.GATE_COMPOSITION,
    Vector2i(42, 8),
    MapTransform.new(),
    {},
    {&"east/tower": {"wall_height": 256.0}},
)
```

Choose the smallest construct that communicates intent:

| Need | Use | Rule |
|---|---|---|
| Repeated multi-object composition with stable internal roles | Prefab | Reuse it at least twice, or establish a reviewed domain building block. Prefer a variant over many structural overrides. |
| Repeated same-kind objects along one vector | `placement_row` | Every slot needs an explicit stable slot ID. Use it when spacing is regular and composition is one-dimensional. |
| Connected orthogonal terrain or wall path | Stroke or `wall_run` | Use ordered points for path intent; use explicit rectangles if overlap/paint fragments need independent meaning. |
| Unique geometry, transition, landmark, or exception | Explicit placement | Keep one-off intent visible. Do not create a single-use prefab solely to shorten code. |

AI authors should invent IDs before coordinates, keep package IDs domain-scoped, use parameters for declared reusable variation, and use named overrides only for narrow exceptions. If generation needs indices, raw runtime dictionaries, recursive composition, or many overrides, stop and choose a clearer primitive/prefab variant.

## Validation expectations

Validation has four layers and must report the blueprint path plus source ID, not only a generated array index.

### 1. Blueprint source validation

Reject missing metadata, unsupported primitive kinds, invalid units or rectangles, duplicate source IDs, invalid scope/activation combinations, unknown fields, stale source references, and non-explicit randomness.

### 2. Prefab and reference validation

Reject unknown prefab IDs or versions, cycles, duplicate resolved IDs, invalid transforms, unresolved local references, unknown override targets, forbidden override fields, and references to disabled or missing children.

### 3. Compiled contract validation

Run `MapDefinition.validate()` and require known terrain/building/prop kinds, positive in-bounds geometry, valid transitions and anchors, complete fingerprint and metadata, unique IDs, and valid camera/world bounds. Compiler diagnostics must map a runtime failure back to its blueprint primitive.

### 4. Behavioral and parity validation

Require full terrain coverage, collision-footprint equality, spawn/transition/mandatory-anchor reachability, patrol segment reachability, deterministic fingerprints, shared Y-sort policy, activation isolation, source-reference resolution, scene startup, and deterministic visual captures where relevant.

For a migration, compare old and compiled definitions using a canonical semantic snapshot. Preserve at minimum:

- map, transition, spawn, anchor, patrol, prop, structure, and landmark IDs;
- scope, activation, destination references, source references, and map bounds;
- terrain coverage and precedence;
- collision and excluded areas;
- navigation reachability between mandatory points;
- view metadata and capture composition within the approved visual tolerance.

An intentional difference must be listed in the migration change and asserted in a test or updated golden artifact. A changed fingerprint alone neither proves parity nor automatically indicates failure: migrated compiler output uses the new canonical fingerprint policy, while semantic parity is checked explicitly.

## Semantic diagnostics and pre-commit validation

`MapBlueprintCompiler.compile_with_diagnostics()` returns a `MapBlueprintCompileResult` with a canonical `diagnostics` array. Every `MapBlueprintDiagnostic` exposes `code`, `severity`, `message`, `map_id`, `path`, `subject`, and `details`, plus `format()` for humans and `to_dict()` for editor or AI tooling. Diagnostic codes are a compatibility API and must not be renamed to reword a message.

Errors reject compiler output and make headless validation exit non-zero. Warnings preserve a valid compiled definition and keep CI green, but are printed for review. Current stable semantic codes are:

| Code | Severity | Meaning |
|---|---|---|
| `MAP_ID_DUPLICATE`, `MAP_ID_UNSTABLE` | error | Duplicate map-wide identity or an ID outside the lowercase stable-ID grammar. |
| `MAP_STYLE_UNKNOWN`, `MAP_KIND_UNKNOWN`, `MAP_TERRAIN_UNKNOWN` | error | Reference is outside an explicit allowlist. |
| `MAP_GEOMETRY_OUT_OF_BOUNDS`, `MAP_SIZE_INVALID` | error | Cell geometry is outside half-open map bounds or has a non-positive size. |
| `MAP_PREFAB_RECURSION`, `MAP_OVERRIDE_TARGET_MISSING` | error | Prefab expansion cycles or a named override has no expanded target. |
| `MAP_TRANSITION_SPAWN_RELATION_INVALID`, `MAP_TRANSITION_DESTINATION_UNKNOWN`, `MAP_TRANSITION_DESTINATION_SPAWN_UNKNOWN` | error | A transition lacks a complete local/destination spawn relationship or disagrees with `content/transitions/active_destinations.json`. |
| `MAP_ANCHOR_BLOCKED`, `MAP_REQUIRED_ANCHOR_MISSING`, `MAP_REQUIRED_ANCHOR_UNREACHABLE` | error | An anchor is blocked, absent from a registry requirement, or unreachable from the exact player spawn. |
| `MAP_GEOMETRY_OVERLAP` | warning | Blocking footprints fully overlap and require author review. |
| `MAP_CHUNK_BOUNDARY_AMBIGUOUS` | warning | Gameplay/blocking geometry crosses the future 16x16-cell planning grid without explicit ownership. |
| `MAP_COMPILE_ERROR`, `MAP_RUNTIME_CONTRACT`, `MAP_TRANSITION_REGISTRY_INVALID` | error | A lower-level compiler/runtime contract or validation registry failed. |

### Owned `MAP_CHUNK_BOUNDARY_AMBIGUOUS` decisions (P0-067a)

The 16x16 planning grid is a review aid (`MapBlueprintSemanticValidator.FUTURE_CHUNK_SIZE_CELLS`). It is not authored chunk identity and is not the runtime default chunk size (32x32 cells per [ADR 0010](./adr/0010-large-map-runtime-chunking.md) and `MapTerrainGrid.DEFAULT_CHUNK_SIZE_CELLS`).

Retained warnings on inactive/dev-gated prototypes `north_quarter`, `monastery_quarter`, `south_quarter`, `toompea_quarter`, `reval_harbor_north`, and `reval_harbor_east` are intentional. The P0-068 Tallinn district reshape was re-audited under the same ADR 0010 ownership policy recorded in [`docs/reports/map_chunk_boundary_review_p0_067a.md`](./reports/map_chunk_boundary_review_p0_067a.md); the report's P0-068 note supersedes its earlier geometry counts. Summary of the owned decision:

- Keep continuous historical footprints; do not suppress the warning code.
- When object chunk streaming is used, owner chunk is the lexicographically smallest intersecting chunk under ADR 0010 section 4 (`MapChunkRuntimeIndex`).
- Transitions stay persistent residency; stable IDs never encode chunk coordinates.
- Do not activate these maps as chunk-streaming-dependent playable content until a later task splits the listed subjects or re-asserts ownership after human review.

### Owned `MAP_CHUNK_BOUNDARY_AMBIGUOUS` decisions (P0-067b)

Retained warnings on playable slice maps `kalev_smithy` and `lower_town_slice`, plus the remaining registry prototype `market_civic_quarter`, are intentional. Each subject ID, planning-grid span, and ownership policy is recorded in [`docs/reports/map_chunk_boundary_review_p0_067b.md`](./reports/map_chunk_boundary_review_p0_067b.md). Summary of the owned decision:

- Keep continuous forge walls, city-wall/foregate runs, brewery/smithy footprints, and civic landmarks; do not suppress the warning code.
- When object chunk streaming is used, owner chunk is the lexicographically smallest intersecting chunk under ADR 0010 section 4 (`MapChunkRuntimeIndex`).
- Transitions stay persistent residency; stable IDs never encode chunk coordinates.
- At the P0-067b review, object chunk streaming remained blocked on the playable slice maps until a later task split the listed subjects or re-asserted ownership at the production 32x32 chunk size after human review. P0-067c closes that slice-map gate in the next section. `market_civic_quarter` remains blocked until its own activation ticket revisits the list.

### Playable-slice object chunk streaming readiness (P0-067c)

Object chunk streaming is production-ready on the active playable maps `kalev_smithy` and `lower_town_slice` at the ADR 0010 production size of 32x32 cells. The 16x16 `MAP_CHUNK_BOUNDARY_AMBIGUOUS` warnings remain visible as conservative review signals; they do not block runtime residency on these two maps.

The reviewed contract and current ownership inventory are recorded in [`docs/reports/map_object_chunk_streaming_readiness_p0_067c.md`](./reports/map_object_chunk_streaming_readiness_p0_067c.md) and locked by [`tests/fixtures/maps/object_chunk_streaming_readiness_p0_067c.json`](../tests/fixtures/maps/object_chunk_streaming_readiness_p0_067c.json). In summary:

- Every reviewed building has one lexicographically smallest owner and every half-open intersecting consumer at 32x32.
- A building remains one complete instance while any consumer chunk is resident; chunks never duplicate authoritative collision or persistent state.
- Transitions use persistent residency. Excluded areas remain baked static navigation data rather than streamable objects.
- Full-load tests on both playable maps produce every building and prop exactly once while preserving authored footprints.
- Existing smithy collision/route checks and Lower Town canonical parity/route checks remain the geometry acceptance gate.

Any change to a retained warning subject, footprint, owner, consumer list, or residency must update the executable fixture only after renewed map review. This readiness does not activate `market_civic_quarter` or any P0-067a prototype, and it does not approve seamless-world streaming or production coarse A*.

Register every new blueprint factory in `scripts/map/map_blueprint_registry.gd`. Registry order is explicit and deterministic; filesystem discovery is forbidden. Put mandatory anchor IDs in the registry entry. The headless command compiles every entry, checks cross-map transitions and exact required-anchor reachability, prints stable codes, and exits `1` when any error exists:

```bash
godot --headless --path . --script tools/validate_map_blueprints.gd
```

Before committing any map blueprint, prefab, compiler, transition registry, audit requirement, or map-authoring documentation change, run this exact workflow from the repository root in this order:

```bash
godot --headless --path . --script tools/validate_map_blueprints.gd
godot --headless --path . --script tools/run_godot_tests.gd
python3 tools/verify_map_audit.py
python3 tools/verify_map_activation.py
python3 tools/verify_map_conversion_plan.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

Do not suppress warnings merely to obtain quiet output. Review overlap and chunk-boundary subjects, then either change authored geometry or record the intentional condition in the map review. CI runs the registry command independently and fails on errors.

### `lower_town_slice` parity fixture

`tests/fixtures/maps/lower_town_slice.parity.json` is the reviewed pre-compiler baseline for `lower_town_slice`. Its canonical serializer records normalized map metadata, an output terrain-ID grid hash, buildings and props, anchors, transitions, patrols, view landmarks, direction signs, exclusions, fade volumes, source references, surroundings metadata, and a cell-by-cell walkability hash/count. Dictionary keys and stable-ID collections are sorted, unordered records are compared canonically, and floats use nine fixed decimal places so representation-only changes do not create diffs. Patrol points retain order because their order is gameplay-relevant. Legacy paint-operation order and the authoring fingerprint are intentionally excluded: a compiler may express the same final terrain differently and will use a new canonical fingerprint policy.

The normal test suite only reads this fixture and never rewrites it. Regeneration is intentionally guarded and must be invoked explicitly:

```bash
godot --headless --path . \
  --script tools/regenerate_lower_town_slice_parity.gd \
  -- --write-lower-town-slice-parity-fixture
```

After regeneration, review the full fixture diff before accepting it. Confirm every metadata or stable-ID change is intended, inspect changed building footprints/properties and gameplay collections, and treat either terrain or walkability hash changes as a map-layout/navigation change requiring dedicated map review. Then run the Godot suite and verify the existing endpoint, gate-passage, water exclusion, and navigation-polygon tests still pass. Do not regenerate merely to make a failing migration test green.

The production gates are executable and may be run independently:

```bash
tools/run_map_pipeline_ci.sh parser            # strict .rrmap parser and loader
tools/run_map_pipeline_ci.sh compiler          # compiler, prefabs, negative cases, semantics
tools/run_map_pipeline_ci.sh audit             # registry completeness and every-source compile
tools/run_map_pipeline_ci.sh persistence       # stable-ID save/load and repartition compatibility
tools/run_map_pipeline_ci.sh parity            # canonical snapshot, routes, preview/runtime/chunk/nav/3D
tools/run_map_pipeline_ci.sh benchmark-smoke   # quick large-map structural/performance report
# Run every gate:
tools/run_map_pipeline_ci.sh all
```

CI runs the same commands. Any `SCRIPT ERROR`, parse error, missing resource, non-zero test result, registry omission, or parity difference fails the wrapper even where Godot itself would return zero.

For visual changes, also run the relevant map scene or capture tool and inspect the deterministic capture. Generated nodes in the running scene are evidence only; edit the blueprint or compiler to fix them.

### Godot editor preview

Migrated blueprint scenes may include `MapBlueprintEditorPreview`, an `@tool` component that is safe to reuse in small scene shells. `scenes/reval_east/reval_east.tscn` binds it to `LowerTownSliceBlueprint`. The component calls `MapBlueprintCompiler.compile_with_diagnostics()` and then uses the normal `MapBuilder` and `MapAssembler` visual path. It does not use `MapSceneBootstrap`, instantiate transition doors, install a gameplay view, or attach a live navigation region.

Select `MapBlueprintPreview` in the Scene dock to use these Inspector controls:

- **Rebuild Preview** - recompile the blueprint and replace all disposable terrain, building, prop, landmark, and overlay nodes.
- **Validate** - compile and validate without replacing the current preview. The read-only **Preview Status** contains the map ID, fingerprint, counts, or one actionable compiler diagnostic per line. Errors also appear as node configuration warnings and in the editor Output panel.
- **Show Stable IDs** - label compiled building, prop, landmark, anchor, and transition IDs.
- **Show Anchors** - display interaction anchors as cyan crosshairs.
- **Show Navigation** - draw polygon data baked with the runtime `MapNavBuilder`; no `NavigationRegion2D` enters the edited scene tree.
- **Show Chunk Bounds** - display a clearly labeled 16x16-cell planning grid. This is a placeholder, not authored chunk identity or a runtime streaming contract.

Only `blueprint_factory` is stored in the scene. The controls and status are editor-session state. The generated root is internal, has no `owner`, is marked `preview_only`, and has physics disabled. Therefore generated nodes are omitted from `.tscn` saves and `PackedScene.pack()`, and the component clears itself and disables processing outside the editor. Runtime still compiles the Lower Town blueprint independently through `LowerTownSliceDefinition.create()` and deliberately rebuilds gameplay nodes there.

#### Manual verification and screenshots

1. Start Godot 4.7.1, open `scenes/reval_east/reval_east.tscn`, select `MapBlueprintPreview`, and click **Rebuild Preview**. Confirm terrain, buildings, props, magenta landmark rectangles, and cyan anchors appear in the 2D viewport. Capture `lower-town-preview-base.png` with the Scene dock, Inspector success status, and full viewport visible.
2. Enable **Show Stable IDs**, **Show Anchors**, **Show Navigation**, and **Show Chunk Bounds**. Confirm labels follow compiled objects, cyan anchor crosses match the labels, blue navigation avoids blocked footprints/water, and the orange grid says `CHUNK BOUNDS PLACEHOLDER`. Capture `lower-town-preview-overlays.png`.
3. Temporarily introduce an invalid map value in `content/maps/lower_town_slice.rrmap`, for example duplicate a stable primitive ID. Click **Validate** and confirm the Inspector status, yellow node warning, and Output error name the compiler problem and tell the author to fix the blueprint. Undo the edit, click **Validate**, and confirm success.
4. Before and after toggling every overlay, save the scene and run `git diff -- scenes/reval_east/reval_east.tscn`. Confirm no generated nodes, overlay state, status text, or compiler output is serialized.
5. Run the scene. Confirm gameplay transitions are created only by `MapSceneBootstrap`, the preview component contains no generated child, and entering a transition changes scenes once rather than being triggered by preview geometry.
6. Run `godot --headless --path . --script tools/run_godot_tests.gd`. `test_map_blueprint_editor_preview.gd` verifies production-compiler parity, inert runtime behavior, disabled preview physics, packing separation, and the Lower Town scene binding.

Screenshots are manual review artifacts. Store them with the relevant map audit/capture package when a ticket requires checked-in evidence; do not embed generated preview nodes in the `.tscn` to preserve a visual baseline.

Lower Town base preview (compiled terrain, buildings, props, landmarks, and anchors):

![Lower Town compiled MapBlueprint editor preview](reports/images/lower-town-preview-base.png)

Lower Town preview with stable IDs, anchors, runtime navigation polygon data, and chunk-bound placeholder enabled:

![Lower Town MapBlueprint editor preview overlays](reports/images/lower-town-preview-overlays.png)

## Migration policy

1. **Do not mass-convert.** Existing direct `MapDefinition` factories remain supported while the compiler is introduced. They are legacy authoring sources, not examples for new maps.
2. **Freeze a baseline first.** Capture the legacy semantic snapshot, fingerprint, mandatory IDs/references, reachability, collision, and representative visual output before editing a map.
3. **Migrate one representative compact map first.** It must exercise terrain, a prefab, explicit placement, transitions, anchors, collision, and view metadata.
4. **Preserve stable IDs and external contracts.** Layout cleanup does not justify renaming IDs. Intentional renames require atomic reference updates or supported aliases.
5. **Keep runtime consumers unchanged.** A migration replaces the definition factory's source path with blueprint compilation; it does not rewrite builders, renderers, or gameplay systems to understand blueprints.
6. **Keep a temporary parity fixture.** The old factory or a reviewed canonical snapshot remains until semantic, behavioral, scene, and visual parity checks pass.
7. **Delete obsolete source only after parity.** Generated scene nodes are never retained as a fallback source. Small bootstrap scenes may stay.
8. **Update registries and docs atomically.** Audit manifest, conversion plan, source references, captures, and tests change in the same migration when needed.
9. **Guard new work.** After the representative migration passes, add a lint/review guard that rejects new giant direct `MapDefinition` dictionary factories while allowing focused runtime tests and unmigrated legacy files.
10. **Chunking does not block migration.** Do not add authored chunk IDs or split stable-ID namespaces during conversion. A later runtime layer partitions compiled data transparently.

## Recommended implementation order

| Order | Deliverable | Depends on | Exit evidence |
|---|---|---|---|
| 1 | Freeze `MapDefinition` semantic snapshots and representative parity fixtures | Existing runtime, audit registry, and map tests | Legacy definitions reproduce stable snapshots, collision/navigation checks, and captures |
| 2 | Add typed `MapBlueprint`, primitive records, diagnostics, and source validation | Step 1; `MapTypes`; current metadata contract | Positive and negative blueprint tests |
| 3 | Add prefab library, local coordinates, transforms, namespaced IDs, and overrides | Step 2 stable-ID and validation rules | Transform/namespace determinism, cycle rejection, override tests |
| 4 | Add pure `MapBlueprintCompiler` and canonical fingerprint serializer | Steps 1-3; unchanged `MapDefinition` | Repeated/fresh-process determinism and `MapDefinition.validate()` |
| 5 | Migrate one compact representative map | Step 4; existing audit/capture tools | Semantic, collision, navigation, scene, and visual parity |
| 6 | Migrate remaining maps incrementally and add direct-definition guard | Step 5 passing; per-map external-reference inventory | One reviewed parity package per map, no new giant factories |
| 7 | Design runtime chunk indexing only after profiling | Stable compiled contract plus measured large-map bottleneck | Separate runtime ADR/tests for cross-chunk identity and traversal |

The critical dependency direction is one-way: `MapBlueprint` and prefab libraries feed `MapBlueprintCompiler`; the compiler targets `MapDefinition`; current runtime consumers read only `MapDefinition`; optional chunking reads compiled runtime data. Rendering, scene nodes, and chunks never feed authored map semantics back into a blueprint.

## Optional `.rrmap` source format (v1)

### Adoption decision and guardrails

The typed GDScript `MapBlueprint` API remains the proven, production authoring path. Lower Town continues to use `LowerTownSliceBlueprint` and its parity fixture. `.rrmap` is an optional declarative front end added only after those semantics, compiler validation, editor preview, and production parity checks existed. The first migrated source is deliberately the non-production fixture `tests/fixtures/maps/rrmap_courtyard_example.rrmap`.

Do not migrate Lower Town or replace a GDScript blueprint merely because `.rrmap` exists. Before any production migration, compare representative sources using the same semantic content and require all of the following:

1. both sources compile through `MapBlueprintCompiler` to the same canonical parity snapshot/fingerprint;
2. all gameplay, navigation, visual-preview, and malformed-input tests pass;
3. the `.rrmap` source has a meaningful measured token/readability benefit for reviewers and authoring agents;
4. no required semantic depends on an unsupported escape hatch.

The small trial is 126 whitespace-delimited words and 987 bytes. This is evidence that the line form is compact for simple maps, not evidence that the large production Lower Town should move. Lower Town remains untouched until a reviewed, semantics-equivalent measurement is available.

### Safety and loading

`.rrmap` is data, not GDScript. The parser recognizes a closed command set, integer coordinates, booleans, allowlisted typed options, quoted text, and explicitly registered prefab packages. It has no expressions, function calls, script paths, includes, filesystem discovery, or raw dictionary values. Unknown commands and fields are errors. This prevents arbitrary code execution by construction.

The enabled `addons/rrmap` editor plugin registers `RrmapResourceFormatLoader`. Loading a `.rrmap` produces an `RrmapResource` only after:

```text
source text -> MapRrmapParser -> MapBlueprint -> MapBlueprintCompiler -> MapDefinition
```

A parse or compile failure returns `ERR_PARSE_ERROR` and prints diagnostics as:

```text
res://maps/example.rrmap:12:18: error[invalid_integer]: expected an integer, got 'east'
```

Runtime systems still consume `MapDefinition`; the loader does not introduce a parallel runtime contract. Tests and tools may call `MapRrmapParser.parse_file(path)` directly.

### Lexical rules

- UTF-8 text, one statement per physical line.
- The first non-empty, non-comment line must be exactly `rrmap 1`.
- Spaces and tabs separate tokens. There is no indentation syntax.
- `#` starts a comment outside a quoted string.
- Double-quoted strings support `\\n`, `\\"`, `\\\\`, and `\\#` escapes.
- IDs are unquoted tokens and are ultimately validated by `MapBlueprintCompiler` with `^[a-z0-9_.-]+$`.
- Coordinates and rectangle values are signed base-10 integers. A rectangle is `x y width height`; sizes must pass compiler validation.
- Compact point lists use `x,y|x,y|...`; compact rectangle lists use `x,y,w,h|x,y,w,h|...`.
- Options are `key=value`, may not repeat on one line, and are command-specific.
- Colors omit the comment marker and use `RRGGBB` or `RRGGBBAA`, for example `806f5cff`.
- A file is rejected as a whole if any parser or compiler diagnostic exists. There is no partial map.

### Version behavior

Version 1 is the only accepted grammar. Version 0 produces `version_migration_required` with the explicit action to change the header to `rrmap 1` and validate all semantics. Versions greater than 1 produce `unsupported_version`; they are never guessed or silently downgraded. Future grammar changes must either remain compatible with v1 or add an explicit deterministic migration tool and tests.

### Grammar

The normative grammar below uses `[]` for optional syntax, `...` for repetition, and `|` for alternatives. These notation characters are not generally literal source syntax.

```ebnf
file          = trivia, "rrmap", WS, "1", EOL,
                trivia, map, EOL,
                { trivia, statement, EOL }, trivia, EOF ;
trivia        = { blank_line | comment_line } ;
statement     = source | surroundings | camera | style
              | terrain | terrain_rects | stroke | building | wall | prop
              | spawn | transition | anchor | patrol | exclude | fade
              | sign | landmark | package | prefab | override ;

map           = "map", ID, ID, INT, INT, ID,
                { map_option } ;
map_option    = "scope=", ("prototype" | "production" | "archive")
              | "active=", BOOL | "palette=", ID
              | "seed=", INT | "cell_size=", INT
              | "elevation=", NUMBER ;
source        = "source", STRING ;
surroundings  = "surroundings", SIDE, { (SIDE, ("town" | "water" | "woodland")) } ;
camera        = "camera", RECT ;
style         = "style", ID, [ "parent=", ID ], typed_option, { typed_option } ;

terrain       = "terrain", ID, TERRAIN, RECT,
                [ "layer=", INT ], [ "order=", INT ], [ "style=", ID ] ;
terrain_rects = "terrain_rects", ID, TERRAIN, RECT_LIST,
                [ "layer=", INT ], [ "order=", INT ], [ "style=", ID ] ;
stroke        = "stroke", ID, TERRAIN, POINT_LIST,
                [ "thickness=", INT ], [ "layer=", INT ],
                [ "order=", INT ], [ "style=", ID ] ;
building      = "building", ID, BUILDING_KIND, RECT,
                [ "style=", ID ], { typed_option } ;
wall          = "wall", ID, INT, INT, INT, INT,
                [ "thickness=", INT ], [ "openings=", RECT_LIST ],
                [ "kind=", BUILDING_KIND ], [ "style=", ID ], { typed_option } ;
prop          = "prop", ID, PROP_KIND, INT, INT,
                [ "rect=", INT, ",", INT ], [ "style=", ID ], { typed_option } ;
spawn         = "spawn", ID, INT, INT, [ "rect=", INT, ",", INT ] ;
transition    = "transition", ID, RECT,
                [ "to=", ID ], [ "destination_spawn=", ID ], [ "spawn=", ID ],
                [ "style=", ID ], { typed_option } ;
anchor        = "anchor", ID, INT, INT,
                [ "kind=", ID ], [ "rect=", INT, ",", INT ],
                [ "style=", ID ], { typed_option } ;
patrol        = "patrol", ID, POINT_LIST ;
exclude       = "exclude", ID, RECT ;
fade          = "fade", ID, RECT ;
sign          = "sign", ID, STRING, INT, INT, SIDE,
                [ "style=", ID ], { typed_option } ;
landmark      = "landmark", ID, ID, RECT,
                [ "style=", ID ], { typed_option } ;
package       = "package", "urban", "1" ;
prefab        = "prefab", ID, ID, INT, INT,
                [ "rotation=", ("0" | "90" | "180" | "270") ],
                [ "mirror_x=", BOOL ], [ "mirror_y=", BOOL ],
                { "param.", ID, "=", LITERAL } ;
override       = "override", ID, typed_option, { typed_option } ;

RECT          = INT, INT, INT, INT ;
POINT_LIST    = INT, ",", INT, { "|", INT, ",", INT } ;
RECT_LIST     = INT, ",", INT, ",", INT, ",", INT,
                { "|", INT, ",", INT, ",", INT, ",", INT } ;
SIDE          = "north" | "east" | "south" | "west" ;
BOOL          = "true" | "false" ;
NUMBER        = [ "-" ], INT, [ ".", INT ] ;
```

`elevation` is an authored view-layer plateau height in 3D world units. It must
be finite and between `0` and `8`; the terrain mesh tapers the value to zero
near map boundaries so connected streets remain readable. It does not change
2D collision, navigation, stable IDs, transition placement, or save identity.
The compiler version is `4` because elevation participates in the canonical
fingerprint. Toompea currently uses `elevation=2.8`.

### Exact primitive mappings

| `.rrmap` command | Exact `MapBlueprint` call |
|---|---|
| `map` | `MapBlueprint.new(...)` plus typed metadata fields |
| `source` | `add_source_reference()` |
| `surroundings` | `surroundings()` or repeated `surroundings_side()` |
| `camera` | `camera_bounds()` |
| `style` | `style()` |
| `terrain` | `terrain_rect()` |
| `terrain_rects` | `terrain_rects()` |
| `stroke` | `terrain_stroke()` |
| `building` | `structure_rect()` |
| `wall` | `wall_run()` |
| `prop` | `prop()` or `prop_rect()` when `rect=w,h` is present |
| `spawn` | `player_spawn()` or `player_spawn_rect()` |
| `transition` | `transition()` |
| `anchor` | `interaction_anchor()` or `interaction_anchor_rect()` |
| `patrol` | `patrol_path()` |
| `exclude` | `excluded_rect()` |
| `fade` | `fade_rect()` |
| `sign` | `direction_sign()` |
| `landmark` | `view_landmark()` |
| `package urban 1` | `use_prefab_package(UrbanPrefabPackage.create())` |
| `prefab` | `prefab_instance()` with `MapTransform` |
| `override` | `override_object()` |

`placement_row` and arbitrary prefab definitions are intentionally not exposed in v1. They remain typed GDScript capabilities because a safe compact grammar has not demonstrated a readability benefit for them.

Typed style/override keys are closed to the compiler's current semantic fields: `enabled`, `terrain`, `rect`, `wall_height`, `wall_height_scale`, `wall_color`, `roof_color`, `wall_material`, `roof_material`, `door_side`, `ridge_axis`, `primitive`, `cell`, `facing`, `style_variant`, `visual_offset_px`, `destination_scene_id`, `destination_spawn_id`, `spawn_id`, `spawn_offset_px`, `highlight_area`, `view_landmark_id`, `kind`, `direction`, `top_px`, `door_material`, `passage_axis`, `tower`, and `faction`. Each key has one parser type; unknown keys are rejected before compilation. The boolean `tower` key on a wall-kind building forces the round limestone tower dressing (drum, conical roof, arrow slits) regardless of footprint size; without it the small-footprint heuristic applies. The optional `faction` name selects readable heraldry for tower pennants, courtyard `banner` props, and merchant-cog mastheads (`danish_crown`, `livonian_order`, `hanseatic`, `harju_kings`, `black_cloaks`, `cult_metsik`, `pskov_novgorod`, `novgorod`, `pskov`, `vitalienbruder`). Prefer `novgorod` (bear) or `pskov` (lynx) when eastern trade cloth should show an animal charge; `pskov_novgorod` keeps the joint fess for undivided emissary placement. `black_cloaks` uses an invented swallow on black cloth (not the historical Brotherhood of Blackheads). `vitalienbruder` flies no flag. Confidence notes live on `FactionHeraldry`.

`round_tower=true` selects a circular limestone footprint independently of the historical completion flag `tower=true`. Use `wall_walk_axis=x|z` on a round tower when an elevated patrol corridor continues through it; this opens matching gameplay collision and cuts a character-scale upper portal. `interior_side=north|south|east|west` may orient blind wall arcades on ambiguous internal circuits; boundary walls otherwise derive their protected city face from map bounds.

`wall_material` and `roof_material` are optional string keys on house `style` blocks. They select the 3D mesh-builder surface family for walls and roofs. Allowed `wall_material` values: `plaster`, `timber`, `smoked_plaster`, `brick`, `plank`, `log`, `limestone`, and `stone`. Allowed `roof_material` values: `tile`, `shingle`, `thatch`, and `straw`. When omitted, houses fall back to a deterministic id-hash mix documented in `map_view_mesh_builder_buildings.gd`. Interior partition styles may use `wall_material` without `roof_material`.

### AI authoring checklist

1. Start with `rrmap 1`, then exactly one `map` line.
2. Use stable lowercase IDs. Never derive gameplay IDs from declaration order.
3. Declare exactly one `spawn`.
4. Keep coordinates in integer cells and paint terrain in explicit `layer`/`order` when overlaps matter.
5. Prefer one semantic command per line; use comments for intent, not hidden data.
6. Quote human-facing text and source paths. Do not invent commands or override keys.
7. Run parser/compiler tests and compare canonical fingerprints before proposing a migration.
8. If the vocabulary cannot express the map exactly, keep or extend the typed GDScript path instead of encoding data into strings.

### Complete non-production example

This is the complete first trial source, mirrored in `tests/fixtures/maps/rrmap_courtyard_example.rrmap`:

```rrmap
# Small non-production trial. Lower Town remains authored in typed GDScript.
rrmap 1
map rrmap_courtyard_example loc.rrmap_courtyard_example 20 14 grass scope=prototype active=false palette=clean_painted seed=42042 cell_size=32
source "docs/MAP_AUTHORING.md"
style house.warm wall_height=96 wall_color=806f5cff roof_color=453027ff door_side=south
terrain yard dirt 2 2 16 10 order=1
stroke path cobblestone 0,7|10,7|10,13 thickness=2 order=2
building house.main house 4 3 5 3 style=house.warm
wall wall.north 2 2 17 2 thickness=1 openings=9,2,2,1
prop prop.well well 10 8
spawn spawn.main 3 7
anchor anchor.house 6 6 kind=door
patrol patrol.watch 3,7|10,7|16,7
transition exit.south 10 13 2 1 to=prototype_hub destination_spawn=entry.north spawn=spawn.main
sign sign.exit "to prototype hub" 9 12 south
exclude blocked.storage 15 9 2 2
fade fade.house 4 3 5 3
landmark landmark.gate gate_arch 9 2 2 1 wall_color=8c8980ff top_px=128 passage_axis=z
camera 1 1 18 12
surroundings north town west town
```

Unlisted sides render no exterior backdrop. Use `woodland` only where a meadow treeline is intended; coastal maps should prefer `water` on sea-facing edges (see `content/maps/reval_harbor_north.rrmap` and `content/maps/reval_harbor_east.rrmap`).

```rrmap
surroundings north water east water west town south town
```

`MapRrmapParser.canonical_print()` emits a deterministic normalized v1 source. Tests require `parse -> canonical print -> parse -> canonical print` stability and an unchanged compiled fingerprint.

### Grass, bushes, and Estonian trees

Terrain rectangles and strokes accept `style=<id>`. When the style id names a reviewed vegetation variant, the compiler stores `style_variant` on the resulting zone and applies default movement penalties for dense bush styles. Supported grass variants: `grass.short`, `grass.tall`, `grass.flowers`, `grass.dry`, `grass.mossy`. Bush terrain variants: `bush.dense`, `bush.scrub`. Tree stand variants: `tree.mixed`, `tree.deciduous`, `tree.spruce`, `tree.pine`, `tree.birch`, `tree.oak`, `tree.alder`, `tree.aspen`, `tree.maple`, `tree.linden`, `tree.apple`, `tree.cherry`, `tree.orchard`. Optional size pins use a third segment (`tree.oak.small`, `tree.birch.large`); the default size is medium. Authors may override speed with `movement_speed_multiplier` on the style block or inline on a prop.

```rrmap
style grass.flowers
style bush.dense movement_speed_multiplier=0.55
style tree.oak
style tree.birch.large
terrain meadow.flowers grass 4 34 18 8 style=grass.flowers order=10
terrain scrub.bushes grass 62 24 8 6 style=bush.dense order=10
terrain boundary.wood forest_floor 0 0 20 12 style=tree.mixed order=10
prop bush.west bush 8 38 rect=2,2
prop yard.oak tree 42 18 style=tree.oak
prop road.birch tree 90 44 style=tree.birch.large
```

`prop bush` and `prop tree` place slow-down volumes over their `rect=` footprint (or around the anchor cell when no rect is given). Tree props resolve one of ten local woodland and orchard species (spruce, pine, birch, oak, alder, aspen, maple, linden, apple, cherry) at small, medium, or large scale. Visual scatter for woodland zones and exterior `woodland` surroundings uses the same species catalog and map seed; they do not change collision or navigation.

## Production hardening contract

### One canonical semantic path

`MapBlueprint` is the sole semantic authoring model for migrated maps. Safe `.rrmap` text parses into that same model. `MapBlueprintCompiler` is the only conversion into canonical `MapDefinition`. The editor preview, runtime bootstrap, fixed-size terrain chunk index/renderer, `MapNavBuilder`, parity/routes tooling, and `MapView3D` all consume that compiled definition or its `MapBuilder` grid. They must not reinterpret blueprint primitives. `test_map_pipeline_hardening.gd` compares fingerprints and canonical snapshots before and after these consumers and verifies their semantic counts.

Chunk ownership is derived runtime metadata. `MapChunkRuntimeIndex` indexes stable objects from canonical world-space records and keeps handles as `{location_id, object_id}`. `MapStableStateStore` is the version-2 persistence boundary: entities use stable IDs plus signed `global_cell` and `sub_cell`; static objects store deltas. Chunk coordinates, node paths, instance IDs, local cells, and owner chunks are never save authority. Version 1 loads by preserving existing fields and adding empty `world_state`; unknown record fields survive round trips; unknown archetypes and fingerprint mismatches produce errors rather than data loss.

### Supported scale and budgets

The supported production partition is 32x32 cells per logical chunk, a 2-cell navigation overlap, simulation radius 1, and resident/load radius 2 (at most 25 resident chunks around focus). The checked smoke profiles are 32, 64, 128, and 256 cells square. These are coverage profiles, not a promise that a monolithic 256x256 scene is shippable.

Budgets from `tools/benchmarks/large_map_benchmark_config.json` are: chunk activation p95 <= 50 ms, chunk navigation bake p95 <= 25 ms, main-thread streaming <= 4 ms/frame, <= 5,000 resident nodes, <= 900 resident collision shapes, <= 256 MiB resident delta, and steady frame p95/p99 <= 16.67/25 ms. CI treats timings as reported evidence because shared runners are noisy; structural contracts and counts are hard gates. Preserve `build/benchmarks/large-map-ci-smoke.json` when investigating regressions and run the full benchmark on target hardware before raising scale or budgets.

### Known limitations

- Streaming is fixed-size and definition-derived; it is not a seamless-world authoring system or a network replication format.
- Coarse prototype routing is not a production world A* graph. Loaded navigation remains authoritative, and cross-chunk portal refinement still needs map-specific evidence.
- Headless benchmarks do not measure target-GPU cost. Visual LOD and camera-visible performance require a non-headless target-hardware capture.
- The renderer can amplify static nodes, and water collision remains expensive. Chunk residency bounds these costs but does not replace batching or collision merging.
- Fingerprint mismatch requires an explicit content migration. The store does not guess renamed IDs, deleted archetypes, or scene-node state.
- Editor chunk overlays are diagnostics, never authored ownership. Generated preview nodes remain disposable.

## Migration guidance for remaining maps

Do not bulk-migrate maps. For one explicitly scoped map at a time:

1. Freeze its current `MapDefinition`, stable IDs, transitions, required route endpoints, and a canonical parity fixture.
2. Inspect nearby styles, prefab packages, runtime assets, and source references before authoring.
3. Author a typed blueprint or safe `.rrmap` source that produces the same semantic IDs. Add the source and factory to `MapBlueprintRegistry` in the same change.
4. Run parser/compiler/audit headlessly. Resolve errors; review warnings rather than suppressing them generically.
5. Add map-specific parity and route tests before switching the runtime factory. Include collision, navigation, transitions, anchors, 2D preview, and 3D semantic counts.
6. Preview in Godot and review diagnostics and captures. Generated nodes are evidence, not content.
7. Switch only that map's thin runtime adapter after parity is protected. Keep the old fixture until the migration diff is reviewed.
8. If an intentional semantic change is included, isolate and explain it, update external stable-ID references atomically, and regenerate parity only with the explicit guarded command.

A map is not migrated merely because it compiles. Unregistered sources, unprotected parity, renamed IDs, or batch conversion are release blockers.
