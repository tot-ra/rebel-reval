# Brute

> He is simply the strongest man in the room and has learned that the room is afraid; the legacy 'supernatural strength' is gone.

| Field | Value |
|---|---|
| ID | `bst.brute` |
| Layer | `physical` |
| Tier | `act1` |
| Confidence | `invented` |
| Habitat | taverns, dock gangs |
| Faction ties | none |
| Archive reference images | image-45, image-54 |

## At a glance
- Slow, heavy, shoves rather than cuts.
- Hired by whoever pays: a tavern keeper, a dock gang, a guild debt collector.
- Doorway fights: his weakness is a narrow gap and a rope.
- Odd detail: he cannot read and keeps tallies on a string of knots.

## Folklore origin
Historical basis: dock and tavern hired muscle exists in every medieval port; `invented` on `attested` conditions (labour around the Reval harbour, ale houses). No supernatural element: the legacy README claim is dropped, see [roster](../README.md).

## Appearance
- **Body:** 1.85-1.95 m, 100-120 kg, thick neck, wide hands; deliberate slow stride, sudden lunge.
- **Materials and colours:** Leather jerkin over wool tunic, bare forearms, coarse apron or sacking over one shoulder; a short staff or tavern bench-leg; palette of wine red, brown leather, ash grey.
- **What a model must get right:** Mass: shoulders wider than the doorway frame, hands the size of the apprentice's head. Not a monster: a big labourer.
- **Concept-art prompt:** Full-body concept of a very large 1343 Reval dock enforcer, thick neck and wide shoulders, scarred knuckles, leather jerkin over wool tunic, bare forearms, short iron-banded staff, slow heavy stance, medieval Baltic port clothing, brown and wine red palette, plain neutral grey background, even lighting, painted realistic style.
- **Model notes:** MPFB human macros (ADR 0022), male, extreme height and mass macros; shared humanoid rig with slower animation set; scale 1.12 over default.

## Motivation
Money and a place at the table. Fears being laughed at and being old. Contradiction: gentle with dogs and children, brutal at work. Released by being outbid or by a debt forgiven; shame works better than steel.

## Manifestation
Tavern floors near the harbour at night, dock yards on pay day, or at the door of a debtor. Attacks because a job says so, not out of malice.

## Combat profile
base `EnemyArchetype` `enemy.bandit` (`scripts/combat/enemy_archetype.gd`) heavy variant: detect 100, telegraph 0.80 s, damage 14 blunt, reach 56, stamina cost 9. Moves: shove (knockback, no damage), overhead club, grab. Does not flee; surrenders if hamstrung or if the paymaster is shown. Loot: purse of coin, a tally string.

Guilt per school (christian / folk blood-debt / civic), deterministic: self-defence 0 / 0 / 0; defending another 0 / 0 / 0; striking after he yields 2 / 2 / 1; killing 3 / 3 / 1.

## Voice
- "Pay me or move."
- "I don't hurt people. People get hurt."
- (beaten) "Enough. Take the purse."

## Relationships and factions
No faction. Hired by Hanseatic debtors, tavern keepers or the Vitalienbruder fringe. Unwelcome with the watch.

## Game hooks
Named individuals:
- **Ülo the Ox**, ex-oarsman, hired for a tavern in Vene street.
- **Gerd Sluter**, ex-cooper, enforcer of a grain merchant's debts.
- **Marten Pikk**, 'Tall Marten', ex-wall labourer, fights for a dock gang.
Act 1 hook: debt-collection quest; the player can fight, pay, or break his hold with a rope and a gap.
