# Bread and Iron: Branch Map and State Table

## Context

Implementation-ready node map for `quest.bread_and_iron`. Reuses evidence, supplier, inventory, and location-state systems documented in [`bread-and-iron.md`](bread-and-iron.md). Machine-readable traversal branches live in [`content/packages/bread_and_iron/branch_map.json`](../../content/packages/bread_and_iron/branch_map.json).

## Branch Map

### NODE 1: Supply Contract

* **Description:** Jürgen Witte delivers the civic weighing-house bracket contract and contracted iron stock before the next municipal grain allotment.
* **Entry Conditions:** Act 1 morning phase active; `quest.bread_and_iron` latent or newly started.
* **Effects:**
  * Sets `quest.bread_and_iron` state to `investigating`.
  * Surfaces journal objective to inspect the weighbridge, grain lane, supplier ledgers, and Raide stall.
  * Adds `item.supplier_iron_stock` to player inventory via supplier handoff.
  * Starts `commission.bread_and_iron` deadline tracking when authored.
* **Exit:** Player accepts the supplier briefing.
* **Reachable Outcome:** Transitions to **NODE 2**.

### NODE 2: Market Investigation

* **Description:** Kalev inspects four evidence sites around the civic market quarter.
* **Entry Conditions:** Exiting **NODE 1**; quest state `investigating`.
* **Effects:**
  * Records journal facts when each site is inspected:
    * `fact.bread_and_iron.short_weight_tally`
    * `fact.bread_and_iron.diverted_grain_sacks`
    * `fact.bread_and_iron.supplier_ledger_fraud`
    * `fact.bread_and_iron.raide_empty_bins`
  * Adds `item.evidence.grain_tally_chit` to inventory at the weighbridge site.
  * Optional landmark discovery beats fire at `market_cross` without duplicating fact storage.
* **Exit:** All four facts are known.
* **Reachable Outcome:** `complete_investigation` transition to **NODE 3**.

### NODE 3: Forge Choice

* **Description:** Kalev forges the weighing-house pivot brackets at the smithy using Jürgen's contracted iron stock.
* **Entry Conditions:** Quest state `investigation_ready`; player at `loc.kalev_smithy`; `item.supplier_iron_stock` present in inventory.
* **Effects:**
  * Presents three standard forging options on `commission.bread_and_iron`.
  * Runs the five-beat forge feedback sequence before committing the forged record.
  * Removes `item.supplier_iron_stock` from inventory on commit.
* **Exit:** Player selects one forging option.
* **Reachable Outcomes:**
  * `honest_work` -> **NODE 4A**
  * `subtle_defect` -> **NODE 4B**
  * `secret_feature` -> **NODE 4C**

### NODE 4A: Honest Brackets

* **Description:** Kalev delivers true tempered pivot brackets and agrees to testify at allotment.
* **Entry Conditions:** Player selected `honest_work` in **NODE 3**.
* **Effects:**
  * Sets `flag.bread_and_iron_honest_work` = true.
  * Sets `flag.family.raide_supplied` = true.
  * Sets `loc.lower_town.market_civic` = `weighhouse_fair`.
  * Records `ledger.bread_and_iron.fair_allotment` for `faction.hanseatic_guilds` (+1).
  * Sets `rel.jurgen_trust` +1.
* **Exit:** Automatic after forge commit.
* **Reachable Outcome:** Transitions to **NODE 5**.

### NODE 4B: Rigged Pivot

* **Description:** Kalev forges a soft-iron pivot that lets underweight sacks pass inspection.
* **Entry Conditions:** Player selected `subtle_defect` in **NODE 3**; requires `fact.bread_and_iron.short_weight_tally`.
* **Effects:**
  * Sets `flag.bread_and_iron_subtle_defect` = true.
  * Sets `flag.family.raide_rationed` = true.
  * Sets `loc.lower_town.market_civic` = `weighhouse_rigged`.
  * Records `ledger.bread_and_iron.rigged_scales` for `faction.hanseatic_guilds` (+1).
  * Sets `flag.bread_and_iron_falsification_risk` = true.
* **Exit:** Automatic after forge commit.
* **Reachable Outcome:** Transitions to **NODE 5**.

### NODE 4C: Smuggler Chute

