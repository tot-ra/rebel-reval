class_name MapViewBushSpecies
extends RefCounted

## North-Baltic shrub catalog for hedgerow, heath, coastal, wetland, and bog
## margins. Generic bush.dense / bush.scrub remain weighted group aliases.

const GROUP_BERRY := &"berry"
const GROUP_HEATH := &"heath"
const GROUP_COASTAL := &"coastal"
const GROUP_HEDGE := &"hedge"
const GROUP_WETLAND := &"wetland"
const GROUP_BOG := &"bog"
const GROUP_UNDERSTORY := &"understory"

const ALL_GROUPS: Array[StringName] = [
	GROUP_BERRY,
	GROUP_HEATH,
	GROUP_COASTAL,
	GROUP_HEDGE,
	GROUP_WETLAND,
	GROUP_BOG,
	GROUP_UNDERSTORY,
]

const ARCHETYPE_ROUND := &"round"
const ARCHETYPE_SPREAD := &"spread"
const ARCHETYPE_UPRIGHT := &"upright"
const ARCHETYPE_COASTAL := &"coastal"
const ARCHETYPE_WETLAND := &"wetland"
const ARCHETYPE_BOG := &"bog"
const ARCHETYPE_CONIFER := &"conifer"

const SPECIES_BILBERRY := &"bilberry"
const SPECIES_COWBERRY := &"cowberry"
const SPECIES_CLOUDBERRY := &"cloudberry"
const SPECIES_CRANBERRY := &"cranberry"
const SPECIES_CROWBERRY := &"crowberry"
const SPECIES_WILD_STRAWBERRY := &"wild_strawberry"
const SPECIES_RASPBERRY := &"raspberry"
const SPECIES_DOG_ROSE := &"dog_rose"
const SPECIES_GUELDER_ROSE := &"guelder_rose"
const SPECIES_ELDER := &"elder"
const SPECIES_SEA_BUCKTHORN := &"sea_buckthorn"
const SPECIES_HEATHER := &"heather"
const SPECIES_BOG_ROSEMARY := &"bog_rosemary"
const SPECIES_JUNIPER_SHRUB := &"juniper_shrub"
const SPECIES_HAZEL_SHRUB := &"hazel_shrub"
const SPECIES_HAWTHORN := &"hawthorn"
const SPECIES_BLACKTHORN := &"blackthorn"
const SPECIES_WILLOW_SHRUB := &"willow_shrub"
const SPECIES_ALDER_SHRUB := &"alder_shrub"
const SPECIES_SPINDLE := &"spindle"

const ALL_SPECIES: Array[StringName] = [
	SPECIES_BILBERRY,
	SPECIES_COWBERRY,
	SPECIES_CLOUDBERRY,
	SPECIES_CRANBERRY,
	SPECIES_CROWBERRY,
	SPECIES_WILD_STRAWBERRY,
	SPECIES_RASPBERRY,
	SPECIES_DOG_ROSE,
	SPECIES_GUELDER_ROSE,
	SPECIES_ELDER,
	SPECIES_SEA_BUCKTHORN,
	SPECIES_HEATHER,
	SPECIES_BOG_ROSEMARY,
	SPECIES_JUNIPER_SHRUB,
	SPECIES_HAZEL_SHRUB,
	SPECIES_HAWTHORN,
	SPECIES_BLACKTHORN,
	SPECIES_WILLOW_SHRUB,
	SPECIES_ALDER_SHRUB,
	SPECIES_SPINDLE,
]

const ALL_VARIANTS: Array[StringName] = [
	&"bush.bilberry",
	&"bush.cowberry",
	&"bush.cloudberry",
	&"bush.cranberry",
	&"bush.crowberry",
	&"bush.wild_strawberry",
	&"bush.raspberry",
	&"bush.dog_rose",
	&"bush.guelder_rose",
	&"bush.elder",
	&"bush.sea_buckthorn",
	&"bush.heather",
	&"bush.bog_rosemary",
	&"bush.juniper_shrub",
	&"bush.hazel_shrub",
	&"bush.hawthorn",
	&"bush.blackthorn",
	&"bush.willow_shrub",
	&"bush.alder_shrub",
	&"bush.spindle",
]

## Legacy terrain aliases pick from these pools so existing rrmap rows keep working.
const DENSE_WEIGHTS: Dictionary = {
	SPECIES_HAWTHORN: 0.18,
	SPECIES_BLACKTHORN: 0.16,
	SPECIES_HAZEL_SHRUB: 0.14,
	SPECIES_ELDER: 0.12,
	SPECIES_SEA_BUCKTHORN: 0.12,
	SPECIES_JUNIPER_SHRUB: 0.10,
	SPECIES_GUELDER_ROSE: 0.08,
	SPECIES_SPINDLE: 0.10,
}

