# ADR 0010: Chunk compiled large maps after compact authoring stabilizes

**Reference:** ADR 0009 follow-up; large-map runtime prototype and baseline  
**Recorded:** 2026-07-17  
**Configuration:** [`tools/benchmarks/large_map_benchmark_config.json`](../../tools/benchmarks/large_map_benchmark_config.json)  
**Evidence:** [`docs/reports/large_map_chunking_baseline.md`](../reports/large_map_chunking_baseline.md)

## Status

Proposed. Do not start production runtime implementation until the compact authoring compiler, semantic validation, representative migration, and parity gates in ADR 0009 are stable.

## Context

ADR 0009 deliberately keeps `MapBlueprint` semantic and compiles it into the existing `MapDefinition`. Chunk coordinates are a runtime performance concern, not authored identity. Lower Town now supplies a compact representative map, but the current runtime still materializes one complete terrain grid, one 2D visual tree, collision for all buildings and every water cell, one navigation bake, and one complete 3D view.

The benchmark in this decision demonstrates that this monolithic model does not scale linearly. On the reference machine, a synthetic 32x32 map costs 2.3 ms to bootstrap and 0.5 ms for an isolated navigation bake. A 128x128 map has 7,839 nodes and 1,284 collision shapes and takes 59.5 ms for navigation. A 256x256 map has 31,251 nodes and 5,124 collision shapes and takes 3.17 seconds for navigation. These are synthetic observations, not production content predictions, but they show where the current architecture stops meeting interactive loading budgets.

Save/load is not implemented yet. `GameState.CURRENT_VERSION` is 1 and state lasts only for the current session. Chunking must therefore define a persistence boundary without freezing an accidental scene-node format.

## Decision

### 1. Layering and rollout gate

Implement chunking as a runtime index and lifecycle layer over canonical compiled `MapDefinition` semantics. `MapBlueprint`, prefab IDs, authored global coordinates, and fingerprints remain independent of chunk configuration. Do not rewrite `MapSceneBootstrap`, `MapAssembler`, `MapNavBuilder`, or `MapViewRuntime` in this ADR/prototype.

Production implementation may begin only after:

- Lower Town compiles deterministically and its semantic, collision, navigation, scene, and visual parity checks pass.
- The compact format and compiler diagnostic schema have no planned breaking change.
- The baseline command in this ADR has been rerun on the target development machine.

### 2. Chunk configuration

The initial configuration is:

| Setting | Value | Rationale |
|---|---:|---|
| Logical chunk size | 32x32 cells | At the current 32 px cell size this is 1024x1024 logic units. The synthetic profile is comfortably below activation budgets and divides common district dimensions without entering authoring semantics. |
| Navigation overlap | 2 cells | 64 logic units, equal to four `MapNavBuilder.AGENT_RADIUS` values. This gives border portals room for clearance and triangulation. |
| Simulation radius | 1 chunk, Chebyshev | Keep the focus chunk and 8 neighbors active for entities and physics. |
| Load radius | 2 chunks, Chebyshev | Keep a 5x5 set resident so one ring is prefetched around simulation. Hysteresis unloads only after the focus moves and the chunk remains outside radius 2 for an implementation-defined grace interval. |
| Visual LOD 0 | distance 0-1 | Full visual, simulation, collision, and local navigation where applicable. |
| Visual LOD 1 | distance 2 | Simplified static meshes/terrain, no dynamic simulation or collision. |
| Visual LOD 2 | distance 3+ | Coarse world proxy, landmark silhouette, or absent when outside camera need. |

`tools/benchmarks/large_map_benchmark_config.json` is the executable source for these prototype values. Changing a value requires updating this ADR rationale and rerunning benchmark and contract tests.

### 3. Global coordinates

- Authored and saved positions use signed global cell coordinates plus sub-cell offsets. Runtime world coordinates remain `global_cell * cell_size + offset` and must not be rebased in persistent data.
- Chunk coordinates are derived with mathematical floor division, including negative coordinates: `chunk = floor(global_cell / chunk_size)`.
- Local cells are derived: `local = global_cell - chunk_origin`. They are disposable runtime data and never serialized as identity.
- Chunk rectangles are half-open: `[origin, origin + size)`. Therefore a point exactly on an east or south boundary belongs to the positive adjacent chunk.
- Rendering may use a transient floating origin later, but conversion happens at the view boundary and cannot affect gameplay coordinates, stable IDs, routing, or saves.

### 4. Deterministic boundary ownership

Every semantic object has exactly one owner chunk and zero or more consumer chunks.

- Point objects are owned by the chunk containing their anchor point under half-open semantics.
- Area objects enumerate chunks intersecting their half-open bounds. The lexicographically smallest `(y, x)` chunk owns the object. Its authored stable ID is the registry key and deterministic tie-break input if ownership rules are extended.
- The owner alone creates persistent state, dynamic entity instances, and authoritative collision.
- Consumer chunks may create clipped visual proxies or navigation obstruction input, but never duplicate authority.
- Changing chunk size may change owner chunk, but never changes the stable object ID or save key.

### 5. Cross-chunk references and coarse routing

References are unresolved stable handles of the form `{location_id, object_id}`. They never store a node path, instance ID, array index, or owner chunk. A world object registry maps each stable handle to metadata, owner chunk, load state, and optional live instance. References remain valid while the target is unloaded and resolve through notification/future-style APIs when it loads.

Long routes use two levels:

1. A deterministic coarse graph contains chunk nodes and authored border portals. Edges include cardinal chunk adjacency plus explicit transitions. The graph may be loaded for the whole location because it contains metadata only.
2. Loaded chunks use normal local navigation between entry and exit portals. A route is refined as chunks load. If a portal becomes invalid, coarse A* reroutes; gameplay never assumes a Manhattan route is traversable.

