# WB-12: 1343 Reval domestic infrastructure dossier - water, food, fuel, sanitation, waste

Board row: **R-984**. Priority: high. Depends on: none.

## Player-facing goal

None directly. This row supplies the facts that make R-985 and R-986 historical rather than
decorative.

## Why this is needed

`docs/HISTORICAL_AUDIT.md` is strong on buildings, institutions, characters, events and the source
register H01-H18, and the P0-072 dossier sets bounded environment targets with an explicit evidence
grading scheme. It has **no section on how a household in 1343 Reval got water, food, fuel or
heat, or where its waste went**. Its section headings are Characters, Buildings and Locations,
Weapons, Religions and Beliefs, Institutions, Faction cloth symbols, Events, the Bishop's Garden
chronology, and the P0-072 dossier.

The maps show the consequence. `lower_town_slice` has **two wells** for a district of 19 456 cells,
one firewood stack, one malt sack pile, one wash tub, and no latrine, midden, gutter, drain, water
butt, kitchen garden, byre or hay store of any kind. An author or an agent told to "make it
historically accurate" currently has nothing in the repository to author against, which is exactly
how generic placeholder dressing gets added instead.

Some of the evidence is already cited and simply not yet turned into authoring guidance: H05
records wells, gutters and manure and chip yard layers in a Lower Town courtyard, plus Cistercian
vegetable and fruit gardens; H11 records a slab-lined rainwater channel draining to the sea; H09
and H10 record watermills; H17 covers archaeobotany and H18 livestock, with cattle most abundant.

## Deliverable

A new dossier section in `docs/HISTORICAL_AUDIT.md`, or a linked
`docs/reports/reval_domestic_infrastructure_1343.md` if length demands it, using the existing
`A`/`B`/`C`/`D`/`U` evidence classes and the canon confidence labels, covering:

1. **Water.** Wells: construction, plausible density per plot or per street, who shared one.
   Rainwater collection and the attested drainage channels. The watermills at Viru and Karja.
   Whether water carriers existed. What the harbour and moat water was **not** used for.
2. **Food.** Household storage - grain, salt fish, salt, root crops, brewing stock. Kitchen and
   yard gardens, on H05 and H17 evidence. Livestock actually kept inside the wall versus in the
   suburbs, on H18 evidence, with cattle most abundant. Baking: household oven, shared oven, or
   commercial bakery. Market supply rhythm and its relation to the existing market-day controller.
3. **Fuel and heat.** Firewood and charcoal volumes for a household winter and for a forge, where
   they were stacked and how long a stack lasts. Hearth versus stove versus the forge. Where the
   fuel came from and how it entered the town. Fire regulation, since it shapes yards and roofs.
4. **Sanitation and waste.** Latrines and cesspits, middens and the chip and manure yard layers in
   H05, street drainage, where refuse went. This is the single largest gap and it changes yard
   layout directly.
5. **What this means for authoring.** A bounded table per category: the prop or structure that
   represents it, a plausible count per plot and per district, where it sits relative to the house
   and the street, and its evidence class. This table is the input R-985 and R-986 consume.
6. **A reject list.** Anachronisms an author or agent must not add: later timber water pipes, which
   H09 explicitly warns cannot be assumed medieval; chimneys and window glass where unwarranted;
   post-1343 institutions and buildings; anything the sources place later.

## Allowed files

`docs/HISTORICAL_AUDIT.md`, `docs/reports/reval_domestic_infrastructure_1343.md`,
`docs/CANON.md`, `history/RESEARCH_INDEX.md`,
`docs/tasks/world/WB-12_domestic_infrastructure_dossier.md`, `TODO.md`.

## Boundary against AR-01 (architecture pack)

AR-01 (`docs/tasks/architecture/AR-01_building_typology_dossier.md`, board row R-959) is the
building-**form** dossier: bays, storeys, gable forms, opening schedules, roof pitches, coursing.
This row is the household-**services** dossier: water, food, fuel, heat, sanitation, waste. They do
not overlap and neither substitutes for the other. Where a service implies a building feature - a
flue for a hearth, a hatch for a cellar, a pentice over a yard door - state the requirement here and
leave the form to AR-01, citing it rather than specifying geometry.

## Constraints and non-goals

Research only - no code, no map, no asset. Every numeric claim carries an inline citation and an
evidence class; a plausible range is labelled `B`, never stated as fact. Where the evidence does
not reach 1343 Reval specifically, say so and use `U` rather than importing a figure from another
town or a later century. Named historical claims need confidence labels in `docs/CANON.md`, per
`AGENTS.md`. Prefer sources already in the register and in `history/`; new sources must be added to
the register with their limits.

## Verification

- `python3 tools/generate_active_docs_report.py --check` and
  `python3 tools/archive_speculative_docs.py --dry-run` clean.
- Every numeric claim has an inline citation and an evidence class; a second reviewer spot-checks
  at least ten and confirms none is stated as fact without one.
- Every category ends with a filled authoring table, so R-985 has no unresolved input.
- The reject list is non-empty and names at least the anachronisms the existing register already
  flags.
- Confidence labels for new named claims are present in `docs/CANON.md`.

## Doc updates

`history/RESEARCH_INDEX.md` indexes the dossier. `docs/CANON.md` gains the labelled claims.
