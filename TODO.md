# Executable work

The project task board is the preferred operational queue for claims and progress.
This file remains the durable/legacy ID index expected by `README.md`, `AGENTS.md`, and active-doc link checks.

| Document | Role |
|----------|------|
| Project task board (`tasks` tool) | Claims, WIP, verification evidence |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Current focus and coordination history |
| [`docs/TASK_ARCHIVE.md`](docs/TASK_ARCHIVE.md) | Completed legacy rows |
| [`docs/STORAGE_SIZE_BACKLOG.md`](docs/STORAGE_SIZE_BACKLOG.md) | Open storage and file-size contracts (**P0-177**..**P0-187**) |
| [`docs/LEGACY_REINTRODUCTION.md`](docs/LEGACY_REINTRODUCTION.md) | ADR 0017 / P7 inventory |

## Storage and file-size (active)

See [`docs/STORAGE_SIZE_BACKLOG.md`](docs/STORAGE_SIZE_BACKLOG.md) for full deliverable/verify contracts.

- [x] P0-177 | deps: none | deliverable: repository size audit + claimable follow-ups | verify: report and backlog landed
- [ ] P0-178 | deps: P0-177 | deliverable: green storage hygiene for `generated/` >=10 MiB binaries | verify: `python3 tools/verify_storage_hygiene.py`
- [ ] P0-179 | deps: P0-178 | deliverable: prune rejected/duplicate `generated/comfyui` candidates | verify: hygiene + asset validators green
- [ ] P0-180 | deps: P0-177 | deliverable: curated music take reduction with MusicDirector proof | verify: soundtrack tests + recorded byte drop
- [ ] P0-181 | deps: P0-177 | deliverable: research-plate dimension/byte policy for `history/reference` | verify: plate fetch `--verify`
- [ ] P0-182 | deps: P0-180 | deliverable: runtime audio bitrate/size budget | verify: lint/validator + audio tests
- [ ] P0-183 | deps: P0-177 | deliverable: oversized runtime GLB budgets (oak + shared characters) | verify: asset lint + focused Godot filters
- [ ] P0-184 | deps: P0-177 | deliverable: refresh ARCHITECTURE large-file audit to current LOC inventory | verify: table matches `scripts/**/*.gd`
- [ ] P0-185 | deps: P0-184 | deliverable: justified view3d hotspot extractions only | verify: named focused filters
- [ ] P0-186 | deps: P0-177 | deliverable: `docs/reports/images` retention/compression rule | verify: acceptance image readers + byte drop
- [ ] P0-187 | deps: P0-177 | deliverable: archive aged ROADMAP coordination notes | verify: Current focus intact + active-docs check

New major work still requires the task contract in [`AGENTS.md`](AGENTS.md): player-facing goal, allowed files, deps, constraints, deliverable, verify.
