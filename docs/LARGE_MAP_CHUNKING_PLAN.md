# Large-map chunking implementation plan

Decision: [ADR 0010](adr/0010-large-map-runtime-chunking.md)  
Prerequisite: compact authoring and Lower Town parity gates from [ADR 0009](adr/0009-map-blueprint-authoring-architecture.md) are stable.

Each milestone can merge independently behind a disabled project setting or test-only entry point. Production runtime behavior remains unchanged until M7.

## M0 - Stabilization gate and reproducible evidence

**Deliverables**

- Freeze the compact authoring/compiler version used by Lower Town.
- Retain `large_map_benchmark_config.json` as the proposed runtime budget source.
- Archive one raw benchmark artifact per reference-machine run with commit, engine, OS, methodology, and profile metadata.

**Acceptance criteria**

- Lower Town deterministic compile, semantic validation, parity fixture, collision/navigation, scene, and visual checks pass twice from a clean `.godot` cache.
- Two identical blueprint compilations have the same fingerprint and semantic snapshot.
- Full benchmark exits 0 and emits all six profiles: Lower Town pipeline/scene plus synthetic 32/64/128/256.
- Synthetic 32x32 p95 activation <= 50 ms and nav bake <= 25 ms on the reference machine.

## M1 - Pure chunk coordinate and ownership library

**Deliverables**

- Move the tested prototype math into a production-neutral `ChunkGrid` value/service library.
- Define signed global cell/sub-cell conversions, half-open bounds, chunk origins, deterministic area ownership, and configuration validation.
- Keep stable object IDs and authored fingerprints independent from chunk size.

**Acceptance criteria**

- Table/property tests cover points and rectangles at `-size-1`, `-size`, `-1`, `0`, `size-1`, `size`, and `size+1` on both axes.
- Shuffling intersecting chunk candidates 1,000 times never changes ownership.
- Repartitioning fixtures from 32 to 16 or 64 changes owner hints but preserves every stable ID, global position, and canonical semantic fingerprint.
- No production scene references the library yet.

## M2 - Compiled world index and stable reference registry

**Deliverables**

- Build an immutable index from one or more canonical `MapDefinition` outputs to owner/consumer chunk records.
- Add stable handles `{location_id, object_id}`, unresolved-reference behavior, load-state notifications, and duplicate-ID diagnostics.
- Store only data/metadata in the global index, never scene nodes.

**Acceptance criteria**

- Index output is byte-identical for shuffled canonical input arrays.
- Every semantic object has exactly one owner and all intersecting chunks are listed as consumers.
- Cross-chunk references resolve before, during, and after target unload without changing the handle.
- Duplicate or missing stable IDs produce deterministic diagnostics with source location.
- A 256x256 synthetic index builds within 50 ms p95 and uses <= 16 MiB on the reference machine, excluding scene content.

## M3 - Chunk extraction and disposable scene assembly

**Deliverables**

- Extract a chunk-local immutable view from the world index: core terrain, owner objects, consumer proxies, collisions, markers, and global-to-local transforms.
- Add a test-only chunk assembler that reuses current renderer primitives without changing `MapSceneBootstrap`.
- Ensure only owners create collision or authoritative dynamic entities.

**Acceptance criteria**

- The union of chunk core terrain exactly equals the monolithic terrain grid with no gaps or duplicate core cells.
- Boundary-spanning fixture produces one authoritative collision/entity and the expected clipped visual proxies.
- Loading a 5x5 resident set from the synthetic world stays <= 5,000 nodes, <= 900 collisions, and <= 256 MiB delta.
- One 32x32 chunk activation is <= 50 ms p95; its main-thread scene attachment can be sliced into <= 4 ms batches.
- Destroying all chunk roots returns live node/RID counts to their pre-test baseline, allowing documented engine caches.

## M4 - Navigation tiles, border portals, and coarse world routing

**Deliverables**

- Bake each chunk core plus 2-cell overlap.
- Quantize reciprocal border portals and build a location-level coarse A* graph.
- Refine coarse routes with current local navigation as chunks activate; support invalidation/reroute.

**Acceptance criteria**

