# ADR 0030: Retire the `direction_sign` map primitive

**Reference:** commit `6af41d1d` (signs no longer drawn in the 3D view); maintainer direction 2026-10-07.

## Status

**Accepted, 2026-10-07.** Small cleanup, no scope added; it removes an authored primitive that nothing consumes.

## Context

Painted wooden road signs with destination names read as game UI, not medieval Reval, so `6af41d1d` stopped building geometry for them. The primitive stayed in the pipeline as data only: `MapBlueprint.direction_sign*`, the rrmap `sign` statement and serializer, the compiler expand/build steps, `MapDefinition.direction_signs` and its validation, the chunk runtime index, the parity snapshot, and the alignment editor model. 12 `.rrmap` files authored 58 signs. No gameplay, quest, audio, or navigation code reads them.

## Decision

Remove the primitive end to end: the authored `sign` statements, the blueprint methods, parser, serializer, compiler steps, `MapDefinition.direction_signs`, chunk-index records, the `signs` key in the parity snapshot, and the signs test. Stable IDs of every other primitive are unchanged.

Parity decision (explicit, not a regeneration to get green): `tests/fixtures/maps/lower_town_slice.parity.json` loses only its `signs` array, and `lower_town_slice_legacy_definition.gd` loses its `direction_signs` block. Every other fixture section is untouched.

## Alternatives

- Keep the data for a future wayfinding feature: rejected. Nothing plans to use it, and keeping it costs validation, parity and chunk-index surface. Git history holds the old authoring if signage returns, and a new ADR would define it then.

## Consequences

- Old `.rrmap` files with a `sign` line now fail to parse (unknown statement). None remain in the repository.
- Diegetic wayfinding, if wanted later, comes back as ordinary props or landmarks.
