---
domain: architecture
slug: rural-smoke-dwelling-and-farmstead-1343
status: partial
consumers: [map, art, dev, narrative]
related:
  - ../hinterland/harju-village-and-manor.md
  - ../nature/spring-climate-and-living-world.md
updated: 2026-07-30
---

# Rural smoke dwelling and farmstead (Estonia, Spring 1343)

## Brief for Map and Art

Build a conservative **plausible composite**, not a copy of an open-air museum exhibit. The Estonian
Open Air Museum is essential evidence for the long-lived functions of the *rehemaja* (barn-dwelling),
but its collection consists principally of buildings from the last two hundred years. Its oldest
displayed farmhouse is dated 1723, Sassi-Jaani's barn-dwelling to 1803, and Pulga's to 1860 [1][3][4].
The museum itself warns that the exterior appearance of surviving barn-dwellings is known only from
the second half of the 18th century [2].

**Ship these decisions:**

1. **Two safe rural dwelling tiers:** use a small chimneyless oven-heated **smoke cottage** as the
   archaeologically secure baseline, and a larger two-part **barn-dwelling** (*rehetuba* +
   *rehealune*) where an established grain farm needs it. Both are `plausible composite` at a named
   1343 farm unless local excavation proves the exact plan [1][5].
2. **Construction:** horizontal round-log walls with corner joints dominate. Use stone pads or short
   wall footings only where damp ground requires them, not a continuous high urban plinth [5].
3. **Heating:** the main room has a corner stone oven/open-rock stove and **no roof chimney**. Smoke
   leaves through the door and other unglazed vents; do not place a masonry stack on every rural roof
   [2][5].
4. **Openings:** default to one low boarded dwelling door and no glazed window rhythm. The North
   Estonian barn room is described as originally dark; later light openings and surviving window
   layouts must not be back-projected as exact 1343 facades [2].
5. **Roof evidence lanes:** wedge-split board roofing is archaeologically plausible for the earlier
   smoke cottage [5]. Straw/reed cover on a barn-dwelling is a conservative vernacular analogy, not
   a dated 1343 exterior fact [2]. Keep both steep and weatherproof; do not copy the museum's
   documented late hipped silhouette as mandatory medieval form.
6. **Plan:** the 1343 barn-dwelling is **two-part**: heated living/grain-drying room plus threshing
   floor. Do not add a line of chambers (*kambrid*); the museum dates the first chamber evidence to
   the early 17th century, with most surviving additions later still [1][2].
7. **Threshing access:** give the working bay a broad boarded gate and the dwelling bay a separate
   human door. Keep decoration minimal and subordinate to the construction [2].
8. **Farmyard:** group the dwelling with a simple barn/store, livestock enclosure, hay or straw
   storage, cart, well, fuel and manure/work surfaces. Use a loose clustered North Estonian village
   relationship with field strips beyond, not the mature 19th-century tenant-farm inventory copied
   one-for-one [3][4][6].
9. **Spring 1343 dressing:** show ploughing, draught cattle, lambing, fodder scarcity, muddy traffic
   and last stored grain. A neat empty tourist lawn is wrong for a working yard [6][7].
10. **Regional scope:** this contract applies to rural Estonia and the agricultural edges outside a
    town. It does not turn the inactive Pärnu military-camp prototype into a peasant farm, and it does
    not replace a separate evidence pass for medieval urban Pernau.

## Evidence boundary

| Question | Production answer | Confidence |
|---|---|---|
| Did combined barn-dwellings exist by the campaign date? | The Estonian Open Air Museum reports the type's first written mention in the 14th century. | `attested` at type level [1] |
| What is the archaeologically safest ordinary dwelling? | An oven-heated, chimneyless horizontal-log smoke cottage; Lavi treats it as typical from the 8th to 15th centuries. | `attested` typology [5] |
| What rooms are safe in a 1343 barn-dwelling? | Heated barn room and threshing floor. | `plausible composite` synthesis [1][2][5] |
| Are later chambers safe? | No. First evidence is early 17th century. | `attested` exclusion [1][2] |
| Can the museum facades be copied literally? | No. Surviving exterior evidence begins in the later 18th century, and museum farms are later ensembles. | `attested` exclusion [1][2][3][4] |
| Exact 1343 roof shape and opening positions? | Unknown without a site-specific archaeological study. | `gap` |
| Exact medieval urban houses of Pernau? | Outside this rural contract. | `gap` |

## Findings

### Archaeological baseline: the smoke cottage

Ain Lavi's synthesis of large settlement excavations describes the typical Estonian farm building of
the 8th-15th centuries as an oven-heated log house of one or more rooms. It was normally a
corner-jointed horizontal-log construction, heated by an open-rock or flueless stove in the corner of
the main room [5]. Excavated buildings were usually erected at ground level. Stone support appeared
selectively under damp walls; the evidence does not support a universal raised stone foundation [5].

Lavi also emphasizes how fragmentary the wooden remains are. Earth floors were usual, although
split-board floors occur in wet contexts. The article proposes wedge-split boards as a likely
humidity-resistant roof material for investigated smoke cottages [5]. These observations justify a
low, dark, chimneyless log mass, but not a precise decorative reconstruction.

### What the open-air museum can and cannot prove

The museum presents the barn-dwelling as a long-lived Estonian house type and records its first
written mention in the 14th century [1]. The heated room supported both daily life and grain drying;
the adjoining floor supported threshing, storage and, in later documented practice, winter livestock
shelter [1][2]. This functional sequence is valuable for gameplay and yard composition.

