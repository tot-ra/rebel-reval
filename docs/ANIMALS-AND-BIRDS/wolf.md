# Wolf

> A real predator of the Harju woods, hungry in a hard spring, with no reason to be cruel and no way to be reasoned with.

| Field | Value |
|---|---|
| ID | `bst.wolf` |
| Layer | `physical` |
| Tier | `act1` |
| Confidence | `attested` |
| Habitat | forests, winter roads |
| Faction ties | none |
| Archive reference images | - |

## At a glance
- Pack of two to four; a lone wolf will not engage a standing group.
- Circles, then lunges for the legs.
- A fed or frightened wolf retreats at once.
- Odd detail: avoids iron and fire more than people.

## Folklore origin
Ecological basis: grey wolves were common in medieval Livonia and Estonia (`attested`); there is no folklore claim in this card (the werewolf case is `bst.libahunt`). See [folklore notes](../lore/estonian_folklore.md) for the human-wolf cases, which are not this card.

## Appearance
- **Body:** 0.7-0.8 m at the shoulder, 35-45 kg, long legs; trots, circles, bursts to a sprint.
- **Materials and colours:** Grey-brown winter coat, pale muzzle and belly, dark saddle; amber eyes; palette of grey, tawny, off-white.
- **What a model must get right:** Long legs, deep chest, narrow head, bushy tail carried low; not a dog and not a monster.
- **Concept-art prompt:** Full-body concept of an adult grey wolf in winter coat, long-legged and lean, grey-brown with pale muzzle and belly, amber eyes, low head circling stance, snow-flecked forest floor suggested but background plain neutral grey, even lighting, realistic painted style.
- **Model notes:** Quadruped rig; no wolf GLB exists in the repo yet (the runtime uses the procedural `fauna.wolf` mesh, see [3D models](./README.md#3d-model-status)); the mammal shared rig and clip set in [`assets/storybook/mammal_sources.json`](../../assets/storybook/mammal_sources.json) is the intended target; scale 1.0; separate pack AI.

## Motivation
Food. Fears fire and iron. No contradiction: it is an animal. Released by fire, a thrown loaf, or a clear retreat path.

## Manifestation
Forest roads at dusk, winter and spring hunger, a flock or a camp. Attacks when it is hungry and the prey is alone or wounded.

## Combat profile
base `EnemyArchetype` `enemy.bandit` (`scripts/combat/enemy_archetype.gd`); slash replaced by bite (`attack_damage_type` `pierce`). 6 damage, reach 40, telegraph 0.40 s, fast circling. Moves: circle, leg lunge, group flank. Retreats at 50 percent health; no surrender; loot: pelt, meat. Fire or an iron tool drives off the pack.

Guilt per school (christian / folk blood-debt / civic), deterministic: wolf kills carry 0 / 0 / 0 in all schools; a tamed or kept wolf is a different case and not covered.

## Voice
Barks: snarl, short bark, the pack answering from the dark.

## Relationships and factions
No faction. [Metsik cult](../CITIZENS/factions/cult_metsik.md) revere the wolf; the spirit-caller can send real wolves.

## Game hooks
Real wolves are the first physical fight outside the city, a no-guilt teacher of combat (Act 1). The spectral wolves of `bst.spirit_caller` and the cursed `bst.libahunt` are separate entries.
