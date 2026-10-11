extends RefCounted

## Procedural texture raster sizes for the 3D map view material stack.
##
## MapViewMaterials re-exports these values so contract tests keep one stable
## facade. Pattern painters and terrain caches import this module directly so
## sizes are not duplicated across modules.

const TEXTURE_SIZE := 128
## Cobblestone fills most of the gameplay frame at street level, so it needs a
## denser source than secondary materials to keep joints and stone grain sharp.
const COBBLE_TEXTURE_SIZE := 512
## Authored grass/mud plates stay at their native 512 px. Downscaling them into
## the 128 px terrain array was the main reason meadows and yards read as blur.
const NATURAL_GROUND_TEXTURE_SIZE := 512
## Wall, tower and gate faces are the tallest surfaces in frame and are read from
## a few metres away, so masonry needs a denser source than secondary materials
## to keep rubble courses, joints and chipped arrises legible.
const MASONRY_TEXTURE_SIZE := 512
## Clay roof tiles carry curved monk/nun profiles and course lips that feed a
## relief normal map. 128 px left only ~10 px per tile, which read as flat
## scales; 256 px keeps 32 px per tile while roof plates stay per-variant cached.
const ROOF_TILE_TEXTURE_SIZE := 256
