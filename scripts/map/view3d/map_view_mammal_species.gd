class_name MapViewMammalSpecies
extends RefCounted

## Data-only catalog for north-Baltic ambient mammals. P0-118 owns stable IDs,
## visual profile stubs, and district suitability. Runtime spawning and behavior
## are owned by P2-024 (urban) and P0-106 (penned livestock and wild-margin actors);
## no gameplay interaction in this task.

const GROUP_BEAR := &"bear"
const GROUP_CANID := &"canid"
const GROUP_FELID := &"felid"
const GROUP_UNGULATE := &"ungulate"
const GROUP_MUSTELID := &"mustelid"
const GROUP_RODENT := &"rodent"
const GROUP_LAGOMORPH := &"lagomorph"
const GROUP_INSECTIVORE := &"insectivore"
const GROUP_SEAL := &"seal"
const GROUP_BAT := &"bat"
const GROUP_FOWL := &"fowl"
const GROUP_SWINE := &"swine"
const ALL_GROUPS: Array[StringName] = [
	GROUP_BEAR,
	GROUP_CANID,
	GROUP_FELID,
	GROUP_UNGULATE,
	GROUP_MUSTELID,
	GROUP_RODENT,
	GROUP_LAGOMORPH,
	GROUP_INSECTIVORE,
	GROUP_SEAL,
	GROUP_BAT,
	GROUP_FOWL,
	GROUP_SWINE,
]
const POSE_STANDING := &"standing"
const POSE_GRAZING := &"grazing"
const POSE_RESTING := &"resting"
const ALL_POSES: Array[StringName] = [POSE_STANDING, POSE_GRAZING, POSE_RESTING]
const CONTEXT_HARBOR := &"harbor"
const CONTEXT_LOWER_TOWN := &"lower_town"
const CONTEXT_MARKET := &"market_civic"
const CONTEXT_MONASTERY := &"monastery"
const CONTEXT_TOOMPEA := &"toompea"
const CONTEXT_FORELAND := &"foreland"
const CONTEXT_WETLAND := &"wetland"
const CONTEXT_WOODLAND := &"woodland"
const CONTEXT_GARDEN := &"garden"
const ALL_CONTEXTS: Array[StringName] = [
	CONTEXT_HARBOR,
	CONTEXT_LOWER_TOWN,
	CONTEXT_MARKET,
	CONTEXT_MONASTERY,
	CONTEXT_TOOMPEA,
	CONTEXT_FORELAND,
	CONTEXT_WETLAND,
	CONTEXT_WOODLAND,
	CONTEXT_GARDEN,
]
const SPECIES_BROWN_BEAR := &"brown_bear"
const SPECIES_WOLF := &"wolf"
const SPECIES_RED_FOX := &"red_fox"
const SPECIES_LYNX := &"lynx"
const SPECIES_ELK := &"elk"
const SPECIES_RED_DEER := &"red_deer"
const SPECIES_ROE_DEER := &"roe_deer"
const SPECIES_WILD_BOAR := &"wild_boar"
const SPECIES_BEAVER := &"beaver"
const SPECIES_OTTER := &"otter"
const SPECIES_BADGER := &"badger"
const SPECIES_STOAT := &"stoat"
const SPECIES_PINE_MARTEN := &"pine_marten"
const SPECIES_POLECAT := &"polecat"
const SPECIES_HARE := &"hare"
const SPECIES_SQUIRREL := &"squirrel"
const SPECIES_HEDGEHOG := &"hedgehog"
const SPECIES_GREY_SEAL := &"grey_seal"
const SPECIES_RINGED_SEAL := &"ringed_seal"
const SPECIES_COMMON_BAT := &"common_bat"
const SPECIES_CAT := &"cat"
const SPECIES_DOG := &"dog"
const SPECIES_HORSE := &"horse"
const SPECIES_RAT := &"rat"
const SPECIES_CHICKEN := &"chicken"
const SPECIES_DUCK := &"duck"
const SPECIES_GOOSE := &"goose"
const SPECIES_PIG := &"pig"
const SPECIES_COW := &"cow"
const SPECIES_SHEEP := &"sheep"
const ALL_SPECIES: Array[StringName] = [
	SPECIES_BROWN_BEAR,
	SPECIES_WOLF,
	SPECIES_RED_FOX,
	SPECIES_LYNX,
	SPECIES_ELK,
	SPECIES_RED_DEER,
	SPECIES_ROE_DEER,
	SPECIES_WILD_BOAR,
	SPECIES_BEAVER,
	SPECIES_OTTER,
	SPECIES_BADGER,
	SPECIES_STOAT,
	SPECIES_PINE_MARTEN,
	SPECIES_POLECAT,
	SPECIES_HARE,
	SPECIES_SQUIRREL,
	SPECIES_HEDGEHOG,
	SPECIES_GREY_SEAL,
	SPECIES_RINGED_SEAL,
	SPECIES_COMMON_BAT,
	SPECIES_CAT,
	SPECIES_DOG,
	SPECIES_HORSE,
	SPECIES_RAT,
	SPECIES_CHICKEN,
	SPECIES_DUCK,
	SPECIES_GOOSE,
	SPECIES_PIG,
	SPECIES_COW,
	SPECIES_SHEEP,
]
const GROUP_GEOMETRY: Dictionary = {
	GROUP_BEAR:
	{
		"body": Vector3(1.10, 0.62, 0.58),
		"head": 0.28,
		"neck": 0.10,
		"legs": 0.42,
		"tail": 0.08,
		"ears": 0.10
	},
	GROUP_CANID:
	{
		"body": Vector3(0.72, 0.34, 0.30),
		"head": 0.18,
		"neck": 0.14,
		"legs": 0.36,
		"tail": 0.34,
		"ears": 0.12
	},
	GROUP_FELID:
	{
		"body": Vector3(0.62, 0.30, 0.28),
		"head": 0.16,
		"neck": 0.10,
		"legs": 0.34,
		"tail": 0.28,
		"ears": 0.10
	},
	GROUP_UNGULATE:
	{
		"body": Vector3(0.92, 0.46, 0.38),
		"head": 0.14,
		"neck": 0.22,
		"legs": 0.52,
		"tail": 0.12,
		"ears": 0.08,
		"horns": 0.0
	},
	GROUP_MUSTELID:
	{
		"body": Vector3(0.52, 0.18, 0.16),
		"head": 0.11,
		"neck": 0.08,
		"legs": 0.16,
		"tail": 0.24,
		"ears": 0.06
	},
	GROUP_RODENT:
	{
		"body": Vector3(0.34, 0.16, 0.14),
		"head": 0.10,
		"neck": 0.04,
		"legs": 0.12,
		"tail": 0.22,
		"ears": 0.07
	},
	GROUP_LAGOMORPH:
	{
		"body": Vector3(0.42, 0.20, 0.18),
		"head": 0.11,
		"neck": 0.02,
		"legs": 0.24,
		"tail": 0.06,
		"ears": 0.18
	},
	GROUP_INSECTIVORE:
	{
		"body": Vector3(0.22, 0.14, 0.18),
		"head": 0.08,
		"neck": 0.0,
		"legs": 0.06,
		"tail": 0.0,
		"ears": 0.0
	},
	GROUP_SEAL:
	{
		"body": Vector3(1.05, 0.34, 0.30),
		"head": 0.14,
		"neck": 0.06,
		"legs": 0.08,
		"tail": 0.18,
		"ears": 0.0
	},
	GROUP_BAT:
	{
		"body": Vector3(0.10, 0.06, 0.08),
		"head": 0.05,
		"neck": 0.0,
		"legs": 0.04,
		"tail": 0.0,
		"ears": 0.10,
		"wing_span": 0.34
	},
	GROUP_FOWL:
	{
		"body": Vector3(0.28, 0.22, 0.24),
		"head": 0.08,
		"neck": 0.10,
		"legs": 0.14,
		"tail": 0.10,
		"ears": 0.0
	},
	GROUP_SWINE:
	{
		"body": Vector3(0.78, 0.38, 0.34),
		"head": 0.16,
		"neck": 0.08,
		"legs": 0.22,
		"tail": 0.08,
		"ears": 0.08
	},
}
const GROUP_SPAWN_WEIGHTS: Dictionary = {
	GROUP_BEAR:
	{
		CONTEXT_HARBOR: 0.0,
		CONTEXT_LOWER_TOWN: 0.0,
		CONTEXT_MARKET: 0.0,
		CONTEXT_MONASTERY: 0.0,
		CONTEXT_TOOMPEA: 0.0,
		CONTEXT_FORELAND: 0.42,
		CONTEXT_WETLAND: 0.28,
		CONTEXT_WOODLAND: 0.72,
		CONTEXT_GARDEN: 0.0
	},
	GROUP_CANID:
	{
		CONTEXT_HARBOR: 0.12,
		CONTEXT_LOWER_TOWN: 0.28,
		CONTEXT_MARKET: 0.18,
		CONTEXT_MONASTERY: 0.22,
		CONTEXT_TOOMPEA: 0.16,
		CONTEXT_FORELAND: 0.58,
		CONTEXT_WETLAND: 0.34,
		CONTEXT_WOODLAND: 0.62,
		CONTEXT_GARDEN: 0.20
	},
	GROUP_FELID:
	{
		CONTEXT_HARBOR: 0.04,
		CONTEXT_LOWER_TOWN: 0.36,
		CONTEXT_MARKET: 0.22,
		CONTEXT_MONASTERY: 0.18,
		CONTEXT_TOOMPEA: 0.14,
		CONTEXT_FORELAND: 0.48,
		CONTEXT_WETLAND: 0.22,
		CONTEXT_WOODLAND: 0.54,
		CONTEXT_GARDEN: 0.26
	},
	GROUP_UNGULATE:
	{
		CONTEXT_HARBOR: 0.02,
		CONTEXT_LOWER_TOWN: 0.18,
		CONTEXT_MARKET: 0.12,
		CONTEXT_MONASTERY: 0.16,
		CONTEXT_TOOMPEA: 0.22,
		CONTEXT_FORELAND: 0.82,
		CONTEXT_WETLAND: 0.24,
		CONTEXT_WOODLAND: 0.68,
		CONTEXT_GARDEN: 0.34
	},
	GROUP_MUSTELID:
	{
		CONTEXT_HARBOR: 0.18,
		CONTEXT_LOWER_TOWN: 0.14,
		CONTEXT_MARKET: 0.08,
		CONTEXT_MONASTERY: 0.20,
		CONTEXT_TOOMPEA: 0.10,
		CONTEXT_FORELAND: 0.52,
		CONTEXT_WETLAND: 0.62,
		CONTEXT_WOODLAND: 0.58,
		CONTEXT_GARDEN: 0.24
	},
	GROUP_RODENT:
	{
		CONTEXT_HARBOR: 0.42,
		CONTEXT_LOWER_TOWN: 0.72,
		CONTEXT_MARKET: 0.68,
		CONTEXT_MONASTERY: 0.38,
		CONTEXT_TOOMPEA: 0.26,
		CONTEXT_FORELAND: 0.34,
		CONTEXT_WETLAND: 0.48,
		CONTEXT_WOODLAND: 0.44,
		CONTEXT_GARDEN: 0.36
	},
	GROUP_LAGOMORPH:
	{
		CONTEXT_HARBOR: 0.0,
		CONTEXT_LOWER_TOWN: 0.08,
		CONTEXT_MARKET: 0.04,
		CONTEXT_MONASTERY: 0.10,
		CONTEXT_TOOMPEA: 0.06,
		CONTEXT_FORELAND: 0.86,
		CONTEXT_WETLAND: 0.42,
		CONTEXT_WOODLAND: 0.52,
		CONTEXT_GARDEN: 0.28
	},
	GROUP_INSECTIVORE:
	{
		CONTEXT_HARBOR: 0.0,
		CONTEXT_LOWER_TOWN: 0.22,
		CONTEXT_MARKET: 0.10,
		CONTEXT_MONASTERY: 0.28,
		CONTEXT_TOOMPEA: 0.12,
		CONTEXT_FORELAND: 0.38,
		CONTEXT_WETLAND: 0.18,
		CONTEXT_WOODLAND: 0.46,
		CONTEXT_GARDEN: 0.52
	},
	GROUP_SEAL:
	{
		CONTEXT_HARBOR: 0.82,
		CONTEXT_LOWER_TOWN: 0.0,
		CONTEXT_MARKET: 0.0,
		CONTEXT_MONASTERY: 0.0,
		CONTEXT_TOOMPEA: 0.0,
		CONTEXT_FORELAND: 0.24,
		CONTEXT_WETLAND: 0.36,
		CONTEXT_WOODLAND: 0.0,
		CONTEXT_GARDEN: 0.0
	},
	GROUP_BAT:
	{
		CONTEXT_HARBOR: 0.08,
		CONTEXT_LOWER_TOWN: 0.18,
		CONTEXT_MARKET: 0.12,
		CONTEXT_MONASTERY: 0.42,
		CONTEXT_TOOMPEA: 0.36,
		CONTEXT_FORELAND: 0.22,
		CONTEXT_WETLAND: 0.16,
		CONTEXT_WOODLAND: 0.48,
		CONTEXT_GARDEN: 0.20
	},
	GROUP_FOWL:
	{
		CONTEXT_HARBOR: 0.18,
		CONTEXT_LOWER_TOWN: 0.42,
		CONTEXT_MARKET: 0.52,
		CONTEXT_MONASTERY: 0.48,
		CONTEXT_TOOMPEA: 0.28,
		CONTEXT_FORELAND: 0.62,
		CONTEXT_WETLAND: 0.22,
		CONTEXT_WOODLAND: 0.12,
		CONTEXT_GARDEN: 0.58
	},
	GROUP_SWINE:
	{
		CONTEXT_HARBOR: 0.06,
		CONTEXT_LOWER_TOWN: 0.24,
		CONTEXT_MARKET: 0.18,
		CONTEXT_MONASTERY: 0.22,
		CONTEXT_TOOMPEA: 0.10,
		CONTEXT_FORELAND: 0.46,
		CONTEXT_WETLAND: 0.14,
		CONTEXT_WOODLAND: 0.20,
		CONTEXT_GARDEN: 0.16
	},
}
const _PROFILE_CARNIVORE := preload("res://scripts/map/view3d/map_view_mammal_species_carnivore.gd")
const _PROFILE_WILD_UNGULATE := preload(
	"res://scripts/map/view3d/map_view_mammal_species_wild_ungulate.gd"
)
const _PROFILE_MUSTELID := preload("res://scripts/map/view3d/map_view_mammal_species_mustelid.gd")
const _PROFILE_SMALL_MAMMAL := preload(
	"res://scripts/map/view3d/map_view_mammal_species_small_mammal.gd"
)
const _PROFILE_COASTAL := preload("res://scripts/map/view3d/map_view_mammal_species_coastal.gd")
const _PROFILE_LIVESTOCK := preload("res://scripts/map/view3d/map_view_mammal_species_livestock.gd")
const _PROFILE_URBAN_COMPANION := preload(
	"res://scripts/map/view3d/map_view_mammal_species_urban_companion.gd"
)
const MaterialPatterns := preload("res://scripts/map/view3d/map_view_material_patterns.gd")

