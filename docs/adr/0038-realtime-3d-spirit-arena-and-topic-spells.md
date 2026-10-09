# ADR 0038: Real-time 3D spirit arena and topic-bound word spells

- **Status:** Proposed (maintainer request, 2026-10-08). Needs human approval before coding.
- **Amends:** [ADR 0033](0033-teen-protagonist-and-spirit-dialogue-combat.md) item 3 ("real-time telegraphed opponent lines with a reply wheel", arena as a 2D overlay). Everything else in 0033 (guilt, traits, temperaments, language, observation) stays.
- **Amended by:** [ADR 0041](0041-spirit-sight-auras-and-soul-lights.md) (proposed): item 2 changes, the building stays and only furniture and clutter hide; duels open only from spirit sight; the outdoor silhouette fade and the spirit-mist edge VFX are dropped.
- **Does not supersede:** ADR 0003 (offline authored dialogue, no runtime LLM), ADR 0028 (building interiors), the asset freeze (P0-040).

## Context

Today a spirit duel is a 2D overlay (`SpiritArenaHost`) over a frozen world. The hero stands still, the opponent speaks telegraphed lines, and the player picks reply cards. It reads as a menu, not a fight, and the replies do not clearly depend on what the argument is about.

The maintainer wants: (1) a 3D scene in roughly the place where the hero stands, (2) a bounded radius, (3) interiors stripped to floor and opponent, (4) free movement during the fight, (5) spells that are emotional verbal strikes, so the fight looks like a word brawl, (6) the strikes should hit by meaning: they must tie to the subject of the conflict.

## Decision (proposed)

1. **Arena in place.** A duel opens a `SpiritArena3D` centred on the hero's position (or the midpoint of hero and opponent). Walkable area is a disc, default radius 9 m, enforced by a clamp on the hero and opponent (soft ring wall plus a spirit-mist edge VFX), not by editing the map. The real map is hidden, not unloaded: a visibility mask on the active map root and on the NPCs outside the duel, restored on close.
2. **Interiors are stripped.** Inside a building the arena hides walls, roof, furniture and props; only the floor plane (extended to the disc radius with a spirit-floor material) and the two fighters remain. Outdoors the ground stays, buildings and props within the disc fade to silhouettes. The set of hidden node groups is a single named list, never per-map code.
3. **Real-time movement.** The hero keeps normal movement, guard, and dodge inside the disc. The opponent has simple authored behaviour (circle, advance, retreat) driven by the line it speaks; no navmesh needed in an empty disc.
4. **Word spells.** Spells `1..5` are cast at any time (cost willpower, short cooldown). A spell is one emotional strike: an `element` (fear, shame, duty, love, faith, coin) plus a short spoken line and a projectile or wave in the matching colour. The opponent's lines are attacks with the same shape, and the hero dodges, guards, or parries them in space.
5. **Topic binding.** Each duel declares a `topic`: the subject of the conflict, with `stakes` it already has and a list of `lines` per element (`topic.lines[element][]`), each line carrying `relevance` tags (`respect`, `secret`, `obligation`, `balance` plus topic-specific IDs, for example `rusted_key`). A cast picks the topic line for its element, so the words spoken are about the actual dispute. Damage multiplier: on-topic x1.5, element-only x1.0, off-topic x0.6. The opponent's `temperament` (SD-15) multiplies as before. No runtime text generation: all lines are authored (ADR 0003).
6. **Dialogue stays the spine.** `SpiritDuel` remains the deterministic rules model (vitals, counters, guilt, traits, resolution nodes). The 3D arena is a new presenter on top of it, the way `SpiritArenaHost` is today. The 2D host stays for observation mode and as a fallback.
7. **Prologue first.** The almshouse duel is migrated first (porter, topic: the stolen key and the boy's place); the staged hall (R-1334) is reused as the floor and lighting source.

## Equivalent scope accounting

Offset: the 2D reply-card hotbar as the primary duel control (SD-18 `SpiritSpellCard` row) is demoted to a compact cast bar in the HUD; the telegraph arc UI is replaced by in-world telegraph decals. No new tower, naval or physical-enemy work. No new art assets: procedural meshes, existing rigs, existing VFX parts.

## Alternatives considered

- **Keep the overlay and add a 3D backdrop.** Cheap, but the hero cannot move, so the main ask is unmet.
- **Load a dedicated arena scene.** Loses the "same place" feeling and the location lighting; needs transition handling. Rejected.
- **Generate topic lines at runtime.** Forbidden by ADR 0003.
- **Pure real-time with no dialogue tags.** Throws away the move/element/stakes data already authored and tested.

## Consequences

- New feature page extension in `docs/SYSTEMS/SPIRIT_DIALOGUE.md` and a new `docs/SYSTEMS/SPIRIT_ARENA_3D.md` as tasks land.
- Dialogue schema gains optional `duel.topic` (topic id, `lines` per element with `relevance`); validator checks that every element line exists and relevance tags are declared in `duel.stakes` or topic tags.
- Tests: arena radius clamp, visibility mask restore, interior stripping, topic multiplier, determinism (same inputs, same outcome).
- Risk: real-time balance. Mitigation: `SpiritDuel` numbers stay data, accessibility option to pause on cast and keep reply pressure off.
