# The Bell and the Chain: Branch Map and State Table

## Context

Implementation-ready node map for `quest.bell_and_chain`. Reuses commission, mechanism, gate, patrol, and consequence systems documented in [`the-bell-and-the-chain.md`](the-bell-and-the-chain.md). Machine-readable traversal branches live in [`content/packages/bell_and_chain/branch_map.json`](../../content/packages/bell_and_chain/branch_map.json).

## Branch Map

### NODE 1: Alarm Order

* **Description:** Henning delivers the Viru Gate chain-and-bell refit commission after a failed weekly alarm test.
* **Entry Conditions:** Act 1 morning phase active; `quest.bell_and_chain` latent or newly started.
* **Effects:**
  * Sets `quest.bell_and_chain` state to `investigating`.
  * Surfaces journal objective to inspect the gate, patrol log, striker winch, and rebel chalk marks.
  * Starts `commission.bell_and_chain` deadline tracking when authored.
* **Exit:** Player accepts the commission briefing.
* **Reachable Outcome:** Transitions to **NODE 2**.

### NODE 2: Gate Investigation

* **Description:** Kalev inspects four evidence sites around Viru Gate and the east checkpoint.
* **Entry Conditions:** Exiting **NODE 1**; quest state `investigating`.
* **Effects:**
  * Records journal facts when each site is inspected:
    * `fact.bell_and_chain.portcullis_wear`
    * `fact.bell_and_chain.patrol_rotation`
    * `fact.bell_and_chain.striker_stress`
    * `fact.bell_and_chain.rebel_gate_map`
  * Optional landmark discovery beats fire at `checkpoint_east` without duplicating fact storage.
* **Exit:** All four facts are known.
* **Reachable Outcome:** `complete_investigation` transition to **NODE 3**.

### NODE 3: Forge Choice

* **Description:** Kalev forges the portcullis chain assembly and bell striker at the smithy.
* **Entry Conditions:** Quest state `investigation_ready`; player at `loc.kalev_smithy`.
* **Effects:**
  * Presents three standard forging options on `commission.bell_and_chain`.
  * Runs the five-beat forge feedback sequence before committing the forged record.
* **Exit:** Player selects one forging option.
* **Reachable Outcomes:**
  * `honest_work` -> **NODE 4A**
  * `subtle_defect` -> **NODE 4B**
  * `secret_feature` -> **NODE 4C**

### NODE 4A: Honest Chain

* **Description:** Kalev delivers true tempered links and a reliable striker.
* **Entry Conditions:** Player selected `honest_work` in **NODE 3**.
* **Effects:**
  * Sets `flag.gate_chain_honest_work` = true.
  * Sets `flag.act_climax_viru_seal` = true.
  * Records `ledger.bell_and_chain.honest_hold` for `faction.livonian_order` (+1).
  * Sets `rel.henning_trust` +1.
* **Exit:** Automatic after forge commit.
* **Reachable Outcome:** Transitions to **NODE 5**.

### NODE 4B: Hidden Fracture

* **Description:** Kalev conceals a stress-fractured middle link that will fail under rebel strain.
* **Entry Conditions:** Player selected `subtle_defect` in **NODE 3**; requires `fact.bell_and_chain.portcullis_wear`.
* **Effects:**
  * Sets `flag.gate_chain_subtle_defect` = true.
  * Sets `flag.act_climax_viru_break` = true.
  * Records `ledger.bell_and_chain.hidden_fracture` for `faction.black_cloaks` (+1).
  * Sets `flag.gate_chain_falsification_risk` = true.
* **Exit:** Automatic after forge commit.
* **Reachable Outcome:** Transitions to **NODE 5**.

### NODE 4C: Secret Release

