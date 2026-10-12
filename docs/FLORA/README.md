# Flora

Status: living catalogue (task **R-1808**, 12 October 2026). One card per plant that is in the game, with its own pictures, grouped as [trees](#trees), [shrubs](#shrubs), [herbs and wild flowers](#herbs-and-wild-flowers) and [crops](#crops). The [wishlist](#wishlist-common-estonian-plants-not-yet-in-the-game) lists the common Estonian plants still missing, checked against the 1343 period rule.

Scope: what each plant is, its runtime ID, where it grows in game, its season, its model status and its folk use. How vegetation is built, placed, animated and drawn lives in [Living vegetation](../SYSTEMS/LIVING_VEGETATION.md) and [Vegetation engineering](../SYSTEMS/VEGETATION_ENGINEERING.md); the ecological ledger and authored map evidence in [Flora and fauna](../FLORA_FAUNA.md). Animals are in [Fauna](../FAUNA/README.md). Out of scope: a herbalism or gathering mechanic (see [herbalism readiness](#herbalism-readiness)).

## Pictures

Every card shows a portrait of the runtime model alone on a turf disc in a three-quarter view, rendered by [`tools/capture_flora_cards.gd`](../../tools/capture_flora_cards.gd) into [`images/`](./images) (`images/.gdignore` keeps Godot from importing them):

```bash
tools/godot_render.sh --script tools/capture_flora_cards.gd            # everything
tools/godot_render.sh --script tools/capture_flora_cards.gd -- --only=forbs   # trees | plants | forbs
```

Trees are the district (blueprint) model at medium size; the seamless city draws the same skeleton with more detail. Wild plants with a city model also link close-ups and in-world plates. A card without a picture has no 3D model.

## Model status

| Status | Meaning |
|---|---|
| Procedural tree | Weber-Penn skeleton with leaf-cluster cards, all 20 tree species |
| Detailed city model | `CityForbMeshes` model with near and far variants and seasons, grows in the seamless city and on blueprint maps |
| City cane model / city: tree mesh | City shrub drawn with its own canes or with a scaled tree mesh |
| Primitive district model | Generic `MapViewPlantMeshes` growth archetype on blueprint maps only; reads as a green bunch up close |
| No model | Data only: slows movement and counts in composition, nothing is drawn |

## Trees

| Tree | Latin | Estonian | Runtime ID | Period |
|---|---|---|---|---|
| [Norway spruce](trees/spruce.md) | *Picea abies* | harilik kuusk | `tree.spruce`, city `spruce` | high |
| [Scots pine](trees/pine.md) | *Pinus sylvestris* | harilik mänd | `tree.pine`, city `pine` and `pine_tall` | high |
| [Juniper](trees/juniper.md) | *Juniperus communis* | harilik kadakas | `tree.juniper`, city `juniper` | high |
| [Birch](trees/birch.md) | *Betula pendula / B. pubescens* | arukask / sookask | `tree.birch`, city `birch` | high |
| [Aspen](trees/aspen.md) | *Populus tremula* | harilik haab | `tree.aspen` | high |
| [Ash](trees/ash.md) | *Fraxinus excelsior* | harilik saar | `tree.ash` | high |
| [Alder](trees/alder.md) | *Alnus glutinosa / A. incana* | sanglepp / hall lepp | `tree.alder` | high |
| [Oak](trees/oak.md) | *Quercus robur* | harilik tamm | `tree.oak` | high |
| [Norway maple](trees/maple.md) | *Acer platanoides* | harilik vaher | `tree.maple` | high |
| [Linden](trees/linden.md) | *Tilia cordata* | harilik pärn | `tree.linden` | high |
| [Elm](trees/elm.md) | *Ulmus glabra / U. laevis* | jalakas / künnapuu | `tree.elm` | high |
| [Willow](trees/willow.md) | *Salix spp.* | paju | `tree.willow`, city shrub `willow_shrub` | high |
| [Apple](trees/apple.md) | *Malus domestica / M. sylvestris* | aed-õunapuu / metsõunapuu | `tree.apple` | medium |
| [Sour cherry](trees/cherry.md) | *Prunus cerasus* | hapukirsipuu | `tree.cherry` | medium |
| [Plum](trees/plum.md) | *Prunus domestica* | ploomipuu | `tree.plum` | medium |
| [Pear](trees/pear.md) | *Pyrus communis* | harilik pirnipuu | `tree.pear` | medium |
| [Rowan](trees/rowan.md) | *Sorbus aucuparia* | harilik pihlakas | `tree.rowan` | high |
| [Hawthorn](trees/hawthorn.md) | *Crataegus spp.* | viirpuu | `tree.hawthorn`, city shrubs `hawthorn`, `spindle` | high |
| [Blackthorn](trees/blackthorn.md) | *Prunus spinosa* | laukapuu | `tree.blackthorn`, city shrubs `blackthorn`, `sea_buckthorn` | high |
| [Hazel](trees/hazel.md) | *Corylus avellana* | harilik sarapuu | `tree.hazel`, city shrubs `elder`, `hazel_shrub`, `guelder_rose`, `willow_shrub`, `alder_shrub` | high |

## Shrubs

| Shrub | Latin | Estonian | Runtime ID | Model |
|---|---|---|---|---|
| [Dog rose](shrubs/dog_rose.md) | *Rosa canina / R. majalis* | koerroos / kibuvits | `bush.dog_rose`, city `dog_rose` | City cane model |
| [Raspberry](shrubs/raspberry.md) | *Rubus idaeus* | harilik vaarikas | `bush.raspberry`, city `raspberry` | City cane model |
| [Elder](shrubs/elder.md) | *Sambucus nigra* | must leeder | `bush.elder`, city `elder` | City: hazel tree mesh |
| [Hazel shrub](shrubs/hazel_shrub.md) | *Corylus avellana* | harilik sarapuu | `bush.hazel_shrub`, city `hazel_shrub` | City: hazel tree mesh |
| [Guelder rose](shrubs/guelder_rose.md) | *Viburnum opulus* | harilik lodjapuu | `bush.guelder_rose`, city `guelder_rose` | City: hazel tree mesh |
| [Willow shrub](shrubs/willow_shrub.md) | *Salix spp.* | paju | `bush.willow_shrub`, city `willow_shrub` | City: hazel tree mesh |
| [Alder shrub](shrubs/alder_shrub.md) | *Alnus incana* | hall lepp | `bush.alder_shrub`, city `alder_shrub` | City: hazel tree mesh |
| [Hawthorn](shrubs/hawthorn.md) | *Crataegus spp.* | viirpuu | `bush.hawthorn`, city `hawthorn` | City: hawthorn tree mesh |
| [Spindle](shrubs/spindle.md) | *Euonymus europaeus* | harilik kikkapuu | `bush.spindle`, city `spindle` | City: hawthorn tree mesh |
| [Blackthorn](shrubs/blackthorn.md) | *Prunus spinosa* | laukapuu | `bush.blackthorn`, city `blackthorn` | City: blackthorn tree mesh |
| [Sea buckthorn](shrubs/sea_buckthorn.md) | *Hippophae rhamnoides* | astelpaju | `bush.sea_buckthorn`, city `sea_buckthorn` | City: blackthorn tree mesh |
| [Juniper shrub](shrubs/juniper_shrub.md) | *Juniperus communis* | harilik kadakas | `bush.juniper_shrub`, city `juniper_shrub` | City: juniper tree mesh |
| [Bilberry](shrubs/bilberry.md) | *Vaccinium myrtillus* | harilik mustikas | `bush.bilberry` | **No model** (data only) |
| [Cowberry](shrubs/cowberry.md) | *Vaccinium vitis-idaea* | harilik pohl | `bush.cowberry` | **No model** (data only) |
| [Cloudberry](shrubs/cloudberry.md) | *Rubus chamaemorus* | murakas | `bush.cloudberry` | **No model** (data only) |
| [Cranberry](shrubs/cranberry.md) | *Vaccinium oxycoccos* | harilik jõhvikas | `bush.cranberry` | **No model** (data only) |
| [Crowberry](shrubs/crowberry.md) | *Empetrum nigrum* | kukemari | `bush.crowberry` | **No model** (data only) |
| [Wild strawberry](shrubs/wild_strawberry.md) | *Fragaria vesca* | metsmaasikas | `bush.wild_strawberry` | **No model** (data only) |
| [Heather](shrubs/heather.md) | *Calluna vulgaris* | kanarbik | `bush.heather` | **No model** (data only) |
| [Bog rosemary](shrubs/bog_rosemary.md) | *Andromeda polifolia* | harilik küüvits | `bush.bog_rosemary` | **No model** (data only) |

## Herbs and wild flowers

| Plant | Latin | Estonian | Above ground / flowering | Model |
|---|---|---|---|---|
| [Oxeye daisy](herbs/oxeye_daisy.md) | *Leucanthemum vulgare* | härjasilm (нивяник) | Rosette from 15 April | Detailed city model |
| [Dandelion](herbs/dandelion.md) | *Taraxacum officinale* | harilik võilill | Flowers in May, seed clocks in June, rosettes until November. | Detailed city model |
| [Broadleaf plantain](herbs/plantain.md) | *Plantago major* | suur teeleht | Spikes June-September. | Detailed city model |
| [White clover](herbs/white_clover.md) | *Trifolium repens* | valge ristik | Flowers June-August. | Detailed city model |
| [Red clover](herbs/red_clover.md) | *Trifolium pratense* | punane ristik | Flowers June-August. | Detailed city model |
| [Burdock](herbs/burdock.md) | *Arctium lappa / A. minus* | takjas | Green burrs July-August, dry brown burrs September-October. | Detailed city model |
| [Chamomile](herbs/chamomile.md) | *Matricaria chamomilla* | kummel | Flowers June-August. | Primitive district model, **needs a detailed model** |
| [Yarrow](herbs/yarrow.md) | *Achillea millefolium* | harilik raudrohi | Flowers June-September. | Primitive district model, **needs a detailed model** |
| [St John's wort](herbs/st_johns_wort.md) | *Hypericum perforatum* | liht-naistepuna | Flowers in July, picked on St John's Eve. | Primitive district model, **needs a detailed model** |
| [Stinging nettle](herbs/nettle.md) | *Urtica dioica* | kõrvenõges | Young shoots April-May | Primitive district model, **needs a detailed model** |
| [Mugwort](herbs/mugwort.md) | *Artemisia vulgaris* | harilik puju | Flowers July-September. | Primitive district model, **needs a detailed model** |
| [Creeping thistle](herbs/thistle.md) | *Cirsium arvense* | põldohakas | Flowers July-August. | Primitive district model, **needs a detailed model** |
| [Mint](herbs/mint.md) | *Mentha arvensis / garden mints* | põldmünt | Flowers July-September. | Primitive district model, **needs a detailed model** |
| [Caraway](herbs/caraway.md) | *Carum carvi* | harilik köömen | Flowers June | Primitive district model, **needs a detailed model** |
| [Bracken / male fern](herbs/fern.md) | *Pteridium aquilinum / Dryopteris filix-mas* | kilpjalg / sõnajalg | Fronds May-October. | Primitive district model, **needs a detailed model** |
| [Sphagnum moss](herbs/moss.md) | *Sphagnum spp.* | turbasammal | Evergreen. | Primitive district model, **needs a detailed model** |
| [Common reed](herbs/reed.md) | *Phragmites australis* | harilik pilliroog | Plumes August-September. | Primitive district model, **needs a detailed model** |
| [Bulrush / cattail](herbs/cattail.md) | *Typha latifolia* | laialehine hundinui | Heads July-autumn. | Primitive district model, **needs a detailed model** |
| [White water lily](herbs/water_lily.md) | *Nymphaea alba / N. candida* | valge vesiroos | Flowers June-August. | Primitive district model, **needs a detailed model** |

Moss, lichen and fungi on walls, roofs, trunks and the forest floor are materials and scatter, not plant models: see [moss, lichen and the forest floor](../SYSTEMS/LIVING_VEGETATION.md#moss-lichen-and-the-forest-floor-r-1661).

## Crops

| Crop | Latin | Estonian | Runtime ID |
|---|---|---|---|
| [Rye](crops/rye.md) | *Secale cereale* | rukis | `crop.rye` |
| [Barley](crops/barley.md) | *Hordeum vulgare* | oder | `crop.barley` |
| [Oat](crops/oat.md) | *Avena sativa* | kaer | `crop.oat` |
| [Wheat](crops/wheat.md) | *Triticum aestivum* | nisu | `crop.wheat` |
| [Flax](crops/flax.md) | *Linum usitatissimum* | harilik lina | `crop.flax` |
| [Hemp](crops/hemp.md) | *Cannabis sativa* | kanep | `crop.hemp` |
| [Hops](crops/hops.md) | *Humulus lupulus* | harilik humal | `crop.hops` |
| [Pea](crops/pea.md) | *Pisum sativum* | hernes | `crop.pea` |
| [Broad bean](crops/broad_bean.md) | *Vicia faba* | põlduba | `crop.broad_bean` |
| [Cabbage](crops/cabbage.md) | *Brassica oleracea* | kapsas | `crop.cabbage` |
| [Turnip](crops/turnip.md) | *Brassica rapa* | naeris | `crop.turnip` |
| [Onion](crops/onion.md) | *Allium cepa* | sibul | `crop.onion` |
| [Garlic](crops/garlic.md) | *Allium sativum* | küüslauk | `crop.garlic` |

Seamless-city fields, gardens and pastures: [Farmland](../SYSTEMS/FARMLAND.md).

## Wishlist: common Estonian plants not yet in the game

Research for the user request of 12 October 2026: the most common and best-loved meadow flowers and herbs of Estonia, chamomile-like daisies, the purple and blue flowers, poppy and rapeseed. Each is checked against the period rule (only plants growing round Reval in 1343; later introductions are excluded). Period labels: **high** (native or long-established, common today), **medium** (archaeophyte or garden plant that is plausible but not attested for Reval), **low**, **excluded** (arrived later). They feed the canon entry [Flora of 1343](../CANON.md#flora-of-1343-r-1808). Confirming sources with citations is task **R-1790**.

The slice opens on 21 April 1343, so the early-spring flowers are the first a player sees; the summer meadow flowers carry Act 1 summer.

### Daisies ("ромашки")

| Plant | Estonian | Period | Habitat | Flowers | Look | Use | Priority |
|---|---|---|---|---|---|---|---|
| Oxeye daisy *Leucanthemum vulgare* | härjasilm | high | Hay meadow, dry verge | Jun-Jul | 4-6 cm white heads, 30-60 cm | Tea, Jaanipäev wreaths | **Done** ([card](herbs/oxeye_daisy.md), R-1807); drifts and far speckle R-1792 |
| Chamomile *Matricaria chamomilla* | kummel | medium | Field edges, yards, gardens | Jun-Aug | 1.5-2 cm heads, petals fold back, feathery leaves | The apothecary chamomile: stomach tea, washes | High: detailed model to replace the primitive one ([card](herbs/chamomile.md)) |
| Scentless mayweed *Tripleurospermum inodorum* | lõhnatu kesalill | medium (archaeophyte weed of fields) | Field margins, fallow, roadsides | Jul-Sep | 3-4 cm heads, bushy | None (look-alike of chamomile) | Medium: the "ромашка" along every field edge |

### Purple and blue flowers

The blue spikes of the reference meadow are garden lupines (*Lupinus polyphyllus*), brought from North America in the 19th century: **excluded**. Period-correct substitutes:

| Plant | Estonian | Period | Habitat | Flowers | Look | Use | Priority |
|---|---|---|---|---|---|---|---|
| Cornflower *Centaurea cyanus* | rukkilill | high (archaeophyte of rye fields, common until modern herbicides; Estonia's national flower) | Rye fields and their margins | Jun-Aug | Bright blue fringed heads, 40-80 cm | Blue dye, eye washes | **High**: the iconic Estonian blue flower, needs the field-margin habitat |
| Long-leaved speedwell *Veronica longifolia* | pikalehine mailane | high | Wet meadows, river banks | Jul-Aug | Tall blue-violet spikes, 50-120 cm | - | **High**: closest period stand-in for the lupine spikes |
| Tufted vetch *Vicia cracca* | hiirehernes | high | Hay meadows, hedges | Jun-Aug | One-sided violet spikes scrambling through grass | Fodder | High |
| Meadow cranesbill *Geranium pratense* | aas-kurereha | high | Moist meadows, verges | Jun-Aug | 3-4 cm violet-blue saucers | Wound herb | Medium |
| Bellflowers *Campanula patula*, *C. rotundifolia* | harilik kellukas, ümaralehine kellukas | high | Meadows, dry banks | Jun-Aug | Small violet bells | - | Medium |
| Field scabious *Knautia arvensis* | põld-äiatar | high | Dry meadows, verges | Jun-Aug | Lilac pincushions, 30-80 cm | Skin washes | Medium |
| Purple loosestrife *Lythrum salicaria* | harilik kukesaba | high | Ditch, moat and river banks | Jul-Aug | Magenta spikes, up to 1.2 m | Astringent | Medium: colour for the moat and stream banks |
| Liverleaf *Hepatica nobilis* | sinilill | high | Deciduous and mixed woods | **Apr-May** | Small blue-violet stars before the leaves | Folk remedy (poisonous fresh) | **High**: flowers on the opening date |
| Heather *Calluna vulgaris* | kanarbik | high | Sandy heath | Aug-Sep | Purple dwarf shrub | Tea | Data exists ([card](shrubs/heather.md)); needs a model |
| Wild thyme *Thymus serpyllum* | nõmm-liivatee | high | Sandy pine heath, dry banks | Jun-Aug | Purple mats | Tea, sauna | Medium: fits the coastal pine heath |

### Red and yellow

| Plant | Estonian | Period | Habitat | Flowers | Look | Use | Priority |
|---|---|---|---|---|---|---|---|
| Common poppy *Papaver rhoeas* | põldmagun | medium-low (arable archaeophyte; uncommon in Estonia even today) | Field margins and fallow only, never old meadow | Jun-Aug | Scarlet 5-8 cm cups | Syrup for cough and sleep | Low-medium: a few at field edges, not drifts |
| Opium poppy *Papaver somniferum* | aedmagun | medium (seeds a common medieval Baltic garden find) | Gardens | Jun-Jul | Pale lilac to white cups, grey leaves | Seeds for baking and oil, sleep remedy | Medium: a garden and herbalism plant |
| Oilseed rape *Brassica napus* | raps | **excluded** (a field crop in Estonia from the 19th-20th century; the yellow fields are modern) | - | - | - | - | Do not add |
| Charlock *Sinapis arvensis* | põldsinep | medium (archaeophyte weed of spring grain) | Barley and oat fields | Jun-Aug | Yellow like rape, but scattered | Mustard seed | Medium: the period yellow in the fields instead of rape |
| Marsh marigold *Caltha palustris* | varsakabi | high | Ditches, wet meadows, stream edges | **Apr-May** | Glossy gold cups | Poisonous | **High**: flowers on the opening date |
| Coltsfoot *Tussilago farfara* | paiseleht | high | Bare clay, road cuts, rubble | **Mar-Apr** | Yellow heads before the leaves | Cough tea | **High**: first flower of spring, bare ground in town |
| Cowslip *Primula veris* | nurmenukk | high | Dry meadows, wooded meadows | May | Nodding yellow bells | Tea for cough and sleep | High |
| Lady's bedstraw *Galium verum* | kollane madar | high | Dry meadows | Jun-Aug | Frothy yellow | Curdling milk, Jaanipäev herb | Medium |
| Tansy *Tanacetum vulgare* | soolikarohi | high | Verges, field edges | Jul-Sep | Yellow buttons | Against worms; insect repellent | Medium |

### White, wood and wet ground

| Plant | Estonian | Period | Habitat | Flowers | Use | Priority |
|---|---|---|---|---|---|---|
| Wood anemone *Anemone nemorosa* | valge ülane | high | Woods | **Apr-May**, white carpets | Poisonous | **High**: spring woods on the opening date |
| Meadowsweet *Filipendula ulmaria* | angervaks | high | Wet meadows, ditches | Jun-Aug, cream plumes | Fever and pain tea | High |
| Lily of the valley *Convallaria majalis* | maikelluke | high | Dry woods | May-Jun | Heart remedy, poisonous | Medium |
| Valerian *Valeriana officinalis* | palderjan | high | Wet meadows, banks | Jun-Aug | Sleep and calm | Medium (herbalism) |
| Ribwort plantain *Plantago lanceolata* | ahtalehine teeleht | high | Meadows, verges | May-Sep | Cough, wounds | Medium (cheap variant of the plantain model) |
| Henbane *Hyoscyamus niger* | harilik koerapöörirohi | medium (archaeophyte of middens and yards) | Yards, middens, wall feet | Jun-Aug | Poison and visions | Medium: a dark herb for the spirit layer |
| Wormwood *Artemisia absinthium* | koirohi | medium | Yards, verges | Jul-Aug | Bitter tonic, beer, against moths | Low |

**Suggested order:** cornflower and long-leaved speedwell (blue), detailed chamomile, the early-spring set (marsh marigold, coltsfoot, liverleaf, wood anemone) for the opening date, then charlock and a few poppies at field margins once the field-margin habitat exists (R-1792). Each new plant follows the oxeye daisy pattern: a `CityForbMeshes` model with a far variant, a `FORB_WINDOWS` entry, a `CityForbs` habitat rule, a test, and a card here.

## Herbalism readiness

There is no herbalism or gathering mechanic, and adding one is a scope change (an ADR, removal of equivalent scope and a task, per `AGENTS.md`). The catalogue is prepared so one can be designed without new research:

- **Where to find it.** Each card names the habitat; the runtime already decides it deterministically (`CityForbs.suitability` for city wild plants, ecology rules for blueprint maps, `VegetationPhenology` for the season). A gathering system can ask "which plant stands here today" without saving per-plant state.
- **When.** Each card gives the season. Several herbs are tied to dates the campaign already has: St John's wort and fern on Jaanipäev (23-24 June), spring shoots of nettle and birch sap in April-May, berries in July-September.
- **What for.** Each card gives the historical folk use as flavour for recipes, not modern medical advice.
- **Gaps to close first.** Most herbs on blueprint maps are primitive models; chamomile, yarrow, St John's wort, nettle and mint need detailed models before a player can pick them out by eye. The berry shrubs have no model at all.

## Adding a plant

1. Check the period rule and add or update the wishlist row and its label.
2. Build the model and its habitat and season rules (see [Living vegetation](../SYSTEMS/LIVING_VEGETATION.md)).
3. Re-render portraits with `tools/capture_flora_cards.gd` and add the card in the matching folder, with any close-up and in-world plates.
4. Add the row to the list above, then run `python3 tools/docs_index.py` and `python3 tools/generate_active_docs_report.py`.
