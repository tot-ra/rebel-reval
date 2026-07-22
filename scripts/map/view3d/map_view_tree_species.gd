class_name MapViewTreeSpecies
extends RefCounted

## Estonian roadside, woodland, and orchard trees for Reval latitudes. Species
## drive a bounded fractal growth profile, bark, foliage tint, and optional fruit;
## size classes scale cached meshes so MultiMesh batches remain cheap.

const SPECIES_SPRUCE := &"spruce"
const SPECIES_PINE := &"pine"
const SPECIES_BIRCH := &"birch"
const SPECIES_OAK := &"oak"
const SPECIES_ALDER := &"alder"
const SPECIES_ASPEN := &"aspen"
const SPECIES_MAPLE := &"maple"
const SPECIES_LINDEN := &"linden"
const SPECIES_APPLE := &"apple"
const SPECIES_CHERRY := &"cherry"
const SPECIES_ASH := &"ash"
const SPECIES_ELM := &"elm"
const SPECIES_WILLOW := &"willow"
const SPECIES_ROWAN := &"rowan"
const SPECIES_HAZEL := &"hazel"
const SPECIES_JUNIPER := &"juniper"
const SPECIES_PLUM := &"plum"
const SPECIES_PEAR := &"pear"
const SPECIES_HAWTHORN := &"hawthorn"
const SPECIES_BLACKTHORN := &"blackthorn"

const ALL_SPECIES: Array[StringName] = [
	SPECIES_SPRUCE,
	SPECIES_PINE,
	SPECIES_BIRCH,
	SPECIES_OAK,
	SPECIES_ALDER,
	SPECIES_ASPEN,
	SPECIES_MAPLE,
	SPECIES_LINDEN,
	SPECIES_APPLE,
	SPECIES_CHERRY,
	SPECIES_ASH,
	SPECIES_ELM,
	SPECIES_WILLOW,
	SPECIES_ROWAN,
	SPECIES_HAZEL,
	SPECIES_JUNIPER,
	SPECIES_PLUM,
	SPECIES_PEAR,
	SPECIES_HAWTHORN,
	SPECIES_BLACKTHORN,
]

const SIZE_SMALL := &"small"
const SIZE_MEDIUM := &"medium"
const SIZE_LARGE := &"large"

const ALL_SIZES: Array[StringName] = [SIZE_SMALL, SIZE_MEDIUM, SIZE_LARGE]

const SILHOUETTE_SPRUCE := &"spruce"
const SILHOUETTE_PINE := &"pine"
const SILHOUETTE_BROAD := &"broad"
const SILHOUETTE_COLUMN := &"column"
const SILHOUETTE_ORCHARD := &"orchard"
const SILHOUETTE_WEEPING := &"weeping"
const SILHOUETTE_SHRUB := &"shrub"

const BARK_DEFAULT := &"bark"
const BARK_BIRCH := &"birch"
const BARK_CHERRY := &"cherry"

## Local Estonian mix for mixed woodland and exterior treelines: spruce and pine
## dominate the north Baltic canopy, with birch and aspen common on margins.
const MIXED_WEIGHTS: Dictionary = {
	SPECIES_SPRUCE: 0.20,
	SPECIES_PINE: 0.16,
	SPECIES_BIRCH: 0.13,
	SPECIES_ASPEN: 0.08,
	SPECIES_ALDER: 0.07,
	SPECIES_OAK: 0.06,
	SPECIES_MAPLE: 0.04,
	SPECIES_LINDEN: 0.04,
	SPECIES_ASH: 0.04,
	SPECIES_ELM: 0.03,
	SPECIES_WILLOW: 0.03,
	SPECIES_ROWAN: 0.04,
	SPECIES_HAZEL: 0.03,
	SPECIES_JUNIPER: 0.03,
	SPECIES_HAWTHORN: 0.01,
	SPECIES_BLACKTHORN: 0.01,
}

const DECIDUOUS_WEIGHTS: Dictionary = {
	SPECIES_BIRCH: 0.19,
	SPECIES_OAK: 0.12,
	SPECIES_ASPEN: 0.11,
	SPECIES_ALDER: 0.10,
	SPECIES_MAPLE: 0.08,
	SPECIES_LINDEN: 0.08,
	SPECIES_ASH: 0.08,
	SPECIES_ELM: 0.06,
	SPECIES_WILLOW: 0.06,
	SPECIES_ROWAN: 0.05,
	SPECIES_HAZEL: 0.04,
	SPECIES_HAWTHORN: 0.02,
	SPECIES_BLACKTHORN: 0.01,
}

## Orchard stands deliberately exclude woodland species. Apple dominates the
## historical northern orchard mix, with sour cherry providing smaller crowns.
const ORCHARD_WEIGHTS: Dictionary = {
	SPECIES_APPLE: 0.48,
	SPECIES_CHERRY: 0.18,
	SPECIES_PLUM: 0.20,
	SPECIES_PEAR: 0.14,
}

