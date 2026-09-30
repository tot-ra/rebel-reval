# UF-16: District master plans and a street-legibility visual gate

Board row: **R-1136**. Priority: high. Depends on: **R-1114**, **R-1115**.

## Player-facing goal

The player can recognise a district from its streets, see where a street leads, and distinguish its inhabited blocks, landmarks and open enclosures. Make the maintainer's Witcher 3 / Kingdom Come reference bar a repeatable evidence-and-human-review contract, not a claim that passing map validators proves urban design quality. Owner: QA, independent of the map authors; historical interpretation still needs Canon review.

## Why this is needed

Checked on 2026-09-30:

- tools/verify_world_building_visual_gate.py already implements the R-716 gate and accepts `--json` and `--manifest`. It checks **12 required capture categories**, **12 rubric criteria**, **5 automated checks**, **2 performance tiers**, a versioned comparison sheet, per-map `automated_density`, and a separately `approved` named human review. It has **zero street-legibility endpoint inventory checks**.
- docs/data/world_building_visual_benchmark.json has **31 source_path rows for 26 unique source maps**, not one row per district. Scene aliases share source maps. It also includes six sources classed as interiors by the streaming census: holy_spirit_church, kuldjala_interior, oleviste_church, st_olafs_guild_hall, toompea_small_castle and town_hall. Do not mistake all 31 rows for exterior districts or remove existing rows to make this task green.
- The complete streaming census identifies **20 exterior source maps** (10 Reval districts/harbours and 10 travel maps) and **9 interiors** among 29 sources. There is currently no docs/reports/district_master_plans directory. UF-05 and UF-06 author streets on **five** of those exterior maps; their completion does not mean all 20 have street primitives yet.
- Existing capture identity is `third_person_gameplay_scale`, **1920x1080**, locked Art Bible day/night exposure, authored day/midnight presets, clear/rain weather and wind seed **716**. The checked-in gate documentation says the overall matrix is **BLOCKED** pending evidence and human sign-offs. This row must add checks without erasing those blockers.

## Deliverable

1. **One master plan for each of the 20 exterior source maps below**, keyed by authored map ID, not scene alias. Each plan contains:
   - source `.rrmap`, canonical map/location IDs and associated benchmark row IDs;
   - named street skeleton, classes, widths, connections and endpoints, citing UF-02/R-1111 register rows; explicitly distinguish `attested`, `plausible composite`, `folklore` and `invented` assertions per Canon;
   - blocks and their uses, plot/frontage organization, landmark enclosures and owned open ground, with UF-09 register IDs when available;
   - sightlines from **every gate and every street end**, named visible destinations, camera positions/orientations and any intentional occlusion;
   - crowd/trade logic and deliberate width, frontage and alignment irregularities, without inventing runtime crowd behavior;
   - a column distinguishing what comes from the register, existing authored content or justified invention. A desired missing street/landmark remains a linked future task, never falsely described as present;
   - actual-versus-intended plan, capture inventory and written human review. Rural maps without an urban street must explain their road/path skeleton rather than fabricate town streets.
