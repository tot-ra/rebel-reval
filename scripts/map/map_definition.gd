class_name MapDefinition
extends RefCounted

## Declarative map data used by MapBuilder. Zones are applied in array order.

var map_id: StringName = &""
var seed: int = MapTypes.DEFAULT_SEED
var cell_size: int = MapTypes.DEFAULT_CELL_SIZE
var size_cells: Vector2i = Vector2i.ZERO
var base_terrain: StringName = MapTypes.TERRAIN_GRASS
## Outdoor terrain datum in 3D world units. This is view geometry only: 2D
## collision/navigation remain on the canonical X/Y gameplay plane.
var ground_elevation: float = 0.0
var zones: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var props: Array[Dictionary] = []
var player_spawn: Vector2 = Vector2.ZERO
var location: StringName = &""
var scope: StringName = &""
var active: bool = false
var palette: StringName = &""
var transitions: Array[Dictionary] = []
## Optional wooden wayfinding signs attached to transitions that lead beyond
## the city walls. Each sign declares text, position, and outgoing direction.
var direction_signs: Array[Dictionary] = []
var excluded_areas: Array[Rect2i] = []
var patrols: Array[Dictionary] = []
var interaction_anchors: Array[Dictionary] = []
var camera_bounds: Rect2 = Rect2(0, 0, 0, 0)
var fade_volumes: Array[Dictionary] = []
var source_references: Array[String] = []
var fingerprint: String = ""
## View-only markers rendered by the 3D layer (e.g. a gate arch spanning a
## walkable opening). Never contributes collision, navigation, or blocking.
var view_landmarks: Array[Dictionary] = []
## Sides of the map (&"north"/&"south"/&"east"/&"west") where the view-only
## surroundings should read as continuing town instead of open woodland.
var surroundings_town_sides: Array[StringName] = []
## Per-side authored view continuation. Values are &"town", &"water", or
## &"woodland". Unlisted sides render no exterior backdrop.
var surroundings_sides: Dictionary = {}

const VIEW_LANDMARK_KINDS: Array[StringName] = [&"gate_arch", &"interior_window"]
const WORLD_SIDES: Array[StringName] = [&"north", &"south", &"east", &"west"]
const SURROUNDINGS_KINDS: Array[StringName] = [&"town", &"water", &"woodland"]


func cell_rect_to_world_rect(cell_rect: Rect2i) -> Rect2:
	var pixel_size := Vector2(float(cell_size), float(cell_size))
	return Rect2(Vector2(cell_rect.position) * pixel_size, Vector2(cell_rect.size) * pixel_size)


func cell_rect_center(cell_rect: Rect2i) -> Vector2:
	var world_rect := cell_rect_to_world_rect(cell_rect)
	return world_rect.position + world_rect.size * 0.5


func validate() -> Array[String]:
	var errors: Array[String] = []

	if map_id.is_empty():
		errors.append("map_id is required")
	if cell_size <= 0:
		errors.append("cell_size must be positive")
	if size_cells.x <= 0 or size_cells.y <= 0:
		errors.append("size_cells must be positive")
	if not is_finite(ground_elevation) or ground_elevation < 0.0 or ground_elevation > 8.0:
		errors.append("ground_elevation must be finite and between 0 and 8 world units")

	if not MapTypes.ALL_TERRAINS.has(base_terrain):
		errors.append("unknown base_terrain: %s" % String(base_terrain))

	for index in zones.size():
		errors.append_array(_validate_zone(zones[index], index))

	var seen_ids: Dictionary = {}
	for index in buildings.size():
		errors.append_array(_validate_building(buildings[index], index, seen_ids))

	for index in props.size():
		errors.append_array(_validate_prop(props[index], index, seen_ids))

	if player_spawn == Vector2.ZERO:
		errors.append("player_spawn must be set")
	elif not _point_inside_world_pixels(player_spawn):
		errors.append("player_spawn is outside world bounds")


	if location.is_empty():
		errors.append("location is required")
	if scope.is_empty():
		errors.append("scope is required")
	elif not scope in [&"prototype", &"production", &"archive"]:
		errors.append("scope must be prototype, production, or archive")
	if active and scope in [&"prototype", &"archive"]:
		errors.append("active=true is rejected for prototype or archive scope")
	if palette.is_empty():
		errors.append("palette is required")

	for index in transitions.size():
		errors.append_array(_validate_transition(transitions[index], index, seen_ids))

	for index in direction_signs.size():
		errors.append_array(_validate_direction_sign(direction_signs[index], index))

	for index in excluded_areas.size():
		errors.append_array(_validate_excluded_area(excluded_areas[index], index))

	for index in patrols.size():
		errors.append_array(_validate_patrol(patrols[index], index))

	for index in interaction_anchors.size():
		errors.append_array(_validate_interaction_anchor(interaction_anchors[index], index, seen_ids))

	for index in fade_volumes.size():
		errors.append_array(_validate_fade_volume(fade_volumes[index], index))

	for index in view_landmarks.size():
		errors.append_array(_validate_view_landmark(view_landmarks[index], index, seen_ids))

	for side in surroundings_town_sides:
		if not WORLD_SIDES.has(side):
			errors.append("surroundings_town_sides has unknown side: %s" % String(side))

	for side in surroundings_sides.keys():
		if not WORLD_SIDES.has(side):
			errors.append("surroundings_sides has unknown side: %s" % String(side))
		elif not SURROUNDINGS_KINDS.has(surroundings_sides[side]):
			errors.append(
				"surroundings_sides[%s] has unknown kind: %s"
				% [String(side), String(surroundings_sides[side])]
			)

	if camera_bounds.size.x < 0 or camera_bounds.size.y < 0:
		errors.append("camera_bounds cannot be negative")

	if fingerprint.is_empty():
		errors.append("fingerprint is required")
	return errors


