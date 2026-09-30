# UF-09: 1343 Reval landmark placement register and its fail-closed gate

Board row: **R-1118**. Priority: high. Depends on: **R-1111** (UF-02 street register supplies addresses). Map/content contract plus a narrow Python verifier; no landmarks are placed by this row.

## Player-facing goal

A player can find St Nicholas' (Niguliste), St Olaf's (Oleviste), the forum and the hill churches as recognisable *1343* places rather than as prose or interchangeable house boxes. Missing anchors and anachronistic later silhouettes become detectable before the church/art rows ship.

## Why this is needed

`docs/data/landmark_integrations.json` has the St Nicholas beat `beat.landmark.tallinn.st_nicholas_church_niguliste_kirik` and the merchant-tombs beat; `docs/LANDMARK_NARRATIVE_INTEGRATION.md` binds the former to a **shared** `monastery_quarter::...` narrative anchor, not a dedicated church anchor. A repo-wide `.rrmap` scan finds **no** St Nicholas church `landmark` statement, dedicated Niguliste anchor or exterior model; `market_civic_quarter.rrmap` **does** contain `sign.niguliste` (`to st nicholas`) and `niguliste_corner_house`, and `south_quarter.rrmap` contains `niguliste_lane`, `niguliste_row` and `niguliste_chapter_house`. Therefore the board phrase "exists only as narrative rows" means *the church as a placed landmark*, not that the name has no other occurrences. [P0-072](../../HISTORICAL_AUDIT.md#p0-072-1343-reval-environment-target-dossier) specifies church-phase targets, but the maps lack a single accountable named-building register.

Reproducible `.rrmap` census: `awk '/^anchor landmark_/{print $2}' content/maps/*.rrmap | sort -u` gives **37 distinct IDs** across **43 anchor declarations**, not the board/pack baseline of 41. They are not 43 Reval church models: all these `anchor landmark_*` lines occur in `world_*` travel maps. Grouped **complete distinct-ID census** (repeat declarations account for 43 total):

- Rural, combat and settlement (20): `landmark_ancient_oak`, `landmark_battle_ridge`, `landmark_bog_causeway`, `landmark_bog_spring`, `landmark_burned_manor`, `landmark_council_camp`, `landmark_east_camp`, `landmark_east_fieldworks`, `landmark_east_quarter`, `landmark_fisher_hamlet`, `landmark_muster_camp`, `landmark_offering_stone`, `landmark_split_fields`, `landmark_threshing_barn`, `landmark_town_barricade`, `landmark_village_well`, `landmark_west_camp`, `landmark_west_fieldworks`, `landmark_west_quarter`, `landmark_work_yard`.
- Island/shore and crossings (6): `landmark_ferry_landing`, `landmark_island_coast`, `landmark_kaali_crater`, `landmark_kaali_lake`, `landmark_river_ford`, `landmark_strait_landing`.
- Castle, chapel and Padise fabric/service (11): `landmark_arched_niche_house`, `landmark_central_keep`, `landmark_early_stone_house`, `landmark_fire_damage`, `landmark_gatehouse`, `landmark_island_chapel`, `landmark_limestone_tower`, `landmark_monastery_well`, `landmark_monks_cemetery`, `landmark_timber_oratory`, `landmark_watermill`.

These `anchor landmark_*` lines occur in `world_*` travel maps, **not** in a Reval street or church precinct. By contrast `landmark viru_gate_arch gate_arch ...` and `landmark pikk_jalg_gate gate_arch ...` are **`landmark` statements**, not `anchor landmark_*`; count them separately. Existing urban `building town_hall_mass`, `building st_olaf_silhouette`, `building st_michaels_convent`, `building cathedral_silhouette`, `building castle_mass`, `building st_catherines_church` and nearby generic frontage anchors are placeholder geometry, not proof of a dedicated anchor plus a 1343 exterior asset. Do not declare them all `absent` without a census.

The tourist catalog and narrative matrix cover **208** tourist entries (108 Tallinn, 100 outside Tallinn), many conceptual, later, generic or attached to shared district anchors. They are **not** an inventory of 208 attested 1343 landmark buildings. `docs/TOURIST_LANDMARKS.md` puts St Nicholas in `monastery_quarter`, St Olaf in `north_quarter`, St Michael in `south_quarter`, and the Great Guild site in `market_civic_quarter`; extant `monastery_quarter.rrmap` instead holds `building st_olaf_silhouette`, `anchor st_olaf_frontage`, `building st_michaels_convent`, `building great_guild_front` and `anchor guild_frontage`, whereas `market_civic_quarter.rrmap` has generic `building guild_frontage`. P0-072 and the [religious-precinct dossier](../../../history/dossiers/religion/ecclesiastical-precinct-boundaries-1343.md) locate the St Michael nunnery in the **western/northern monastery belt**. The register must resolve actual ownership and whether a model spans maps explicitly rather than copying catalog anchors or quietly moving a precinct. The [church-phase dossier](../../../history/dossiers/religion/churches-and-religious-houses.md) already distinguishes 1343 fabric from later church rebuilding.

## Deliverable

1. `docs/reports/reval_landmark_placement_1343.md`: short placement decision table (one 1343 physical site/precinct per stable id), evidence, 1343 phase versus later state, old-to-new map geometry/anchor mapping, exact UF-02 address reference, tower/gate coverage, proposed placement task, disputes and exclusions. For every institution, name what the cited evidence supports **in spring 1343**, what is only analogical, and what is absent or post-period. Include the current-state census (already placed arch, generic building mass, shared narrative anchor, dedicated anchor, exterior GLB are different things). Cross-check every Reval entry in `docs/data/landmark_integrations.json`, `docs/TOURIST_LANDMARKS.md`, and `docs/LANDMARK_NARRATIVE_INTEGRATION.md`: map to a register row or add an explicit exclusion/classification reason in the report. Non-Reval places, roads/streets covered by UF-02, incidental props and later-only buildings need classification, **not** fictitious 1343 buildings. Record named historical sources inline with [CANON](../../CANON.md#confidence-labels) confidence and P0-072 evidence class; local `history/*.pdf` archaeology and Estonian institutional sources before unsourced modern summaries. Existing visual plates may inform a specified phase decision only with date/place/transfer and rights recorded; no evidence-substitute generation. This task-writing session does not produce the report.
2. `docs/data/reval_landmark_register_1343.json`: UTF-8 JSON **object** with exactly `schema_version` (integer, **1**), `as_of` (string, **`spring-1343`**), `landmarks` (array of rows sorted by `id`), `grace` (array of explicit temporary placement exceptions, sorted by `landmark_id`), and `excluded` (array of exclusion records). **Exact landmark-row schema** (no extra keys):

   | Field | Type and required value |
   |---|---|
   | `id` | Unique nonempty stable `landmark.<lowercase_snake_case>` string, e.g. `landmark.niguliste`, `landmark.oleviste`; physical gate/tower IDs may reference existing `.rrmap` IDs separately. |
   | `name` | Nonempty display string; do not mistake present-day tourist name for an attested 1343 form. |
   | `owning_map_id` | Nonempty existing `.rrmap` `map` statement's second token; one primary physical owner only. This is not a filename or shared narrative anchor. |
   | `anchor_id` | Nonempty **planned dedicated stable anchor** string (unqualified ID on the owning map), even while absent; must resolve to an authored `anchor` or to an existing `landmark` statement explicitly classified as the corresponding anchor when `status` is `anchored`/`modelled`. A nearby `market_cross` or `katariina_kaik` does not satisfy it. An existing gate/tower `landmark` statement may be the exact anchor without duplicating it; do not rename an existing stable ID. |
   | `street_id` | Existing UF-02 `street.<id>` reference or `null` **only** where a castle/precinct has no defensible street address; `address_note` must then explain entrance/gate/close location. |
   | `address_note` | Nonempty string, with named approach, entrance and frontage relationship; no invented medieval house number. |
   | `phase_1343` | Nonempty string specifying surviving or in-progress mass in spring 1343 and explicitly delimiting any later work. An undated building name alone fails. |
   | `later_phase_excluded` | Nonempty array of strings naming the anachronistic elements not to build; at least one phase-specific exclusion (or `none identified after review` with cited explanation in report). |
   | `model_tier` | Exactly `B`, `K-S`, or `K-L` from [ADR 0025](../../adr/0025-architectural-asset-pipeline.md#1-tier-split-per-ar-01-family). A church/castle/tower/gate primary mass uses `B`; **generic pre-1407 Great Guild meeting frontage is `K-L`**, not a 1343 `B` hall, unless the ADR/Canon review formally changes that verdict. |
   | `status` | Exactly `absent`, `anchored`, or `modelled`: `absent` = proposed anchor not yet present; `anchored` = exact owning-map anchor resolves but no approved exterior model; `modelled` = exact anchor and source-controlled exterior asset resolve. Existing placeholder `building` rows do not automatically advance the status. |
   | `asset_path` | `null` for `absent` or `anchored`; repository-relative nonempty `.glb` path for `modelled`, and the file must exist. Runtime script-generated cubes/house silhouettes are not approved exterior assets. |
   | `existing_geometry_ids` | Array of distinct strings naming **actual** existing `building`, `anchor`, `landmark` and sign IDs on owning or adjoining maps where relevant; may be empty. Document what each represents in the report. |
   | `confidence` | Exactly one of `attested`, `plausible composite`, `folklore`, `invented`, using [CANON](../../CANON.md#confidence-labels) verbatim; this labels the overall 1343 authoring decision, not each later historical phase automatically. |
   | `evidence_class` | Exactly `A`, `B`, `C`, `D`, or `U` from [P0-072](../../HISTORICAL_AUDIT.md#p0-072-1343-reval-environment-target-dossier); this supplements rather than replaces `confidence`. |
   | `source_ids` | Nonempty array of distinct citation IDs resolvable in the linked report. Dates, phases and location must each be source-backed or explicitly identified as inference/unknown. |

   A `grace` record has **exactly** `{ "landmark_id": string, "placement_task": string, "reason": string }`; each value nonempty, `landmark_id` unique and referencing one `status: "absent"` row; `placement_task` names **UF-10/R-1119**, **UF-11/R-1120**, **UF-12/R-1122**, or **UF-13/R-1125** (or a separately authorized task for a tower). No grace for `anchored` or `modelled`. An `excluded` record has exactly `{ "name": string, "reason": string, "source_ids": string[] }`, all nonempty, with resolvable source citations. Unresolved later-only *named* tourist entries may be excluded without deleting their narrative beat; flag the mismatch for Canon rather than editing narrative content in this row.

   **Fail-closed exception rule:** A missing/nonmatching anchor fails the verifier unless and only unless the row is `absent` with exactly one valid, task-bound grace record; the baseline remains green with explicit debt. An `anchored`/`modelled` row with no exact anchor fails even if a `grace` record is mistakenly left. Any missing phase, missing map, invalid street reference, missing source, unsupported 1343 dating, duplicate ID, `modelled` row without a real `.glb`, extra field or unlisted 1343 landmark in the cross-check makes delivery invalid. No blanket grace and no `enforce=false`. The Python verifier must emit actionable row IDs and exit nonzero on invalid data; `tools/run_pre_commit_checks.sh` must run it for changes to this register or its relevant `.rrmap` sources.

Minimum sites to decide: **St Nicholas'**, **St Olaf's**, **Holy Spirit**, **Dominican St Catherine's** precinct, **Cistercian St Michael's** precinct, **Town Hall**, **Great Guild meeting site**, **Dome Church**, **Toompea castle**, and existing urban gate/tower landmark statements. Treat an existing tower **position** or a gate arch separately from a completed later tower silhouette; include genuine 1343 candidates and classify rejected/tentative towers explicitly against the [fortification evidence](../../../history/dossiers/topography/walls-gates-towers.md) and P0-072. One church/precinct is one stable site row unless distinct attested buildings and separate placement tasks justify more. Ensure the civic forum is a UF-02 open space rather than a duplicated landmark building.

**Phase lock:** The 1343 St Nicholas parish church is not its late-Gothic/15th-century enlarged nave or choir; St Olaf is not the post-1433 basilica or 15th-century giant spire; the Town Hall precedes the **1402-04** rebuild, arcade and tower. The present Great Guild Hall is **1407-10**, so the 1343 row is a qualified meeting **site/room**, not that hall. Keep the 1343 Dome church under-construction state and exclude later chapels/tower. Do not import the 1375 Cat's Well rebuild or attach modern 15th-century gate towers to 1343. Cite [P0-072 map cards](../../HISTORICAL_AUDIT.md#p0-072-1343-reval-environment-target-dossier), [South Quarter](../../reports/south_quarter_1343_fabric_contract.md), and the religious dossier rather than assigning misleading certainty from tourism copy. **ADR 0025 currently says Proposed/Awaiting maintainer acceptance**; this report may record proposed `model_tier` but cannot authorize production art before that ADR is accepted.

## Allowed files

For **R-1118 implementation**, and no others: `docs/data/reval_landmark_register_1343.json`, `docs/reports/reval_landmark_placement_1343.md`, `tools/verify_landmark_register.py`, `tests/python/test_verify_landmark_register.py`, `docs/data/landmark_integrations.json`, `docs/HISTORICAL_AUDIT.md`, `docs/CANON.md`, `tools/run_pre_commit_checks.sh`, `TODO.md`. Canon/audit and integration changes require their owners' approval, not silent rewrite. **This contract-writing session edits only this contract file.**

## Constraints and non-goals

- No models, `.rrmap` edits, new anchors or map activation. UF-10..UF-13 place and model; this row registers and gates. Keep existing IDs and distinguish `building`, `landmark` and `anchor` kinds. A name in narrative data is not spatial placement.
- Do not copy tourist catalog errors: its St Michael south-ward placement conflicts with P0-072 northern/monastery precinct evidence; its St Nicholas monastery/Dominican binding is narrative reuse, not church siting. Its St Olaf north-ward entry and Great Guild civic entry disagree with extant `monastery_quarter` placeholder masses. Resolve disputed owning maps with UF-02 and Canon Keeper in the report, never by inventing geography in JSON.
- Only exactly four CANON confidence labels; A/B/C/D/U are **separate** evidence classes, never fifth/sixth confidence labels. No post-1343 building phase or later first mention treated as April 1343 fact. No unsigned edit of canon or downstream narrative content.

## Verification

From repository root, after **R-1118** implementation:

```bash
python3 -m json.tool docs/data/reval_landmark_register_1343.json >/dev/null
awk '/^anchor landmark_/{print $2}' content/maps/*.rrmap | sort -u
rg -n '^landmark |^anchor |^building |niguliste|st_nicholas' content/maps/*.rrmap > /tmp/uf09-map-census.txt
rg -n 'Niguliste|Nicholas|Oleviste|Olaf|Holy Spirit|Catherine|Michael|Town Hall|Great Guild|Castle|Toomkirik' docs/TOURIST_LANDMARKS.md docs/LANDMARK_NARRATIVE_INTEGRATION.md docs/data/landmark_integrations.json > /tmp/uf09-catalog-census.txt
python3 -m unittest tests.python.test_verify_landmark_register -v
python3 tools/verify_landmark_register.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

Tests must include negative fixtures for **missing anchor without valid grace**, mismatched map/anchor, phase missing, `modelled` without asset, invalid UF-02 address, duplicate ID, expired grace after an anchor lands, and unrecognised confidence or tier; baseline test confirms each absent row's grace names its placing task. Reviewer reconciles `/tmp/uf09-catalog-census.txt` against every Reval physical site plus a reasoned exclusion for nonphysical, later, or non-Reval entries; manually checks one-by-one the minimum nine sites and urban tower/gate statements and signs the phase column as Canon Keeper. Check pre-commit invocation with a staged register fixture (without staging unrelated files). If `python3` is unavailable in a limited agent container, state this environment blocker; do not report these commands as passed without running them.

## Doc updates

On **R-1118 delivery**, link the register to UF-02 and the report; only Canon Keeper may sign new claims in `docs/CANON.md` and correct conflicting tourist/catalog assertions through their authorized paths. `docs/HISTORICAL_AUDIT.md` and `docs/data/landmark_integrations.json` are allowed only for a reviewed reconciliation, not necessary to hide exclusions. TODO status remains Producer-owned. No such updates occur while writing this contract.

## TODO.md line

```text
- [ ] R-1118 | deps: R-1111 | deliverable: docs/data/reval_landmark_register_1343.json and docs/reports/reval_landmark_placement_1343.md with 1343 phase, UF-02 address, actual map/anchor status, ADR-0025 tier, sourced exclusions and task-bound absence grace; fail-closed landmark verifier and tests | verify: JSON and UF-02 reference check; negative fixture suite and real-repo verifier pass; catalog coverage reviewed; Canon Keeper signs phases
```
