# R-294 / P4-025e Toompea 1343 historical acceptance

**Review date:** 2026-08-11
**Historical target:** Danish-ruled Toompea, Spring 1343, before the 16 May castle handover
**Inputs:** A-012 `toompea_1343_art_brief.md`, R-006 `toompea-castle-and-upper-town.md`, R-035 `toompea-small-castle-interior.md`
**Scope:** Historical dating and bounded art-direction acceptance only. The Toompea prototype remains inactive.

## Gate decision

**HISTORICAL DATING GATE: PASS.**

The Spring-1343 hill-gate dating issue is closed: Pikk jalg and Lühike jalg are accepted as wooden gate structures with a timber or earthen boundary treatment. The historical audit no longer leaves their gate superstructures as an open `C/U` review. The exact carpentry, guard-shelter arrangement, and measured gate geometry remain reconstruction boundaries rather than newly attested facts.

This report does **not** claim any of the following:

- an archaeological reconstruction or measured 1343 plan;
- a runtime map or gameplay capture sign-off;
- a day/night image pair for the prototype;
- acceptance of later Order, Swedish, baroque, or modern Toompea fabric.

The four attached PNGs are documentation-only visual studies. They are useful for checking whether the intended period cues survive a lighting review, but they are not archaeological proof, licensed source photographs, or runtime assets.

## Evidence inventory and day/night boundary

All four plates are present under `docs/reports/images/toompea_1343/`. They decode as 1200 x 800, 8-bit RGBA PNGs. A-012 identifies them as deterministic Blender studies rendered for non-runtime art direction. Their `reference_` filenames and neutral study presentation do not establish paired day/night runtime captures.

| Plate | Evidence role | Historical question | Day/night review status |
|---|---|---|---|
| [`reference_castle_compound.png`](images/toompea_1343/reference_castle_compound.png) | Documentation study | Can Small Castle, Great Castle, the intervening ward, and the outer ward read as a low Danish compound without a later Order skyline? | **Target annotated, capture not claimed.** In any later matched day/night capture, plateau/cliff separation, low massing, subordinate towers, and Danish banner must remain legible without relying on a later skyline. |
| [`reference_cathedral_construction.png`](images/toompea_1343/reference_cathedral_construction.png) | Documentation study | Can the Dome church read as an active Gothic enlargement rather than a finished or baroque cathedral? | **Target annotated, capture not claimed.** In any later matched day/night capture, the open nave, scaffold, rectangular pillars in progress, cut stone, and mason's work area must remain readable. |
| [`reference_wooden_hill_gate.png`](images/toompea_1343/reference_wooden_hill_gate.png) | Documentation study | Can the hill-route control point be wooden without importing the 1380 stone Long Leg tower? | **Target annotated, capture not claimed.** In any later matched day/night capture, the steep route, timber posts, plank leaves, guard shelter, and timber/earth barrier must remain distinct from masonry. |
| [`reference_vassal_house.png`](images/toompea_1343/reference_vassal_house.png) | Documentation study | Can a hill vassal or curia house read as private compound fabric rather than Lower Town merchant frontage? | **Target annotated, capture not claimed.** In any later matched day/night capture, the compact silhouette, sparse openings, high chimney, plot wall, and service yard must remain readable by form and material, not hue alone. |

**Interpretation rule:** the rows above record day/night readability requirements for downstream captures, not results from captures that do not exist in this evidence set. This limitation does not block the historical dating gate, but it does keep gameplay-scale visual sign-off outside R-294.

## R-006 Brief ship decisions 1-8

| # | Ship decision | Evidence and R-035 boundary | R-294 acceptance |
|---:|---|---|---|
| 1 | **Plateau:** limestone tableland, elevated over Lower Town, with strong cliff edges. | The castle and gate studies use the elevated hill/cliff separation as the broad visual cue. Exact dimensions and gameplay composition remain bounded reconstruction. | **ACCEPT.** Preserve the attested plateau relationship; do not present the study framing as a measured survey. |
| 2 | **Castle compound:** Small Castle southwest, Great Castle north/central, intervening ward, and early-14th-century outer ward. | `reference_castle_compound.png` presents the four-part production relationship. R-035 supports the three labelled zones and the outer bailey while keeping room sizes and some curtain timing uncertain. | **ACCEPT WITH BOUNDARY.** The massing is an attested production relationship; individual curtain lines, tower arrangement, and room dimensions are plausible composite or unknown. |
| 3 | **Danish seat:** `Castrum Danorum`, with viceroy, court, garrison, and controlled access rather than Hanseatic merchant space. | Castle and vassal studies use a restrained Danish court/garrison read. R-035 accepts Danish secular-seat functions while treating room labels as composite where no 1343 room record survives. | **ACCEPT.** Keep Danish authority and pre-handover presentation; do not use Lower Town merchant typology or an Order default. |
| 4 | **Dome church:** Gothic enlargement under construction, with standing choir/vestry and unfinished nave. | `reference_cathedral_construction.png` records the open nave, scaffold, pillars in progress, cut stone, and mason's yard. R-006/R-035 classify this construction-site presentation as a plausible composite grounded in the attested enlargement phase. | **ACCEPT WITH BOUNDARY.** Construction-state art is accepted; the plate is not proof of an exact 1343 building footprint. No baroque spire or finished tourist silhouette. |
| 5 | **Vassal belt:** compact stone or stone-timber noble and curia houses around the Great Castle and cathedral square. | `reference_vassal_house.png` uses sparse openings, a high chimney, plot wall, service wing, and restrained yard. R-006 attests the settlement type, while individual house footprints and frontage assignments remain composite. | **ACCEPT WITH BOUNDARY.** Preserve hill-vassal/curia distinction; do not treat the study as a measured house plan or as a Lower Town house-tier asset. |
| 6 | **Hill gates:** Pikk jalg and Lühike jalg are wooden in 1343; use timber/earth rather than later masonry. | `reference_wooden_hill_gate.png` shows the accepted period material and route-control read. R-006/R-035 explicitly exclude the stone Long Leg tower dated to 1380 and the later Short Leg masonry. Exact carpentry and guard-house layout remain plausible composite. | **ACCEPT - DATING CLOSED.** Wooden gate structures and timber/earthen boundary are the historical decision. Do not add a 1380+ stone gate tower or the 1454-1455 masonry curtain. |
| 7 | **Political colour:** Danish authority in April, before the 16 May Order handover. | Castle and gate studies retain a Danish banner and avoid an Order takeover presentation. R-035 keeps the handover as a later campaign state. | **ACCEPT.** Danish pre-handover is the default for this pack; later Order heraldry belongs to a separately dated state. |
| 8 | **Exclusion lock:** reject Pikk Hermann, Order convent/four-wing upper ward, stone hill gates, Catherine/baroque east wing, Alexander Nevsky Cathedral, Swedish bastions, and completed baroque cathedral. | All four studies are reviewed against the A-012 exclusion list. The R-035 lock additionally rejects the post-1346 Order convent plan and later towers. | **PASS.** The exclusion list remains authoritative for this gate and is not weakened by the visual studies. |

