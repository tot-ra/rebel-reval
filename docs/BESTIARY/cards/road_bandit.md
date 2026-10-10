# Road bandit

> Not born a thief: a levied archer, a fled serf, a ruined carter, working the forest road in threes and wishing he did not need to.

| Field | Value |
|---|---|
| ID | `bst.road_bandit` |
| Layer | `physical` |
| Tier | `act1` |
| Confidence | `invented` |
| Habitat | hinterland roads |
| Faction ties | none (some allied to harju_kings or cult_metsik, stated on the individual) |
| Archive reference images | bandits:thug3.png, bandits:thug4.png, image-57, image-58, image-51 |

## At a glance
- Ambushes in a group of three with a hidden archer; the first bolt is a warning shot.
- Flees or surrenders when outnumbered or when the leader falls.
- Faces are people with reasons: hunger, debt, the Order levy, a manor flight.
- Odd detail: every band has one man who will not hit a boy.

## Folklore origin
Historical basis: roads in Harju and Viru in 1343 had landless men, deserters and fugitives from manor bonds; `invented` on `attested` conditions (the Danish and Order levy tensions, grain failure). Faction links: [Harju Kings](../../CITIZENS/factions/harju_kings.md), [Livonian Order](../../CITIZENS/factions/livonian_order.md).

## Appearance
- **Body:** 1.65-1.85 m, wiry, tired; moves in a crouch from cover, runs well.
- **Materials and colours:** Worn wool cap or hood, coarse tunic and cloak, hose tied up, bast or leather shoes, a hunting bow or spear, sometimes a stolen Order surcoat cut down; palette of mud brown, moss green, faded blue.
- **What a model must get right:** Mismatched clothing (stolen and patched); a bow or spear; a camouflage cloak of forest greens. Never a uniform.
- **Concept-art prompt:** Full-body concept of a 1343 Estonian forest road bandit, worn wool hood and cloak in moss green and mud brown, coarse tunic, bast shoes, short hunting bow and a knife at the belt, mismatched stolen belt buckle, wary crouched stance, medieval Baltic clothing, no plate armour, plain neutral grey background, even lighting, painted realistic style.
- **Model notes:** MPFB human macros (ADR 0022), male or female, lean, age 20-45; shared humanoid rig; `bandit.tscn` is the existing placeholder variant.

## Motivation
A meal and a roof before the winter, and a way back to a farm that may be gone. Fears the Order's hangman and his own children seeing him. Contradiction: he robs travellers and gives half to a village. Released by a witness he cannot kill, a better offer, or a leader down.

## Manifestation
Forest road toward the western coast, Viru road, Harju hinterland between farmsteads. Attacks travellers likely to carry silver, tools or grain, including the apprentice on an errand.

## Combat profile
base `EnemyArchetype` `enemy.bandit` (`scripts/combat/enemy_archetype.gd`), unchanged for the sword bandit (damage 10, slash), a spear variant (reach 60, damage 9) and a hidden archer. Moves: ambush from cover, slash, spear thrust, arrow (ranged, 8 damage). Flees at 25 percent health (`retreat_health_ratio`), surrenders if the leader falls or the player outnumbers. Loot: cut silver, coarse bread, a stolen tool, sometimes a letter.

Guilt per school (christian / folk blood-debt / civic), deterministic: self-defence 0 / 0 / 0; defending a traveller 0 / 0 / 0; striking a surrendered man 2 / 2 / 1; killing a surrendered or fleeing bandit 3 / 3 / 1; killing in open ambush 1 / 1 / 0.

## Voice
- "Bread and silver, traveller. No blood needed."
- "The Order took my plough ox. Take my place on the gallows, if you like."
- (down) "My children... who will tell them?"

## Relationships and factions
Not a faction. Some bands feed [Harju Kings](../../CITIZENS/factions/harju_kings.md) intelligence or hide in [Metsik](../../CITIZENS/factions/cult_metsik.md) groves. Hunted by the Order's riders and the watch.

## Game hooks
Named individuals:
- **Jaan Kask**, ex-serf of a Harju manor, ran after the grain levy; leads a band of three.
- **Karl Brandt**, Low German archer, discharged from an Order levy unpaid.
- **Liisa Raud**, widow of a carter, drives the band's pack pony and hits no boys.
Hooks: forest-road errands in Act 1; a surrender yields a quest thread (the village behind the band).
