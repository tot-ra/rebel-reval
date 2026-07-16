class_name MapSceneBootstrap
extends RefCounted

const DOOR_SCENE := preload("res://scenes/elements/door.tscn")

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
	var nav := MapNavBuilder.create_navigation_region(definition, grid)
	nav.name = "Navigation"
	host.add_child(nav)

	var gameplay := Node2D.new()
	gameplay.name = "Gameplay"
	host.add_child(gameplay)

	var doors := _create_doors(definition, gameplay)
	var anchors := _create_anchor_markers(definition, gameplay)
	var fades := _create_fade_areas(definition, gameplay)

	return {
		"grid": grid,
		"assembled": assembled,
		"navigation": nav,
		"doors": doors,
		"anchors": anchors,
		"fades": fades,
		"definition": definition,
	}


static func wire_player(player: Node, definition: MapDefinition, navigation: NavigationRegion2D) -> void:
	if player == null:
		return
	player.global_position = definition.player_spawn
	if player.has_method("set_navigation_map") and navigation != null:
		player.set_navigation_map(navigation.get_navigation_map())
	elif player.has_node("navigation_agent"):
		var agent: NavigationAgent2D = player.get_node("navigation_agent")
		if agent != null and navigation != null:
			agent.set_navigation_map(navigation.get_navigation_map())


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
