# Toompea 1343 landmark and fabric art brief

**Task:** A-012 / R-9
**Historical anchor:** Danish-ruled Toompea, Spring 1343, before the 16 May castle handover
**Primary dossiers:** [`toompea-castle-and-upper-town.md`](../../history/dossiers/architecture/toompea-castle-and-upper-town.md) (R-006, `solid`) and [`toompea-small-castle-interior.md`](../../history/dossiers/architecture/toompea-small-castle-interior.md) (R-035, `solid`)
**Evidence status:** The four PNGs are deterministic Blender studies for non-runtime art direction. They are not archaeological reconstructions, licensed source photographs, or runtime assets.

## 1. Brief ship decisions

These decisions freeze the visual guardrails for the inactive `toompea_quarter` prototype and hand the next implementation work to P4-025a through P4-025d. The art target is the Danish phase in April-May 1343, not the later Order castle or the modern tourist skyline.

1. **Plateau:** Read Toompea as a limestone tableland approximately 400 x 250 m and 20-30 m above Lower Town, with a strong cliff edge on the north, east, and west. The cliff and elevation are the visual separation from All-linn. The exact plateau dimensions are an `attested` source range, while each gameplay camera composition remains a bounded reconstruction.
2. **Castle compound:** Use a low, two-part 13th-century compound: Small Castle in the southwest, Great Castle in the north or centre, and an outer ward tied to the early 14th-century southern and eastern enclosure. The three-part relationship is `attested` in R-006 and R-035. Exact Spring-1343 room sizes and every curtain line are `unknown` or `plausible composite`, so the art must not imply a measured survey.
3. **Danish seat:** The compound reads as *Castrum Danorum*: viceroy, court, garrison, chapel staff, stores, and controlled gates. Use a restrained Danish banner before 16 May. Do not dress the hill as Hanseatic merchant space or apply an Order cross as the April default.
4. **Dome church:** Show Toomkirik as a Gothic enlargement under construction. The choir and vestry may stand, while the three-aisle nave has half-height walls, rectangular pillars in progress, scaffolding, cut stone, and a mason's yard. This construction-site read is a `plausible composite` grounded in the `attested` 1330s-1430s enlargement. Do not show the later baroque spire or a finished tourist silhouette.
5. **Vassal belt:** Surround the Great Castle and cathedral square with compact stone or stone-timber vassal and curia houses. Use high chimneys, sparse openings, yard walls, small service wings, and occasional domestic oratory cues. This settlement type is `attested`; exact house plans, frontage assignments, and dimensions are `plausible composite`.
6. **Hill gates:** Pikk jalg and Lühike jalg terminate in wooden gate structures in 1343. Show steep routes, timber posts, plank leaves, guard shelter, and a timber or earthen barrier. The routes and wooden-gate era are `attested` in R-006/R-035; the exact gate carpentry and guard-house arrangement are `plausible composite`.
7. **Political colour:** April scenes belong to Danish authority under Viceroy Konrad Preen, with bishop and vassal factions visible through banners, household dress, and controlled audience spaces. The 16 May Order handover is a later campaign state. Keep this pack neutral enough for the Danish pre-handover scene and do not pre-stage an Order takeover.
8. **Exclusion lock:** Do not show Pikk Hermann, the Order convent or four-wing cloistered upper ward, the stone Long Leg gate tower, the stone Short Leg gate, the Catherine Palace or baroque east wing, Alexander Nevsky Cathedral, Swedish bastions, or a completed baroque cathedral. Later surviving limestone may inform colour and roughness only, never the 1343 footprint.

## 2. Confidence and production language

