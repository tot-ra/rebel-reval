# The Price of a Name: Branch Map and State Table

## Context

Implementation-ready node map for `quest.price_of_a_name`. Reuses relationships, detention, false evidence, and Hingepuu reflection hooks documented in [`the-price-of-a-name.md`](the-price-of-a-name.md). Machine-readable traversal branches live in [`content/packages/price_of_a_name/branch_map.json`](../../content/packages/price_of_a_name/branch_map.json).

## Branch Map

### NODE 1: Round-Up Order

* **Description:** Henning delivers the coastal detention-cart commission after a rebel dispatch names Mart as a harbor contact.
* **Entry Conditions:** Act 1 morning phase active; `quest.price_of_a_name` latent or newly started.
* **Effects:**
  * Sets `quest.price_of_a_name` state to `investigating`.
  * Surfaces journal objective to inspect the watch tower log, salt warehouse, packhouse lane, and ropewalk route.
  * Adds `item.evidence.seized_dispatch` to player inventory via watch handoff.
  * Starts `commission.price_of_a_name` deadline tracking when authored.
* **Exit:** Player accepts the detention briefing.
* **Reachable Outcome:** Transitions to **NODE 2**.

### NODE 2: Harbor Investigation

* **Description:** Kalev inspects four evidence sites around the north-quarter merchant court.
* **Entry Conditions:** Exiting **NODE 1**; quest state `investigating`.
* **Effects:**
  * Records journal facts when each site is inspected:
    * `fact.price_of_a_name.dispatch_name`
    * `fact.price_of_a_name.salt_warehouse_drop`
    * `fact.price_of_a_name.packhouse_spears`
    * `fact.price_of_a_name.ropewalk_route`
  * Adds `item.evidence.seized_dispatch` to inventory at the watch tower site if not already held.
  * Optional landmark discovery beats fire at `merchant_court` without duplicating fact storage.
* **Exit:** All four facts are known.
* **Reachable Outcome:** `complete_investigation` transition to **NODE 3**.

### NODE 3: Forge Choice

* **Description:** Kalev forges detention-cart shackles and a brass name-plate at the smithy.
* **Entry Conditions:** Quest state `investigation_ready`; player at `loc.kalev_smithy`; `item.evidence.seized_dispatch` present in inventory.
* **Effects:**
  * Presents three standard forging options on `commission.price_of_a_name`.
  * Runs the five-beat forge feedback sequence before committing the forged record.
  * Removes `item.evidence.seized_dispatch` from inventory on commit when the plate is altered.
* **Exit:** Player selects one forging option.
* **Reachable Outcomes:**
  * `honest_work` -> **NODE 4A**
  * `subtle_defect` -> **NODE 4B**
  * `secret_feature` -> **NODE 4C**

### NODE 4A: Honest Plates

* **Description:** Kalev forges true name-plates and agrees to testify at the St. Olaf guild hearing.
* **Entry Conditions:** Player selected `honest_work` in **NODE 3**.
* **Effects:**
  * Sets `flag.price_of_a_name_honest_work` = true.
  * Sets `flag.mart.name_cleared` = true.
  * Sets `loc.north_quarter.merchant_court` = `detention_fair`.
  * Records `ledger.price_of_a_name.name_cleared` for `faction.livonian_order` (+1).
  * Sets `rel.mart_trust` +1 and `rel.henning_trust` +1.
  * Sets `memory.mart.name_defended` = true.
* **Exit:** Automatic after forge commit.
* **Reachable Outcome:** Transitions to **NODE 5**.

### NODE 4B: False Clerk Plate

* **Description:** Kalev forges a name-plate implicating a dead Novgorod clerk found in the counting-house ledgers.
* **Entry Conditions:** Player selected `subtle_defect` in **NODE 3**; requires `fact.price_of_a_name.dispatch_name`.
* **Effects:**
  * Sets `flag.price_of_a_name_subtle_defect` = true.
  * Sets `flag.mart.name_redirected` = true.
  * Sets `loc.north_quarter.merchant_court` = `detention_redirected`.
  * Records `ledger.price_of_a_name.false_clerk` for `faction.black_cloaks` (+1).
  * Sets `flag.price_of_a_name_falsification_risk` = true.
  * Sets `rel.kaja_trust` +1.
* **Exit:** Automatic after forge commit.
* **Reachable Outcome:** Transitions to **NODE 5**.

### NODE 4C: Swapped Plate