* **Description:** Kalev forges a concealed chute latch Kaja's couriers can trigger during allotment.
* **Entry Conditions:** Player selected `secret_feature` in **NODE 3**; requires `fact.bread_and_iron.diverted_grain_sacks`.
* **Effects:**
  * Sets `flag.bread_and_iron_secret_feature` = true.
  * Sets `flag.family.raide_debt` = true.
  * Sets `loc.lower_town.market_civic` = `weighhouse_smuggled`.
  * Records `ledger.bread_and_iron.smuggled_grain` for `faction.harju_kings` (+1).
  * Sets `memory.kaja.grain_chute_taught` = true.
* **Exit:** Automatic after forge commit.
* **Reachable Outcome:** Transitions to **NODE 5**.

### NODE 5: Allotment Install

* **Description:** Kalev installs the brackets at the civic weighing house during municipal grain allotment.
* **Entry Conditions:** One of **NODE 4A/B/C** completed; day phase active.
* **Effects:**
  * `mechanism.bread_and_iron_scales` resolves forged-record behavior (fair hold, rigged jam, smuggler release).
  * Patrol density follows `DistrictPressureModel` tier at `district.lower_town`.
  * Non-combat and confrontation routes reuse the civic weighing-house encounter contract.
* **Exit:** Install encounter resolves.
* **Reachable Outcomes:**
  * Honest install -> **NODE 6A**
  * Defect install undiscovered -> **NODE 6B**
  * Smuggler install (quiet or contested) -> **NODE 6C**

### NODE 6A: Fair Allotment

* **Description:** Scales read true; Mare Raide fills her reserve bins from the municipal allotment.
* **Entry Conditions:** `flag.bread_and_iron_honest_work` = true; install encounter succeeded.
* **Effects:**
  * Sets `quest.bread_and_iron` terminal state `aftermath_supplied`.
  * Sets `loc.grain_stall_raide` state to `stall_full`.
  * Clears crackdown overlay on market cross unless district pressure already `crackdown`.
* **Exit:** Bed rest or phase advance.
* **Reachable Outcome:** Cycle complete; Raide family supplied for later Act 1 references.

### NODE 6B: Rationed Ward

* **Description:** Scales pass inspection but the Raides receive half their flour reserve.
* **Entry Conditions:** `flag.bread_and_iron_subtle_defect` = true; install encounter succeeded.
* **Effects:**
  * Sets `quest.bread_and_iron` terminal state `aftermath_rationed`.
  * Sets `loc.grain_stall_raide` state to `stall_rationed`.
  * Sets `flag.jurgen_surplus_visible` = true on Jürgen's warehouse props.
* **Exit:** Bed rest or phase advance.
* **Reachable Outcome:** Cycle complete; Raide family rationed.

### NODE 6C: Black-Market Debt

* **Description:** Diverted grain moves overnight; the Raides owe Jürgen for emergency flour.
* **Entry Conditions:** `flag.bread_and_iron_secret_feature` = true; install encounter succeeded.
* **Effects:**
  * Sets `quest.bread_and_iron` terminal state `aftermath_debt`.
  * Sets `loc.grain_stall_raide` state to `stall_debt`.
  * Sets `flag.kaja_grain_chute` = true when install was quiet; sets `flag.bread_and_iron_discovered` = true when install was contested.
  * Adjusts `rel.jurgen_trust` -1 when discovery flag is set.
* **Exit:** Bed rest or phase advance.
* **Reachable Outcome:** Cycle complete; Raide family in debt.

---

## State Table

