# Creature card template

Copy this structure for every card in `docs/BESTIARY/cards/<slug>.md`, where the ID is `bst.<slug>` and the roster row in [`README.md`](./README.md) links to the card. Headings and the field table are checked by `python3 tools/validate_bestiary_cards.py`. Replace every `<...>`. Delete the lines of the layer that does not apply (the validator accepts either the spirit or the physical form of the two layer-specific sections; a `hybrid` card keeps both). Modelled on the [citizen card template](../CITIZENS/TEMPLATE.md).

```markdown
# <Display name exactly as in the roster>

> <One-sentence hook: what this creature is to the people who fear it, in a way no other card could say.>

| Field | Value |
|---|---|
| ID | `bst.<slug>` |
| Layer | `spirit` / `physical` / `hybrid` |
| Tier | `slice` / `act1` / `act2` / `act3` / `backlog` |
| Confidence | `folklore` / `invented` / `attested` |
| Habitat | <district, hinterland or region, as in the roster> |
| Faction ties | <faction ids or none> |
| Archive reference images | <roster image refs or none> |

## At a glance
<Three to five bullets: what the player sees first, what it is known for, one oddity.>

## Folklore origin
<Where the belief comes from, citing the sources in docs/lore/estonian_folklore.md. For `physical` entries: the historical or ecological basis instead.>

## Appearance
- **Body:** <scale in metres, build, how it moves.>
- **Materials and colours:** <what it is made of or looks made of; the palette.>
- **What a model must get right:** <the two or three features that make it recognisable.>
- **Concept-art prompt:** <60-90 words, English, one paragraph, neutral background; only visible traits.>
- **Model notes:** <rig class: humanoid shared rig / MPFB human / quadruped / bespoke; scale; spirit material hints.>

## Motivation
<What it wants, what it fears, its contradiction, what releases it.>

## Manifestation
<Spirit: which fear, place, person and time trigger it. Physical: where and why it attacks.>

## Combat profile
<Spirit: duel topic, elements, temperament, non-violent resolution, cost of destroying it. Physical: EnemyArchetype base, moves, guilt weights per school, flee and surrender rules.>

## Voice
<Sample lines and barks.>

## Relationships and factions
<Who uses, hunts, fears or shelters it.>

## Game hooks
<Quests, ties to forge commissions, places where the player first meets it.>
```
