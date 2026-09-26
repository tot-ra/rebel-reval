# AR-01: Reval 1343 building typology dossier

Board row: **R-959**. Priority: high. Depends on: none. Research only - no code, no assets.

## Player-facing goal

None directly. This is the number source that lets every later AR task produce a building a historian
would recognise instead of a box with a chosen wall height. Without it, AR-04..AR-12 invent proportions
and the result looks generic for the same reason the current fabric does.

## Why this is needed

`content/maps/lower_town_slice.rrmap` encodes its entire building vocabulary as `wall_height` in
centimetres plus a material keyword: `house.south.h120.09`, `house.east.h104.41`. There is no data
anywhere in the repository for bay width, storey line, gable form, window schedule, door height,
plinth height, pentice depth, cellar-hatch position or roof pitch per cover. `docs/HISTORICAL_AUDIT.md`
answers *how much* of each material and *how dense* each district is; it does not answer *what one
building is shaped like*.

## Deliverable

`docs/reports/reval_architecture_typology_1343.md` with one **typology card** per family below. Every
card carries a confidence label (`attested` / `plausible composite` / `folklore` / `invented`) per
`docs/CANON.md`, and every number carries its source row.

Families to cover:

1. **Lower Town stone merchant house (Diele house)** - frontage, plot depth, storey count, undercroft,
   `Diele` hall height, `Dornse` heated room, loft floors, hoist beam, stepped or triangular gable.
2. **Lower Town timber-frame merchant house** - frame module, sill beam, jetty or no jetty, infill.
3. **Horizontal-log dwelling** - log diameter, corner joint, course count, chimneyless smoke room.
4. **Craft `boda` / booth** - one-room frontage, pentice, shutter counter, workshop opening.
5. **Service and yard fabric** - storehouse, brewhouse, bath house, stable, barn, privy, root cellar.
6. **Ecclesiastical, Lower Town** - parish church nave/aisle bay, west tower, buttress, lancet, portal.
7. **Cistercian conventual range** - claustral range width, dorter, refectory, chapter house, oratory,
   undercroft vaulting, cloister walk bay.
8. **Toompea elite** - cathedral construction-phase mass, castle keep, curia, chancery.
9. **Civic** - town hall arcade bay, hall storey, hospital range, guild frontage, weighhouse.
10. **Fortification** - wall thickness and batter, putlog spacing, merlon rhythm, drum-tower diameter,
    wall-walk width, gate tower plan.
11. **Rural and coastal** - smoke cottage, barn dwelling, threshing barn, boat shed, drying shed,
    watermill, windmill.

Each card states, in metres and degrees where known:

- frontage x depth range, storey heights, eave height, ridge height;
- bay module and how openings sit on it;
- gable form and its pitch, per roof cover (tile / shingle / thatch / straw are different pitches);
- opening schedule: door height and width, window height and width by storey, shutter type, whether
  glazing is plausible in 1343 for that family;
- plinth and ground relationship: exposed cellar, external stair, hatch, pentice depth;
- surface treatment: coursing, joint width, render coverage, tar, limewash, soot;
- what is **excluded** for 1343 and why, cross-referenced to the `docs/HISTORICAL_AUDIT.md` cross-map
  exclusions.

Also required: a **source register** in the same format as `docs/HISTORICAL_AUDIT.md` H01-H24, extending
the numbering, and a short **"what the current fabric gets wrong"** table mapping each finding in
[`README.md`](README.md) root causes to the card that fixes it.

## Allowed files

- `docs/reports/reval_architecture_typology_1343.md` (new)
- `docs/HISTORICAL_AUDIT.md` (source register extension only)
- `docs/CANON.md` (confidence labels for newly named historical claims only)
- `TODO.md`

## Constraints and non-goals

- No code, no assets, no map edits, no ADR. AR-02 writes the ADR from this.
- Do not restate the `docs/HISTORICAL_AUDIT.md` density, roof-share or ground-surface targets. Reference
  them. This dossier is about **form**, that one is about **proportion of the map**.
- Prefer Estonian and Baltic archaeology and building-history sources over generic "medieval Europe"
  pattern books. Tallinn Lower Town excavation reports, Tallinna Linnamuuseum material,
  `history/AVE2011_Kadakas_Padise.pdf`, Muinsuskaitseamet registry entries and the existing
  `history/RESEARCH_INDEX.md` chain are the expected spine.
- Where no Baltic evidence exists, say so, give the nearest Hanseatic analogue (Lübeck, Visby, Riga),
  and label it `plausible composite`. Do not present an analogue as attested.
- Existing canon verdicts are not reopened here.

## Verification

```bash
python3 tools/generate_active_docs_report.py --check
python3 tools/archive_speculative_docs.py --dry-run
```

- Every one of the 11 families has a card, and every card has a confidence label and at least one
  source row.
- Every numeric range cites a source row id; a reviewer can pick any five numbers at random and trace
  each one.
- The "what the current fabric gets wrong" table covers all seven root causes in
  [`README.md`](README.md).
- The exclusion list reproduces the `docs/HISTORICAL_AUDIT.md` cross-map exclusions without
  contradicting them.
- Canon review: a second agent or the maintainer confirms no new claim is presented as `attested`
  without a primary or established-historiography source.

## Doc updates

`docs/reports/reval_architecture_typology_1343.md`, `docs/HISTORICAL_AUDIT.md` source register,
`docs/CANON.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-959 | deps: none | deliverable: docs/reports/reval_architecture_typology_1343.md with one sourced typology card per building family (stone Diele house, timber-frame house, log dwelling, craft boda, yard service fabric, parish church, Cistercian range, Toompea elite, civic, fortification, rural/coastal) giving frontage, storey and eave heights, bay module, gable form and pitch per roof cover, opening schedule, plinth/cellar/pentice practice, coursing and 1343 exclusions, each with a confidence label and a source row, plus an extended HISTORICAL_AUDIT source register and a table mapping the seven measured root causes to their card | allowed files: per docs/tasks/architecture/AR-01_building_typology_dossier.md | verify: active docs check; archive header check; all 11 families carded with labels and sources; five randomly sampled numbers traceable to source rows; exclusions consistent with HISTORICAL_AUDIT cross-map exclusions; named canon review that nothing new is labelled attested without a primary source
```