* **Description:** Kalev forges a concealed shackle release and swaps the brass plate to keep Mart off the detention roll.
* **Entry Conditions:** Player selected `secret_feature` in **NODE 3**; requires `fact.price_of_a_name.salt_warehouse_drop`.
* **Effects:**
  * Sets `flag.price_of_a_name_secret_feature` = true.
  * Sets `flag.mart.name_concealed` = true.
  * Sets `loc.north_quarter.merchant_court` = `detention_concealed`.
  * Records `ledger.price_of_a_name.name_concealed` for `faction.harju_kings` (+1).
  * Sets `memory.kaja.name_plate_swapped` = true.
  * Sets `rel.mart_trust` +1.
* **Exit:** Automatic after forge commit.
* **Reachable Outcome:** Transitions to **NODE 5**.

### NODE 5: Coastal Transfer Install

* **Description:** Kalev installs the shackles and name-plate at the Coastal Gate detention apron before prisoner transfer.
* **Entry Conditions:** One of **NODE 4A/B/C** completed; day phase active.
* **Effects:**
  * `mechanism.price_of_a_name_detention` resolves forged-record behavior (fair hold, false clerk redirect, concealed release).
  * Patrol density follows `DistrictPressureModel` tier at `district.north_quarter`.
  * Non-combat and confrontation routes reuse the coastal detention encounter contract.
* **Exit:** Install encounter resolves.
* **Reachable Outcomes:**
  * Honest install -> **NODE 6A**
  * Redirect install undiscovered -> **NODE 6B**
  * Concealed install (quiet or contested) -> **NODE 6C**

### NODE 6A: Guild Hearing Cleared

* **Description:** Mart's name is struck from the detention roll at the St. Olaf guild courtyard hearing.
* **Entry Conditions:** `flag.mart.name_cleared` = true; install encounter succeeded.
* **Effects:**
  * Sets `quest.price_of_a_name` terminal state `aftermath_cleared`.
  * Sets `flag.reflection.conviction_duty` = true for the next Hingepuu morning.
  * Clears crackdown overlay on merchant court unless district pressure already `crackdown`.
* **Exit:** Bed rest opens Hingepuu reflection.
* **Reachable Outcome:** Cycle complete; Mart cleared for later Act 1 references.

### NODE 6B: Scapegoat Transfer

* **Description:** A dead clerk's name rides the cart while Mart stays nervous but off the roll.
* **Entry Conditions:** `flag.mart.name_redirected` = true; install encounter succeeded.
* **Effects:**
  * Sets `quest.price_of_a_name` terminal state `aftermath_redirected`.
  * Sets `flag.reflection.conviction_fury` = true for the next Hingepuu morning.
  * Sets `flag.kaja_harbor_emboldened` = true.
* **Exit:** Bed rest opens Hingepuu reflection.
* **Reachable Outcome:** Cycle complete; Mart redirected.

### NODE 6C: Quiet Release

* **Description:** Mart knows the shackle release; Kaja's harbor drop survives the round-up.
* **Entry Conditions:** `flag.mart.name_concealed` = true; install encounter succeeded.
* **Effects:**
  * Sets `quest.price_of_a_name` terminal state `aftermath_concealed`.
  * Sets `flag.reflection.conviction_mercy` = true for the next Hingepuu morning.
  * Sets `flag.mart_detention_release` = true when install was quiet; sets `flag.price_of_a_name_discovered` = true when install was contested.
  * Adjusts `rel.henning_trust` -1 when discovery flag is set.
* **Exit:** Bed rest opens Hingepuu reflection.
* **Reachable Outcome:** Cycle complete; Mart concealed.

---

## State Table