static var _profiles_cache: Dictionary = {}
static var _surface_material_cache: Dictionary = {}
static var _normal_texture_cache: Dictionary = {}


static func _profiles() -> Dictionary:
	if _profiles_cache.is_empty():
		_profiles_cache = (
			_PROFILE_CARNIVORE.PROFILES
			.merged(_PROFILE_WILD_UNGULATE.PROFILES)
			.merged(_PROFILE_MUSTELID.PROFILES)
			.merged(_PROFILE_SMALL_MAMMAL.PROFILES)
			.merged(_PROFILE_COASTAL.PROFILES)
			.merged(_PROFILE_URBAN_COMPANION.PROFILES)
			.merged(_PROFILE_LIVESTOCK.PROFILES)
		)
	return _profiles_cache


static func is_known_species(species: StringName) -> bool:
	return species in ALL_SPECIES


static func is_known_group(group: StringName) -> bool:
	return group in ALL_GROUPS


static func is_known_pose(pose: StringName) -> bool:
	return pose in ALL_POSES


static func id_for(species: StringName) -> StringName:
	if not is_known_species(species):
		return &""
	return StringName("fauna.%s" % species)


static func is_known_id(fauna_id: StringName) -> bool:
	return not parse_variant(fauna_id).is_empty()


static func parse_variant(variant: StringName) -> Dictionary:
	var parts := String(variant).split(".")
	if parts.size() < 2 or parts.size() > 3 or parts[0] != "fauna":
		return {}
	var species := StringName(parts[1])
	if not is_known_species(species):
		return {}
	var pose := default_pose(species)
	if parts.size() == 3:
		pose = StringName(parts[2])
		if not is_known_pose(pose):
			return {}
	return {"species": species, "pose": pose}


