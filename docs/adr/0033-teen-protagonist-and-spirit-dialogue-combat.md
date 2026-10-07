# ADR 0033: A teenage clairvoyant protagonist and spirit-world dialogue combat

- **Status:** Accepted (maintainer-directed, 2026-10-07). Implementation is gated by tasks; nothing here is runtime truth until a task verifies it.
- **Amends:** [ADR 0008](0008-three-act-campaign-and-faction-scope.md) and [ADR 0017](0017-legacy-design-reintroduction.md) where they fix Kalev as an adult smith protagonist and make hammer combat plus physical night missions the combat spine. Kalev's elevated NPC role is canon-level; see [`docs/CHARACTERS/kalev.md`](../CHARACTERS/kalev.md).
- **Does not supersede:** ADR 0003 (offline authored dialogue, no runtime LLM), ADR 0019/0027/0028 (seamless world), ADR 0022 (realistic humans), the MVP-first delivery order, or the ban on a universal morality score.

## Context

The game is a Reval smith RPG with an action combat layer and a dual-school magic layer ([`MAGIC.md`](../SYSTEMS/MAGIC.md), [`PSYCHE.md`](../SYSTEMS/PSYCHE.md)). Two tensions remain unresolved:

1. Magic and monsters (Estonian folklore) do not fit a realistic 1343 city and everyday craft.
2. The progression fantasy (schools, skill growth, a soul-tree) competes with the commission-and-consequence loop instead of reinforcing it.

The maintainer proposes a unifying frame: the protagonist is a 15-year-old orphan who perceives a spirit world. Magic and most combat happen there. In the physical world the city stays realistic.

## Decision

1. **Protagonist.** The player character is a 15-year-old orphan, apprenticed into the forge. Adult **Kalev becomes the master smith (mentor NPC)**, keeping his model, portrait, and forge. The forge, commission ledger, and forged-record loop stay; the protagonist influences commissions as an apprentice (quiet modification, substitution, concealment). Mart (16) stays the missing apprentice whose absence opens the story; the protagonist is taken in to fill his place.
2. **Two layers.**
   - **Physical world:** realistic, no magic. Movement, observation, stealth, trade, craft, ordinary dialogue.
   - **Spirit world** (an extension of Hingepuu): spells and most combat. The hero sees it as clairvoyance. Other people read his behaviour (talking to himself, staring) as oddness. The game never confirms a clinical diagnosis; it is a gift and a burden.
3. **Dialogue is combat.** Authored conversations carry per-line **move tags** (kind, element, stake, spirit image) so one record has two presentations: plain text in the world, a spirit duel in the arena. The hero **observes** other people's conflicts as duels (learning from them, optionally intervening) and fights his own. Real-time telegraphed opponent lines with a reply wheel for fast beats; paced turn choices for slow beats. The arena reuses the existing combat feel (guard, dodge, stamina) where possible.
4. **Hybrid physical combat with guilt.** A physical blow is available but opens a guilt (*süü*) debuff in the spirit layer. Guilt is **per school**, never a single score: Christian sin and absolution, folk blood-debt and cleansing, and civic or faction reputation. Weight depends on circumstance (self-defence, defending another, provocation, unarmed victim, killing) and is deterministic. Unresolved guilt returns as dream phantoms. Some encounters are physical-only (ambush, mob, animals) with low guilt.
5. **Language and fear.** Languages the hero does not understand render as imagery without meaning; comprehension is a skill that reveals stakes. Estonian folklore creatures appear only to him, as phantoms of fear around dark places and threatening people.
6. **Traits.** Hero traits are double-edged (a buff and a debuff tied to how they were gained). NPC temperament tags (procrastinator, impulsive, creative, and so on) set which duel moves hit them hard. Talking to oneself is an action with a buff, and witnesses react by faction and rule, deterministically.
7. **Prologue.** The game opens in an almshouse tied to the Holy Spirit parish (Holy Spirit priest 1316 is `attested`; an orphan house there is `plausible composite`). It teaches observation of a duel, a first own duel, the physical-versus-spiritual choice with guilt, and Kalev taking the apprentice.

## Equivalent scope accounting (per AGENTS.md scope-change rule)

**Removed or deferred as the offset:**

- standalone physical **night-mission templates** (sabotage, theft, escort, defense) as a separate mode, including the unbuilt P5 night-mission packages; slice night-consequence state stays;
- **tower capture and boss interiors** (`scripts/tower/`): unmounted code is to be deleted by a cleanup task;
- **magic in the physical world** (number-key casting outside the arena, `map_view_magic_vfx` world effects, "hammer as world conduit"); delivery nodes are reused in the spirit arena;
- **broad physical enemy rosters** (`watchman`, `sergeant`, `knight_order`, `crossbowman`, `bandit`): cut to the few physical-only encounters;
- **adult-smith combat animation** as the player move set ([`COMBAT_ANIMATION.md`](../SYSTEMS/COMBAT_ANIMATION.md)): replaced by teen moves; the shared 76-clip rig is kept.

**Not cut, still open:** the eight launch factions. Each needs authored duels, so the faction count may be reduced by a later decision; this ADR does not do it.

## Alternatives considered

- **Keep adult Kalev, add magic as ambiguous folklore.** Rejected: leaves the realism-versus-magic tension and gives no coherent reason for a progression system.
- **A mentally disabled adult protagonist.** Rejected: higher risk of caricature, and the weakness-in-the-physical-world argument is stronger for a teenager.
- **A fully separate turn-based spirit mode.** Rejected: duplicates content. One tagged dialogue record serves both layers.
- **A single sin or karma meter.** Rejected: forbidden by README and AGENTS.md; guilt is per school and faction.

## Consequences

- README, AGENTS.md, and `kalev.md` carry a pointer to this ADR. Playable code stays as-is until tasks land; today's prototype still controls Kalev.
- New feature page [`SPIRIT_DIALOGUE.md`](../SYSTEMS/SPIRIT_DIALOGUE.md) (`Status: planned`).
- The dialogue schema ([`schemas/dialogue.schema.json`](../../schemas/dialogue.schema.json)) and `tools/validate_content.py` gain move-tag fields and checks through a task, with a one-scene prototype first (prologue quarrel) to test authoring cost before wider markup.
- New teen protagonist model on the realistic-human pipeline (ADR 0022); Kalev's existing model is reused for the master smith.
- Named canon items (almshouse, spirit-world creatures, guilt rites) need confidence labels in `docs/CANON.md` when the tasks land.
- Content budget: only key conflicts are move-tagged (tens of scenes, not every conversation).
