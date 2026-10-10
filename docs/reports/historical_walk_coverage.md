# Historical walk coverage ledger

Status: living ledger, updated by each historical-plausibility playtest walk.

One row per location of the ADR 0031 seamless Reval city (`content/world/reval_city/plan.json` districts and ADR 0032 landmark sites) and its hinterland. Each walk picks the least recently visited or lowest rated rows first so that no area is richly detailed while another stays empty. Findings go to the task board (`tasks` tool, tag `#historical-walk`), never into this file as a backlog.

Ratings are 1-5 against the best-developed location (the bar): **A** architecture, **P** props, **V** vegetation and terrain, **L** people and life, **S** audio and ambience. "-" means not yet rated; from 2026-10-09 on, **S** stays "-" until someone actually listens in the running game (screenshots cannot rate sound), and **Avg** is over the rated columns only.

Captures: `docs/reports/images/historical_walk/`, produced with two scratch scripts. Static views extend `tools/capture_reval_city.gd` and override `_shots()` (`tools/godot_render.sh --script ... -- --out=res://build/<dir>`, day progress 0.42). That tool does not stream fauna, fences, forbs or citizens around the camera, so every walk also takes gameplay-camera shots from the live scene (`scenes/world/reval_city/reval_city.tscn` in a host `.tscn`, teleport `city.player`, wait about 6 s for streaming, then save the viewport), as `tools/capture_reval_city_walk.gd` does. Do not rate life or props from static views alone.

## Ledger

| Location | Plan id | Last visited | A | P | V | L | S | Avg | Open tasks |
|----------|---------|--------------|---|---|---|---|---|-----|------------|
| Toompea plateau and Danish castle | `district.toompea` | 2026-10-09 | 2 | 1 | 2 | 1 | 2 | 1.6 | R-1462, R-1463, R-1464, R-1465, R-1466, R-1470, R-1471; legacy-targeted R-1128, R-967, R-293 |
| Kalarand fishing shore | `district.kalarand` | 2026-10-09 | 2 | 2 | 2 | 1 | 2 | 1.8 | R-1467, R-1468, R-1469, R-1470; R-1347 (LIFE-4 fishers) |
| Lower Town streets and forum (bar, provisional) | `district.lower_town`, `poi.forum` | not walked (rated from 2026-10-07/08 captures in `images/city/`) | 4 | 2 | 3 | 2 | 2 | 2.6 | R-1465 (shingle roofs) |
| Town Hall square | `site.raekoja_plats` | - | - | - | - | - | - | - | |
| Holy Spirit church and almshouse | `site.holy_spirit` | - | - | - | - | - | - | - | |
| St Olaf's | `site.st_olaf` | - | - | - | - | - | - | - | |
| St Nicholas' | `site.st_nicholas` | - | - | - | - | - | - | - | |
| St Mary's (Dome church building site) | `site.st_mary` | seen from Toompea 2026-10-09 | - | - | - | - | - | - | |
| Harbour and Coastal Gate | `harbour`, `gate.coastal` | 2026-10-10 | 3 | 2 | 1 | 2 | - | 2.0 | R-1542, R-1543, R-1465, R-1470; legacy-targeted R-206, R-208, R-298 |
| Viru road suburb | `district.viru` | 2026-10-09 | 2 | 1 | 2 | 2 | - | 1.8 | R-1504, R-1545, R-1434, R-1470 |
| Cattle-road farmsteads | `district.karja` | 2026-10-10 | 2 | 1 | 2 | 2 | - | 1.8 | R-1544, R-1545, R-1546, R-1465, R-1434, R-1323 |
| Harju-road houses | `district.harju` | 2026-10-10 | 2 | 1 | 2 | 2 | - | 1.8 | R-1594, R-1592, R-1465, R-1434, R-1545, R-1323 |
| Vassal yards below the castle | `district.toompea_foot` | 2026-10-09 | 2 | 2 | 1 | 2 | - | 1.8 | R-1503, R-1545, R-1434, R-1470 |
| Hinterland fields, pastures and woods | `fields`, `pastures`, `woods` | 2026-10-10 | - | 2 | 2 | 2 | - | 2.0 | R-1591, R-1592, R-1593, R-1595, R-1596, R-1544 |

## Walk log

### 2026-10-09 - Toompea and Kalarand

