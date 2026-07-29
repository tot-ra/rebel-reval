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

const HAY_STACK_SMALL := &"hay_stack.small"
const HAY_STACK_MEDIUM := &"hay_stack.medium"
const HAY_STACK_TALL := &"hay_stack.tall"
const HAY_STACK_VARIANTS: Array[StringName] = [
	HAY_STACK_SMALL,
	HAY_STACK_MEDIUM,
	HAY_STACK_TALL,
]
const DEFAULT_HAY_STACK_VARIANT := HAY_STACK_MEDIUM

const HEARTH_STATE_LIT := MapTypes.HEARTH_STATE_LIT
const HEARTH_STATE_EMBERS := MapTypes.HEARTH_STATE_EMBERS
const HEARTH_STATE_COLD := MapTypes.HEARTH_STATE_COLD
const HEARTH_STATE_VARIANTS: Array[StringName] = [
	HEARTH_STATE_LIT,
	HEARTH_STATE_EMBERS,
	HEARTH_STATE_COLD,
]

const KITCHENWARE_VARIANTS: Array[StringName] = MapTypes.KITCHENWARE_VARIANTS
const HOUSEHOLD_CLUTTER_VARIANTS: Array[StringName] = MapTypes.HOUSEHOLD_CLUTTER_VARIANTS

## Closed R-003 / P0-163 ordinary Lower Town house tiers. Optional on house
## buildings; empty means "unset / legacy hash style" until P2-067 wiring.
const HOUSE_TIER_MERCHANT_STONE := &"merchant_stone"
const HOUSE_TIER_MERCHANT_TIMBER := &"merchant_timber"
const HOUSE_TIER_CRAFT_BODA := &"craft_boda"
const HOUSE_TIERS: Array[StringName] = [
	HOUSE_TIER_MERCHANT_STONE,
	HOUSE_TIER_MERCHANT_TIMBER,
	HOUSE_TIER_CRAFT_BODA,
]


static func is_known_house_tier(tier: StringName) -> bool:
	if tier.is_empty():
		return true
	return tier in HOUSE_TIERS


static func house_tier_allows_hoist(tier: StringName) -> bool:
	return tier == HOUSE_TIER_MERCHANT_STONE or tier == HOUSE_TIER_MERCHANT_TIMBER


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
	if kind == MapTypes.PROP_KIND_HAY_STACK:
		return variant in HAY_STACK_VARIANTS
	if kind == MapTypes.PROP_KIND_HEARTH:
		return variant in HEARTH_STATE_VARIANTS
	if kind == MapTypes.PROP_KIND_KITCHENWARE:
		return variant in KITCHENWARE_VARIANTS
	if kind == MapTypes.PROP_KIND_HOUSEHOLD_CLUTTER:
		return variant in HOUSEHOLD_CLUTTER_VARIANTS
	if kind == MapTypes.PROP_KIND_CANDLE:
		return variant in MapTypes.LIGHTING_VARIANTS
	return TerrainVegetation.is_known_variant(variant)
