class_name MapSceneBootstrap
extends RefCounted

const DOOR_SCENE := preload("res://scenes/elements/door.tscn")
const MINIMAP_HUD_SCENE := preload("res://scenes/elements/minimap_hud.tscn")
const GridRegionMergerScript := preload("res://scripts/map/grid_region_merger.gd")
## WB-08b: marks a package boundary shape that only seals a streamable seam.
const SEAM_GATE_META := &"seam_gate_transition_id"

## Wires declarative maps into playable scenes without legacy TileSets.


static func assemble(
	root: Node2D,
	definition: MapDefinition,
	actors: Node2D,
	map_root: Node2D = null,
	visual_target: StringName = MapVisualStyle.TARGET_CLEAN_PAINTED,
	time_of_day: StringName = MapVisualStyle.TIME_DAY
) -> Dictionary:
	var host := map_root if map_root != null else root
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var assembled := MapAssembler.assemble(
		host, definition, grid, actors, visual_target, time_of_day
	)
	var terrain := assembled.get("terrain") as MapTerrainRenderer
	var object_streamer := assembled.get("object_streamer") as MapObjectChunkStreamer
	var terrain_focus := actors.find_child("Player", true, false) as Node2D
	if terrain != null and terrain_focus != null:
		terrain.follow(terrain_focus)
		if object_streamer != null:
			object_streamer.update_active_chunks(terrain.loaded_chunk_coordinates())
	# WB-07: behind the async-assembly flag the bake runs on a worker thread and
	# publishes atomically; default off keeps the synchronous region.
	var nav := (
		MapNavBuilder.create_navigation_region_threaded(definition, grid)
		if MapView3D.Assembly.enabled()
		else MapNavBuilder.create_navigation_region(definition, grid)
	)
	nav.name = "Navigation"
	host.add_child(nav)
	var world_bounds := _create_world_bounds(definition, host)
	var water_blocks := _create_water_blocks(definition, grid, host)
	var relief_blocks := _create_relief_blocks(definition, host)
	var excluded_blocks := _create_excluded_area_blocks(definition, grid, host)
	var boat_blocks := _create_boat_blocks(definition, host)

	var gameplay := Node2D.new()
	gameplay.name = "Gameplay"
	host.add_child(gameplay)

	var doors := _create_doors(definition, gameplay)
	var anchors := _create_anchor_markers(definition, gameplay)
	var fades := _create_fade_areas(definition, gameplay)
	var location_hud := _create_minimap_hud(definition, grid, actors, root)

	return {
		"grid": grid,
		"assembled": assembled,
		"navigation": nav,
		"world_bounds": world_bounds,
		"water_blocks": water_blocks,
		"relief_blocks": relief_blocks,
		"excluded_blocks": excluded_blocks,
		"boat_blocks": boat_blocks,
		"doors": doors,
		"anchors": anchors,
		"fades": fades,
		"location_hud": location_hud,
		"minimap_hud": location_hud,
		"definition": definition,
	}


## WB-06: the disposable logic package WorldHost mounts under LogicLocations.
## Same collision, navigation and gameplay nodes as assemble(), built in the same
## order by the same helpers, but no player, no minimap HUD and no flat 2D map:
## those are host globals (ADR 0019 section 2). The navigation region is left on
## the default map; WorldHost.mount_location() moves it onto the one host map.
## Doors and anchors carry a `stable_handle` so the host rejects duplicates.
static func assemble_location_package(
	definition: MapDefinition, grid: MapTerrainGrid = null
) -> Node2D:
	var built_grid := grid if grid != null else MapBuilder.build(definition)
	var package := Node2D.new()
	package.name = "LocationPackage_%s" % String(definition.map_id)
	var nav := MapNavBuilder.create_navigation_region(definition, built_grid)
	nav.name = "Navigation"
	package.add_child(nav)
	_split_seam_gates(definition, _create_world_bounds(definition, package))
	_create_water_blocks(definition, built_grid, package)
	_create_relief_blocks(definition, package)
	_create_excluded_area_blocks(definition, built_grid, package)
	_create_boat_blocks(definition, package)

	var gameplay := Node2D.new()
	gameplay.name = "Gameplay"
	package.add_child(gameplay)
	for door in _create_doors(definition, gameplay):
		var transition_id := String(door.name).trim_prefix("door_")
		door.set_meta(&"stable_handle", _package_handle(definition, "transition", transition_id))
	for marker in _create_anchor_markers(definition, gameplay):
		marker.set_meta(&"stable_handle", _package_handle(definition, "anchor", String(marker.name)))
	_create_fade_areas(definition, gameplay)
	return package


