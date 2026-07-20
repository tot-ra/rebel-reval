class_name MapSceneBootstrap
extends RefCounted

const DOOR_SCENE := preload("res://scenes/elements/door.tscn")
const MINIMAP_HUD_SCENE := preload("res://scenes/elements/minimap_hud.tscn")
const GAMEPLAY_HELP_HUD_SCENE := preload("res://scenes/elements/gameplay_help_hud.tscn")
const GridRegionMergerScript := preload("res://scripts/map/grid_region_merger.gd")

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
	var assembled := MapAssembler.assemble(host, definition, grid, actors, visual_target, time_of_day)
	var terrain := assembled.get("terrain") as MapTerrainRenderer
	var object_streamer := assembled.get("object_streamer") as MapObjectChunkStreamer
	var terrain_focus := actors.find_child("Player", true, false) as Node2D
	if terrain != null and terrain_focus != null:
		terrain.follow(terrain_focus)
		if object_streamer != null:
			object_streamer.update_active_chunks(terrain.loaded_chunk_coordinates())
	var nav := MapNavBuilder.create_navigation_region(definition, grid)
	nav.name = "Navigation"
	host.add_child(nav)
	var world_bounds := _create_world_bounds(definition, host)
	var water_blocks := _create_water_blocks(definition, grid, host)

	var gameplay := Node2D.new()
	gameplay.name = "Gameplay"
	host.add_child(gameplay)

	var doors := _create_doors(definition, gameplay)
	var anchors := _create_anchor_markers(definition, gameplay)
	var fades := _create_fade_areas(definition, gameplay)
	var location_hud := _create_minimap_hud(definition, grid, actors, root)
	var gameplay_help_hud := _create_gameplay_help_hud(root)

	return {
		"grid": grid,
		"assembled": assembled,
		"navigation": nav,
		"world_bounds": world_bounds,
		"water_blocks": water_blocks,
		"doors": doors,
		"anchors": anchors,
		"fades": fades,
		"location_hud": location_hud,
		"minimap_hud": location_hud,
		"gameplay_help_hud": gameplay_help_hud,
		"definition": definition,
	}


static func configure_player_movement(player: Node, bootstrap: Dictionary) -> void:
	if player == null or not player.has_method("configure_map_movement"):
		return
	var definition := bootstrap.get("definition") as MapDefinition
	var grid := bootstrap.get("grid") as MapTerrainGrid
	if definition != null and grid != null:
		player.configure_map_movement(definition, grid)


## Place at a pending door spawn when set; otherwise use authored player_spawn.
## WHY: spawn_player_at_pending_spawn clears pending IDs on success, so scenes must
## not treat an empty pending_spawn_id as "use default spawn" after a door transition.
static func place_player(level: Node, player: Node2D, definition: MapDefinition) -> bool:
	if DoorNavigator.spawn_player_at_pending_spawn(level):
		return true
	if player != null and definition != null:
		player.global_position = definition.player_spawn
	return false


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
	definition: MapDefinition,
	grid: MapTerrainGrid,
	actors: Node2D,
	root: Node2D
) -> MinimapHud:
	var player := actors.find_child("Player", true, false) as Node2D
	var hud := MINIMAP_HUD_SCENE.instantiate() as MinimapHud
	root.add_child(hud)
	hud.configure(definition, grid, player)
	return hud


static func _create_gameplay_help_hud(root: Node2D) -> GameplayHelpHud:
	var hud := GAMEPLAY_HELP_HUD_SCENE.instantiate() as GameplayHelpHud
	root.add_child(hud)
	return hud


## Navigation constrains click targets, but keyboard input drives CharacterBody2D
## directly. Thin static walls keep both input methods inside the authored map;
## transition triggers sit just inside these walls and fire before contact.
## Keyboard movement bypasses NavigationAgent2D, so water cells need the same
## physical blocking as buildings until a traversal mechanic ships.
static func _create_water_blocks(definition: MapDefinition, grid: MapTerrainGrid, parent: Node2D) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "WaterBlocks"
	body.add_to_group(&"map_water_collision")
	var water_rects := GridRegionMergerScript.merge_matching_cells(
		definition.size_cells,
		func(cell: Vector2i) -> bool:
			return MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell))
	)
	for index in water_rects.size():
		var world_rect := definition.cell_rect_to_world_rect(water_rects[index])
		var collision := CollisionShape2D.new()
		collision.name = "Water%d" % index
		var shape := RectangleShape2D.new()
		shape.size = world_rect.size
		collision.shape = shape
		collision.position = world_rect.get_center()
		body.add_child(collision)
	if water_rects.is_empty():
		body.free()
		return null
	parent.add_child(body)
	return body


static func _create_world_bounds(definition: MapDefinition, parent: Node2D) -> StaticBody2D:
	var bounds := StaticBody2D.new()
	bounds.name = "WorldBounds"
	bounds.add_to_group(&"map_world_bounds")
	var world := definition.world_size()
	var thickness := float(definition.cell_size)
	var walls := [
		{"position": Vector2(world.x * 0.5, -thickness * 0.5), "size": Vector2(world.x + thickness * 2.0, thickness)},
		{"position": Vector2(world.x * 0.5, world.y + thickness * 0.5), "size": Vector2(world.x + thickness * 2.0, thickness)},
		{"position": Vector2(-thickness * 0.5, world.y * 0.5), "size": Vector2(thickness, world.y)},
		{"position": Vector2(world.x + thickness * 0.5, world.y * 0.5), "size": Vector2(thickness, world.y)},
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
