# ADR 0041: Spirit sight, auras and the seven soul lights

- **Status:** Accepted (maintainer-approved, 2026-10-09). Implementation is gated by tasks R-1484..R-1491; nothing here is runtime truth until a task verifies it.
- **Amends:** [ADR 0038](0038-realtime-3d-spirit-arena-and-topic-spells.md) item 2 (interiors stripped to the floor) and the duel entry of [ADR 0033](0033-teen-protagonist-and-spirit-dialogue-combat.md) ("the world freezes into an arena"). Everything else in 0033 and 0038 (guilt, traits, temperaments, word spells, topic binding, the disc, real-time movement) stays.
- **Revised (maintainer, 2026-10-09):** the seven soul lights are the seven NATURAL aspects ([`NATURAL.md`](../SYSTEMS/NATURAL.md)) shown on the body, not a second set of points; hero light levels derive from NATURAL ranks. Sections 3, 4, 6 and 7 updated; there are no `chakra.*` ids.
- **Does not supersede:** ADR 0003 (offline authored dialogue), ADR 0019/0027/0028 (seamless world, in-place interiors), the asset freeze (P0-040), the ban on a universal good/evil morality score.

## Context

Today the spirit world exists only inside a duel or an observation: the arena opens, the world is hidden, and it closes again. The hero's clairvoyance, the core of his character, is not something the player can use while walking the city.

The maintainer wants:

1. A **spirit sight** mode the hero switches on and off at will, like the Witcher's senses. Same map, same place, same position; only the lighting and colour change in a simple way.
2. In spirit sight every person and animal shows an **aura**: a coloured picture of their inner state.
3. Each body carries **seven chakras**. How bright each one glows depends on how developed the person is, so the picture shows at a glance how strong or troubled someone is.
4. The aura **flows** like a magnetic field or running water, from one point to another, between the chakras.
5. **Battles happen only in the spirit world.** In a battle furniture and ordinary things vanish, the building itself stays, and the lighting and palette change so the focus is on the fight and the other person.

The maintainer also asked that the aura show "how good or bad" a person is. That conflicts with the standing ban on a universal morality score (AGENTS.md scope, ADR 0033). This ADR resolves it below: the aura shows **strength** and **inner conflict**, never a moral verdict.

## Decision

### 1. Three layers on one map

| Layer | Entered by | World | Hero can |
|---|---|---|---|
| Physical | default | normal grade, all props | everything |
| Spirit sight | `player_spirit_sight` toggle | same map, cold desaturated grade, props stay, auras on | walk (no run), look, read auras, challenge |
| Spirit duel | challenge from spirit sight, or a scripted duel | same place, duel grade, furniture and clutter hidden, only the two fighters' auras | fight (ADR 0038) |

Nothing is loaded or unloaded between layers. The map, streaming, time of day, NPC schedules and the hero's position are untouched. A duel can only start from spirit sight: a scripted duel switches spirit sight on first (one transition), then opens the arena. Closing a duel returns to spirit sight, not to the physical layer, so the player sees the opponent's changed aura before leaving.

### 2. Spirit sight

- **Toggle** `player_spirit_sight` (proposal: keyboard `V`, gamepad left stick press; final binding in the task). Free, no timer, no resource. Turning it on plays a short ripple (about 0.6 s) that spreads from the hero across the screen; turning it off plays it in reverse. Reduced motion makes it a 0.2 s cross-fade.
- **Grade:** one post-process recipe on the active `WorldEnvironment`, tweened, never per map: saturation about 0.25, a cold blue-violet tint, ambient and sun energy down about 40 %, a soft vignette. Buildings, terrain and props stay fully readable. Restored exactly on exit.
- **Limits while on:** walk speed only, no sprint, no physical attack, no object use. Interact (`interact`) on a person who has a duel offers **Challenge**; on anything else it leaves spirit sight first and then interacts normally.
- **Transient:** `GameState.spirit_sight` is never saved; a loaded game starts in the physical layer. `GameState.in_spirit_world` (SD-14) becomes true in spirit sight as well as in a duel, so spells still answer only in the spirit world, but casting stays limited to duels.
- **When it is unavailable:** the toggle does nothing during dialogue, cutscenes (ADR 0034), modal overlays, swimming and diving, and while carried by a scripted move; opening any of these while sight is on turns it off first. Observation mode (SD-06) uses the spirit-sight grade instead of its own dimming.
- **Witnesses:** a boy staring through people is odd. Spirit sight reuses the existing oddness reaction of self-talk (SD-09) for NPCs that watch him for more than a few seconds. No new reaction system.

### 3. Auras and the seven soul lights (= the seven NATURAL aspects)

In the fiction the points are **hingetuled** ("soul lights"): the visible face of the seven hearths of the soul that [`NATURAL.md`](../SYSTEMS/NATURAL.md) already defines and that the Hingepuu shows as its tiers from roots to sky. The aura is the same tree seen from outside, laid along the body from the pelvis to above the head. The Sanskrit word chakra is an anachronism in 1343 Livonia and never appears in player-facing text or code ids. Canon label: **`invented`** / **`folklore`**-inspired, like the Hingepuu.

