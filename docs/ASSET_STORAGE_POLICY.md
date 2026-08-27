# Repository Storage Policy

This document defines what belongs in Git, Git LFS, external storage, or local generated output for **Reval Rebel**. It supersedes the earlier asset-only threshold guidance, closes the P0-064 storage-hygiene decision, and records the P0-070 Git LFS migration.

## Baseline and goals

The 2026-07-21 P0-064 audit found 1,392,730,231 tracked working-tree bytes (1.297 GiB). The largest owners were:

| Owner | Tracked size | Decision |
|------|------:|----------|
| `archive/` | 318.15 MiB at P0-070 migration | Approved but inactive source archive. Store in GitHub LFS and skip by default fetch. |
| `music/` | 208.25 MiB | Runtime audio sources. Keep with provenance; use LFS for migrated or new binaries at least 10 MiB. |
| `history/` | 158.91 MiB | Historical research sources. Store binary references in LFS and skip by default fetch. |
| `bin/rr.zip` | 94.99 MiB | Generated release package. Remove from Git and reproduce through the documented export. |
| `quarantine/` | 26.17 MiB | Rights-review evidence. Keep isolated and checksummed until approved or safely removed. |

The policy optimizes normal clone size without breaking runtime imports, asset provenance, license review, or on-demand access to source evidence.

## Ownership classes

| Class | Examples | Git ownership | Required metadata |
|------|----------|---------------|-------------------|
| Runtime | `project.godot`, `scenes/`, `scripts/`, `content/`, active `assets/`, `music/`, and `sounds/` | Track text normally. Track required binary media normally below 10 MiB and in Git LFS at or above 10 MiB. | Stable IDs where applicable; media row in `assets/SOURCES.csv`; matching Godot `*.import` sidecar. |
| Source | Schemas, authoring tools, approved editable art sources, and research needed to reproduce an accepted decision | Track text normally. Use Git LFS for binary files at or above 10 MiB, or approved versioned external storage for bulk sources. | Owner, source URL or retrieval location, license, immutable revision/checksum. |
| Archival | `archive/`, legacy `characters/`, `story/`, and inactive historical references | Keep out of runtime import and export. Track migrated binary corpora in LFS with default fetch exclusions; new bulk archives may use approved external storage. | Classification, rights status, checksum, and restoration procedure; media provenance where relevant. |
| Quarantine | `quarantine/` files with unknown, incomplete, or commercial-risk rights | Never reference from runtime. Existing evidence stays available for rights review until it can be approved or deleted. | Mirrored original path and `assets/SOURCES.csv` rights/approval status. |
| Generated | `.godot/`, `.import/`, `build/`, Python caches, benchmark JSON, temporary captures | Never track. Regenerate locally or in CI. | Generator command in documentation when the output is useful. |
| Release artifact | `.dmg`, `.zip`, `.app`, platform exports, packaged walkthrough output | Never track in source Git. CI or release hosting owns distribution and retention. | Source commit, export preset, Godot version, checksum, and release URL when published. |

`archive/.gdignore`, `history/.gdignore`, `story/.gdignore`, and `quarantine/.gdignore` keep non-runtime corpora out of Godot import/export. `assets/SOURCES.csv` continues to use original runtime-relative media paths for archived audio so restoration remains reviewable.

## Binary thresholds

- Files below 10 MiB may use standard Git when they are required runtime or source inputs.
- New binary files at least 10 MiB must use Git LFS or approved versioned external storage. Do not add another standard-Git exception.
- Bulk inactive collections should be skipped by default fetch or placed in approved external storage so they do not create normal clone cost.
- Godot `*.import` files are small text metadata. Track them beside tracked media, but never put them in LFS.

Git LFS is only a valid destination after authenticated pull and push access is proven for contributors and CI. A pointer without retrievable remote content is data loss, not a migration.

## Standard-Git exceptions

The repository originally contained nine standard-Git binaries at least 10 MiB. P0-070 migrated those files and the eligible archive/research corpora to GitHub LFS. [`storage_binary_exceptions.json`](./storage_binary_exceptions.json) must now remain an empty JSON array.

`python3 tools/verify_storage_hygiene.py` rejects:

- tracked generated or release paths
- any new standard-Git binary at least 10 MiB
- missing, stale, malformed, or checksum-mismatched exception rows

Do not add another exception without a separately approved task and documented retrieval risk; the normal path is Git LFS or versioned external storage.

## Git LFS migration

P0-070 migrated the initial 110 current-tree objects totaling 569,387,736 bytes to authenticated GitHub LFS without rewriting shared history. Subsequent runtime audio and research-plate additions bring the current manifest to 281 objects:

| Scope | Objects | Bytes | Default checkout |
|------|------:|------:|------------------|
| Runtime audio | 34 | 212,222,440 | Restored explicitly by CI and `tools/restore_lfs_assets.sh runtime`. |
| Inactive audio archive | 26 | 154,526,695 | Excluded by `.lfsconfig`; restore on demand. |
| Historical research media | 209 | 532,699,256 | Excluded by `.lfsconfig`; reference-only rights status is preserved. |
| Legacy narrative images | 12 | 46,584,682 | Excluded by `.lfsconfig`; archive-only rights status is preserved. |

[`lfs_assets.json`](./lfs_assets.json) is the authoritative machine-readable manifest. Every row records repository-relative path, exact bytes, SHA-256/LFS object ID, owner, license or explicit rights uncertainty, approval, source reference, and scope. GitHub repository `tot-ra/rebel-reval` owns storage at remote `origin`; upload and download authorization were proven over SSH before migration, and every object must be uploaded before the pointer commit.

