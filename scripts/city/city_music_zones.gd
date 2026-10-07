class_name CityMusicZones
extends RefCounted

## Picks the `MusicDirector` theme for the seamless Reval city from where Kalev
## stands, instead of from a scene path. Each zone is a landmark and a radius in
## world units (x east, z south). The most specific zone around Kalev wins (the
## smallest radius), so the council hall beats the forum and the forum beats the
## wider quarter. Away from every zone the district decides. A theme that is
## already playing holds on for HOLD_FACTOR x its radius, so walking along a
## zone edge does not flip the music back and forth.
##
## Themes are the existing `MusicDirector` ids, each backed by a folder under
## `res://music/`. Zone centres reuse plan ids (`poi.*`, `gate.*`, landmarks).

const HOLD_FACTOR := 1.25

const ZONES: Array[Dictionary] = [
	# Interiors and precincts: small radii, most specific.
	{"id": "zone.town_hall", "theme": &"raekoda", "at": Vector2(-13.0, 15.0), "radius": 22.0},
	{"id": "zone.holy_spirit", "theme": &"holy_spirit", "at": Vector2(14.0, -79.0), "radius": 28.0},
	{"id": "zone.st_olaf", "theme": &"oleviste", "at": Vector2(111.0, -445.0), "radius": 48.0},
	{"id": "zone.dominican", "theme": &"monastery", "at": Vector2(164.0, -65.0), "radius": 48.0},
	{"id": "zone.smithy", "theme": &"forge", "at": Vector2(-75.0, 190.0), "radius": 34.0},
	{"id": "zone.bishop_garden", "theme": &"garden", "at": Vector2(-330.0, 110.0), "radius": 60.0},
	# Quarters.
	{"id": "zone.forum", "theme": &"center", "at": Vector2(5.0, -10.0), "radius": 95.0},
	{"id": "zone.pikk", "theme": &"north", "at": Vector2(100.0, -330.0), "radius": 150.0},
	{"id": "zone.south", "theme": &"south", "at": Vector2(-117.0, 163.0), "radius": 115.0},
	{"id": "zone.viru", "theme": &"town", "at": Vector2(200.0, 40.0), "radius": 130.0},
	{"id": "zone.harbour", "theme": &"harbor", "at": Vector2(230.0, -640.0), "radius": 140.0},
	{"id": "zone.castle", "theme": &"toompea", "at": Vector2(-400.0, 100.0), "radius": 170.0},
]

## Used where no zone reaches: plan district id -> theme. Fields and the far
## suburbs are left out on purpose; the music fades out there.
const DISTRICT_THEMES: Dictionary = {
	"district.toompea": &"toompea",
	"district.toompea_foot": &"toompea",
	"district.lower_town": &"center",
	"district.viru": &"town",
	"district.kalarand": &"harbor",
}

var current_theme := &""


## Theme for `world_xz`, remembering it for the hold radius on the next call.
func update(world_xz: Vector2, district_id: String = "") -> StringName:
	current_theme = theme_at(world_xz, district_id, current_theme)
	return current_theme


static func theme_at(
	world_xz: Vector2, district_id: String = "", current: StringName = &""
) -> StringName:
	var best_theme := &""
	var best_radius := INF
	for zone: Dictionary in ZONES:
		var theme: StringName = zone["theme"]
		var radius: float = zone["radius"]
		var reach := radius * (HOLD_FACTOR if theme == current else 1.0)
		if world_xz.distance_to(zone["at"]) > reach:
			continue
		# Compare on the zone's own radius, not the widened hold reach.
		if radius < best_radius:
			best_radius = radius
			best_theme = theme
	if not best_theme.is_empty():
		return best_theme
	return DISTRICT_THEMES.get(district_id, &"") as StringName
