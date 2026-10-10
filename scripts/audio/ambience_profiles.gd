class_name AmbienceProfiles
extends RefCounted

## Per-map ambience layer declarations for AmbienceController (ADR 0035 phase
## 2). Same shape as the bird, insect and fauna context tables: an explicit map
## of map_id -> layers, never filesystem or catalog discovery, so CI coverage
## cannot depend on load order.
##
## Layer entries address catalog IDs only. An entry may carry:
##   id            catalog ID (required)
##   volume_db     offset applied on top of the catalog entry
##   hours         [from, to] audible window in game hours, wrapping allowed
##   min_interval, max_interval, radius_min, radius_max   spot layer only
##
## The weather layer names the *exterior* rain loop. Interior rain-on-roof stays
## with SkyWeatherRoofAudio inside SkyWeather3D.
##
## Phase-2 pilot covers the two slice locations. The bed clips are in-house
## synthesis placeholders (see tools/audio/generate_ambience_beds.py); the mid
## and spot layers stay empty until licensed crowd and spot material exists
## (AUDIO-4 / R-1359). Birds and insects already run as their own controllers,
## so day and night variation comes from them, not from separate beds.
##
## R-1550 adds two weather-driven layers, each a three-tier crossfade by wind
## strength (AmbienceController.tier_weights):
##   sea    {"calm", "moderate", "storm"} surf, scaled by distance to the sea
##   wind   {"light", "strong", "storm"} exterior wind, lifted by gusts
## Coastal maps get both; inland exterior maps get wind only. Interiors get
## neither (suppresses_exterior_surroundings mutes them anyway).

const SEA: Dictionary = {
	"calm": &"amb.sea.calm",
	"moderate": &"amb.sea.moderate",
	"storm": &"amb.sea.storm",
}
const WIND: Dictionary = {
	"light": &"amb.wind.light",
	"strong": &"amb.wind.strong",
	"storm": &"amb.wind.storm",
}

const PROFILES: Dictionary = {
	&"lower_town_slice":
	{
		"bed": [{"id": &"amb.lower_town.bed"}],
		"mid": [],
		"spot": [],
		"weather": {"rain_exterior": &"amb.weather.rain_outdoor"},
		"wind": WIND,
	},
	# Seamless city (ADR 0031): Kalarand strand, harbour and the bay shore. No
	# bed: the city's districts get their own beds under R-1470.
	&"reval_city":
	{
		"bed": [],
		"mid": [],
		"spot": [],
		"weather": {"rain_exterior": &"amb.weather.rain_outdoor"},
		"sea": SEA,
		"wind": WIND,
	},
	&"prototype.reval_harbor_surroundings":
	{
		"weather": {"rain_exterior": &"amb.weather.rain_outdoor"},
		"sea": SEA,
		"wind": WIND,
	},
	&"prototype.paldiski_coastal_outpost":
	{
		"weather": {"rain_exterior": &"amb.weather.rain_outdoor"},
		"sea": SEA,
		"wind": WIND,
	},
	&"world_saaremaa":
	{
		"weather": {"rain_exterior": &"amb.weather.rain_outdoor"},
		"sea": SEA,
		"wind": WIND,
	},
	&"kalev_smithy":
	{
		"bed": [{"id": &"amb.forge.bed"}],
		"mid": [],
		"spot": [],
		# Interior: SkyWeatherRoofAudio owns the muffled roof rain.
		"weather": {},
	},
}


static func has_profile(map_id: StringName) -> bool:
	return PROFILES.has(map_id)


## Empty dictionary for maps without a profile; the controller then stays silent.
static func profile_for_map(map_id: StringName) -> Dictionary:
	return PROFILES.get(map_id, {})


## Every catalog ID any profile references. The coverage test asserts each one
## exists, so a typo in a profile cannot ship as silence.
static func referenced_sound_ids() -> Array[StringName]:
	var ids: Dictionary = {}
	for map_id: StringName in PROFILES.keys():
		var profile: Dictionary = PROFILES[map_id]
		for layer: StringName in [&"bed", &"mid", &"spot"]:
			for entry: Dictionary in profile.get(layer, []):
				ids[StringName(entry.get("id", &""))] = true
		for weather_id: Variant in profile.get("weather", {}).values():
			ids[StringName(weather_id)] = true
		for layer_name: String in ["sea", "wind"]:
			for tier_id: Variant in profile.get(layer_name, {}).values():
				if tier_id is StringName:
					ids[tier_id] = true
	ids.erase(&"")
	var out: Array[StringName] = []
	out.assign(ids.keys())
	out.sort()
	return out
