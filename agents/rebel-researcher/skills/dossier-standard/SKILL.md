---
name: rebel-researcher-dossier-standard
description: Domain taxonomy, file layout, cross-linking rules, and dossier template that make Reval Rebel historical research directly reusable by art, map, character, quest, and dialogue roles.
---

# Reval Rebel Dossier Standard

Research output is a **navigable graph of small markdown files**, not a few long essays. Another
agent must be able to start at `history/RESEARCH_INDEX.md`, follow two links, and reach a
production-ready specific.

## Domain taxonomy

Every dossier belongs to exactly one domain. The domain is its folder and the first field of its
frontmatter.

| Domain | Slug | Covers | Primary consumers |
|--------|------|--------|-------------------|
| Topography | `topography` | city plan, street network, walls, gates, towers, plot layout, Toompea/Lower Town split, relief, water, harbour | Map, Dev |
| Architecture | `architecture` | building typology, floor plans, interiors, roofs, cellars, materials, heating, light, furniture | Map, Art |
| People | `people` | prosopography of named residents, councillors, vassals, clergy, servants, famous figures, name stock, households | Character, Narrative |
| Power | `power` | governance, jurisdictions, charters, town council, law, courts, punishment, Danish crown, bishop, vassalry | Quest, Narrative |
| Military | `military` | garrison, watch duty, arms, armour, fortification practice, siege craft, campaign logistics | Quest, Art, Dev |
| Crafts | `crafts` | professions, guild structure, workshops, tools, techniques - smithing above all, since the forge is the core mechanic | Dev, Art, Quest |
| Economy | `economy` | Hanseatic trade, goods, routes, prices, coinage, weights and measures, markets, credit, taxation | Dev, Quest |
| Religion | `religion` | churches, monastic orders, liturgy, calendar, saints, processions, burial, popular piety | Narrative, Map, Art |
| Culture | `culture` | music, instruments, song, dance, festivals, performance, games, visual culture | Art, Dialogue, Dev |
| Folklore | `folklore` | tales, beliefs, spirits, omens, magic, healing, oral tradition, pre-Christian Estonian layer | Narrative, Dialogue |
| Daily life | `dailylife` | food, drink, clothing, hygiene, housing, health, work rhythm, childhood, gender and status roles | Character, Art, Dialogue |
| Language | `language` | Low German / Estonian / Latin registers, naming conventions, address, oaths, curses, inscriptions | Dialogue, Character |
| Nature | `nature` | flora, fauna, climate, the April-May season specifically, agriculture, livestock, weather | Map, Art |
| Hinterland | `hinterland` | Harju and Viru villages, manors, roads, Padise, Paide, Saaremaa, Pöide - everything outside the walls | Map, Narrative |

## File layout

```text
history/RESEARCH_INDEX.md            hub: taxonomy, coverage matrix, downstream requests
history/dossiers/<domain>/<slug>.md  one topic, one tick of work
history/dossiers/TEMPLATE.md         the canonical skeleton
history/reference/plates.csv         image manifest: one row per reference plate
history/reference/<domain>/<slug>/   fetched plate files (Git LFS, outside Godot import)
```

Slugs are kebab-case and specific: `st-olafs-guild-hall-interior`, not `buildings`. Never rename a
delivered dossier - other files link to it; supersede it with a new file and a pointer instead.

## Cross-linking rules

1. Frontmatter carries the machine-readable edges; prose carries the reasons.
2. Every dossier links to at least one neighbour, and every link is **reciprocal** - if A cites B, B gains a back-link in the same pass.
3. Links are relative markdown paths (`../crafts/blacksmith-workshop.md`), so they resolve on disk and in the repo browser.
4. `history/RESEARCH_INDEX.md` links to every dossier. A dossier reachable from nothing does not exist.
5. When a dossier supersedes canon or lore, link to `docs/CANON.md` and flag it - the Canon Keeper, not you, makes the amendment.

## Reference plates - the visual half of a dossier

Art, map, and character roles cannot build a door from a paragraph about doors. Prose fixes the
decision; a plate fixes the shape. Every dossier whose consumers include `art`, `map`, or
`character` ships **3-8 reference plates** unless you state explicitly that no licensed visual
evidence exists for the topic.

**What counts as a plate.** Primary or scholarly visual evidence, not mood art:

