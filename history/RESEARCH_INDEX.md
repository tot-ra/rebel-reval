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
- **Looking for pictures?** Dossiers written for art, map, and character carry a `## Reference plates` table - licensed images of clothing, floor plans, facades, doors, ironwork, interiors, and tools. The files are under [`reference/`](reference/README.md) and the manifest is [`reference/plates.csv`](reference/plates.csv). They are evidence, not assets: derive from them, do not ship them.
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
| `topography` | city plan, walls, gates, plots, harbour | partial | [`lower-town-street-plan`](dossiers/topography/lower-town-street-plan.md) (partial), [`walls-gates-towers`](dossiers/topography/walls-gates-towers.md) (partial), [`harbour-and-shoreline`](dossiers/topography/harbour-and-shoreline.md) (solid), [`kalamaja-fishing-shore-1343`](dossiers/topography/kalamaja-fishing-shore-1343.md) (partial), [`raekoja-plats-extents-1343`](dossiers/topography/raekoja-plats-extents-1343.md) (partial), [`pikk-lai-frontage-materials-1340s`](dossiers/topography/pikk-lai-frontage-materials-1340s.md) (partial), [`old-market-vanaturg`](dossiers/topography/old-market-vanaturg.md) (solid), [`viru-vanaturg-paving-archaeology`](dossiers/topography/viru-vanaturg-paving-archaeology.md) (partial), [`back-lanes-east-of-pikk`](dossiers/topography/back-lanes-east-of-pikk.md) (partial) | R-033, R-036, R-043, R-052 | Map, Dev |
| `architecture` | building types, floor plans, interiors | partial | [`burgher-house-plan`](dossiers/architecture/burgher-house-plan.md) (solid), [`smithy-workshop-layout`](dossiers/architecture/smithy-workshop-layout.md) (solid), [`domestic-storage-furniture`](dossiers/architecture/domestic-storage-furniture.md) (solid), [`toompea-castle-and-upper-town`](dossiers/architecture/toompea-castle-and-upper-town.md) (solid) | R-035 | Map, Art |
| `people` | named residents, households, name stock | partial | [`town-council-and-officers`](dossiers/people/town-council-and-officers.md) (partial), [`estonian-and-german-populations`](dossiers/people/estonian-and-german-populations.md) (partial) | R-007, R-026, R-038 | Character, Narrative |
| `power` | council, jurisdictions, law, punishment | partial | [`jurisdictions-of-reval`](dossiers/power/jurisdictions-of-reval.md) (solid), [`law-courts-and-punishment`](dossiers/power/law-courts-and-punishment.md) (solid) | R-040 | Quest, Narrative |
| `military` | garrison, watch, arms, fortification, siege | partial | [`watch-duty-and-town-defence`](dossiers/military/watch-duty-and-town-defence.md) (solid), [`arms-and-armour-livonia-1340s`](dossiers/military/arms-and-armour-livonia-1340s.md) (partial) | R-040 | Quest, Art, Dev |
| `crafts` | guilds, trades, workshops, tools, smithing | partial | [`guild-structure`](dossiers/crafts/guild-structure.md) (partial), [`blacksmith-materials-and-techniques`](dossiers/crafts/blacksmith-materials-and-techniques.md) (solid) | R-027, R-041, R-042 | Dev, Art, Quest |
| `economy` | trade, goods, prices, coin, measures | partial | [`coinage-prices-and-measures`](dossiers/economy/coinage-prices-and-measures.md) (solid), [`hanseatic-trade-and-season`](dossiers/economy/hanseatic-trade-and-season.md) (solid) | R-042 | Dev, Quest |
| `religion` | churches, orders, liturgy, calendar | partial | [`churches-and-religious-houses`](dossiers/religion/churches-and-religious-houses.md) (solid), [`liturgical-calendar-spring-1343`](dossiers/religion/liturgical-calendar-spring-1343.md) (solid) | R-049, R-050 | Narrative, Map, Art |
| `culture` | music, instruments, festivals, games | absent | - | R-018, R-019 | Art, Dialogue, Dev |
| `folklore` | tales, beliefs, spirits, magic | stub (see lore compendium) | - | R-020, R-021 | Narrative, Dialogue |
| `dailylife` | food, clothing, housing, health | partial | [`food-and-drink`](dossiers/dailylife/food-and-drink.md) (solid) | R-023 | Character, Art, Dialogue |
| `language` | registers, names, address, oaths | absent | - | R-024 | Dialogue, Character |
| `nature` | flora, fauna, April-May climate, livestock | partial | [`spring-climate-and-living-world`](dossiers/nature/spring-climate-and-living-world.md) (solid) | R-022 phenology tie-in | Map, Art |
| `hinterland` | villages, manors, roads, Saaremaa | partial | [`harju-village-and-manor`](dossiers/hinterland/harju-village-and-manor.md) (partial) | R-048, R-049 | Map, Narrative |

Replace the `-` in **Dossiers** with links as files land, and clear the backlog cell as rows close.
The skeleton every dossier copies is [`dossiers/TEMPLATE.md`](dossiers/TEMPLATE.md).

## Downstream requests

Needs discovered during research that belong to another role. The Producer reads this section on
its reconcile tick and turns entries into task rows; the Researcher never authors rows for other
roles directly.

| Raised | For role | Need | Source dossier |
|--------|----------|------|----------------|
| 2026-07-28 | research | Fetch `topography.kalamaja-fishing-shore-1343.02` and `.04` reference plates after Wikimedia rate-limit clears | [`kalamaja-fishing-shore-1343`](dossiers/topography/kalamaja-fishing-shore-1343.md) |
| 2026-07-28 | research | Tallinn City Archives pass on 1340–1343 AWB entries for explicit Pikk/Lai street names | [`pikk-lai-frontage-materials-1340s`](dossiers/topography/pikk-lai-frontage-materials-1340s.md) |
| 2026-07-28 | research | Denkelbuch / AWB folio read for sitting burgomaster pair and December 1343 council election names | [`town-council-and-officers`](dossiers/people/town-council-and-officers.md) |
| 2026-07-28 | research | Tallinn City Archives / AWB pass for named Estonian *Bürger* before 1343 | [`estonian-and-german-populations`](dossiers/people/estonian-and-german-populations.md) |
| 2026-07-28 | research | Steel sheet / osmund barrel weights for forge material costs (R-042) | [`blacksmith-materials-and-techniques`](dossiers/crafts/blacksmith-materials-and-techniques.md) |
| 2026-07-28 | research | Fetch `religion.liturgical-calendar-spring-1343.01`–`.05` reference plates after Wikimedia rate-limit clears | [`liturgical-calendar-spring-1343`](dossiers/religion/liturgical-calendar-spring-1343.md) |
| 2026-07-28 | research | Fetch `topography.back-lanes-east-of-pikk.01`–`.04` reference plates once Wikimedia rate-limit clears | [`back-lanes-east-of-pikk`](dossiers/topography/back-lanes-east-of-pikk.md) |
| 2026-07-28 | canon | Reconcile Easter 1343 date in `hanseatic-trade-and-season.md` (21 Apr → **13 Apr** Julian) against computus | [`liturgical-calendar-spring-1343`](dossiers/religion/liturgical-calendar-spring-1343.md) |

## Maintenance

1. Update the status column in the same pass that delivers a dossier - never in a later one.
2. Every dossier links to at least one neighbour, reciprocally.
3. When the `## R -` backlog in [`TODO.md`](../TODO.md) falls below six open rows, refill it from
   the `absent`/`stub` domains and from the `## Open questions` sections of existing dossiers.