## Location-scoped handle, the same {location_id, object_id} identity
## MapStableStateStore persists. The kind prefix keeps a transition and an anchor
## that share an authored id from colliding inside one location.
static func _package_handle(
	definition: MapDefinition, kind: String, object_id: String
) -> Dictionary:
	return {
		"location_id": String(definition.map_id),
		"object_id": "%s:%s" % [kind, object_id],
	}


static func configure_player_movement(player: Node, bootstrap: Dictionary) -> void:
	if player == null or not player.has_method("configure_map_movement"):
		return
	var definition := bootstrap.get("definition") as MapDefinition
	var grid := bootstrap.get("grid") as MapTerrainGrid
	if definition != null and grid != null:
		player.configure_map_movement(definition, grid)


## Thin wrapper so map tests can place without depending on scene scripts.
## Prefer DoorNavigator.place_player from playable scenes (autoload, always live).
static func place_player(level: Node, player: Node2D, definition: MapDefinition) -> bool:
	var default_spawn := definition.player_spawn if definition != null else Vector2.ZERO
	return DoorNavigator.place_player(level, player, default_spawn)


static func wire_player(
	player: Node,
	definition: MapDefinition,
	navigation: NavigationRegion2D,
	grid: MapTerrainGrid = null
) -> void:
	if player == null:
		return
	player.global_position = definition.player_spawn
	var terrain := _terrain_renderer_for_player(player)
	if terrain != null:
		terrain.follow(player as Node2D)
	if player.has_method("configure_map_movement") and grid != null:
		player.configure_map_movement(definition, grid)
	if player.has_method("set_navigation_map") and navigation != null:
		player.set_navigation_map(navigation.get_navigation_map())
	elif player.has_node("navigation_agent"):
		var agent: NavigationAgent2D = player.get_node("navigation_agent")
		if agent != null and navigation != null:
			agent.set_navigation_map(navigation.get_navigation_map())


static func _terrain_renderer_for_player(player: Node) -> MapTerrainRenderer:
	var root := player.get_tree().current_scene if player.is_inside_tree() else null
	if root == null:
		return null
	return root.find_child("Terrain", true, false) as MapTerrainRenderer


static func _create_doors(definition: MapDefinition, parent: Node2D) -> Array[Area2D]:
	var doors: Array[Area2D] = []
	var doors_root := Node2D.new()
	doors_root.name = "Doors"
	parent.add_child(doors_root)

	for transition in definition.transitions:
		var door: Area2D = DOOR_SCENE.instantiate()
		var transition_id := StringName(String(transition.get("id", "")))
		door.name = "door_%s" % String(transition_id)
		var rect: Rect2 = transition["rect"]
		door.position = rect.get_center()
		if transition.has("spawn_id"):
			door.spawn_id = transition["spawn_id"]
		var destination_scene_id := String(transition.get("destination_scene_id", ""))
		if destination_scene_id.is_empty():
			door.transition_enabled = false
		else:
			door.destination_scene_id = transition["destination_scene_id"]
			if transition.has("destination_spawn_id"):
				door.destination_spawn_id = transition["destination_spawn_id"]

		var collision := door.get_node("CollisionShape2D") as CollisionShape2D
		if collision != null:
			var shape := collision.shape as RectangleShape2D
			if shape == null:
				shape = RectangleShape2D.new()
				collision.shape = shape
			shape.size = Vector2(maxf(32.0, rect.size.x), maxf(32.0, rect.size.y))
		var spawn := door.get_node("Spawn") as Marker2D
		if spawn != null and transition.has("spawn_offset"):
			spawn.position = transition["spawn_offset"]
		doors_root.add_child(door)
		doors.append(door)
	return doors


static func _create_minimap_hud(
	definition: MapDefinition, grid: MapTerrainGrid, actors: Node2D, root: Node2D
) -> MinimapHud:
	var player := actors.find_child("Player", true, false) as Node2D
	var hud := MINIMAP_HUD_SCENE.instantiate() as MinimapHud
	root.add_child(hud)
	hud.configure(definition, grid, player)
	return hud


