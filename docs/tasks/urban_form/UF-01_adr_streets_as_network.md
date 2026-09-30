# UF-01: ADR 0026 - streets are an authored network

Board row: **R-1110**. Priority: high. Depends on: none.

## Player-facing goal

Make a lane a named, continuous route with a width, surface and destination, so houses can line it deliberately instead of forming a matrix of unrelated rectangles. This row decides the representation before UF-03 implements it. Owner: Dev; scope and acceptance decision: maintainer; downstream implementer: UF-03/R-1112.

## Why this is needed

Checked on 2026-09-30 in scripts/map/rrmap/map_rrmap_parser_statements.gd: there is no `street` branch. There are **32 statement dispatch kinds**, counting the separately dispatched `map`, plus the separate `rrmap` version header:

```text
map source surroundings camera grade elevation_area elevation_ramp
relief_hill relief_ridge relief_ditch relief_terrace relief_cliff relief_noise
style terrain terrain_rects stroke building wall prop spawn transition anchor
patrol exclude fade decal sign landmark package prefab override
```

The pack README's 23-kind list is a census of statements occurring in content/maps/*.rrmap, not the full supported grammar. The six relief commands, `grade`, `package`, `prefab` and `override` must not disappear from the ADR's compatibility account. The 29 current map files contain no authored street object. lower_town_slice.rrmap has **97 building rows and 63 style rows**, confirmed with anchored counts. `terrain_rects` and `stroke` express terrain coverage, not street identity, connected destinations or frontage. Individually placed building origins cannot establish those semantics.

WB-09/R-981 already reserves **ADR 0024**, and its deliverable 2 adds a plot carrying frontage, depth and street. Two independent geometry languages for that plot and this network would conflict. The agreed pack seam is that **UF-03 owns street geometry; WB-09 consumes it**.

ADR-number check on 2026-09-30: `ls docs/adr/` has 0023 and 0025 but no 0024, 0026 or 0027. `grep -rn "ADR 0026" docs/tasks TODO.md` found only this pack's reservation in its README before these contracts were written. Therefore this contract retains **0026**, leaving WB-09's 0024 and UF-14's 0027 reservations intact. Recheck immediately before creating the ADR; a prose reservation is not a lock.

## Deliverable

1. docs/adr/0026-streets-as-authored-network.md with **Status / Context / Decision / Alternatives / Consequences**. Start Status as `Proposed, <YYYY-MM-DD>. Awaiting maintainer acceptance.` Record a named, dated human acceptance or rejection; proposal publication alone does not release UF-03.
2. Specify an ID-first `street` primitive on MapBlueprint: stable ID, orthogonally stepped centreline, width band with units and validation bounds, authored surface, and class (`spine`, `lane`, `alley`, `ramp`, `square edge`). Define deterministic ordering, edge-grown thickness consistent with `stroke`, overlaps and endpoints. Define how UF-15's `extramural road` class will be represented before hinterland authoring, without adding a second geometry vocabulary.
3. Specify compilation into `MapDefinition.street_network`, a typed `StreetNetwork` contributing to the canonical fingerprint. Buildings may bind `street=<id> side=<n|s|e|w> offset=<cells>`; UF-04/R-1113 implements frontage seating and block subdivision. Distinguish street-facing placement from WB-13/R-985 plot contents and AR-13/R-971 appearance repetition.
4. Reserve stable MapBlueprintDiagnostic codes for UF-03: `MAP_STREET_ORPHAN`, `MAP_STREET_WIDTH_JUMP`, `MAP_STREET_DEAD_END`, `MAP_STREET_OVERLAP`. Specify severity, forbidden/allowed dead ends by class, width-jump tolerance and what counts as a gate, square, transition or street connection. Thresholds must be numerical in the accepted ADR, not left to runtime guesswork.
5. State the compatibility invariant: `stroke` and `terrain_rects` keep their meanings; every map without streets retains byte-identical canonical fingerprint and walkability. Empty network serialization must not silently change old fingerprints. UF-03 proves this across all 29 legacy maps and adds round-trip/negative fixtures; this row writes no such code.
6. **Equivalent-cost scope removed: WB-09/R-981's independent free-form plot/street geometry layer.** Remove its separate trace, width, edge-offset, frontage-geometry validation and lowering vocabulary. Its plot statement consumes UF-03/R-1112 street IDs and network geometry, and UF-04 frontage semantics where needed. Retain WB-09 style presets, descriptions, summaries, deterministic prefab lowering and stable IDs. The ADR must compare the eliminated parser/validator/serializer and geometry-test work with the new street work, rather than claiming a zero-cost rename.
7. Amend WB-09's contract and the world-pack README in the same decision change, recording named WB-09 owner agreement and maintainer scope approval. Add the street dependency for its geometry-consuming work without introducing a reverse dependency from UF-03 to WB-09. If the removed work is judged insufficient or is already implemented, leave the decision blocked for a replacement cost trade, not accepted by assertion.
8. Discuss alternatives: infer roads from empty terrain (cannot identify intended continuity/frontage); reuse `stroke` with no identity (no network contract); duplicate plot geometry in WB-09 (two authorities); pathfinding/traffic graph (unnecessary scope). Link the accepted or pending ADR from docs/MAP_AUTHORING.md with its status visible.