| Feature | Confidence | Art consequence |
|---|---|---|
| Toompea plateau, cliff separation, Danish/Lower Town jurisdiction split | **attested** (R-006) | Keep the hill visually and socially distinct from All-linn. Do not flatten the cliff into an ordinary street block. |
| Small Castle / Great Castle / intervening ward division | **attested** (R-035) | Preserve the three-part massing and labelled zones, but leave internal dimensions conservative. |
| Outer-ward southern and eastern enclosure by Spring 1343 | **plausible composite** (R-006) | Use low, incomplete-looking or recently repaired walls rather than a later monumental ring fortress. |
| Danish viceroy residence, audience, chapel, service and muster functions | **attested function; plausible composite rooms** (R-035) | Build a court and garrison read, not a merchant diele or post-1346 convent. |
| Cathedral nave scaffolding and unfinished pillars | **plausible composite** from attested enlargement (R-006/R-035) | Make active construction the dominant square read; leave sky visible over the nave. |
| Vassal and curia stone-timber houses | **attested settlement type; plausible composite individual houses** (R-006) | Use narrow, sober compounds with yards, chimneys and sparse openings. Avoid Lower Town house tiers. |
| Wooden Pikk jalg / Lühike jalg gates and timber barrier | **attested era; plausible composite carpentry** (R-006/R-035) | No masonry gate towers. Timber can be repaired, uneven and defensive without looking like a later stone gatehouse. |

`Attested` means the dossier supports the period, role, or broad type. `Plausible composite` means a restrained production synthesis that must not be presented as a measured 1343 plan. `Unknown` means the generator should stay variable or conservative rather than invent a fixed citywide rule.

## 3. Documentation-only reference plates

All plates are under `docs/reports/images/toompea_1343/`. They are deterministic Blender studies rendered at 1200 x 800 for art review. They must not be copied into `assets/`, loaded by runtime scenes, or registered in `assets/SOURCES.csv`.

| Plate | Shows | R-006 / R-035 question answered | Read and exclusions |
|---|---|---|---|
| [`reference_castle_compound.png`](images/toompea_1343/reference_castle_compound.png) | Small Castle, Great Castle, cingele, outer ward, low early towers and eastern gate | Can the Danish compound read as two castle zones plus an outer ward without a later Order skyline? | Low limestone massing, open forecourt, subordinate towers and Danish banner. No Pikk Hermann, Order convent or complete tourist ring. |
| [`reference_cathedral_construction.png`](images/toompea_1343/reference_cathedral_construction.png) | Standing choir and vestry, open nave, rectangular pillars, scaffold, cut stone and mason's bench | Does the cathedral square read as the 1343 construction phase rather than a completed cathedral? | Active worksite with sky over the nave. No baroque spire, finished nave vault, or later fittings. |
| [`reference_wooden_hill_gate.png`](images/toompea_1343/reference_wooden_hill_gate.png) | Steep hill ascent, timber gate posts, plank leaves, guard shelter, palisade and Danish banner | Can Pikk jalg / Lühike jalg be controlled without importing the 1380 stone gate tower? | Timber and earth only. The plate is a gate-era and route-control study, not a measured gate plan. |
| [`reference_vassal_house.png`](images/toompea_1343/reference_vassal_house.png) | Stone lower storey, timber upper storey, steep roof, high chimney, oratory, plot wall, service wing and well | Does the hill house read as vassal/curia fabric rather than a Lower Town merchant diele-dornse? | Sparse openings, sober compound and service yard. No merchant hoist, repeated Gothic window wall, or landmark scale. |

## 4. Shared art rules

### Castle and cliff

- Keep the cliff edge legible in broad views and retain a visibly higher plateau than Lower Town.
- Use cool grey local limestone with damp lower courses, repaired joints and modest timber roofs. Later Order ashlar is a material cue only.
- Keep the Small Castle southwest, Great Castle north or central, and outer ward south/east. Do not merge them into one generic keep.
- Use low early towers only as subordinate anchors. A single tall skyline tower is an anachronism for this brief.
- The eastern outer-ward gate controls the upper end of the hill-route chain. It may be reconstructed in timber, but must not become a stone gatehouse.

### Cathedral construction site

- The choir and vestry can feel established; the nave must feel incomplete.
- Rectangular pillars, half-walls, scaffold rails, cut stone and a mason's work area should be readable at gameplay scale.
- Scaffolding is working infrastructure, not decorative Gothic ornament. Use rough timber, uneven platforms and material piles.
- Keep the silhouette low and open above the nave. Reject baroque spires, completed vaults and modern roof profiles.

### Hill gates and boundary