## Navigation constrains click targets, but keyboard input drives CharacterBody2D
## directly. Thin static walls keep both input methods inside the authored map;
## transition triggers sit just inside these walls and fire before contact.
## Keyboard movement bypasses NavigationAgent2D, so water cells need the same
## physical blocking as buildings. ADR 0021: the player may enter every water
## terrain except rivers, so the full water body sits on CollisionLayers.WATER
## (NPCs mask it, the player does not) and river cells get a second solid body on
## the world layer that still stops the player.
static func _create_water_blocks(
	definition: MapDefinition, grid: MapTerrainGrid, parent: Node2D
) -> StaticBody2D:
	var body := _water_body(
		definition, "WaterBlocks", CollisionLayers.WATER,
		func(cell: Vector2i) -> bool: return MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell))
	)
	if body == null:
		return null
	parent.add_child(body)
	var barrier := _water_body(
		definition, "WaterBarrier", CollisionLayers.WORLD,
		func(cell: Vector2i) -> bool:
			return PlayerWaterTraversal.BLOCKING_TERRAINS.has(grid.get_terrain(cell))
	)
	if barrier != null:
		parent.add_child(barrier)
	return body


static func _water_body(
	definition: MapDefinition, body_name: String, layer: int, matches: Callable
) -> StaticBody2D:
	var water_rects := GridRegionMergerScript.merge_matching_cells(definition.size_cells, matches)
	if water_rects.is_empty():
		return null
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = layer
	body.add_to_group(&"map_water_collision")
	for index in water_rects.size():
		var world_rect := definition.cell_rect_to_world_rect(water_rects[index])
		var collision := CollisionShape2D.new()
		collision.name = "Water%d" % index
		var shape := RectangleShape2D.new()
		shape.size = world_rect.size
		collision.shape = shape
		collision.position = world_rect.get_center()
		body.add_child(collision)
	return body


## ADR 0021 lets the player wade and swim, so a moored boat needs its own solid
## body or Kalev walks straight through the hull. One capsule per boat prop
## matches the 3D hull plan (same centre, visual offset and yaw as
## MapViewMeshBuilderPropModels.build_prop) on the world layer, which both the
## player and NPCs mask. Navigation is unchanged: boats sit on water cells that
## click-to-move already routes around or onto as authored.
static func _create_boat_blocks(definition: MapDefinition, parent: Node2D) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "BoatBlocks"
	body.collision_layer = CollisionLayers.WORLD
	body.add_to_group(&"map_boat_collision")
	var cell := float(definition.cell_size)
	for prop in definition.props:
		var kind: StringName = prop.get("kind", &"")
		if not kind in MapTypes.BOAT_PROP_KINDS:
			continue
		var half := (
			Vector2(MapViewFishingBoatBuilder.HULL_HALF_LENGTH, MapViewFishingBoatBuilder.HULL_HALF_BEAM)
			if kind == MapTypes.PROP_KIND_FISHING_BOAT
			else Vector2(
				MapViewMerchantBoatBuilder.HULL_HALF_LENGTH, MapViewMerchantBoatBuilder.HULL_HALF_BEAM
			)
		) * cell
		var yaw := MapTypes.prop_facing_yaw(prop)
		var footprint: Variant = prop.get("footprint")
		if footprint is Rect2 and footprint.size.y > footprint.size.x:
			yaw += PI * 0.5
		var shape := CapsuleShape2D.new()
		shape.radius = half.y
		shape.height = half.x * 2.0
		var collision := CollisionShape2D.new()
		collision.name = "Boat_%s" % String(prop["id"])
		collision.shape = shape
		# build_prop applies visual_offset_px.y as height, so only x moves the hull.
		var offset: Vector2 = prop.get("visual_offset_px", Vector2.ZERO)
		collision.position = (prop["position"] as Vector2) + Vector2(offset.x, 0.0)
		# 3D yaw turns hull +X toward (cos, -sin) on the logic plane; the capsule's
		# long axis is its local +Y, hence the quarter-turn back.
		collision.rotation = Vector2(cos(yaw), -sin(yaw)).angle() - PI * 0.5
		body.add_child(collision)
	if body.get_child_count() == 0:
		body.free()
		return null
	parent.add_child(body)
	return body


## ADR 0023 (WB-03): gameplay collision stays on the 2D plane, so the ground
## follows the compiled field at one-cell resolution: every cell steeper than the
## walkable slope (and both sides of a relief_cliff) is a physical block, the same
## rects MapNavBuilder obstructs, so keyboard/gamepad movement cannot climb a bank
## that click-to-move routes around. Returns null on maps whose ground cannot block.
static func _create_relief_blocks(definition: MapDefinition, parent: Node2D) -> StaticBody2D:
	var relief_rects := MapNavBuilder.relief_obstruction_rects(definition)
	if relief_rects.is_empty():
		return null
	var body := StaticBody2D.new()
	body.name = "ReliefBlocks"
	body.add_to_group(&"map_relief_collision")
	for index in relief_rects.size():
		var world_rect := definition.cell_rect_to_world_rect(relief_rects[index])
		var collision := CollisionShape2D.new()
		collision.name = "Relief%d" % index
		var shape := RectangleShape2D.new()
		shape.size = world_rect.size
		collision.shape = shape
		collision.position = world_rect.get_center()
		body.add_child(collision)
	parent.add_child(body)
	return body