Captures: `toompea_castle_aerial`, `toompea_castle_forecourt`, `toompea_kohtu_street`, `toompea_toom_ruutli`, `toompea_overview_n`, `toompea_short_hill_gate`, `kalarand_aerial`, `kalarand_beach`, `kalarand_village`, `kalarand_boatwright`, `kalarand_from_sea` (all `.jpg` in `images/historical_walk/`).

**Toompea.** Dense stone vassal houses and the Dome church building site with scaffolding fit the dossier (`history/dossiers/architecture/toompea-castle-and-upper-town.md`). Biggest breaks: the Danish castle bailey is empty grass (R-1462); every Toompea wall segment is a 5 m crenellated stone curtain although the masonry barrier toward the Lower Town is attested only for 1454-1455 (R-1463); the wall-walk roof floats on slopes (R-1464); shingle roofs read as green camouflage (R-1465, city-wide); streets carry no props, yard walls or people (R-1466). Audio is the music theme only (R-1470). Idea: the Lower Town watch shuts the wooden hill gates at night (R-1471). Older castle and curiae tasks (R-1128, R-967, R-293) point at the retired `toompea_quarter.rrmap`; R-1128 now carries a retarget note.

**Kalarand.** Net yards, clinker boats and the beach fit `history/dossiers/topography/kalamaja-fishing-shore-1343.md`. Biggest breaks: the sea ends about 52 m offshore, so the bay reads as a canal with a green plain beyond (R-1468); 24 identical huts on a lawn instead of a few huts with smoke and salt sheds, splitting tables and fish racks (R-1467); the boatwright yard is untextured primitives (R-1469).

**Consistency gap.** The Lower Town and its five landmark sites have bespoke builders, interiors and citizens. Toompea, the second political pole of the story, has generic house shells, an empty castle and no street life, and the outer districts (Kalarand, Viru, Karja, Harju) are uniform log-and-thatch huts on lawn. Next walks: Viru road suburb and Vassal yards below the castle (not yet visited), then the Harbour.

### 2026-10-09 - Viru road suburb and Vassal yards below the castle (backfilled 2026-10-10)

Captures: `hw2_viru_overview`, `hw2_viru_road`, `hw2_viru_yard`, `hw2_viru_runtime`, `hw2_foot_overview`, `hw2_foot_road`, `hw2_foot_yard`, `hw2_foot_runtime`, `hw2_lower_town_bar`, `hw2_bar_runtime`. This walk filed its tasks but did not update the ledger or commit the captures; the 2026-10-10 walk added both.

**Viru.** 21 houses on a road through lawn and scattered trees, no service outbuildings (Toompea foot has 38). Census has carpenter, carter and gardener households, and the runtime loads about 30 citizens, so the gap is readable work yards, not population (R-1504). Window rhythm on smoke dwellings was sent to the window review (R-1434).

**Toompea foot.** Dense log yards with outbuildings below the cliff. All 12 households are classified poor, including a knight of the Danish crown and crown clerks with labourer status (R-1503). Ground is bare lawn with brown yard pads.

### 2026-10-10 - Harbour and Coastal Gate, Cattle-road farmsteads

Captures: `hw3_harbour_aerial`, `hw3_harbour_strand`, `hw3_harbour_to_gate`, `hw3_harbour_to_sea`, `hw3_harbour_from_roads`, `hw3_harbour_runtime`, `hw3_karja_aerial`, `hw3_karja_road`, `hw3_karja_gate_mill`, `hw3_karja_farmyard`, `hw3_karja_farm_above`, `hw3_karja_runtime`, `hw3_karja_road_runtime`.

**Harbour.** What fits `history/dossiers/topography/harbour-and-shoreline.md`: open roadstead with cogs at anchor, two short timber jetties, one treadwheel crane, no stone quay, a low Coastal Gate, a broken sandy shore. Biggest breaks: the strand is painted with a fieldstone paving lattice and carries dandelions and meadow grass down to the jetties (R-1542). The landing has no cargo work: no lighters at the jetties, carts, plank stacks or rope, and about 20 citizens stand idle in one clump by a shed (R-1543). Correctly absent: a customs house or toll booth (no 1343 harbour tariff is attested, `history/dossiers/economy/reval-harbour-customs-1340s.md`).

