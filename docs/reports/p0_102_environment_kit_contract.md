# P0-102 Environment Kit Contract and Gap Inventory

**Status:** Planning baseline for P0-102
**Owner:** P0-102a / R-357
**Snapshot:** 2026-08-01
**Scope:** The shared 3D environment kit for the forge, street/well, brewery, and checkpoint spaces in the Lower Town slice.

This report defines the production contract before module assembly begins. It is an interface and ownership document, not a runtime implementation. The kit must reuse the existing map/compiler/view boundaries and must not absorb ordinary-house tier authoring, plot dressing, or exceptional landmark work owned by P2-063-P2-067 and P0-101.

## 1. Authoritative decisions

The following sources are normative for this work:

- [`docs/ART_BIBLE.md`](../ART_BIBLE.md): saturated Baltic fantasy/anime presentation, painterly PBR, readable macro/meso/micro detail, and the value hierarchy that keeps players, interactables, routes, and doors above environmental noise.
- [`docs/MAP_AUTHORING.md`](../MAP_AUTHORING.md): RRMap/MapDefinition is the semantic source of truth; one authored cell is one world unit in the 3D view; view geometry must not change collision, navigation, interactions, or fingerprints; stable IDs are public API.
- [`history/dossiers/architecture/burgher-house-plan.md`](../../history/dossiers/architecture/burgher-house-plan.md): 1343-safe gable-to-street plots, 7-11 m frontage rhythm, mixed timber/stone fabric, steep roofs, cellar necks, rear yards, and the diele/dornse sequence.
- [`docs/reports/burgher_house_typology_contract.md`](burgher_house_typology_contract.md): closed `house_tier` values, tier height/hoist rules, ward bias, rejection rules, and parser/compiler propagation.
- `content/maps/lower_town_slice.rrmap`: current stable map IDs, target-space anchors, routes, transitions, props, and existing visual style data.

### Non-negotiable contract

1. **RRMap owns intent.** New module placement, stable IDs, footprint, route clearance, terrain, and authored style keys belong in the map source. Generated scene nodes and 3D meshes are disposable views.
2. **The existing runtime contract stays stable.** Modules feed `MapDefinition` through the existing parser/compiler and are rendered through `MapViewMeshBuilder`; no parallel environment-map dictionary or scene-only placement API is allowed.
3. **One cell equals one world unit.** Asset pivots and footprints must be authored in metres and checked against the map `rect` rather than hidden inside oversized visual envelopes.
4. **View-only builders stay view-only.** Environment meshes, materials, decals, and visual wear cannot create collision, navigation, gameplay triggers, patrol blockers, or save-state effects.
5. **Stable IDs are preserved.** Existing IDs such as `kalev_smithy`, `foaming_mug_brewery`, `cistern`, `checkpoint_west`, `checkpoint_east`, `smithy_door`, and `brewery_door` are map-facing interfaces. A visual replacement must keep the same ID or provide an explicitly reviewed migration.
6. **Ordinary and exceptional geometry are separate.** Ordinary fabric may use shared house/module families. Churches, guild halls, civic buildings, gatehouses, and Viru Gate landmark geometry must stay on the exceptional/landmark path.
7. **Evidence status controls content.** The kit may stylize color, wear, and readable shape grouping, but it may not introduce post-1400 tourist facades, universal tiled roofs, modern restaurant interiors, or later fortification enrichment.

## 2. Shared interface inventory