const SCRUB_WEIGHTS: Dictionary = {
	SPECIES_BILBERRY: 0.18,
	SPECIES_COWBERRY: 0.16,
	SPECIES_HEATHER: 0.14,
	SPECIES_CROWBERRY: 0.12,
	SPECIES_RASPBERRY: 0.12,
	SPECIES_DOG_ROSE: 0.10,
	SPECIES_WILD_STRAWBERRY: 0.08,
	SPECIES_ALDER_SHRUB: 0.10,
}

const HEDGE_WEIGHTS: Dictionary = {
	SPECIES_HAWTHORN: 0.28,
	SPECIES_BLACKTHORN: 0.24,
	SPECIES_HAZEL_SHRUB: 0.20,
	SPECIES_SPINDLE: 0.14,
	SPECIES_DOG_ROSE: 0.14,
}

const HEATH_WEIGHTS: Dictionary = {
	SPECIES_HEATHER: 0.30,
	SPECIES_CROWBERRY: 0.22,
	SPECIES_BILBERRY: 0.20,
	SPECIES_COWBERRY: 0.18,
	SPECIES_JUNIPER_SHRUB: 0.10,
}

const COASTAL_WEIGHTS: Dictionary = {
	SPECIES_SEA_BUCKTHORN: 0.34,
	SPECIES_CROWBERRY: 0.22,
	SPECIES_DOG_ROSE: 0.18,
	SPECIES_JUNIPER_SHRUB: 0.16,
	SPECIES_WILLOW_SHRUB: 0.10,
}

const BOG_WEIGHTS: Dictionary = {
	SPECIES_CLOUDBERRY: 0.28,
	SPECIES_CRANBERRY: 0.24,
	SPECIES_BOG_ROSEMARY: 0.22,
	SPECIES_ALDER_SHRUB: 0.16,
	SPECIES_WILLOW_SHRUB: 0.10,
}

const MIXED_WEIGHTS: Dictionary = {
	SPECIES_BILBERRY: 0.08,
	SPECIES_COWBERRY: 0.07,
	SPECIES_HEATHER: 0.06,
	SPECIES_HAWTHORN: 0.07,
	SPECIES_BLACKTHORN: 0.06,
	SPECIES_HAZEL_SHRUB: 0.06,
	SPECIES_DOG_ROSE: 0.06,
	SPECIES_ELDER: 0.05,
	SPECIES_RASPBERRY: 0.05,
	SPECIES_GUELDER_ROSE: 0.05,
	SPECIES_SEA_BUCKTHORN: 0.05,
	SPECIES_CROWBERRY: 0.05,
	SPECIES_JUNIPER_SHRUB: 0.05,
	SPECIES_WILLOW_SHRUB: 0.05,
	SPECIES_ALDER_SHRUB: 0.05,
	SPECIES_WILD_STRAWBERRY: 0.04,
	SPECIES_SPINDLE: 0.04,
	SPECIES_CLOUDBERRY: 0.04,
	SPECIES_CRANBERRY: 0.04,
	SPECIES_BOG_ROSEMARY: 0.03,
}