2. Extend the **existing verifier and existing manifest** with a `street_legibility` evidence packet tied to each exterior source. Preserve `schema_version=1`, `task_id=R-716` and existing category/rubric/automation lists; add a separate packet rather than replacing the 12-category contract. Share the same source packet across existing scene-alias rows, keeping all existing acceptance requirements intact.
3. Each packet records `source_map_id`, `master_plan`, source/compiled fingerprint, camera/settings identity, explicit expected gate IDs and street endpoint IDs, capture rows, skeleton overlay and named review evidence. Expected inventory comes from compiled streets plus map gates, not only the supplied image list; dropping an endpoint must fail. Any source lacking street primitives gets an explicit missing-network blocker and the existing owning task ref where available. Missing data is not an empty list that passes. Future absent tasks must be created through Producer, not left solely in a plan.
4. Require **two gameplay plates per expected view**: clear-weather noon (12:00) and midnight (00:00), with identical camera transform/framing and the existing locked exposures. Define view identity as `gate:<stable_id>` or `street_end:<street_id>:<endpoint_id>`; coincident views may reuse a plate only with explicit inventory coverage. Add **one top-down street-skeleton overlay per source**, showing IDs, gate connections, blocks, open enclosures and landmark anchors. For `G` gates and `E` street ends the coverage is `2*(G+E)+1` slots before justified physical-view deduplication. Report expected versus present slots for every source in both text and JSON output.
5. tools/capture_district_street_plates.gd is a new capture helper, not an alternative gate. Its proposed interface is `--map=<source_map_id> --view=<gate-or-endpoint-id> --time=noon|midnight --output=<path>` or `--map=<source_map_id> --overlay --output=<path>`. It must support one requested plate per process and exit; it must not change noon to midnight inside one running Godot instance. Store reproducible camera, time, weather, renderer, fingerprint and command metadata in the benchmark packet/master plan. The interface must be implemented and documented by this row before the example invocation below is executable.
6. A **named human** answers these exact questions in each plan, citing plates and the real ISO review date:
   1. Can you tell where you are from a street-level view?
   2. Does any view read as a repeated row of similar houses?
   3. Does the street lead somewhere you can see?

   Answers `yes / no / yes` are the desired result, with written reasons. Every `yes` to question 2 creates a concrete board follow-up identifying the source map, view, bounded fix, exact paths, owner, dependencies and verification. Negative answers to 1 or 3 likewise remain blocked until addressed. Record returned refs, never invented IDs. Producer triages placement issues to UF and appearance issues to AR-13/R-971. QA cannot certify human art judgement automatically or substitute a numerical regularity check for these answers.
7. Keep the original `human_review` approval separate and mandatory. The extension must reject missing plate files, incomplete inventories, absent overlays, missing/unapproved/undated human decisions and unresolved blocking findings. It may report that this task's evidence packet is delivered while the overall release gate remains BLOCKED; it must never claim overall release acceptance on that basis.

## Allowed files

The implementation row's exact documentation/tool paths are:

- docs/reports/district_master_plans/lower_town_slice.md
- docs/reports/district_master_plans/market_civic_quarter.md
- docs/reports/district_master_plans/monastery_quarter.md
- docs/reports/district_master_plans/north_quarter.md
- docs/reports/district_master_plans/south_quarter.md
- docs/reports/district_master_plans/toompea_quarter.md
- docs/reports/district_master_plans/archbishops_garden.md
- docs/reports/district_master_plans/viru_gate_foreland.md
- docs/reports/district_master_plans/reval_harbor_north.md
- docs/reports/district_master_plans/reval_harbor_east.md
- docs/reports/district_master_plans/world.saaremaa.md
- docs/reports/district_master_plans/world.padise.md
- docs/reports/district_master_plans/world.paide.md
- docs/reports/district_master_plans/world.parnu.md
- docs/reports/district_master_plans/world.poide.md
- docs/reports/district_master_plans/world.kanavere.md
- docs/reports/district_master_plans/world.sojamae.md
- docs/reports/district_master_plans/world.harju.md
- docs/reports/district_master_plans/world.sacred_grove.md
- docs/reports/district_master_plans/world.rebel_kings.md
- tools/verify_world_building_visual_gate.py
- docs/data/world_building_visual_benchmark.json
- tools/capture_district_street_plates.gd
- docs/WORLD_BUILDING_VISUAL_GATE.md
- docs/reports/images/district_streets/ (only the exact PNG output paths inventoried in the benchmark packets before capture; no other image directory)
- TODO.md

Bind the evidence directory's file list to the actual compiled endpoint census before capture work is claimed, so no unbounded wildcard grants extra assets. If a Godot UID sidecar or a new persistent test file is needed, obtain an explicit board-path amendment first; the export does not currently authorize those files. This contract-writing pass edits only this task document.

## Constraints and non-goals