**Karja.** The 13 farmsteads have the right building types (barn-dwelling, byre, granary, pigsty, sheep shed, henhouse), and hens and sheep spawn at runtime. Biggest breaks: no fields, gardens, orchards or yard fences inside the district (0 of 99 fields), so it reads as barns on a lawn (R-1544). Yard pads end in stair-stepped grid edges (R-1545, also Viru and Toompea foot). Pale round blotches on the thatch (R-1465 widened from shingle to thatch). A lattice window on a barn-dwelling (R-1434 addendum). Knee-high summer grass and flowering dandelions in April (R-1323 note). Correctly absent: a mill or barbican at the Cattle Gate (`history/dossiers/topography/karja-gate-leaf-state-1343.md` excludes both). New idea: St George's Day cattle drive-out on 23 April, research first because the custom is attested only in later folklore (R-1546).

**Consistency gap.** The Lower Town (average 2.6) is still the only place with dressed streets and work. All five extramural areas now rated (Toompea, Kalarand, Viru, Toompea foot, Karja) sit at 1.6-1.8, and the main commercial entrance (the harbour, 2.0) has the buildings but none of the activity that justifies them. The shared causes are city-wide, not per district: blotched roof materials, splat-grid yard edges, a summer sward in April, and citizens that stand instead of working. Fixing those four once (R-1465, R-1545, R-1323, R-1543 activities) lifts every outer district together. Next walks: Harju-road houses and the hinterland fields, then the Lower Town on foot (it has only been rated from older captures) and the landmark sites.

### 2026-10-10 - Harju-road houses and the hinterland west of them

Captures: `hw4_harju_aerial`, `hw4_harju_gate_out`, `hw4_harju_road`, `hw4_harju_yard`, `hw4_harju_to_fields`, `hw4_fields_aerial`, `hw4_fields_eye`, `hw4_wood_edge`, `hw4_east_country` (static), `hw4_rt_harju_road`, `hw4_rt_harju_yard`, `hw4_rt_fields`, `hw4_rt_pasture` (gameplay camera; the runtime clock reached dusk by the pasture shot, so the wood edge was rated from the static view only), and `hw4_farm_field_rye_game`, `hw4_farm_pasture`, `hw4_farm_yard_barn_dwelling` from `tools/capture_city_farmland.gd --tag=hw4` (21 April). Hinterland **A** is "-": its only buildings are the farmsteads rated under Karja and Harju.

**Harju.** 18 farmsteads (69 buildings) in a loose cluster on both sides of the road from the Smiths' Gate, with the right rural types (smoke cottages, barn-dwellings, byres, sheep sheds) and no chimneys, which fits `history/dossiers/architecture/rural-smoke-dwelling-and-farmstead-1343.md`. Garden beds with seedlings line the road and cattle stand at the gate, so at gameplay height it reads better than from above. Biggest breaks: yards are bare mud pads with no well, cart, woodpile or manure heap (R-1594); painted red doors and two framed windows per gable on peasant cottages (R-1434 addendum); blotched thatch (R-1465 addendum). The gate itself fits `walls-gates-towers.md` (plain gate tower, no foregate); the red shutters with white cross match Reval's lesser arms (CANON line on the Dannebrog), so not filed.

**Hinterland.** Crops follow the date, crofts have wattle, pole and stone fences, hay ricks and stock, orchards stand beside the farms. Biggest breaks: every winter-grain strip renders as a pale white-grey slab, which reads as snow from any distance (R-1591, visual bug); `road.toompea_south` crosses four sown strips (R-1592); fields are about 10 ha in small islands on a uniform mown lawn, where the dossiers describe open strips and hay meadows dominating (R-1593); woods are spaced trees on lawn with no understorey or forest floor (R-1595). New idea: an April ploughing team as ambient life, which lifts a FARMLAND non-goal and needs approved art (R-1596).

**Consistency gap.** Every extramural area now has a row; all sit at 1.6-2.0 against the Lower Town's provisional 2.6. The farm suburbs (Karja, Harju, Toompea foot) share one generator and the same four faults: bare yards, blotched roofs, stair-step pads and a summer lawn instead of April ground. One pass on the farmstead generator (R-1594, R-1545) and the ground (R-1591, R-1593, R-1323) lifts all three districts and the country together. Next walks: the Lower Town on foot (still rated only from older captures), then the landmark sites (Town Hall square, Holy Spirit, St Olaf's, St Nicholas'), which have no rows rated yet.