## Size distribution for procedural scatter: medium trees carry the silhouette;
## saplings and veterans stay rare so stands read natural rather than uniform.
const SIZE_WEIGHTS: Dictionary = {
	SIZE_SMALL: 0.26,
	SIZE_MEDIUM: 0.50,
	SIZE_LARGE: 0.24,
}

## Uniform footprint scale range (XZ and base Y) per size class. Large veterans
## also get SIZE_HEIGHT_MULTIPLIER so they read much taller than medium crowns.
const SIZE_SCALE: Dictionary = {
	SIZE_SMALL: Vector2(0.40, 0.58),
	SIZE_MEDIUM: Vector2(0.82, 1.08),
	SIZE_LARGE: Vector2(1.45, 1.90),
}

## Extra vertical stretch. Large trees push well above the medium canopy line
## without becoming comically thick trunks.
const SIZE_HEIGHT_MULTIPLIER: Dictionary = {
	SIZE_SMALL: 0.92,
	SIZE_MEDIUM: 1.0,
	SIZE_LARGE: 1.48,
}


static func is_known_species(species: StringName) -> bool:
	return species in ALL_SPECIES


static func is_known_size(size_class: StringName) -> bool:
	return size_class in ALL_SIZES


## Resolve an authored vegetation variant into optional pinned species/size.
## Examples: tree.oak, tree.birch.large, tree.mixed, tree.deciduous.
static func parse_variant(variant: StringName) -> Dictionary:
	var text := String(variant)
	if text.is_empty() or not text.begins_with("tree."):
		return {}
	var parts := text.split(".")
	# ["tree", species_or_group, optional size]
	if parts.size() < 2:
		return {}
	var token := StringName(parts[1])
	var size_class := SIZE_MEDIUM
	if parts.size() >= 3 and is_known_size(StringName(parts[2])):
		size_class = StringName(parts[2])
	match token:
		&"mixed", &"deciduous", &"orchard":
			return {"group": token, "size": size_class}
		_:
			if is_known_species(token):
				return {"species": token, "size": size_class}
	return {}


static func silhouette_for(species: StringName) -> StringName:
	match species:
		SPECIES_SPRUCE:
			return SILHOUETTE_SPRUCE
		SPECIES_PINE:
			return SILHOUETTE_PINE
		SPECIES_BIRCH, SPECIES_ASPEN, SPECIES_ASH, SPECIES_ELM, SPECIES_ROWAN, SPECIES_PEAR:
			return SILHOUETTE_COLUMN
		SPECIES_APPLE, SPECIES_CHERRY, SPECIES_PLUM:
			return SILHOUETTE_ORCHARD
		SPECIES_WILLOW:
			return SILHOUETTE_WEEPING
		SPECIES_HAZEL, SPECIES_HAWTHORN, SPECIES_BLACKTHORN:
			return SILHOUETTE_SHRUB
		SPECIES_JUNIPER:
			return SILHOUETTE_SPRUCE
		_:
			return SILHOUETTE_BROAD


static func bark_kind_for(species: StringName) -> StringName:
	match species:
		SPECIES_BIRCH:
			return BARK_BIRCH
		SPECIES_CHERRY:
			return BARK_CHERRY
		SPECIES_PLUM:
			return BARK_CHERRY
		_:
			return BARK_DEFAULT


static func canopy_material_kind(species: StringName) -> StringName:
	match silhouette_for(species):
		SILHOUETTE_SPRUCE:
			return &"spruce"
		SILHOUETTE_PINE:
			return &"pine"
		SILHOUETTE_COLUMN:
			return &"column"
		SILHOUETTE_ORCHARD:
			return &"orchard"
		SILHOUETTE_WEEPING:
			return &"column"
		SILHOUETTE_SHRUB:
			return &"orchard"
		_:
			return &"leaf"