const PROFILES: Dictionary = {
	SPECIES_BILBERRY:
	{
		"group": GROUP_BERRY,
		"archetype": ARCHETYPE_ROUND,
		"height": 0.42,
		"spread": 0.52,
		"clusters": 5,
		"density": 0.36,
		"color": Color(0.28, 0.58, 0.24),
		"accent": Color(0.42, 0.18, 0.62)
	},
	SPECIES_COWBERRY:
	{
		"group": GROUP_BERRY,
		"archetype": ARCHETYPE_ROUND,
		"height": 0.36,
		"spread": 0.48,
		"clusters": 4,
		"density": 0.34,
		"color": Color(0.30, 0.62, 0.26),
		"accent": Color(0.78, 0.22, 0.18)
	},
	SPECIES_CLOUDBERRY:
	{
		"group": GROUP_BOG,
		"archetype": ARCHETYPE_BOG,
		"height": 0.22,
		"spread": 0.58,
		"clusters": 6,
		"density": 0.40,
		"color": Color(0.34, 0.56, 0.28),
		"accent": Color(0.96, 0.78, 0.22)
	},
	SPECIES_CRANBERRY:
	{
		"group": GROUP_BOG,
		"archetype": ARCHETYPE_BOG,
		"height": 0.18,
		"spread": 0.62,
		"clusters": 7,
		"density": 0.42,
		"color": Color(0.26, 0.54, 0.24),
		"accent": Color(0.82, 0.24, 0.20)
	},
	SPECIES_CROWBERRY:
	{
		"group": GROUP_HEATH,
		"archetype": ARCHETYPE_SPREAD,
		"height": 0.28,
		"spread": 0.54,
		"clusters": 8,
		"density": 0.38,
		"color": Color(0.22, 0.48, 0.22),
		"accent": Color(0.18, 0.14, 0.12)
	},
	SPECIES_WILD_STRAWBERRY:
	{
		"group": GROUP_BERRY,
		"archetype": ARCHETYPE_SPREAD,
		"height": 0.14,
		"spread": 0.44,
		"clusters": 9,
		"density": 0.46,
		"color": Color(0.36, 0.68, 0.30),
		"accent": Color(0.92, 0.28, 0.24)
	},
	SPECIES_RASPBERRY:
	{
		"group": GROUP_BERRY,
		"archetype": ARCHETYPE_UPRIGHT,
		"height": 0.78,
		"spread": 0.38,
		"clusters": 4,
		"density": 0.32,
		"color": Color(0.32, 0.60, 0.28),
		"accent": Color(0.84, 0.20, 0.22)
	},
	SPECIES_DOG_ROSE:
	{
		"group": GROUP_UNDERSTORY,
		"archetype": ARCHETYPE_UPRIGHT,
		"height": 0.86,
		"spread": 0.42,
		"clusters": 4,
		"density": 0.30,
		"color": Color(0.34, 0.58, 0.30),
		"accent": Color(0.92, 0.42, 0.52)
	},
	SPECIES_GUELDER_ROSE:
	{
		"group": GROUP_UNDERSTORY,
		"archetype": ARCHETYPE_ROUND,
		"height": 0.92,
		"spread": 0.56,
		"clusters": 5,
		"density": 0.28,
		"color": Color(0.30, 0.56, 0.28),
		"accent": Color(0.94, 0.88, 0.72)
	},
	SPECIES_ELDER:
	{
		"group": GROUP_UNDERSTORY,
		"archetype": ARCHETYPE_UPRIGHT,
		"height": 1.04,
		"spread": 0.48,
		"clusters": 5,
		"density": 0.26,
		"color": Color(0.28, 0.54, 0.26),
		"accent": Color(0.72, 0.62, 0.18)
	},
	SPECIES_SEA_BUCKTHORN:
	{
		"group": GROUP_COASTAL,
		"archetype": ARCHETYPE_COASTAL,
		"height": 0.96,
		"spread": 0.62,
		"clusters": 5,
		"density": 0.30,
		"color": Color(0.52, 0.66, 0.28),
		"accent": Color(0.94, 0.72, 0.18)
	},
	SPECIES_HEATHER:
	{
		"group": GROUP_HEATH,
		"archetype": ARCHETYPE_SPREAD,
		"height": 0.34,
		"spread": 0.66,
		"clusters": 10,
		"density": 0.48,
		"color": Color(0.24, 0.46, 0.22),
		"accent": Color(0.72, 0.38, 0.78)
	},
	SPECIES_BOG_ROSEMARY:
	{
		"group": GROUP_BOG,
		"archetype": ARCHETYPE_BOG,
		"height": 0.30,
		"spread": 0.50,
		"clusters": 6,
		"density": 0.36,
		"color": Color(0.30, 0.50, 0.26),
		"accent": Color(0.82, 0.52, 0.72)
	},
	SPECIES_JUNIPER_SHRUB:
	{
		"group": GROUP_COASTAL,
		"archetype": ARCHETYPE_CONIFER,
		"height": 0.72,
		"spread": 0.46,
		"clusters": 4,
		"density": 0.32,
		"color": Color(0.22, 0.42, 0.24),
		"accent": Color(0.34, 0.52, 0.30)
	},
	SPECIES_HAZEL_SHRUB:
	{
		"group": GROUP_HEDGE,
		"archetype": ARCHETYPE_UPRIGHT,
		"height": 0.88,
		"spread": 0.44,
		"clusters": 5,
		"density": 0.30,
		"color": Color(0.30, 0.56, 0.28),
		"accent": Color(0.68, 0.48, 0.18)
	},
	SPECIES_HAWTHORN:
	{
		"group": GROUP_HEDGE,
		"archetype": ARCHETYPE_UPRIGHT,
		"height": 0.94,
		"spread": 0.40,
		"clusters": 4,
		"density": 0.28,
		"color": Color(0.28, 0.54, 0.26),
		"accent": Color(0.78, 0.22, 0.18)
	},
	SPECIES_BLACKTHORN:
	{
		"group": GROUP_HEDGE,
		"archetype": ARCHETYPE_UPRIGHT,
		"height": 0.82,
		"spread": 0.36,
		"clusters": 4,
		"density": 0.28,
		"color": Color(0.24, 0.48, 0.22),
		"accent": Color(0.42, 0.16, 0.14)
	},
	SPECIES_WILLOW_SHRUB:
	{
		"group": GROUP_WETLAND,
		"archetype": ARCHETYPE_WETLAND,
		"height": 0.98,
		"spread": 0.52,
		"clusters": 5,
		"density": 0.30,
		"color": Color(0.34, 0.60, 0.30),
		"accent": Color(0.72, 0.78, 0.42)
	},
	SPECIES_ALDER_SHRUB:
	{
		"group": GROUP_WETLAND,
		"archetype": ARCHETYPE_WETLAND,
		"height": 0.86,
		"spread": 0.48,
		"clusters": 5,
		"density": 0.32,
		"color": Color(0.26, 0.52, 0.28),
		"accent": Color(0.48, 0.62, 0.34)
	},
	SPECIES_SPINDLE:
	{
		"group": GROUP_HEDGE,
		"archetype": ARCHETYPE_UPRIGHT,
		"height": 0.76,
		"spread": 0.34,
		"clusters": 4,
		"density": 0.26,
		"color": Color(0.30, 0.54, 0.28),
		"accent": Color(0.82, 0.34, 0.42)
	},
}


