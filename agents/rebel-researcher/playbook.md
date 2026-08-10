# Researcher playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Researcher role.

## Role-specific lessons
- Before editing from a summarized audit, re-read the exact target line; a stale assumption can turn an already-correct permission into a failed replacement.
- When downloading research papers, verify the response MIME/file signature before passing it to PDF tools; OJS download links can return an HTML interstitial, so resolve the actual article-download URL first.
- Verify downloaded research-source MIME type and file signature before treating a download endpoint as a PDF; OJS and museum endpoints can return HTML viewers or interstitial pages.
- When web-search wrappers return truncated payloads or quota errors, pivot to direct official pages and scholarly sources, then state the evidence boundary instead of repeatedly retrying broad search.
- `python3 tools/verify_historical_dossier.py` currently fails on the pre-existing registry-map coverage gap (`holy_spirit_church` and `oleviste_church` missing dossier cards); keep this baseline failure separate from scoped dossier/plate verification.
- When an archive download endpoint returns HTML instead of the advertised file, verify the response MIME type and file signature before using it as evidence; prefer the repository's API content route or cite the catalog record and preserve the access limitation.
- When a research task finds a regionally correct media page without an explicit commercial license, treat it as a rights blocker: preserve the verified fallback, record the exact source URL and permission path, and never download or register the asset from metadata alone. If an external page also has TLS or API access errors, record that as evidence but do not treat it as permission.
- For rights-blocked media tasks, preserve the verified fallback and record access failures (rate limits, bot challenges, HTTP errors) as an evidence boundary; never substitute metadata, regional relevance, or an NC license for explicit commercial permission.
- For rights-blocked bird-audio integration, keep the existing commercial-compatible fallback unchanged when the regional candidate is metadata-only or CC BY-NC; record the exact source/permission boundary and create a permission-cleared follow-up instead of changing curated rows.
- A permission-cleared regional audio replacement cannot be completed from metadata or a non-commercial page: preserve the verified fallback, record the exact rights boundary, and hand off to the existing human-outreach task before changing the curated row or registering audio.
- Research dossier reciprocal-link edits need the exact live line re-read after summarized grep; similar-looking cross-reference text can differ by path depth or punctuation and make a targeted replacement fail.
- Direct DOI/handle fetches may return 403/500 even when indexed scholarly metadata is available; use the indexed abstract as comparative evidence, record the access boundary, and do not repeatedly retry broad fetches.
- A dossier-specific smoke check should validate required sections and evidence labels actually used by the dossier, not require every possible confidence category to appear in every file.
- The task board replaced the legacy `TODO.md`, so research-index link checks may report that pre-existing path as missing; exclude that known legacy link when validating a scoped dossier rather than widening the research task.
- When a research PDF endpoint returns HTML or an anti-bot interstitial, verify MIME type and the file signature before using `pdftotext`; preserve the source URL and pivot to an accessible official OCR or archive catalogue instead of treating the failed download as evidence.
- When a historical dossier's verifier assumes coordination files that are absent from the checkout, treat that as an environment baseline failure; run scoped source/diff checks and record the missing-path limitation instead of fabricating the file.
- A dossier smoke check should validate the confidence labels and evidence boundary actually used by the file, not require an arbitrary count of one label; distinguish scoped link failures from the known legacy `history/RESEARCH_INDEX.md -> ../TODO.md` task-board migration gap.
- The historical dossier unittest is stale in task-board repositories that no longer ship `TODO.md`; record its `FileNotFoundError` as a baseline limitation and use scoped dossier/index contract checks instead of creating a compatibility file.
- For permission/outreach tasks, never claim an email was sent without an authenticated mail channel and provider message ID; record the failed channel check with UTC time and create a maintainer follow-up instead.
- When reconciling a generated LFS manifest, do not assume every tracked research file has a central `plates.csv` fetched row; first classify legacy dossier/root files and preserve their source-specific attribution before writing any manifest changes.
- During research tool batching, validate each wrapper payload shape before dispatch; one malformed parallel step can fail an otherwise independent evidence sweep.
- When adding reciprocal dossier links, inspect the exact live cross-reference wording first; a semantically equivalent line can make an exact edit fail, so re-read the saved block and patch the actual boundary serially.
- MDZ OCR endpoints return XHTML, and AWB entries can cross page canvases; strip tags, normalize whitespace, and inspect adjacent canvases before classifying a missing token as an evidence gap.
- After an exact dossier edit misses because the live block differs from the earlier excerpt, re-read the current bounded section before retrying; preserve the existing evidence wording and apply only the new archival delta.
- If `generate_active_docs_report.py --check` reports a stale generated report plus pre-existing issue count while the scoped historical dossier links pass, do not regenerate or widen the research patch; record the baseline limitation and validate the changed dossier locally.