| Variable Name | Type | Initial Value | Modified In | Description / Effect |
| :--- | :--- | :--- | :--- | :--- |
| `quest.price_of_a_name` | Quest state | `investigating` | NODE 1-6 | `investigating`, `investigation_ready`, `aftermath_cleared`, `aftermath_redirected`, `aftermath_concealed` |
| `fact.price_of_a_name.dispatch_name` | Boolean | `false` | NODE 2 | Seized dispatch lists Mart as a Pikk Street harbor contact. |
| `fact.price_of_a_name.salt_warehouse_drop` | Boolean | `false` | NODE 2 | Kaja's wax-sealed dispatches hide between salt barrels. |
| `fact.price_of_a_name.packhouse_spears` | Boolean | `false` | NODE 2 | Smuggled spearheads travel in empty barrel returns. |
| `fact.price_of_a_name.ropewalk_route` | Boolean | `false` | NODE 2 | Detention cart route tied to Henning's watch-boat requisition. |
| `item.evidence.seized_dispatch` | Inventory | absent | NODE 1, 3 | Watch copy of the rebel dispatch naming Mart. |
| `flag.price_of_a_name_honest_work` | Boolean | `false` | NODE 4A | Honest name-plates committed at forge. |
| `flag.price_of_a_name_subtle_defect` | Boolean | `false` | NODE 4B | False clerk name-plate committed at forge. |
| `flag.price_of_a_name_secret_feature` | Boolean | `false` | NODE 4C | Concealed shackle release and swapped plate committed at forge. |
| `flag.mart.name_cleared` | Boolean | `false` | NODE 4A, 6A | Mart's name struck from the detention roll. |
| `flag.mart.name_redirected` | Boolean | `false` | NODE 4B, 6B | False evidence redirects the round-up onto a scapegoat. |
| `flag.mart.name_concealed` | Boolean | `false` | NODE 4C, 6C | Mart stays off the roll through a swapped plate. |
| `loc.north_quarter.merchant_court` | Location state | `""` | NODE 4A/B/C | `detention_fair`, `detention_redirected`, or `detention_concealed`. |
| `flag.price_of_a_name_falsification_risk` | Boolean | `false` | NODE 4B | False clerk plate may be discovered before St. George's Night. |
| `flag.kaja_harbor_emboldened` | Boolean | `false` | NODE 6B | Kaja's network keeps operating after the redirect. |
| `flag.mart_detention_release` | Boolean | `false` | NODE 6C | Mart can operate the concealed shackle release. |
| `flag.price_of_a_name_discovered` | Boolean | `false` | NODE 6C | Watch discovered the swapped plate during install. |
| `rel.mart_trust` | Integer | 0 | NODE 4A, 4C | Apprentice trust delta from name outcome. |
| `rel.henning_trust` | Integer | 0 | NODE 4A, 6C | Watch captain trust delta from detention outcome. |
| `rel.kaja_trust` | Integer | 0 | NODE 4B | Rebel courier trust delta from false-evidence path. |
| `memory.mart.name_defended` | Boolean | `false` | NODE 4A | Relationship memory hook for Mart dialogue. |
| `memory.kaja.name_plate_swapped` | Boolean | `false` | NODE 4C | Relationship memory hook for Kaja dialogue. |
| `flag.reflection.conviction_duty` | Boolean | `false` | NODE 6A | Hingepuu Duty mark after honest testimony. |
| `flag.reflection.conviction_fury` | Boolean | `false` | NODE 6B | Hingepuu Fury mark after false-evidence redirect. |
| `flag.reflection.conviction_mercy` | Boolean | `false` | NODE 6C | Hingepuu Mercy mark after concealed release. |

---

## Reachability Checklist

| Node ID | Node Name | Has Entry Conditions? | Has Effects? | Has Exit? | Has Reachable Outcome? | Status |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| NODE 1 | Round-Up Order | Yes | Yes | Yes | Yes (NODE 2) | PASS |
| NODE 2 | Harbor Investigation | Yes | Yes | Yes | Yes (NODE 3) | PASS |
| NODE 3 | Forge Choice | Yes | Yes | Yes | Yes (NODE 4A/B/C) | PASS |
| NODE 4A | Honest Plates | Yes | Yes | Yes | Yes (NODE 5) | PASS |
| NODE 4B | False Clerk Plate | Yes | Yes | Yes | Yes (NODE 5) | PASS |
| NODE 4C | Swapped Plate | Yes | Yes | Yes | Yes (NODE 5) | PASS |
| NODE 5 | Coastal Transfer Install | Yes | Yes | Yes | Yes (NODE 6A/B/C) | PASS |
| NODE 6A | Guild Hearing Cleared | Yes | Yes | Yes | Yes (Mart cleared) | PASS |
| NODE 6B | Scapegoat Transfer | Yes | Yes | Yes | Yes (Mart redirected) | PASS |
| NODE 6C | Quiet Release | Yes | Yes | Yes | Yes (Mart concealed) | PASS |

**Verification Result:** All nodes pass the reachability and definition check. Every forging branch terminates with a distinct Mart name outcome flag (`flag.mart.name_cleared`, `flag.mart.name_redirected`, or `flag.mart.name_concealed`) and no universal morality score.

## Character Consequence Feed

| Mart flag | Mart state | Kaja read | Henning read | Kalev reflection |
| :--- | :--- | :--- | :--- | :--- |
| `flag.mart.name_cleared` | Works openly at guild workshops | Salt drop burned; respects honesty | Gains a real rebel lead | Duty |
| `flag.mart.name_redirected` | Nervous but off the roll | Emboldened; harbor drop survives | May discover falsification later | Fury |
| `flag.mart.name_concealed` | Knows shackle release | Network keeps harbor drop | Suspicious if swap found | Mercy |

These character states stack with ledger standing, relationship memory, and district pressure when later Act 1 cycles reference the north-quarter merchant court.