## R-035 exclusion lock

The following later or unsupported reads remain explicitly excluded from Spring 1343 art direction:

- the post-1346 Order convent and four-wing cloistered upper ward;
- Pikk Hermann and the later corner towers Stür den Kerl, Landskrone, and Pilsticker at their later heights;
- the stone Long Leg gate tower, first attested in 1380;
- the mid-15th-century stone Short Leg gate;
- a complete Great Castle ring curtain presented as securely dated before the handover;
- modern or baroque wings, Catherine Palace, the Alexander Nevsky Cathedral, and a finished baroque cathedral silhouette;
- Lower Town diele-dornse merchant frontage substituted for the hill's vassal/curia fabric.

Surviving later limestone may inform colour, roughness, and restrained masonry weathering only. It must not be used as a measured 1343 plan.

## Historical audit closure

`docs/HISTORICAL_AUDIT.md` now records the following closed decision for `toompea_quarter`:

- the cathedral remains an under-construction second-quarter-14th-century basilica;
- the Danish castle remains a fortified southwest compound and seat of power, with later palace facades and Teutonic additions excluded;
- Pikk jalg and Lühike jalg remain retained routes with **wooden 1343 hill gates**;
- timber or earthen boundary treatment is accepted for this date;
- exact gate carpentry and local reconstruction geometry remain bounded uncertainty, not an open gate-dating `C/U` review.

## Inactive-map guard

No runtime map or scene was changed by this acceptance. The authored map remains explicitly inactive:

```text
content/maps/toompea_quarter.rrmap
map toompea_quarter loc.toompea.quarter 144 192 grass scope=prototype active=false
```

The documentation PNGs remain under `docs/reports/images/toompea_1343/`; they must not be copied into `assets/`, loaded by runtime scenes, or registered in `assets/SOURCES.csv`.

## Verification record

The following checks are part of the R-294 review boundary:

```sh
python3 - <<'PY'
from pathlib import Path
from PIL import Image

root = Path("docs/reports/images/toompea_1343")
paths = sorted(root.glob("reference_*.png"))
assert [p.name for p in paths] == [
    "reference_castle_compound.png",
    "reference_cathedral_construction.png",
    "reference_vassal_house.png",
    "reference_wooden_hill_gate.png",
]
for path in paths:
    with Image.open(path) as image:
        assert image.size == (1200, 800)
        assert image.mode == "RGBA"
        assert image.getbbox() is not None
print("Toompea reference plates: 4/4 present, 1200x800 RGBA, non-blank")
PY

# Historical contract and inactive-map checks
grep -n "active=false" content/maps/toompea_quarter.rrmap
grep -n "wooden\|Pikk jalg\|Lühike jalg\|R-006\|R-035" docs/HISTORICAL_AUDIT.md
! grep -Fq "gate superstructures require separate dating review **C/U**" docs/HISTORICAL_AUDIT.md

# Focused fabric contract test (baseline note)
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_toompea_1343_fabric_contract
```

Observed on 2026-08-11: the harness discovered 4 tests, with 3/4 passing. The three implementation checks passed, including the closed hill-gate allowlist and stone-tower rejection. The documentation-contract test failed because its pre-existing required file `docs/reports/toompea_1343_fabric_contract.md` is absent and the test also expects contract tokens that are not present in `docs/MAP_AUTHORING.md`. Those files are outside the R-294 allowlist and were not created or edited here. This is recorded as a baseline prerequisite, not attributed to the historical acceptance report. The report's image, audit, and inactive-map checks above pass independently.

The focused contract test protects the closed R-006/R-035 fabric allowlists, rejects stone hill-gate styles, and verifies the historical contract boundary when its prerequisite contract document is available. Any broader runtime visual or gameplay acceptance remains outside this documentation-only gate.

## Handoff

- **P4-025e:** historical dating gate closed by this report and the audit-row update.
- **P4-025a-d:** remain responsible for any runtime/map visual corrections; this report does not activate or rewrite the prototype.
- **P4-040 / P4-041:** may consume the wooden-gate curfew and Danish pre-handover boundary as separately scoped jurisdiction and narrative inputs.
- **P4-039:** may use R-035 labelled Danish interior zones without back-projecting the post-1346 Order plan.