- Every traversable seam fixture publishes reciprocal portal IDs, endpoints, flags, and clearance.
- Blocked seam fixtures publish no portal; narrow seams below `2 * AGENT_RADIUS` are rejected.
- A route crossing at least 10 chunks reaches the expected target and remains deterministic under shuffled chunk load order.
- Unloading an intermediate chunk preserves the coarse route handle and refinement resumes after reload.
- Each 36x36-cell overlap bake is <= 25 ms p95 on the reference machine; no test invokes a whole-location navigation bake.

## M5 - Persistent world state and save migration

**Deliverables**

- Add version 2 save schema with location/entity stable IDs, global cell plus sub-cell position, state deltas, optional diagnostics fingerprints, and migration registry.
- Hydrate/dehydrate owner entities on chunk lifecycle and retain unresolved cross-chunk references.
- Implement version 1 to version 2 migration without introducing chunk IDs as authority.

**Acceptance criteria**

- Version 1 fixtures migrate deterministically and retain all previously representable state.
- A dynamic entity can cross a chunk border, unload, save, reload, and respawn once at the same global position/state.
- Static opened/destroyed/looted deltas survive owner unload/reload.
- Repartitioning a version 2 save from chunk size 32 to 16 and 64 yields semantically identical loaded state.
- Load/unload without gameplay mutation produces an empty state diff and byte-identical canonical save after round trip.
- Unknown fields are retained where specified; unknown archetypes fail with stable actionable diagnostics.

## M6 - Streaming scheduler, radii, and visual LOD

**Deliverables**

- Add focus tracking, radius-1 simulation, radius-2 residency/prefetch, unload hysteresis, deterministic priority, teleport handling, and cancellation.
- Implement LOD0/1/2 visual representations without changing gameplay semantics.
- Add instrumentation markers for queue latency, preparation, main-thread attach, nav activation, memory, nodes, collisions, and frame spikes.

**Acceptance criteria**

- Continuous traversal across a 16-chunk route never leaves the player without the current and next route chunk simulation-ready.
- Main-thread streaming work is <= 4 ms in 99% of frames and no streaming frame exceeds 25 ms in the reference traversal capture.
- Resident nodes <= 5,000, collisions <= 900, and memory delta <= 256 MiB at radius 2 in the agreed stress fixture.
- Frame time p95 <= 16.67 ms and p99 <= 25 ms with representative NPC simulation on target hardware.
- LOD transitions show no missing terrain, duplicate authoritative objects, collision changes, or stable-ID changes.
- Teleport test activates destination core before player spawn and cancels obsolete work without leaks.

## M7 - Lower Town shadow integration, parity, and opt-in rollout

**Deliverables**

- Run the chunk service in shadow mode against Lower Town while the monolithic runtime remains authoritative.
- Compare ownership, terrain, objects, collision, routes, anchors, transitions, and persistence decisions.
- Add a disabled feature flag for chunk-authoritative Lower Town, then enable only after parity and performance sign-off.

**Acceptance criteria**

- Shadow output has zero semantic, collision, transition, anchor, and required-route mismatches over the full Lower Town parity fixture.
- Visual captures at chunk seams match approved Lower Town references with no visible gaps or LOD popping in the agreed camera path.
- Chunk-authoritative startup improves full-scene startup from the recorded 2.93 s baseline and stays within all resident/streaming budgets.
- Save/load compatibility matrix passes version 1 migration, version 2 same-config load, and version 2 repartition load.
- Feature flag defaults off for one release/test cycle; disabling it restores the unchanged monolithic path.

## M8 - Production cutover and removal criteria

**Deliverables**

- Make chunk-authoritative loading the default only for maps explicitly marked compatible.
- Retain rollback telemetry and the monolithic path until all active maps pass the same gates.
- Remove the old path in a separate reviewed change, never as part of initial rollout.

**Acceptance criteria**

- Every active map has chunk parity, seam navigation, save compatibility, target-hardware performance, and visual capture evidence.
- No unresolved high-severity streaming, duplication, navigation, persistence, or leak defect remains.
- Two release candidates complete soak traversal and repeated save/reload without budget regression.
- Removal ADR records rollback history, benchmark comparison, and save compatibility commitment.
