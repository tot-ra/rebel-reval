# Researcher playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Researcher role.

## Role-specific lessons
- Verify MIME type and file signature before treating a download as a PDF or image. OJS, museum, and archive endpoints often return HTML viewers, interstitials, or anti-bot pages.
- An access blocker is not a historical no-hit. Record HTTP content type, final URL, credentials boundary, and zero-folio or timeout limits. Keep `null` fields unchanged until the source is actually readable.
- Rights-blocked media: preserve the verified fallback. Never download or register an asset from metadata, regional relevance, or a CC BY-NC page. Do not claim an email was sent without an authenticated mail channel and provider message ID.
- Copy the exact live archive permalink from the dossier before probing. A reconstructed or translated URL is a command-construction failure, not evidence. Isolate each response body so a TLS failure cannot reuse stale HTML.
- `python3 tools/verify_historical_dossier.py` can stop on missing registry cards or absent legacy `TODO.md`. Record that baseline and use scoped dossier, index-link, and plate checks. Do not fabricate compatibility files.
- `history/reference/plates.csv` uses named fields (`plate_id`, `slug`, `status`, `local_path`, `sha256`). Link-only rows are valid when status is `linked` and local/checksum fields are empty. Parse with `csv.DictReader` and handle a `None` key for extra delimiters.
- Research-index dossier links can be embedded inside domain-table cells. Scan all Markdown destinations and resolve `dossiers/` targets from `history/`.
- Scope source-number checks to the `## Sources` section. Inline `[1][2]` markers are not source-list entries. Append a matching source row in the same change as a new numbered citation.
- After inserting an index or dossier row, re-read the bounded table and grep the task ref. A successful replacement can relocate a neighbouring row. Validate the newly delivered dossier's section contract; legacy parent headings are maintenance drift, not a production failure.
- Scoped smoke checks must match the document's live wording and emphasis. Do not require every confidence category, contiguous numbering across legacy dossiers, or an invented hyphenated phrase.
- When an official catalogue is reachable but images redirect to authenticated VAU/DGS, classify it as a zero-folio access blocker. Release the task to `todo` and link the existing authorized-access clearing task instead of creating a duplicate.
- Indexed search snippets are not verified inventory finds. Require object type, inventory number, context, and provenance. A later-state digitized page must not be promoted into a missing phase-specific measurement.
- GeoJSON probes must inspect `geometry.type` before traversing coordinates. A collection can mix polygons and point anchors.
- Use `tools/research/fetch_reference_plates.py` for plate manifest work. Keep `image_url` / `local_path` / `sha256` empty on link-only rows.
- In a no-claim research scout, clean index-link and plate checks are enough when open rows are already in review or typed access blockers. Do not invent backlog to fill capacity.
- Task-pack confidence words (bounded reconstruction, reconstructed, speculative) are not a second canon. Map them onto `docs/CANON.md` (`attested`, `plausible composite`, `folklore`, `invented`) and write `unknown` instead of inventing a number. A later wreck or ethnographic reconstruction stays a labelled comparandum, not a 1343 measurement.
- A published maststep-to-keelson station is not an LOA fraction when the stem is missing. Publish the station and the wreck-length caveat. Do not divide by excavated wreck length to invent an LOA%.
- A copyrighted DIGAR viewer or a paywalled museum monograph is an access blocker, not a historical no-hit. Leave the field `unknown` and name the clearing pages. Do not infer a missing fitting from ship-type analogy. If DIGAR marks the record unavailable on both the public network and the National Library intranet, stop: that is a physical-copy blocker (shop / Raamatukoi), not a login retry. Conservator blogs that name hardware on a later sibling wreck are not a hang for the unread hull.
- A paywalled popular article that names a year but cites no folio in the public extract is **B/C** or `unknown`, not an attested first-mention. Do not let a later tourist rebuild date (for example 1375 Cat's Well) overwrite an earlier secondary name-year, and do not hang that year on an unrelated H-register row.
- When a source compiles names for several towns or periods, read every entry under the right heading before citing it. A Tartu form is not Tallinn evidence, and a "shoe street" form belongs to Kinga, not Kuninga. Record the earliest form the cited source gives, not the first one a dossier quoted.
