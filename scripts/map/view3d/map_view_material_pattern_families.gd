extends RefCounted

## Closed set of procedural pattern family IDs for terrain, building, and prop surfaces.
##
## MapViewMaterials re-exports these constants so builders and tests keep one
## stable facade. Pattern painters and UV tables import this module directly so
## the IDs are not duplicated across terrain, building, and prop caches.

const PATTERN_GRASS := &"grass"
const PATTERN_SPECKLE := &"speckle"
const PATTERN_MUD := &"mud"
## Packed-earth streets and yards. Separate from PATTERN_SPECKLE so sand and ash
## keep their fine even grain while trodden earth gains gravel, ruts and cracks.
const PATTERN_EARTH := &"earth"
const PATTERN_COBBLE := &"cobble"
const PATTERN_BRICK := &"brick"
const PATTERN_PLANK := &"plank"
const PATTERN_LIMESTONE := &"limestone"
## Weathered boulders and shoreline scatter: organic mottling without ashlar
## courses so sphere meshes do not read as brick bands at lake/sea edges.
const PATTERN_ROCK := &"rock"
const PATTERN_ROOF_TILE := &"roof_tile"
const PATTERN_PLASTER := &"plaster"
const PATTERN_STRAW := &"straw"
## Layered reed/straw thatch courses for roofs. Distinct from PATTERN_STRAW so
## hay/terrain scatter keeps its soft field look while roofs read as bundled reed.
const PATTERN_THATCH := &"thatch"
const PATTERN_SHINGLE := &"shingle"
const PATTERN_LOG := &"log"
const PATTERN_BARK := &"bark"
const PATTERN_BIRCH_BARK := &"birch_bark"
const PATTERN_CHERRY_BARK := &"cherry_bark"
