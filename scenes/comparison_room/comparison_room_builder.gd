class_name ComparisonRoomBuilder
extends RefCounted

## Builds the shared P0-035 comparison-room geometry and HUD nodes.

const SpecsScript := preload("res://scenes/comparison_room/comparison_room_specs.gd")


static func build_room(
	host: Node2D,
	projection,
	variant_id: String,
	variant_title: String,
	doorway_entered: Callable,
	foreground_entered: Callable,
	foreground_exited: Callable
) -> Dictionary:
	host.name = "P0_035_%s" % variant_id

	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.position = ComparisonRoomProjection.ROOM_CENTER
	camera.enabled = true
	host.add_child(camera)

	_add_surface(host, projection, "Floor", Vector2.ZERO, SpecsScript.ROOM_SIZE, Color(0.14, 0.15, 0.17, 1.0), 0)
	_add_surface(host, projection, "WalkablePlane", Vector2(120, 110), Vector2(1040, 500), Color(0.28, 0.29, 0.31, 1.0), 1)
	_add_surface(host, projection, "DoorThresholdPaint", Vector2(720, 100), Vector2(110, 70), Color(0.46, 0.40, 0.30, 1.0), 2)
	_add_surface(host, projection, "ForegroundFadePaint", Vector2(860, 445), Vector2(250, 145), Color(0.23, 0.25, 0.27, 1.0), 2)

	for data in SpecsScript.WALL_SPECS:
		var wall_color := Color(0.12, 0.12, 0.13, 1.0)
		if String(data["name"]) == "CollisionTable":
			wall_color = Color(0.16, 0.13, 0.10, 1.0)
		_add_wall(host, projection, String(data["name"]), data["center"], data["size"], wall_color)

	var doorway := _create_doorway(host, projection, doorway_entered)
	var foreground := _create_foreground_fade(host, projection, foreground_entered, foreground_exited)

	var actors := Node2D.new()
	actors.name = "YSortActors"
	actors.y_sort_enabled = true
	host.add_child(actors)

	var player := _create_body(actors, projection, "Kalev", Vector2(225, 430), Color(0.21, 0.52, 0.92, 1.0), false)
	player.name = "PlayerGreyboxBody"
	player.add_to_group("p0_035_comparison_player")

	var dialogue_npc: CharacterBody2D = null
	var combat_npc: CharacterBody2D = null
	for data in SpecsScript.NPC_SPECS:
		var npc := _create_body(actors, projection, String(data["name"]), data["position"], data["color"], true)
		npc.set_meta("comparison_role", data["role"])
		if String(data["role"]) == "dialogue":
			dialogue_npc = npc
		elif String(data["role"]) == "combat":
			combat_npc = npc

	_create_world_labels(host, projection, variant_title)
	var ui := _create_ui(host)

	return {
		"actors": actors,
		"player": player,
		"dialogue_npc": dialogue_npc,
		"combat_npc": combat_npc,
		"foreground_wall": foreground["foreground_wall"],
		"foreground_probe": foreground["foreground_probe"],
		"status_label": ui["status_label"],
		"dialogue_box": ui["dialogue_box"],
		"dialogue_label": ui["dialogue_label"],
		"combat_label": ui["combat_label"],
		"facing_label": ui["facing_label"],
		"doorway": doorway,
	}


static func _add_surface(
	parent: Node,
	projection,
	node_name: String,
	top_left: Vector2,
	size: Vector2,
	color: Color,
	layer: int
) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.polygon = projection.projected_rect_points(top_left + size * 0.5, size)
	polygon.color = color
	polygon.z_index = layer
	parent.add_child(polygon)
	return polygon


static func _add_wall(
	host: Node2D,
	projection,
	node_name: String,
	center: Vector2,
	size: Vector2,
	color: Color
) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.name = node_name
	wall.position = projection.project_point(center)
	host.add_child(wall)

	var points := projection.projected_rect_offsets(center, size)
	var shape := ConvexPolygonShape2D.new()
	shape.points = points
	var collision := CollisionShape2D.new()
	collision.shape = shape
	wall.add_child(collision)

	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = points
	visual.color = color
	visual.z_index = 3
	wall.add_child(visual)
	return wall