| Interface | Current source or hook | Contract for P0-102 | Gap / action |
|---|---|---|---|
| Map source | `content/maps/*.rrmap` via `MapRrmapParser` | Add only typed, stable map primitives and supported keys | No new raw dictionary escape hatch |
| Compiled building | `MapDefinition.buildings[]` | Preserve `id`, `kind`, `footprint`, height, door/ridge orientation, material keys, and optional `house_tier` | Tier assignment remains P2-067 |
| Ordinary building renderer | `MapViewMeshBuilder.build_building()` -> `MapViewMeshBuilderBuildings` | Ordinary houses use shared wall, roof, facade, chimney, and historic-detail helpers | Tier-specific authored model handoff is not present yet |
| Exceptional boundary | `MapViewMeshBuilderBuildingRegistry` and `build_exceptional_building()` | New environment modules must not register as exceptional unless they are genuinely landmark/institutional | Add acceptance coverage, not ordinary-house exceptions |
| Wall and roof materials | `MapViewMeshBuilderHouseStyles`, `MapViewMaterials`, `MapViewMeshBuilderConfig` | Resolve limestone, log, plank, plaster/timber and tile, shingle, thatch using deterministic per-building inputs | Named worn/repaired states are not a separate map key yet; document and test the shared derivation |
| Prop renderer | `MapViewMeshBuilder.build_prop()` -> prop model modules | Use existing prop kinds and validated `style_variant`, `facing`, `rect`, and visual offsets | Dedicated environment kit registry is absent; keep additions narrow and reusable |
| Terrain and wear | RRMap terrain/style lines plus view-only `MapViewDecals` | Use packed earth, mud, grass, cobble, drainage cues, and restrained `mud`/`wet_threshold`/`grime`/`soot` decals | Space-specific wear coverage needs acceptance evidence |
| Routes and entrances | `anchor`, `transition`, `patrol`, `exclude`, `building_id`, `transition_visual` | Modules must preserve route, transition, patrol, and interaction clearance | Focused four-space tests are required |
| Provenance and asset checks | `assets/SOURCES.csv`, `tools/verify_asset_lint.py`, `tools/validate_asset_sources.py` | Every new shipped asset and derived map must have pivot, scale, source, and provenance evidence | P0-102b/c must add scoped rows only for new assets |

## 3. Module family matrix

The matrix is the minimum shared kit. A module is complete only when its visual output, map-facing inputs, pivot/scale behavior, and route safety are covered. A module can be procedural or an imported asset, but it must not encode a map-specific camera, world coordinate, or quest rule.

| Family | Required read and variants | Map-facing inputs | Reuse targets | Current status / owner |
|---|---|---|---|---|
| Ordinary wall shell | Log, plank, plastered-timber, limestone; repaired/worn variation without a global wash | `building` ID, `footprint`, `wall_height`, `wall_material`, `wall_color`, optional `house_tier` | Forge, street/well, brewery, checkpoint background fabric | Procedural material/style helpers exist; tier-aware kits are P2-063-P2-065 |
| Gable and roof | Gable to street, steep pitch; tile for affluent stone, shingle/thatch for ordinary timber/service fabric | `roof_material`, `roof_color`, `ridge_axis`, footprint | All four spaces | Procedural roof exists; explicit tier selection remains downstream |
| Door and threshold | Readable entry, raised threshold/cellar neck where appropriate, facade-aligned transition | `transition`, `building_id`, `door_side`, `transition_visual` | Smithy, brewery, ordinary houses, checkpoint access | Door builder and transition contract exist; cellar-neck/threshold dressing is P2-066 |
| Upper storage face | Small openings/hatches and optional hoist beam, never late-Gothic cross windows | Merchant-tier house metadata and authored facade hook | Merchant street fronts only | Not part of P0-102 assembly; P2-063/P2-064 own tier kit and P2-066 owns hoist dressing |
| Boundary wall/fence | Limestone party wall or timber/wattle fence, gates, open route-facing thresholds | `building`/`wall`, `openings`, stable ID, map rect | Rear plots, smithy yard, brewery yard, checkpoint edge | Wall primitives and fence props exist; shared module consistency and tests are a gap |
| Drainage and ground wear | Packed earth/mud, threshold wetness, restrained grime/soot, no blanket cobble | terrain rectangles/strokes, decal IDs and radii | Forge apron, brewery service yard, street/well, checkpoint | Terrain and decal systems exist; space-specific placement acceptance is a gap |
| Forge/workshop dressing | Fire-separated work zone, anvil/furnace/bellows/tools, charcoal/scrap/fuel, repaired surfaces | Existing prop IDs, `rect`, `facing`, style variants, anchors | Kalev smithy and compatible craft yards | Existing smithy prop families are available; P0-102b owns shared assembly validation, not a second forge scene |
| Well/street kit | Well body, apron, wash vessel or drainage cue, clear approach and route edges | `well`/`wash_tub` props, terrain/decal IDs, stable anchor | `cistern`, monastery/public wells, street approaches | Well and wash props exist; a reusable street/well composition contract and focused test are missing |
| Brewery service yard | Kegs, malt sacks, work surface/storage, door apron, restrained wet/mud wear | Existing brewery prop kinds and `brewery_door` interface | `foaming_mug_brewery` and future brewery yards | Keg/sack builders exist; shared yard assembly and safety test are P0-102c |
| Checkpoint / gate approach | Readable route throat, carts/stall/barricade dressing only where appropriate, no freestanding door in open yard | Gate/wall/landmark records, checkpoint anchors, `transition_visual=ground` | `checkpoint_west`, `checkpoint_east`, Viru approach | Existing gate/wall and cart/stall primitives exist; dedicated checkpoint composition and acceptance are P0-102c |
| Small trade/yard props | Barrels, crates/pallets, carts, signs, firewood, vegetation, fences | Validated prop kind, stable ID, rect/style/facing | All four spaces | Broad prop registry exists; replace placeholders only where a scoped trade module needs it |
| Material/wear presentation | Per-building seed, roughness/material identity, repaired patches, local wear decals | Building/prop ID and style variant; no gameplay fields | All four spaces and day/night captures | P0-053 materials and decals exist; an explicit shared wear checklist is required |
| Exceptional landmark handoff | Churches, guild/civic masses, gatehouses, Viru Gate arch/towers remain unique | Registry category, landmark IDs, authored landmark primitives | Checkpoint view context only, never ordinary kit source | Boundary exists; P0-102 must test it and must not extend it with house substitutes |

