# AR-13: architectural repetition and silhouette audit gate

Board row: **R-971**. Priority: high. Depends on: AR-05, AR-06, AR-07, AR-08, AR-09, AR-10, AR-11, AR-12.

## Player-facing goal

The "too generic" complaint cannot come back silently. Any future change that drops a map's building
variety, pushes a roof-cover share outside its historical band, or reintroduces a repeating row fails a
command rather than surviving until someone notices it in play.

## Why this is needed

Every other task in this pack proves itself with its own captures and its own review. Nothing keeps them
proven. The project already has the right precedent -
`docs/WORLD_BUILDING_VISUAL_GATE.md` with `tools/verify_world_building_visual_gate.py`, which is
deliberately fail-closed and requires a named human reviewer, an ISO date and an evidence path for each
rubric row, including **`landmark_architecture`** and **repetition** rows that currently have no
architecture evidence behind them.

`tools/verify_building_variety.py` is introduced by AR-05 as a per-map reporter. AR-13 turns it into a
gate with committed thresholds, and connects it to the visual gate so the architectural work is part of
the release decision rather than a set of one-off reports.

## Deliverable

1. **`tools/verify_building_variety.py` promoted to a gate**, with thresholds committed in
   `docs/data/building_variety_budget.json`, per map:
   - **distinct configurations** - minimum count and minimum ratio to the map's house record count;
   - **identical-neighbour runs** - maximum length along a street front;
   - **nearest identical appearance** - the minimum world distance between two buildings with the same
     full configuration, so clones are at least far apart;
   - **realised roof-cover shares** - must fall inside the `docs/HISTORICAL_AUDIT.md` band for that map;
   - **realised wall-material mix** - must fall inside the same card's band;
   - **part-reuse histogram** - no single kit part may account for more than a stated share of a map's
     visible building surface, which is what makes kit-built districts read as kit-built;
   - **silhouette diversity** - distinct (eave height, ridge height, gable form, frontage bay count)
     tuples per map.

   Fail-closed: a map with no budget row is a failure, not a skip.

2. **Landmark uniqueness check** - every bespoke landmark from AR-07..AR-11 appears exactly where its ID
   says and nowhere else, and no two named landmarks share a silhouette signature. A reused convent range
   standing in for a guild hall must fail.

3. **Visual gate rows wired.** `docs/data/world_building_visual_benchmark.json` gains, for every exterior
   map touched by this pack, `landmark_architecture` and repetition rubric rows pointing at the AR
   capture evidence, with named reviewers and ISO dates. The gate's existing fail-closed behaviour is
   preserved - this task supplies evidence, it does not relax the gate.

4. **A district architecture contact sheet** per exterior map: one plate per map at a fixed vista framing,
   collected in `docs/reports/images/ar13_districts/`, so a reviewer can see all districts side by side and
   judge whether they read as different places.

5. **Pre-commit wiring.** `tools/run_pre_commit_checks.sh` runs the variety gate when a file under
   `assets/buildings/`, `scripts/map/view3d/architecture_*`, `scripts/map/view3d/map_view_building_*`,
   `scripts/map/view3d/map_view_mesh_builder_building_*` or `docs/data/building_variety_budget.json`
   is staged, alongside the existing map gates in `AGENTS.md`.

6. **The pack's closing report**, `docs/reports/ar13_architecture_pack_review.md`: the measured before and
   after for every number in [`README.md`](README.md)'s baseline table, so the improvement is a figure and
   not an impression.

## Allowed files

- `tools/verify_building_variety.py`
- `docs/data/building_variety_budget.json` (new)
- `tests/python/test_verify_building_variety.py`
- `tools/verify_world_building_visual_gate.py` (row wiring only)
- `docs/data/world_building_visual_benchmark.json`
- `tools/run_pre_commit_checks.sh`
- `tools/capture_ar13_district_sheet.gd` (+ `.uid`, new)
- `docs/WORLD_BUILDING_VISUAL_GATE.md`, `docs/ART_BIBLE.md`, `docs/ARCHITECTURE_KIT.md`,
  `docs/reports/ar13_architecture_pack_review.md`, `docs/reports/images/ar13_districts/`,
  `AGENTS.md` (pre-commit gate row only), `TODO.md`

