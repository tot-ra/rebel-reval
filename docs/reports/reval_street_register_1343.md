# Reval street, lane and open-space register - spring 1343

Status: **research delivered, pending Canon Keeper sign-off** (task **R-1111** / UF-02, contract [`docs/tasks/urban_form/UF-02_street_register.md`](../tasks/urban_form/UF-02_street_register.md)).
Machine-readable contract: [`docs/data/reval_street_register.json`](../data/reval_street_register.json) (`schema_version` 1, `as_of` `spring-1343`).

Scope: every way, square edge and bounded open space that map authors may draw in Reval (Lower Town, the Toompea ascents and the two gate approach roads), with a dated name verdict, a 1343 route verdict, an owning map and the conflicts in current `.rrmap` geometry.
Out of scope: street geometry (UF-03 primitive, UF-05..UF-07 authoring), frontage binding (UF-04), landmark placement (UF-09), hinterland roads beyond the current gate-side map (UF-14 / UF-15). This register edits no `.rrmap`, code or asset.

## Decision brief

1. **Names are almost all later than April 1343.** Only Olevimägi (*Zantberg* 1337) and Rataskaevu (*rader strate* 1325) carry a pre-1343 year, and both come from secondary syntheses without a reviewed folio, so both stay `unverified`. No row is `by_1343`. Dialogue and UI should use functional descriptions (`name_1343`) and keep modern names for authors only. This repeats the [street-plan dossier](../../history/dossiers/topography/lower-town-street-plan.md) and [`docs/CANON.md`](../CANON.md) practice.
2. **Routes are older than their names.** The surviving 13th-14th-century street and plot skeleton (H01, H02) supports the direction and adjacency of every spine. Three routes reach `attested`, each from dated fabric:
   - the forum's Town Hall edge (hall recorded 1322, H06)
   - Niguliste (13th-century gravel street layer, AVE 2022)
   - the Karja gate end (early rubble/pebble road, H10)
