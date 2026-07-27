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
	GROUP_BEAR: {"body": Vector3(1.10, 0.62, 0.58), "head": 0.28, "neck": 0.10, "legs": 0.42, "tail": 0.08, "ears": 0.10},
	GROUP_CANID: {"body": Vector3(0.72, 0.34, 0.30), "head": 0.18, "neck": 0.14, "legs": 0.36, "tail": 0.34, "ears": 0.12},
	GROUP_FELID: {"body": Vector3(0.62, 0.30, 0.28), "head": 0.16, "neck": 0.10, "legs": 0.34, "tail": 0.28, "ears": 0.10},
	GROUP_UNGULATE: {"body": Vector3(0.92, 0.46, 0.38), "head": 0.14, "neck": 0.22, "legs": 0.52, "tail": 0.12, "ears": 0.08, "horns": 0.0},
	GROUP_MUSTELID: {"body": Vector3(0.52, 0.18, 0.16), "head": 0.11, "neck": 0.08, "legs": 0.16, "tail": 0.24, "ears": 0.06},
	GROUP_RODENT: {"body": Vector3(0.34, 0.16, 0.14), "head": 0.10, "neck": 0.04, "legs": 0.12, "tail": 0.22, "ears": 0.07},
	GROUP_LAGOMORPH: {"body": Vector3(0.42, 0.20, 0.18), "head": 0.11, "neck": 0.02, "legs": 0.24, "tail": 0.06, "ears": 0.18},
	GROUP_INSECTIVORE: {"body": Vector3(0.22, 0.14, 0.18), "head": 0.08, "neck": 0.0, "legs": 0.06, "tail": 0.0, "ears": 0.0},
	GROUP_SEAL: {"body": Vector3(1.05, 0.34, 0.30), "head": 0.14, "neck": 0.06, "legs": 0.08, "tail": 0.18, "ears": 0.0},
	GROUP_BAT: {"body": Vector3(0.10, 0.06, 0.08), "head": 0.05, "neck": 0.0, "legs": 0.04, "tail": 0.0, "ears": 0.10, "wing_span": 0.34},
	GROUP_FOWL: {"body": Vector3(0.28, 0.22, 0.24), "head": 0.08, "neck": 0.10, "legs": 0.14, "tail": 0.10, "ears": 0.0},
	GROUP_SWINE: {"body": Vector3(0.78, 0.38, 0.34), "head": 0.16, "neck": 0.08, "legs": 0.22, "tail": 0.08, "ears": 0.08},
}

