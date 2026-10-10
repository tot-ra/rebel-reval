# Street thug

> A man with a club and a hungry household, who knows that a purse is a week of rye and a witness is a hanging.

| Field | Value |
|---|---|
| ID | `bst.street_thug` |
| Layer | `physical` |
| Tier | `slice` |
| Confidence | `invented` |
| Habitat | Lower Town alleys |
| Faction ties | none |
| Archive reference images | bandits:thug.png, bandits:thug2.png, image-53 |

## At a glance
- First fight a player can lose in a Lower Town lane after dark.
- Throws a fistful of sand before closing; the sand is the telegraph, not a trick.
- Runs when the apprentice shouts for the watch.
- Odd detail: he asks for the purse politely first.

## Folklore origin
Historical basis: a growing landless underclass in Reval after the 1340s grain failures, `invented` on `attested` conditions (day labourers, discharged carters, serfs fled from Harju manors). Coin-by-weight economy: a purse is worth silver by weight, so a thief steals scrap silver as readily as money. He has no folklore basis; the setting is the citizen ledger ([CITIZENS](../../CITIZENS/README.md)).

## Appearance
- **Body:** 1.65-1.80 m, lean from Lent, shoulders hunched against cold; moves in short quick steps and stays near walls.
- **Materials and colours:** Undyed grey-brown homespun tunic, hose tied to the belt, wooden shoes or rag-wrapped feet, a scarf pulled over the nose; club of ash, belt knife; palette of grey, mud brown, dirty linen.
- **What a model must get right:** Hood or scarf hiding the lower face; a cudgel held low; worn-through hose at the knee. He must read as poor, not as a villain.
- **Concept-art prompt:** Full-body concept of a lean 1343 Reval street thief in coarse grey-brown homespun tunic, patched hose, rag-wrapped feet, scarf over the lower face, short ash club in one hand, other hand cupped to throw sand, hunched cautious stance, medieval Baltic port clothing, no armour, muted palette, plain neutral grey background, even lighting.
- **Model notes:** MPFB human macros (ADR 0022), male, lean, age 25-40; shared humanoid rig; existing `bandit` variant scene is the placeholder.

## Motivation
Eat this week and keep his name off the watch roll. He fears the gallows and being recognised by his own street. The contradiction: he prays at St Olaf on Sundays and robs on Mondays. A shout, a dropped purse, or a witness releases him; he does not want a killing.

## Manifestation
Lower Town lanes between Vene and Müürivahe after the curfew bell, when the apprentice carries a commission or a purse; also at the harbour sheds at dawn. He attacks because the lane is empty and the prey is young.

## Combat profile
base `EnemyArchetype` `enemy.bandit` (`scripts/combat/enemy_archetype.gd`), tuned slower (longer telegraph 0.6 s) with a blunt club (`attack_damage_type` `blunt`, 7 damage, reach 46). Moves: sand throw (blinds for a second, dodged by turning away), club swing, shove. Flees at 40 percent health or when someone shouts for the watch; surrenders if disarmed and cornered. Loot: 2-6 örtug in scrap silver, a hunk of rye bread, a bad knife.

Guilt per school (christian / folk blood-debt / civic), deterministic: self-defence 0 / 0 / 0; defending another 0 / 0 / 0; striking a fleeing or surrendered thug 1 / 1 / 0; killing 3 / 3 / 1. He has no faction to remember it.

## Voice
- "Your purse, lad. Gently, now, gently."
- "I have children, boy. Think of that before you shout."
- (running) "Not worth it, not worth it..."

## Relationships and factions
No faction. Shelters in the underclass of the harbour sheds. The watch hunts him; the Black Cloaks pity and sometimes recruit him ([black_cloaks](../../CITIZENS/factions/black_cloaks.md)).

## Game hooks
Named individuals:
- **Hannes the Limper**, ex-carter of St Olaf parish, lost the cart to debt at Candlemas; his club is a cart-stave.
- **Ints Nine-fingers**, Latvian-born porter, lost a finger to a crane rope; steals for his sister's rent.
- **Mats Kruus**, boy of 17, new to it, apologises while robbing.
First meet: the lane to the forge in the first night walk (slice). Pairs with the guilt tutorial: the player learns that striking a surrendered man costs more than defending.