## Base instance tint multiplied onto the canopy material. Values stay near 1 so
## wind shaders remain readable while species still separate at a glance.
static func canopy_tint(species: StringName, roll: float) -> Color:
	var variance := 0.88 + roll * 0.24
	match species:
		SPECIES_SPRUCE:
			return Color(variance * 0.86, variance, variance * 0.84)
		SPECIES_PINE:
			return Color(variance * 0.78, variance * 0.92, variance * 0.72)
		SPECIES_BIRCH:
			return Color(variance * 0.94, variance * 1.02, variance * 0.78)
		SPECIES_OAK:
			return Color(variance * 0.90, variance * 0.96, variance * 0.70)
		SPECIES_ALDER:
			return Color(variance * 0.82, variance * 0.98, variance * 0.78)
		SPECIES_ASPEN:
			return Color(variance * 0.98, variance * 1.04, variance * 0.72)
		SPECIES_MAPLE:
			return Color(variance * 0.92, variance * 1.0, variance * 0.68)
		SPECIES_LINDEN:
			return Color(variance * 0.96, variance * 1.02, variance * 0.76)
		SPECIES_APPLE:
			return Color(variance * 0.84, variance * 1.02, variance * 0.70)
		SPECIES_CHERRY:
			return Color(variance * 0.92, variance * 1.04, variance * 0.74)
		SPECIES_ASH:
			return Color(variance * 0.84, variance * 1.02, variance * 0.74)
		SPECIES_ELM:
			return Color(variance * 0.78, variance * 0.96, variance * 0.66)
		SPECIES_WILLOW:
			return Color(variance * 0.94, variance * 1.04, variance * 0.72)
		SPECIES_ROWAN:
			return Color(variance * 0.88, variance * 1.02, variance * 0.66)
		SPECIES_HAZEL:
			return Color(variance * 0.80, variance * 0.96, variance * 0.68)
		SPECIES_JUNIPER:
			return Color(variance * 0.64, variance * 0.84, variance * 0.70)
		SPECIES_PLUM:
			return Color(variance * 0.82, variance * 0.98, variance * 0.68)
		SPECIES_PEAR:
			return Color(variance * 0.88, variance * 1.02, variance * 0.70)
		SPECIES_HAWTHORN:
			return Color(variance * 0.80, variance * 0.98, variance * 0.72)
		SPECIES_BLACKTHORN:
			return Color(variance * 0.70, variance * 0.90, variance * 0.64)
		_:
			return Color(variance * 0.96, variance, variance * 0.78)


static func bark_tint(species: StringName, roll: float) -> Color:
	var shade := 0.82 + roll * 0.28
	if species == SPECIES_BIRCH:
		# Pale paper bark with a cool grey cast, not pure white.
		var pale := 0.92 + roll * 0.08
		return Color(pale, pale * 0.98, pale * 0.94)
	if species == SPECIES_PINE:
		return Color(shade * 1.05, shade * 0.88, shade * 0.72)
	if species == SPECIES_ALDER:
		return Color(shade * 0.92, shade * 0.86, shade * 0.78)
	if species in [SPECIES_CHERRY, SPECIES_PLUM]:
		return Color(shade * 0.78, shade * 0.48, shade * 0.42)
	if species in [SPECIES_APPLE, SPECIES_PEAR]:
		return Color(shade * 0.92, shade * 0.78, shade * 0.62)
	if species == SPECIES_WILLOW:
		return Color(shade * 0.82, shade * 0.84, shade * 0.74)
	if species == SPECIES_JUNIPER:
		return Color(shade * 0.80, shade * 0.74, shade * 0.64)
	return Color(shade, shade * 0.96, shade * 0.9)


static func weights_for_variant(variant: StringName) -> Dictionary:
	var parsed := parse_variant(variant)
	if parsed.has("species"):
		return {parsed["species"]: 1.0}
	match parsed.get("group", &""):
		&"deciduous":
			return DECIDUOUS_WEIGHTS
		&"orchard":
			return ORCHARD_WEIGHTS
		&"mixed":
			return MIXED_WEIGHTS
	# Unstyled forest floor and exterior bands default to the full Estonian mix.
	return MIXED_WEIGHTS


static func pick_weighted(weights: Dictionary, roll: float, fallback: StringName) -> StringName:
	var total := 0.0
	for weight: Variant in weights.values():
		total += float(weight)
	if total <= 0.0:
		return fallback
	var cursor := clampf(roll, 0.0, 0.999999) * total
	var last_key: StringName = fallback
	for key: Variant in weights.keys():
		last_key = key as StringName
		cursor -= float(weights[key])
		if cursor <= 0.0:
			return last_key
	return last_key


static func pick_species(weights: Dictionary, roll: float) -> StringName:
	return pick_weighted(weights, roll, SPECIES_SPRUCE)


static func pick_size(roll: float, pinned: StringName = &"") -> StringName:
	if is_known_size(pinned):
		return pinned
	return pick_weighted(SIZE_WEIGHTS, roll, SIZE_MEDIUM)


static func scale_range(size_class: StringName) -> Vector2:
	return SIZE_SCALE.get(size_class, SIZE_SCALE[SIZE_MEDIUM])


static func height_multiplier(size_class: StringName) -> float:
	return float(SIZE_HEIGHT_MULTIPLIER.get(size_class, 1.0))


## Non-uniform instance scale: roll picks within SIZE_SCALE, then height bias
## stretches Y so large trees tower over the stand.
static func instance_scale(size_class: StringName, roll: float = 0.5) -> Vector3:
	var range := scale_range(size_class)
	var uniform := range.x + clampf(roll, 0.0, 1.0) * (range.y - range.x)
	var height := uniform * height_multiplier(size_class)
	return Vector3(uniform, height, uniform)


## The new procedural meshes are rooted at local y = 0. These compatibility
## accessors remain for older callers while new tree builders use zero lift.
static func trunk_height() -> float:
	return 1.2


static func canopy_lift(_species: StringName) -> float:
	return 0.0


static func trunk_lift() -> float:
	return 0.0
