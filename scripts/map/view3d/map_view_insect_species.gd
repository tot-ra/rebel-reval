class_name MapViewInsectSpecies
extends RefCounted

## Data-only catalog for Orthoptera (grasshoppers, bush-crickets, crickets)
## stridulation ambience. Mirrors MapViewBirdSpecies: stable IDs, ecological
## habitat weights, and a diel (time-of-day) activity tag. Runtime playback is
## owned by MapViewInsectAmbientAudio; there is no gameplay interaction and no
## on-screen model (individuals are sub-pixel at gameplay orthographic scale).
##
## Clips are the CC BY-SA field recordings sourced from elurikkus.ee; the stream
## for a species lives at res://sounds/insects/<id>/<id>.mp3 (see CREDITS.md).

const GROUP_GRASSHOPPER := &"grasshopper"
const GROUP_BUSH_CRICKET := &"bush_cricket"
const GROUP_CRICKET := &"cricket"
const GROUP_MOLE_CRICKET := &"mole_cricket"

const ALL_GROUPS: Array[StringName] = [
	GROUP_GRASSHOPPER,
	GROUP_BUSH_CRICKET,
	GROUP_CRICKET,
	GROUP_MOLE_CRICKET,
]

## Insect-specific habitat contexts. Deliberately green/rural only: the stone
## town core has no insect context, so the ambience stays silent there.
const CONTEXT_MEADOW := &"meadow"
const CONTEXT_GARDEN := &"garden"
const CONTEXT_WETLAND := &"wetland"
const CONTEXT_WOODLAND_EDGE := &"woodland_edge"

const ALL_CONTEXTS: Array[StringName] = [
	CONTEXT_MEADOW,
	CONTEXT_GARDEN,
	CONTEXT_WETLAND,
	CONTEXT_WOODLAND_EDGE,
]

## Diel activity tags. Grasshoppers need sun-warmth (day); bush-crickets carry
## on into the summer night; true crickets and the mole cricket are dusk/night.
const TIME_WARM_DAY := &"warm_day"
const TIME_DAY_DUSK_NIGHT := &"day_dusk_night"
const TIME_DUSK_NIGHT := &"dusk_night"

## Relative authoring weights per group and context (not probabilities).
const GROUP_SPAWN_WEIGHTS: Dictionary = {
	GROUP_GRASSHOPPER: {CONTEXT_MEADOW: 1.0, CONTEXT_GARDEN: 0.35, CONTEXT_WETLAND: 0.40, CONTEXT_WOODLAND_EDGE: 0.25},
	GROUP_BUSH_CRICKET: {CONTEXT_MEADOW: 0.80, CONTEXT_GARDEN: 0.70, CONTEXT_WETLAND: 0.50, CONTEXT_WOODLAND_EDGE: 0.90},
	GROUP_CRICKET: {CONTEXT_MEADOW: 0.30, CONTEXT_GARDEN: 0.90, CONTEXT_WETLAND: 0.20, CONTEXT_WOODLAND_EDGE: 0.30},
	GROUP_MOLE_CRICKET: {CONTEXT_MEADOW: 0.20, CONTEXT_GARDEN: 0.50, CONTEXT_WETLAND: 1.0, CONTEXT_WOODLAND_EDGE: 0.20},
}