## 4. Four target-space profiles

### 4.1 Forge

**Current map surface:** `kalev_smithy` interior plus the Lower Town `kalev_smithy` building and yard. The interior already exposes `forge_anvil`, `forge_furnace`, `forge_bellows`, `forge_tongs`, `forge_hammer`, `forge_punch`, `quench`, `coal_store`, and `iron_scrap_store`. The exterior has `courtyard_firewood`, `courtyard_quench`, `hay_store`, `smithy_yard_fence_north`, `smithy_yard_fence_east`, `smithy_door`, and its transition.

**Required shared kit:** smoked/plastered workshop shell, furnace/anvil/tool grouping, domestic/workshop fuel, yard fence, mud/soot/grime thresholds, and a clear approach from the courtyard. The interior `ap.*` activity points remain owned by the smithy routine contract and must not be replaced by visual module placement.

**Acceptance anchors:** `smithy_door`, `anvil`, `ledger`, `bed_alcove`, `smithy_door_transition`, `courtyard_quench`.

**Known gap:** the current visual system has strong forge-specific props but no explicit reusable forge-yard composition contract that proves the same modules can be placed without blocking the door, activity points, or route. R-356 owns that assembly and proof.

### 4.2 Street/well

**Current map surface:** Lower Town through-routes `road.pikk`, `road.viru`, and `road.karja`; the `cistern` well at `(104,60)` with `cistern_wash_tub`; and the `monastery_well` at `(73,11)`. The map already uses dirt, mud, grass, sand, and limited cobble rather than a district-wide paved substrate.

**Required shared kit:** well body and readable apron, wash/drainage cue, wet threshold/grime, adjacent wall or yard edge, and a route-safe street surface. The composition must be legible from gameplay camera without turning the well into an obstacle or placing a prop on the road spine.

**Acceptance anchors:** `cistern`, `cistern_wash_tub`, `monastery_well`, nearby `checkpoint_east`, and the through-route strokes.

**Known gap:** `well` and `wash_tub` are available prop primitives, but there is no named street/well family that defines the shared apron, drainage, wear, and clearance contract. R-356 owns this narrow composition, not a new gameplay interaction system.

### 4.3 Brewery

**Current map surface:** `foaming_mug_brewery` at `(76,62)` with `brewery_door`, `brewery_keg_stack`, `brewery_malt_sacks`, and nearby `evidence_barrels`/market goods pallet. The brewery has authored mud at the door and is adjacent to the smithy/yard route network.

**Required shared kit:** plastered-timber or mixed workshop shell, service-yard storage, keg/malt grouping, threshold wear, and an unobstructed door approach. The kit should make brewery function readable by silhouette and material grouping, not by adding a bespoke camera or quest marker.

**Acceptance anchors:** `foaming_mug_brewery`, `brewery_door`, `brewery_keg_stack`, `brewery_malt_sacks`, `brewery_door` anchor and transition route.

**Known gap:** the prop models exist, but a reusable brewery service-yard composition, material/wear state matrix, and route regression are not yet documented as one contract. R-358 owns this assembly.

### 4.4 Checkpoint / gate approach

**Current map surface:** `checkpoint_west` and `checkpoint_east` anchors; the Viru gate wall/tower/jamb records; `viru_gate_arch` and `viru_foregate_arch`; `market_stall_gate`, `gate_cart`, `sign.viru_road`, and the ground transition at `viru_road_boundary`.

