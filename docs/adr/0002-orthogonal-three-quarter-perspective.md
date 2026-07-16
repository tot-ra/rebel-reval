# ADR 0002: Select orthogonal three-quarter perspective pending comparison spike

**Reference:** TODO P0-004

## Status
Accepted (pending comparison spike confirmation)

Amended by [ADR 0007](0007-ai-generated-isometric-presentation.md) (2026-07-16): the orthogonal gameplay plane (rules 1 and 3) is reaffirmed, but presentation becomes true 2:1 dimetric isometric rendered from AI-generated assets, and the four-direction cap (rule 2) is lifted for prerendered characters.

## Context
The project's current prototype and design documents rely on diamond-isometric TileSets and eight-direction frame-animation assumptions. While this provides a classic RPG look, it introduces significant complexity in asset production (requiring eight directions of animation for characters), Y-sorting, and collision handling on a skewed grid. To reduce the asset burden and simplify the technical implementation of movement and collisions, we are proposing a shift to a fixed-camera 2D three-quarter top-down perspective on an orthogonal gameplay plane. This must be validated through a comparison spike (tasks P0-033 and P0-035) to ensure it meets our visual and gameplay requirements before fully committing and discarding the isometric prototypes.

## Decision
We select the **orthogonal three-quarter perspective** as our current development target. This perspective is defined by the following rules:

1. **Projection:** The art may look isometric (three-quarter top-down view to show verticality and depth), but the underlying world grid and rendering projection remain completely orthogonal. Spaces are composed as small reusable rooms and streets. Foreground roofs and walls will fade only where readability requires it.
2. **Movement directions:** Characters use four movement directions (North, South, East, West). East/west animations may be mirrored when equipment asymmetry does not make that visibly wrong, effectively reducing the animation workload.
3. **Collision plane:** Collisions, navigation, and positioning are resolved on a flat, orthogonal 2D plane. We will not use a skewed diamond grid for physics or pathfinding.
4. **Decision gate:** The final confirmation of this decision is deferred to the completion of the comparison spike (P0-033 and P0-035). The gate will evaluate an orthogonal/four-direction comparison room against an equivalent diamond-isometric/eight-direction room. If the orthogonal approach fails on documented reliability, readability, performance, or art-editability criteria, this decision will be overturned and we will revert to or reconsider the isometric approach.

## Alternatives
- **True diamond-isometric with 8 directions (Current prototype):** Rejected as the primary target for now due to the heavy asset multiplication (8 animation directions) and the technical friction of managing collisions and Y-sorting on a skewed grid.
- **Strict top-down (e.g., classic Zelda):** Rejected. While it simplifies movement and collisions even further, it loses the architectural depth and character silhouette readability required for our visual style and dense city environment.

## Consequences
- Existing diamond-isometric maps and animations are now considered legacy prototypes.
- The art pipeline and visual style decisions (P0-040) will target the orthogonal 4-direction approach.
- Technical implementation of movement, collision, and pathfinding will be simplified to work on a standard orthogonal X/Y grid.
- We accept the risk of building the comparison room spike to validate this decision, knowing that if it fails the gate, the spike effort will be discarded.