func world_size() -> Vector2:
	return Vector2(float(size_cells.x * cell_size), float(size_cells.y * cell_size))


## Enclosed room shells (perimeter interior_wall on every side) should not paint
## the countryside treeline or meadow apron past the authored walls.
func suppresses_exterior_surroundings() -> bool:
	if not surroundings_sides.is_empty():
		return false
	if not surroundings_town_sides.is_empty():
		return false
	var north := false
	var south := false
	var west := false
	var east := false
	for building in buildings:
		if building.get("kind") != MapTypes.BUILDING_KIND_INTERIOR_WALL:
			continue
		var cell_rect := _world_rect_to_cell_rect(building["footprint"])
		if cell_rect.position.y <= 0:
			north = true
		if cell_rect.end.y >= size_cells.y:
			south = true
		if cell_rect.position.x <= 0:
			west = true
		if cell_rect.end.x >= size_cells.x:
			east = true
	return north and south and west and east


func resolved_surroundings_sides() -> Dictionary:
	if not surroundings_sides.is_empty():
		return surroundings_sides
	var derived: Dictionary = {}
	for side in surroundings_town_sides:
		derived[side] = &"town"
	return derived


func _world_rect_to_cell_rect(world_rect: Rect2) -> Rect2i:
	var pixel := float(cell_size)
	return Rect2i(
		int(floor(world_rect.position.x / pixel)),
		int(floor(world_rect.position.y / pixel)),
		maxi(1, int(round(world_rect.size.x / pixel))),
		maxi(1, int(round(world_rect.size.y / pixel)))
	)


func _validate_zone(zone: Dictionary, index: int) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "zones[%d]" % index

	if not zone.has("rect") or not zone["rect"] is Rect2i:
		errors.append("%s.rect must be Rect2i" % prefix)
		return errors

	var terrain: Variant = zone.get("terrain", &"")
	if not MapTypes.ALL_TERRAINS.has(terrain):
		errors.append("%s.terrain is unknown: %s" % [prefix, str(terrain)])

	var rect: Rect2i = zone["rect"]
	if rect.size.x <= 0 or rect.size.y <= 0:
		errors.append("%s.rect must have positive size" % prefix)
	elif not _rect_inside_bounds(rect):
		errors.append("%s.rect is outside world bounds" % prefix)

	var style_variant: Variant = zone.get("style_variant", &"")
	if style_variant is StringName and not String(style_variant).is_empty():
		if not TerrainVegetation.is_known_variant(style_variant):
			errors.append("%s.style_variant is unknown: %s" % [prefix, String(style_variant)])

	if zone.has("movement_speed_multiplier"):
		var speed := float(zone["movement_speed_multiplier"])
		if speed < TerrainVegetation.MIN_SPEED_MULTIPLIER or speed > TerrainVegetation.MAX_SPEED_MULTIPLIER:
			errors.append("%s.movement_speed_multiplier must be between %.2f and %.2f" % [
				prefix, TerrainVegetation.MIN_SPEED_MULTIPLIER, TerrainVegetation.MAX_SPEED_MULTIPLIER
			])

	return errors