## species id -> {group, time, abundance}. `abundance` scales the group weight so
## dominant meadow species carry the bed while rarities stay occasional.
const PROFILES: Dictionary = {
	# Short-grass grasshoppers (Acrididae): warm daytime meadow carpet.
	&"acrididae": {"group": GROUP_GRASSHOPPER, "time": TIME_WARM_DAY, "abundance": 0.70},
	&"orthoptera": {"group": GROUP_GRASSHOPPER, "time": TIME_WARM_DAY, "abundance": 0.55},
	&"chorthippus_albomarginatus": {"group": GROUP_GRASSHOPPER, "time": TIME_WARM_DAY, "abundance": 0.85},
	&"chorthippus_apricarius": {"group": GROUP_GRASSHOPPER, "time": TIME_WARM_DAY, "abundance": 0.80},
	&"chorthippus_biguttulus": {"group": GROUP_GRASSHOPPER, "time": TIME_WARM_DAY, "abundance": 1.0},
	&"chorthippus_brunneus": {"group": GROUP_GRASSHOPPER, "time": TIME_WARM_DAY, "abundance": 0.95},
	&"chorthippus_dorsatus": {"group": GROUP_GRASSHOPPER, "time": TIME_WARM_DAY, "abundance": 0.75},
	&"chorthippus_mollis": {"group": GROUP_GRASSHOPPER, "time": TIME_WARM_DAY, "abundance": 0.70},
	&"pseudochorthippus_montanus": {"group": GROUP_GRASSHOPPER, "time": TIME_WARM_DAY, "abundance": 0.60},
	&"pseudochorthippus_parallelus": {"group": GROUP_GRASSHOPPER, "time": TIME_WARM_DAY, "abundance": 0.90},
	&"stenobothrus_lineatus": {"group": GROUP_GRASSHOPPER, "time": TIME_WARM_DAY, "abundance": 0.65},
	&"myrmeleotettix_maculatus": {"group": GROUP_GRASSHOPPER, "time": TIME_WARM_DAY, "abundance": 0.60},
	&"omocestus_viridulus": {"group": GROUP_GRASSHOPPER, "time": TIME_WARM_DAY, "abundance": 0.70},
	&"euthystira_brachyptera": {"group": GROUP_GRASSHOPPER, "time": TIME_WARM_DAY, "abundance": 0.55},
	&"chrysochraon_dispar": {"group": GROUP_GRASSHOPPER, "time": TIME_WARM_DAY, "abundance": 0.60},
	# Bush-crickets (Tettigoniidae): afternoon into the night.
	&"tettigonia_viridissima": {"group": GROUP_BUSH_CRICKET, "time": TIME_DAY_DUSK_NIGHT, "abundance": 1.0},
	&"tettigonia_cantans": {"group": GROUP_BUSH_CRICKET, "time": TIME_DAY_DUSK_NIGHT, "abundance": 0.90},
	&"metrioptera_brachyptera": {"group": GROUP_BUSH_CRICKET, "time": TIME_DAY_DUSK_NIGHT, "abundance": 0.70},
	&"roeseliana_roeselii": {"group": GROUP_BUSH_CRICKET, "time": TIME_DAY_DUSK_NIGHT, "abundance": 0.85},
	&"bicolorana_bicolor": {"group": GROUP_BUSH_CRICKET, "time": TIME_DAY_DUSK_NIGHT, "abundance": 0.65},
	&"conocephalus_dorsalis": {"group": GROUP_BUSH_CRICKET, "time": TIME_DAY_DUSK_NIGHT, "abundance": 0.70},
	&"conocephalus_fuscus": {"group": GROUP_BUSH_CRICKET, "time": TIME_DAY_DUSK_NIGHT, "abundance": 0.75},
	&"decticus_verrucivorus": {"group": GROUP_BUSH_CRICKET, "time": TIME_DAY_DUSK_NIGHT, "abundance": 0.60},
	&"pholidoptera_griseoaptera": {"group": GROUP_BUSH_CRICKET, "time": TIME_DAY_DUSK_NIGHT, "abundance": 0.80},
	&"barbitistes_constrictus": {"group": GROUP_BUSH_CRICKET, "time": TIME_DAY_DUSK_NIGHT, "abundance": 0.55},
	# True cricket: warm garden, dusk into night.
	&"acheta_domestica": {"group": GROUP_CRICKET, "time": TIME_DUSK_NIGHT, "abundance": 0.80},
	# Mole cricket: damp ground, spring/summer dusk churr.
	&"gryllotalpa_gryllotalpa": {"group": GROUP_MOLE_CRICKET, "time": TIME_DUSK_NIGHT, "abundance": 0.65},
}

const ALL_SPECIES: Array[StringName] = [
	&"acrididae", &"orthoptera",
	&"chorthippus_albomarginatus", &"chorthippus_apricarius", &"chorthippus_biguttulus",
	&"chorthippus_brunneus", &"chorthippus_dorsatus", &"chorthippus_mollis",
	&"pseudochorthippus_montanus", &"pseudochorthippus_parallelus",
	&"stenobothrus_lineatus", &"myrmeleotettix_maculatus", &"omocestus_viridulus",
	&"euthystira_brachyptera", &"chrysochraon_dispar",
	&"tettigonia_viridissima", &"tettigonia_cantans", &"metrioptera_brachyptera",
	&"roeseliana_roeselii", &"bicolorana_bicolor", &"conocephalus_dorsalis",
	&"conocephalus_fuscus", &"decticus_verrucivorus", &"pholidoptera_griseoaptera",
	&"barbitistes_constrictus", &"acheta_domestica", &"gryllotalpa_gryllotalpa",
]


static func is_known_species(species: StringName) -> bool:
	return PROFILES.has(species)


static func group_for(species: StringName) -> StringName:
	return StringName(PROFILES.get(species, {}).get("group", &""))


static func time_tag_for(species: StringName) -> StringName:
	return StringName(PROFILES.get(species, {}).get("time", TIME_WARM_DAY))


static func spawn_weight(species: StringName, context: StringName) -> float:
	if not is_known_species(species):
		return 0.0
	var group := group_for(species)
	var base := float((GROUP_SPAWN_WEIGHTS.get(group, {}) as Dictionary).get(context, 0.0))
	var abundance := float(PROFILES[species].get("abundance", 1.0))
	return clampf(base * abundance, 0.0, 1.0)


## Deterministic clip path for a species (looped as a stridulation bed at runtime).
static func stream_path_for(species: StringName) -> String:
	if not is_known_species(species):
		return ""
	return "res://sounds/insects/%s/%s.mp3" % [species, species]
