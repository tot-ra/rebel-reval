# P6-001 Act 3 design: The Iron Harvest

**Status:** approved for implementation; runtime/content activation remains task-gated
**Task:** R-323 / P6-001
**Authority:** [ADR 0008](../adr/0008-three-act-campaign-and-faction-scope.md)
**Manifest:** [`docs/data/act3_design_manifest.json`](../data/act3_design_manifest.json)
**Canon:** [`docs/CANON.md`](../CANON.md)

## Player-facing goal

After the Paide handoff, Kalev enters an occupation-shaped Act 3 in which the Order can demand his craft, while his records, faction standing, and prior choices determine which forms of survival remain possible. The campaign closes at the attested 1346 sale of the Duchy of Estonia. The player changes human cost, trust, evidence, and the meaning of the forge, not the historical sale itself.

The design reuses the existing Act 2 handoff, `FactionLedger`, forced-forge package, `SaveService`, and `Act3EndingModel`. It does not add a new faction, a universal morality meter, an army simulator, or a second world-map format.

## 1. Occupation state model

The Act 3 opening is keyed by `phase.act3_occupation_day` and consumes the validated `transition.act2_to_act3.paide` record from P5-009/P6-006. The following are gameplay states, not claims that the historical institutions changed in exactly these ways:

| State | Meaning in play | Confidence |
|---|---|---|
| `state.occupation.order_controlled` | Order authority and inspection pressure dominate the player's available routes. | `invented` |
| `state.occupation.negotiated_survival` | Ledger standing and prior records preserve limited civic bargains. | `invented` |
| `state.occupation.hidden_resistance` | Black Cloak, Harju, and Metsik contacts preserve covert routes and evidence. | `invented` |

The historical frame is narrower: the Order's military/political leverage rises after the May 1343 victories, while Danish overlordship and Lower Town civic continuity cannot be flattened into a single instant regime swap. That frame is `attested` and remains in `docs/CANON.md`.

Hard invariants:

- `event.sale_estonia_1346` is the terminal campaign milestone.
- No `morality`, `alignment`, `karma`, `virtue`, `sin`, or `good_evil` aggregate may decide an ending.
- Act 3 may change survivors, faction standing, records, and forge outcomes, but it may not rewrite the attested island milestones or the 1346 sale.

## 2. Forced-forge arc

The existing `package.forced_forge` and `commission.forced_forge` are the design source for the occupation pressure loop. Their content remains runtime/content work for P6-003, but the direction is approved here:

1. **Acquisition:** the Order uses inspection authority to compel Kalev's work; the coercive commission is `invented`.
2. **Investigation:** the player reads the genuine seal, locked search list, soft-pin failure, and concealed channel clues.
3. **Forge choice:** honest work, subtle defect, or secret feature each creates explicit flags and faction events.
4. **Inspection:** the Order may record compliance, discover a load flaw, or miss a concealed message.
5. **Consequence:** the next mission consumes the result through existing faction, journal, save, and ending systems.

The Order's presence is historically grounded as an `attested` political/military pressure; Brother Hermann and the coercive personal commission are a `plausible composite` / `invented` dramatic layer. The package must remain `canon_status: draft` until P6-003 wires and verifies runtime behavior.

## 3. Location list and activation boundary

| Location | Act 3 use | Confidence | Ownership/status |
|---|---|---|---|
| `world_padise` | Two authored phases: the under-construction Cistercian monastery before the sack and the damaged aftermath. | `attested` event and site; phase presentation is authored | P6-002/P6-009; prototype inactive |
| `world_paide` | Paide Castle handoff and continuity anchor from the Four Kings finale. | `attested` | P5-009/P6-006; prototype inactive |
| `world_saaremaa` | Travel and supply corridor for the island campaign. | `plausible composite` | P6-004; prototype inactive |
| `world_poide` | Pöide Castle siege objective after the July 1343 island rising. | `attested` event/site; mission cost is authored | P6-004; prototype inactive |
| `loc.maasilinna_castle` | Post-pacification Maasilinna/Soneburg concept metadata and ending colour. | `attested` historical milestone; playable treatment deferred | P6-001/P6-004; metadata only |

Padise, Paide, Saaremaa, and Pöide keep their existing `DistantLocationDefinitions` and RRMap IDs. This brief does not activate any map or add a parallel scene source. Maasilinna must not be shown as a completed later castle in the 1343 Pöide layout.

## 4. Ending families

`Act3EndingModel` remains the runtime matrix and writes one terminal envelope at the 1346 sale. Each final choice has four authored dimensions:

| Choice | Kalev | Forge | People | Land | Runtime family |
|---|---|---|---|---|---|
| `choice.rebuild_with_the_city` | civic rebuilder | civic hearth | shared ward | remembered roads | `family.rebuild` |
| `choice.serve_the_new_order` | Order survivor | commandeered forge | ordered silence | extracted holdings | `family.occupation` |
| `choice.hide_the_hammer` | hidden maker | buried hammer | hidden network | memory under occupation | `family.survival` |

All four dimensions are `invented` authored outcomes constrained by the `attested` sale and island timeline. They are not a replacement for faction standing: faction rows and district pressure remain explicit components of the terminal envelope.

## 5. Timeline and canon boundary

The design uses the following historical milestones without changing their confidence:

| Milestone | Date | Confidence | Playable boundary |
|---|---|---|---|
| Saaremaa rising and capture of Pöide | 24 July 1343 | `attested` | P6-004 may vary local cost and survivors only |
| Karja campaign and Vesse | February 1344 | `attested` | P6-004 may vary local cost and evidence only |
| Saaremaa pacification and Maasilinna concept | Winter 1345 | `attested` | metadata/aftermath until separately activated |
| Sale of the Duchy of Estonia | 1346 | `attested` | fixed campaign close and ending-envelope trigger |

The design explicitly rejects the legacy 1351 plague epilogue, a wife/daughter hostage branch, a ninth launch faction, tower capture, and a playable Maasilinna map in this task.

## 6. Implementation ownership and verification

| Concern | Existing system/task |
|---|---|
| Paide Act 2 -> Act 3 record | P5-009, P6-006 |
| Occupation transition and map waves | P6-002 |
| Forced-forge content/runtime | P6-003 |
| Pöide/Saaremaa campaign | P6-004 |
| Terminal ending envelope | P6-005 |
| Full campaign traversal and saves | P6-006 |
| Authorial full-campaign gate | P6-007 |
| Padise two-phase scene | P6-009 |

Verification for this design task is the manifest contract test plus the existing Act 3 ending manifest/model contract. Runtime activation and visual/traversal acceptance remain blocked until their owning tasks pass their stated gates.

## 7. Decision record

P6-001 approves the design boundary and canon mapping, not the completion of Act 3 implementation. Every named historical milestone in this report and its manifest carries an explicit confidence label. Any later task that changes a location's activation status, ending family, or historical date must update this manifest and `docs/CANON.md` together.