## Constraints and non-goals

- No assets, no geometry, no shaders, no map edits, no loader changes. This task measures and gates.
- Do not weaken `tools/verify_world_building_visual_gate.py`. It is fail-closed by design and stays that
  way; a `BLOCKED` result because a human review is pending is the correct behaviour, not a bug to fix.
- Thresholds must be set from the **measured post-AR state**, not aspirationally, and the report must state
  the headroom between the measured value and the threshold for every map. A threshold that the current
  build already fails is a failed task, not a backlog item.
- Do not add a metric that can be satisfied by adding noise. Each threshold must be defensible as "a
  player would notice if this got worse".
- Do not make the gate depend on rendering. It reads compiled `MapDefinition` data and the kit catalogue,
  so it stays fast and headless. The rendered evidence lives in the visual gate rows.

## Verification

```bash
python3 -m unittest tests.python.test_verify_building_variety -v
python3 tools/verify_building_variety.py
python3 tools/verify_world_building_visual_gate.py
python3 tools/verify_world_building_visual_gate.py --json
tools/run_pre_commit_checks.sh all
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
python3 tools/verify_map_audit.py && python3 tools/verify_map_activation.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

- `test_verify_building_variety.py` asserts each of the seven metrics independently, including **negative
  fixtures**: a synthetic map with one repeated configuration fails; a map with a roof share outside its
  band fails; a map with no budget row fails; two named landmarks sharing a silhouette signature fail.
- `verify_building_variety.py` returns zero on the real repository and prints the per-map table with the
  headroom column.
- `verify_world_building_visual_gate.py` includes the new architecture rows and its result is explainable:
  either it passes, or every remaining blocker is a named pending human review, listed in the report.
- The pre-commit hook fires on a staged `assets/buildings/` change and not on an unrelated one - prove
  both with a fixture, as `R-926` did for the class-cache guard.
- `docs/reports/ar13_architecture_pack_review.md` reproduces the [`README.md`](README.md) baseline table
  with a measured "after" column for every row, including the 362 / 43 / 319 / 6 / 0 figures.
- The district contact sheet has one plate per exterior map at the same framing.
- **Named human review** of the contact sheet, answering the maintainer's original question directly: do
  the districts read as different, historically specific places, and is the "too generic" complaint
  resolved. This is the acceptance line for the whole pack.

## Doc updates

`docs/WORLD_BUILDING_VISUAL_GATE.md`, `docs/ART_BIBLE.md`, `docs/ARCHITECTURE_KIT.md`,
`docs/reports/ar13_architecture_pack_review.md`, `AGENTS.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-971 | deps: R-963,R-964,R-965,R-966,R-967,R-968,R-969,R-970 | deliverable: tools/verify_building_variety.py promoted to a fail-closed gate with committed per-map thresholds in docs/data/building_variety_budget.json for distinct configurations, identical-neighbour run length, minimum world distance between identical appearances, realised roof-cover and wall-material shares against the HISTORICAL_AUDIT bands, part-reuse histogram and silhouette-tuple diversity; a landmark uniqueness check; architecture rows wired into docs/data/world_building_visual_benchmark.json; a fixed-framing district contact sheet; pre-commit wiring for assets/buildings and the architecture scripts; and docs/reports/ar13_architecture_pack_review.md restating the pack baseline table with measured after values | allowed files: per docs/tasks/architecture/AR-13_repetition_audit_gate.md | verify: python verifier unittest with negative fixtures for a repeated-configuration map, an out-of-band roof share, a missing budget row and two landmarks sharing a silhouette signature; verify_building_variety zero on the real repo with a per-map headroom table; world-building visual gate run with every remaining blocker a named pending human review; pre-commit fixture proving the hook fires on a staged assets/buildings change and not on an unrelated one; full Godot suite; map audit and activation; active docs; git diff --check; thresholds set from the measured post-AR state with stated headroom and no currently-failing map; one contact-sheet plate per exterior map at fixed framing; named human review answering whether the districts read as different historically specific places and the generic complaint is resolved
```
