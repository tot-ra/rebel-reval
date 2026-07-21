class_name MapViewTreeSpecies
extends RefCounted

## Estonian roadside and woodland trees for Reval latitudes. Species drive
## silhouette family, bark, and canopy tint; size classes scale the same mesh
## so MultiMesh batches stay cheap. Terrain styles such as tree.mixed pick from
## weighted tables; authored props may pin one species and size.

const SPECIES_SPRUCE := &"spruce"
const SPECIES_PINE := &"pine"
const SPECIES_BIRCH := &"birch"
const SPECIES_OAK := &"oak"
const SPECIES_ALDER := &"alder"
const SPECIES_ASPEN := &"aspen"
const SPECIES_MAPLE := &"maple"
const SPECIES_LINDEN := &"linden"

const ALL_SPECIES: Array[StringName] = [
	SPECIES_SPRUCE,
	SPECIES_PINE,
	SPECIES_BIRCH,
	SPECIES_OAK,
	SPECIES_ALDER,
	SPECIES_ASPEN,
	SPECIES_MAPLE,
	SPECIES_LINDEN,
]

const SIZE_SMALL := &"small"
const SIZE_MEDIUM := &"medium"
const SIZE_LARGE := &"large"

const ALL_SIZES: Array[StringName] = [SIZE_SMALL, SIZE_MEDIUM, SIZE_LARGE]

const SILHOUETTE_SPRUCE := &"spruce"
const SILHOUETTE_PINE := &"pine"
const SILHOUETTE_BROAD := &"broad"
const SILHOUETTE_COLUMN := &"column"

const BARK_DEFAULT := &"bark"
const BARK_BIRCH := &"birch"

## Local Estonian mix for mixed woodland and exterior treelines: spruce and pine
## dominate the north Baltic canopy, with birch and aspen common on margins.
const MIXED_WEIGHTS: Dictionary = {
	SPECIES_SPRUCE: 0.28,
	SPECIES_PINE: 0.22,
	SPECIES_BIRCH: 0.16,
	SPECIES_ASPEN: 0.10,
	SPECIES_ALDER: 0.08,
	SPECIES_OAK: 0.07,
	SPECIES_MAPLE: 0.05,
	SPECIES_LINDEN: 0.04,
}

const DECIDUOUS_WEIGHTS: Dictionary = {
	SPECIES_BIRCH: 0.28,
	SPECIES_OAK: 0.18,
	SPECIES_ASPEN: 0.16,
	SPECIES_ALDER: 0.14,
	SPECIES_MAPLE: 0.12,
	SPECIES_LINDEN: 0.12,
}

## Size distribution for procedural scatter: medium trees carry the silhouette;
## saplings and veterans stay rare so stands read natural rather than uniform.
const SIZE_WEIGHTS: Dictionary = {
	SIZE_SMALL: 0.28,
	SIZE_MEDIUM: 0.52,
	SIZE_LARGE: 0.20,
}

const SIZE_SCALE: Dictionary = {
	SIZE_SMALL: Vector2(0.52, 0.72),
	SIZE_MEDIUM: Vector2(0.88, 1.12),
	SIZE_LARGE: Vector2(1.28, 1.62),
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
		&"mixed", &"deciduous":
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
		SPECIES_BIRCH, SPECIES_ASPEN:
			return SILHOUETTE_COLUMN
		_:
			return SILHOUETTE_BROAD


static func bark_kind_for(species: StringName) -> StringName:
	return BARK_BIRCH if species == SPECIES_BIRCH else BARK_DEFAULT


static func canopy_material_kind(species: StringName) -> StringName:
	match silhouette_for(species):
		SILHOUETTE_SPRUCE:
			return &"spruce"
		SILHOUETTE_PINE:
			return &"pine"
		SILHOUETTE_COLUMN:
			return &"column"
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
	return Color(shade, shade * 0.96, shade * 0.9)


static func weights_for_variant(variant: StringName) -> Dictionary:
	var parsed := parse_variant(variant)
	if parsed.has("species"):
		return {parsed["species"]: 1.0}
	match parsed.get("group", &""):
		&"deciduous":
			return DECIDUOUS_WEIGHTS
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


## Trunk cylinder height in mesh-local units before instance scale. Canopy lift
## keeps the crown seated on top of that trunk for each silhouette family.
static func trunk_height() -> float:
	return 1.2


static func canopy_lift(species: StringName) -> float:
	match silhouette_for(species):
		SILHOUETTE_SPRUCE:
			return 0.4
		SILHOUETTE_PINE:
			return 0.55
		SILHOUETTE_COLUMN:
			return 1.35
		_:
			return 1.55


static func trunk_lift() -> float:
	return trunk_height() * 0.5