func _validate_building(building: Dictionary, index: int, seen_ids: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "buildings[%d]" % index

	if not building.has("id") or String(building["id"]).is_empty():
		errors.append("%s.id is required" % prefix)
	else:
		var building_id: StringName = building["id"]
		if seen_ids.has(building_id):
			errors.append("duplicate stable id: %s" % String(building_id))
		seen_ids[building_id] = true

	var kind: Variant = building.get("kind", MapTypes.BUILDING_KIND_HOUSE)
	if not MapTypes.ALL_BUILDING_KINDS.has(kind):
		errors.append("%s.kind is unknown: %s" % [prefix, str(kind)])

	if not building.has("footprint") or not building["footprint"] is Rect2:
		errors.append("%s.footprint must be Rect2" % prefix)
		return errors

	var footprint: Rect2 = building["footprint"]
	if footprint.size.x <= 0.0 or footprint.size.y <= 0.0:
		errors.append("%s.footprint must have positive size" % prefix)
	if not _rect_inside_world_pixels(footprint):
		errors.append("%s.footprint is outside world bounds" % prefix)
	if bool(building.get("tower", false)):
		var door_side := StringName(String(building.get("door_side", "")))
		if not WORLD_SIDES.has(door_side):
			errors.append("%s.tower requires door_side north, south, east, or west" % prefix)
	elif building.has("tower") and building["tower"] != false:
		errors.append("%s.tower must be a boolean" % prefix)
	if building.has("round_tower") and not (building["round_tower"] is bool):
		errors.append("%s.round_tower must be a boolean" % prefix)
	var wall_walk_axis := StringName(building.get("wall_walk_axis", &""))
	if wall_walk_axis != &"" and wall_walk_axis not in [&"x", &"z"]:
		errors.append("%s.wall_walk_axis must be x or z" % prefix)
	if wall_walk_axis != &"" and not MapWallWalkAccess.is_round_tower(building):
		errors.append("%s.wall_walk_axis requires a round tower" % prefix)
	var interior_side := StringName(building.get("interior_side", &""))
	if interior_side != &"" and not WORLD_SIDES.has(interior_side):
		errors.append("%s.interior_side must be north, south, east, or west" % prefix)
	if building.has("faction") and not FactionHeraldry.is_known(StringName(building["faction"])):
		errors.append("%s.faction is unknown: %s" % [prefix, str(building["faction"])])

	return errors


func _validate_prop(prop: Dictionary, index: int, seen_ids: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "props[%d]" % index

	if not prop.has("id") or String(prop["id"]).is_empty():
		errors.append("%s.id is required" % prefix)
	else:
		var prop_id: StringName = prop["id"]
		if seen_ids.has(prop_id):
			errors.append("duplicate stable id: %s" % String(prop_id))
		seen_ids[prop_id] = true

	if not prop.has("kind") or String(prop["kind"]).is_empty():
		errors.append("%s.kind is required" % prefix)
	elif not MapTypes.ALL_PROP_KINDS.has(prop["kind"]):
		errors.append("%s.kind is unknown: %s" % [prefix, str(prop["kind"])])

	if not prop.has("position") or not prop["position"] is Vector2:
		errors.append("%s.position must be Vector2" % prefix)
	elif not _point_inside_world_pixels(prop["position"]):
		errors.append("%s.position is outside world bounds" % prefix)

	if prop.has("movement_speed_multiplier"):
		var speed := float(prop["movement_speed_multiplier"])
		if speed < TerrainVegetation.MIN_SPEED_MULTIPLIER or speed > TerrainVegetation.MAX_SPEED_MULTIPLIER:
			errors.append("%s.movement_speed_multiplier must be between %.2f and %.2f" % [
				prefix, TerrainVegetation.MIN_SPEED_MULTIPLIER, TerrainVegetation.MAX_SPEED_MULTIPLIER
			])
	if prop.has("faction") and not FactionHeraldry.is_known(StringName(prop["faction"])):
		errors.append("%s.faction is unknown: %s" % [prefix, str(prop["faction"])])

	return errors


func _rect_inside_bounds(rect: Rect2i) -> bool:
	return rect.position.x >= 0 \
		and rect.position.y >= 0 \
		and rect.end.x <= size_cells.x \
		and rect.end.y <= size_cells.y


func _rect_inside_world_pixels(rect: Rect2) -> bool:
	var world := world_size()
	return rect.position.x >= 0.0 \
		and rect.position.y >= 0.0 \
		and rect.end.x <= world.x \
		and rect.end.y <= world.y


func _point_inside_world_pixels(point: Vector2) -> bool:
	var world := world_size()
	return point.x >= 0.0 \
		and point.y >= 0.0 \
		and point.x <= world.x \
		and point.y <= world.y


func _validate_transition(trans: Dictionary, index: int, seen_ids: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "transitions[%d]" % index

	if not trans.has("id") or String(trans["id"]).is_empty():
		errors.append("%s.id is required" % prefix)
	else:
		var trans_id: StringName = trans["id"]
		if seen_ids.has(trans_id):
			errors.append("duplicate stable id: %s" % String(trans_id))
		seen_ids[trans_id] = true

	if not trans.has("rect") or not trans["rect"] is Rect2:
		errors.append("%s.rect must be Rect2" % prefix)
	elif not _rect_inside_world_pixels(trans["rect"]):
		errors.append("%s.rect is outside world bounds" % prefix)

	var transition_visual: StringName = trans.get("transition_visual", MapTypes.TRANSITION_VISUAL_DOOR)
	if not MapTypes.TRANSITION_VISUALS.has(transition_visual):
		errors.append("%s.transition_visual is unknown: %s" % [prefix, String(transition_visual)])
	if bool(trans.get("highlight_area", false)) and transition_visual != MapTypes.TRANSITION_VISUAL_GROUND:
		errors.append("%s.highlight_area requires transition_visual=ground" % prefix)

	var building_id := StringName(String(trans.get("building_id", "")))
	if not building_id.is_empty():
		var building: Dictionary = {}
		for candidate in buildings:
			if candidate.get("id", &"") == building_id:
				building = candidate
				break
		if building.is_empty():
			errors.append("%s.building_id references unknown building: %s" % [prefix, String(building_id)])
		elif transition_visual != MapTypes.TRANSITION_VISUAL_DOOR:
			errors.append("%s.building_id requires transition_visual=door" % prefix)
		elif not MapBuildingEntrance.approach_aligns_with_facade(building, trans, cell_size):
			errors.append("%s approach does not align with building facade: %s" % [prefix, String(building_id)])

	return errors


func _validate_direction_sign(sign: Dictionary, index: int) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "direction_signs[%d]" % index

	if not sign.has("text") or String(sign["text"]).strip_edges().is_empty():
		errors.append("%s.text is required" % prefix)

	if not sign.has("position") or not sign["position"] is Vector2:
		errors.append("%s.position must be Vector2" % prefix)
	elif not _point_inside_world_pixels(sign["position"]):
		errors.append("%s.position is outside world bounds" % prefix)

	if not sign.has("direction") or not sign["direction"] is Vector2:
		errors.append("%s.direction must be Vector2" % prefix)
	elif (sign["direction"] as Vector2).is_zero_approx():
		errors.append("%s.direction must not be zero" % prefix)

	return errors


func _validate_excluded_area(rect: Rect2i, index: int) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "excluded_areas[%d]" % index

	if rect.size.x <= 0 or rect.size.y <= 0:
		errors.append("%s must have positive size" % prefix)
	elif not _rect_inside_bounds(rect):
		errors.append("%s is outside world bounds" % prefix)

	return errors


func _validate_patrol(patrol: Dictionary, index: int) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "patrols[%d]" % index

	if not patrol.has("points") or not patrol["points"] is Array:
		errors.append("%s.points must be Array of Vector2" % prefix)
	else:
		var points = patrol["points"]
		if points.is_empty():
			errors.append("%s.points must not be empty" % prefix)
		else:
			for p in points:
				if not p is Vector2:
					errors.append("%s.points must contain Vector2" % prefix)
					break
				if not _point_inside_world_pixels(p):
					errors.append("%s.points has point outside world bounds" % prefix)
					break

	return errors


func _validate_interaction_anchor(anchor: Dictionary, index: int, seen_ids: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "interaction_anchors[%d]" % index

	if not anchor.has("id") or String(anchor["id"]).is_empty():
		errors.append("%s.id is required" % prefix)
	else:
		var anchor_id: StringName = anchor["id"]
		if seen_ids.has(anchor_id):
			errors.append("duplicate stable id: %s" % String(anchor_id))
		seen_ids[anchor_id] = true

	if not anchor.has("position") or not anchor["position"] is Vector2:
		errors.append("%s.position must be Vector2" % prefix)
	elif not _point_inside_world_pixels(anchor["position"]):
		errors.append("%s.position is outside world bounds" % prefix)

	return errors


func _validate_view_landmark(landmark: Dictionary, index: int, seen_ids: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "view_landmarks[%d]" % index

	if not landmark.has("id") or String(landmark["id"]).is_empty():
		errors.append("%s.id is required" % prefix)
	else:
		var landmark_id: StringName = landmark["id"]
		if seen_ids.has(landmark_id):
			errors.append("duplicate stable id: %s" % String(landmark_id))
		seen_ids[landmark_id] = true

	if not VIEW_LANDMARK_KINDS.has(landmark.get("kind", &"")):
		errors.append("%s.kind is unknown: %s" % [prefix, str(landmark.get("kind", ""))])

	if not landmark.has("rect") or not landmark["rect"] is Rect2:
		errors.append("%s.rect must be Rect2" % prefix)
	elif not _rect_inside_world_pixels(landmark["rect"]):
		errors.append("%s.rect is outside world bounds" % prefix)

	return errors


func _validate_fade_volume(volume: Dictionary, index: int) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "fade_volumes[%d]" % index

	if not volume.has("rect") or not volume["rect"] is Rect2:
		errors.append("%s.rect must be Rect2" % prefix)
	elif not _rect_inside_world_pixels(volume["rect"]):
		errors.append("%s.rect is outside world bounds" % prefix)

	return errors
