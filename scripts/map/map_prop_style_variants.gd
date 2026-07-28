class_name MapPropStyleVariants
extends RefCounted

## Domain-aware allowlist for prop style_variant values. Vegetation keeps its
## species registry while reusable district props can define independent variants.

const FISH_RACK_EMPTY := &"fish_rack.empty"
const FISH_RACK_HERRING := &"fish_rack.herring"
const FISH_RACK_MIXED := &"fish_rack.mixed"
const FISH_RACK_VARIANTS: Array[StringName] = [
	FISH_RACK_EMPTY,
	FISH_RACK_HERRING,
	FISH_RACK_MIXED,
]

const STORAGE_COMMON_OPEN := &"shelf.common_open"
const STORAGE_BURGHER_CUPBOARD := &"shelf.burgher_cupboard"
const STORAGE_ELITE_ARMARIUM := &"shelf.elite_armarium"
const STORAGE_FURNITURE_VARIANTS: Array[StringName] = [
	STORAGE_COMMON_OPEN,
	STORAGE_BURGHER_CUPBOARD,
	STORAGE_ELITE_ARMARIUM,
]

const CHEST_PLAIN_COFFER := &"chest.plain_coffer"
const CHEST_BURGHER := &"chest.burgher"
const CHEST_MERCHANT_STRONGBOX := &"chest.merchant_strongbox"
const CHEST_VARIANTS: Array[StringName] = [
	CHEST_PLAIN_COFFER,
	CHEST_BURGHER,
	CHEST_MERCHANT_STRONGBOX,
]

const TABLE_COMMON_HOUSEHOLD := &"table.common_household"
const TABLE_TRESTLE_WORK := &"table.trestle_work"
const TABLE_LONG_BOARD := &"table.long_board"
const TABLE_VARIANTS: Array[StringName] = [
	TABLE_COMMON_HOUSEHOLD,
	TABLE_TRESTLE_WORK,
	TABLE_LONG_BOARD,
]


static func is_known(kind: StringName, variant: StringName) -> bool:
	if variant.is_empty():
		return true
	if kind == MapTypes.PROP_KIND_FISH_DRYING_RACK:
		return variant in FISH_RACK_VARIANTS
	if kind == MapTypes.PROP_KIND_CHEST:
		return variant in CHEST_VARIANTS
	if kind == MapTypes.PROP_KIND_SHELF:
		return variant in STORAGE_FURNITURE_VARIANTS
	if kind == MapTypes.PROP_KIND_TABLE or kind == MapTypes.PROP_KIND_FISH_SPLITTING_TABLE:
		return variant in TABLE_VARIANTS
	if kind == MapTypes.PROP_KIND_CANDLE:
		return variant in MapTypes.LIGHTING_VARIANTS
	return TerrainVegetation.is_known_variant(variant)
