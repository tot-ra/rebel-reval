# Saboteur

> Where other rebels shout, he lets the smoke and the caltrops do the talking, and then he is gone over a roof.

| Field | Value |
|---|---|
| ID | `bst.saboteur` |
| Layer | `physical` |
| Tier | `act1` |
| Confidence | `invented` |
| Habitat | Lower Town, harbour |
| Faction ties | black_cloaks |
| Archive reference images | image-55, image-56 |

## At a glance
- Opens a fight with a smoke pot and a scatter of iron caltrops.
- Prefers to cut a rope, a brace or a gate chain over cutting a man.
- Black cloak is a coat of work, not a uniform.
- Odd detail: carries a smith's file in his sleeve.

## Folklore origin
Historical basis: urban resistance in a Hanseatic town would use fire, cut cordage and blocked gates; `invented` on `attested` conditions (the 1343 St George's Night rising is attested; a Reval Black Cloak cell is the game's own). Faction context: [Black Cloaks](../../CITIZENS/factions/black_cloaks.md).

## Appearance
- **Body:** 1.70-1.80 m, wiry; moves low and in bursts, climbs well.
- **Materials and colours:** Dark homespun coat and hood, soot-blackened hands, leather gloves, belt of clay smoke pots and small iron caltrops; palette of charcoal black, rust, a stripe of dyed red on the sleeve as cell marker.
- **What a model must get right:** Hood and black coat; clay pot in hand; soot on face. Not a ninja: coat is patched and sized for a man of the street.
- **Concept-art prompt:** Full-body concept of a wiry 1343 Reval rebel saboteur in a patched black hooded coat, soot-darkened hands and gloves, a belt of small clay pots and iron caltrops, crouched ready stance, medieval Baltic craftsman clothing, no armour, rust and charcoal palette, plain neutral grey background, even lighting, painted realistic style.
- **Model notes:** MPFB human macros (ADR 0022), male or female, lean, age 22-35; shared humanoid rig; coat and hood from existing citizen cloth parts.

## Motivation
To make a particular warehouse, gate or watch post unusable before the rising without killing anyone he can avoid. Fears an informer in his own cell. Contradiction: he hates the Hanseatic grain levy but burns grain he has helped to carry. Released by a convincing argument that the target feeds his own street.

## Manifestation
Triggers where a commission item has been stolen or a delivery is to be wrecked: harbour stores, Müürivahe sheds, a Lower Town gate chain. Attacks to escape, not to win.

## Combat profile
base `EnemyArchetype` `enemy.bandit` (`scripts/combat/enemy_archetype.gd`) variant: fast (detect 150, telegraph 0.40 s), light slash damage 7 plus area effects. Moves: smoke pot (blocks sight 2 s), caltrops (slow 30 percent on a circle), file stab, rope cut that drops a barrel. Flees at 60 percent health by roof or alley. Surrenders almost never; a captured saboteur is leverage for [Black Cloaks](../../CITIZENS/factions/black_cloaks.md) quests. Loot: smoke pots, file, a cell cipher scrap.

{GUILT}self-defence 0 / 0 / 1; defending another 0 / 0 / 0; striking him fleeing 1 / 1 / 2; killing 3 / 3 / 4 (a Cloak dead is remembered by the faction). The civic school weighs most.

## Voice
- "Smoke is cheaper than steel, and kinder."
- "Not you, smith's boy. Move aside."
- (fleeing) "Tell no one you saw my face."

## Relationships and factions
[Black Cloaks](../../CITIZENS/factions/black_cloaks.md): active cell member. Hunted by the watch and the Hanseatic guards; sometimes shielded by Lower Town residents who owe them a favour.

## Game hooks
Named individuals:
- **Reinu Smith**, journeyman from a Harju-gate forge, files grievance into iron.
- **Tiit Kalmus**, ex-docker of the harbour, burned a grain shed at Easter.
- **Anna Wulf**, glover's widow, burns what her late husband was fined for.
Act 1 hook: a forge commission is wrecked at night; the apprentice meets the saboteur on the harbour approach. A non-fight resolution (reveal, bargain) is expected.
