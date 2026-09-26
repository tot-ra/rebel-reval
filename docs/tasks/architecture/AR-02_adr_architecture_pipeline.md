# AR-02: ADR 0022 architectural asset pipeline, fidelity tiers and budget

Board row: **R-960**. Priority: high. Depends on: AR-01. Decision document - no code, no assets.

## Player-facing goal

None directly. This is the gate that stops AR-04..AR-12 from producing forty buildings the maintainer
then rejects, which is exactly what happened to the procedural mammals under **P0-209b**.

## Why this is needed

Three separate things are currently undecided and each one changes the shape of every production task:

1. **Kit or bespoke, and where the line falls.** The project already has a modular in-house generator
   (`tools/burgher_house_kit_common.py`, 82k, with procedural PBR surface functions) and it already has
   the opposite pattern - 54k of GDScript that assembles St Olaf, St Michael's convent and every wall
   tower from primitives at runtime with zero asset references.
2. **Provenance.** `docs/ASSET_STORAGE_POLICY.md` and `assets/SOURCES.csv` govern rights, but there is
   no ruling on whether licensed external architecture meshes may enter the runtime tree at all. The
   character pipeline has an explicit rule ("no vendor meshes at runtime", own mesh on retargeted
   skeleton); architecture has none.
3. **Budget.** There is no triangle or texture budget for a building. `docs/PERFORMANCE_REPORT.md`
   measures, `P0-183` polices oversized runtime GLBs, but nothing says what a merchant house or a
   convent range is allowed to cost, or at what distance it must drop to an LOD. `north_quarter` alone
   places 96 houses.

`AGENTS.md` also requires an ADR for a scope change of this size, with a named removal of
equivalent-cost scope.

## Deliverable

`docs/adr/0022-architectural-asset-pipeline.md` in the repository ADR format (Status / Context /
Decision / Alternatives / Consequences), deciding at minimum:

1. **Tier split.** Which building families are **kit-assembled** (ordinary fabric, high count, high
   reuse) and which are **bespoke** (landmark, low count, silhouette carries the district). The
   recommendation this pack is written against: kit for families 1-5 and 11 of AR-01, bespoke for 6-10.
   The maintainer may move the line; AR-04..AR-12 follow it.
2. **Provenance rule.** Whether licensed CC0 / CC-BY / commercial architecture meshes may ship in
   `assets/`, and if so under what conditions (rework required, ornament only, LOD only, none). State
   the answer for meshes and for textures separately - `assets/materials/pbr/building_variants` is
   already procedurally generated, and AR-03 has to know whether that must continue.
3. **Budgets**, per tier, as numbers a verifier can check:
   - triangles for LOD0 / LOD1 / LOD2 and the switch distances;
   - texture set resolution and channel set per surface family;
   - material count per building and the shared-material rule (the 96 houses of `north_quarter` cannot
     each own a unique material);
   - total on-disk budget for the pack, consistent with `docs/STORAGE_SIZE_BACKLOG.md`.
4. **Instancing and streaming contract.** How kit parts interact with
   `MapObjectChunkStreamer` and the `MapDefinition` fingerprint rule in `docs/MAP_AUTHORING.md`:
   generated building geometry is disposable output, never persisted, never keyed by node path or
   instance id.
5. **Visual acceptance protocol.** The named, repeatable review that a building set must pass, at the
   gameplay camera, in real maps, day and night, on both quality tiers - and the explicit statement
   that green tests do not substitute for it. Cite P0-209b as the precedent.
6. **Scope trade.** The named equivalent-cost scope being removed or deferred to pay for AR-03..AR-13,
   as `AGENTS.md` requires. Candidates already on the board, for the maintainer to choose from:
   `P0-180`/`P0-182` audio reduction, `P0-185` view3d extractions, `P0-194` stale plate refresh,
   `P0-198` ambient NPC gesture variety, or a deferral of AR-09..AR-12 out of the current wave.
7. **Amendment note** on [ADR 0018](../../adr/0018-saturated-hdr-fantasy-anime-visual-direction.md)
   and [ADR 0016](../../adr/0016-tiered-character-fidelity.md) if the architecture tiers need to mirror
   the character tiers, and on [ADR 0009](../../adr/0009-map-blueprint-authoring-architecture.md) if
   kit parts become blueprint-visible at all.

## Allowed files

- `docs/adr/0022-architectural-asset-pipeline.md` (new)
- `docs/ART_BIBLE.md` (pointer to the ADR only)
- `docs/ARCHITECTURE.md` (file-ownership rows for the new pipeline only)
- `TODO.md`

## Constraints and non-goals

- No code, no assets, no map edits, no new tools.
- Do not decide the content of any building set. AR-07..AR-12 own that.
- Do not weaken `docs/MAP_AUTHORING.md`. Kit geometry is view output; blueprint authoring, stable IDs,
  collision and navigation are untouched by this ADR.
- The ADR must be **merged or explicitly human-approved before AR-04 starts coding**, per the
  `AGENTS.md` scope-change rule.

## Verification

```bash
python3 tools/generate_active_docs_report.py --check
```

- The ADR has all five required sections and is numbered 0022, following 0021.
- All seven decisions above are answered with a concrete value, not "to be determined". A budget stated
  as a range is acceptable; a budget stated as "reasonable" is not.
- The scope trade names specific existing task ids and says whether they are removed or deferred.
- The visual acceptance protocol is reproducible: a reader can follow it without asking a question.
- Status is `Accepted` with the maintainer named, or `Proposed` with an explicit note that AR-04 is
  blocked until it is accepted.
- AR-01 is referenced as the dimension source, and every budget number is consistent with
  `docs/PERFORMANCE_REPORT.md` and `docs/ASSET_STORAGE_POLICY.md`.

## Doc updates

`docs/adr/0022-architectural-asset-pipeline.md`, `docs/ART_BIBLE.md`, `docs/ARCHITECTURE.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-960 | deps: R-959 | deliverable: docs/adr/0022-architectural-asset-pipeline.md deciding the kit-vs-bespoke tier split per building family, the provenance rule for external meshes and textures, numeric triangle/texture/material/LOD-distance and on-disk budgets per tier, the instancing and chunk-streaming contract that keeps generated geometry disposable, the named visual acceptance protocol that green tests cannot substitute for (P0-209b precedent), the named equivalent-cost scope trade, and any ADR 0016/0018/0009 amendment notes | allowed files: per docs/tasks/architecture/AR-02_adr_architecture_pipeline.md | verify: active docs check; ADR numbered 0022 with Status/Context/Decision/Alternatives/Consequences; all seven decisions carry concrete values; scope trade names existing task ids; acceptance protocol reproducible without clarification; budgets consistent with PERFORMANCE_REPORT and ASSET_STORAGE_POLICY; Accepted with maintainer named, or Proposed with AR-04 explicitly blocked
```
