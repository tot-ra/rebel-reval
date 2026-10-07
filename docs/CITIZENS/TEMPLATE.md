# Citizen card template

Copy this structure for every card in `docs/CITIZENS/people/<district>/<slug>.md`. Headings and the field table are checked by `python3 tools/validate_citizen_cards.py`. Replace every `<...>`. Keep adult cards at roughly 600-850 words and children (5-13) at 300-450 words. The writer rules are in [`WRITING_CARDS.md`](./WRITING_CARDS.md).

```markdown
# <Display name exactly as in the census>

> <One-sentence hook: who this person is to the street, in a way no other card could say.>

| Field | Value |
|---|---|
| ID | `char.<slug>` |
| Census ID | `cit.<...>` |
| Confidence | `plausible composite` |
| Tier | Citizen card (ambient, authored; not promoted into `docs/CHARACTERS/`) |
| Household | [<household id>](<relative ledger link>) |
| Home | <street>, plot `<bldg id>` (<m2> m2) |
| Age / sex | <age>, <male/female> |
| Ethnicity / segment | <ethnicity> / <segment> |
| Status | <legal and social standing> |
| Trade | <trade label, with the local-language term if useful> |
| Languages | <languages, first = mother tongue> |
| Literacy | <reads and writes / reads numerals / numerals only / none> |
| Faction | <label> (<faction_role>) |
| Office | <office or none> |

## At a glance
<Three to five bullets: what the player sees first, what the person is known for, one oddity.>

## Appearance
- **Body:** <height in cm, build, posture, gait. Use the seed.>
- **Face:** <bones, nose, jaw, brow, expression at rest, what a portrait must get right.>
- **Hair and facial hair:** <colour (seed), cut, how it is kept, grey, covering.>
- **Skin and marks:** <complexion (seed), every mark in the seed, plus trade wear.>
- **Hands:** <what a close-up of the hands shows.>
- **Clothing and kit (April 1343):** <garments by layer, fabrics, colours, repairs, shoes, belt contents, what rank each item signals. No held objects in the base outfit.>
- **Portrait prompt:** <60-90 words, English, one paragraph, neutral grey background, shoulders-up, natural light; only visible traits.>
- **Model notes:** <MPFB macros: gender, age_years, muscle, weight, proportions, height_m; skin tone; eye colour; hair/beard hint; crowd tier 1 or 2.>

## Biography
<Born where, raised how, the two or three events that made them. Specific places, years (1300s), named relatives (link cards). End with how they live now.>

## Motivation
- **Want:** <...>
- **Fear:** <...>
- **Contradiction:** <...>
- **Secret or withheld fact:** <...>

## Daily routine
| Phase | Time (late April) | Place | Activity |
|---|---|---|---|
| Dawn | <...> | <...> | <...> |
| Morning | <...> | <...> | <...> |
| Midday | <...> | <...> | <...> |
| Afternoon | <...> | <...> | <...> |
| Evening | <...> | <...> | <...> |
| Night | <...> | <...> | <...> |

- **Sundays and feast days:** <...>
- **Spring 1343 disruption:** <how the weeks before and after St George's Night change this day.>

## Work and money
<Income and how it arrives; tools and stock; who they buy from and sell to; debts and credits in marks, schilling, pfennig; property; what a bad month looks like.>

## Relationships
- **Household:** <each member, with links to their cards where they exist, otherwise a ledger link.>
- **Network:** <one bullet per planned edge, using the agreed fact from the batch. Link every edge. Add the relationship's history and the feeling on this side.>
- **Others:** <extra people from the ledger or nearby households, linked.>

## Faction and belief
<Faction affinity and how strong; the person's own reason, not the faction's slogan; what they would do if asked for a small favour, a large one, or to inform; faith and folk practice.>

## Voice
- **Registers:** <languages and when each is used.>
- **Delivery:** <pace, volume, habits; the seed's voice.>
- **Sample lines:** <three lines in English; add a short Low German or Estonian fragment where natural.>
- **Verbal tic:** <one.>

## Knowledge and rumours
<What this person knows that others do not, what they would trade it for, and one rumour they believe that is false.>

## Game hooks
- **Ambient role:** <where the player normally meets them, per phase.>
- **Interaction:** <what they will do or say if spoken to; reaction to Kalev (smith of the Lower Town) based on their standing.>
- **Barks:** <three short barks, one each for calm, tense, and curfew.>
- **Quest touch:** <one small, optional hook; not a main-quest dependency.>
- **St George's Night:** <what they do or suffer if the rising reaches the walls.>
```
