# ADR 0004: Clean-painted visual style candidate

**Reference:** TODO P0-036, preparation for P0-040  
**Recorded:** 2026-07-16

## Status

Accepted

## Context

P0-036 requires pixel, digital-woodcut, and clean-painted targets to be compared with identical composition, camera framing, gameplay scale, collisions, and Y-sort. All three were implemented as rendering profiles over `scenes/map_prototype/smithy_courtyard.tscn`. The shared definition contains seven terrain types, medieval Lower Town buildings, forge props, and one 64 px comparison character.

A style choice made before equivalent evidence would risk mass conversion into another dead-end pipeline. Conversely, P0-040 cannot be truthfully marked approved until its required P0-038 production/performance report and P0-039 blind five-participant readability test exist.

## Proposed decision

Adopt **clean-painted** as the P0-040 candidate, with restrained digital-woodcut accents. Retain Godot 4.7 GL Compatibility and the orthogonal three-quarter projection from ADR 0002. Freeze the provisional values in `docs/ART_BIBLE.md` for the remaining gate work.

Do not convert active districts or approve production art against this proposal until P0-040 is accepted by a human approver.

## Evidence

- All targets use one scene, one `SmithyCourtyardDefinition`, a 1600 x 900 viewport, camera center `(800, 448)`, zoom `1.0`, 32 px terrain cells, identical collision rectangles, identical prop anchors, and shared Y-sort.
- The automated verifier confirms seven terrain IDs, eight building footprints, five prop kinds, 64 px character height, `(0, 18)` character pivot, distinct captures, and darker night grades.
- Independent rubric review found all profiles viable for landmarks and depth. Clean-painted best protects the intended value hierarchy because it uses the least continuous surface hatching while retaining timber, plaster, roof, stone, and forge material cues.
- Pixel is readable but reintroduces the production assumptions frozen by P0-026 and does not support the intended cutout rig direction as cleanly.
- Digital woodcut has distinctive historical-print character, but full-surface hatching creates the highest texture density and risks competing with characters and prompts in dense streets.

## Alternatives

### Pixel

Keep as a comparison target only. It has crisp terrain segmentation and compact color count, but selecting it would encourage frame-based sprite multiplication and conflict with the planned reusable cutout rig.

### Digital woodcut

Use as a controlled accent language, not the base treatment. It communicates period printmaking strongly, but the current full-scene target spends too much edge contrast on background terrain.

### Hybrid without a primary style

Rejected. An unconstrained hybrid gives asset authors no enforceable palette, outline, shadow, or value hierarchy and cannot serve as a conversion gate.

## Consequences

- `docs/ART_BIBLE.md` is usable as a provisional input for P0-037 through P0-039.
- P0-039 should blind labels and test actual gameplay-scale captures rather than naming styles.
- If P0-038 or P0-039 contradicts the proposal, update this ADR and regenerate captures before approval.
- Active districts remain unchanged and frozen.