## Excluded areas already remove cells from navigation. Mirror them as physical
## world blocks so direct CharacterBody2D movement cannot walk through the same
## authored obstruction (for example, a bed footprint).
static func _create_excluded_area_blocks(
	definition: MapDefinition, grid: MapTerrainGrid, parent: Node2D
) -> StaticBody2D:
	if definition.excluded_areas.is_empty():
		return null
	var body := StaticBody2D.new()
	body.name = "ExcludedAreaBlocks"
	body.add_to_group(&"map_excluded_collision")
	var rects := _excluded_collision_rects(definition, grid)
	for index in rects.size():
		var world_rect := definition.cell_rect_to_world_rect(rects[index])
		var collision := CollisionShape2D.new()
		collision.name = "Excluded%d" % index
		var shape := RectangleShape2D.new()
		shape.size = world_rect.size
		collision.shape = shape
		collision.position = world_rect.get_center()
		body.add_child(collision)
	parent.add_child(body)
	return body


## ADR 0021: harbour maps author `exclude` rects over open water to keep the player on
## the shore. Those cells must not wall off the swimmer, so traversable water is cut
## out of the physical player blocks (WaterBlocks still stops NPCs there, and
## navigation, walkability and every audit keep reading the untouched rects). Maps
## whose exclusions do not overlap traversable water keep their rects unchanged.
static func _excluded_collision_rects(
	definition: MapDefinition, grid: MapTerrainGrid
) -> Array[Rect2i]:
	var overlaps_water := false
	for rect in definition.excluded_areas:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if PlayerWaterTraversal.is_traversable_terrain(grid.get_terrain(Vector2i(x, y))):
					overlaps_water = true
					break
			if overlaps_water:
				break
		if overlaps_water:
			break
	if not overlaps_water:
		return definition.excluded_areas.duplicate()
	var excluded := {}
	for rect in definition.excluded_areas:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if not PlayerWaterTraversal.is_traversable_terrain(grid.get_terrain(cell)):
					excluded[cell] = true
	return GridRegionMergerScript.merge_matching_cells(
		definition.size_cells, func(cell: Vector2i) -> bool: return excluded.has(cell)
	)


static func _create_world_bounds(definition: MapDefinition, parent: Node2D) -> StaticBody2D:
	var bounds := StaticBody2D.new()
	bounds.name = "WorldBounds"
	bounds.add_to_group(&"map_world_bounds")
	var world := definition.world_size()
	var thickness := float(definition.cell_size)
	var walls := [
		{
			"position": Vector2(world.x * 0.5, -thickness * 0.5),
			"size": Vector2(world.x + thickness * 2.0, thickness)
		},
		{
			"position": Vector2(world.x * 0.5, world.y + thickness * 0.5),
			"size": Vector2(world.x + thickness * 2.0, thickness)
		},
		{"position": Vector2(-thickness * 0.5, world.y * 0.5), "size": Vector2(thickness, world.y)},
		{
			"position": Vector2(world.x + thickness * 0.5, world.y * 0.5),
			"size": Vector2(thickness, world.y)
		},
	]
	for index in walls.size():
		var collision := CollisionShape2D.new()
		collision.name = "Boundary%d" % index
		collision.position = walls[index]["position"]
		var shape := RectangleShape2D.new()
		shape.size = walls[index]["size"]
		collision.shape = shape
		bounds.add_child(collision)
	parent.add_child(bounds)
	return bounds


