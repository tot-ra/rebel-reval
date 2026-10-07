extends Node

## Frame-cost probe for the seamless city (ADR 0031): stands Kalev at a few
## busy spots and measures rendered-frame time, then removes one layer at a
## time (people, chimney smoke, wall-foot weeds, ships, grass, vegetation) to
## show what each costs. Host scene so autoloads resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/profile_reval_city.tscn

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const SPOTS: Array[String] = ["poi.forum", "gate.viru", "poi.granary.pikk"]
const SAMPLE_SEC := 2.0

var _city: Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_city = SCENE.instantiate()
	get_tree().root.add_child(_city)
	for i in 30:
		await get_tree().process_frame
	await _measure("all layers")
	if OS.get_cmdline_user_args().has("--quick"):
		var t0 := Time.get_ticks_usec()
		for i in 20:
			_city._process(0.016)
		print("city _process: %.2f ms" % ((Time.get_ticks_usec() - t0) / 20000.0))
		var rt: MapViewRuntime = _city.runtime
		var parts := {
			"advance_cycle":
			## Frame-cost probe for the seamless city (ADR 0031): stands Kalev at a few
			## busy spots and measures rendered-frame time, then removes one layer at a
			## time (people, chimney smoke, wall-foot weeds, ships, grass, vegetation) to
			## show what each costs. Host scene so autoloads resolve:
			##   tools/godot_render.sh --resolution 1600x900 res://tools/profile_reval_city.tscn
			func() -> void:
## Frame-cost probe for the seamless city (ADR 0031): stands Kalev at a few
## busy spots and measures rendered-frame time, then removes one layer at a
## time (people, chimney smoke, wall-foot weeds, ships, grass, vegetation) to
## show what each costs. Host scene so autoloads resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/profile_reval_city.tscn

## Frame-cost probe for the seamless city (ADR 0031): stands Kalev at a few
## busy spots and measures rendered-frame time, then removes one layer at a
## time (people, chimney smoke, wall-foot weeds, ships, grass, vegetation) to
## show what each costs. Host scene so autoloads resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/profile_reval_city.tscn

				rt._environment.advance_cycle(0.016, Callable(rt._session, "current_calendar_date")),
			"ambient": func() -> void: rt._ambient_controller.sync(0.016, rt.cycle_progress),
			"view_rotation": func() -> void: rt._camera_binding.apply_view_rotation(0.016),
			"sync_player": func() -> void: rt._sync_player(false, 0.016),
			"sync_actors": func() -> void: rt._actor_controller.sync_view_actors(0.016),
			"minimap_tracker": func() -> void: rt._hosted.sync_minimap_tracker(),
		}
		for key: String in parts:
			var t1 := Time.get_ticks_usec()
			for i in 10:
				(parts[key] as Callable).call()
			print("runtime %s: %.2f ms" % [key, (Time.get_ticks_usec() - t1) / 10000.0])
		_city.set_process(false)
		for child in rt.get_children():
			child.process_mode = Node.PROCESS_MODE_DISABLED
			await _measure("off: %s (%s)" % [child.name, child.get_class()])
		await _measure("city _process off")
		_city.runtime.process_mode = Node.PROCESS_MODE_DISABLED
		await _measure("runtime off too")
		get_tree().quit(0)
		return
	var world: Node = _city.world
	var layers := [
		["people", _city.find_child("CityNpcs", true, false)],
		["chimney smoke", world.get_node_or_null("ChimneySmoke")],
		["wall-foot weeds and climbers", world.get_node_or_null("WallFoot")],
		["ships", world.get_node_or_null("Ships")],
		["grass", world.get_node_or_null("Grass")],
		["trees and shrubs", world.get_node_or_null("Vegetation")],
		["buildings", world.get_node_or_null("Buildings")],
	]
	for layer: Array in layers:
		var node: Node = layer[1]
		if node == null:
			print("%-30s (not found)" % layer[0])
			continue
		if node is Node3D:
			(node as Node3D).visible = false
		node.process_mode = Node.PROCESS_MODE_DISABLED
		if layer[0] == "people":
			node.queue_free()
		await _measure("without %s" % layer[0])
	get_tree().quit(0)


func _measure(label: String) -> void:
	var total := 0.0
	var frames := 0
	for spot in SPOTS:
		_city.arrive_at(spot)
		for i in 10:
			await get_tree().process_frame
		var f0 := Engine.get_process_frames()
		var t0 := Time.get_ticks_usec()
		while Time.get_ticks_usec() - t0 < SAMPLE_SEC * 1e6:
			await get_tree().process_frame
		frames += Engine.get_process_frames() - f0
		total += (Time.get_ticks_usec() - t0) / 1000.0
	print(
		(
			"%-36s %.1f ms/frame  process %.1f ms  physics %.1f ms  draws %d  objects %d  nodes %d"
			% [
				label,
				total / maxf(frames, 1),
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			]
		)
	)