| Variable Name | Type | Initial Value | Modified In | Description / Effect |
| :--- | :--- | :--- | :--- | :--- |
| `quest.bread_and_iron` | Quest state | `investigating` | NODE 1-6 | `investigating`, `investigation_ready`, `aftermath_supplied`, `aftermath_rationed`, `aftermath_debt` |
| `fact.bread_and_iron.short_weight_tally` | Boolean | `false` | NODE 2 | Harbour tally chits outweigh municipal scale readings. |
| `fact.bread_and_iron.diverted_grain_sacks` | Boolean | `false` | NODE 2 | Rebel wax seals found on diverted rye sacks in Vana Turg. |
| `fact.bread_and_iron.supplier_ledger_fraud` | Boolean | `false` | NODE 2 | Jürgen's wax tallies hide bribe lines in civic books. |
| `fact.bread_and_iron.raide_empty_bins` | Boolean | `false` | NODE 2 | Mare Raide's reserve bins nearly empty before allotment. |
| `item.supplier_iron_stock` | Inventory | absent | NODE 1, 3 | Jürgen's contracted iron bars for the bracket commission. |
| `item.evidence.grain_tally_chit` | Inventory | absent | NODE 2 | Short-weight tally chit collected at the weighbridge. |
| `flag.bread_and_iron_honest_work` | Boolean | `false` | NODE 4A | Honest pivot brackets committed at forge. |
| `flag.bread_and_iron_subtle_defect` | Boolean | `false` | NODE 4B | Soft-iron rigged pivot committed at forge. |
| `flag.bread_and_iron_secret_feature` | Boolean | `false` | NODE 4C | Concealed smuggler chute committed at forge. |
| `flag.family.raide_supplied` | Boolean | `false` | NODE 4A, 6A | Raide family receives full municipal flour reserve. |
| `flag.family.raide_rationed` | Boolean | `false` | NODE 4B, 6B | Raide family receives half allotment. |
| `flag.family.raide_debt` | Boolean | `false` | NODE 4C, 6C | Raide family owes Jürgen for black-market flour. |
| `loc.lower_town.market_civic` | Location state | `""` | NODE 4A/B/C | `weighhouse_fair`, `weighhouse_rigged`, or `weighhouse_smuggled`. |
| `loc.grain_stall_raide` | Location state | `""` | NODE 6A/B/C | `stall_full`, `stall_rationed`, or `stall_debt`. |
| `flag.bread_and_iron_falsification_risk` | Boolean | `false` | NODE 4B | Rigged pivot may be discovered before St. George's Night. |
| `flag.jurgen_surplus_visible` | Boolean | `false` | NODE 6B | Jürgen's hoarded surplus is visible at the warehouse. |
| `flag.kaja_grain_chute` | Boolean | `false` | NODE 6C | Kaja's network can operate the concealed chute. |
| `flag.bread_and_iron_discovered` | Boolean | `false` | NODE 6C | Watch discovered tampering during install. |
| `rel.jurgen_trust` | Integer | 0 | NODE 4A, 6C | Supplier trust delta from bracket outcome. |
| `memory.kaja.grain_chute_taught` | Boolean | `false` | NODE 4C | Relationship memory hook for Kaja dialogue. |

---

## Reachability Checklist

| Node ID | Node Name | Has Entry Conditions? | Has Effects? | Has Exit? | Has Reachable Outcome? | Status |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| NODE 1 | Supply Contract | Yes | Yes | Yes | Yes (NODE 2) | PASS |
| NODE 2 | Market Investigation | Yes | Yes | Yes | Yes (NODE 3) | PASS |
| NODE 3 | Forge Choice | Yes | Yes | Yes | Yes (NODE 4A/B/C) | PASS |
| NODE 4A | Honest Brackets | Yes | Yes | Yes | Yes (NODE 5) | PASS |
| NODE 4B | Rigged Pivot | Yes | Yes | Yes | Yes (NODE 5) | PASS |
| NODE 4C | Smuggler Chute | Yes | Yes | Yes | Yes (NODE 5) | PASS |
| NODE 5 | Allotment Install | Yes | Yes | Yes | Yes (NODE 6A/B/C) | PASS |
| NODE 6A | Fair Allotment | Yes | Yes | Yes | Yes (Raide supplied) | PASS |
| NODE 6B | Rationed Ward | Yes | Yes | Yes | Yes (Raide rationed) | PASS |
| NODE 6C | Black-Market Debt | Yes | Yes | Yes | Yes (Raide in debt) | PASS |

**Verification Result:** All nodes pass the reachability and definition check. Every forging branch terminates with a distinct Raide family outcome flag (`flag.family.raide_supplied`, `flag.family.raide_rationed`, or `flag.family.raide_debt`) and no universal morality score.

## Family Consequence Feed

| Family flag | Raide family state | Visible market read |
| :--- | :--- | :--- |
| `flag.family.raide_supplied` | Full reserve bins | Civic bread price eases one tier; Mare thanks Kalev at the stall |
| `flag.family.raide_rationed` | Half-filled bins | Ration chit nailed to the stall; Jürgen's surplus props swell nearby |
| `flag.family.raide_debt` | Credit tally on stall | Kaja's couriers move grain overnight; Ott Raide avoids eye contact |

These family states stack with ledger standing and district pressure when later Act 1 cycles reference the civic market quarter.
