# Vanapagan cultist

> A man who sold something small to the Old Devil and now carries it as a second, darker shadow in the spirit layer.

| Field | Value |
|---|---|
| ID | `bst.vanapagan_cultist` |
| Layer | `hybrid` |
| Tier | `act2` |
| Confidence | `invented` |
| Habitat | monastery cellars, cult rites |
| Faction ties | cult_metsik, church |
| Archive reference images | image-46, image-49, image-50 |

## At a glance
- Hurls rocks and heavy objects; the rock-thrower from the legacy README is folded in.
- Human body, spirit mark: darker and larger in spirit sight.
- Fought physically, but the mark can be read and lifted.
- Odd detail: refuses salt, takes it for weakness.

## Folklore origin
Folklore basis: the Old Devil Vanapagan and the soul-bargain stories (`estonian_folklore.md` 4a). Human side `invented`. Factions: [Metsik cult](../../CITIZENS/factions/cult_metsik.md) and [Church](../../CITIZENS/factions/church.md) (as hunter and victim).

## Appearance
- **Body:** 1.70-1.90 m, heavy-armed, deliberate; throws from a distance, then closes.
- **Materials and colours:** Torn monk-like robe or coarse wool tunic, a bundle of stones at the belt, a rope sling, charcoal marks on the forearms; palette of soot black, ash white, dried-blood brown.
- **What a model must get right:** Soot marks on hands and brow; a sling or stone bundle; in the spirit layer a second, larger shadow behind him.
- **Concept-art prompt:** Full-body concept of a 1343 Estonian cultist in a torn dark wool robe, charcoal marks on forearms and brow, rope sling and a bundle of stones at the belt, sunken eyes, heavy-shouldered stance, medieval Baltic clothing, no armour, soot black and ash white palette, plain neutral grey background, even lighting, painted realistic style.
- **Model notes:** MPFB human macros (ADR 0022), male, heavy build, age 30-55; shared humanoid rig; spirit-layer shadow as a second mesh (see BST-5).

## Motivation
Wants what the bargain promised (a harvest, a child, a debt gone) and fears the day it is collected. Contradiction: believes he is protected and is being used. Released by lifting the mark in the spirit layer or by naming what was sold.

## Manifestation
Monastery cellars, cult rites under the hill, hinterland barns; appears at night, in a group or alone. Attacks anyone who disturbs a rite.

## Combat profile
base `EnemyArchetype` `enemy.bandit` (`scripts/combat/enemy_archetype.gd`) heavy variant: detect 120, engage 100, damage 12 blunt thrown (range 160) and 14 melee. Moves: rock throw, sling stones, charge, grab. Flees only if the mark is lifted; surrenders if the mark is named and refused. Loot: stones, charcoal, a bone token, sometimes a coin of the bargain.

Guilt per school (christian / folk blood-debt / civic), deterministic: physical blow, self-defence 0 / 1 / 1; striking after the mark is lifted 3 / 3 / 2; killing 4 / 5 / 3. Spirit-layer reading removes the mark without a blow and carries no guilt.

## Voice
- "I gave a little. They took more."
- "Do not bring salt into this house."
- (freed) "I... I can see the sky again."

## Relationships and factions
[Metsik cult](../../CITIZENS/factions/cult_metsik.md): member or bargained victim. [Church](../../CITIZENS/factions/church.md): hunters of the rite and, sometimes, the cause.

## Game hooks
Named individuals:
- **Jüri Vahtra**, farmhand who traded his name for a harvest.
- **Brother Anselm**, a lay brother who fell into the bargain.
- **Tiina Kuld**, a miller's widow who gave up a child's cough.
Act 2 hook: a monastery cellar mission; the spirit-layer duel is an alternative to the physical fight.
