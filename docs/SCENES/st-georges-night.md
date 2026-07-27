# Scene Outline: St. George's Night (Act 1 Climax)

## Context

**Type:** Act 1 act-boundary climax (design contract for **P4-008** playable implementation)  
**Timeline:** April 23, 1343 (St. George's Night), **`attested`** uprising date per `docs/CANON.md`  
**Canon status:** active outline, reconciled with ADR 0008 act-boundary model  
**Quest id:** `quest.st_georges_night`

## Premise

Hilltop bonfires signal the Estonian uprising. Kalev reaches Viru Gate as the watch, rebels, and townsfolk collide. Every forged object, ledger debt, and relationship from Act 1 cycles surfaces here. The player does not forge new metal in this beat; they **choose** how the gate resolves among the three act-boundary families **Open**, **Seal**, and **Break**. Each family writes a distinct act-transition record for Act 2 rather than ending the campaign.

## Locations

* **Viru Gate checkpoint (`lower_town_slice::checkpoint_east`):** Portcullis, bell striker, and the forged chain assembly from `quest.bell_and_chain`.
* **Viru Gate foreland (`viru_gate_foreland`):** Bonfire sightline and rebel approach path (optional bark staging).
* **Wall patrol spine:** Henning's rally point and sergeant bark hosts.

## Characters

* **Kalev:** Player; chooses gate family and witnesses the act boundary.
* **Captain Henning:** Commands the seal defense when watch standing is high.
* **Mart / Kaja:** Rebel network voices when open or break bias flags are set.
* **Watch sergeant and patrol hosts:** Surface district-pressure and environmental-consequence overlays.

## Prior Act 1 Feed (stacking, not a new framework)

| Source | Flags / records consumed at climax |
| :--- | :--- |
| `quest.bell_and_chain` | `flag.act_climax_viru_seal`, `flag.act_climax_viru_break`, `flag.act_climax_viru_open` |
| `quest.bread_and_iron` | `flag.family.raide_*`, weighing-house mechanism state |
| `quest.price_of_a_name` | `flag.mart.name_*`, detention mechanism state |
| `quest.root_and_ember` | `flag.ellen.*`, household hearth flags |
| Faction ledger | `faction_standing_at_least` gates on rally dialogue options |
| Environmental consequences | `EnvironmentalConsequenceController` unrest/crackdown overlays |

`mechanism.st_georges_night_gate` resolves forged-record behavior (`hold`, `fail`, `release`) from the stacked bias flags plus the player's explicit climax choice transition.

## Climax Phase: Gate Choice

Night phase `phase.act1_climax` (owned by **P4-008** runtime). Authored encounter at `interact.st_georges_night.gate_choice`:

| Player choice | Act-boundary family | Gate behavior |
| :--- | :--- | :--- |
| Hold the portcullis with Henning | **Seal** | Chain holds; gate stays down unless breached elsewhere |
| Let the fracture fail under ram pressure | **Break** | Hidden link snaps; rebels force the portcullis |
| Trigger the concealed release | **Open** | Pin drops the gate without cutting the chain |

Each choice requires the matching climax-bias flag **or** a high enough faction standing fallback documented in the branch map. No universal morality score ranks the options.

## Act-Transition Record

Terminal quest states write mutually exclusive act-boundary flags:

| Terminal state | Boundary flag | Act 2 opening bias |
| :--- | :--- | :--- |
| `aftermath_seal` | `flag.act_boundary.viru_seal` | Watch-led defense, curfew hardens |
| `aftermath_break` | `flag.act_boundary.viru_break` | Forced entry, rebel surge through Viru |
| `aftermath_open` | `flag.act_boundary.viru_open` | Quiet drop, network escape corridors |

`flag.act_transition.act1_recorded` = true on every terminal path. **P4-009** aggregates character, forge, and district aftermath from this record.

## System Reuse Checklist

| System | Reuse |
| :--- | :--- |
| Mechanism | `mechanism.st_georges_night_gate` behavior responses keyed to prior forged records and climax choice |
| Gate | `lower_town_slice::checkpoint_east`, `viru_gate_arch`, `mechanism.bell_and_chain_gate` install state |
| Patrol | `MapPatrolBarkPresenter`, `DistrictPressureModel`, `EnvironmentalConsequenceController` |
| Consequence | Faction ledger events, relationship memory barks, no new encounter framework |
| Act boundary | `flag.act_boundary.viru_*` plus `flag.act_transition.act1_recorded` for save migration |

No new major framework is introduced; **P4-008** wires runtime controllers against this contract.

See also: [Branch Map and State Table](st-georges-night-branch-map.md) for node transitions, stable flags, and reachability checks.
