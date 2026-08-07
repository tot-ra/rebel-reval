# Canon Keeper playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Canon Keeper role.

## Role-specific lessons
- Documentation contract smoke checks should normalize case for human-facing confidence labels; `Attested typology` and `attested typology` carry the same decision even when prose capitalization differs.
- Solid history dossiers need Producer follow-up rows that name the target map anachronism and Brief ship decisions; closing `R-###` alone does not put historically accurate fabric into the game.
- Renaming a `docs/CANON.md` heading breaks auto-generated anchors used by active docs (`BROKEN_ANCHOR`); keep a stable HTML `<a id="...">` alias for the old slug (for example `timeline-aprilmay-1343`) when widening a timeline section, then re-run `python3 tools/generate_active_docs_report.py --check`.
- A canon task that changes TODO structure can make `docs/reports/active_markdown_report.md` stale; if the task allowlist excludes the generated report, keep the scoped canon/TODO change and report the refresh as a separate follow-up instead of widening the commit.
