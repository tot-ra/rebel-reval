# Black Cloak fighter

> A smith's son or a fired porter who fights with the city's own stones, and who might be an ally if the apprentice does not strike first.

| Field | Value |
|---|---|
| ID | `bst.black_cloak_fighter` |
| Layer | `physical` |
| Tier | `act2` |
| Confidence | `invented` |
| Habitat | Lower Town, sewers, rooftops |
| Faction ties | black_cloaks |
| Archive reference images | image-48, image-52 |

## At a glance
- Uses the street: shutters, barrels, drain covers, a roof edge.
- Guilt-sensitive: he is a potential ally, so killing him is costly.
- Fights to cover a retreat, not to win.
- Odd detail: wears a thread of red under the cloak collar as cell sign.

## Folklore origin
Historical basis: the St George's Night rising of 1343 is `attested`; an urban Black Cloak cell is the game's own, `invented` on that base. Faction context: [Black Cloaks](../../CITIZENS/factions/black_cloaks.md).

## Appearance
- **Body:** 1.70-1.85 m, athletic, trained by street work rather than drill; quick, uses terrain.
- **Materials and colours:** Black wool hooded cloak over a work tunic, leather gloves, a short hammer or hand axe taken from a forge, a sling; palette of black, soot grey, one thread of red.
- **What a model must get right:** The cloak (patched, working, not a costume), the red thread, tools as weapons (hammer, tongs, chain).
- **Concept-art prompt:** Full-body concept of a 1343 Reval urban rebel fighter, patched black hooded cloak over a smith's leather apron, soot-streaked forearms, short forge hammer in hand, red thread at the collar, ready low stance, medieval Baltic craftsman clothing, no plate armour, charcoal and rust palette, plain neutral grey background, even lighting, painted realistic style.
- **Model notes:** MPFB human macros (ADR 0022), male or female, athletic, age 20-40; shared humanoid rig; cloak from citizen cloth parts, hammer prop from the forge set.

## Motivation
Relief from the toll booth, the levy and the flogging. Fears an informer and an Order sergeant. Contradiction: loves the city he is ready to burn. Released by the apprentice naming a cell contact, a shared friend, or a forge token.

## Manifestation
Lower Town back lanes, the sewer entry near the wall, rooftops over Müürivahe. Attacks when the apprentice runs into a cell operation or is taken for a watch informer.

## Combat profile
base `EnemyArchetype` `enemy.bandit` (`scripts/combat/enemy_archetype.gd`) fast variant: detect 140, telegraph 0.45 s, damage 9, mixed slash and blunt. Moves: hammer swing, shield-bash with a shutter, sling shot at range, alley retreat with a barrel kick. Flees at 50 percent health to cover a comrade; surrenders only if the apprentice names a cell contact. Loot: cell cipher scrap, nails, a forge file.

Guilt per school (christian / folk blood-debt / civic), deterministic: self-defence 0 / 0 / 1; defending another 0 / 0 / 1; striking him after surrender 2 / 2 / 3; killing 3 / 3 / 5. The civic school (faction standing with [Black Cloaks](../../CITIZENS/factions/black_cloaks.md)) weighs most.

## Voice
- "Walls have ears, boy. So do I."
- "We are not murderers. Neither of us wants to be."
- (down) "Tell my mother I held the line."

## Relationships and factions
[Black Cloaks](../../CITIZENS/factions/black_cloaks.md): core member. Enemy of the Order and the Hanseatic watch; the cell protects its own in Lower Town.

## Game hooks
Named individuals:
- **Mihkel Sepp**, smith's journeyman who lost a forge to a levy.
- **Eero Tamm**, fired porter who now carries messages and a hammer.
- **Katrin Lõhmus**, widow of a guild baker, fights to keep her shop's grain off the list.
Act 2 hook: a mission where the apprentice may choose to fight, flee or ally; fighting costs standing.
