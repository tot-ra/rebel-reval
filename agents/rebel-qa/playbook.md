# Qa playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Qa role.

## Role-specific lessons
- After a verify tool injects joypad motion into `ui_*` move actions, `action_release` every move action and wait until `ScreenDirectionInput.read_axis()` and velocity are zero before click-to-move. A `0.0` axis event is not enough; leftover `ui_right`/`ui_down` cancels navigation and walks the wrong way (R-1074).
- Keep content-only CI jobs scoped to content validators and their fixtures. The main CI job should run the fast Python contract subset (`test_pre_commit_hooks`, `test_project_configuration`, `test_test_commands`, `test_campaign_save_fixtures`, `test_verify_clean_checkout_load`), not full `unittest discover`.
- Do not edit runtime from a QA allowlist. Record reproduction and open a Dev row. Prefer Current focus over a historical report that says "do not start X".
- Close preflight findings in the gate report itself. Do not rewrite historical gate reports from a later allowlist that only names the new report.
- A Producer-only TODO or ROADMAP tick can leave `generate_active_docs_report.py --check` red on purpose. Create a bounded report-refresh row instead of regenerating the report from a QA or gate allowlist.
- `tools/validate_content.py` expects corpus root directories (`content/examples/valid content/examples/support`), not an individual JSON file.
- `python3 -m unittest` module targets must omit the `.py` suffix.
- Discover current test filenames before invoking a remembered module. The active-docs suite is `tests/python/test_active_docs_report.py`.
- `python3 tools/verify_historical_dossier.py` can fail on pre-existing registry-map coverage gaps. Keep that baseline separate from scoped dossier or plate verification.
- For evidence-only gates, capture expected-failing statuses separately. A green plate audit does not waive parser, shader, provenance, or renderer baseline failures.
- Do not promote machine-verified captures into human visual acceptance. Distinguish documentation studies from gameplay-camera evidence.
- Compatibility harbour `under_horizontal` plates can show only the water underside (flat sea plus a sky limb) while the same pose on Metal shows the crib or bed. Treat those GL frames as invalid geometry evidence and hand the renderer split to R-932. Do not restyle a crib or bed builder from them.
- A water renderer-parity investigation can close from the existing WS-07 / WS-13e plates plus `tools/probe_water_renderer_parity.py --check`. Do not wait for GPU recapture when Godot `--editor` already holds the tree. Shader or lighting edits belong on a Dev follow-up that names those files.
- Do not regenerate parity, walkability, or chunk-readiness fixtures from dirty WIP. Record the exact SHA or inventory drift and assign a dependent reconciliation task.
- Fail-closed visual gates must keep capture planning separate from evidence approval. A custom SceneTree probe that exits 0 is not a harness summary.
- Inspect a live evidence-manifest schema before validating files. Image paths may live under `plates[*].output` with `res://` prefixes, not a guessed `path` field.
- When a focused suite is blocked by a neighboring inactive map or unsupported RRMap command, run the remaining package tests separately and classify the foreign parser issue outside the claimed row.
- Project-configuration scene scans must exclude nested `.worktrees/`.
- macOS BSD `find` does not support GNU `-printf`.
- `tools/verify_supported_platform.sh` runs packaged-platform smoke before mounting the DMG. A MapViewRuntime parse defect fails that entrypoint and never reaches install/start/save/load/exit.
- For Act 1 packaging, keep the DMG gitignored and force-add only the small SHA fingerprint sidecars so QA can bind the release without committing a multi-gigabyte binary.
- After a batch returns non-zero without a reliable summary, inspect every saved per-suite log and classify wrapper failures separately from assertions and engine diagnostics.
- In-map gameplay-camera captures must focus a named street spawn or street anchor, call `MapView3D.sync_actor`, and set the shipped dimetric rotation explicitly. A long-route midpoint often sits inside roof mass, so actors and VFX vanish. Do not rerun a combined studio+in-map tool without a skip flag: it rewrites accepted studio plates.
- If the verify clause names a helper that is not in allowed files (a packet verifier, for example), update that helper in the same change. A stale identity list fails the stated verify even when the capture tool is correct.
- A filtered capture that rebuilds its manifest from a header will mark already-captured plates missing. Seed from the committed manifest and upsert by identity.
- For GL/Metal plate pairs, check the `renderer=` field the capture tool prints for every plate. Renderer flags passed through a zsh variable are not word-split and Godot silently falls back to Compatibility, so the "Metal" plate comes out byte-identical to the GL one.
- After multiplying a harbor `_open_water_cell` by `cell_size`, world matching that cell centre is the pass. `reval_harbor_north` deep water covers y=0..46, so the first max-score sample is often (4,4) and world=4.5 sits in-sea, not at the quay `GAMEPLAY_FOCUS`. Do not retune the finder from a camera-scale row, and do not treat that near-corner sea pose as a failed recapture.
- Judge particle and foliage effects at the shipped gameplay crop (about 21 px per metre at 720p), using 2x crops of the full frame. True-size leaves (under 10 cm) render as 1-2 px there, and particles emitted inside a crown are hidden by its own foliage. A distinct md5 per frame proves only that frames are not frozen, because wind sway changes every frame.
- When a capture picks a target from `tree_canopy_multimesh`, keep the target inside the map bounds. Surroundings-ring crowns carry the same tag but are not drawn at gameplay camera distance, so a strike on one shows nothing.
- Gameplay-camera walks in `reval_city.tscn` run the compressed day clock, so the third or fourth teleport lands at dusk. Set `city.runtime.cycle_progress` to the target value before each teleport and again after the streaming wait. Pick teleport points from `plan.json` streets, not plot centres: a point inside a footprint captures a dark interior.
