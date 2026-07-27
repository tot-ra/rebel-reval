# Scene Outline: The Price of a Name

## Context

**Type:** Act 1 cycle quest (design contract for **P4-006** implementation)  
**Timeline:** Mid spring 1343, during harbor round-ups before St. George's Night  
**Canon status:** active outline, reconciled with P4-031 relationship memory and north-quarter landmark bindings  
**Quest id:** `quest.price_of_a_name`

## Premise

Captain Henning seizes a rebel dispatch that lists **Mart** as a harbor contact at the St. Olaf guild workshops. He commissions Kalev to forge detention-cart shackles and a brass name-plate before the next coastal-gate prisoner transfer. Kaja asks Kalev to plant **false evidence** redirecting the name to a dead Novgorod clerk. Mart begs Kalev to testify honestly at the guild courtyard hearing. Every forged plate and shackle will decide whether Mart is **cleared**, **redirected** onto a scapegoat, or **concealed** through a hidden release - and whether Kalev carries that weight to the **Hingepuu** reflection the next morning.

## Locations

* **North Quarter merchant court (`loc.north_quarter.merchant_court`):** Pikk Street warehouses, salt stores, ropewalk, and St. Olaf guild workshop row where investigation sites live.
* **Coastal Gate detention apron (`north_quarter::merchant_court`):** Install site for forged shackles and name-plate before prisoner transfer.
* **Kalev's Smithy (`loc.kalev_smithy`):** Commission forge work and detention hardware intake.

## Characters

* **Kalev:** Player; must balance watch duty, apprentice loyalty, and rebel leverage without a universal morality score.
* **Mart:** Apprentice named in the seized dispatch; receives a distinct relationship and detention outcome in every branch.
* **Captain Henning:** Commissioning client; wants reliable identification hardware before the coastal transfer.
* **Kaja:** Rebel courier who pressures Kalev to swap or redirect the name-plate evidence.

## Day Phase: Investigation

Kalev gathers evidence at four authored inspection sites (journal facts, no new investigation framework):

1. **Harbor watch tower:** Seized dispatch lists Mart as a Pikk Street contact (`fact.price_of_a_name.dispatch_name`).
2. **Salt warehouse drop:** Kaja's wax-sealed dispatches hide between salt barrels (`fact.price_of_a_name.salt_warehouse_drop`).
3. **Packhouse lane:** Smuggled spearheads travel in "empty" barrel returns (`fact.price_of_a_name.packhouse_spears`).
4. **Ropewalk lane:** Henning's requisition ties the detention cart route to watch boats (`fact.price_of_a_name.ropewalk_route`).

Landmark discovery beats from `docs/data/landmark_integrations.json` reinforce the same north-quarter sites without adding a second journal system.

## Detention Phase: Evidence Intake

Detention record reuses the watch checkpoint and cart-lock patterns from the vertical slice (no new detention framework).

| Step | System reuse | Effect |
| :--- | :--- | :--- |
| Round-up briefing | `char.henning` dialogue at coastal gate | Starts `commission.price_of_a_name` and optional deadline |
| Seized dispatch handoff | `add_item` on `item.evidence.seized_dispatch` | Player inventory holds the watch copy naming Mart |
| Guild hearing rumor | `char.mart` dialogue at St. Olaf courtyard | Surfaces relationship memory hooks before forge commit |

## Forge Phase: Commission

Commission record: `commission.price_of_a_name` (reuses `ForgeCommissionRunner`, `ForgeFeedbackSequence`, and `CommissionDeadlineModel`).

| Option | Label | Mart name outcome |
| :--- | :--- | :--- |
| `honest_work` | Forge true name-plates and testify at the guild hearing | **Cleared** - Mart's name is struck from the detention roll |
| `subtle_defect` | Forge a false name-plate implicating a dead Novgorod clerk | **Redirected** - false evidence sends the watch after a scapegoat |
| `secret_feature` | Concealed shackle release and swapped name-plate | **Concealed** - Mart stays off the roll while rebels keep the harbor drop |

Each option writes a forged record, faction ledger event, Mart outcome flag, relationship deltas, and north-quarter location state consumed by `mechanism.price_of_a_name_detention`.

## Day Phase: Coastal Transfer Install

Day encounter template reuses the coastal-gate detention encounter pattern with merchant-court anchors:

* **Non-combat route:** Complete shackle install under Henning's supervision when Kalev carries honest paperwork or a planted false-evidence chit (redirect path).
* **Confrontation route:** Interrupted install when district pressure is `crackdown`, or when Kaja's swapped plate is discovered mid-transfer (conceal path).

Mechanism responses (`mechanism.price_of_a_name_detention`) map forged modifications to cart behavior during the transfer beat and set aftermath flags.

## Aftermath States

| State | Forging option | Visible consequence for Mart, Kaja, Henning, and Kalev |
| :--- | :--- | :--- |
| Name cleared | `honest_work` | Mart works openly at the guild workshops; Henning gains a real rebel lead; Kaja loses the salt drop; Kalev earns `rel.mart_trust` +1 and a Duty reflection mark |
| Name redirected | `subtle_defect` | A dead clerk's name rides the cart; Mart stays nervous but free; Kaja is emboldened; Henning may discover the falsification later; Kalev earns `rel.kaja_trust` +1 and a Fury reflection mark |
| Name concealed | `secret_feature` | Mart knows the shackle release; Kaja's network keeps the harbor drop; Henning grows suspicious if the swap is found; Kalev records `memory.kaja.name_plate_swapped` and a Mercy reflection mark |

`loc.north_quarter.merchant_court` location state (`detention_fair`, `detention_redirected`, `detention_concealed`) drives `EnvironmentalConsequenceController` prop visibility on the north-quarter prototype.

## Hingepuu Reflection Hook

The morning after the transfer install, `ReflectionController` reads the Mart outcome flag and surfaces one consequence mark without grading morality:

* **Duty** when `flag.mart.name_cleared` is set.
* **Fury** when `flag.mart.name_redirected` is set.
* **Mercy** when `flag.mart.name_concealed` is set.

Plain-text recap lines reference the forged plate choice and the named characters affected. No new reflection framework is introduced.

## System Reuse Checklist

| System | Reuse |
| :--- | :--- |
| Relationships | `rel.mart_trust`, `rel.henning_trust`, `rel.kaja_trust`, and `memory.*` hooks per branch |
| Detention | Watch cart-lock and coastal transfer encounter contract from the vertical slice |
| False evidence | `item.evidence.seized_dispatch`, planted clerk name-plate, and `flag.price_of_a_name_falsification_risk` |
| Hingepuu | `ReflectionController` consequence marks keyed to Mart outcome flags |
| Commission | `commission.price_of_a_name` with three standard forging options and optional deadline |
| Mechanism | `mechanism.price_of_a_name_detention` behavior responses keyed to forged record |
| Consequence | `EnvironmentalConsequenceController` overlays plus faction ledger events |

No new major framework is introduced; **P4-006** wires runtime controllers against this contract.

See also: [Branch Map and State Table](the-price-of-a-name-branch-map.md) for node transitions, stable flags, and reachability checks.