- Wooden Pikk jalg and Lühike jalg gates should use plank leaves, heavy posts, simple lintels and guard shelter.
- The routes can differ in grade: Pikk jalg is the longer, gentler approach; Lühike jalg is shorter and steeper. Do not imply that either had a 1380 masonry tower.
- The Lower Town-facing barrier is timber and earth for this date. The 1454-1455 masonry curtain is excluded.
- Gate closure is a curfew and jurisdiction hook, not permission to add an invented toll booth.

### Vassal and curia fabric

- Make houses narrower and more private than Lower Town merchant fronts, with high chimneys, few street-facing openings, plot walls and small service wings.
- Stone lower levels with timber upper work are a safe restrained composite. Roofs should be steep and dark, without a universal late-Gothic finish.
- A small oratory or chapel cue is acceptable as a quiet plot feature, but do not turn every house into a church.
- Do not apply `merchant_stone`, `merchant_timber`, or `craft_boda` as if the hill belt were ordinary Lower Town frontage. Those tiers belong to the separate A-008 brief.

## 5. Handoff and non-runtime boundary

This pack is an art-direction input, not a runtime asset delivery. The PNGs remain documentation evidence under `docs/reports/images/toompea_1343/`; no row is added to `assets/SOURCES.csv`, and no scene or mesh-builder loads them.

Downstream handoff:

- **P4-025a:** replace the current stone hill-gate tower read with wooden Pikk jalg / Lühike jalg gate structures and timber/earthen boundary cues.
- **P4-025b:** correct `toompea_quarter` castle massing toward Danish Small Castle, Great Castle, intervening ward and outer ward; remove Pikk Hermann and Order-convent silhouettes.
- **P4-025c:** stage the Dome church as an active Gothic nave construction site with scaffolding and cut-stone yard; reject the completed/baroque silhouette.
- **P4-025d:** add the vassal/curia stone-timber fabric and jurisdiction-aware Danish hill dressing without converting it into Lower Town merchant frontage.
- **P4-025e:** independently verify the four map/art corrections at gameplay scale, including the exclusion list and day/night readability.
- **P4-039:** use R-035 labelled Small Castle zones for the later Danish interior prototype; do not back-project the post-1346 four-wing Order plan.
- **P4-040 / P4-041:** carry the wooden-gate curfew, Danish pre-handover banners and 16 May Order transition into jurisdiction and narrative review.

## 6. Review checklist

- [x] Brief cites the `solid` R-006 and R-035 dossiers and preserves their `attested`, `plausible composite`, and `unknown` boundaries.
- [x] Ship decisions 1-8 are explicit and include the Danish compound, cathedral construction site, vassal belt, wooden gates, political colour and exclusion lock.
- [x] At least one non-runtime plate exists for the castle compound, cathedral construction, wooden hill gate, and vassal house.
- [x] Castle plate omits Pikk Hermann, Order convent massing, Catherine/baroque east wing and a completed Order skyline.
- [x] Cathedral plate shows scaffolding, open nave work, rectangular pillars in progress and cut-stone activity without a baroque spire.
- [x] Gate plate uses timber and earth, not the 1380 stone Long Leg tower or later masonry curtain.
- [x] Vassal plate is stone-timber, sparse and yard-based, distinct from Lower Town diele-dornse merchant fabric.
- [x] PNGs are documentation-only and are not registered as runtime assets.
- [ ] P4-025a-d map corrections and P4-025e acceptance remain downstream work.

## Sources

1. [`toompea-castle-and-upper-town.md`](../../history/dossiers/architecture/toompea-castle-and-upper-town.md) - R-006, especially Brief ship decisions 1-8, castle phases, cathedral construction, vassal belt, wooden gates, exclusions and confidence table.
2. [`toompea-small-castle-interior.md`](../../history/dossiers/architecture/toompea-small-castle-interior.md) - R-035, especially labelled Small Castle / Great Castle / outer-bailey zones, Danish interior boundary and post-1346 exclusions.
3. [`docs/ROADMAP.md`](../ROADMAP.md) - Toompea / R-006 coordination note and downstream order P0-165 -> A-012 -> P4-025a-d -> P4-025e.
4. [`docs/reports/burgher_house_art_brief.md`](burgher_house_art_brief.md) - separate Lower Town house-tier boundary used to keep vassal/curia fabric distinct from diele-dornse merchant studies.
