# P0-036 independent UX review

Recorded: 2026-07-16  
Reviewer role: independent rubric pass, performed after implementation and automated verification  
Evidence set: six unlabeled-in-rubric 1600 x 900 captures linked from `visual_targets_p0_036.md`

## Independence and limitation

This review used a separate UX/readability rubric and the rendered captures, not renderer implementation details, as its evaluation surface. It was conducted as a distinct review pass after the invariant verifier was green. No sub-agent or external human reviewer was used because the task session explicitly prohibited sub-agents.

This is therefore independent from the coding pass, but **not** a substitute for P0-039's required blind test with at least five human participants. Scores are heuristic evidence for the P0-040 candidate only.

## Rubric

Each category is scored 1-5 at native gameplay framing:

- Terrain: seven materials remain separable without labels.
- Reval architecture: gable, plaster/timber, roof, wall, door/window cues read as a coherent medieval Lower Town.
- Props: anvil, hay, cart, well, and barrels are recognizable by silhouette/material.
- Character: player remains the primary mobile accent and separates from ground.
- Depth/Y-sort: ground contact, foreground/background overlap, and collision-bearing masses are legible.
- Value hierarchy: characters/interactables outrank routes/buildings, which outrank surface texture.
- Night continuity: phase is clearly darker without losing routes, landmarks, or terrain identity.

## Results

| Target | Terrain | Architecture | Props | Character | Depth/Y-sort | Value hierarchy | Night | Total / 35 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Pixel | 5 | 4 | 4 | 5 | 4 | 4 | 4 | 30 |
| Digital woodcut | 4 | 5 | 4 | 4 | 4 | 3 | 4 | 28 |
| Clean painted | 5 | 5 | 5 | 5 | 5 | 5 | 4 | 34 |

## Findings

### Pixel

- Strongest hard segmentation of terrain and character silhouette.
- Character and props remain readable at 1.0 zoom.
- Repeated square clusters flatten material transitions and make the environment feel closer to the frozen legacy pixel pipeline.
- Production risk: encourages frame-specific sprite assumptions that P0-037 is intended to avoid.

### Digital woodcut

- Strongest historical-print identity and architectural character.
- Hatching provides surface direction, especially on roofs and terrain.
- Full-scene hatch density competes with prop and character contours in the courtyard. This violates the desired background-to-foreground contrast budget before NPC crowds or prompts are added.
- Best retained as a sparse accent language for roofs, cloth, portraits, printed notices, and selected narrative surfaces.

### Clean painted

- Clearest overall hierarchy: broad terrain masses first, route and buildings second, character/props above them.
- Timber framing, gabled roofs, limestone walls, anvil, cart, well, barrels, and hay remain identifiable without continuous hatch.
- Thin outlines are sufficient because material planes provide most separation.
- Night grade is the darkest relative transform of the three in measured luminance while still retaining all required landmarks.
- Candidate weakness: later production art must preserve deliberate texture restraint; uncontrolled brush noise would erase this advantage.

## Recommendation

Advance **clean painted with restrained digital-woodcut accents** as the provisional P0-040 direction. Keep pixel and full woodcut captures as negative/contrast references.

Before approval:

1. P0-037 must exercise idle, four-direction walk, forge, combat, hit, and fall at the frozen 64 px scale.
2. P0-038 must compare performance and production reuse.
3. P0-039 must blind style labels and recruit at least five participants to identify terrain, props, character silhouette, interaction priority, depth, and motion.
4. A human P0-040 approver must record the final decision.

No active-district conversion is authorized by this review.