const GROUP_SPAWN_WEIGHTS: Dictionary = {
	GROUP_BEAR: {CONTEXT_HARBOR: 0.0, CONTEXT_LOWER_TOWN: 0.0, CONTEXT_MARKET: 0.0, CONTEXT_MONASTERY: 0.0, CONTEXT_TOOMPEA: 0.0, CONTEXT_FORELAND: 0.42, CONTEXT_WETLAND: 0.28, CONTEXT_WOODLAND: 0.72, CONTEXT_GARDEN: 0.0},
	GROUP_CANID: {CONTEXT_HARBOR: 0.12, CONTEXT_LOWER_TOWN: 0.28, CONTEXT_MARKET: 0.18, CONTEXT_MONASTERY: 0.22, CONTEXT_TOOMPEA: 0.16, CONTEXT_FORELAND: 0.58, CONTEXT_WETLAND: 0.34, CONTEXT_WOODLAND: 0.62, CONTEXT_GARDEN: 0.20},
	GROUP_FELID: {CONTEXT_HARBOR: 0.04, CONTEXT_LOWER_TOWN: 0.36, CONTEXT_MARKET: 0.22, CONTEXT_MONASTERY: 0.18, CONTEXT_TOOMPEA: 0.14, CONTEXT_FORELAND: 0.48, CONTEXT_WETLAND: 0.22, CONTEXT_WOODLAND: 0.54, CONTEXT_GARDEN: 0.26},
	GROUP_UNGULATE: {CONTEXT_HARBOR: 0.02, CONTEXT_LOWER_TOWN: 0.18, CONTEXT_MARKET: 0.12, CONTEXT_MONASTERY: 0.16, CONTEXT_TOOMPEA: 0.22, CONTEXT_FORELAND: 0.82, CONTEXT_WETLAND: 0.24, CONTEXT_WOODLAND: 0.68, CONTEXT_GARDEN: 0.34},
	GROUP_MUSTELID: {CONTEXT_HARBOR: 0.18, CONTEXT_LOWER_TOWN: 0.14, CONTEXT_MARKET: 0.08, CONTEXT_MONASTERY: 0.20, CONTEXT_TOOMPEA: 0.10, CONTEXT_FORELAND: 0.52, CONTEXT_WETLAND: 0.62, CONTEXT_WOODLAND: 0.58, CONTEXT_GARDEN: 0.24},
	GROUP_RODENT: {CONTEXT_HARBOR: 0.42, CONTEXT_LOWER_TOWN: 0.72, CONTEXT_MARKET: 0.68, CONTEXT_MONASTERY: 0.38, CONTEXT_TOOMPEA: 0.26, CONTEXT_FORELAND: 0.34, CONTEXT_WETLAND: 0.48, CONTEXT_WOODLAND: 0.44, CONTEXT_GARDEN: 0.36},
	GROUP_LAGOMORPH: {CONTEXT_HARBOR: 0.0, CONTEXT_LOWER_TOWN: 0.08, CONTEXT_MARKET: 0.04, CONTEXT_MONASTERY: 0.10, CONTEXT_TOOMPEA: 0.06, CONTEXT_FORELAND: 0.86, CONTEXT_WETLAND: 0.42, CONTEXT_WOODLAND: 0.52, CONTEXT_GARDEN: 0.28},
	GROUP_INSECTIVORE: {CONTEXT_HARBOR: 0.0, CONTEXT_LOWER_TOWN: 0.22, CONTEXT_MARKET: 0.10, CONTEXT_MONASTERY: 0.28, CONTEXT_TOOMPEA: 0.12, CONTEXT_FORELAND: 0.38, CONTEXT_WETLAND: 0.18, CONTEXT_WOODLAND: 0.46, CONTEXT_GARDEN: 0.52},
	GROUP_SEAL: {CONTEXT_HARBOR: 0.82, CONTEXT_LOWER_TOWN: 0.0, CONTEXT_MARKET: 0.0, CONTEXT_MONASTERY: 0.0, CONTEXT_TOOMPEA: 0.0, CONTEXT_FORELAND: 0.24, CONTEXT_WETLAND: 0.36, CONTEXT_WOODLAND: 0.0, CONTEXT_GARDEN: 0.0},
	GROUP_BAT: {CONTEXT_HARBOR: 0.08, CONTEXT_LOWER_TOWN: 0.18, CONTEXT_MARKET: 0.12, CONTEXT_MONASTERY: 0.42, CONTEXT_TOOMPEA: 0.36, CONTEXT_FORELAND: 0.22, CONTEXT_WETLAND: 0.16, CONTEXT_WOODLAND: 0.48, CONTEXT_GARDEN: 0.20},
	GROUP_FOWL: {CONTEXT_HARBOR: 0.18, CONTEXT_LOWER_TOWN: 0.42, CONTEXT_MARKET: 0.52, CONTEXT_MONASTERY: 0.48, CONTEXT_TOOMPEA: 0.28, CONTEXT_FORELAND: 0.62, CONTEXT_WETLAND: 0.22, CONTEXT_WOODLAND: 0.12, CONTEXT_GARDEN: 0.58},
	GROUP_SWINE: {CONTEXT_HARBOR: 0.06, CONTEXT_LOWER_TOWN: 0.24, CONTEXT_MARKET: 0.18, CONTEXT_MONASTERY: 0.22, CONTEXT_TOOMPEA: 0.10, CONTEXT_FORELAND: 0.46, CONTEXT_WETLAND: 0.14, CONTEXT_WOODLAND: 0.20, CONTEXT_GARDEN: 0.16},
}

