# Scene Outline: The Maker's Mark

## Context

**Type:** Playable Prologue / Vertical Slice  
**Timeline:** Pre-April 23, 1343  
**Canon status:** active outline, reconciled with README Campaign outline and P0-012 family canon

## Locations

* **Kalev's Smithy (Interior):** Kalev's home and primary workspace. Contains the forge, anvil, ledger, storage chest, and a simple bed or sleeping alcove.
* **Smithy Courtyard (Exterior):** A small enclosed area outside the shop, connecting to the Lower Town street.

## Characters

* **Kalev:** The player character. A skilled lower-town smith.
* **Captain Henning:** Commander of the Viru Watch. Imposing, representing the local city watch authority.
* **Mart:** Kalev's 16-year-old apprentice. Mart is not physically present in this prologue beat; his absence and the missing rejected iron create the incident Kalev must answer for.

## Interactions

1. **Introduction:** Kalev starts in the Smithy Courtyard and enters the smithy to repair a plough part and a watchman's buckle.
2. **The Commission Pressure:** Captain Henning arrives with a seized spearhead bearing Kalev's maker mark and demands an explanation before the next inspection.
3. **The Missing Apprentice:** Kalev discovers that Mart is missing and rejected iron blanks are gone, implying that Mart passed marked rejects to the Black Cloaks.
4. **The Ledger Choice:** Kalev inspects the forge ledger and chooses whether to preserve, alter, or destroy the record of rejected blanks.
5. **End of Day:** Kalev commits to his ledger choice and uses the bed or door to end the day shift, triggering the night consequence setup.

## Tutorial Beats

* **Movement:** Basic orthogonal navigation in the courtyard and into the smithy.
* **Interaction:** Approaching characters and objects, including Henning, the anvil, storage chest, ledger, bed, and door.
* **Commission Reading:** Recognizing workmanship, maker marks, and rejected blanks as evidence rather than generic inventory.
* **Forging / Repair:** Completing simple repair actions before the maker-mark incident escalates the scene.
* **Ledger Consequence:** Making a deliberate narrative-system choice with visible state effects.

## Ledger Branches

The player must decide how Kalev handles the written evidence linking his forge to Mart's action:

* **Branch A (Preserve):** Kalev keeps the ledger intact. Henning can later use it as evidence, but Kalev retains a truthful record.
* **Branch B (Alter):** Kalev changes the ledger to obscure the rejected blanks. This buys time, but creates a falsified record that can be exposed.
* **Branch C (Destroy):** Kalev destroys the relevant ledger pages. This protects Mart in the short term, but removes evidence Kalev may need later.

## State Effects

* **Global Variables:**
  * `prologue_maker_mark_incident`: true
  * `mart_missing`: true
  * `rejected_blanks_missing`: true
  * `forge_ledger_status`: `preserved`, `altered`, or `destroyed`
* **Relationship / Reputation:**
  * Branch A: +1 Watch Authority Trust (Henning), +1 Evidence Risk (Mart)
  * Branch B: +1 Suspicion if falsification is discovered
  * Branch C: +1 Mart Protection, +1 Watch Suspicion
* **Inventory / Evidence:** The seized spearhead is inspected as evidence; it is not treated as a normal quest reward.

## Exit Condition

The scene concludes when Kalev confirms the ledger branch and ends the day shift at his bed or door. The chosen ledger state and Mart's missing status carry into the next playable phase.