static func profile_for(species: StringName) -> Dictionary:
	if not is_known_species(species):
		return {}
	return (_profiles()[species] as Dictionary).duplicate(true)


static func common_name(species: StringName) -> String:
	return String(_profiles().get(species, {}).get("name", String(species)))


static func group_for(species: StringName) -> StringName:
	return StringName(_profiles().get(species, {}).get("group", &""))


static func default_pose(species: StringName) -> StringName:
	return StringName(_profiles().get(species, {}).get("pose", POSE_STANDING))


static func scale_m(species: StringName) -> float:
	return float(_profiles().get(species, {}).get("scale_m", 0.2))


static func geometry_for(species: StringName) -> Dictionary:
	var group := group_for(species)
	if not GROUP_GEOMETRY.has(group):
		return {}
	var geometry := (GROUP_GEOMETRY[group] as Dictionary).duplicate()
	var overrides: Dictionary = _profiles()[species].get("geometry", {})
	geometry.merge(overrides, true)
	geometry["scale_m"] = scale_m(species)
	return geometry


static func colors_for(species: StringName) -> Array[Color]:
	var source: Array = _profiles().get(species, {}).get(
		"colors", [Color.GRAY, Color.DARK_GRAY, Color.BEIGE]
	)
	var colors: Array[Color] = []
	for color: Variant in source:
		colors.append(color as Color)
	return colors


