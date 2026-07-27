# Scene Outline: Bread and Iron

## Context

**Type:** Act 1 cycle quest (design contract for **P4-004** implementation)  
**Timeline:** Mid spring 1343, during pre-harvest grain scarcity  
**Canon status:** active outline, reconciled with P4-030 trade pricing and market/civic landmark bindings  
**Quest id:** `quest.bread_and_iron`

## Premise

Jürgen Witte controls harbour iron and the civic supply contract. He commissions Kalev to forge pivot brackets for the municipal weighing house before the next grain allotment. The **Raide baker family** (Mare and Ott Raide at the civic grain stall) depend on honest weights for their spring flour reserve. Short-weight tallies, diverted sacks, and Jürgen's hoarded surplus are squeezing the ward; every bracket Kalev forges will decide whether the Raides are fed, rationed, or driven into black-market debt.

## Locations

* **Market civic quarter (`loc.lower_town.market_civic`):** Weigh-house apron, grain stall row, and Vana Turg cart lane where investigation sites live.
* **Civic weighing house (`market_civic_quarter::market_cross`):** Install site for forged pivot brackets and municipal allotment ceremony.
* **Kalev's Smithy (`loc.kalev_smithy`):** Commission forge work and supplier iron intake from Jürgen's warehouse stock.

## Characters

* **Kalev:** Player; must balance civic duty, supplier leverage, and a baker family's survival.
* **Jürgen Witte:** Commissioning client and iron/grain supplier; profits from scarcity and rigged tallies.
* **Mare and Ott Raide:** Named baker family at the civic grain stall; receive a visible consequence in every branch.
* **Kaja:** Rebel courier routing messages through diverted grain sacks.
* **Captain Henning:** Breaks up weigh-house disputes; surfaces district-pressure consequences after install.

## Day Phase: Investigation

Kalev gathers evidence at four authored inspection sites (journal facts, no new investigation framework):

1. **Civic weighbridge:** Municipal scales read light against harbour tally chits (`fact.bread_and_iron.short_weight_tally`).
2. **Vana Turg grain lane:** Diverted rye sacks carry wax-sealed rebel messages (`fact.bread_and_iron.diverted_grain_sacks`).
3. **Market weighbridge ledgers:** Jürgen's wax tallies hide bribe lines in the civic books (`fact.bread_and_iron.supplier_ledger_fraud`).
4. **Raide grain stall:** Mare Raide's reserve bins are nearly empty before allotment day (`fact.bread_and_iron.raide_empty_bins`).

Landmark discovery beats from `docs/data/landmark_integrations.json` reinforce the same sites without adding a second journal system.

## Supplier Phase: Material Intake

Supplier record: Jürgen delivers contracted iron stock through the existing merchant supplier pattern (no new supplier framework).

| Step | System reuse | Effect |
| :--- | :--- | :--- |
| Contract briefing | `char.jurgen` dialogue at Town Hall steps | Starts `commission.bread_and_iron` and optional deadline |
| Iron stock handoff | `add_item` on `item.supplier_iron_stock` | Player inventory holds Jürgen's contracted bars for the forge charge |
| Grain tally evidence | `add_item` on `item.evidence.grain_tally_chit` | Short-weight chit collected at the weighbridge inspection site |

`TradePriceModel` quotes for `trade.iron` and `trade.bread` surface in supplier dialogue during briefing.

## Forge Phase: Commission

Commission record: `commission.bread_and_iron` (reuses `ForgeCommissionRunner`, `ForgeFeedbackSequence`, and `CommissionDeadlineModel`).

| Option | Label | Family consequence |
| :--- | :--- | :--- |
| `honest_work` | Forge true pivot brackets and testify at allotment | **Supplied** - Raides receive full municipal flour reserve |
| `subtle_defect` | Soft iron pivot that lets light sacks pass inspection | **Rationed** - Raides receive half allotment while Jürgen hoards surplus |
| `secret_feature` | Concealed chute latch for diverted grain sacks | **Black market** - Raides buy flour on credit from Jürgen at punitive rates |

Each option writes a forged record, faction ledger event, family outcome flag, and civic location state consumed by `mechanism.bread_and_iron_scales`.

## Day Phase: Allotment Install

Day encounter template reuses the civic weighing-house encounter pattern with market-cross anchors:

* **Non-combat route:** Complete bracket install under Henning's supervision when Kalev carries honest paperwork or a tampered inspection chit (subtle-defect path).
* **Confrontation route:** Interrupted install when district pressure is `crackdown`, or when Kaja's diverted sacks are discovered mid-install (secret-feature path).

Mechanism responses (`mechanism.bread_and_iron_scales`) map forged modifications to weigh-house behavior during the allotment beat and set aftermath flags.

## Aftermath States

| State | Forging option | Visible consequence for the Raide family |
| :--- | :--- | :--- |
| Fair allotment | `honest_work` | Mare Raide's stall shows full reserve bins; civic bread price eases one tier; `flag.family.raide_supplied` = true |
| Rigged scales | `subtle_defect` | Half-filled bins and a ration chit on the stall; Jürgen's warehouse props swell; `flag.family.raide_rationed` = true |
| Black-market debt | `secret_feature` | Credit tally nailed to the stall; Kaja's network moves grain overnight; `flag.family.raide_debt` = true |

`loc.lower_town.market_civic` location state (`weighhouse_fair`, `weighhouse_rigged`, `weighhouse_smuggled`) drives `EnvironmentalConsequenceController` prop visibility on the civic quarter prototype.

## System Reuse Checklist

| System | Reuse |
| :--- | :--- |
| Evidence | Journal `fact.bread_and_iron.*` facts from four inspection sites |
| Supplier | `char.jurgen` client contract, `item.supplier_iron_stock` intake, `TradePriceModel` quotes |
| Inventory | `add_item` / `remove_item` on tally chit and contracted iron stock |
| Location state | `set_location_state` on `loc.lower_town.market_civic` per aftermath branch |
| Commission | `commission.bread_and_iron` with three standard forging options and optional deadline |
| Mechanism | `mechanism.bread_and_iron_scales` behavior responses keyed to forged record |
| Consequence | `EnvironmentalConsequenceController` overlays plus faction ledger events |

No new major framework is introduced; **P4-004** wires runtime controllers against this contract.

See also: [Branch Map and State Table](bread-and-iron-branch-map.md) for node transitions, stable flags, and reachability checks.