3. **The forum is an open space, not a street.** `space.forum` (attested 1313) has four walkable square edges. The Viru/Vene convergence is a bounded junction (`space.viru_vene_junction`), not the later *forum inferior* (1368).
4. **Current maps contradict the register in nine places.** See [Present-map census](#present-map-census). The two most visible errors:
   - Lai is drawn **east** of Pikk on both northern maps. It runs west of Pikk, toward the western curtain.
   - Pikk is discontinuous across the market / monastery seam.
5. **Harju has no gate on any map.** The Harju street and its extramural road are registered as `not_authored` under `south_quarter`, which owns the south curtain.

## Source register

IDs below are the only valid `source_ids` in the JSON. H-codes reuse the signed [P0-072 source register](../HISTORICAL_AUDIT.md#source-register); dossier rows point to the project research that already cites the primary material.

| ID | Source | Used for | Limits |
|---|---|---|---|
| `SRC-PALL2009` | Päll, P., "Names in Multi-Lingual, -Cultural and -Ethnic Contact", Proc. 23rd ICOS, York University, 2009 | Dated first attestations: Harju *smedestrate* 1362, Viru *leymstrate* 1362, Karja *Kariestrate* 1365, Kuninga *schostrate* 1374, Lühike jalg *parvus mons* 1371, Nunne *susterstrate* 1361, Olevimägi *Zantberg* 1337, Lai 1547+, Vene 1732+ | Onomastic survey; folios not reviewed here, so pre-1343 years stay `unverified` |
| `SRC-SGABRIEL` | Lucas, R., "Street names from Tallinn, Tartu and Pärnu", S-Gabriel, 2020, https://www.s-gabriel.org/names/ffride/eestreets.html | MLG/Latin forms, *dummestrate* 1328, *velud itur ad monachos* 1363 | Secondary compilation of Päll and archive forms |
| `SRC-AWB302` | Alter Wirtbuch entry 302, *platea dicta dummestrate*, as cited in the [Pikk/Lai frontage dossier](../../history/dossiers/topography/pikk-lai-frontage-materials-1340s.md) | Pre-1343 existence of a *dummestrate* | Entry not re-read for this register; its identification with Rataskaevu is a secondary claim |
| `SRC-AWB497` | Alter Wirtbuch entry 497, *platea fabrorum in opposito domini Hunoldi de Ostinchusen*, as cited in the same dossier | A pre-1343 "smiths' street" | Not identified with Harju by any reviewed source |
| `SRC-KUUSKEMAA2024` | Kuuskemaa, J., "Rataskaevust Kassikaevuks", Postimees, 2024, https://arvamus.postimees.ee/7993047/ | Rataskaevu *rader strate* 1325, *sub monte* | Popular synthesis, no folio; **B/C** per the shared R-1009 label |
| `SRC-AVE2010-KARJA` | Nurk et al., Karja Gate archaeology, AVE 2010 (H10) | Early rubble/pebble road below later slabs, coastal relief, road-aligned suburb | Karja name 1365; 1343 superstructure uncertain |
| `SRC-AVE2016-VIRU` | Kraut and Nurk, Viru / Vana Turg / Kuninga archaeology, AVE 2016/17, `history/AVE2016_17_KRAUT-NURK_Tln-Viru-tn.pdf` (H09) | Mid-14th-century Viru gate and moat, plank on moat fill, Kuninga slab hints, humus layers on inner Viru | Gate possibly under construction in 1343; timber pipes and barbicans later |
| `SRC-AVE2019-COASTAL` | Reppo and Kadakas, Great Coastal Gate, AVE 2019, `history/AVE2019_15_Reppo-Kadakas.pdf` (H11) | Gate on a 5-8 m cliff, probable 1311-1340 tower, slab-lined rainwater channel | Gate name 1359; barbican date unresolved |
| `SRC-AVE2022-NIGULISTE` | AVE 2022 Niguliste Street excavation, cited as [15] in the [street-plan dossier](../../history/dossiers/topography/lower-town-street-plan.md) | 13th-century gravel street layer and slope on Niguliste | Plate/page number not yet recorded; no width |
| `SRC-H04` | Medieval Heritage, "Tallinn residential buildings" (H04) | Irregular streets, limestone/erratic/timber paving, 7-11 m strip plots | Synthesis including later fabric |
| `SRC-H05` | Heinloo, NUKU courtyard archaeology, AVE 2013 (H05) | Mid-14th-century timber auxiliary buildings on the Lai quarter | One quarter only |
| `SRC-H06` | Tallinn Town Hall building history (H06) | Hall recorded 1322; tower and full length later | 1343 facade partly reconstructed |
| `SRC-H07` | Medieval Heritage, Holy Spirit Church (H07) | Chapel and almshouse by 1316 | Present church mass later |
| `SRC-H13` | Medieval Heritage, Cathedral of the Virgin Mary (H13) | Cathedral close on Toompea | 1343 is a construction state |
| `SRC-H14` | Medieval Heritage, St Olaf's Church (H14) | Church 1267, vaults 1330, northern settlement incorporated | 15th-century basilica excluded |
| `SRC-H15` | Medieval Heritage, Dominican Friary of St Catherine (H15) | Precinct from 1246 | Later enlargements excluded |
| `SRC-H22` | Uus and Uus, *Traditional Log Building in Estonia* (H22) | Context check that "Uus" in the audit names authors | Not street evidence |
| `SRC-H31` | Medieval Heritage, St Nicholas, Tallinn (H31) | Hall church, north porch first half 14th century | 15th-century choir excluded |
| `SRC-H32` | Medieval Heritage, St Michael's Cistercian nunnery (H32) | Convent on the western belt, 1340s wall tie-in, Nuns' Gate name 1355 | URL returned 404 on 2026-09-27 |
| `SRC-POSTIMEES-MARKET` | Postimees, "Turud on tegutsenud ilmakorrast hoolimata", https://www.postimees.ee/1777651/ | *forum* 1313, *forum inferior* 1368 | Popular synthesis |
| `SRC-ETWIKI-VANATURUKAEL` | Estonian Wikipedia, "Vanaturu kael" | Neck geography and modern name | Tertiary; used for geography only |
| `SRC-TOWNHALL` | Tallinn Town Hall, "The building", https://raekoda.tallinn.ee/en/the-building/ | 1322 hall on the market's south side | Later tower and arcade excluded |
| `DOS-LTSP` | [Lower Town street plan dossier](../../history/dossiers/topography/lower-town-street-plan.md) (R-002) | Name table, Blocks A-C widths, surfaces | Its own open questions on Pikk/Lai names and widths |
| `DOS-OLDMARKET` | [Old market / Vanaturu kael dossier](../../history/dossiers/topography/old-market-vanaturg.md) (R-031) | 4-6 m neck, 10-14 m junction, absences | Corridor vertices are composite |
| `DOS-RAEKODA` | [Raekoja plats extents dossier](../../history/dossiers/topography/raekoja-plats-extents-1343.md) (R-029) | Forum polygon and edges, 1343 hall length | Polygon is composite ±2 m |
| `DOS-BACKLANES` | [Back lanes east of Pikk dossier](../../history/dossiers/topography/back-lanes-east-of-pikk.md) (R-032) | Müürivahe, Vene, Katariina käik widths and surfaces | Places Rataskaevu north of the market (disputed below) |
| `DOS-VIRUPAVE` | [Viru / Vana turg paving dossier](../../history/dossiers/topography/viru-vanaturg-paving-archaeology.md) | Zone surfaces from AVE 2016/17 | No continuous slab edge |
| `DOS-PIKKLAI` | [Pikk/Lai frontage materials dossier](../../history/dossiers/topography/pikk-lai-frontage-materials-1340s.md) (R-030) | Timber/stone front bands per spine block | No house-by-house cadastre |
| `DOS-WALLS` | [Walls, gates and towers dossier](../../history/dossiers/topography/walls-gates-towers.md) (H33) | Eight-gate scheme, gate names and states | Not a day-exact completion state |
| `DOS-TOOMPEA` | [Toompea castle and Upper Town dossier](../../history/dossiers/architecture/toompea-castle-and-upper-town.md) (R-006) | Pikk jalg / Lühike jalg as wooden-gated ascents | No measured 1343 widths |
| `DOS-KARJAGATE` | [Karja gate leaf state dossier](../../history/dossiers/topography/karja-gate-leaf-state-1343.md) | Gate present as composite; leaf state unknown | Leaf fields null |
| `DOS-SQFC` | [South Quarter 1343 fabric contract](south_quarter_1343_fabric_contract.md) | Lane bands, Rataskaev uncertainty labels | Gameplay contract |
| `DOS-HARBOUR` | [Harbour and shoreline dossier](../../history/dossiers/topography/harbour-and-shoreline.md) (R-005) | Coastal Gate descent to the landing | Shoreline moved since 1343 |
| `DOS-HARJU-HINTER` | [Harju rebel camp and Pirita approach dossier](../../history/dossiers/hinterland/harju-rebel-camp-and-pirita-approach-1343.md) | Viru - Iru - Pirita corridor as the eastern approach | Corridor, not a surveyed road |
| `DOS-BATHS` | [Public bath locations dossier](../../history/dossiers/topography/public-bath-locations-1343.md) | Rataskaevu 1325 B/C, Dunkri / Cat's Well anchor U | Bath POI low confidence |

## Evidence cards

One line per JSON row. Name = `name_attestation.status` and year; Route = `route_1343`; Conf = `confidence` / `evidence_class`; State = `map_state`. The JSON carries the full trace, width, surface, drainage and frontage.

| Way ID | Owning map | Name | Route | Conf | State | Reasoning |
|---|---|---|---|---|---|---|
| `street.apteegi` | market_civic_quarter | post 1363 | composite | PC / B | partial | Lane to the friars from the market side; name 1363 |
| `street.coastal_gate_descent` | reval_harbor_north | post 1359 (gate) | composite | PC / B | partial | Cliff descent and slab channel attested at the gate (H11). The road surface is unknown |
| `street.dunkri` | market_civic_quarter | unverified | composite | PC / B | partial | West from the forum to the hill foot. Duplicate N-S `dunkri_lane` on south_quarter |
| `street.forum_east_edge` | market_civic_quarter | unverified | composite | PC / B | partial | Edge into the neck |
| `street.forum_north_edge` | market_civic_quarter | unverified | composite | PC / B | partial | Holy Spirit complex by 1316 on this edge |
| `street.forum_south_edge` | market_civic_quarter | unverified | **attested** | A | partial | Town Hall recorded 1322 closes the south edge |
| `street.forum_west_edge` | market_civic_quarter | unverified | composite | PC / B | partial | Dunkri and Kullassepa mouths |
| `street.harju` | south_quarter | post 1362 | composite | PC / B | not_authored | Smiths' street to the Harju Gate (mentioned 1361). AWB 497 *platea fabrorum* is a possible earlier form, identification unreviewed |
| `street.harju_road_extramural` | south_quarter → planned `harju_approach_road` | unverified | composite | PC / B | not_authored | Ends at the south_quarter boundary. Its continuation belongs to UF-15 |
| `street.karja_lower_town_slice` | lower_town_slice | post 1365 | composite | PC / B | **contradicts** | Branches mid-Viru instead of at the market junction. Renamed `viru_internal_lane` across the seam |
| `street.karja_market` | market_civic_quarter | post 1365 | composite | PC / B | **contradicts** | Enters south_quarter where Dunkri/Kuninga start, so Karja does not continue |
| `street.karja_south_quarter` | south_quarter | post 1365 | **attested** | A | **contradicts** | H10 road at the gate. Fed from the wrong seam |
| `street.katariina_kaik` | lower_town_slice | unverified | composite | PC / B | partial | Passage on the Dominican west range, 2-3 m |
| `street.kullassepa` | market_civic_quarter | unverified | composite | PC / C | **contradicts** | Drawn west to the Toompea seam. It should go south-west to St Nicholas'. The goldsmith name is reused on north_quarter |
| `street.kuninga_market` | market_civic_quarter | post 1374 | composite | PC / B | partial | Built frontage, partial slab hints (H09) |
| `street.kuninga_south_quarter` | south_quarter | post 1374 | composite | PC / B | partial | Continuation toward St Nicholas' |
| `street.lai_monastery` | monastery_quarter | post 1547 | composite | PC / B | **contradicts** | Drawn east of Pikk |
| `street.lai_north` | north_quarter | post 1547 | composite | PC / B | **contradicts** | Drawn east of Pikk |
| `street.lossi_plats` | toompea_quarter | unverified | composite | PC / D | partial | Castle forecourt approach. Modern name |
| `street.luhike_jalg` | toompea_quarter | post 1371 | composite | PC / B | partial | Steep ascent with a wooden gate; foot at the Dunkri/Rataskaevu belt |
| `street.muurivahe` | lower_town_slice | unverified | composite | PC / B | partial | Wall lane 4-6 m. Intermittent where the 1340s curtain is unfinished |
| `street.niguliste` | south_quarter | unverified | **attested** | A | partial | 13th-century gravel layer. The map uses dirt, so its surface should become gravel |
| `street.nunne` | monastery_quarter | post 1361 | composite | PC / B | not_authored | Convent-side lane to the Nuns' Gate opening |
| `street.olevimagi` | monastery_quarter | unverified 1337 | composite | PC / B | not_authored | *Zantberg* via Päll, folio unreviewed |
| `street.pikk_jalg` | toompea_quarter | unverified | composite | PC / B | **contradicts** | Foot delivered to the convent edge, not the south end of Pikk |
| `street.pikk_market` | market_civic_quarter | unverified | composite | PC / B | partial | 4 cells (~3.5 m) against a 4-6 m band |
| `street.pikk_monastery` | monastery_quarter | unverified | composite | PC / B | **contradicts** | Market seam lands on `civic_lane`, about 62 cells from `pikk_spine` |
| `street.pikk_north` | north_quarter | unverified | composite | PC / B | matches | Continuous to the Coastal Gate at 5 cells (~4.4 m) |
| `street.puhavaimu` | market_civic_quarter | unverified | composite | PC / B | partial | Forum to Pikk past the Holy Spirit house |
| `street.rataskaevu` | south_quarter | unverified 1325 | composite | PC / C | partial | *rader strate* is B/C. The 1343 well anchor is U and the 1375 Cat's Well is excluded |
| `street.toom_kooli` | toompea_quarter | unverified | **invented** | invented / D | partial | Designed connection across the cathedral close |
| `street.vanaturu_kael` | market_civic_quarter | unverified | composite | PC / B | matches | 5-cell throat inside the 4-6 m band; no second square |
| `street.vene_lower_town_slice` | lower_town_slice | post 1732 | composite | PC / B | partial | Only an anchor, no stroke |
| `street.vene_monastery` | monastery_quarter | post 1732 | composite | PC / B | **contradicts** | U-loop instead of a through-route to St Olaf's |
| `street.viru` | lower_town_slice | post 1362 | composite | PC / B | partial | 3 cells against a 5-7 m band. The gate is possibly unfinished |
| `street.viru_road_extramural` | viru_gate_foreland → planned `viru_approach_road` | unverified | composite | PC / B | partial | Viru - Iru - Pirita corridor; the bridge is uncertain |

Open spaces: `space.forum` (attested / A, 1313 *forum*; smaller than the modern plaza, Town Hall south edge, no arcade or tower), `space.viru_vene_junction` (plausible composite / B, 10-14 m crossroads, not a market).

### Minimum candidates, one by one

| Candidate | Verdict |
|---|---|
| Pikk | Registered in three segments; route composite, name unattested in the 14th century |
| Lai | Registered in two segments; name 1547+. Current maps place it on the wrong side of Pikk |
| Vene | Registered in two segments; quarter identity composite, name 1732+ |
| Olevimägi | Registered; *Zantberg* 1337 `unverified`; not authored |
| Pühavaimu | Registered; name undated |
| Rataskaevu | Registered; 1325 B/C, kept `unverified` per R-1009 |
| Dunkri | Registered west of the forum; south_quarter duplicate is a conflict |
| Niguliste | Registered; route attested by 13th-century gravel |
| Kuninga | Registered in two segments; name 1374 |
| Rüütli | **Excluded**: no reviewed source |
| Harju | Registered; name 1362, not authored |
| Müürivahe | Registered; function composite |
| Suur-Karja | Registered in three segments; name 1365, gate road attested |
| Väike-Karja | **Excluded**: no reviewed source |
| Viru | Registered; name 1362 |
| Vanaturg / Raekoja plats | `space.forum` plus four edges; `street.vanaturu_kael`; Vana turg as a market **excluded** |
| Pikk jalg | Registered; name undated, route composite |
| Lühike jalg | Registered; name 1371 |
| Harju approach road | Registered, `not_authored`, planned `harju_approach_road` |
| Viru approach road | Registered on viru_gate_foreland, planned `viru_approach_road` |
| Uus | **Excluded**: audit tokens are the H22 authors |
| Kullassepa, Apteegi, Katariina käik, Nunne, Lossi plats, Toom-Kooli | Added because `.rrmap` comments or strokes use them |
| Kinga | **Excluded**: `kinga_passage` stroke has no source |

Generic stroke IDs (`guild_lane`, `convent_lane`, `harbor_lane`, `east_work_lane`, `rear_service_lane`, `pikk_lai_cross_lane`, `intramural_wall_lane`, the harbour and foreland tracks, Toompea cathedral lanes) are not street names. They are game service lanes (**D**) for UF-04 / UF-05 to keep, re-route or delete.

## Present-map census

Inventory commands from the contract (`rg` over `content/maps/*.rrmap` and `docs/HISTORICAL_AUDIT.md`) were run on 2026-10-07. Contradictions, each recorded in the JSON `map_conflicts`:

1. **Lai east of Pikk** - `monastery_quarter` `lai_lane` x 135 vs `pikk_spine` x 101, `north_quarter` `lai_lane` x 138 vs `pikk_spine` x 104. Lai belongs between Pikk and the western curtain, where the same maps already place the Nunnatorn and Kuldjala towers.
2. **Pikk broken at the market seam** - market `to_reval_north` (x 34-44) lands on monastery `civic_lane`, which turns ~62 cells east before it meets Pikk.
3. **Pikk jalg foot on the convent edge** - toompea `to_reval_north` delivers to monastery x 0 (`convent_lane`), not to the south end of Pikk by the Holy Spirit.
4. **Vene as a loop** - monastery `vene_lane` leaves and re-enters the south seam.
5. **Karja split three ways** - market `street.karja_south` enters south_quarter at `dunkri_lane` / `king_street`, while the south_quarter Karja is fed by `viru_internal_lane` from lower_town_slice `road.karja`, which itself branches mid-Viru.
6. **Two Dunkris** - market `street.dunkri_approach` (west, plausible) and south_quarter `dunkri_lane` (north-south).
7. **Kullassepa to the wrong seam** - market `street.kullassepa_approach` ends on the same Toompea-seam cell as Dunkri. North_quarter `goldsmith_lane` reuses the name.
8. **Niguliste surface** - `niguliste_lane` is dirt; the excavated 13th-century layer is gravel. This is recorded as partial, not as a contradiction.
9. **Rataskaevu placement dispute** - the back-lanes dossier calls Rataskaevu rear access "north of the market for Pikk Block A". That conflicts with the *sub monte* (under the hill) form and with the south-quarter contract. The register follows *sub monte* and leaves this for Canon review.

Not authored anywhere: Harju street and Harju Gate, the Harju approach road, Olevimägi, Nunne. No map draws Müürivahe, Vene (slice) or Katariina käik as a stroke; they exist only as anchors and house IDs.

Several of these are seam problems already tracked by the UF-08 gate (R-1117, R-1166, R-1182). This register supplies the historical target those fixes should converge on; it does not change their grace entries.

## Phase exclusions

- 1375 Cat's Well rebuild, its folklore, and any claim that the 1343 well sits at the Dunkri corner (**U**).
- *forum inferior* (1368) and *dat olde market* (1442) as a second square; Peppersack (1420-1460); Pakkhoone (1655); a stone staple warehouse before the 1346 staple right.
- Town Hall tower, arcade and full 1371-74 length; Holy Spirit's later church mass.
- Viru round foregate towers (~1370), Karja/Harju barbicans (1448-1461), Coastal Gate barbican (1430), Fat Margaret (1520s), the 1454-1455 masonry hill wall and any stone hill-gate tower.
- Blanket cobble, 19th-20th-century timber water pipes and vaulted collectors, the 2016 granite scheme.
- Street names quoted as April 1343 speech: Karja (1365), Harju and Viru (1362), Kuninga (1374), Lühike jalg (1371), Nunne (1361), Apteegi (1363), Lai (1547), Vene (1732).

## Open questions and hand-off

- **Canon Keeper (sign-off required):** confirm the `unverified` status of *Zantberg* 1337 and *rader strate* 1325; settle the Rataskaevu placement dispute; decide whether AWB 302 / 497 should be re-read to test the *dummestrate* = Rataskaevu and *platea fabrorum* = Harju identifications.
- **Research:** record the AVE 2022 Niguliste plate/page; look for any dated width at Viru × forum or Pikk × Coastal Gate.
- **Map (UF-05 / UF-06 / UF-07):** fix contradictions 1-7 when the street primitive lands (UF-03, gated by ADR 0026 acceptance). Swap Lai to the west of Pikk without renaming stable IDs, and join Pikk across the market seam.
- **UF-14 / UF-15:** the Harju gate road leaves the south curtain, while `world.harju` is reached today from `viru_gate_foreland`. The project's own dossier treats the Viru - Iru - Pirita line as the main approach to the Harju region, so this is not a contradiction. The ADR 0027 census should still say which gate owns the `harju_approach_road` endpoint.

## Cross-links

[P0-072 target cards](../HISTORICAL_AUDIT.md#p0-072-1343-reval-environment-target-dossier) (H01-H11 used above), [South Quarter fabric contract](south_quarter_1343_fabric_contract.md#rataskaev-well-uncertainty), [`history/RESEARCH_INDEX.md`](../../history/RESEARCH_INDEX.md), [urban form pack](../tasks/urban_form/README.md), [ADR 0026 (proposed)](../adr/0026-streets-as-authored-network.md).

## Verification

```bash
python3 -m json.tool docs/data/reval_street_register.json >/dev/null
python3 tools/generate_active_docs_report.py --check
python3 tools/archive_speculative_docs.py --dry-run
git diff --check
```

The full field/type/enum review and `source_ids` resolution against the table above were run with a one-off checker during delivery (36 ways, 2 open spaces, 5 exclusions, zero errors). A permanent validator belongs to a later authorised row.
