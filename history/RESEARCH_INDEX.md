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
| `topography` | city plan, walls, gates, plots, harbour | partial | [`lower-town-street-plan`](dossiers/topography/lower-town-street-plan.md) (partial), [`walls-gates-towers`](dossiers/topography/walls-gates-towers.md) (partial), [`harbour-and-shoreline`](dossiers/topography/harbour-and-shoreline.md) (solid), [`harjapea-mouth-shoreline-gis`](dossiers/topography/harjapea-mouth-shoreline-gis.md) (partial), [`kalamaja-fishing-shore-1343`](dossiers/topography/kalamaja-fishing-shore-1343.md) (partial), [`raekoja-plats-extents-1343`](dossiers/topography/raekoja-plats-extents-1343.md) (partial), [`pikk-lai-frontage-materials-1340s`](dossiers/topography/pikk-lai-frontage-materials-1340s.md) (partial), [`old-market-vanaturg`](dossiers/topography/old-market-vanaturg.md) (solid), [`viru-vanaturg-paving-archaeology`](dossiers/topography/viru-vanaturg-paving-archaeology.md) (partial), [`back-lanes-east-of-pikk`](dossiers/topography/back-lanes-east-of-pikk.md) (partial), [`public-bath-locations-1343`](dossiers/topography/public-bath-locations-1343.md) (partial) | R-036, R-043, R-052 | Map, Dev |
| `architecture` | building types, floor plans, interiors | partial | [`burgher-house-plan`](dossiers/architecture/burgher-house-plan.md) (solid), [`rural-smoke-dwelling-and-farmstead-1343`](dossiers/architecture/rural-smoke-dwelling-and-farmstead-1343.md) (partial), [`smithy-workshop-layout`](dossiers/architecture/smithy-workshop-layout.md) (solid), [`domestic-storage-furniture`](dossiers/architecture/domestic-storage-furniture.md) (solid), [`toompea-castle-and-upper-town`](dossiers/architecture/toompea-castle-and-upper-town.md) (solid), [`toompea-small-castle-interior`](dossiers/architecture/toompea-small-castle-interior.md) (solid) | — | Map, Art |
| `people` | named residents, households, name stock | partial | [`town-council-and-officers`](dossiers/people/town-council-and-officers.md) (partial), [`reval-council-prosopography-1340-1345`](dossiers/people/reval-council-prosopography-1340-1345.md) (partial), [`estonian-and-german-populations`](dossiers/people/estonian-and-german-populations.md) (partial) | R-007, R-026, R-038a | Character, Narrative |
| `power` | council, jurisdictions, law, punishment | partial | [`jurisdictions-of-reval`](dossiers/power/jurisdictions-of-reval.md) (solid), [`law-courts-and-punishment`](dossiers/power/law-courts-and-punishment.md) (solid), [`order-comptoir-transition-1343-1346`](dossiers/power/order-comptoir-transition-1343-1346.md) (solid), [`reval-law-codex-arms-and-watch`](dossiers/power/reval-law-codex-arms-and-watch.md) (solid), [`reval-codex-cm6-folio-map`](dossiers/power/reval-codex-cm6-folio-map.md) (partial), [`reval-street-cleaning-ordinances-1340s`](dossiers/power/reval-street-cleaning-ordinances-1340s.md) (partial) | R-059 | Quest, Narrative, Dialogue, Dev |
| `military` | garrison, watch, arms, fortification, siege | partial | [`watch-duty-and-town-defence`](dossiers/military/watch-duty-and-town-defence.md) (solid), [`arms-and-armour-livonia-1340s`](dossiers/military/arms-and-armour-livonia-1340s.md) (partial), [`lower-town-weapon-finds-1340s`](dossiers/military/lower-town-weapon-finds-1340s.md) (solid) | R-061 | Quest, Art, Dev |
| `crafts` | guilds, trades, workshops, tools, smithing | partial | [`guild-structure`](dossiers/crafts/guild-structure.md) (partial), [`schmiede-amt-ordinances-pre-1363`](dossiers/crafts/schmiede-amt-ordinances-pre-1363.md) (partial), [`blacksmith-materials-and-techniques`](dossiers/crafts/blacksmith-materials-and-techniques.md) (solid), [`trades-of-the-lower-town`](dossiers/crafts/trades-of-the-lower-town.md) (solid) | R-042 | Dev, Art, Quest |
| `economy` | trade, goods, prices, coin, measures | partial | [`coinage-prices-and-measures`](dossiers/economy/coinage-prices-and-measures.md) (solid), [`hanseatic-trade-and-season`](dossiers/economy/hanseatic-trade-and-season.md) (solid), [`merchant-cart-and-transport-1340s`](dossiers/economy/merchant-cart-and-transport-1340s.md) (solid), [`reval-cart-tolls-and-fuhr-rent-1340s`](dossiers/economy/reval-cart-tolls-and-fuhr-rent-1340s.md) (partial), [`awb-fuhr-servitude-clauses-1340-1343`](dossiers/economy/awb-fuhr-servitude-clauses-1340-1343.md) (partial), [`awb-clausuris-mortgage-text-1340-1343`](dossiers/economy/awb-clausuris-mortgage-text-1340-1343.md) (partial), [`pr-voorimees-garden-coastal-gate`](dossiers/economy/pr-voorimees-garden-coastal-gate.md) (partial) | R-042, R-048, R-073, R-074 | Dev, Quest, Art |
| `religion` | churches, orders, liturgy, calendar | partial | [`churches-and-religious-houses`](dossiers/religion/churches-and-religious-houses.md) (solid), [`liturgical-calendar-spring-1343`](dossiers/religion/liturgical-calendar-spring-1343.md) (solid), [`ecclesiastical-precinct-boundaries-1343`](dossiers/religion/ecclesiastical-precinct-boundaries-1343.md) (solid) | R-050 | Narrative, Map, Art |
| `culture` | music, instruments, festivals, games | partial | [`music-and-instruments`](dossiers/culture/music-and-instruments.md) (partial), [`reval-musician-payments-1340s`](dossiers/culture/reval-musician-payments-1340s.md) (solid), [`festivals-games-and-public-life`](dossiers/culture/festivals-games-and-public-life.md) (solid) | R-050 | Art, Dialogue, Dev |
| `folklore` | tales, beliefs, spirits, magic | partial | [`belief-omens-and-healing`](dossiers/folklore/belief-omens-and-healing.md) (partial), [`tales-tellable-in-1343`](dossiers/folklore/tales-tellable-in-1343.md) (partial); see also [`../docs/lore/estonian_folklore.md`](../docs/lore/estonian_folklore.md) | R-056 | Narrative, Dialogue |
| `dailylife` | food, clothing, housing, health | partial | [`food-and-drink`](dossiers/dailylife/food-and-drink.md) (solid), [`clothing-and-status-markers`](dossiers/dailylife/clothing-and-status-markers.md) (solid), [`hygiene-and-grooming-1343`](dossiers/dailylife/hygiene-and-grooming-1343.md) (solid) | R-064 | Character, Art, Dialogue |
| `language` | registers, names, address, oaths | partial | [`names-address-and-oaths`](dossiers/language/names-address-and-oaths.md) (solid), [`estonian-forenames-harju-1340s`](dossiers/language/estonian-forenames-harju-1340s.md) (partial) | R-057 AWB Estonian name deep pass | Dialogue, Character |
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
| 2026-07-30 | map / art / quest / producer | Build historically accurate merchant-cart traffic from R-068 (+ R-069 toll gap): contract **P0-164**, art brief **A-010**, *Karren* GLB **A-004**, kit **P2-068**, corridors **P2-069**, systems **P4-037**, quests **P4-038**, traffic wiring **P2-070**, sign-off **A-011** (rows now in `TODO.md`) | [`merchant-cart-and-transport-1340s`](dossiers/economy/merchant-cart-and-transport-1340s.md) |
| 2026-07-30 | map / art / producer | Build historically tiered Lower Town houses from R-003: contract **P0-163**, tiers **P2-063**–**P2-065**, plot dressing **P2-066**, slice wiring **P2-067**, art brief **A-008** / sign-off **A-009** (rows now in `TODO.md`) | [`burgher-house-plan`](dossiers/architecture/burgher-house-plan.md) |
| 2026-07-29 | research | EV II folio read (Nottbeck 1890) matching fn. 99 entries to verbatim *Karrienpforte* carter *ort* deed text | [`pr-voorimees-garden-coastal-gate`](dossiers/economy/pr-voorimees-garden-coastal-gate.md) |
| 2026-07-29 | research | Fetch `economy.reval-cart-tolls-and-fuhr-rent-1340s.04` reference plate once Wikimedia rate-limit clears | [`reval-cart-tolls-and-fuhr-rent-1340s`](dossiers/economy/reval-cart-tolls-and-fuhr-rent-1340s.md) |
| 2026-07-29 | research | AWB folio read 1340–1343 for explicit **Badpacht**, **Mist**, and **Gasse** rent/fine clauses (Nottbeck 1888 pagination) | [`reval-street-cleaning-ordinances-1340s`](dossiers/power/reval-street-cleaning-ordinances-1340s.md) |
| 2026-07-29 | research | Fetch `economy.merchant-cart-and-transport-1340s.05` (Tacuinum harvest cart) once Wikimedia rate-limit clears | [`merchant-cart-and-transport-1340s`](dossiers/economy/merchant-cart-and-transport-1340s.md) |
| 2026-07-29 | research | Retry `military.lower-town-weapon-finds-1340s.01` and `.02` when Meremuuseum publishes open-licence Lootsi projectile photography (blocked R-062) | [`lower-town-weapon-finds-1340s`](dossiers/military/lower-town-weapon-finds-1340s.md) |
| 2026-07-29 | research | Fetch `dailylife.hygiene-and-grooming-1343.05` (Tacuinum wool-merchant miniature) once Wikimedia rate-limit clears | [`hygiene-and-grooming-1343`](dossiers/dailylife/hygiene-and-grooming-1343.md) |
| 2026-07-29 | research | Fetch `dailylife.clothing-and-status-markers.04`–`.07` reference plates once Wikimedia rate-limit clears | [`clothing-and-status-markers`](dossiers/dailylife/clothing-and-status-markers.md) |
| 2026-07-29 | research | TLÜ foto.arheoloogia.ee / AI inventory pass for in-situ arrowheads and bolts from Pikk, Lai, Rahukohtu, Müürivahe rescue collections | [`lower-town-weapon-finds-1340s`](dossiers/military/lower-town-weapon-finds-1340s.md) |
| 2026-07-29 | research | Meremuuseum open-licence photography of conserved Lootsi arrowhead typology once published | [`lower-town-weapon-finds-1340s`](dossiers/military/lower-town-weapon-finds-1340s.md) |
| 2026-07-28 | research | Fetch `power.order-comptoir-transition-1343-1346.02` (Cross livonia.png) once Wikimedia rate-limit clears | [`order-comptoir-transition-1343-1346`](dossiers/power/order-comptoir-transition-1343-1346.md) |
| 2026-07-28 | research | Fetch `language.names-address-and-oaths.03` (Revals seal) once Wikimedia rate-limit clears | [`names-address-and-oaths`](dossiers/language/names-address-and-oaths.md) |
| 2026-07-28 | research | Fetch `folklore.belief-omens-and-healing.05` reference plate once Wikimedia rate-limit clears | [`belief-omens-and-healing`](dossiers/folklore/belief-omens-and-healing.md) |
| 2026-07-28 | research | Mine `history/*.pdf` / Zobel 2008 for measured Danish-phase Small Castle drawings | [`toompea-small-castle-interior`](dossiers/architecture/toompea-small-castle-interior.md) |
| 2026-07-28 | research | Tallinn City Archives pass on 1340–1343 AWB entries for explicit Pikk/Lai street names | [`pikk-lai-frontage-materials-1340s`](dossiers/topography/pikk-lai-frontage-materials-1340s.md) |
| 2026-08-02 | research | Denkelbuch folio read for dated 1340-1345 council elections, burgomaster pair, turnover, and Osenburge/Osenbryg spelling collation (R-038a) | [`reval-council-prosopography-1340-1345`](dossiers/people/reval-council-prosopography-1340-1345.md) |
| 2026-07-28 | research | Tallinn City Archives / AWB pass for named Estonian *Bürger* before 1343 | [`estonian-and-german-populations`](dossiers/people/estonian-and-german-populations.md) |
| 2026-07-28 | research | Steel sheet / osmund barrel weights for forge material costs (R-042) | [`blacksmith-materials-and-techniques`](dossiers/crafts/blacksmith-materials-and-techniques.md) |
| 2026-07-28 | research | Fetch `religion.liturgical-calendar-spring-1343.03` and `.04` reference plates once Wikimedia hash drift is corrected | [`liturgical-calendar-spring-1343`](dossiers/religion/liturgical-calendar-spring-1343.md) |
| 2026-07-28 | research | Fetch `topography.back-lanes-east-of-pikk.01`–`.04` reference plates once Wikimedia rate-limit clears | [`back-lanes-east-of-pikk`](dossiers/topography/back-lanes-east-of-pikk.md) |
| 2026-07-28 | canon | Reconcile Easter 1343 date in `hanseatic-trade-and-season.md` (21 Apr → **13 Apr** Julian) against computus | [`liturgical-calendar-spring-1343`](dossiers/religion/liturgical-calendar-spring-1343.md) |
| 2026-08-01 | canon / research | Collate AWB 1340–1343 entries 554–580 against the MDZ OCR extract for *clausura* variants and confirm whether the negative result is edition-wide or only a searchable-OCR boundary | [`awb-clausuris-mortgage-text-1340-1343`](dossiers/economy/awb-clausuris-mortgage-text-1340-1343.md) |

## Maintenance

1. Update the status column in the same pass that delivers a dossier - never in a later one.
2. Every dossier links to at least one neighbour, reciprocally.
3. When the `## R -` backlog in [`TODO.md`](../TODO.md) falls below six open rows, refill it from
   the `absent`/`stub` domains and from the `## Open questions` sections of existing dossiers.