## Allowed files

- docs/adr/0026-streets-as-authored-network.md
- docs/tasks/urban_form/README.md
- docs/tasks/urban_form/UF-01_adr_streets_as_network.md
- docs/tasks/urban_form/UF-03_street_primitive.md
- docs/tasks/world/WB-09_rrmap_v2_semantic_layer.md
- docs/tasks/world/README.md
- docs/MAP_AUTHORING.md
- TODO.md

These are the decision row's narrowed paths. If a competing ADR occupies 0026, substitute the next free, unreserved ADR path and obtain an exact amended write set for every affected citation before editing it. This contract-writing pass changes only this task document.

## Constraints and non-goals

- No parser, compiler, test, map or asset implementation in this row.
- No curved geometry, traffic simulation, navigation-cost graph, procedural city generator or map activation.
- Preserve historical authority: UF-02/R-1111 supplies the attested street register and Canon labels; the ADR cannot invent a street's 1343 existence or width.
- WB-09 remains the semantic authoring surface; WB-13 owns plot contents; WB-01..04 own relief; AR owns building materials and appearance; CO owns shore levels; WS owns water/sky. This is not a combined pack.
- The accepted ADR must be merged or human-approved before R-1112 starts. A rejection closes the decision only and blocks street implementation pending re-scope.

## Verification

```bash
ls docs/adr/
grep -rn "ADR 0026" docs/tasks TODO.md
grep -rn "ADR 0024" docs/tasks/world TODO.md
grep -c '^building ' content/maps/lower_town_slice.rrmap
grep -c '^style ' content/maps/lower_town_slice.rrmap
sed -n '45,145p' scripts/map/rrmap/map_rrmap_parser_statements.gd
python3 tools/generate_active_docs_report.py --check
git diff --check
```

- Independent Dev review: all five ADR sections, explicit units/tolerances, stable diagnostics and the 29-map no-street compatibility obligation are present; no implementation files changed.
- Named WB-09 owner review: R-981's removed geometry work and dependency/handoff match both contracts. Scope removal is identified by board ref, not only a local pack alias.
- Maintainer decision review: Status carries a named human and ISO date; removed scope has explicit agreement; UF-03 is not released on a merely proposed or rejected ADR.
- Verify docs/MAP_AUTHORING.md links the actual selected ADR path and labels whether it is accepted. Run the mandatory map-authoring documentation pre-commit gate from AGENTS.md when that document is amended.

## Doc updates

ADR 0026, the urban-form README and UF-03 contract, WB-09 contract and world README, MAP_AUTHORING and the R-1110/R-1112/R-981 durable task entries must describe one geometry authority. Record number substitutions consistently if the reservation changes. No ADR or shared document is edited while merely authoring this contract.

## TODO.md line

```text
- [ ] R-1110 | deps: none | deliverable: ADR 0026 for authored StreetNetwork and frontage authority, replacing WB-09/R-981 independent plot geometry with UF-03 consumption and recording owner agreement | verify: five-section ADR and named maintainer ISO-dated decision; WB-09 seam review; MAP_AUTHORING link; python3 tools/generate_active_docs_report.py --check; git diff --check
```


## Implementation record (2026-09-30)

Published [ADR 0026](../../adr/0026-streets-as-authored-network.md) as **Proposed**.
The UF-03 contract, urban/world pack summaries, WB-09 contract and MAP_AUTHORING
now state one proposed geometry authority and an explicit WB-09 scope exchange.
No runtime, parser, compiler, test, map or asset implementation is included.
No named owner agreement or human acceptance has been supplied; UF-03 remains
blocked. Task-board entries, not this document's legacy TODO example, own status.

### Independent review and verification

Code Reviewer (`dev-code-reviewer`), 2026-09-30: **technical PASS**, final review
session `e7b63fcb-6f14-4f98-8093-a82502bfe4ac`. The earlier endpoint/orphan
conflation and UF-03 severity shorthand were corrected. WB-09 seam review is a
technical PASS, not named human owner agreement. Human decision follow-up:
**R-1152 (P0)**; R-1110 remains in review and UF-03 remains blocked.

Host checks: active-docs analysis found zero issues; an alternate report under
`build/r1110/` passes `--check`; active-docs unit tests pass 5/5. The default
`docs/reports/active_markdown_report.md` was already stale before this task and
is not refreshed from the shared dirty worktree. Blueprint validation reports
29 maps, zero errors and 638 warnings (no warning suppression); world layout,
map audit, activation and conversion-plan Python gates pass. The complete Godot
suite was invoked (409 files) but reports failures in unrelated runtime tests and
exceeded a 600-second watchdog (exit 124); its gate is not claimed green. Default
report refresh is tracked as R-1153 (P2). No runtime or map file was changed by
this proposal.
