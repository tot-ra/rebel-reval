extends "res://scenes/world/reval_city/reval_city.gd"

## A regional site (ADR 0042, docs/SYSTEMS/REGIONAL_SITES.md): a distant travel
## destination built by tools/city/build_site_plan.py and shown by the same
## level as the seamless city. Only the plan differs: its directory, its ids
## (location, map and scene id from the plan's `site` block), its arrival
## spawns, its feature flags (citizens, fauna and interiors are off until a task
## turns them on) and its sky (sun, moon and stars over the site's own
## latitude and longitude). Sea, shore, harbour and ships mount only when the
## plan has a coast. Walking into the edge band opens the global travel map,
## as in Reval; there is no seamless link to any other place.
##
## Start a site directly:
##   godot --path . res://scenes/world/sites/paide.tscn -- --city-spawn=from_world_sojamae

## Plan directory under content/world/ (set per site scene).
@export var site_id := "paide"


func load_plan() -> CityPlan:
	var site_plan := CityPlan.load_site(site_id)
	# Before the view exists: the sky bakes its stars for this observer.
	SkyAstronomy.set_observer(site_plan.origin_latitude(), site_plan.origin_longitude())
	return site_plan


func scene_id() -> StringName:
	return StringName(plan.site_info().get("scene_id", site_id))


func default_spawn() -> String:
	return String(plan.site_info().get("default_spawn", ""))


## No Reval music zones here: the site plays its own theme, or none.
func _update_music(_xz: Vector2) -> void:
	var director := get_node_or_null("/root/MusicDirector")
	if director == null:
		return
	var theme := StringName(plan.site_info().get("music_theme", ""))
	if theme.is_empty():
		director.clear_zone_theme_override()
	else:
		director.set_zone_theme_override(theme)


func _exit_tree() -> void:
	# Back to the Reval observer for whatever loads next.
	SkyAstronomy.reset_observer()