static func is_known_species(species: StringName) -> bool:
	return species in ALL_SPECIES


static func is_known_variant(variant: StringName) -> bool:
	if variant in ALL_VARIANTS:
		return true
	return not parse_variant(variant).is_empty()


static func parse_variant(variant: StringName) -> Dictionary:
	var text := String(variant)
	if text.is_empty() or not text.begins_with("bush."):
		return {}
	var parts := text.split(".")
	if parts.size() < 2:
		return {}
	var token := StringName(parts[1])
	match token:
		&"dense":
			return {"group": &"dense"}
		&"scrub":
			return {"group": &"scrub"}
		&"mixed", &"hedge", &"heath", &"coastal", &"bog":
			return {"group": token}
		_:
			if is_known_species(token):
				return {"species": token}
	return {}


static func profile_for(species: StringName) -> Dictionary:
	return PROFILES.get(species, {})


static func group_for(species: StringName) -> StringName:
	return profile_for(species).get("group", &"")


static func weights_for_variant(variant: StringName) -> Dictionary:
	var parsed := parse_variant(variant)
	if parsed.has("species"):
		return {parsed["species"]: 1.0}
	match parsed.get("group", &""):
		&"dense":
			return DENSE_WEIGHTS
		&"scrub":
			return SCRUB_WEIGHTS
		&"hedge":
			return HEDGE_WEIGHTS
		&"heath":
			return HEATH_WEIGHTS
		&"coastal":
			return COASTAL_WEIGHTS
		&"bog":
			return BOG_WEIGHTS
		&"mixed":
			return MIXED_WEIGHTS
	return MIXED_WEIGHTS


static func pick_species(weights: Dictionary, roll: float) -> StringName:
	var total := 0.0
	for weight: Variant in weights.values():
		total += float(weight)
	if total <= 0.0:
		return SPECIES_BILBERRY
	var cursor := clampf(roll, 0.0, 0.999999) * total
	var last_key: StringName = SPECIES_BILBERRY
	for key: Variant in weights.keys():
		last_key = key as StringName
		cursor -= float(weights[key])
		if cursor <= 0.0:
			return last_key
	return last_key


static func scatter_density(species: StringName) -> float:
	return float(profile_for(species).get("density", 0.30))


static func scale_range(species: StringName) -> Vector2:
	var spread := float(profile_for(species).get("spread", 0.45))
	return Vector2(spread * 0.72, spread * 1.08)


static func instance_tint(species: StringName, roll: float) -> Color:
	var profile := profile_for(species)
	var leaf: Color = profile.get("color", Color(0.4, 0.7, 0.3))
	var variance := 0.86 + roll * 0.28
	return Color(leaf.r * variance, leaf.g * variance, leaf.b * variance)


static func material_kind(species: StringName) -> StringName:
	match group_for(species):
		GROUP_COASTAL, GROUP_HEATH:
			return &"scrub"
		GROUP_HEDGE, GROUP_UNDERSTORY:
			return &"leaf"
		GROUP_BOG, GROUP_WETLAND:
			return &"reed"
		_:
			return &"leaf"