const PROFILES: Dictionary = {
	SPECIES_BROWN_BEAR: {"name": "Brown bear", "group": GROUP_BEAR, "scale_m": 1.35, "pose": POSE_STANDING, "colors": [Color("6a4a32"), Color("4a3424"), Color("2a2018")], "abundance": 0.12},
	SPECIES_WOLF: {"name": "Wolf", "group": GROUP_CANID, "scale_m": 0.95, "pose": POSE_STANDING, "colors": [Color("7a7468"), Color("4f4a42"), Color("2a2824")], "abundance": 0.18, "spawn": {CONTEXT_WOODLAND: 0.82, CONTEXT_FORELAND: 0.68}},
	SPECIES_RED_FOX: {"name": "Red fox", "group": GROUP_CANID, "scale_m": 0.62, "pose": POSE_STANDING, "colors": [Color("b56a3a"), Color("e8ddd0"), Color("2a2824")], "geometry": {"tail": 0.42}, "abundance": 0.46, "spawn": {CONTEXT_FORELAND: 0.78, CONTEXT_WOODLAND: 0.62}},
	SPECIES_LYNX: {"name": "Eurasian lynx", "group": GROUP_FELID, "scale_m": 0.82, "pose": POSE_STANDING, "colors": [Color("b39a72"), Color("6f5a42"), Color("2a2824")], "geometry": {"ears": 0.16, "tail": 0.12}, "abundance": 0.14, "spawn": {CONTEXT_WOODLAND: 0.76}},
	SPECIES_ELK: {"name": "Elk", "group": GROUP_UNGULATE, "scale_m": 1.55, "pose": POSE_GRAZING, "colors": [Color("6a5844"), Color("4a3c30"), Color("2a241c")], "geometry": {"body": Vector3(1.18, 0.58, 0.42), "horns": 0.42}, "abundance": 0.16, "spawn": {CONTEXT_WOODLAND: 0.72, CONTEXT_FORELAND: 0.58}},
	SPECIES_RED_DEER: {"name": "Red deer", "group": GROUP_UNGULATE, "scale_m": 1.18, "pose": POSE_GRAZING, "colors": [Color("8a6848"), Color("5a4632"), Color("2a241c")], "geometry": {"horns": 0.36}, "abundance": 0.22, "spawn": {CONTEXT_WOODLAND: 0.68}},
	SPECIES_ROE_DEER: {"name": "Roe deer", "group": GROUP_UNGULATE, "scale_m": 0.78, "pose": POSE_GRAZING, "colors": [Color("9a7a52"), Color("6a5438"), Color("2a241c")], "geometry": {"body": Vector3(0.72, 0.36, 0.30), "horns": 0.14}, "abundance": 0.34, "spawn": {CONTEXT_FORELAND: 0.74, CONTEXT_GARDEN: 0.28}},
	SPECIES_WILD_BOAR: {"name": "Wild boar", "group": GROUP_UNGULATE, "scale_m": 0.92, "pose": POSE_GRAZING, "colors": [Color("4a3428"), Color("2a2018"), Color("1a1814")], "geometry": {"head": 0.18, "tail": 0.08}, "abundance": 0.28, "spawn": {CONTEXT_WOODLAND: 0.62, CONTEXT_FORELAND: 0.48}},
	SPECIES_BEAVER: {"name": "Beaver", "group": GROUP_RODENT, "scale_m": 0.58, "pose": POSE_STANDING, "colors": [Color("5a4638"), Color("3a2e24"), Color("2a241c")], "geometry": {"tail": 0.28, "body": Vector3(0.42, 0.20, 0.18)}, "abundance": 0.24, "spawn": {CONTEXT_WETLAND: 0.82}},
	SPECIES_OTTER: {"name": "Eurasian otter", "group": GROUP_MUSTELID, "scale_m": 0.62, "pose": POSE_STANDING, "colors": [Color("5a4a3a"), Color("e8ddd0"), Color("2a2824")], "geometry": {"body": Vector3(0.58, 0.16, 0.14), "tail": 0.32}, "abundance": 0.26, "spawn": {CONTEXT_HARBOR: 0.48, CONTEXT_WETLAND: 0.76}},
	SPECIES_BADGER: {"name": "European badger", "group": GROUP_MUSTELID, "scale_m": 0.68, "pose": POSE_STANDING, "colors": [Color("7a6a52"), Color("2a2824"), Color("e8ddd0")], "geometry": {"body": Vector3(0.56, 0.22, 0.18)}, "abundance": 0.30},
	SPECIES_STOAT: {"name": "Stoat", "group": GROUP_MUSTELID, "scale_m": 0.28, "pose": POSE_STANDING, "colors": [Color("8a7a62"), Color("e8e4dc"), Color("2a2824")], "geometry": {"body": Vector3(0.38, 0.12, 0.10), "tail": 0.16}, "abundance": 0.32},
	SPECIES_PINE_MARTEN: {"name": "Pine marten", "group": GROUP_MUSTELID, "scale_m": 0.48, "pose": POSE_STANDING, "colors": [Color("6a4a2a"), Color("d8c8a8"), Color("2a2824")], "geometry": {"tail": 0.30}, "abundance": 0.28, "spawn": {CONTEXT_WOODLAND: 0.72}},
	SPECIES_POLECAT: {"name": "European polecat", "group": GROUP_MUSTELID, "scale_m": 0.42, "pose": POSE_STANDING, "colors": [Color("4a3a2a"), Color("d8c8a8"), Color("2a2824")], "abundance": 0.22},
	SPECIES_HARE: {"name": "European hare", "group": GROUP_LAGOMORPH, "scale_m": 0.52, "pose": POSE_STANDING, "colors": [Color("9a8468"), Color("d8c8a8"), Color("6a5a48")], "abundance": 0.52, "spawn": {CONTEXT_FORELAND: 0.88}},
	SPECIES_SQUIRREL: {"name": "Red squirrel", "group": GROUP_RODENT, "scale_m": 0.22, "pose": POSE_STANDING, "colors": [Color("9a4a28"), Color("d8c8a8"), Color("4a3424")], "geometry": {"tail": 0.28, "ears": 0.10}, "abundance": 0.58, "spawn": {CONTEXT_GARDEN: 0.72, CONTEXT_WOODLAND: 0.68}},
	SPECIES_HEDGEHOG: {"name": "European hedgehog", "group": GROUP_INSECTIVORE, "scale_m": 0.20, "pose": POSE_STANDING, "colors": [Color("6a5a48"), Color("4a4038"), Color("2a241c")], "abundance": 0.42},
	SPECIES_GREY_SEAL: {"name": "Grey seal", "group": GROUP_SEAL, "scale_m": 1.42, "pose": POSE_RESTING, "colors": [Color("8a8a82"), Color("6a6a62"), Color("4a4a44")], "abundance": 0.18, "spawn": {CONTEXT_HARBOR: 0.86}},
	SPECIES_RINGED_SEAL: {"name": "Ringed seal", "group": GROUP_SEAL, "scale_m": 1.05, "pose": POSE_RESTING, "colors": [Color("9a9488"), Color("6a6458"), Color("4a443c")], "geometry": {"body": Vector3(0.82, 0.28, 0.24)}, "abundance": 0.12, "spawn": {CONTEXT_HARBOR: 0.62, CONTEXT_WETLAND: 0.42}},
	SPECIES_COMMON_BAT: {"name": "Common bat", "group": GROUP_BAT, "scale_m": 0.10, "pose": POSE_STANDING, "colors": [Color("4a4038"), Color("2a2824"), Color("6a5a48")], "abundance": 0.36},
	# Cat and rat are the close-range Lower Town actors, so their proportions are
	# measured from the real animal rather than inherited from the felid/rodent
	# reference blocks: small head, low-slung body, long tail.
	SPECIES_CAT: {"name": "Domestic cat", "group": GROUP_FELID, "scale_m": 0.42, "pose": POSE_RESTING, "colors": [Color("8a7a62"), Color("4a4038"), Color("e8ddd0")], "geometry": {"body": Vector3(0.48, 0.20, 0.17), "head": 0.09, "neck": 0.05, "legs": 0.20, "ears": 0.07, "tail": 0.32}, "abundance": 0.72, "spawn": {CONTEXT_LOWER_TOWN: 0.92, CONTEXT_MARKET: 0.68}},
	SPECIES_DOG: {"name": "Domestic dog", "group": GROUP_CANID, "scale_m": 0.52, "pose": POSE_STANDING, "colors": [Color("8a6a42"), Color("4a4038"), Color("2a2824")], "geometry": {"body": Vector3(0.62, 0.28, 0.24), "tail": 0.24}, "abundance": 0.68, "spawn": {CONTEXT_LOWER_TOWN: 0.88, CONTEXT_MARKET: 0.62}},
	SPECIES_HORSE: {"name": "Horse", "group": GROUP_UNGULATE, "scale_m": 1.42, "pose": POSE_STANDING, "colors": [Color("7a5a38"), Color("4a3424"), Color("2a241c")], "geometry": {"body": Vector3(1.02, 0.50, 0.34), "neck": 0.34, "legs": 0.58, "tail": 0.42}, "abundance": 0.54, "spawn": {CONTEXT_LOWER_TOWN: 0.48, CONTEXT_MARKET: 0.42, CONTEXT_FORELAND: 0.38}},
	SPECIES_RAT: {"name": "Brown rat", "group": GROUP_RODENT, "scale_m": 0.24, "pose": POSE_STANDING, "colors": [Color("6a5a48"), Color("4a4038"), Color("2a2824")], "geometry": {"body": Vector3(0.28, 0.11, 0.10), "head": 0.055, "neck": 0.02, "legs": 0.05, "ears": 0.05, "tail": 0.30}, "abundance": 0.82, "spawn": {CONTEXT_LOWER_TOWN: 0.86, CONTEXT_HARBOR: 0.72}},
	SPECIES_CHICKEN: {"name": "Chicken", "group": GROUP_FOWL, "scale_m": 0.34, "pose": POSE_STANDING, "colors": [Color("c8a86a"), Color("8a4a28"), Color("d8c8a8")], "abundance": 0.76, "spawn": {CONTEXT_LOWER_TOWN: 0.62, CONTEXT_FORELAND: 0.58}},
	SPECIES_DUCK: {"name": "Domestic duck", "group": GROUP_FOWL, "scale_m": 0.38, "pose": POSE_STANDING, "colors": [Color("6a5a42"), Color("4a6a52"), Color("d8a848")], "abundance": 0.58, "spawn": {CONTEXT_FORELAND: 0.52, CONTEXT_WETLAND: 0.34}},
	SPECIES_GOOSE: {"name": "Domestic goose", "group": GROUP_FOWL, "scale_m": 0.62, "pose": POSE_STANDING, "colors": [Color("e8e4dc"), Color("6a6a62"), Color("d8a848")], "geometry": {"neck": 0.18}, "abundance": 0.46, "spawn": {CONTEXT_FORELAND: 0.62}},
	SPECIES_PIG: {"name": "Domestic pig", "group": GROUP_SWINE, "scale_m": 0.82, "pose": POSE_STANDING, "colors": [Color("d8a8a0"), Color("c88880"), Color("4a3424")], "abundance": 0.48, "spawn": {CONTEXT_FORELAND: 0.52, CONTEXT_LOWER_TOWN: 0.22}},
	SPECIES_COW: {"name": "Cattle", "group": GROUP_UNGULATE, "scale_m": 1.48, "pose": POSE_GRAZING, "colors": [Color("8a6a48"), Color("e8e4dc"), Color("4a3424")], "geometry": {"body": Vector3(1.08, 0.52, 0.40), "horns": 0.10}, "abundance": 0.32, "spawn": {CONTEXT_FORELAND: 0.68}},
	SPECIES_SHEEP: {"name": "Sheep", "group": GROUP_UNGULATE, "scale_m": 0.92, "pose": POSE_GRAZING, "colors": [Color("e8e4dc"), Color("b8b0a4"), Color("4a3424")], "geometry": {"body": Vector3(0.78, 0.40, 0.32)}, "abundance": 0.38, "spawn": {CONTEXT_FORELAND: 0.72}},
}


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
	return (PROFILES[species] as Dictionary).duplicate(true)


