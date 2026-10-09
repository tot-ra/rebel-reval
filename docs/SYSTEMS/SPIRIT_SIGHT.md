# Spirit sight, auras and soul lights

Status: planned (epic **R-1483**, [ADR 0041](../adr/0041-spirit-sight-auras-and-soul-lights.md), proposed; needs approval before coding). Nothing on this page is runtime truth yet.

Scope: a spirit-sight layer the hero toggles anywhere on the same map, auras with seven soul lights on every person and animal, reading a soul, soul lights feeding the spirit duel, and duels that keep the building but hide furniture under a focused grade. Out of scope: a universal good/evil score, duels with animals, a separate spirit-world copy of the map, new art assets (P0-040). The duel rules themselves live in [`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md).

Canon: the soul lights (*hingetuled*), auras and spirit sight are **`invented`**, folklore-inspired like the Hingepuu ([`CANON.md`](../CANON.md)). The word "chakra" is an anachronism and appears only in code ids, never in player-facing text.

## Three layers on one map

| Layer | Entered by | World | Hero can |
|---|---|---|---|
| Physical | default | normal grade, all props | everything |
| Spirit sight | `player_spirit_sight` toggle | same map, cold desaturated grade, props stay, auras on | walk, look, read, challenge |
| Spirit duel | Challenge from spirit sight, or a scripted duel | same place, indigo duel grade, furniture and clutter hidden, only the two fighters glow | fight ([ADR 0038](../adr/0038-realtime-3d-spirit-arena-and-topic-spells.md)) |

Nothing is loaded or unloaded between layers. A duel starts only from spirit sight and ends back in spirit sight.

## Spirit sight toggle (planned, SS-1, **R-1484**)

- Toggle `player_spirit_sight` (proposed `V` / gamepad left stick press). Free, no timer. A ripple spreads from the hero (about 0.6 s; 0.2 s cross-fade with reduced motion).
- One grade on the active `WorldEnvironment`: saturation about 0.25, cold blue-violet tint, ambient and sun about 40 % down, soft vignette. Restored exactly on exit.
- Walk only; no sprint, physical attack or object use. Interact on a duel-ready person offers Challenge; on anything else it leaves sight and interacts.
- `GameState.spirit_sight` is transient and never saved. `GameState.in_spirit_world` is also true in sight; casting stays limited to duels.
- Unavailable during dialogue, cutscenes, modal overlays, swimming and diving; opening one turns sight off first. Observation mode (SD-06) uses the sight grade.
- NPCs who watch the hero stare reuse the self-talk oddness reaction (SD-09).

## Aura data (planned, SS-2, **R-1485**)

Seven lights, levels 0..5 each, plus clarity 0..1. Six lights are the duel elements, the seventh is sight:

| Light | Code id | Anchor | Element | Colour |
|---|---|---|---|---|
| 1 | `chakra.root` | pelvis | fear | red |
| 2 | `chakra.sacral` | lower spine | coin | orange |
| 3 | `chakra.solar` | mid spine | duty | yellow |
| 4 | `chakra.heart` | chest | love | green |
| 5 | `chakra.throat` | neck | shame | blue |
| 6 | `chakra.brow` | head, front | sight | indigo |
| 7 | `chakra.crown` | above the head | faith | violet |

- An optional `aura` block on a character record (`levels`, `clarity`, `closed_mask`) wins; otherwise the profile is derived deterministically from the character id, faction, profession and temperament tags.
- Hero clarity comes from the highest guilt tier (SD-03). Animals use a species table (root and heart, brow for dogs and horses, always clear).
- **Meaning, not morality:** bright lights = a strong soul, a closed light (level 0) = a weak point, low clarity = a troubled soul. The aura never says whether someone is good.

## Aura look (planned, SS-3, **R-1486**)

- Each light is a glow on its bone anchor of the shared rig: 0 a dark crackling knot, 1 ember, 2 glow, 3 bright, 4 radiant, 5 blazing with a corona. Lights pulse at a slow breathing rate.
- The flow is a set of field lines shaped like a magnetic dipole: up the spine through the lights from root to crown, spilling over the head, arcing around the body and back into the root, like water running in a loop. Colour blends the lights each line passes; speed and shimmer follow the levels; low clarity adds curl noise and smoke streaks. A faint fresnel shell hugs the body.
- Budget: full auras on the 12 nearest beings within the sight radius, a single soft glow up to 40 m, nothing beyond. Ribbons are a fixed mesh deformed in the vertex shader from seven anchor uniforms (GL Compatibility, no compute).

## Reading a soul (planned, SS-4, **R-1487**)

Looking at a being for about 0.5 s opens a panel: the seven lights with glyph, element and level pips, the strongest and closed lights, clarity in words (calm, uneasy, torn). The hero's brow light sets the depth: 3 adds temperament tags (SD-15), 4 masked closed lights, 5 a hint of the duel topic.

## Soul lights in a duel (planned, SS-5, **R-1488**)

- The opponent's pressure pool scales with the sum of its levels; its blows of an element scale +10 % per level above 2 (-10 % below).
- The hero's words into a closed light land x1.5, into a level 1 light x1.25, stacked with topic, temperament and traits; the combined product is clamped to 0.5..2.0 (today only the temperament product is). The hero's own levels scale his words the same way.
- A landed word dims the target light; falling pressure lowers clarity; a break shatters the aura. A duel without a profile keeps today's numbers.
- The duel element colours are recoloured to the soul-light table so bolts and lights match.

## Duel layer (planned, SS-6, **R-1489**)

The building stays: walls, floor, pillars, stairs and building shells keep their place and collision. Furniture, props, loose items, decor and clutter are hidden through one named list of node groups, as are people outside the duel. The duel grade is nearly monochrome deep indigo with only arena key and fill lights; only the two fighters glow. Everything is restored on close. This replaces the ADR 0038 interior stripping to the floor.

## Entering a duel (planned, SS-7, **R-1490**)

Challenge (interact) on a duel-ready person in spirit sight opens the in-place duel. Scripted duels (the almshouse porter, future open-world duels, SW-3) switch spirit sight on first, then open the arena. After the duel the hero stays in spirit sight.

## Hero growth (planned, SS-8, **R-1491**)

The hero starts with root 2, heart 2, brow 3, the rest 1. Absolution and NATURAL aspects spent at the Hingepuu (SW-4) raise one light by one, capped per act. Brow sets the sight radius (12 m + 4 m per level above 2) and the reading depth. Saved as an optional `soul_lights` section; old saves load the starting levels.

## Save state and IDs

- Stable ids: `chakra.root`, `chakra.sacral`, `chakra.solar`, `chakra.heart`, `chakra.throat`, `chakra.brow`, `chakra.crown`; input action `player_spirit_sight`.
- Saved: hero light levels only (SS-8). Spirit sight, auras and duel visibility are transient.

## Verification

Each task names its filter: `test_spirit_sight`, `test_spirit_aura_profile`, `test_spirit_aura_view`, `test_spirit_reading`, `test_spirit_duel_aura`, `test_spirit_arena_3d`, `test_spirit_sight_duel_entry`, `test_soul_lights_state`, plus capture plates for the grade, auras and the duel layer.

## Limits

Planned only. Open balance questions: light-level multipliers, the 12-aura budget in dense crowds, and how many NPCs get an authored `aura` block versus a derived one.
