# Historical walk coverage ledger

Status: living ledger, updated by each historical-plausibility playtest walk.

One row per location of the ADR 0031 seamless Reval city (`content/world/reval_city/plan.json` districts and ADR 0032 landmark sites) and its hinterland. Each walk picks the least recently visited or lowest rated rows first so that no area is richly detailed while another stays empty. Findings go to the task board (`tasks` tool, tag `#historical-walk`), never into this file as a backlog.

Ratings are 1-5 against the best-developed location (the bar): **A** architecture, **P** props, **V** vegetation and terrain, **L** people and life, **S** audio and ambience. "-" means not yet rated.

Captures: `docs/reports/images/historical_walk/`, produced with a scratch capture script that follows `tools/capture_reval_city.gd` (`tools/godot_render.sh --script ...`, day progress 0.42).

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
| Harbour and Coastal Gate | `harbour`, `gate.coastal` | - | - | - | - | - | - | - | |
| Viru road suburb | `district.viru` | - | - | - | - | - | - | - | |
| Cattle-road farmsteads | `district.karja` | - | - | - | - | - | - | - | |
| Harju-road houses | `district.harju` | - | - | - | - | - | - | - | |
| Vassal yards below the castle | `district.toompea_foot` | - | - | - | - | - | - | - | |
| Hinterland fields, pastures and woods | `fields`, `pastures`, `woods` | - | - | - | - | - | - | - | |

## Walk log

### 2026-10-09 - Toompea and Kalarand

Captures: `toompea_castle_aerial`, `toompea_castle_forecourt`, `toompea_kohtu_street`, `toompea_toom_ruutli`, `toompea_overview_n`, `toompea_short_hill_gate`, `kalarand_aerial`, `kalarand_beach`, `kalarand_village`, `kalarand_boatwright`, `kalarand_from_sea` (all `.jpg` in `images/historical_walk/`).

**Toompea.** Dense stone vassal houses and the Dome church building site with scaffolding fit the dossier (`history/dossiers/architecture/toompea-castle-and-upper-town.md`). Biggest breaks: the Danish castle bailey is empty grass (R-1462); every Toompea wall segment is a 5 m crenellated stone curtain although the masonry barrier toward the Lower Town is attested only for 1454-1455 (R-1463); the wall-walk roof floats on slopes (R-1464); shingle roofs read as green camouflage (R-1465, city-wide); streets carry no props, yard walls or people (R-1466). Audio is the music theme only (R-1470). Idea: the Lower Town watch shuts the wooden hill gates at night (R-1471). Older castle and curiae tasks (R-1128, R-967, R-293) point at the retired `toompea_quarter.rrmap`; R-1128 now carries a retarget note.

**Kalarand.** Net yards, clinker boats and the beach fit `history/dossiers/topography/kalamaja-fishing-shore-1343.md`. Biggest breaks: the sea ends about 52 m offshore, so the bay reads as a canal with a green plain beyond (R-1468); 24 identical huts on a lawn instead of a few huts with smoke and salt sheds, splitting tables and fish racks (R-1467); the boatwright yard is untextured primitives (R-1469).

**Consistency gap.** The Lower Town and its five landmark sites have bespoke builders, interiors and citizens. Toompea, the second political pole of the story, has generic house shells, an empty castle and no street life, and the outer districts (Kalarand, Viru, Karja, Harju) are uniform log-and-thatch huts on lawn. Next walks: Viru road suburb and Vassal yards below the castle (not yet visited), then the Harbour.
