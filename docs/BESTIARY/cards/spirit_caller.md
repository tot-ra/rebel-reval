# Spirit-caller

> A shaman who can call what the apprentice sees; the human holds the spirit on a leash, and cutting the leash hurts both.

| Field | Value |
|---|---|
| ID | `bst.spirit_caller` |
| Layer | `hybrid` |
| Tier | `act2` |
| Confidence | `invented` |
| Habitat | hinterland groves |
| Faction ties | cult_metsik |
| Archive reference images | image-47 |

## At a glance
- Ranged curse and a thrown vial; summons shows only in the spirit layer.
- The wolves he sends can be real (physical) or spectral (spirit).
- Keeps a bone-and-feather staff as the anchor.
- Odd detail: sings under his breath, a children's rhyme.

## Folklore origin
Folklore basis: Estonian cunning-folk and ritual specialists (`estonian_folklore.md` 4a; the Slavic *volkhv* is not used). Physical side `invented`. Faction: [Metsik cult](../../CITIZENS/factions/cult_metsik.md). See [folklore notes](../../lore/estonian_folklore.md).

## Appearance
- **Body:** 1.65-1.80 m, spare, moves slowly with a staff, sudden precise gestures.
- **Materials and colours:** Undyed wool robe patched with hide, a bone-and-feather staff, a wolf pelt over the shoulders, ash and ochre on the face; palette of off-white, ash grey, red ochre.
- **What a model must get right:** Staff with a bone cap, wolf pelt, face paint of ash and ochre. Reads as a village healer, not a sorcerer from a book.
- **Concept-art prompt:** Full-body concept of a 1343 Estonian forest ritual healer, spare figure in undyed wool robe patched with hide, wolf pelt on the shoulders, ash and red ochre on the face, tall bone-and-feather staff, calm watchful stance, medieval Baltic folk clothing, no armour, plain neutral grey background, even lighting, painted realistic style.
- **Model notes:** MPFB human macros (ADR 0022), male or female, age 40-65; shared humanoid rig; spirit summon modelled in the spirit layer only (see BST-5).

## Motivation
Defend the grove, heal the sick, hold off the Church and the Order. Fears the cult's overreach and the loss of the old words. Contradiction: calls spirits to protect, but spirits can overcome the caller. Released by honouring the grove and the old words.

## Manifestation
Groves of the Harju hinterland; at a sacred site, or when the apprentice carries iron into the grove. Attacks a stranger who threatens the site.

## Combat profile
base `EnemyArchetype` `enemy.bandit` (`scripts/combat/enemy_archetype.gd`) caster variant: detect 150, engage 120 (ranged), damage 6 plus curse (stamina drain). Moves: thrown vial (area), curse bolt, summon wolf (real wolves are physical `bst.wolf`; spectral ones are spirit-layer adds), staff strike. Flees at 30 percent health into the grove; surrenders if the grove is spared. Loot: ochre, herb bundle, a bone token.

Guilt per school (christian / folk blood-debt / civic), deterministic: physical blow, self-defence 0 / 0 / 1; striking after surrender 2 / 3 / 2; killing 4 / 5 / 3 (folk blood-debt weighs most). Summoned spirits carry no guilt.

## Voice
- "You walk in a house you do not know. Wipe your feet on the old threshold."
- "The wolf is not mine. I only ask it to listen."
- (hurt) "The grove will remember."

## Relationships and factions
[Metsik cult](../../CITIZENS/factions/cult_metsik.md): member or healer. Church and Order hunt them; villagers hide and fear them.

## Game hooks
Named individuals:
- **Ellen Luik**, healer of a Harju village; the model for the Nõid card (see roster).
- **Tõnn the Crow**, old shaman whose staff is a crow-bone staff.
- **Maret Sild**, young herb-woman learning the call.
Act 2 hook: a grove quest where the apprentice can negotiate, fight, or pass through; the human and the spirit are separable.
