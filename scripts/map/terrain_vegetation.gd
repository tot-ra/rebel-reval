class_name TerrainVegetation
extends RefCounted

## Authored grass and bush style variants for terrain zones and vegetation props.
## Visual tuning lives here; movement penalties are gameplay-relevant and may also
## be overridden per zone or prop via movement_speed_multiplier in rrmap.

const VARIANT_GRASS_SHORT := &"grass.short"
const VARIANT_GRASS_TALL := &"grass.tall"
const VARIANT_GRASS_FLOWERS := &"grass.flowers"
const VARIANT_GRASS_DRY := &"grass.dry"
const VARIANT_GRASS_MOSSY := &"grass.mossy"
const VARIANT_GRASS_CLOVER := &"grass.clover"
const VARIANT_GRASS_FERN := &"grass.fern"
const VARIANT_REED_SHORE := &"reed.shore"
const VARIANT_BUSH_DENSE := &"bush.dense"
const VARIANT_BUSH_SCRUB := &"bush.scrub"

const ALL_VARIANTS: Array[StringName] = [
	VARIANT_GRASS_SHORT,
	VARIANT_GRASS_TALL,
	VARIANT_GRASS_FLOWERS,
	VARIANT_GRASS_DRY,
	VARIANT_GRASS_MOSSY,
	VARIANT_GRASS_CLOVER,
	VARIANT_GRASS_FERN,
	VARIANT_REED_SHORE,
	VARIANT_BUSH_DENSE,
	VARIANT_BUSH_SCRUB,
]

const DEFAULT_BUSH_PROP_SPEED := 0.58
const MIN_SPEED_MULTIPLIER := 0.35
const MAX_SPEED_MULTIPLIER := 1.0


static func resolved_variant(style_id: StringName, values: Dictionary) -> StringName:
	var explicit: Variant = values.get("style_variant", &"")
	if explicit is StringName and not String(explicit).is_empty():
		return explicit
	if not style_id.is_empty():
		return style_id
	return &""


static func is_known_variant(variant: StringName) -> bool:
	return variant.is_empty() or variant in ALL_VARIANTS


static func default_speed_for_variant(variant: StringName) -> float:
	match variant:
		VARIANT_GRASS_TALL:
			return 0.92
		VARIANT_BUSH_DENSE:
			return 0.55
		VARIANT_BUSH_SCRUB:
			return 0.68
		_:
			return 1.0


static func default_speed_for_prop_kind(kind: StringName) -> float:
	if kind == MapTypes.PROP_KIND_BUSH:
		return DEFAULT_BUSH_PROP_SPEED
	return 1.0


static func clamp_speed_multiplier(value: float) -> float:
	return clampf(value, MIN_SPEED_MULTIPLIER, MAX_SPEED_MULTIPLIER)


static func resolved_zone_speed(variant: StringName, authored: Variant) -> float:
	if authored is float or authored is int:
		return clamp_speed_multiplier(float(authored))
	if variant.is_empty():
		return 1.0
	return clamp_speed_multiplier(default_speed_for_variant(variant))


static func resolved_prop_speed(kind: StringName, authored: Variant) -> float:
	if authored is float or authored is int:
		return clamp_speed_multiplier(float(authored))
	return clamp_speed_multiplier(default_speed_for_prop_kind(kind))


static func ground_color_tint(variant: StringName) -> Color:
	match variant:
		VARIANT_GRASS_SHORT:
			return Color(1.04, 1.02, 0.94)
		VARIANT_GRASS_TALL:
			return Color(0.92, 1.05, 0.86)
		VARIANT_GRASS_FLOWERS:
			return Color(0.98, 1.03, 0.9)
		VARIANT_GRASS_DRY:
			return Color(1.12, 1.04, 0.82)
		VARIANT_GRASS_MOSSY:
			return Color(0.9, 1.06, 0.92)
		VARIANT_GRASS_CLOVER:
			return Color(0.94, 1.08, 0.88)
		VARIANT_GRASS_FERN:
			return Color(0.88, 1.04, 0.84)
		VARIANT_REED_SHORE:
			return Color(0.92, 1.02, 0.78)
		VARIANT_BUSH_DENSE, VARIANT_BUSH_SCRUB:
			return Color(0.86, 1.0, 0.82)
		_:
			return Color.WHITE


static func scatter_profile(variant: StringName) -> Dictionary:
	match variant:
		VARIANT_GRASS_SHORT:
			return {"chance_scale": 0.55, "height_min": 0.35, "height_max": 0.62, "flower_chance": 0.0}
		VARIANT_GRASS_TALL:
			return {"chance_scale": 1.15, "height_min": 0.95, "height_max": 1.55, "flower_chance": 0.0}
		VARIANT_GRASS_FLOWERS:
			return {"chance_scale": 0.95, "height_min": 0.65, "height_max": 1.05, "flower_chance": 0.22}
		VARIANT_GRASS_DRY:
			return {"chance_scale": 0.75, "height_min": 0.5, "height_max": 0.9, "flower_chance": 0.0}
		VARIANT_GRASS_MOSSY:
			return {"chance_scale": 0.85, "height_min": 0.45, "height_max": 0.8, "flower_chance": 0.0}
		VARIANT_GRASS_CLOVER:
			return {"chance_scale": 0.7, "height_min": 0.25, "height_max": 0.45, "flower_chance": 0.08, "clover_chance": 0.35}
		VARIANT_GRASS_FERN:
			return {"chance_scale": 0.95, "height_min": 0.55, "height_max": 1.0, "flower_chance": 0.0, "fern_chance": 0.4}
		VARIANT_REED_SHORE:
			return {"chance_scale": 0.8, "height_min": 0.9, "height_max": 1.6, "flower_chance": 0.0, "reed_chance": 0.55}
		VARIANT_BUSH_DENSE:
			return {"chance_scale": 1.25, "height_min": 0.55, "height_max": 1.1, "flower_chance": 0.0, "bush_chance": 0.65}
		VARIANT_BUSH_SCRUB:
			return {"chance_scale": 0.9, "height_min": 0.45, "height_max": 0.85, "flower_chance": 0.0, "bush_chance": 0.35}
		_:
			return {"chance_scale": 1.0, "height_min": 0.7, "height_max": 1.4, "flower_chance": 0.0, "bush_chance": 0.0}