static func common_name(species: StringName) -> String:
	return String(PROFILES.get(species, {}).get("name", String(species)))


static func group_for(species: StringName) -> StringName:
	return StringName(PROFILES.get(species, {}).get("group", &""))


static func default_pose(species: StringName) -> StringName:
	return StringName(PROFILES.get(species, {}).get("pose", POSE_STANDING))


static func scale_m(species: StringName) -> float:
	return float(PROFILES.get(species, {}).get("scale_m", 0.2))


static func geometry_for(species: StringName) -> Dictionary:
	var group := group_for(species)
	if not GROUP_GEOMETRY.has(group):
		return {}
	var geometry := (GROUP_GEOMETRY[group] as Dictionary).duplicate()
	var overrides: Dictionary = PROFILES[species].get("geometry", {})
	geometry.merge(overrides, true)
	geometry["scale_m"] = scale_m(species)
	return geometry


static func colors_for(species: StringName) -> Array[Color]:
	var source: Array = PROFILES.get(species, {}).get("colors", [Color.GRAY, Color.DARK_GRAY, Color.BEIGE])
	var colors: Array[Color] = []
	for color: Variant in source:
		colors.append(color as Color)
	return colors


static func spawn_weights_for(species: StringName) -> Dictionary:
	var group := group_for(species)
	if not GROUP_SPAWN_WEIGHTS.has(group):
		return {}
	var abundance := float(PROFILES[species].get("abundance", 1.0))
	var weights: Dictionary = {}
	for context in ALL_CONTEXTS:
		weights[context] = clampf(float(GROUP_SPAWN_WEIGHTS[group].get(context, 0.0)) * abundance, 0.0, 1.0)
	var overrides: Dictionary = PROFILES[species].get("spawn", {})
	for context: Variant in overrides:
		if context in ALL_CONTEXTS:
			weights[context] = clampf(float(overrides[context]), 0.0, 1.0)
	return weights


static func spawn_weight(species: StringName, context: StringName) -> float:
	return float(spawn_weights_for(species).get(context, 0.0))
