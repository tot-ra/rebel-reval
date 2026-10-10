class_name CityMapDefinition
extends MapDefinition

## MapDefinition facade for the seamless city (ADR 0031), so the shared
## gameplay runtime (MapViewRuntime: cameras, actors, magic, swimming, sky)
## can run on the city plan. It carries no cells, props or relief array; the
## height queries the runtime makes are answered from CityPlan instead.

var plan: CityPlan


static func from_plan(city_plan: CityPlan) -> CityMapDefinition:
	var definition := CityMapDefinition.new()
	definition.plan = city_plan
	# Regional sites (ADR 0042) keep their travel ids (`world.paide`, `loc.world_paide`).
	var site := city_plan.site_info()
	definition.map_id = StringName(site.get("map_id", "reval_city"))
	definition.location = StringName("loc.%s" % String(site.get("location_id", "reval_city")))
	definition.scope = &"production"
	definition.active = true
	definition.cell_size = int(CityPlan.LOGIC_PX_PER_UNIT)
	var end := city_plan.bounds.end
	definition.size_cells = Vector2i(ceili(end.x), ceili(end.y))
	definition.fingerprint = city_plan.site_id
	return definition


## Walking height (floors inside buildings) at a view XZ position.
func ground_height_override(world_xz: Vector2) -> float:
	return plan.walk_height(world_xz)


func height_at_world(world_position: Vector2) -> float:
	return plan.walk_height(world_position / float(cell_size))


func slope_at_world(world_position: Vector2) -> float:
	return plan.slope_at(world_position / float(cell_size))


func height_at_cell_space(position: Vector2) -> float:
	return plan.walk_height(position)


func is_world_travel_location() -> bool:
	return false


func suppresses_exterior_surroundings() -> bool:
	return false


## Bird habitat (MapViewBirdSpecies context) at a logic position: gulls and
## terns on the shore, jackdaws round the castle, market birds on the forum,
## open-country birds outside the walls, town birds elsewhere.
func bird_context_at(logic_position: Vector2) -> StringName:
	var xz := logic_position / float(cell_size)
	if plan.has_coast() and plan.ground_height(xz) < 2.5:
		return &"harbor"
	# A regional castle (ADR 0042) has the castle birds Toompea has.
	if plan.district_id_at(xz).ends_with(".district.castle"):
		return &"toompea"
	var where := plan.location_at(xz, false)
	match String(where.get("district", "")):
		"Toompea", "Vassal yards below the castle":
			return &"toompea"
		"Lower Town":
			var forum := plan.point_of_interest("poi.forum")
			if (
				not forum.is_empty()
				and xz.distance_to(Vector2(forum["at"][0], forum["at"][1])) < 70.0
			):
				return &"market_civic"
			return &"lower_town"
		"Fishing beach":
			return &"harbor"
	return &"foreland"
