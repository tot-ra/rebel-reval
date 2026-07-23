class_name MapTypes
extends RefCounted

## Shared identifiers and sizing for programmatic map authoring (P0-042).

const TERRAIN_GRASS := &"grass"
const TERRAIN_SAND := &"sand"
const TERRAIN_HAY := &"hay"
const TERRAIN_DIRT := &"dirt"
const TERRAIN_COBBLESTONE := &"cobblestone"
const TERRAIN_WATER := &"water"
const TERRAIN_RIVER_WATER := &"river_water"
const TERRAIN_STONE := &"stone"
const TERRAIN_MEADOW := &"meadow"
const TERRAIN_COAST_SAND := &"coast_sand"
const TERRAIN_STRAW := &"straw"
const TERRAIN_FARM_SOIL := &"farm_soil"
const TERRAIN_MUD := &"mud"
const TERRAIN_FOREST_FLOOR := &"forest_floor"
const TERRAIN_BOG := &"bog"
const TERRAIN_CASTLE_PAVING := &"castle_paving"
const TERRAIN_SHALLOW_WATER := &"shallow_water"
const TERRAIN_DEEP_WATER := &"deep_water"

## Terrain families that block movement until a dedicated water traversal
## mechanic exists.
const WATER_TERRAINS: Array[StringName] = [
	TERRAIN_WATER,
	TERRAIN_RIVER_WATER,
	TERRAIN_SHALLOW_WATER,
	TERRAIN_DEEP_WATER,
]

## District exits are continuous streets, unlike doors into interiors. Marking
## them explicitly lets the view use a ground cue without inventing a door frame.
const TRANSITION_VISUAL_DOOR := &"door"
const TRANSITION_VISUAL_GROUND := &"ground"
const TRANSITION_VISUAL_NONE := &"none"
const TRANSITION_VISUALS: Array[StringName] = [
	TRANSITION_VISUAL_DOOR,
	TRANSITION_VISUAL_GROUND,
	TRANSITION_VISUAL_NONE,
]
const TERRAIN_ASH := &"ash"
const TERRAIN_TIMBER_FLOOR := &"timber_floor"
const TERRAIN_PLASTER := &"plaster"

const ALL_TERRAINS: Array[StringName] = [
	TERRAIN_GRASS,
	TERRAIN_SAND,
	TERRAIN_HAY,
	TERRAIN_DIRT,
	TERRAIN_COBBLESTONE,
	TERRAIN_WATER,
	TERRAIN_RIVER_WATER,
	TERRAIN_STONE,
	TERRAIN_MEADOW,
	TERRAIN_COAST_SAND,
	TERRAIN_STRAW,
	TERRAIN_FARM_SOIL,
	TERRAIN_MUD,
	TERRAIN_FOREST_FLOOR,
	TERRAIN_BOG,
	TERRAIN_CASTLE_PAVING,
	TERRAIN_SHALLOW_WATER,
	TERRAIN_DEEP_WATER,
	TERRAIN_ASH,
	TERRAIN_TIMBER_FLOOR,
	TERRAIN_PLASTER,
]

const BUILDING_KIND_HOUSE := &"house"
const BUILDING_KIND_WALL := &"wall"
const BUILDING_KIND_INTERIOR_WALL := &"interior_wall"
const BUILDING_KIND_INTERIOR_BLOCK := &"interior_block"

const ALL_BUILDING_KINDS: Array[StringName] = [
	BUILDING_KIND_HOUSE,
	BUILDING_KIND_WALL,
	BUILDING_KIND_INTERIOR_WALL,
	BUILDING_KIND_INTERIOR_BLOCK,
]

