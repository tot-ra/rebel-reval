extends Node

## Non-headless render probe for the Lower Town (workers district) scene.
##
## The existing lower_town_scene_baseline.gd runs under the dummy renderer, so it
## cannot see GPU-side cost. This probe runs with a real rendering device and
## reports draw calls, primitives and a census of the visual node types that
## drive them, which is what actually decides frame rate on this map.

const DEFAULT_OUTPUT := "user://lower_town_render_probe.json"


func _ready() -> void:
	call_deferred("_record")


func _record() -> void:
	var scene_root := get_parent().get_node("LowerTown")
	# Let the map finish streaming/building before sampling steady state.
	for ignored in 60:
		await get_tree().process_frame
	_apply_experiments(scene_root)
	for ignored in 10:
		await get_tree().process_frame
	var frame_times: Array[float] = []
	var previous := Time.get_ticks_usec()
	var draw_calls := 0
	var primitives := 0
	for ignored in 120:
		await get_tree().process_frame
		var current := Time.get_ticks_usec()
		frame_times.append(float(current - previous) / 1000.0)
		previous = current
		draw_calls = maxi(draw_calls, int(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		)))
		primitives = maxi(primitives, int(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
		)))
	frame_times.sort()
	var census := {}
	var heavy: Array = []
	_census(scene_root, census, heavy, "")
	heavy.sort_custom(func(a, b): return int(a["surfaces"]) > int(b["surfaces"]))
	var report := {
		"draw_calls_peak": draw_calls,
		"primitives_peak": primitives,
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"frame_time_ms_median": frame_times[frame_times.size() / 2],
		"frame_time_ms_p95": frame_times[clampi(
			ceili(float(frame_times.size()) * 0.95) - 1, 0, frame_times.size() - 1
		)],
		"video_mem_mib": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"census": census,
		"heaviest_parents": heavy.slice(0, 40),
	}
	var output_path := DEFAULT_OUTPUT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--screenshot="):
			get_viewport().get_texture().get_image().save_png(
				argument.trim_prefix("--screenshot=")
			)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write render probe: %s" % output_path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	get_tree().quit(0)


## Attribution switches. They only mutate the running probe instance so a single
## build can be measured with individual cost sources removed.
func _apply_experiments(scene_root: Node) -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--no-shadows"):
		for light in _collect(scene_root, "DirectionalLight3D"):
			light.shadow_enabled = false
	if args.has("--no-neighbors"):
		var view := scene_root.find_child("Surroundings", true, false)
		if view != null:
			view.visible = false
	if args.has("--no-particles"):
		for particles in _collect(scene_root, "GPUParticles3D"):
			particles.emitting = false
			particles.visible = false
	for hidden in ["Scatter", "Terrain", "SkyWeather", "FogOfWar", "Buildings", "Props"]:
		if not args.has("--hide-%s" % hidden.to_lower()):
			continue
		var node := scene_root.find_child(hidden, true, false)
		if node != null:
			node.visible = false
	if args.has("--hide-particles"):
		for particles in _collect(scene_root, "GPUParticles3D"):
			particles.visible = false
	if args.has("--halve-particles"):
		for particles in _collect(scene_root, "GPUParticles3D"):
			particles.amount = maxi(1, particles.amount / 2)
	if args.has("--splits2"):
		for light in _collect(scene_root, "DirectionalLight3D"):
			light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if args.has("--trim-shadows"):
		for mesh in _collect(scene_root, "MeshInstance3D"):
			var size: Vector3 = mesh.get_aabb().size * mesh.global_transform.basis.get_scale()
			var dims := [size.x, size.y, size.z]
			dims.sort()
			if dims[1] < 0.35 or dims[2] < 0.6:
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if args.has("--no-props"):
		for props in _collect(scene_root, "Node3D"):
			if props.name == "Props" or props.name == "Scatter":
				props.visible = false


func _collect(node: Node, type_name: String) -> Array:
	var found: Array = []
	if node.is_class(type_name):
		found.append(node)
	for child in node.get_children():
		found.append_array(_collect(child, type_name))
	return found


func _census(node: Node, counters: Dictionary, heavy: Array, path: String) -> int:
	var own_surfaces := 0
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		own_surfaces = mesh.get_surface_count() if mesh != null else 0
		_bump(counters, "mesh_instance_3d")
		_bump(counters, "mesh_surfaces", own_surfaces)
		if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			_bump(counters, "mesh_instance_shadow_casting")
		if node.visibility_range_end <= 0.0:
			_bump(counters, "mesh_instance_no_visibility_range")
	elif node is MultiMeshInstance3D:
		_bump(counters, "multi_mesh_instance_3d")
		if node.multimesh != null:
			_bump(counters, "multi_mesh_instances", node.multimesh.instance_count)
		own_surfaces = 1
	elif node is OmniLight3D or node is SpotLight3D:
		_bump(counters, "positional_light")
		if node.shadow_enabled:
			_bump(counters, "positional_light_shadow")
	elif node is DirectionalLight3D:
		_bump(counters, "directional_light")
	elif node is GPUParticles3D:
		_bump(counters, "gpu_particles")
		if node.is_visible_in_tree():
			_bump(counters, "gpu_particles_visible")
		_bump(counters, "gpu_particles_amount", node.amount)
	elif node is CPUParticles3D:
		_bump(counters, "cpu_particles")
		_bump(counters, "cpu_particles_amount", node.amount)
	elif node is Sprite3D or node is Label3D:
		_bump(counters, "sprite_or_label_3d")
		own_surfaces = 1
	var subtree := own_surfaces
	var child_path := path + "/" + node.name
	for child in node.get_children():
		subtree += _census(child, counters, heavy, child_path)
	if subtree >= 20 and node.get_child_count() > 0:
		heavy.append({"path": child_path, "surfaces": subtree, "children": node.get_child_count()})
	return subtree


func _bump(counters: Dictionary, key: String, amount: int = 1) -> void:
	counters[key] = int(counters.get(key, 0)) + amount