static func spawn_weights_for(species: StringName) -> Dictionary:
	var group := group_for(species)
	if not GROUP_SPAWN_WEIGHTS.has(group):
		return {}
	var abundance := float(_profiles()[species].get("abundance", 1.0))
	var weights: Dictionary = {}
	for context in ALL_CONTEXTS:
		weights[context] = clampf(
			float(GROUP_SPAWN_WEIGHTS[group].get(context, 0.0)) * abundance, 0.0, 1.0
		)
	var overrides: Dictionary = _profiles()[species].get("spawn", {})
	for context: Variant in overrides:
		if context in ALL_CONTEXTS:
			weights[context] = clampf(float(overrides[context]), 0.0, 1.0)
	return weights


static func spawn_weight(species: StringName, context: StringName) -> float:
	return float(spawn_weights_for(species).get(context, 0.0))

static func reset_surface_material_cache() -> void:
	_surface_material_cache.clear()
	_normal_texture_cache.clear()


## Lit surface material for procedural P0-118 meshes. Vertex colours remain the
## species tint; a soft fur normal map keeps distant silhouettes readable under
## the dynamic sun and P0-141 grade instead of reading as flat vertex blobs.
static func surface_material_for(species: StringName) -> StandardMaterial3D:
	if _surface_material_cache.has(species):
		return _surface_material_cache[species]
	var group := group_for(species)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.metallic = 0.0
	material.roughness = _fur_roughness_for_group(group)
	material.metallic_specular = 0.14
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.normal_enabled = true
	material.normal_texture = _fur_normal_for_group(group)
	material.normal_scale = 0.42
	_surface_material_cache[species] = material
	return material


static func _fur_roughness_for_group(group: StringName) -> float:
	match group:
		GROUP_SEAL:
			return 0.72
		GROUP_BAT:
			return 0.80
		GROUP_UNGULATE, GROUP_SWINE:
			return 0.90
		GROUP_FELID, GROUP_RODENT, GROUP_LAGOMORPH:
			return 0.88
		_:
			return 0.86


static func _fur_normal_for_group(group: StringName) -> Texture2D:
	if _normal_texture_cache.has(group):
		return _normal_texture_cache[group]
	var seed := int(group.hash()) ^ 0x6A09E667
	var image := (
		MaterialPatterns.pattern_texture(MapViewMaterials.PATTERN_SPECKLE, seed).get_image()
	)
	image.bump_map_to_normal_map(1.28)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_normal_texture_cache[group] = texture
	return texture