static func _create_body(
	actors: Node2D,
	projection,
	label_text: String,
	logical_position: Vector2,
	color: Color,
	is_npc: bool
) -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.name = label_text.replace(" ", "") + "Body"
	body.position = projection.project_point(logical_position)
	body.set_meta("display_name", label_text)
	body.set_meta("logical_spawn", logical_position)
	if is_npc:
		CollisionLayers.apply_npc(body)
	else:
		CollisionLayers.apply_player(body)
	actors.add_child(body)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(34, 42)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.position = Vector2(0, -21)
	collision.shape = shape
	body.add_child(collision)

	_add_actor_rect(body, "Shadow", Vector2(-20, -7), Vector2(40, 12), Color(0, 0, 0, 0.28), -1)
	_add_actor_rect(body, "Body", Vector2(-16, -47), Vector2(32, 44), color, 1)
	_add_actor_rect(body, "Head", Vector2(-11, -64), Vector2(22, 20), color.lightened(0.18), 2)

	var label := Label.new()
	label.name = "NameLabel"
	label.text = label_text
	label.position = Vector2(-48, -88)
	label.size = Vector2(96, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(label)

	if is_npc:
		body.add_to_group("p0_035_comparison_npc")
	return body


static func _add_actor_rect(
	parent: Node,
	node_name: String,
	position: Vector2,
	size: Vector2,
	color: Color,
	layer: int
) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.position = position
	rect.size = size
	rect.color = color
	rect.z_index = layer
	parent.add_child(rect)
	return rect


static func _create_doorway(host: Node2D, projection, doorway_entered: Callable) -> Area2D:
	var center := Vector2(775, 125)
	var size := Vector2(95, 105)
	var door := Area2D.new()
	door.name = "DoorwayProbe"
	door.position = projection.project_point(center)
	door.collision_layer = 0
	door.collision_mask = CollisionLayers.PLAYER
	host.add_child(door)

	var points := projection.projected_rect_offsets(center, size)
	var shape := ConvexPolygonShape2D.new()
	shape.points = points
	var collision := CollisionShape2D.new()
	collision.shape = shape
	door.add_child(collision)

	var visual := Polygon2D.new()
	visual.name = "DoorwayVisual"
	visual.polygon = points
	visual.color = Color(0.58, 0.50, 0.35, 0.55)
	visual.z_index = 4
	door.add_child(visual)
	door.body_entered.connect(doorway_entered)
	return door


static func _create_foreground_fade(
	host: Node2D,
	projection,
	foreground_entered: Callable,
	foreground_exited: Callable
) -> Dictionary:
	var foreground_wall := _add_surface(
		host,
		projection,
		"ForegroundOccluder",
		Vector2(850, 385),
		Vector2(280, 205),
		Color(0.08, 0.10, 0.11, 0.92),
		20
	)

	var center := Vector2(990, 555)
	var size := Vector2(300, 140)
	var foreground_probe := Area2D.new()
	foreground_probe.name = "ForegroundFadeProbe"
	foreground_probe.position = projection.project_point(center)
	foreground_probe.collision_layer = 0
	foreground_probe.collision_mask = CollisionLayers.PLAYER
	host.add_child(foreground_probe)

	var shape := ConvexPolygonShape2D.new()
	shape.points = projection.projected_rect_offsets(center, size)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	foreground_probe.add_child(collision)
	foreground_probe.body_entered.connect(foreground_entered)
	foreground_probe.body_exited.connect(foreground_exited)

	return {
		"foreground_wall": foreground_wall,
		"foreground_probe": foreground_probe,
	}


static func _create_world_labels(host: Node2D, projection, variant_title: String) -> void:
	_add_world_label(host, projection, "ProjectionLabel", variant_title, Vector2(420, 172), Vector2(440, 36), 24)
	_add_world_label(host, projection, "DoorLabel", "shared doorway", Vector2(705, 65), Vector2(180, 28), 8)
	_add_world_label(host, projection, "ForegroundLabel", "shared foreground fade", Vector2(850, 410), Vector2(260, 28), 21)


static func _add_world_label(
	host: Node2D,
	projection,
	node_name: String,
	text: String,
	logical_position: Vector2,
	size: Vector2,
	layer: int
) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = projection.project_point(logical_position) - size * 0.5
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = layer
	host.add_child(label)
	return label


static func _create_ui(host: Node2D) -> Dictionary:
	var canvas := CanvasLayer.new()
	canvas.name = "ComparisonHUD"
	host.add_child(canvas)

	var panel := ColorRect.new()
	panel.name = "InstructionPanel"
	panel.position = Vector2(20, 20)
	panel.size = Vector2(760, 128)
	panel.color = Color(0.04, 0.04, 0.05, 0.84)
	canvas.add_child(panel)

	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.position = Vector2(34, 30)
	status_label.size = Vector2(730, 102)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(status_label)

	var dialogue_box := ColorRect.new()
	dialogue_box.name = "DialogueBox"
	dialogue_box.position = Vector2(330, 590)
	dialogue_box.size = Vector2(620, 96)
	dialogue_box.color = Color(0.06, 0.05, 0.09, 0.88)
	dialogue_box.visible = false
	canvas.add_child(dialogue_box)

	var dialogue_label := Label.new()
	dialogue_label.name = "DialogueLabel"
	dialogue_label.position = Vector2(348, 608)
	dialogue_label.size = Vector2(584, 62)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(dialogue_label)

	var combat_label := Label.new()
	combat_label.name = "CombatLabel"
	combat_label.position = Vector2(980, 26)
	combat_label.size = Vector2(270, 90)
	canvas.add_child(combat_label)

	var facing_label := Label.new()
	facing_label.name = "FacingLabel"
	facing_label.position = Vector2(980, 118)
	facing_label.size = Vector2(280, 48)
	canvas.add_child(facing_label)

	return {
		"status_label": status_label,
		"dialogue_box": dialogue_box,
		"dialogue_label": dialogue_label,
		"combat_label": combat_label,
		"facing_label": facing_label,
	}
