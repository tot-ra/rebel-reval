# Reval Research Index

Hub for all historical evidence on Spring 1343 Reval. **Start here.** Every dossier is reachable
from this page; a dossier that is not listed here does not count as delivered.

Owned by the Historical-Geo Researcher loop
([work loop](../agents/rebel-researcher/skills/work-loop/SKILL.md),
[dossier standard](../agents/rebel-researcher/skills/dossier-standard/SKILL.md)).
Confidence labels are defined in [`docs/CANON.md`](../docs/CANON.md): `attested`,
`plausible composite`, `folklore`, `invented`.

## How to use this index

- **Producing agents (art, map, character, quest, dialogue, narrative):** find your domain below, open the dossier, and read its `## Brief` and `## Production hooks` sections. Those are written for you. If the evidence you need is absent, say so in your task row rather than inventing it.
- **Canon Keeper:** dossiers are proposals, not canon. Amendments to [`docs/CANON.md`](../docs/CANON.md) remain yours.
- **Researcher:** keep the status column honest, keep `## Downstream requests` current, and refill the `## R -` backlog in [`TODO.md`](../TODO.md) whenever it runs dry.

Status values: `absent` (nothing yet) · `stub` (a pointer only) · `partial` (usable, gaps flagged) ·
`solid` (production-ready for the stated scope).

## Existing material (pre-index)

These predate the dossier layout and are progressively being decomposed into it.

| File | Content | Status |
|------|---------|--------|
| [`HISTORY.md`](HISTORY.md) | uprising narrative, wider 1343 geopolitics, notable figures of the era | partial |
| [`TIMELINE.md`](TIMELINE.md) | 1342-1346 event table | solid for the campaign spine |
| [`history_image_prompts.md`](history_image_prompts.md) | image prompt notes for art generation | partial |
| [`../docs/lore/estonian_folklore.md`](../docs/lore/estonian_folklore.md) | folklore compendium | partial |
| [`../docs/lore/four_kings_act2_lore.md`](../docs/lore/four_kings_act2_lore.md) | Four Kings lore for Act 2 | partial |

Local primary/scholarly holdings in `history/` (Estonian-language archaeology yearbooks, AVE
series, plus `Linnakindlustuste kaardistus.pdf` on town fortifications). Cite these by filename and
note the language; they are the strongest evidence available offline and should be mined before web
search.

## Domain coverage

Domains and their scope are defined in the
[dossier standard](../agents/rebel-researcher/skills/dossier-standard/SKILL.md). Dossiers live in
`history/dossiers/<domain>/<slug>.md`.

| Domain | Scope | Status | Dossiers | Open backlog | Primary consumers |
|--------|-------|--------|----------|--------------|-------------------|
| `topography` | city plan, walls, gates, plots, harbour | partial | [`lower-town-street-plan`](dossiers/topography/lower-town-street-plan.md) (partial), [`walls-gates-towers`](dossiers/topography/walls-gates-towers.md) (partial), [`harbour-and-shoreline`](dossiers/topography/harbour-and-shoreline.md) (stub) | R-005, R-029–R-032 | Map, Dev |
| `architecture` | building types, floor plans, interiors | partial | [`burgher-house-plan`](dossiers/architecture/burgher-house-plan.md) (partial) | R-004, R-006 | Map, Art |
| `people` | named residents, households, name stock | absent | - | R-007, R-026 | Character, Narrative |
| `power` | council, jurisdictions, law, punishment | absent | - | R-008, R-009 | Quest, Narrative |
| `military` | garrison, watch, arms, fortification, siege | absent | - | R-010, R-011 | Quest, Art, Dev |
| `crafts` | guilds, trades, workshops, tools, smithing | absent | - | R-012, R-013, R-027 | Dev, Art, Quest |
| `economy` | trade, goods, prices, coin, measures | absent | - | R-014, R-015 | Dev, Quest |
| `religion` | churches, orders, liturgy, calendar | absent | - | R-016, R-017 | Narrative, Map, Art |
| `culture` | music, instruments, festivals, games | absent | - | R-018, R-019 | Art, Dialogue, Dev |
| `folklore` | tales, beliefs, spirits, magic | stub (see lore compendium) | - | R-020, R-021 | Narrative, Dialogue |
| `dailylife` | food, clothing, housing, health | absent | - | R-022, R-023 | Character, Art, Dialogue |
| `language` | registers, names, address, oaths | absent | - | R-024 | Dialogue, Character |
| `nature` | flora, fauna, April-May climate, livestock | absent | - | R-025 | Map, Art |
| `hinterland` | villages, manors, roads, Saaremaa | absent | - | R-028 | Map, Narrative |

Replace the `-` in **Dossiers** with links as files land, and clear the backlog cell as rows close.
The skeleton every dossier copies is [`dossiers/TEMPLATE.md`](dossiers/TEMPLATE.md).

## Downstream requests

Needs discovered during research that belong to another role. The Producer reads this section on
its reconcile tick and turns entries into task rows; the Researcher never authors rows for other
roles directly.

| Raised | For role | Need | Source dossier |
|--------|----------|------|----------------|
| - | - | - | - |

## Maintenance

1. Update the status column in the same pass that delivers a dossier - never in a later one.
2. Every dossier links to at least one neighbour, reciprocally.
3. When the `## R -` backlog in [`TODO.md`](../TODO.md) falls below six open rows, refill it from
   the `absent`/`stub` domains and from the `## Open questions` sections of existing dossiers.