const PROP_KIND_ANVIL := &"anvil"
const PROP_KIND_HAY_STACK := &"hay_stack"
const PROP_KIND_CART := &"cart"
const PROP_KIND_WELL := &"well"
const PROP_KIND_BARRELS := &"barrels"
const PROP_KIND_FURNACE := &"furnace"
const PROP_KIND_LEDGER := &"ledger"
const PROP_KIND_BED := &"bed"
const PROP_KIND_CHEST := &"chest"
const PROP_KIND_TABLE := &"table"
const PROP_KIND_SHELF := &"shelf"
const PROP_KIND_QUENCH := &"quench_bucket"
const PROP_KIND_STAIRS := &"stairs"
const PROP_KIND_STALL := &"stall"
const PROP_KIND_HEARTH := &"hearth"
const PROP_KIND_CHAIR := &"chair"
const PROP_KIND_CANDLE := &"candle"
const PROP_KIND_BUSH := &"bush"
const PROP_KIND_TREE := &"tree"
const PROP_KIND_FISHING_BOAT := &"fishing_boat"
const PROP_KIND_MERCHANT_BOAT := &"merchant_boat"
const PROP_KIND_CARGO_CRATES := &"cargo_crates"
const PROP_KIND_TRADE_GOODS := &"trade_goods"
const PROP_KIND_TIMBER_FENCE := &"timber_fence"
const PROP_KIND_CATTLE := &"cattle"
const PROP_KIND_SHEEP := &"sheep"
const PROP_KIND_HORSE := &"horse"
const PROP_KIND_BANNER := &"banner"
const PROP_KIND_FISHING_NETS := &"fishing_nets"
const PROP_KIND_FISH_DRYING_RACK := &"fish_drying_rack"
const PROP_KIND_SMOKE_RACK := &"smoke_rack"
const PROP_KIND_FISH_SPLITTING_TABLE := &"fish_splitting_table"
const PROP_KIND_BOAT_TIMBER_STACK := &"boat_timber_stack"
const PROP_KIND_ROPE_COIL := &"rope_coil"
const PROP_KIND_SAIL_CLOTH_BALE := &"sail_cloth_bale"
const PROP_KIND_COOPER_STAVES := &"cooper_staves"
const PROP_KIND_MALT_SACK_PILE := &"malt_sack_pile"
const PROP_KIND_BREWERY_KEG_STACK := &"brewery_keg_stack"
const PROP_KIND_CHARCOAL_PILE := &"charcoal_pile"
const PROP_KIND_IRON_SCRAP_PILE := &"iron_scrap_pile"
const PROP_KIND_WEAPON_RACK := &"weapon_rack"
const PROP_KIND_HERB_DRYING_RACK := &"herb_drying_rack"
const PROP_KIND_MARKET_GOODS_PALLET := &"market_goods_pallet"
const PROP_KIND_SALT_PILE := &"salt_pile"
const PROP_KIND_TANNING_FRAME := &"tanning_frame"
const PROP_KIND_WASH_TUB := &"wash_tub"
const BOAT_PROP_KINDS: Array[StringName] = [PROP_KIND_FISHING_BOAT, PROP_KIND_MERCHANT_BOAT]
const DISTRICT_LIFE_PROP_KINDS: Array[StringName] = [
	PROP_KIND_FISHING_NETS,
	PROP_KIND_FISH_DRYING_RACK,
	PROP_KIND_SMOKE_RACK,
	PROP_KIND_FISH_SPLITTING_TABLE,
	PROP_KIND_BOAT_TIMBER_STACK,
	PROP_KIND_ROPE_COIL,
	PROP_KIND_SAIL_CLOTH_BALE,
	PROP_KIND_COOPER_STAVES,
	PROP_KIND_MALT_SACK_PILE,
	PROP_KIND_BREWERY_KEG_STACK,
	PROP_KIND_CHARCOAL_PILE,
	PROP_KIND_IRON_SCRAP_PILE,
	PROP_KIND_WEAPON_RACK,
	PROP_KIND_HERB_DRYING_RACK,
	PROP_KIND_MARKET_GOODS_PALLET,
	PROP_KIND_SALT_PILE,
	PROP_KIND_TANNING_FRAME,
	PROP_KIND_WASH_TUB,
]

const ALL_PROP_KINDS: Array[StringName] = [
	PROP_KIND_ANVIL,
	PROP_KIND_HAY_STACK,
	PROP_KIND_CART,
	PROP_KIND_WELL,
	PROP_KIND_BARRELS,
	PROP_KIND_FURNACE,
	PROP_KIND_LEDGER,
	PROP_KIND_BED,
	PROP_KIND_CHEST,
	PROP_KIND_TABLE,
	PROP_KIND_SHELF,
	PROP_KIND_QUENCH,
	PROP_KIND_STAIRS,
	PROP_KIND_STALL,
	PROP_KIND_HEARTH,
	PROP_KIND_CHAIR,
	PROP_KIND_CANDLE,
	PROP_KIND_BUSH,
	PROP_KIND_TREE,
	PROP_KIND_FISHING_BOAT,
	PROP_KIND_MERCHANT_BOAT,
	PROP_KIND_CARGO_CRATES,
	PROP_KIND_TRADE_GOODS,
	PROP_KIND_TIMBER_FENCE,
	PROP_KIND_CATTLE,
	PROP_KIND_SHEEP,
	PROP_KIND_HORSE,
	PROP_KIND_BANNER,
	PROP_KIND_FISHING_NETS,
	PROP_KIND_FISH_DRYING_RACK,
	PROP_KIND_SMOKE_RACK,
	PROP_KIND_FISH_SPLITTING_TABLE,
	PROP_KIND_BOAT_TIMBER_STACK,
	PROP_KIND_ROPE_COIL,
	PROP_KIND_SAIL_CLOTH_BALE,
	PROP_KIND_COOPER_STAVES,
	PROP_KIND_MALT_SACK_PILE,
	PROP_KIND_BREWERY_KEG_STACK,
	PROP_KIND_CHARCOAL_PILE,
	PROP_KIND_IRON_SCRAP_PILE,
	PROP_KIND_WEAPON_RACK,
	PROP_KIND_HERB_DRYING_RACK,
	PROP_KIND_MARKET_GOODS_PALLET,
	PROP_KIND_SALT_PILE,
	PROP_KIND_TANNING_FRAME,
	PROP_KIND_WASH_TUB,
]

const DEFAULT_CELL_SIZE := 32
const DEFAULT_SEED := 42042

## City fortifications render taller than authored px heights so walls and towers
## read imposing next to the frozen 2.0-unit character. Low enclosure fences and
## courtyard walls stay at their authored scale.
const FORTIFICATION_HEIGHT_SCALE := 1.5
const FORTIFICATION_MIN_HEIGHT_PX := 128.0


static func resolved_wall_height_px(building: Dictionary) -> float:
	var height_px := float(building.get("wall_height", 64.0))
	var kind: StringName = building.get("kind", BUILDING_KIND_HOUSE)
	if kind != BUILDING_KIND_WALL or height_px < FORTIFICATION_MIN_HEIGHT_PX:
		return height_px
	if building.has("wall_height_scale"):
		return height_px * float(building["wall_height_scale"])
	return height_px * FORTIFICATION_HEIGHT_SCALE


static func resolved_landmark_top_px(landmark: Dictionary) -> float:
	var top_px := float(landmark.get("top_px", 256.0))
	if top_px < FORTIFICATION_MIN_HEIGHT_PX:
		return top_px
	return top_px * FORTIFICATION_HEIGHT_SCALE
