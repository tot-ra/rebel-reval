---
domain: architecture
slug: domestic-storage-furniture
status: solid
consumers: [art, map, dev]
related:
  - burgher-house-plan.md
updated: 2026-07-28
---

# Domestic storage furniture (Reval, 1343)

## Brief for Art / Map / Dev

1. Do **not** treat the modern hanging wardrobe as the default medieval clothes store. Clothing and linen are folded in chests, on shelves, or placed on pegs; the shipped models have no hanging rail. `attested / plausible composite` [1][4][6]
2. Keep the existing `shelf` prop ID for map compatibility, but use three explicit visual variants:
   - `shelf.common_open` - rough open rack and pegs for an ordinary craft or low-income household; clothing storage still depends primarily on a separate chest. `plausible composite` [1][6]
   - `shelf.burgher_cupboard` - compact oak framed-and-boarded cupboard with two doors, lock plate, and restrained iron straps for a prosperous craft or merchant household. `plausible composite` [2][3][5]
   - `shelf.elite_armarium` - rare tall oak armarium/press with full-height posts, framed panels, cornice, and more ironwork; reserve for civic, ecclesiastical, or exceptional elite interiors. `plausible composite` [2][3]
3. Social variants must be authored, never randomized: a rare armarium in every small house would be less accurate than repeating simple chests and open storage. `plausible composite` [1][2][4]
4. Avoid linenfold panels, Renaissance marquetry, drawers, plate-glass mirrors, uniform factory boards, and modern tubular hanging rails. Most museum cupboards with those familiar features are fifteenth century or later. `attested negative chronology` [4][5]
5. The evidence does not establish a surviving domestic Reval cupboard from precisely 1343. The three-tier mapping is a transparent production inference from period construction, Hanseatic comparanda, household architecture, and the unequal cost of oak joinery and iron security. `plausible composite` [1-7]

## Findings

### What is securely supported

- The V&A's clamped-front oak chest W.30-1926 is dated 1200-1300. Its catalogue describes chests as portable storage for clothes, linen, documents, or money in houses and churches. It measures 111 x 53 x 49.5 cm, has a lidded till, a large lock plate, pegged/tenoned construction, and carved decoration confined to its front. `attested comparative object` [1]
- A rare full-height oak cabinet survives from the Liebfrauenkirche at Halberstadt. The museum catalogue describes an approximately 2 m high, 1.35 m wide, 0.8 m deep frame-and-panel cupboard with full-height posts and grooved boards; Johannes Tripps identifies its function as an armarium for liturgical books. It proves that tall closed case furniture was technically available before 1343, but its ecclesiastical setting makes it a shape and construction comparandum, not evidence for a normal Reval home. `attested object; domestic use not attested` [2][3]
- Fifteenth-century French and South Netherlandish museum cupboards show that substantial oak cupboards become much better represented later. Their dating is a warning not to import late Gothic linenfold or elaborate display cabinetry backward into 1343. `attested negative chronology` [4][5]
- The project burgher-house dossier places chests in the private dornse and storage in upper floors/cellars. The smithy dossier supports shelves and pegs for tools and finished work. `attested / local production synthesis` [6][7]

### Reval and Baltic limits

A dismantled merchant chest from Tallinn Bay documents dowelled plank joins, an internal compartment, iron bands, hinges, hasps, and several lock arrangements. The available online object page does not provide a reliable date, so it is used only as a local construction and hardware analogy, not as direct proof for Spring 1343. `undated local comparandum` [8]

No searched source supplied a dated 1343 Reval household inventory distinguishing furniture by poor, middling, and rich homes. Consequently:

| Household/context | Shipped form | Confidence | Why |
|---|---|---|---|
| Ordinary craft / low-income | Open rack plus separate chest | plausible composite | Low material and iron cost; shelf/peg storage is compatible with workshop evidence; chest remains the primary closed store [1][7]. |
| Prosperous burgher | Compact locked cupboard | plausible composite | Period framed/boarded construction and iron security are supported, but a specific Reval domestic example is absent [1-3][8]. |
| Civic / ecclesiastical / exceptional elite | Tall armarium | plausible composite | Tall medieval cabinet form is attested at Halberstadt, but broad domestic ownership is not [2][3]. |

## Production hooks

- **Art:** Use hand-planed broad boards, visible posts/rails, wooden pegs, matte oak or cheaper softwood, and restrained wrought-iron straps. Ornament and hardware increase with status, but silhouette and construction remain primary.
- **Map:** Default omitted `style_variant` to `shelf.common_open`. Assign closed variants explicitly from the known room and owner. Town Hall archive storage can justify burgher/elite locked variants; ordinary workshops should not.
- **Dev / systems:** Strict allowlist: `shelf.common_open`, `shelf.burgher_cupboard`, `shelf.elite_armarium`. Preserve the existing `shelf` kind, footprint ownership, anchor, and navigation behavior.
- **Narrative:** A locked cupboard can signal institutional or household authority. A chest is still the more common target for clothing, portable valuables, dowry goods, or travel.

## Cross-references

- [`burgher-house-plan.md`](burgher-house-plan.md) - places chests and storage within affluent and ordinary Lower Town house plans.
- [`smithy-workshop-layout.md`](smithy-workshop-layout.md) - establishes shelves and pegs as work storage rather than a modern wardrobe.

## Open questions

- Search Tallinn City Archives inventories and wills for explicit fourteenth-century Low German furniture terms and household distributions.
- Identify a securely dated Baltic or north German domestic cupboard between 1300 and 1350 to replace the ecclesiastical armarium as the elite shape reference.
- Date and publish the Tallinn Bay merchant chest context before treating it as direct 1343 evidence.

## Sources

1. Victoria and Albert Museum, **Chest**, W.30-1926, 1200-1300, oak and iron, object O93911: https://collections.vam.ac.uk/item/O93911/chest-unknown/ - museum catalogue, accessed 2026-07-28.
2. Kulturstiftung Sachsen-Anhalt, **Reliquienschrank aus der Liebfrauenkirche Halberstadt, Stollenschrank**, DS426: https://st.museum-digital.de/object/96437?navlang=en - museum object catalogue (German), accessed 2026-07-28. The page's event label and prose dating are not fully consistent; the construction and dimensions, rather than the interface date facet, are used here.
3. Johannes Tripps, **Der Schrank aus dem Marienstift zu Halberstadt: Überlegungen zu Form und Funktion**, 2011, DOI 10.11588/artdok.00001694: https://doi.org/10.11588/artdok.00001694 - scholarly function analysis (German; English abstract).
4. Metropolitan Museum of Art, **Cupboard**, South Netherlandish, 15th century, oak, 49.56.2: https://www.metmuseum.org/art/collection/search/471327 - museum catalogue, accessed 2026-07-28.
5. Metropolitan Museum of Art, **Cupboard**, French, ca. 1460, oak, 1974.126.1: https://www.metmuseum.org/art/collection/search/465967 - museum catalogue, accessed 2026-07-28.
6. [`burgher-house-plan.md`](burgher-house-plan.md) - local project synthesis for Spring 1343 Reval rooms and storage.
7. [`smithy-workshop-layout.md`](smithy-workshop-layout.md) - local project synthesis for shelf, peg, rack, and chest placement in the forge household.
8. Jaan Märss, **Merchant's chest from Tallinn Bay**, photographs and technical drawings: http://jaanmarss.planet.ee/juhendid/lukud_v6tmed_sulgurid/pildid/Merchant%27s%20chest/index.html - undated online technical plate; construction analogy only, accessed 2026-07-28.
