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

## Decisions (2026-09-26)

1. Length required a linked report, not an inline HISTORICAL_AUDIT chapter:
   [`docs/reports/reval_domestic_infrastructure_1343.md`](../../reports/reval_domestic_infrastructure_1343.md).
2. No new H-register rows. The report cites existing H05, H09-H12, H15, H17-H19
   plus the already indexed history dossiers.
3. Foreign or later numbers (Tartu 1335 latrines, Hanse dump fines, smithing
   charcoal kg/day) stay labelled comparanda and are **U** for Reval household
   counts. Household firewood volume is **U**.
4. Second-reviewer spot-check of ten claims is board row **R-992**. The
   dossier itself is ready for R-985 to consume.

## R-992 second-reviewer spot-check (2026-09-27)

Independent review of
[`docs/reports/reval_domestic_infrastructure_1343.md`](../../reports/reval_domestic_infrastructure_1343.md).
The dossier was not rewritten. Ten numeric or count claims were checked against
the cited dossier or H-register row.

| # | Claim | Citation | Class | Verdict |
|---|---|---|---|---|
| 1 | `lower_town_slice` has two wells on 19 456 cells | report baseline; map `152 x 128`; props `cistern` and `monastery_well` | map census, not a 1343 statistic | Pass. Product of the authored grid. Not stated as a medieval well census. |
| 2 | Inside-wall kitchen/fruit plots 3-10% of developable land | [5] P0-072 Lower Town card | **B/U** | Pass. Matches `HISTORICAL_AUDIT.md`. Report does not tighten the band. |
| 3 | H04 strip frontage 7-11 m | [2] burgher-house-plan; H04 | analogical **B** band | Pass. H04 itself calls the width a synthesis band, not a measured 1343 rule. |
| 4 | Forum at Raekoja plats attested from 1313; weekly weekday unknown | [10] market-weekday dossier | location **A**; weekday **U** / runtime **invented** | Pass. Wednesday/Saturday stays an implementation fallback. |
| 5 | Rataskaevu name from a 1325 well mention; standing rebuild 1375 | [12] public-bath dossier | name **B/C**; fabric later | Pass as labelled. See note below. |
| 6 | Karja first written as *Kariestrate* in 1365; 1343 mill **U** | [6] H10 | **U** for 1343 mill | Pass. H10: name 1365; mill state uncertain. |
| 7 | Kalev commission day 8-15 kg charcoal; 0.5-2 kg per heat | [20] blacksmith-materials | **plausible composite**; Reval household **U** | Pass. Kept as smithing hypothesis, not a household cordwood figure. |
| 8 | AWB 553 (1342 sequence): three *stupa* wood dues, `unam mc. arg.` / `4 mc. den.` | [22] awb-sanitation | **attested** civic fuel; not a house tariff | Pass. Abbreviation left unexpanded. |
| 9 | Tartu latrine dendrochronology 1335 | [13] hygiene dossier | foreign comparandum; Reval lining **U** | Pass. Not copied as a Reval measurement. |
| 10 | Forum dump fine 4-12 schillings | [9] street-cleaning dossier | Hanse comparandum; Reval amount **unset** | Pass. Not an attested 1343 Reval tariff. |

Also checked (same rules, not in the ten): H18 cattle-as-bones not live herds ([7]);
H19 chicken as the common bird ([19]); Saunatorn 1371+ and Nuns' Gate 1355 on the
reject list ([12]).

Structural gates:

- Authoring tables exist for water, food, fuel/heat, and sanitation.
- Reject list is non-empty and names the register anachronisms (Viru timber
  pipes, brick chimney pots, later guild/church masses, Wednesday market as
  history, Tartu latrine dimensions, peat at Kalev's forge).
- CANON Daily Life bullets match the report labels: wells
  `attested` / sharing `plausible composite`; privy and chip heaps
  `plausible composite`; hearth/woodpile `attested` with forge charcoal
  `plausible composite`; market weekday `invented` fallback. Household
  firewood volume and a 1343 Feuerordnung stay unknown in both places.

Note, not a fail: P0-072 / H10 still say Rataskaev is first mentioned after
1343 (1375 in later summaries) and keep a 1343 exact-anchor **U**. The report
follows the public-bath dossier's 1325 mention plus 1375 rebuild and already
marks the street well **B/C**. That is a register tension, not a silent
promotion of the 1375 fabric into 1343 fact. Follow-up **R-1009** reconciles
the H10 sentence with the 1325 citation.

Result: R-984 verify item for the second reviewer is met. Close R-984.