- **Clothing and textiles:** cut, layering, fastenings, headwear, footwear, status contrast, working dress versus feast dress; effigies, brasses, manuscript folios, surviving garments (Herjolfsnes, Bocksten, London Museum textiles).
- **Floor plans and sections:** measured surveys of houses, cellars, halls, guild houses, church interiors; excavation plans in `history/*.pdf` and Muinsuskaitseamet reports.
- **Facades and elevations:** gable forms, window rhythm, hoist beams, doorway placement, wall surface, roof pitch and covering.
- **Doors, ironwork, fittings:** hinges, straps, locks, keys, handles, nails, grilles, shutters, chest mounts.
- **Interiors:** hearth and stove types, ceiling and floor construction, furniture, lighting, storage, workshop layout.
- **Tools, arms, and craft gear:** forge equipment above all, plus trade tools, measures, containers, weapons and armour.
- **Ships, harbour, transport:** cog construction, cranes, carts, sledges, harness.
- **Town views, maps, seals, coins:** later views used only as retrospective evidence, plus seals and coins that are contemporary.

**Where to look first.** Local `history/*.pdf` archaeology reports (they contain measured drawings
and finds photography), then Muinsuskaitseamet / Estonian registers, Tallinn City Archives and
Tallinn City Museum, Eesti Ajaloomuuseum, Wikimedia Commons scans of out-of-copyright plates,
Rijksmuseum, and digitised manuscript folios (BnF Gallica, British Library, e-codices).

**Dating discipline is the same as for prose.** State the object's date and place of origin in the
plate row. Baltic or North German material of 1250-1400 is the target; anything later or from
Lübeck, Riga, Visby, or Novgorod is a `plausible composite` comparandum and must say so and say why
it transfers. A plate never silently upgrades a guess into evidence.

**Rights.** Only `public domain`, `CC0`, `CC BY`, and `CC BY-SA` plates are downloaded; everything
else stays a link-only row with `status: linked`. Plates are evidence under `history/`, never game
content: they are Git-LFS tracked, excluded from Godot import, and absent from `assets/SOURCES.csv`.
If art later derives a shipped asset from a plate, that role records its own provenance row.

**Manifest.** Append rows to `history/reference/plates.csv`, then run
`python3 tools/research/fetch_reference_plates.py --slug <dossier-slug>` to download, checksum, and
write the local paths back. `--verify` re-checks every fetched row and is what QA runs. Plate IDs
are `<domain>.<slug>.<nn>` and are never reused.

## Dossier template

```markdown
---
domain: crafts
slug: blacksmith-workshop
status: partial            # stub | partial | solid
consumers: [art, map, dev]
related:
  - ../architecture/lower-town-house-plan.md
  - ../economy/iron-and-metal-trade.md
updated: YYYY-MM-DD
---

# <Topic>

## Brief for <requesting role>
Max 20 lines. What a producing agent needs to act, stated as decisions rather than background.

## Findings
Grouped by sub-question. Every non-trivial statement ends with a confidence label and a source
reference: `attested [1]`, `plausible composite (rationale) [2]`, `folklore [3]`, `invented`.

## Production hooks
Concrete, reusable specifics, grouped by consumer role:
- **Art:** palettes, materials, wear patterns, silhouettes, props worth generating.
- **Map:** dimensions, adjacencies, circulation, landmarks, plausible plot shapes.
- **Character:** occupations, ages, clothing, status markers, household composition.
- **Quest / Narrative:** frictions, obligations, seasonal deadlines, plausible conflicts.
- **Dialogue:** terms of art, forms of address, oaths, units, prices to quote.
- **Dev / systems:** quantities, rates, durations, tolerances a system could model.

## Reference plates
One row per plate, mirroring `history/reference/plates.csv`. Omit only with an explicit line saying
no licensed visual evidence was found.

| Plate | Shows | Source, date, origin | License | Answers |
|-------|-------|----------------------|---------|---------|
| [`crafts.blacksmith-workshop.01`](../../reference/crafts/blacksmith-workshop/crafts.blacksmith-workshop.01.jpg) | forge hearth, bellows, tool rack | Mendel Hausbuch f. 34r, Nuremberg, c. 1425 - later comparandum | public domain | how the bellows meets the hearth wall |
| `crafts.blacksmith-workshop.02` (link-only) | tong and hammer finds | Tallinn City Museum catalogue, 14th c., Reval | rights unclear | tool silhouettes and proportions |

## Cross-references
Why each linked dossier matters here, one line each.

## Open questions
Unresolved points, each phrased so it can become a future `R-###` backlog row.

## Sources
Numbered. Prefer primary, institutional, and scholarly work. Mark local repository sources
(`history/*.pdf`) explicitly, note language, and reconcile conflicts rather than hiding them.
```

## Standing constraints

- Spring 1343. Anything post-1343 in term, technology, or event is an anachronism unless explicitly
  labelled as a later source describing earlier practice.
- A source absence is never upgraded into a confident assertion; say the record is thin and give the
  best-supported composite, labelled as such.
- Reconstructions drawn from Lübeck, Riga, Visby, or Novgorod comparanda are `plausible composite`
  and must name the comparandum and why it transfers.
- Confidence labels are exactly the four in `docs/CANON.md`: `attested`, `plausible composite`,
  `folklore`, `invented`.