**One seven, not two.** The light ids are the existing NATURAL aspect ids. Each light also has one duel element it guards, so the aura, the fight and progression share one vocabulary. The seventh light guards sight itself.

| # | Light = aspect (code id) | Hingepuu tier | Body anchor (shared rig) | Guards duel element | Colour |
|---|---|---|---|---|---|
| 1 | `aspect.nature` | root system | pelvis (hips) | fear (survival) | red |
| 2 | `aspect.affection` | base of trunk | lower spine | coin (appetite, possession) | orange |
| 3 | `aspect.tenacity` | main trunk | mid spine | duty (will, obligation) | yellow |
| 4 | `aspect.unity` | large branch | chest | love | green |
| 5 | `aspect.resonance` | high windy branch | neck | shame (the word, silence) | blue |
| 6 | `aspect.awareness` | treetop perch | head, front | sight (insight) | indigo |
| 7 | `aspect.light` | sky above the tree | above the head | faith | violet |

The duel element colours (`ELEMENT_COLORS`, today in `spirit_spell_card.gd`) are recoloured to this table in the implementation task, so a fear bolt is the colour of the nature light. Colour is never the only cue: each light keeps its fixed body position and a glyph in the reading panel (colour-blind safe).

- **Level** per light, integer 0..5: 0 closed (a dark knot that crackles), 1 ember, 2 glow, 3 bright, 4 radiant, 5 blazing with a corona. Brightness, size and flow speed follow the level.
- **Hero levels come from NATURAL ranks**, never stored separately: rank below 5 or a locked aspect (`natural.lock_aspect`) = 0, 5-9 = 1, 10-14 = 2, 15-24 = 3, 25-39 = 4, 40-50 = 5. NPCs carry no NATURAL ranks; their light levels are content (section 7).
- **Clarity** 0..1 for the whole aura: calm, clean flow at 1; choppy flow with dark smoke streaks near 0. It comes from inner conflict: for the hero, the highest guilt tier (SD-03); for an NPC, an authored or derived value.
- **This is how the aura shows "good or bad" without a morality score:** bright and many lights = a strong soul (dangerous to argue with); a closed light = a weak point; murky, turbulent flow = a troubled soul. A cruel man can be bright and clear, a kind widow dim and murky. The picture answers "how strong, where weak, how torn", never "how good". This matches the NATURAL rule that no morality score is derived from the aspect mix.
- **Flow:** the aura is a set of field lines shaped like a magnetic dipole around the body axis: they rise along the spine through the seven lights from nature to light, spill out over the head, arc around the body and return into the root, like water running in a loop (sap rising through the Hingepuu). The colour along each line blends the colours of the lights it passes; the flow speed and the shimmer follow the levels; low clarity adds curl noise and smoke. A faint fresnel shell hugs the body. Each light pulses at a slow breathing rate.
- **Animals:** species profiles with few lights (nature and unity for all, awareness for dogs and horses), always clear. Animals have auras but cannot be challenged in this ADR.

### 4. Reading a soul

Looking at a being in spirit sight (camera centre or mouse hover, about 0.5 s) opens a compact **reading**: the seven lights with level pips, their aspect names and the element each guards, the strongest and the closed lights, and clarity in words ("calm", "uneasy", "torn"). How much is revealed scales with the hero's own awareness light (NATURAL Perception): level 3 adds the temperament tags (SD-15), level 4 the closed lights hidden behind a mask, level 5 a hint of what the person's dispute is about (the duel topic). Reading is the strategic layer: the player learns which words will cut before starting a fight.

### 5. The duel in the spirit world

- **Light levels drive the fight.** The opponent's pressure pool scales with the sum of its levels. Each light scales the damage of the opponent's blows of the element it guards (level 2 = x1.0, +10 % per level above, -10 % per level below). The hero's words of an element hit a closed light (level 0) x1.5 and a level 1 light x1.25; this stacks with the topic, temperament and trait multipliers, and the combined product is clamped to 0.5..2.0 (today only the temperament product is clamped; the task widens the clamp to the whole product). The hero's own levels scale his words and replies the same way. Spells cast through `MagicResolver` keep their existing NATURAL scaling (MAGIC.md section 6) and get no second light multiplier, so an aspect is never counted twice.
- **Hits show on the aura:** a landed word dims the target light briefly; as pressure falls the whole aura loses clarity; breaking the opponent scatters the aura into shards (the existing spirit-form break, SD-19).
- **Arena stripping (amends ADR 0038 item 2):** the building stays. Inside a building the walls, floor, pillars and stairs stay as they are (the normal interior camera cut-away still applies); furniture, props, loose items, decor and clutter are hidden. Outdoors terrain and building shells stay; props, carts, stalls and loose items are hidden. People and animals outside the duel are hidden as before. The hidden set is one named list of node groups (furniture, prop, item, clutter), never per-map code. The disc boundary stays; walls inside the radius bound the fight too.
- **Duel grade:** stronger than spirit sight. The world goes nearly monochrome in deep indigo, every light except the arena key and fill is dimmed, and only the two fighters keep full colour through their auras. Bolts, telegraph zones and the fighters are the only saturated things on screen.