The executable prototype uses deterministic Manhattan routing only to test coordinate/order semantics. It is not the production routing algorithm.

### 6. Persistent entity state

Persistent state belongs to stable entity IDs, not chunks or scene nodes:

```json
{
  "save_version": 2,
  "world_state": {
    "loc.lower_town_slice": {
      "entities": {
        "char.example": {
          "archetype": "char.example",
          "global_cell": [41, 18],
          "sub_cell": [0.5, 0.25],
          "state": {"alive": true}
        }
      }
    }
  }
}
```

- Runtime activation hydrates owner entities from this store; deactivation writes dirty state before freeing nodes.
- Static authored objects store only deltas keyed by stable ID, such as opened, destroyed, looted, or phase override.
- References persist as stable handles. Chunk IDs and local coordinates are optional cache hints only and are ignored/recomputed when configuration changes.
- Unknown entity fields must be retained by migration where possible; unknown archetypes fail with a diagnostic rather than silently dropping state.

### 7. Navigation border overlap

Each chunk navigation bake consumes its core 32x32 cells plus a 2-cell border. Geometry is clipped to the expanded rectangle. Only polygons whose representative point lies in the core are authoritative; overlap is used to derive matching border portals and clearance.

Adjacent chunks publish portal records with quantized global endpoints, clearance, traversal flags, and a deterministic ID derived from the shared border and endpoint cells. A seam test must prove reciprocal portals and a path at least `2 * AGENT_RADIUS` wide. Navigation polygons may overlap, but agents switch maps only at a matched portal. A chunk never bakes the full world.

### 8. Loading, scheduling, and LOD

- Focus is normally the player owner chunk. Teleports atomically replace focus and synchronously load the destination core before player activation.
- Radius 1 is simulation-ready; radius 2 is resident/prefetched. Loading is prioritized by coarse route, distance, then lexicographic chunk order.
- I/O and pure data preparation may run off-thread. Scene-tree mutation, physics registration, RenderingServer-facing construction, and NavigationServer activation stay on the main thread unless Godot documentation explicitly permits otherwise.
- Main-thread streaming work is sliced to 4 ms per rendered frame. A single 32x32 activation must be below 50 ms p95 in the benchmark, but production should split activation so it does not consume that amount in one frame.
- LOD is visual only. Stable IDs, global coordinates, quest state, and route metadata are identical at every LOD.

### 9. Budgets and measurement policy

Initial resident-set and timing budgets are:

| Metric | Budget |
|---|---:|
| One 32x32 chunk activation CPU p95 | <= 50 ms |
| One chunk navigation bake p95 | <= 25 ms |
| Main-thread streaming work per frame | <= 4 ms |
| Resident nodes | <= 5,000 |
| Resident collision shapes | <= 900 |
| Resident memory delta | <= 256 MiB |
| Steady frame time p95 / p99 | <= 16.67 / 25 ms |

Hardware timing is recorded evidence, not a deterministic CI gate. CI enforces functional contracts and structural counts. Scheduled/reference-machine performance runs compare medians and p95 against the committed budget configuration and preserve raw JSON artifacts.

The current headless frame samples measure idle residency, not camera-visible render/GPU cost. Visual LOD acceptance therefore requires a non-headless capture on the target GPU before production rollout.

### 10. Save compatibility

- The first chunk-aware save is version 2. Version 1 migrates by preserving existing global gameplay state and initializing an empty `world_state`; it does not guess node state.
- Save files record `location_id`, stable entity/object IDs, global coordinates, and semantic state. They do not record chunk size as authority.
- A save may record `map_fingerprint` and `chunk_config_version` for diagnostics. Fingerprint mismatch invokes explicit content migration or a recoverable compatibility error, never silent deletion.
- Repartitioning 32 to another size requires no save migration beyond recomputing owner chunks from global positions and current object bounds.
- Save round trips must be deterministic after canonical key sorting, and loading/unloading a chunk without gameplay changes must produce no state diff.

## Consequences

### Positive

- Compact authoring stays independent from runtime performance policy.
- Stable IDs and global coordinates survive repartitioning and LOD changes.
- Navigation, collision, entities, and visuals can be budgeted per resident set rather than per authored world.
- The synthetic benchmark exposes current scaling limits without creating production streaming code.

### Costs and risks

- Boundary proxies, portal reconciliation, and unload-safe references add lifecycle complexity.
- The current renderer has high static node amplification. Chunking controls residency but does not replace batching/mesh optimization.
- Current water collision creates one shape per water cell. Chunking bounds the count, but collision merging remains a likely later optimization.
- Headless frame time cannot validate visual LOD or GPU budgets.

## Rejected alternatives

- **Chunk during `MapBlueprint` compilation:** rejected because chunk size would contaminate authored identity and fingerprints.
- **Use scene paths or chunk-local IDs for references:** rejected because unloading and repartitioning invalidate them.
- **Assign boundary objects by center point:** rejected because centers can change through harmless shape edits and exact boundary behavior is less obvious than half-open intersection plus deterministic minimum.
- **Bake one navigation polygon for the whole location:** rejected by the 128x128 and 256x256 synthetic bake results.
- **Rewrite the production runtime now:** rejected because compact authoring and parity stabilization are explicit prerequisites.

## Validation

```bash
# Functional contracts, including coordinate, ownership, radius, overlap, routing, and LOD rules
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd

# Full hardware baseline, raw JSON defaults to build/benchmarks/large-map-baseline.json
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  tools/benchmarks/run_large_map_benchmark.sh

# Fast smoke run
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  tools/benchmarks/run_large_map_benchmark.sh /tmp/large-map-quick.json --quick
```

The benchmark is non-production. Neither benchmark scene is referenced by `project.godot`, the map registry, or a production scene.
