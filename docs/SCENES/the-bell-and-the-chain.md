# Scene Outline: The Bell and the Chain

## Context

**Type:** Act 1 cycle quest (design contract for **P4-002** implementation)  
**Timeline:** Mid spring 1343, before the April alarm drills  
**Canon status:** active outline, reconciled with README campaign outline and P0-113 Viru Gate landmark bindings  
**Quest id:** `quest.bell_and_chain`

## Premise

Captain Henning orders Kalev to refit the Viru Gate portcullis chain and bell striker before the next weekly alarm test. Rebels have already mapped the gate's squeal and patrol gaps; every honest link, hidden flaw, or secret release Kalev forges will surface again at St. George's Night when the city chooses to **Open**, **Seal**, or **Break** the gate (**P4-008**).

## Locations

* **Viru Gate checkpoint (`lower_town_slice::checkpoint_east`):** Patrol desk, portcullis groove, and installation access for the forged chain assembly.
* **Gate portcullis groove (`viru_gate_arch` landmark):** Wear inspection site where rebels note rusted chain squeal.
* **Kalev's Smithy (`loc.kalev_smithy`):** Commission forge work and mechanism response authoring.
* **Wall lime kiln margin (optional patrol bark site):** Prior fitting work Kalev supplied for the winch drum.

## Characters

* **Kalev:** Player; must balance watch trust, rebel leverage, and forge reputation.
* **Captain Henning:** Commissioning client; wants a reliable alarm before the April readiness drill.
* **Mart:** Apprentice who can learn the hidden release if Kalev builds one.
* **Kaja:** Rebel courier who pressures Kalev for intelligence on gate weakness.
* **Watch sergeant (patrol host):** Surfaces district-pressure and patrol-speed consequences after the night install.

## Day Phase: Investigation

Kalev gathers evidence at four authored inspection sites (journal facts, no new investigation framework):

1. **Portcullis groove:** Chain links are pitted; the alarm test squeals audibly (`fact.bell_and_chain.portcullis_wear`).
2. **Patrol rotation log:** Henning doubles east-wall patrols after curfew (`fact.bell_and_chain.patrol_rotation`).
3. **Bell striker winch:** Drum fittings Kalev supplied show stress cracks (`fact.bell_and_chain.striker_stress`).
4. **Rebel chalk marks:** Kaja's scouts mapped the gate rotation from the Margaret wall circuit (`fact.bell_and_chain.rebel_gate_map`).

Landmark discovery beats from `docs/data/landmark_integrations.json` reinforce the same sites without adding a second journal system.

## Forge Phase: Commission

Commission record: `commission.bell_and_chain` (reuses `ForgeCommissionRunner`, `ForgeFeedbackSequence`, and `CommissionDeadlineModel`).

| Option | Label | Act-climax bias |
| :--- | :--- | :--- |
| `honest_work` | Forge true tempered links and a reliable striker | **Seal** - chain holds under ram pressure |
| `subtle_defect` | Hide a stress-fractured middle link | **Break** - link fails when rebels strain the portcullis |
| `secret_feature` | Conceal a quick-release pin Mart can trigger from inside | **Open** - gate can be dropped without cutting the chain |

Each option writes a forged record, faction ledger event, and act-climax bias flag consumed by `mechanism.bell_and_chain_gate`.

## Night Phase: Gate Install Consequence

Night encounter template reuses the watch checkpoint encounter pattern (`encounter.watch_checkpoint` contract) with Viru Gate anchors:

* **Non-combat route:** Complete install under sergeant supervision when Kalev carries honest paperwork or a tampered inspection chit (subtle-defect path).
* **Combat / evasion route:** Interrupted install when patrol density is high, district pressure is `crackdown`, or Kalev is caught scouting the groove after curfew.

Mechanism responses (`mechanism.bell_and_chain_gate`) map forged modifications to gate behavior during the install beat and set aftermath flags.

## Aftermath States

| State | Forging option | Visible consequence |
| :--- | :--- | :--- |
| Honest hold | `honest_work` | Henning praises the silent test; patrol barks note a solid portcullis; `flag.act_climax_viru_seal` = true |
| Hidden fracture | `subtle_defect` | Watch trusts the repair until a stress test groans; Black Cloaks gain gate intelligence; `flag.act_climax_viru_break` = true |
| Secret release | `secret_feature` | Mart knows the pin; Kaja's network gains a quiet opening plan; Henning grows suspicious if the feature is discovered; `flag.act_climax_viru_open` = true |

District-pressure overlays (`EnvironmentalConsequenceController`) and patrol bark pools react to the aftermath tier without new consequence frameworks.

## System Reuse Checklist

| System | Reuse |
| :--- | :--- |
| Commission | `commission.bell_and_chain` with three standard forging options and optional deadline |
| Mechanism | `mechanism.bell_and_chain_gate` behavior responses keyed to forged record |
| Gate | `lower_town_slice::checkpoint_east`, `viru_gate_arch`, portcullis groove landmark beat |
| Patrol | `MapPatrolBarkPresenter`, `DistrictPressureModel` speed/density tiers |
| Consequence | `EnvironmentalConsequenceController` overlays plus faction ledger events |

No new major framework is introduced; **P4-002** wires runtime controllers against this contract.

See also: [Branch Map and State Table](the-bell-and-the-chain-branch-map.md) for node transitions, stable flags, and reachability checks.
