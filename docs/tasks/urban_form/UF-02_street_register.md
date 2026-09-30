# UF-02: 1343 Reval street, lane and open-space register with attestation

Board row: **R-1111**. Priority: high. Depends on: none. Research evidence gate for UF-04..UF-07 and UF-09; this row does not author streets.

## Player-facing goal

The player can leave Kalev's yard, follow intelligible ways through the market, church precincts and gates, and distinguish an attested 1343 route from a later name placed on an older way. A map author must not make up a street merely to fill space.

## Why this is needed

The pack baseline counts **23** `.rrmap` statement kinds, none named `street`; `lower_town_slice` has **97 `building` rows** and **63 `style` rows**, with absolute placements rather than frontage bound to a continuous route ([pack baseline](README.md#measured-baseline-2026-09-30)). The signed [P0-072 environment dossier](../../HISTORICAL_AUDIT.md#p0-072-1343-reval-environment-target-dossier) gives district-wide street/property and surface bands, **not** per-way endpoints, widths or name dates. Its own H01-H04 distinguish surviving medieval alignment from a measured spring-1343 plan.

Street-name census in `docs/HISTORICAL_AUDIT.md` at contract drafting, using **case-insensitive whole-token matches** (including source titles and references, not a count of 1343 attestations): Viru **17**, Karja **12**, Pikk **7**, Harju **6**, Uus **4**, Lai **3**, Rataskaevu **2**, Kuninga **2**, Vene **2**, Suur-Karja **1**, Müürivahe **1**, Dunkri **1**, Niguliste **2**, Oleviste **1**. **Fourteen distinct tokens**, none accompanied by a per-way trace, width, surface and dated-name register. The shorter pack count is a different substring/case census, not a street inventory. `Uus` in this count includes **Uus and Uus**, the roof-paper authors, and is not automatically evidence for Uus Street; `Karja`/`Viru` include gates and sources; `Niguliste`/`Oleviste` can name churches rather than ways. Classify occurrences in context before treating them as street evidence.

Existing `content/maps/market_civic_quarter.rrmap` comments name **Kullassepa/Dunkri**, Pühavaimu and the Viru/Vene convergence; `south_quarter.rrmap` authors `niguliste_lane` as a `stroke` and nearby `niguliste_row` as a house, but neither supplies a dated street record. Reconcile every actual way named in `.rrmap` comments, not just the audit's prose. [Lower Town street-plan dossier](../../../history/dossiers/topography/lower-town-street-plan.md) already distinguishes later documentary names from 1343 physical routes; [old-market dossier](../../../history/dossiers/topography/old-market-vanaturg.md) distinguishes the **1313 forum** from the cart throat and the later Vana turg strip. These are inputs, not a surviving 1343 survey.

## Deliverable

1. `docs/reports/reval_street_register_1343.md`: decision-ready brief; source register with exact document/folio or excavation plate where available; one evidence card per way; named endpoint/adjacency and alternate-name reasoning; widths and surfaces with *site-specific* versus regional-transfer limits; present-map census and contradictory geometry; rejected/unknown list; phase exclusions; open questions and named handoff to Map and Canon. Cross-link H01-H11, P0-072 target cards, the [South Quarter fabric contract](../../reports/south_quarter_1343_fabric_contract.md), and `history/RESEARCH_INDEX.md`. A later survival is not a dated 1343 measurement. Link relevant existing plates; if adding new visual evidence in the implementation row, document date, origin, license and transfer limit before use. Do not produce the report in this contract-writing task.
2. `docs/data/reval_street_register.json`: UTF-8 JSON **object** with exactly `schema_version` (integer, **1**), `as_of` (string, **`spring-1343`**), `ways` (array of way rows, including admissible but currently unplaced ways), `open_spaces` (array of bounded open-space records), and `excluded` (array of rejected-way records). No silent omissions. Rows are ordered by `id` for stable diffs. **Complete row schema** (no extra keys):

   | Field | Type and required value |
   |---|---|
   | `id` | Nonempty unique stable string `street.<lowercase_snake_case>`; e.g. `street.pikk`, `street.rataskaevu`, `street.luhike_jalg`; do not derive from a later spelling if a stable ID already exists. |
   | `name_1343` | Nonempty string with a source-backed contemporary form or a neutral functional description (e.g. `market-to-gate way`); **never** silently substitute the modern name. |
   | `modern_name` | Nonempty string; present-day identification for authors, not automatically a period label. |
   | `name_attestation` | Object `{ "status": "by_1343" | "post_1343" | "unverified", "first_mention_year": integer | null, "recorded_form": string | null, "source_ids": string[] }`. `by_1343` requires a **reviewed dated primary record** at or before 1343; `post_1343` requires a cited later dated mention. `unverified` permits a secondary-source proposed year, but that year cannot become an attested 1343 name. When no source proposes a year or form, use `null` for the respective field and explain it in the report. `source_ids` is nonempty and resolvable when either year/form is given; otherwise it may be empty with the gap explained. The 1325 *rader strate* secondary claim, lacking a reviewed folio, must be `unverified` with its B/C limit, not silently upgraded. |
   | `route_1343` | One of `attested`, `plausible composite`, `invented`; `folklore` is not a physical-route verdict. This is separate from the name's status; explain the evidentiary boundary in the report. |
   | `owning_map_id` | Nonempty existing `.rrmap` **map id** (the `map` statement's second token, not the filename or an imagined future map); if a way crosses a seam, split into separately identified map-owned segments and record the shared endpoints. For an as-yet-unmapped extramural segment, name its **planned** owner in `planned_map_id` while `owning_map_id` names the current gate-side owner; the registered trace must end at that owner's physical boundary and may not assert a not-yet-authored road beyond it. Record the future continuation in the report, not as already placed. |
   | `planned_map_id` | String or null; proposed new map id only where the segment cannot be authored on an existing map, with an explicit implementation dependency in the report. |
   | `class` | Exactly `spine`, `lane`, `alley`, `ramp`, `square edge`, or `extramural road`; the **open forum** must also be represented by a distinct bounded open-space record, not disguised as a through street (see below). |
   | `trace` | Object `{ "from": string, "via": string[], "to": string }`; named physical endpoints (gate, church, well, market corner or seam). Nonempty `from` and `to`; `via` may be empty. Include gate construction-state qualifiers. No asserted metric coordinates without archaeological support. |
   | `width_m` | Object `{ "min": number | null, "max": number | null, "basis": string, "source_ids": string[] }`; finite positive numbers with `min <= max` **or both bounds null**. Basis says excavation, dated plan, or labelled B/C/D analogue, **not** a fabricated measured 1343 street width. Where width is U, both bounds must be null with a nonempty reason in `basis`. |
   | `surface` | Object `{ "material": "rammed earth" | "gravel" | "timber corduroy" | "cobble" | "pebble/rubble" | "limestone slab" | "unknown", "basis": string, "source_ids": string[] }`; distinguish attested local fabric from later paving; `unknown` needs a reason. |
   | `drainage` | Object `{ "runoff": string, "centre_gutter": "attested" | "plausible composite" | "unknown" | "not applicable", "basis": string }`; state side/open gutter versus centre gutter explicitly, without asserting a city-wide sewer. |
   | `frontage` | Nonempty string stating houses, rear yards, precinct walls, market edge, gate/road verge, or open ground as appropriate; classify a designed game arrangement as such. |
   | `map_state` | One of `not_authored`, `partial`, `matches`, `contradicts`; evaluated against current authored source (not a claim that a `stroke` is a street primitive). |
   | `map_conflicts` | Array of strings; for `contradicts`, at least one specific `.rrmap` path, id and discrepancy; otherwise may be empty. |
   | `confidence` | Exactly one of `attested`, `plausible composite`, `folklore`, `invented` from [CANON Confidence Labels](../../CANON.md#confidence-labels). This is the *overall proposed authoring decision*, not a shortcut for the separately dated name. |
   | `evidence_class` | Exactly `A`, `B`, `C`, `D`, or `U` from [P0-072](../../HISTORICAL_AUDIT.md#p0-072-1343-reval-environment-target-dossier); it supplements, never replaces, `confidence`. |
   | `source_ids` | Nonempty array of unique, resolvable citations to the report's source register; at least one source actually supports the route or clearly documents the uncertainty. |

   An `excluded` item has exactly `{ "name": string, "reason": string, "source_ids": string[] }`, all nonempty, with sources resolvable in the report. For the forum, add a `ways` record with `class: "square edge"` for each *walkable edge* and a **bounded open-space record** in top-level `open_spaces`: `{ "id": "space.forum", "modern_name": "Raekoja plats", "name_1343": "forum", "owning_map_id": string, "bounds": string, "confidence": string, "evidence_class": string, "source_ids": string[] }`. This is the **exact eight-field** open-space schema (no extra keys): `id` is a unique `space.<lowercase_snake_case>`; the two names and `bounds` are nonempty strings; `owning_map_id` is an existing map id; `confidence` and `evidence_class` use the enums defined above; `source_ids` is a nonempty resolvable array. `bounds` describes named corner/edge relations, not invented survey coordinates. Other genuine opens use the same schema. A plaza is not the later Vana turg street.

   A row is **invalid** for any missing/unknown extra field, duplicate ID, unresolved map/source reference, broken type or enum, `by_1343` attestation without a dated pre-1344 source, unjustified numeric width, `contradicts` without a named conflict, missing forum open-space/edges, or later phase stated as 1343. JSON `null` is permitted **only** where specified above. The report must enumerate the minimum list even when a candidate is excluded; an uncertain name cannot be silently discarded or promoted.

Minimum candidates to decide, **not a mandate that all existed under these names in 1343**: Pikk, Lai, Vene, Olevimägi, Pühavaimu, Rataskaevu, Dunkri, Niguliste, Kuninga, Rüütli, Harju, Müürivahe, Suur-Karja, Väike-Karja, Viru, Vanaturg / Raekoja plats, Pikk jalg, Lühike jalg, extramural Harju and Viru approach roads. Include `Uus` only if an actual street reference survives context-checking, plus any additional actual way named in an `.rrmap` comment (e.g. Kullassepa) or required by P0-072. Assign owning map by actual street geometry, not by a misleading tourist catalog: the St Michael precinct is on the **western/northern monastery belt** in P0-072, not automatically `south_quarter`.

Phase lock: reconcile the **1325** *rader strate* secondary name (**B/C**), **unknown** exact 1343 Dunkri/Cat's Well corner (**U**), and **1375** Cat's Well rebuild as later fabric with R-1009/R-1011 and the [South Quarter contract](../../reports/south_quarter_1343_fabric_contract.md#rataskaev-well-uncertainty). Preserve H10's **1365** Karja name and the Lower Town dossier's later Harju/Viru name dates as later attestations, not spring-1343 dialogue. The 1343 forum is not its later formal rectangular plaza; 15th-century building phases may not determine a way's 1343 surface.

## Allowed files

For **R-1111 implementation**, and no others: `docs/reports/reval_street_register_1343.md`, `docs/data/reval_street_register.json`, `docs/HISTORICAL_AUDIT.md`, `docs/CANON.md`, `history/RESEARCH_INDEX.md`, `TODO.md`. The last three shared files require their owners' review; no unilateral canon changes. **This task-pack writing session edits only this contract file.**

## Constraints and non-goals

- Evidence before geometry. Read local `history/*.pdf` archaeology and Estonian institutional sources first, then use later maps strictly as labelled analogues. Cite every nontrivial date, route, material and width; mark unreviewed or conflicting claims **U**, and separate route existence, alignment and *name*.
- Preserve signed P0-072 A/B/C/D/U cards and the South Quarter H-bands. Width proposals do not amend a signed band. No `.rrmap`, code, runtime assets, new plate files or map activation in this row.
- Streets are not guessed from a house-grid gap; frontage ownership belongs to UF-04, street primitive to UF-03, district authoring to UF-05..UF-07 and hinterland extension to UF-14/UF-15. Do not copy 1375 Cat's Well, later gate barbicans or blanket cobble into spring 1343.

## Verification

From repository root, after **R-1111** creates its deliverables:

```bash
python3 -m json.tool docs/data/reval_street_register.json >/dev/null
rg -n '^map |^#.*(street|lane|road|approach)|^stroke ' content/maps/*.rrmap > /tmp/uf02-map-ways.txt
rg -n -i 'viru|karja|pikk|harju|uus|lai|rataskaevu|kuninga|vene|müürivahe|dunkri|niguliste|oleviste' docs/HISTORICAL_AUDIT.md > /tmp/uf02-audit-mentions.txt
python3 tools/generate_active_docs_report.py --check
python3 tools/archive_speculative_docs.py --dry-run
git diff --check
```

A second reviewer manually checks every row against the **complete field/type/enum rules above**, resolves each `source_ids` reference, and compares the two command inventories to all actual way references (not roofs, church names or gate names). Review the minimum candidates and the `excluded` list one by one. Verify every numeric width has a bounded basis and each named form has a date/status; list unplaced ways and contradictory current geometry with file/id. Canon Keeper signs the report's 1343 name/phase decisions as second reviewer; the task remains pending canon until then. If a later implementer adds a machine schema/validator under another authorized row, it must enforce this contract, not silently redefine it.

## Doc updates

On **R-1111 delivery**, cross-link the new report/register in `history/RESEARCH_INDEX.md`; update `docs/HISTORICAL_AUDIT.md` and `docs/CANON.md` only through the named reviewers, preserving existing confidence language. TODO status is the Producer's responsibility. No such updates occur while writing this contract.

## TODO.md line

```text
- [ ] R-1111 | deps: none | deliverable: sourced docs/reports/reval_street_register_1343.md and docs/data/reval_street_register.json, with dated names, 1343 route verdicts, owner map, trace, bounded width/surface/drainage/frontage, map conflicts, forum open space, citations and exclusions | verify: JSON parse and full schema/coverage review, active-docs check and speculative-archive dry run; Canon Keeper signs 1343 claims
```