### 6. The hero grows his lights through NATURAL

The hero's lights grow exactly as his NATURAL aspects do: points granted by content (`natural.grant_points`) and spent at the Hingepuu (`natural.spend_point`, already wired in the reflection host) raise a rank, and the light follows its band. There is no separate light currency, cap or save field. The apprentice's NATURAL baseline replaces the flat 5 of the Kalev-era contract: nature 10, unity 10, awareness 15 (the clairvoyant gift), the other four 5, which reads as nature 2, unity 2, awareness 3, the rest 1. The awareness level sets the spirit-sight aura radius (12 m + 4 m per level above 2) and the reading depth (section 4).

### 7. Data and determinism

- An optional `aura` block on a character content record: `levels` keyed by the seven `aspect.*` ids (0..5), optional `clarity`, optional `closed_mask` for lights hidden from shallow reading. The validator checks ids and ranges. NPCs have light levels, not NATURAL ranks.
- Without an authored block the profile is derived deterministically from the character id (a stable hash), the character's faction and profession, and its temperament tags; the same character always has the same aura. No randomness at runtime.
- The hero's levels are read live from `GameState` NATURAL ranks (section 3), so they always match the Hingepuu.
- Animal profiles are a small species table.
- Duel balance numbers (multipliers, pools) and the rank-to-level bands stay data, as today.

### 8. Performance budget

Full auras (lights, field lines, shell) on at most 12 beings inside the sight radius, nearest first; beyond that and up to 40 m a single soft glow per being; nothing past 40 m. Field lines are a fixed ribbon mesh deformed in the vertex shader from the seven anchor positions passed as uniforms each frame, so no per-frame mesh rebuild. GL Compatibility only (no compute, no `Decal`).

## Equivalent scope accounting

Removed to pay for this:

1. The separate spirit-world shift transition planned in SW-5 (R-1352) is replaced by the spirit-sight ripple; SW-5 keeps only Hingepuu environment art and audio.
2. The 2D dark-silhouette fallback of `SpiritFormView` in 3D duels is retired: the opponent's aura carries its state. The spirit image over the head (SD-19) stays.
3. The ADR 0038 outdoor "fade buildings and props to silhouettes" step is dropped: buildings simply stay and props are hidden.
4. No separate hero light progression or save section: lights reuse NATURAL ranks, grants and Hingepuu spending.
5. The per-duel spirit-mist edge VFX of ADR 0038 item 1 is not built; the boundary ring stays as is.

No new tower, naval, party or physical-enemy work. No new art assets: all looks are procedural shaders and meshes (P0-040).

## Alternatives considered

- **Show a single good/evil colour per person.** Directly what was asked, but forbidden by the scope rules and flattens the faction drama. Rejected in favour of strength + clarity.
- **Seven new lights unrelated to the duel elements.** More traditional, but two colour vocabularies for one fight; the reading would not help the player choose words. Rejected.
- **Load a separate spirit-world copy of the map.** Doubles content and breaks "same place". Rejected (as in ADR 0038).
- **Particles for the flow.** Looks fine up close but costs too much for a crowd and drifts off the body when people walk. A bone-driven ribbon shader is cheaper and stays attached.
- **Keep stripping interiors to the floor.** Loses the sense of where the fight is; the maintainer explicitly wants the building to stay.

## Consequences

- New feature page [`docs/SYSTEMS/SPIRIT_SIGHT.md`](../SYSTEMS/SPIRIT_SIGHT.md) (`Status: planned` until tasks land); `SPIRIT_DIALOGUE.md` player-facing design and the 3D arena section point to it.
- Schema: optional `aura` on character records; validator codes for unknown light ids and out-of-range levels.
- Saves: nothing new. Hero lights are NATURAL ranks, already saved; spirit sight itself is never saved.
- `NATURAL.md` gains the apprentice baseline and a soul-light section; its Kalev-era wording moves to the apprentice (ADR 0033).
- Tests: toggle and exact grade restore, no save of the layer, deterministic derived profiles, LOD budget, reading depth by brow level, light-level multipliers in `SpiritDuel`, arena hides furniture and keeps walls and restores both, duel returns to spirit sight.
- Accessibility: spirit-sight grade intensity slider, reduced flashing calms the shimmer and the pulse, reduced motion shortens the ripple; glyphs next to colours.
- Risk: readability of a city full of auras. Mitigation: the radius and the 12-aura budget, nearest first, and the duel grade hiding every non-fighter aura.