* **Description:** Kalev forges a concealed quick-release pin Mart can trigger from inside the gate passage.
* **Entry Conditions:** Player selected `secret_feature` in **NODE 3**; requires `fact.bell_and_chain.rebel_gate_map`.
* **Effects:**
  * Sets `flag.gate_chain_secret_feature` = true.
  * Sets `flag.act_climax_viru_open` = true.
  * Records `ledger.bell_and_chain.secret_release` for `faction.harju_kings` (+1).
  * Sets `memory.mart.gate_release_taught` = true.
* **Exit:** Automatic after forge commit.
* **Reachable Outcome:** Transitions to **NODE 5**.

### NODE 5: Night Install

* **Description:** Kalev installs and tests the assembly at Viru Gate under curfew patrol pressure.
* **Entry Conditions:** One of **NODE 4A/B/C** completed; night phase active.
* **Effects:**
  * `mechanism.bell_and_chain_gate` resolves forged-record behavior (hold, fail-under-strain, release-ready).
  * Patrol density follows `DistrictPressureModel` tier at `district.lower_town`.
  * Non-combat, evasion, and combat routes reuse `encounter.watch_checkpoint` encounter contract.
* **Exit:** Install encounter resolves.
* **Reachable Outcomes:**
  * Honest install -> **NODE 6A**
  * Defect install undiscovered -> **NODE 6B**
  * Release install (discovered or quiet) -> **NODE 6C**

### NODE 6A: Watch Confidence

* **Description:** The alarm test passes cleanly; Henning logs the repair as exemplary.
* **Entry Conditions:** `flag.gate_chain_honest_work` = true; install encounter succeeded.
* **Effects:**
  * Sets `quest.bell_and_chain` terminal state `aftermath_honest`.
  * Sets `location.viru_gate` patrol bark pool to `watch_confident`.
  * Clears crackdown overlay on gate approach unless district pressure already `crackdown`.
* **Exit:** Bed rest or phase advance.
* **Reachable Outcome:** Cycle complete; act-climax seal bias recorded for **P4-008**.

### NODE 6B: Whispered Weakness

* **Description:** The repair passes inspection but rebels note the hidden flaw.
* **Entry Conditions:** `flag.gate_chain_subtle_defect` = true; install encounter succeeded.
* **Effects:**
  * Sets `quest.bell_and_chain` terminal state `aftermath_defect`.
  * Sets `flag.rebel_gate_intelligence` = true.
  * Patrol barks reference a "quiet groan" during the stress test.
* **Exit:** Bed rest or phase advance.
* **Reachable Outcome:** Cycle complete; act-climax break bias recorded for **P4-008**.

### NODE 6C: Hidden Latch

* **Description:** Mart or Kaja's network knows the release; the watch may or may not suspect tampering.
* **Entry Conditions:** `flag.gate_chain_secret_feature` = true; install encounter succeeded.
* **Effects:**
  * Sets `quest.bell_and_chain` terminal state `aftermath_release`.
  * Sets `flag.mart_gate_release` = true when install was quiet; sets `flag.gate_chain_discovered` = true when install was contested.
  * Adjusts `rel.henning_trust` -1 when discovery flag is set.
* **Exit:** Bed rest or phase advance.
* **Reachable Outcome:** Cycle complete; act-climax open bias recorded for **P4-008**.

---

## State Table

