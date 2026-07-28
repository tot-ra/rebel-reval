# hendrikReyneke Sketchfab model review

Reviewed 2026-07-28 from the public Sketchfab profile and v3 model metadata API. All selected models are downloadable under **Creative Commons Attribution 4.0**, which permits commercial use and modification when the creator is credited. The imported sources contain no authored animation.

## Imported first pass

| Sketchfab model | Source triangles | Runtime use | Decision |
|---|---:|---|---|
| Chicken | 4,200 | Penned chicken actor | Imported; strong fit for existing farmyard placements. |
| Duck | 2,470 | Penned duck actor and standing mallard mesh | Imported; folded-wing standing pose matches ground actors. |
| Goat | 5,278 | Tethered Viru foreland farmstead actor | Imported; adds a missing historically plausible domestic species. |
| Sparrow | 2,106 | Perched house sparrow | Imported; pose and budget match the authored-bird GLB contract. |
| Pig | 6,748 | Existing rigged medieval pig actor | Already integrated from the same creator and retained. |

Runtime files are normalized to metric scale, centred, grounded, and keep the source PBR textures. Missing animation continues to use the existing lightweight root-motion ambient behaviour; the previously integrated pig remains separately rigged.

## Reviewed but not imported in this pass

| Model | Source triangles | Reason |
|---|---:|---|
| Cow | 6,120 | The project already ships a purpose-built rigged cattle model with idle/walk clips. |
| Sheep | 4,372 | The project already ships a purpose-built rigged sheep model with idle/walk clips. |
| Crow | 2,208 | Good future base for rook; generic black plumage is not accurate for the current hooded-crow profile. |
| Pigeon | 2,394 | No pigeon species exists in the signed north-Baltic bird catalog yet. |
| Seagull | 2,638 | Source is standing while current gull runtime defaults to a gliding flap cycle. |
| Eagle | 3,700 | Source is perched while current white-tailed eagle runtime requires a gliding silhouette. |
| Owl | 3,438 | Could support tawny owl after plumage review; deferred to the dedicated bird batch. |
| Blue Jay | 4,444 | North American species, unsuitable for Reval 1343. |

## Sources and license

- Creator: https://sketchfab.com/hendrikReyneke
- Farm collection: https://sketchfab.com/hendrikReyneke/collections/farm-animals-9544a9c4210d4bd18fe84df53134edb7
- License: https://creativecommons.org/licenses/by/4.0/
- Full per-file source URLs and checksums: `assets/SOURCES.csv`
