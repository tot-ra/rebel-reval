# St. George's Night: Branch Map and State Table

## Context

Implementation-ready node map for `quest.st_georges_night`. Reuses mechanism, gate, patrol, ledger, and consequence systems documented in [`st-georges-night.md`](st-georges-night.md). Machine-readable traversal branches live in [`content/packages/st_georges_night/branch_map.json`](../../content/packages/st_georges_night/branch_map.json).

## Branch Map

### NODE 1: Bonfire Signal

* **Description:** Hilltop fires light the April sky; the act-climax phase begins and Kalev is summoned to Viru Gate.
* **Entry Conditions:** Act 1 epilogue quests complete or skipped per campaign gate; calendar reaches St. George's Night.
* **Effects:**
  * Sets `quest.st_georges_night` state to `latent` if not started.
  * Sets `flag.st_georges_night_signal` = true.
  * Advances phase to `phase.act1_climax` when runtime wiring lands in **P4-008**.
* **Exit:** Phase director triggers climax start.
* **Reachable Outcome:** Transitions to **NODE 2**.

### NODE 2: Gate Approach

* **Description:** Kalev reaches `checkpoint_east` while patrol density and environmental overlays reflect district pressure.
* **Entry Conditions:** Exiting **NODE 1**; quest state `latent`.
* **Effects:**
  * `begin_approach` sets quest state to `approaching`.
  * `mechanism.st_georges_night_gate` evaluates stacked bias flags from prior cycles.
  * Rally dialogue surfaces Henning, Mart, and Kaja options gated by ledger standing and memory keys.
* **Exit:** Player commits one climax choice.
* **Reachable Outcomes:**
  * Seal choice -> **NODE 3A**
  * Break choice -> **NODE 3B**
  * Open choice -> **NODE 3C**

### NODE 3A: Seal the Gate

* **Description:** Kalev holds the portcullis with Henning; the honest chain from `quest.bell_and_chain` holds under ram pressure.
* **Entry Conditions:** Quest state `approaching`; `flag.act_climax_viru_seal` = true **or** `faction_standing_at_least` for `faction.livonian_order` >= 2.
* **Effects:**
  * Sets `flag.act_boundary.viru_seal` = true.
  * Sets `flag.act_transition.act1_recorded` = true.
  * Records `ledger.st_georges_night.gate_sealed` for `faction.livonian_order` (+1).
  * Sets `quest.st_georges_night` terminal state `aftermath_seal`.
* **Exit:** Encounter resolves; act-boundary cutscene plays.
* **Reachable Outcome:** Act 1 boundary **Seal** family recorded for **P4-009**.

### NODE 3B: Break the Gate

* **Description:** Rebels strain the hidden fracture; the portcullis fails and the ward collapses inward.
* **Entry Conditions:** Quest state `approaching`; `flag.act_climax_viru_break` = true **or** `faction_standing_at_least` for `faction.harju_kings` >= 2.
* **Effects:**
  * Sets `flag.act_boundary.viru_break` = true.
  * Sets `flag.act_transition.act1_recorded` = true.
  * Records `ledger.st_georges_night.gate_breached` for `faction.harju_kings` (+1).
  * Sets `quest.st_georges_night` terminal state `aftermath_break`.
* **Exit:** Encounter resolves; act-boundary cutscene plays.
* **Reachable Outcome:** Act 1 boundary **Break** family recorded for **P4-009**.

### NODE 3C: Open the Gate

* **Description:** Mart or Kaja triggers the concealed release; the gate drops without cutting the chain.
* **Entry Conditions:** Quest state `approaching`; `flag.act_climax_viru_open` = true **or** `faction_standing_at_least` for `faction.black_cloaks` >= 2.
* **Effects:**
  * Sets `flag.act_boundary.viru_open` = true.
  * Sets `flag.act_transition.act1_recorded` = true.
  * Records `ledger.st_georges_night.gate_opened` for `faction.black_cloaks` (+1).
  * Sets `quest.st_georges_night` terminal state `aftermath_open`.
* **Exit:** Encounter resolves; act-boundary cutscene plays.
* **Reachable Outcome:** Act 1 boundary **Open** family recorded for **P4-009**.

---

## State Table

| Variable Name | Type | Initial Value | Modified In | Description / Effect |
| :--- | :--- | :--- | :--- | :--- |
| `quest.st_georges_night` | Quest state | `latent` | NODE 1-3 | `latent`, `approaching`, `aftermath_seal`, `aftermath_break`, `aftermath_open` |
| `flag.st_georges_night_signal` | Boolean | `false` | NODE 1 | Bonfires visible; climax phase armed. |
| `flag.act_climax_viru_seal` | Boolean | `false` | Prior cycles | Seal bias from `quest.bell_and_chain` and allies. |
| `flag.act_climax_viru_break` | Boolean | `false` | Prior cycles | Break bias from prior forged defects. |
| `flag.act_climax_viru_open` | Boolean | `false` | Prior cycles | Open bias from secret release work. |
| `flag.act_boundary.viru_seal` | Boolean | `false` | NODE 3A | Terminal **Seal** act-boundary family. |
| `flag.act_boundary.viru_break` | Boolean | `false` | NODE 3B | Terminal **Break** act-boundary family. |
| `flag.act_boundary.viru_open` | Boolean | `false` | NODE 3C | Terminal **Open** act-boundary family. |
| `flag.act_transition.act1_recorded` | Boolean | `false` | NODE 3A/B/C | Act 1 transition envelope written for save migration. |
| `rel.henning_trust` | Integer | 0 | NODE 3A | Watch captain trust delta from seal path. |
| `rel.mart_trust` | Integer | 0 | NODE 3C | Apprentice trust delta from open path. |
| `memory.mart.gate_release_taught` | Boolean | `false` | Prior cycles | Unlocks open-path dialogue when true. |

---

## Reachability Checklist

| Node ID | Node Name | Has Entry Conditions? | Has Effects? | Has Exit? | Has Reachable Outcome? | Status |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| NODE 1 | Bonfire Signal | Yes | Yes | Yes | Yes (NODE 2) | PASS |
| NODE 2 | Gate Approach | Yes | Yes | Yes | Yes (NODE 3A/B/C) | PASS |
| NODE 3A | Seal the Gate | Yes | Yes | Yes | Yes (P4-009 seal family) | PASS |
| NODE 3B | Break the Gate | Yes | Yes | Yes | Yes (P4-009 break family) | PASS |
| NODE 3C | Open the Gate | Yes | Yes | Yes | Yes (P4-009 open family) | PASS |

**Verification Result:** All nodes pass the reachability and definition check. Every act-boundary family terminates with a distinct `flag.act_boundary.viru_*` flag and `flag.act_transition.act1_recorded` without a universal morality score.

## Prior Cycle Feed

| Climax bias flag | Source quest | Gate behavior at NODE 3 |
| :--- | :--- | :--- |
| `flag.act_climax_viru_seal` | `quest.bell_and_chain` honest chain | **Seal** - portcullis holds |
| `flag.act_climax_viru_break` | `quest.bell_and_chain` hidden fracture | **Break** - link fails under strain |
| `flag.act_climax_viru_open` | `quest.bell_and_chain` secret release | **Open** - pin drops the gate |

Ledger standing and forged records from `quest.bread_and_iron`, `quest.price_of_a_name`, and `quest.root_and_ember` adjust rally dialogue and patrol overlays but do not introduce a fourth act-boundary family.
