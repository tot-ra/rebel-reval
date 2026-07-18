# ADR 0009: Adopt MapBlueprint as the compact map-authoring source

**Reference:** compact map-authoring architecture before implementation
**Recorded:** 2026-07-17

## Status

Accepted and implemented

## Context

The project already has an executable `MapDefinition` contract used by terrain building, collision, navigation, transitions, interaction anchors, the 2D and 3D view layers, map audits, and activation guards. Existing maps construct that contract directly in GDScript. This proved the runtime pipeline, but larger definitions repeat conversion code and accumulate deeply nested dictionaries that are difficult for humans and AI agents to review safely.

Godot scenes are also the wrong authoring boundary. Most map nodes are derived from terrain, footprints, props, and gameplay markers. Treating generated `.tscn` nodes as authored content would duplicate semantic data, invite scene/source drift, and create large merge-sensitive files.

Future campaign maps may require streaming or chunk-based loading. Chunk boundaries are runtime performance concerns, while authored locations, stable gameplay IDs, transitions, and prefab composition are semantic concerns. Coupling chunking to the authoring compiler would make map content depend prematurely on an unmeasured streaming strategy.

## Decision

1. **`MapBlueprint` is the source format for new and migrated maps.** A blueprint is a compact, typed authoring object persisted initially as a small GDScript factory that calls named primitive and prefab APIs. It contains map metadata, stable IDs, cell-space placement, prefab instances, explicit placements, and narrow overrides. Authors must not express new maps as giant `MapDefinition` dictionary builders.
2. **`MapBlueprintCompiler` produces the existing `MapDefinition` runtime contract.** Compilation validates and expands the blueprint, resolves prefab-local coordinates and IDs, converts cell-space geometry to runtime units, applies overrides in a defined order, emits canonical arrays, and computes a deterministic fingerprint. Existing builders, renderers, scene bootstrap code, audits, and gameplay systems continue to consume `MapDefinition`.
3. **Generated Godot scene nodes are derived output, not source of truth.** Runtime nodes are assembled from the compiled `MapDefinition`. A hand-authored scene may remain as a small bootstrap or integration shell, but generated terrain, structure, prop, collision, navigation, marker, and view nodes must not be edited as map content. Any optional generated cache must be reproducible, clearly marked, and safe to delete.
4. **Large-map chunking is a separate runtime layer.** A future chunk or streaming service may partition or index compiled runtime data, but it must consume the `MapDefinition` semantics, preserve authored stable IDs, and remain transparent to `MapBlueprint`. Chunk coordinates and load state are not part of authored gameplay identity.
5. **The initial primitive vocabulary stays deliberately compact.** It covers metadata and bounds, terrain rectangles, rectangular structures and wall runs, props, player spawns, transitions, interaction anchors, patrol paths, excluded areas, fade volumes, direction signs, view landmarks, surroundings metadata, source references, and prefab instances. Exact placement and prefab-child overrides are the escape hatches. An untyped general-purpose raw dictionary primitive is not part of the authoring API.
6. **Stable identity and deterministic output are hard requirements.** Semantic objects receive explicit IDs. Prefab children derive IDs from the instance ID and prefab-local child ID, never from array position or world coordinates. The same blueprint, compiler version, primitive library, and seed must produce semantically identical `MapDefinition` output and the same canonical fingerprint on every supported platform.

The detailed author contract, validation gates, examples, migration rules, and current commands are defined in [`docs/MAP_AUTHORING.md`](../MAP_AUTHORING.md).

## Recommended implementation order and dependencies

1. **Freeze the runtime baseline.** Characterize the existing `MapDefinition` fields, validation, fingerprints, audit registry, collision/navigation behavior, and representative map output. This depends only on the current map pipeline and supplies parity fixtures for later steps.
2. **Implement the `MapBlueprint` model and source validator.** Add typed metadata, primitive records, stable-ID namespaces, cell-space units, diagnostics, and source-reference rules. This depends on the frozen runtime vocabulary and `MapTypes`, but not on rendering or chunking.
3. **Implement prefabs and transforms.** Add prefab-local coordinates, deterministic translation/orthogonal rotation/reflection, namespaced child IDs, cycle rejection, exact placement, and allowlisted child overrides. This depends on blueprint validation and stable-ID rules.
4. **Implement `MapBlueprintCompiler`.** Compile validated blueprints into the unchanged `MapDefinition` contract, canonicalize output ordering, compute fingerprints from canonical semantic data, and run `MapDefinition.validate()`. This depends on steps 1 through 3.
5. **Prove one representative migration.** Migrate a compact map with terrain, a prefab, a transition, anchors, collision, and view metadata. Require semantic snapshot, fingerprint policy, collision/navigation, scene smoke, and visual-capture parity. This depends on compiler tests and existing audit tooling.
6. **Migrate incrementally and guard the boundary.** Move maps one at a time, preserve IDs and external references, and add lint or review guards against new giant direct `MapDefinition` factories. Runtime consumers remain unchanged. This depends on a passing representative migration.
7. **Add runtime chunking only when profiling justifies it.** Define chunk indexing, cross-chunk navigation, lifecycle, and cache policy after compiled maps and stable IDs are established. This depends on the compiler contract and measured runtime requirements, not on completion of every map migration.

## Alternatives

### Keep authoring `MapDefinition` directly

Rejected. Direct construction exposes runtime representation details to every author, encourages large repetitive dictionaries, and makes reusable composition, local overrides, diagnostics, and deterministic canonicalization harder.

### Treat Godot scenes as canonical map content

Rejected. Generated node trees duplicate the semantic map data, are difficult for AI agents to edit safely, and can drift from collision, navigation, and audit data. Small scene bootstraps remain valid, but generated nodes do not become authored map state.

### Introduce JSON, YAML, or a custom text grammar first

Deferred. A typed GDScript blueprint API fits the current repository, preserves Godot value types, avoids a parser dependency, and can be validated headlessly. A future serialization may be added only if it preserves the same `MapBlueprint` semantic model and stable-ID rules.

### Make the compiler produce chunks directly

Rejected. It couples semantic authoring to a runtime optimization before scale and streaming constraints are measured. It would also make chunk movement a source change and threaten stable gameplay identity.

### Allow arbitrary runtime dictionaries as an escape hatch

Rejected. A general raw entry would quickly become the default and recreate the current authoring problem inside the new format. Missing reusable behavior should become a reviewed primitive; one-off composition should use explicit placement or a narrow, validated override.

## Consequences

- New map authoring gains a smaller, reviewable primitive vocabulary while all current runtime consumers keep the `MapDefinition` contract.
- The compiler and prefab library become compatibility-sensitive infrastructure and require deterministic, negative, and parity tests.
- Stable IDs must be designed before layout details. Renaming an ID becomes a migration with external-reference checks rather than a cosmetic edit.
- Scene files become smaller integration shells; generated nodes can be discarded and regenerated.
- Existing direct definitions remain supported during incremental migration, but they are legacy sources and should not receive broad structural growth.
- The repository must maintain parity tooling until all production maps have migrated.
- Runtime chunking can evolve independently without forcing authors to split semantic maps or rewrite IDs.

## Implementation status

The typed blueprint API, safe `.rrmap` parser, deterministic compiler, prefab expansion, machine-readable diagnostics, explicit registry completeness audit, editor preview, and representative Lower Town parity migration are implemented. Production gates and the incremental migration policy are normative in [`docs/MAP_AUTHORING.md`](../MAP_AUTHORING.md). Remaining direct `MapDefinition` maps are intentionally not bulk-migrated.