**Required shared kit:** a route-facing checkpoint read made from walls, gate leaves/arch context, ground cue, sign/cart/stall dressing where justified, and mud/wear at the throat. The approach must preserve the authored gate passage and must not imply the later barbican or post-1346 tower massing.

**Acceptance anchors:** `checkpoint_west`, `checkpoint_east`, `viru_gate_north_tower`, `viru_gate_south_tower`, `viru_gate_arch`, `viru_foregate_arch`, `viru_road_boundary`, `viru_watch` patrol, and `iron_convoy` patrol.

**Known gap:** existing wall/landmark/prop systems can render the pieces, but there is no dedicated checkpoint assembly contract proving that visual dressing keeps both patrols, the gate throat, and ground transition clear. R-358 owns the composition and regression; P0-101 remains the owner of landmark art quality.

## 5. Ordinary house tier boundary and non-duplication

The following work is intentionally outside R-357 and must not be claimed by the environment-kit assembly tasks:

| Task | Owns | Must remain separate from P0-102 module assembly |
|---|---|---|
| P2-063 | `merchant_stone` authored exterior kit | Limestone/mixed merchant facade, hatch rhythm, optional hoist, tile band, generator, GLB, and tier-specific tests |
| P2-064 | `merchant_timber` authored exterior kit | Timber/plastered-timber front, smaller openings, optional stone cellar, shingle/thatch treatment, generator, GLB, and tier-specific tests |
| P2-065 | `craft_boda` authored exterior kit | Compact one/two-storey two-room dwelling, single hearth, no hypocaust/hoist, generator, GLB, and tier-specific tests |
| P2-066 | Plot/street threshold dressing | Cellar-neck steps, plot wall/fence, yard gate, privy, well sweep, lean-to/Hinterhaus, firewood, and merchant-only hoist/loading-hatch dressing |
| P2-067 | Lower Town tier wiring | Authored `house_tier` assignment, ward bias, mesh-builder selection, stable-ID preservation, parity, and Lower Town integration tests |
| P0-101 | Ordinary-fabric and landmark art pass | Final visual sign-off, repeated facade audit, exceptional landmark quality, and gameplay-scale day/night evidence |

P0-102 may consume these outputs after their contracts are accepted. It may provide shared ground, fence, drainage, material, and route-safety infrastructure, but it must not create substitute house GLBs, duplicate tier generators, assign house tiers opportunistically, or turn a generic ordinary building into a church, guild hall, civic building, or gatehouse.

## 6. Gap inventory and handoff checklist

### G-01: Tier-specific house assets and selection are not yet production-complete

- **Evidence:** `house_tier` is parsed, validated, and copied through the compiler, but `lower_town_slice.rrmap` currently uses legacy `style=house.*` records without an explicit tier assignment on its ordinary buildings.
- **Owner:** P2-063, P2-064, P2-065, then P2-067.
- **P0-102 rule:** use current shared procedural house helpers as a compatibility baseline; do not author tier assets or silently assign tiers in the forge/brewery/checkpoint work.

### G-02: Plot dressing is not a general shared kit yet

- **Evidence:** well, firewood, carts, walls, and trade props exist, but cellar-neck, yard-gate, privy, lean-to, and merchant-only hoist/loading-hatch responsibilities are not consolidated into a reusable contract.
- **Owner:** P2-066.
- **P0-102 rule:** use only existing validated prop kinds for scoped space assembly; no replacement plot-dressing generator.

### G-03: Street/well and checkpoint are compositions, not typed families

- **Evidence:** the map exposes common `well`, wall, landmark, cart, stall, sign, and decal primitives, but no `street_well` or `checkpoint` semantic primitive is required by the current RRMap vocabulary.
- **Owner:** R-356 for street/well composition; R-358 for checkpoint composition.
- **Decision:** do not add new semantic primitives for this planning task. Prefer reusable view/helper modules plus existing map-facing primitives. Add a new typed key only if implementation demonstrates that existing interfaces cannot express the contract, with a separate scoped task and parser/compiler tests.

### G-04: Named worn/repaired building states are under-specified

- **Evidence:** per-building material seeds, P0-053 surface materials, and view-only decals already provide deterministic variation, but the environment-kit task does not yet have a shared matrix saying which wear belongs on thresholds, roof edges, joints, forge aprons, brewery yards, or gate throats.
- **Owner:** R-356/R-358 for placement evidence; R-359 for acceptance.
- **Decision:** keep wear as local material/decal presentation keyed by stable IDs. Do not add gameplay state or a universal `wear_level` field merely to label visual differences.