The migration is deliberately current-tree-only. Old standard-Git blobs remain in shared history until maintainers separately approve a coordinated history rewrite.

## LFS retrieval and failure behavior

Normal checkouts intentionally leave inactive archive, research, and narrative LFS objects as pointers. Restore the 34 runtime objects, including the shared battle library, before import, test, or export:

```bash
tools/restore_lfs_assets.sh runtime
```

Restore another scope, or the complete source corpus, only when needed:

```bash
tools/restore_lfs_assets.sh archive
tools/restore_lfs_assets.sh research
tools/restore_lfs_assets.sh narrative
tools/restore_lfs_assets.sh all
```

The script installs repository-local Git LFS hooks, overrides `.lfsconfig` exclusions for the requested scope, downloads from `origin`, and verifies exact bytes and SHA-256 against `docs/lfs_assets.json`. `python3 tools/manage_lfs_assets.py verify` validates all indexed pointers without requiring inactive objects to be materialized. CI restores and verifies the runtime scope before Godot import and export.

If a required object cannot be fetched, import/export must fail rather than silently substitute a pointer. A temporary placeholder may unblock local development, but it must not be committed as a substitute for the unavailable source.

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

## External-storage migration contract

A binary may leave Git or LFS only when the same change records all of the following:

1. A stable, access-controlled retrieval URL or object key and the owning team/service.
2. Exact byte count and SHA-256 for every moved file, preferably in a machine-readable manifest.
3. Source, license, and approval data, preserving `assets/SOURCES.csv` entries for media.
4. A documented fetch or restore command that recreates the expected repository-relative path.
5. CI and clean-clone proof that import, tests, and export work with fetched runtime sources and without inactive archives.
6. Maintainer approval before any shared-history rewrite. Removing a path from the current tree does not remove old Git objects from repository history.

If the destination is unavailable or its license/access contract is unclear, do not delete the tracked source.

## ComfyUI generated candidate retention (`generated/comfyui/`)

Tracked `generated/comfyui/**` is pipeline evidence, not runtime import surface. Keep manifests, workflow JSON, audit reports, generator scripts, and production Blender outputs that still reproduce an accepted runtime asset.

Remove without LFS migration when any of the following holds:

1. A fauna or livestock audit marks the Hunyuan candidate `rejected_for_production` or an equivalent overall rejected verdict. Delete candidate GLBs and cleanup experiment meshes; retain `candidate_audit.json`, `candidate_workflow.json`, `state.json`, and markdown reports with SHA-256 checksums.
2. A ComfyUI run dumps a UUID-prefixed GLB beside a canonical named copy with identical bytes. Keep the canonical path inside the experiment bundle; delete the root-level UUID dump.
3. A superseded experiment bundle (for example `pack_horse_v2` replaced by `pack_horse_v3`) no longer feeds runtime assets. Delete its candidate GLB when the successor bundle documents the retained checksum and reproduction path.

Do not delete pending or accepted candidate GLBs solely for size unless they also fail hygiene (standard Git at or above 10 MiB) or an approved task names the path. Record removals in the bundle `state.json` `candidate_note` field, matching the `bird_wader_v1` pattern.

## Evidence image retention (`docs/reports/images/`)

Acceptance captures, README walkthrough frames, and closed-task report plates live under `docs/reports/images/`. They are documentation evidence, not runtime imports. The tree is excluded from Godot import/export through [`docs/reports/images/.gdignore`](./reports/images/.gdignore); do not add tracked `*.import` sidecars there.

| Tier | Examples | Format / size rule | On close |
|------|----------|--------------------|----------|
| Active acceptance | `view3d/`, `p0_102_environment_kit/`, `adr0018_calibration/`, `demo_walkthrough/`, `nunnatorn/`, `r713_sky_weather/`, `r715_water/` | PNG only; standard captures at `1280x720` unless a task names a higher cap (for example README walkthrough at `1920x1080`); active PNG soft cap 1.5 MiB | Keep local; regenerate through the owned capture tool when stale |
| Archived evidence | `renderer_evaluation/`, `characters/`, `combat/`, `fauna/`, `population/`, `p039_blind_pack/` | PNG/JPEG/WebP allowed after lossless optimize; archived PNG soft cap 1.0 MiB | Run `python3 tools/optimize_evidence_images.py`; move to LFS-skip only with manifest + verifier update |

Manifest and byte budgets: [`docs/data/evidence_image_retention.json`](./data/evidence_image_retention.json). Closed directories must stay listed in `archived_directories` with the owning task id. New acceptance sets must be added to `active_directories` and, when they gate CI or slice sign-off, to `active_acceptance_verifiers`.

```bash
python3 tools/verify_evidence_image_retention.py
python3 tools/verify_evidence_image_retention.py --run-acceptance
python3 tools/optimize_evidence_images.py
```

## Verification

Run from the repository root:

```bash
python3 tools/manage_lfs_assets.py verify
tools/restore_lfs_assets.sh runtime
python3 tools/verify_storage_hygiene.py
python3 tools/verify_evidence_image_retention.py
python3 tools/validate_asset_sources.py
python3 tools/generate_asset_inventory.py --check
godot --headless --editor --quit
mkdir -p build && godot --headless --export-release "rr" ./build/rr.dmg
test -s ./build/rr.dmg
```

The storage validators are covered by Python discovery and CI. Import and export generate ignored output only; `git status --short` must remain unchanged after verification except for intentional source edits already under review.