The same official material draws a firm chronological boundary. The classic three-part plan includes
chambers that were late additions, first evidenced in the early 17th century [2]. The museum's extant
exteriors become legible only from the later 18th century [2], while named exhibition farms are
predominantly 19th-century tenant-farm ensembles [3][4]. Therefore their hipped roofs, enlarged
windows, exact gates, stone sheds and complete outbuilding lists are analogies, not direct 1343
records.

### North Estonian relationship

The museum describes the North Estonian form as having a heated barn room narrower and higher than
the threshing floor and originally enclosed so that it was dark [1][2]. The project may use this
relative room hierarchy as a broad silhouette cue. It must not claim exact dimensions, a surviving
window scheme or a complete 19th-century yard for Harju in 1343.

The companion Harju dossier establishes clustered villages with open field strips and warns against
19th-century manor and village forms [6]. Together the two dossiers support clustered working yards
with fields beyond, selective wells, timber service buildings, livestock and earth/mud surfaces.

## 1343 exterior contract

| Runtime primitive | Function | Required visual cues | Hard exclusions |
|---|---|---|---|
| `smoke_cottage_1343` | Small household dwelling | horizontal logs, one boarded door, steep board/shingle roof, no glazed facade rhythm, no chimney | white plaster bands, masonry chimney, symmetrical multi-window facade, urban stone stair |
| `barn_dwelling_1343` | Established grain-farm dwelling and threshing building | long log mass, separate dwelling door and broad working gate, steep thatch/reed analogy, no chimney | 17th-century chambers, 19th-century enlarged windows, copied museum floor plan presented as exact |
| `rural_barn_1343` | Storage/threshing outbuilding | log mass, broad boarded gate, minimal openings, steep weatherproof roof | domestic windows, chimney, ornamental urban facade |

These primitives are view contracts. Authored `footprint`, routes, collisions and stable building IDs
remain the map source of truth.

## Production hooks

- **Implemented first slice:** `world_harju.rrmap` assigns all three primitives, retains stable
  building IDs, and adds working livestock to the existing enclosure.
- **Map:** use farm clusters, narrow trampled paths, manure/fodder work zones and fields beyond the
  yard. Do not distribute isolated white cottages evenly across empty terrain.
- **Art:** an authored model pass should concentrate on log variation, corner joinery, doors, thick
  roof edges, smoke-darkening around the doorway and grounded clutter. It should not add more rooms
  or later windows to make the model look "finished".
- **Dev:** keep rural smoke primitives chimneyless and exempt them from generic glazed-window facade
  generation and evening window emission.
- **Pärnu:** preserve `world_parnu` as a military road/ferry-camp prototype until a separate medieval
  Pernau settlement dossier establishes town and edge-farm fabric.

## Reference views

These are evidence pages, not redistributable game assets. The dated buildings show construction
vocabulary and farm functions only; they are not visual truth for 1343.

| Reference | Use | Chronology warning |
|---|---|---|
| [Museum barn-dwelling overview][2] | log walls, room-function diagrams, later exterior vocabulary | exterior evidence only from later 18th century |
| [Sassi-Jaani farm][3] | roof/corner demonstrations and working implement categories | barn-dwelling dated 1803 and rebuilt as a replica |
| [Pulga farm][4] | North Estonian functional relationship and later yard plan | tenant farm and barn-dwelling dated 1860 |
| Lavi 2005 figures [5] | excavated house bases, corner stove placement, construction interpretation | archaeological traces do not preserve a complete facade |

## Open questions

- A site-specific medieval Pernau/Pärnu domestic-architecture and settlement-edge dossier.
- Regional 13th-14th-century roof-form evidence distinguishing thatch, reed and split-board frequency.
- Medieval yard-boundary, standalone storehouse and livestock-shelter chronology by region.
- A licensed/downloaded reference plate set for the three runtime primitives after Art defines the
  exact camera-facing needs.

## Sources

1. Estonian Open Air Museum, "Exhibition", especially collection chronology, first 14th-century
   barn-dwelling mention, two-part function and North/South type distinction,
   https://evm.ee/exhibition (accessed 2026-07-30).
2. Estonian Open Air Museum, "Rehemaja", especially original two-part plan, early-17th-century
   chamber addition, North Estonian dark room, and the warning that surviving exterior evidence
   begins only in the second half of the 18th century,
   https://evm.ee/maaarhitektuur/maaehitusparand/traditsiooniline-taluarhitektuur/rehemaja
   (accessed 2026-07-30; Estonian).
3. Estonian Open Air Museum, "Sassi-Jaani farm", dated exhibit and component-building descriptions,
   https://evm.ee/exhibition/western-estonia/sassi-jaani-farm (accessed 2026-07-30).
4. Estonian Open Air Museum, "Pulga farm", North Estonian tenant-farm and 1860 barn-dwelling,
   https://evm.ee/exhibition/northern-estonia/pulga-farm (accessed 2026-07-30).
5. Ain Lavi, "An Addendum to the Study of Smoke Cottages", *Estonian Journal of Archaeology* 9.2
   (2005), 132-155, https://doi.org/10.3176/arch.2005.2.03.
6. [`harju-village-and-manor.md`](../hinterland/harju-village-and-manor.md), clustered settlement,
   manor and field-system contract for Spring 1343.
7. [`spring-climate-and-living-world.md`](../nature/spring-climate-and-living-world.md), seasonal
   agriculture, livestock and ground-state contract.
8. Ants Viires, "Lisandeid eesti rehielamu kujunemisloole", *Eesti NSV Teaduste Akadeemia
   Toimetised. Ühiskonnateaduste Seeria* 11.2 (1962), 162-191,
   https://doi.org/10.3176/hum.soc.sci.1962.2.03 (Estonian; historiographic comparison, used as a
   secondary check rather than as sole dating evidence).