- No map content, model, terrain, shader, gameplay or activation edits. Plans describe and review, not silently reauthor maps.
- Extend tools/verify_world_building_visual_gate.py; do not create a new `verify_street_visual_gate.py`, duplicate R-716 data or replace WB-10/AR-13 checks. UF-04 measures placement; AR-13 measures appearance; this row collects reproducible human evidence.
- Capture only through **tools/godot_render.sh**, real GPU, minimized without focus. Never launch a visible Godot window, use `GODOT_RENDER_VISIBLE=1`, or run a bare non-headless Godot command. Headless dummy-renderer output is not pixel evidence.
- **One Godot process per plate**, particularly the noon/midnight pair. Freeze time before capture and wait for calibrated rendering inside that process; no reused daytime light state at midnight.
- Keep docs/reports/images/.gdignore in place; generate no import sidecars under evidence. Respect the existing retention budget. Do not lower the fixed 1920x1080 capture contract to meet a file cap; use permitted lossless optimisation or seek a budget decision.
- Do not silently resolve the existing six-interior/alias matrix mismatch by deleting rows. Use explicit exterior-source membership for this extension. Register new UF-15 districts only through an authorized follow-up once they exist.
- Canon Keeper reviews historical claims; a named human reviews district legibility. Agent-generated prose, a manifest `pass` or a complete screenshot folder is not human approval.

## Verification

Existing exact commands:

```bash
python3 tools/verify_world_building_visual_gate.py
python3 tools/verify_world_building_visual_gate.py --json
python3 -m unittest tests.python.test_verify_world_building_visual_gate -v
python3 tools/generate_active_docs_report.py --check
python3 tools/verify_evidence_image_retention.py
test -f docs/reports/images/.gdignore
git diff --check
```

The real manifest may continue to exit **1** for pre-existing missing evidence. Record the before/after findings, prove no old requirement was removed, and distinguish extension-delivery verification from release acceptance. Exit **0** is valid only when every original and new requirement is genuinely accepted.

Reproducible negative checks use the verifier's existing API `verify_manifest(root, manifest)` with an in-memory deep copy of the real manifest, requiring no extra fixture write paths:

- Select a delivered exterior packet and replace one noon plate path with a nonexistent repository-relative path. The result must name that map/view/time as missing.
- Drop one required street endpoint, remove an overlay and delete a master-plan link in separate copies. Each must produce its own street-legibility error even when other legacy blockers exist.
- Change the named human approval to `pass`, blank the reviewer/date, or set question 2 to `yes` without a board ref. Each must remain blocked. Adding a fix task ref records work, not approval.
- A complete positive packet must have no extension-specific errors, while legacy R-716 blockers are still reported. Publish exact executable mutation snippets against the implemented packet schema in docs/WORLD_BUILDING_VISUAL_GATE.md. Run the existing unittest module unchanged; persistent additional tests need the path amendment noted above.

After the new helper is implemented, invoke each selected view separately (replace the inventory variables with actual stable IDs, not guessed gate names):

```bash
tools/godot_render.sh --script tools/capture_district_street_plates.gd -- --map="$MAP_ID" --view="$VIEW_ID" --time=noon --output="$NOON_PATH"
tools/godot_render.sh --script tools/capture_district_street_plates.gd -- --map="$MAP_ID" --view="$VIEW_ID" --time=midnight --output="$MIDNIGHT_PATH"
tools/godot_render.sh --script tools/capture_district_street_plates.gd -- --map="$MAP_ID" --overlay --output="$OVERLAY_PATH"
```

- Independent QA census review: 20 plans linked from WORLD_BUILDING_VISUAL_GATE, one per exterior source; all gates and street endpoints have both times plus one overlay per source. Explicitly report sources blocked on unauthored networks instead of recording false coverage.
- Named human district review: three written answers per district, reviewer identity and ISO date, cited plates and actionable board refs for every repeated-row finding. No unnamed or automated approval.
- Canon Keeper plan review: register-derived and invented assertions are distinguished; enclosures do not become house-filled blocks merely to satisfy a density metric.

## Doc updates

Link the 20 plans from docs/WORLD_BUILDING_VISUAL_GATE.md, describe the additive schema, commands, mutation checks, alias handling and human-review semantics, and update the existing benchmark with exact inventories and evidence paths. Put the task's durable line in TODO.md only when executing the row in the parent project. Missing art/map fixes become existing-row amendments or new concrete board follow-ups, not prose-only requests to improve the district.

## TODO.md line

```text
- [ ] R-1136 | deps: R-1114,R-1115 | deliverable: 20 exterior master plans and additive R-716 street-legibility packets covering every gate/street end at noon and midnight plus skeleton overlays and named human reviews | verify: existing visual verifier and unittest module; missing-plate/inventory/review negative checks; 20-plan coverage review; python3 tools/generate_active_docs_report.py --check; python3 tools/verify_evidence_image_retention.py; human review answers and board refs for repeated-row findings
```
