# Authenticated archive export intake

This directory accepts only lawful, provenance-preserving material supplied by the archive or captured from a producer-approved authenticated VAU/DGS session. Do not store VAU usernames, passwords, session cookies, bearer tokens, or private remote URLs in Git.

## Required companion metadata

Every submitted export must include a sidecar Markdown or JSON record containing:

- archive: `Rahvusarhiiv` / Tallinn City Archives as applicable;
- reference: `TLA.230.1.Aa2`;
- title and catalogue date span;
- access or supply date in UTC;
- authenticated VAU/DGS URL or archive delivery identifier, redacted to remove secrets;
- folio/page identifiers for every image or transcription;
- date coverage, including whether 1340-1343 was actually inspected;
- original wording and transcription policy, with uncertain readings marked;
- rights, redistribution, and archive permission terms;
- SHA-256 checksums for supplied files.

## Acceptance boundary

Catalogue HTML, anonymous AIS gallery previews, redirect targets, login-page captures, and unverified OCR are not folio evidence. They must not be placed here as if they clear R-502. A valid submission reaches folio-level content or is an archive-supplied scan/transcription traceable to `TLA.230.1.Aa2` and preserves the identifiers and provenance above.

The Research owner consumes an accepted export through R-499. Until then, downstream dossiers must retain their bounded access-blocker wording and must not infer a carter-owner hit or no-hit.
