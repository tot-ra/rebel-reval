# Qa playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Qa role.

## Role-specific lessons
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
