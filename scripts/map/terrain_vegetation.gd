class_name TerrainVegetation
extends RefCounted

## Vegetation is layered deliberately: the terrain material supplies continuous
## ground cover while only a minority of cells receive small grass, large grass,
## shrubs, or trees. Movement penalties remain gameplay-relevant and may be
## overridden per zone or prop via movement_speed_multiplier in rrmap.

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
const VARIANT_TREE_SPRUCE := &"tree.spruce"
const VARIANT_TREE_PINE := &"tree.pine"
const VARIANT_TREE_BIRCH := &"tree.birch"
const VARIANT_TREE_OAK := &"tree.oak"
const VARIANT_TREE_ALDER := &"tree.alder"
const VARIANT_TREE_ASPEN := &"tree.aspen"
const VARIANT_TREE_MAPLE := &"tree.maple"
const VARIANT_TREE_LINDEN := &"tree.linden"
const VARIANT_TREE_APPLE := &"tree.apple"
const VARIANT_TREE_CHERRY := &"tree.cherry"
const VARIANT_TREE_ORCHARD := &"tree.orchard"
const VARIANT_TREE_DECIDUOUS := &"tree.deciduous"
const VARIANT_TREE_MIXED := &"tree.mixed"

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
	VARIANT_TREE_SPRUCE,
	VARIANT_TREE_PINE,
	VARIANT_TREE_BIRCH,
	VARIANT_TREE_OAK,
	VARIANT_TREE_ALDER,
	VARIANT_TREE_ASPEN,
	VARIANT_TREE_MAPLE,
	VARIANT_TREE_LINDEN,
	VARIANT_TREE_APPLE,
	VARIANT_TREE_CHERRY,
	VARIANT_TREE_ORCHARD,
	VARIANT_TREE_DECIDUOUS,
	VARIANT_TREE_MIXED,
]

## Urban green surfaces remain visible through the terrain texture, but repeated
## 3D vegetation is intentionally scarce. Explicit authored planting is retained
## at a moderate density so gardens and landmark trees still read.
const URBAN_IMPLICIT_OBJECT_DENSITY := 0.08
const URBAN_AUTHORED_OBJECT_DENSITY := 0.42

const DEFAULT_BUSH_PROP_SPEED := 0.58
const DEFAULT_TREE_PROP_SPEED := 0.9
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
	if variant.is_empty() or variant in ALL_VARIANTS:
		return true
	# tree.oak.large / tree.birch.small are valid authored size pins.
	var parsed: Dictionary = MapViewTreeSpecies.parse_variant(variant)
	return not parsed.is_empty()


static func is_tree_variant(variant: StringName) -> bool:
	return not MapViewTreeSpecies.parse_variant(variant).is_empty()


static func object_density_multiplier(is_urban: bool, variant: StringName) -> float:
	if not is_urban:
		return 1.0
	return URBAN_IMPLICIT_OBJECT_DENSITY if variant.is_empty() else URBAN_AUTHORED_OBJECT_DENSITY


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
	if kind == MapTypes.PROP_KIND_TREE:
		return DEFAULT_TREE_PROP_SPEED
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
		VARIANT_TREE_SPRUCE, VARIANT_TREE_PINE:
			return Color(0.82, 0.94, 0.82)
		VARIANT_TREE_ALDER:
			return Color(0.86, 0.98, 0.84)
		VARIANT_TREE_APPLE, VARIANT_TREE_CHERRY, VARIANT_TREE_ORCHARD:
			return Color(0.94, 1.04, 0.82)
		_:
			if is_tree_variant(variant):
				return Color(0.9, 1.0, 0.84)
			return Color.WHITE


## Per-style object layers. `small_chance_scale` multiplies terrain-family
## density; all other chances are direct per-cell probabilities before urban
## suppression. Ground cover itself is always supplied by the terrain material.
static func scatter_profile(variant: StringName) -> Dictionary:
	var tree_parsed: Dictionary = MapViewTreeSpecies.parse_variant(variant)
	if not tree_parsed.is_empty():
		var tree_chance := 0.2
		if tree_parsed.get("group", &"") == &"orchard" or variant == VARIANT_TREE_ORCHARD:
			# Orchard rows need readable individual crowns without becoming forest.
			tree_chance = 0.18
		elif tree_parsed.get("group", &"") == &"mixed" or variant == VARIANT_TREE_MIXED:
			tree_chance = 0.22
		elif tree_parsed.has("species"):
			tree_chance = 0.24
		return {
			"small_chance_scale": 0.22,
			"large_chance": 0.02,
			"tree_chance": tree_chance,
			"tree_variant": variant,
		}
	match variant:
		VARIANT_GRASS_SHORT:
			return {"small_chance_scale": 1.0, "small_height_min": 0.3, "small_height_max": 0.55, "large_chance": 0.01}
		VARIANT_GRASS_TALL:
			# Sparse pasture trees outside town: saplings along meadow edges.
			return {
				"small_chance_scale": 0.65,
				"small_height_min": 0.42,
				"small_height_max": 0.72,
				"large_chance": 0.24,
				"large_height_min": 0.95,
				"large_height_max": 1.5,
				"tree_chance": 0.012,
				"tree_variant": VARIANT_TREE_MIXED,
			}
		VARIANT_GRASS_FLOWERS:
			return {"small_chance_scale": 0.85, "small_height_min": 0.38, "small_height_max": 0.68, "large_chance": 0.07, "large_height_min": 0.72, "large_height_max": 1.05, "flower_chance": 0.12}
		VARIANT_GRASS_DRY:
			return {"small_chance_scale": 0.7, "small_height_min": 0.34, "small_height_max": 0.62, "large_chance": 0.05, "large_height_min": 0.68, "large_height_max": 0.95}
		VARIANT_GRASS_MOSSY:
			return {"small_chance_scale": 0.45, "small_height_min": 0.28, "small_height_max": 0.5, "large_chance": 0.015}
		VARIANT_GRASS_CLOVER:
			return {"small_chance_scale": 0.3, "small_height_min": 0.25, "small_height_max": 0.45, "large_chance": 0.01, "clover_chance": 0.28}
		VARIANT_GRASS_FERN:
			return {"small_chance_scale": 0.35, "small_height_min": 0.32, "small_height_max": 0.56, "large_chance": 0.025, "fern_chance": 0.24}
		VARIANT_REED_SHORE:
			return {"small_chance_scale": 0.2, "small_height_min": 0.3, "small_height_max": 0.55, "large_chance": 0.0, "reed_chance": 0.34}
		VARIANT_BUSH_DENSE:
			return {"small_chance_scale": 0.18, "large_chance": 0.02, "dense_bush_chance": 0.32}
		VARIANT_BUSH_SCRUB:
			return {"small_chance_scale": 0.28, "large_chance": 0.03, "scrub_bush_chance": 0.24}
		_:
			return {"small_chance_scale": 1.0, "small_height_min": 0.34, "small_height_max": 0.62, "large_chance": 0.025, "large_height_min": 0.75, "large_height_max": 1.05}
