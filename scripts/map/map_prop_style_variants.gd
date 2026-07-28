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


static func is_known(kind: StringName, variant: StringName) -> bool:
	if variant.is_empty():
		return true
	if kind == MapTypes.PROP_KIND_FISH_DRYING_RACK:
		return variant in FISH_RACK_VARIANTS
	return TerrainVegetation.is_known_variant(variant)