## WB-08b: in a location package every wall that an edge transition touches is
## split so the transition span becomes its own `SeamGate_<transition_id>` shape
## (meta SEAM_GATE_META). Gates start enabled, so the union still seals the map
## exactly like assemble(); the WorldHost streaming driver disables a gate only
## while both sides of its seam are resident, which lets keyboard and gamepad
## movement walk across. Wall order Boundary0..3 is north, south, west, east.
static func _split_seam_gates(definition: MapDefinition, bounds: StaticBody2D) -> void:
	var world := definition.world_size()
	var thickness := float(definition.cell_size)
	var gaps_by_wall := {0: [], 1: [], 2: [], 3: []}
	for transition in definition.transitions:
		var rect: Rect2 = transition.get("rect", Rect2())
		var wall := _edge_wall_index(rect, world, thickness)
		if wall < 0:
			continue
		var along := rect.position.x if wall < 2 else rect.position.y
		var length := rect.size.x if wall < 2 else rect.size.y
		gaps_by_wall[wall].append(
			{"id": String(transition.get("id", "")), "from": along, "to": along + length}
		)
	for wall in gaps_by_wall.keys():
		var gaps: Array = gaps_by_wall[wall]
		if gaps.is_empty():
			continue
		gaps.sort_custom(
			func(left: Dictionary, right: Dictionary) -> bool: return left["from"] < right["from"]
		)
		var shape_node := bounds.get_node("Boundary%d" % wall) as CollisionShape2D
		var size := (shape_node.shape as RectangleShape2D).size
		var horizontal := int(wall) < 2
		var length := size.x if horizontal else size.y
		var middle := shape_node.position.x if horizontal else shape_node.position.y
		var start := middle - length * 0.5
		var end := start + length
		var fixed := shape_node.position.y if horizontal else shape_node.position.x
		bounds.remove_child(shape_node)
		shape_node.free()
		var cursor := start
		var piece := 0
		for gap: Dictionary in gaps:
			var gap_from := clampf(float(gap["from"]), cursor, end)
			var gap_to := clampf(float(gap["to"]), gap_from, end)
			if gap_from > cursor:
				_add_wall_piece(
					bounds, _wall_piece_name(wall, piece), horizontal, fixed, cursor, gap_from, thickness
				)
				piece += 1
			if gap_to > gap_from:
				var gate := _add_wall_piece(
					bounds, "SeamGate_%s" % gap["id"], horizontal, fixed, gap_from, gap_to, thickness
				)
				gate.set_meta(SEAM_GATE_META, StringName(gap["id"]))
			cursor = maxf(cursor, gap_to)
		if end > cursor:
			_add_wall_piece(
				bounds, _wall_piece_name(wall, piece), horizontal, fixed, cursor, end, thickness
			)


## Index of the boundary wall a transition rect lies against (within one cell),
## or -1 for interior doors such as the forge entrance.
static func _edge_wall_index(rect: Rect2, world: Vector2, thickness: float) -> int:
	if rect.size == Vector2.ZERO:
		return -1
	var distances := [rect.position.y, world.y - rect.end.y, rect.position.x, world.x - rect.end.x]
	var best := -1
	for index in distances.size():
		if float(distances[index]) <= thickness and (best < 0 or distances[index] < distances[best]):
			best = index
	return best


static func _wall_piece_name(wall: int, piece: int) -> String:
	return "Boundary%d" % wall if piece == 0 else "Boundary%d_%d" % [wall, piece]


static func _add_wall_piece(
	bounds: StaticBody2D,
	piece_name: String,
	horizontal: bool,
	fixed: float,
	from: float,
	to: float,
	thickness: float
) -> CollisionShape2D:
	var collision := CollisionShape2D.new()
	collision.name = piece_name
	var shape := RectangleShape2D.new()
	shape.size = Vector2(to - from, thickness) if horizontal else Vector2(thickness, to - from)
	collision.shape = shape
	var middle := (from + to) * 0.5
	collision.position = Vector2(middle, fixed) if horizontal else Vector2(fixed, middle)
	bounds.add_child(collision)
	return collision


static func _create_anchor_markers(definition: MapDefinition, parent: Node2D) -> Array[Marker2D]:
	var anchors: Array[Marker2D] = []
	var root := Node2D.new()
	root.name = "InteractionAnchors"
	parent.add_child(root)

	for anchor in definition.interaction_anchors:
		var marker := Marker2D.new()
		marker.name = String(anchor["id"])
		marker.position = anchor["position"]
		marker.set_meta("anchor_id", anchor["id"])
		root.add_child(marker)
		anchors.append(marker)
	return anchors


static func _create_fade_areas(definition: MapDefinition, parent: Node2D) -> Array[Area2D]:
	var fades: Array[Area2D] = []
	if definition.fade_volumes.is_empty():
		return fades

	var root := Node2D.new()
	root.name = "FadeVolumes"
	parent.add_child(root)

	for index in definition.fade_volumes.size():
		var volume: Dictionary = definition.fade_volumes[index]
		var rect: Rect2 = volume["rect"]
		var area := Area2D.new()
		area.name = "FadeArea_%d" % index
		area.monitorable = false
		area.monitoring = false
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		collision.position = rect.get_center()
		area.add_child(collision)
		root.add_child(area)
		fades.append(area)
	return fades