| Variable Name | Type | Initial Value | Modified In | Description / Effect |
| :--- | :--- | :--- | :--- | :--- |
| `quest.bell_and_chain` | Quest state | `investigating` | NODE 1-6 | `investigating`, `investigation_ready`, `aftermath_honest`, `aftermath_defect`, `aftermath_release` |
| `fact.bell_and_chain.portcullis_wear` | Boolean | `false` | NODE 2 | Portcullis groove pitting and audible squeal documented. |
| `fact.bell_and_chain.patrol_rotation` | Boolean | `false` | NODE 2 | East-wall patrol doubling after curfew logged. |
| `fact.bell_and_chain.striker_stress` | Boolean | `false` | NODE 2 | Bell striker drum stress cracks noted. |
| `fact.bell_and_chain.rebel_gate_map` | Boolean | `false` | NODE 2 | Rebel gate rotation chalk marks found. |
| `flag.gate_chain_honest_work` | Boolean | `false` | NODE 4A | Honest tempered links committed at forge. |
| `flag.gate_chain_subtle_defect` | Boolean | `false` | NODE 4B | Hidden stress fracture committed at forge. |
| `flag.gate_chain_secret_feature` | Boolean | `false` | NODE 4C | Concealed release pin committed at forge. |
| `flag.act_climax_viru_seal` | Boolean | `false` | NODE 4A, 6A | Act-boundary **Seal** readiness for P4-008. |
| `flag.act_climax_viru_break` | Boolean | `false` | NODE 4B, 6B | Act-boundary **Break** readiness for P4-008. |
| `flag.act_climax_viru_open` | Boolean | `false` | NODE 4C, 6C | Act-boundary **Open** readiness for P4-008. |
| `flag.gate_chain_falsification_risk` | Boolean | `false` | NODE 4B | Hidden fracture may be discovered before St. George's Night. |
| `flag.rebel_gate_intelligence` | Boolean | `false` | NODE 6B | Rebels know the fracture location. |
| `flag.mart_gate_release` | Boolean | `false` | NODE 6C | Mart can operate the concealed release. |
| `flag.gate_chain_discovered` | Boolean | `false` | NODE 6C | Watch discovered tampering during install. |
| `rel.henning_trust` | Integer | 0 | NODE 4A, 6C | Watch captain trust delta from chain outcome. |
| `memory.mart.gate_release_taught` | Boolean | `false` | NODE 4C | Relationship memory hook for Mart dialogue. |

---

## Reachability Checklist

| Node ID | Node Name | Has Entry Conditions? | Has Effects? | Has Exit? | Has Reachable Outcome? | Status |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| NODE 1 | Alarm Order | Yes | Yes | Yes | Yes (NODE 2) | PASS |
| NODE 2 | Gate Investigation | Yes | Yes | Yes | Yes (NODE 3) | PASS |
| NODE 3 | Forge Choice | Yes | Yes | Yes | Yes (NODE 4A/B/C) | PASS |
| NODE 4A | Honest Chain | Yes | Yes | Yes | Yes (NODE 5) | PASS |
| NODE 4B | Hidden Fracture | Yes | Yes | Yes | Yes (NODE 5) | PASS |
| NODE 4C | Secret Release | Yes | Yes | Yes | Yes (NODE 5) | PASS |
| NODE 5 | Night Install | Yes | Yes | Yes | Yes (NODE 6A/B/C) | PASS |
| NODE 6A | Watch Confidence | Yes | Yes | Yes | Yes (P4-008 seal bias) | PASS |
| NODE 6B | Whispered Weakness | Yes | Yes | Yes | Yes (P4-008 break bias) | PASS |
| NODE 6C | Hidden Latch | Yes | Yes | Yes | Yes (P4-008 open bias) | PASS |

**Verification Result:** All nodes pass the reachability and definition check. Every forging branch terminates with a distinct act-climax bias flag (`flag.act_climax_viru_seal`, `flag.act_climax_viru_break`, or `flag.act_climax_viru_open`) and no universal morality score.

## P4-008 Climax Feed

| Climax flag | St. George's Night family | Gate behavior at climax |
| :--- | :--- | :--- |
| `flag.act_climax_viru_seal` | **Seal** | Forged chain holds; portcullis stays down unless walls are breached elsewhere. |
| `flag.act_climax_viru_break` | **Break** | Fractured link fails under ram pressure; rebels force the portcullis. |
| `flag.act_climax_viru_open` | **Open** | Release pin allows the gate to drop without cutting the chain. |

These biases stack with ledger standing and prior forged objects when **P4-008** resolves the act boundary.
