# The Maker's Mark: Branch Map and State Table

## Context
This document defines the definitive node-based branch map and state table for `The Maker's Mark` prologue scene. It translates the narrative outline into an implementation-ready structure, tracking entry conditions, effects, player exits, and outcomes for every step.

## Branch Map

### NODE 1: Morning Repairs
* **Description:** Kalev begins his day in the Smithy Courtyard. He moves inside to perform routine repairs.
* **Entry Conditions:** `Start of Prologue`
* **Effects:** 
  * Player learns basic orthogonal movement and interaction.
  * Kalev interacts with the anvil to repair a plough part and a watchman's buckle.
* **Exit:** Player completes the required repair interactions.
* **Reachable Outcome:** Automatically transitions to **NODE 2**.

### NODE 2: The Commission Pressure
* **Description:** Captain Henning arrives unexpectedly at the smithy.
* **Entry Conditions:** Completion of morning repairs (exiting **NODE 1**).
* **Effects:** 
  * Henning presents a seized spearhead bearing Kalev's unique maker mark.
  * Dialogue scene occurs: Henning demands an explanation before his official inspection tomorrow.
  * Sets state: `prologue_maker_mark_incident` = `true`.
* **Exit:** Henning concludes his dialogue and leaves the smithy.
* **Reachable Outcome:** Automatically transitions to **NODE 3**.

### NODE 3: The Missing Apprentice
* **Description:** Kalev searches the shop for his apprentice, Mart, to demand answers.
* **Entry Conditions:** Henning has left the smithy (exiting **NODE 2**).
* **Effects:** 
  * Kalev investigates the storage chest and workspace.
  * Discovers Mart is absent and the rejected iron blanks are missing.
  * Sets state: `mart_missing` = `true`.
  * Sets state: `rejected_blanks_missing` = `true`.
* **Exit:** Kalev approaches the forge ledger to check the material records.
* **Reachable Outcome:** Automatically transitions to **NODE 4**.

### NODE 4: The Ledger Choice
* **Description:** Kalev reviews the ledger and faces a critical choice on how to handle the written evidence.
* **Entry Conditions:** Player interacts with the ledger after discovering the missing blanks (exiting **NODE 3**).
* **Effects:** 
  * Kalev reads the entries confirming the rejected blanks were logged.
  * Player is presented with a three-way narrative choice.
* **Exit:** Player selects one of three dialogue/action prompts.
* **Reachable Outcomes:** 
  * Selects "Preserve" -> transitions to **NODE 5A**.
  * Selects "Alter" -> transitions to **NODE 5B**.
  * Selects "Destroy" -> transitions to **NODE 5C**.

### NODE 5A: Preserve Ledger
* **Description:** Kalev leaves the ledger intact, keeping a truthful record despite the danger.
* **Entry Conditions:** Player selected "Preserve" in **NODE 4**.
* **Effects:** 
  * Sets state: `forge_ledger_status` = `preserved`.
  * Increases relationship: `watch_trust` +1.
  * Increases danger: `mart_risk` +1.
* **Exit:** Automatic.
* **Reachable Outcome:** Transitions to **NODE 6**.

### NODE 5B: Alter Ledger
* **Description:** Kalev changes the ledger to obscure the rejected blanks, covering for Mart.
* **Entry Conditions:** Player selected "Alter" in **NODE 4**.
* **Effects:** 
  * Sets state: `forge_ledger_status` = `altered`.
  * Sets state flag: `falsification_risk` = `true`.
* **Exit:** Automatic.
* **Reachable Outcome:** Transitions to **NODE 6**.

### NODE 5C: Destroy Ledger Pages
* **Description:** Kalev tears out and burns the relevant ledger pages in the forge.
* **Entry Conditions:** Player selected "Destroy" in **NODE 4**.
* **Effects:** 
  * Sets state: `forge_ledger_status` = `destroyed`.
  * Increases relationship: `mart_protection` +1.
  * Increases danger: `watch_suspicion` +1.
* **Exit:** Automatic.
* **Reachable Outcome:** Transitions to **NODE 6**.

### NODE 6: End of Day Shift
* **Description:** Kalev commits to his decision. The work day is over.
* **Entry Conditions:** Ledger choice completed (exiting **NODE 5A**, **NODE 5B**, or **NODE 5C**).
* **Effects:** 
  * The ledger is locked from further interaction.
  * Kalev reflects on the impending night.
* **Exit:** Player interacts with the bed or door to end the shift.
* **Reachable Outcome:** Ends the Prologue. Proceeds to Scene 1 (Night consequence setup).

---

## State Table

| Variable Name | Type | Initial Value | Modified In | Description / Effect |
| :--- | :--- | :--- | :--- | :--- |
| `prologue_maker_mark_incident` | Boolean | `false` | NODE 2 | True when Henning confronts Kalev with the marked spearhead. |
| `mart_missing` | Boolean | `false` | NODE 3 | True when Kalev confirms Mart is not in the shop. |
| `rejected_blanks_missing` | Boolean | `false` | NODE 3 | True when Kalev discovers the rejected materials are gone. |
| `forge_ledger_status` | Enum | `null` | NODE 5A/B/C | `preserved`, `altered`, or `destroyed`. Determines Henning's evidence later. |
| `watch_trust` | Integer | 0 | NODE 5A | Tracks Henning's belief in Kalev's honesty. |
| `watch_suspicion` | Integer | 0 | NODE 5C | Tracks Henning's suspicion of Kalev's activities. |
| `mart_risk` | Integer | 0 | NODE 5A | Tracks the level of evidential danger to Mart. |
| `mart_protection` | Integer | 0 | NODE 5C | Tracks Kalev's active measures to protect Mart. |
| `falsification_risk` | Boolean | `false` | NODE 5B | True if the ledger was altered, creating a blackmail/discovery risk. |

---

## Reachability Checklist

| Node ID | Node Name | Has Entry Conditions? | Has Effects? | Has Exit? | Has Reachable Outcome? | Status |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| NODE 1 | Morning Repairs | Yes | Yes | Yes | Yes (NODE 2) | PASS |
| NODE 2 | The Commission Pressure | Yes | Yes | Yes | Yes (NODE 3) | PASS |
| NODE 3 | The Missing Apprentice | Yes | Yes | Yes | Yes (NODE 4) | PASS |
| NODE 4 | The Ledger Choice | Yes | Yes | Yes | Yes (NODE 5A/B/C) | PASS |
| NODE 5A | Preserve Ledger | Yes | Yes | Yes | Yes (NODE 6) | PASS |
| NODE 5B | Alter Ledger | Yes | Yes | Yes | Yes (NODE 6) | PASS |
| NODE 5C | Destroy Ledger Pages | Yes | Yes | Yes | Yes (NODE 6) | PASS |
| NODE 6 | End of Day Shift | Yes | Yes | Yes | Yes (Scene 1) | PASS |

**Verification Result:** All nodes pass the reachability and definition check. Every branch successfully terminates at the Prologue's end.