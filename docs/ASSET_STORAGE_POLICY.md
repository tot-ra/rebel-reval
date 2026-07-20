# Repository Storage Policy

This document defines what belongs in Git, Git LFS, external storage, or local generated output for **Reval Rebel**. It supersedes the earlier asset-only threshold guidance and closes the P0-064 storage-hygiene decision.

## Baseline and goals

The 2026-07-21 audit found 1,392,730,231 tracked working-tree bytes (1.297 GiB). The largest owners were:

| Owner | Tracked size | Decision |
|------|------:|----------|
| `archive/` | 661.56 MiB | Approved but inactive source archive. Keep available until external storage is reproducible. |
| `music/` | 208.25 MiB | Runtime audio sources. Keep with provenance; use LFS for new or migrated binaries at least 10 MiB. |
| `history/` | 158.91 MiB | Historical research sources. Not runtime content; candidate for versioned external storage. |
| `bin/rr.zip` | 94.99 MiB | Generated release package. Remove from Git and reproduce through the documented export. |
| `quarantine/` | 26.17 MiB | Rights-review evidence. Keep isolated and checksummed until approved or safely removed. |

The policy optimizes clean-clone size without breaking runtime imports, asset provenance, license review, or access to source evidence.

## Ownership classes

| Class | Examples | Git ownership | Required metadata |
|------|----------|---------------|-------------------|
| Runtime | `project.godot`, `scenes/`, `scripts/`, `content/`, active `assets/`, `music/`, and `sounds/` | Track text normally. Track required binary media normally below 10 MiB and in Git LFS at or above 10 MiB. | Stable IDs where applicable; media row in `assets/SOURCES.csv`; matching Godot `*.import` sidecar. |
| Source | Schemas, authoring tools, approved editable art sources, and research needed to reproduce an accepted decision | Track text normally. Use Git LFS for binary files at or above 10 MiB, or approved versioned external storage for bulk sources. | Owner, source URL or retrieval location, license, immutable revision/checksum. |
| Archival | `archive/`, legacy `characters/`, `story/`, and inactive historical references | Keep out of runtime import and export. Existing files stay in Git until a verified migration exists; new bulk archives use external storage. | Classification and restoration procedure; media provenance where relevant. |
| Quarantine | `quarantine/` files with unknown, incomplete, or commercial-risk rights | Never reference from runtime. Existing evidence stays available for rights review until it can be approved or deleted. | Mirrored original path and `assets/SOURCES.csv` rights/approval status. |
| Generated | `.godot/`, `.import/`, `build/`, Python caches, benchmark JSON, temporary captures | Never track. Regenerate locally or in CI. | Generator command in documentation when the output is useful. |
| Release artifact | `.dmg`, `.zip`, `.app`, platform exports, packaged walkthrough output | Never track in source Git. CI or release hosting owns distribution and retention. | Source commit, export preset, Godot version, checksum, and release URL when published. |

`archive/.gdignore` and `quarantine/.gdignore` remain mandatory. Moving a file there changes runtime ownership, not its provenance path. `assets/SOURCES.csv` continues to use the original runtime-relative media path so restoration remains reviewable.

## Binary thresholds

- Files below 10 MiB may use standard Git when they are required runtime or source inputs.
- New binary files at least 10 MiB must use Git LFS or approved versioned external storage. Do not add another standard-Git exception.
- Bulk inactive sources approaching 100 MiB individually, or collections that create material clone cost, belong in external storage rather than LFS.
- Godot `*.import` files are small text metadata. Track them beside tracked media, but never put them in LFS.

Git LFS is only a valid destination after authenticated pull and push access is proven for contributors and CI. A pointer without retrievable remote content is data loss, not a migration.

## Temporary standard-Git exceptions

The repository predates this policy and still contains nine required or review-owned binaries at least 10 MiB. Their exact path, byte count, SHA-256, ownership, and migration task are recorded in [`storage_binary_exceptions.json`](./storage_binary_exceptions.json).

`python3 tools/verify_storage_hygiene.py` rejects:

- tracked generated or release paths
- any new standard-Git binary at least 10 MiB
- missing, stale, malformed, or checksum-mismatched exception rows

P0-070 owns migration of those exceptions and the bulk inactive archive. Until that task has an authenticated destination, immutable references, and a clean-clone retrieval proof, retaining the checked and provenance-covered source is safer than deleting or replacing it with an unavailable LFS pointer.

## Generated and release output

The following paths are local or CI output and are ignored:

- `/build/`, including `build/benchmarks/*.json` and exported packages
- `/bin/`, including the removed legacy `bin/rr.zip`
- `.godot/` and legacy `.import/`
- `__pycache__/`, `*.pyc`, `*.pyo`, `.pytest_cache/`, `.mypy_cache/`, and `.ruff_cache/`

Generate benchmark evidence with `tools/benchmarks/run_large_map_benchmark.sh`. Generate the macOS package with:

```bash
mkdir -p build
godot --headless --export-release "rr" ./build/rr.dmg
test -s ./build/rr.dmg
```

Published release artifacts belong in the release host or CI artifact storage, with retention chosen there. They do not belong under `bin/` in Git.

## LFS retrieval and failure behavior

For repositories containing LFS objects:

```bash
git lfs install
git lfs pull
```

CI checkout must enable LFS. If a required object cannot be fetched, import/export must fail rather than silently substitute a pointer. A temporary placeholder may unblock local development, but it must not be committed as a substitute for the unavailable source.

## External-storage migration contract

A binary may leave Git only when the same change records all of the following:

1. A stable, access-controlled retrieval URL or object key and the owning team/service.
2. Exact byte count and SHA-256 for every moved file, preferably in a machine-readable manifest.
3. Source, license, and approval data, preserving `assets/SOURCES.csv` entries for media.
4. A documented fetch or restore command that recreates the expected repository-relative path.
5. CI and clean-clone proof that import, tests, and export work with fetched runtime sources and without inactive archives.
6. Maintainer approval before any shared-history rewrite. Removing a path from the current tree does not remove old Git objects from repository history.

If the destination is unavailable or its license/access contract is unclear, do not delete the tracked source.

## Verification

Run from the repository root:

```bash
python3 tools/verify_storage_hygiene.py
python3 tools/validate_asset_sources.py
python3 tools/generate_asset_inventory.py --check
godot --headless --editor --quit
mkdir -p build && godot --headless --export-release "rr" ./build/rr.dmg
test -s ./build/rr.dmg
```

The storage validator is also covered by Python discovery and CI. Import and export generate ignored output only; `git status --short` must remain unchanged after verification except for intentional source edits already under review.
