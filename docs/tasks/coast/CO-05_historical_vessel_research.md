# CO-05: Sourced 1343 Baltic vessel dossier

Board row: **R-952**. Priority: high. Depends on: none. Research only, no runtime code.

## Player-facing goal

None directly. This is the evidence gate that lets CO-06 build vessels a historian would recognise
instead of a second round of invented boxes.

## Why this is needed

The current fleet is two procedural primitive builders with no cited dimensions. The only vessel
evidence in the repo is four lines in `docs/reports/reval_harbour_1343_research.md` plus one citation
(Estonian Maritime Museum, wreck of the Lootsi cog). `docs/CANON.md` requires named historical claims
to carry confidence labels, and CO-06 will assert hull proportions, plank counts, rig geometry and
crew positions, so those claims need a source and a confidence label first.

## Deliverable

`docs/reports/baltic_vessels_1343.md`, structured per vessel type, each entry carrying:

- **Type and role** in the Reval roadstead / Kalamaja fishery / Saaremaa strait
- **Dimensions**: length overall, beam, depth, draught, freeboard, in metres, with the tolerance the
  source supports
- **Construction**: clinker or carvel, plank count and lap, frame spacing, keel and stem profile,
  caulking, fastening, tar and paint treatment
- **Rig**: mast position as a fraction of LOA, mast height, yard length, sail area and cut, sheet and
  brace layout, halyard and shroud count
- **Oars**: number, length, thole/oarport arrangement, stowed position
- **Fittings**: rudder type (side rudder vs stern rudder - this is the period transition and matters),
  tiller, anchor, bailer, mooring bitts, fish/cargo handling gear
- **Confidence label** per claim in the `docs/CANON.md` vocabulary (attested / bounded reconstruction
  / reconstructed / speculative), with the source cited inline
- **What we do not know**, explicitly

Minimum type coverage:

1. Hanseatic cog, cargo - the roadstead vessel; anchor on the Lootsi cog wreck
2. Small inshore clinker fishing boat, 2 sizes - the Kalamaja working craft
3. Open rowing/ferry boat - the pier and strait craft
4. Baltic lighter / lodja-type river and coastal barge - cargo transfer to the beach landings
5. One Saaremaa-appropriate local craft for the strait crossing

Also required:

- A short section on **1343 rigging behaviour**: how a square sail on a single yard is furled, reefed,
  braced and how it luffs, and how oars are shipped and stowed. CO-07 animates this, so it needs the
  real vocabulary and the real ranges of motion.
- A reject list: vessel features that must **not** appear (later fore-and-aft rigs, gaff, wheel
  steering, later carvel hulls, ratlines on shrouds where the period does not support them).

## Allowed files

- `docs/reports/baltic_vessels_1343.md` (new)
- `docs/CANON.md` (vessel claims and confidence labels)
- `history/RESEARCH_INDEX.md` (index entry)
- `docs/reports/reval_harbour_1343_research.md` (cross-reference only)
- `TODO.md`

## Constraints and non-goals

- No asset work, no code, no map edits.
- Every dimension needs a source. An uncited number must be labelled speculative or omitted.
- Prefer Baltic and Estonian sources (Estonian Maritime Museum, Bremen cog, Baltic wreck
  archaeology). Do not generalise from Mediterranean or North Sea later-period vessels without
  flagging it.
- Do not decide art direction here. This is dimensions and mechanics; ADR 0018 styling is CO-06.

## Verification

```bash
python3 tools/generate_active_docs_report.py --check
python3 tools/archive_speculative_docs.py --dry-run
```

- Every vessel entry has all the required fields filled or explicitly marked unknown.
- Every numeric claim has an inline citation and a confidence label.
- `docs/CANON.md` carries the vessel claims with matching labels.
- A second reviewer (agent or human) confirms no uncited dimension is presented as fact.

## Doc updates

`docs/CANON.md`, `history/RESEARCH_INDEX.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-952 | deps: none | deliverable: docs/reports/baltic_vessels_1343.md covering cog, two inshore clinker fishing sizes, rowing/ferry boat, lodja-type lighter and a Saaremaa strait craft, each with sourced dimensions, construction, rig, oars, fittings, confidence labels, a 1343 rigging-behaviour section and a feature reject list | allowed files: per docs/tasks/coast/CO-05_historical_vessel_research.md | verify: active docs check and speculative-archive dry run clean; every numeric claim carries an inline citation and a CANON confidence label; second reviewer confirms no uncited dimension is stated as fact
```