### G-05: Dedicated four-space regression coverage is missing

- **Evidence:** existing tests cover map contracts and individual systems, including house-tier parsing and market prototypes, but no single acceptance suite proves all four P0-102 spaces share scale/material/route rules.
- **Owner:** R-356/R-358 for focused tests; R-359 for final acceptance report.
- **Minimum checks:** deterministic node construction; one-cell/metre scale; expected child/material metadata; no collisions or navigation authored by view builders; transition and anchor clearance; patrol route preservation; day/night readability evidence.

### G-06: Asset/provenance inventory is scoped per future output, not per kit family

- **Evidence:** existing procedural and imported props are registered independently; no P0-102 family manifest exists.
- **Owner:** each implementation task for new assets; R-359 for scoped lint/provenance sweep.
- **Rule:** never rewrite unrelated `assets/SOURCES.csv` rows. Append only new, verified asset paths and derived sidecars for the scoped module.

### G-07: Exceptional boundary coverage must be explicit in acceptance

- **Evidence:** `MapViewMeshBuilderBuildingRegistry` already routes known churches, civic/guild/institutional buildings, and gatehouse categories to `build_exceptional_building()`.
- **Owner:** R-359.
- **Rule:** acceptance must assert that ordinary environment modules do not change the `renderer_boundary=exceptional` behavior and that Viru Gate remains the approved 1343 state. Do not expand the registry as a convenience for ordinary modules.

## 7. Implementation checklist

### R-356 / P0-102b: forge and street/well

- [ ] Build from current wall/roof/material/prop helpers; no new house-tier asset ownership.
- [ ] Cover the forge shell, yard fence, anvil/furnace/tool/fuel grouping, well apron, drainage, and local wear.
- [ ] Keep `smithy_door`, `anvil`, routine activity points, `cistern`, and `monastery_well` interfaces stable.
- [ ] Prove pivots, scale, deterministic output, and no route/anchor blockage with focused Godot tests.
- [ ] Record new assets and sidecars in provenance without absorbing unrelated worktree files.

### R-358 / P0-102c: brewery and checkpoint

- [ ] Build from current wall/roof/material/prop/landmark helpers; no post-1343 fortification enrichment.
- [ ] Cover brewery service-yard storage and threshold wear.
- [ ] Cover checkpoint throat readability using existing wall, gate, cart/stall/sign, ground transition, and mud/wear primitives.
- [ ] Preserve `brewery_door`, `checkpoint_west`, `checkpoint_east`, both patrols, gate passage, and transition clearance.
- [ ] Prove ordinary/exceptional separation and add scoped provenance rows only for shipped assets.

### R-359 / P0-102g: acceptance

- [ ] Verify the four spaces use shared builders/material conventions rather than bespoke camera, scale, or map-coordinate exceptions.
- [ ] Verify log, plank, plastered-timber, and limestone families plus shingle, thatch, and tile roof bands where each space requires them.
- [ ] Verify local worn/repaired presentation in matched day/night captures without lowering player/interactable/route value priority.
- [ ] Verify view-only geometry does not alter collision, navigation, fingerprints, saves, transitions, patrols, or interaction anchors.
- [ ] Verify exceptional churches, civic/guild structures, and Viru Gate remain outside the ordinary kit.
- [ ] Run focused Godot tests, scoped asset lint, and scoped provenance validation; record exact reproductions for any finding.
- [ ] Confirm no P0-101 landmark or P2-063-P2-067 deliverable is claimed as completed by P0-102.

## 8. Definition of ready for implementation

R-356 and R-358 may begin implementation against this report when each new module can answer all of the following without inventing a new runtime contract:

1. Which existing RRMap ID and primitive place it?
2. Which shared builder/material/prop helper renders it?
3. What is its metre footprint and pivot relative to the authored rect?
4. Which route, transition, patrol, or interaction anchors must remain clear?
5. Which historical confidence and 1343 exclusion govern its silhouette/material?
6. Which deterministic wear/decal inputs make it distinct without gameplay state?
7. Which focused test and provenance row prove the result?

If an implementation cannot answer one of these questions, it must stop and add a narrowly scoped follow-up task rather than widening P0-102 implicitly.
