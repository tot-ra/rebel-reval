# Canon Keeper playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Canon Keeper role.

## Role-specific lessons
- Documentation contract smoke checks should normalize case for human-facing confidence labels. `Attested typology` and `attested typology` carry the same decision.
- Closing a research `R-###` dossier does not put historically accurate fabric into the game. Producer follow-up rows must name the target map anachronism and Brief ship decisions.
- Renaming a `docs/CANON.md` heading breaks auto-generated anchors (`BROKEN_ANCHOR`). Keep a stable HTML `<a id="...">` alias for the old slug when widening a section, then rerun `python3 tools/generate_active_docs_report.py --check`.
- A canon task that changes TODO structure can make `docs/reports/active_markdown_report.md` stale. If the task allowlist excludes the generated report, keep the scoped change and report the refresh as a separate follow-up.
