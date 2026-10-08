extends SceneTree

## R-1320 (VEGR-0) per-layer vegetation benchmark.
##
## Walks a fixed, named camera set and reports, per vegetation layer, the
## instances, triangles and draw calls that the renderer is asked to submit
## from that camera. Counts are a deterministic census of the built scene:
## a node counts when it is visible in the tree, its world AABB intersects the
## camera frustum and its AABB centre lies inside its visibility range (the
## same per-node tests Godot's scene cull applies). A MultiMesh is culled as a
## whole, so every instance of a submitted MultiMesh counts, as on the GPU.
##
## It needs a real renderer: the headless dummy renderer drops MultiMesh
## instance data (transforms and AABB read back as zero), so frustum culling
## cannot be reproduced there and the tool refuses to run headless. It also
## records the RenderingServer frame totals and, with --layer-timing, the
## frame-time saving measured by hiding one layer at a time.
##
## Usage (minimized window, never a visible one):
##   tools/godot_render.sh --resolution 1920x1080 --disable-vsync \
##     --script res://tools/capture_vegetation_benchmark.gd \
##     -- --output=res://build/benchmarks/vegetation.json [--camera=name] [--frames=40] \
##     [--layer-timing] [--size=1920x1080] [--screenshots=res://dir/]
## tools/run_performance_report.sh <out.json> --vegetation wraps this command.
## Layer and schema contract: docs/PERFORMANCE_REPORT.md (Vegetation benchmark).

const SCHEMA := "rr.vegetation_benchmark.v1"
const DEFAULT_OUTPUT := "res://build/benchmarks/vegetation.json"
const VIRU := "res://scripts/map/definitions/outdoor/viru_gate_foreland_definition.gd"
const LOWER_TOWN := "res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
const LAYER_META := &"veg_layer"
## Report order. `veg_misc` holds vegetation outside the named tiers (reeds,
## cattails, herbs, ferns, tree fruit); `other` is every non-vegetation node.
const LAYERS: Array[StringName] = [
	&"grass_near",
	&"grass_mid",
	&"grain",
	&"trees_lod0",
	&"trees_lod1",
	&"trees_lod2",
	&"shrubs",
	&"flowers",
	&"litter",
	&"veg_misc",
	&"other",
]
## First-person ground cover lives in map_view_terrain_details.gd under fixed
## child names (TerrainDetails/FirstPerson/<name>); attribution by that path.
const TERRAIN_DETAIL_LAYERS := {
	&"MeadowGrass": &"grass_near",
	&"DryGrass": &"grass_near",
	&"Clover": &"flowers",
	&"Ferns": &"veg_misc",
}
## Authored props keep their kind on the MapDefinition; vegetation kinds map here.
const PROP_KIND_LAYERS := {
	&"tree": &"trees_lod0",
	&"bush": &"shrubs",
	&"orchard_row": &"trees_lod0",
	&"hedge": &"shrubs",
}
## Fixed camera set. Cells are map cells (1 world unit each); `look` is the aim
## cell. Eye cameras are perspective at standing height with first-person
## ground detail; gameplay cameras reproduce the orthographic follow camera.
const CAMERAS: Array[Dictionary] = [
	{
		"name": "meadow_eye_level",
		"map": VIRU,
		"mode": "eye",
		"cell": Vector2(121, 31),
		"look": Vector2(136, 22),
		"eye_height": 1.65,
		"look_height": 0.6,
		"fov": 65.0,
	},
	{
		"name": "meadow_gameplay",
		"map": VIRU,
		"mode": "gameplay",
		"cell": Vector2(121, 31),
	},
	{
		"name": "grain_field_eye_level",
		"map": VIRU,
		"mode": "eye",
		"cell": Vector2(36, 79),
		"look": Vector2(30, 95),
		"eye_height": 1.65,
		"look_height": 0.4,
		"fov": 65.0,
	},
	{
		"name": "woodland_interior",
		"map": VIRU,
		"mode": "eye",
		"cell": Vector2(50, 114),
		"look": Vector2(24, 116),
		"eye_height": 1.65,
		"look_height": 2.0,
		"fov": 65.0,
	},
	{
		"name": "woodland_distance",
		"map": VIRU,
		"mode": "eye",
		"cell": Vector2(35, 72),
		"look": Vector2(35, 114),
		"eye_height": 6.0,
		"look_height": 3.0,
		"fov": 65.0,
	},
	{
		"name": "lower_town_street",
		"map": LOWER_TOWN,
		"mode": "eye",
		"cell": Vector2(11, 85),
		"look": Vector2(9, 82),
		"eye_height": 1.65,
		"look_height": 0.35,
		"fov": 65.0,
	},
]

var _triangle_cache := {}
## Fixed-size render target, so the window size and display scale never change
## what is measured; own world so nothing else shares the scene.
var _viewport: SubViewport


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var only := _argument_value("--camera=", "")
	var frames := int(_argument_value("--frames=", "40"))
	var layer_timing := _has_flag("--layer-timing")
	if DisplayServer.get_name() == "headless":
		push_error(
			(
				"capture_vegetation_benchmark needs a real renderer; run it through"
				+ " tools/godot_render.sh (the dummy renderer drops MultiMesh transforms)"
			)
		)
		quit(2)
		return
	var timed := true
	var size_text := _argument_value("--size=", "1920x1080")
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(size_text.get_slice("x", 0)), int(size_text.get_slice("x", 1)))
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var reports: Array[Dictionary] = []
	var view: MapView3D = null
	var view_map := ""
	for spec in CAMERAS:
		if not only.is_empty() and spec["name"] != only:
			continue
		if spec["map"] != view_map:
			if view != null:
				view.queue_free()
				await process_frame
			view = await _build_view(spec["map"])
			view_map = spec["map"]
		reports.append(await _measure(view, spec, timed, layer_timing, frames))
	if view != null:
		view.queue_free()
		await process_frame
	if reports.is_empty():
		push_error("capture_vegetation_benchmark: no camera matched %s" % only)
		quit(1)
		return
	var report := {
		"schema": SCHEMA,
		"godot": Engine.get_version_info()["string"],
		"renderer": RenderingServer.get_current_rendering_method(),
		"display_server": DisplayServer.get_name(),
		"host":
		{
			"os": OS.get_name(),
			"cpu": OS.get_processor_name(),
			"arch": Engine.get_architecture_name(),
			"gpu": RenderingServer.get_video_adapter_name(),
		},
		"resolution": [_viewport.size.x, _viewport.size.y],
		"timed": timed,
		"layer_timing": timed and layer_timing,
		"frames": frames,
		"layers": LAYERS.map(func(layer: StringName) -> String: return String(layer)),
		"cameras": reports,
	}
	var output_path := _argument_value("--output=", DEFAULT_OUTPUT)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(output_path).get_base_dir()
	)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write vegetation benchmark: %s" % output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  ", false) + "\n")
	file.close()
	print("VEGETATION report: %s" % output_path)
	quit(0)


func _build_view(map_script: String) -> MapView3D:
	var definition: MapDefinition = load(map_script).create()
	var grid := MapBuilder.build(definition)
	var view := MapView3D.create(definition, grid)
	_viewport.add_child(view)
	# Fixed season, time and weather: crown density and wind state follow them.
	view.set_calendar_date({"year": 1343, "month": 6, "day": 15})
	view.apply_cycle_progress(0.5)
	await process_frame
	return view


func _measure(
	view: MapView3D, spec: Dictionary, timed: bool, layer_timing: bool, frames: int
) -> Dictionary:
	var definition := view.definition
	var camera := view.view_camera()
	var cell: Vector2 = spec["cell"]
	var focus := view.world_position(cell * definition.cell_size)
	var entry := {"name": spec["name"], "map_id": String(definition.map_id), "mode": spec["mode"]}
	if spec["mode"] == "gameplay":
		view.set_close_camera_mode(false)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.rotation_degrees = Vector3(
			MapView3D.CAMERA_PITCH_DEGREES, MapView3D.CAMERA_YAW_DEGREES, 0.0
		)
		camera.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
		camera.position = focus + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
		entry["projection"] = "orthogonal"
		entry["size"] = camera.size
	else:
		view.set_close_camera_mode(true)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = spec["fov"]
		camera.position = focus + Vector3.UP * float(spec["eye_height"])
		var look: Vector2 = spec["look"]
		var target := view.world_position(look * definition.cell_size)
		camera.look_at(target + Vector3.UP * float(spec["look_height"]))
		view.update_terrain_detail_focus(camera.position)
		entry["projection"] = "perspective"
		entry["fov"] = camera.fov
		entry["look_cell"] = [look.x, look.y]
	camera.current = true
	entry["cell"] = [cell.x, cell.y]
	entry["position"] = _round_vector(camera.position)
	view.update_active_chunks_from_logic_positions([cell * definition.cell_size] as Array[Vector2])
	for ignored in 6:
		await process_frame
	var census := _census(view, camera)
	entry["layers"] = census["layers"]
	entry["totals"] = census["totals"]
	entry["vegetation_share"] = census["vegetation_share"]
	entry["unattributed_top"] = census["unattributed_top"]
	var shots := _argument_value("--screenshots=", "")
	if not shots.is_empty():
		RenderingServer.force_draw(true, 0.0)
		var image := _viewport.get_texture().get_image()
		image.resize(image.get_width() / 2, image.get_height() / 2, Image.INTERPOLATE_LANCZOS)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots))
		image.save_png(ProjectSettings.globalize_path(shots).path_join("%s.png" % spec["name"]))
	if timed:
		entry["gpu"] = await _time_frames(frames)
		if layer_timing:
			entry["layer_ms"] = await _layer_timing(census["nodes"], entry["gpu"], frames)
	print(_summary_line(entry))
	return entry


## Per-layer census of what the camera submits. Deterministic for a given build.
func _census(view: MapView3D, camera: Camera3D) -> Dictionary:
	var planes := _frustum(camera)
	var props := _prop_layers(view.definition)
	var layers := {}
	var nodes := {}
	for layer in LAYERS:
		layers[String(layer)] = {
			"nodes": 0, "instances": 0, "triangles": 0, "draw_calls": 0, "shadow_draw_calls": 0
		}
		nodes[layer] = [] as Array[GeometryInstance3D]
	var other_names := {}
	var stack: Array[Node] = [view]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Node3D and not (node as Node3D).visible:
			continue
		for index in range(node.get_child_count() - 1, -1, -1):
			stack.append(node.get_child(index))
		if not node is GeometryInstance3D:
			continue
		var geometry := node as GeometryInstance3D
		var cost := _geometry_cost(geometry)
		if cost.is_empty() or not _submitted(geometry, cost["aabb"], camera, planes):
			continue
		var layer := _layer_of(geometry, view, props)
		var bucket: Dictionary = layers[String(layer)]
		bucket["nodes"] += 1
		bucket["instances"] += cost["instances"]
		bucket["triangles"] += cost["triangles"]
		bucket["draw_calls"] += cost["surfaces"]
		if geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			bucket["shadow_draw_calls"] += cost["surfaces"]
		(nodes[layer] as Array).append(geometry)
		if layer == &"other":
			var key := _name_key(geometry, view)
			other_names[key] = int(other_names.get(key, 0)) + int(cost["triangles"])
	var totals := {"triangles": 0, "draw_calls": 0, "instances": 0}
	var vegetation := {"triangles": 0, "draw_calls": 0, "instances": 0}
	for layer in LAYERS:
		var bucket: Dictionary = layers[String(layer)]
		for key in totals:
			totals[key] += bucket[key]
			if layer != &"other":
				vegetation[key] += bucket[key]
	var top: Array = other_names.keys()
	top.sort_custom(
		func(a: String, b: String) -> bool:
			return other_names[a] > other_names[b] or (other_names[a] == other_names[b] and a < b)
	)
	var unattributed: Array[Dictionary] = []
	for key: String in top.slice(0, 8):
		unattributed.append({"node": key, "triangles": other_names[key]})
	return {
		"layers": layers,
		"nodes": nodes,
		"totals": {"all": totals, "vegetation": vegetation},
		"vegetation_share":
		{
			"triangles": _share(vegetation["triangles"], totals["triangles"]),
			"draw_calls": _share(vegetation["draw_calls"], totals["draw_calls"]),
		},
		"unattributed_top": unattributed,
	}


func _layer_of(geometry: GeometryInstance3D, view: MapView3D, props: Dictionary) -> StringName:
	if geometry.has_meta(LAYER_META):
		return StringName(geometry.get_meta(LAYER_META))
	var parent := geometry.get_parent()
	if parent != null and parent.name == &"FirstPerson":
		return TERRAIN_DETAIL_LAYERS.get(geometry.name, &"veg_misc")
	var node: Node = geometry
	while node != null and node != view:
		if node is TreeLeafFall3D:
			return &"litter"
		var prop_layer: Variant = props.get(node.name)
		if prop_layer != null:
			return prop_layer
		node = node.get_parent()
	return &"other"


## Prop node name ("Prop_<id>") -> layer, from the authored prop kind.
func _prop_layers(definition: MapDefinition) -> Dictionary:
	var result := {}
	for prop in definition.props:
		var layer: Variant = PROP_KIND_LAYERS.get(StringName(prop.get("kind", "")))
		if layer != null:
			var node_name := ("Prop_%s" % String(prop.get("id", ""))).validate_node_name()
			result[StringName(node_name)] = layer
	return result


## Instances, triangles, surfaces and local AABB of one geometry node.
func _geometry_cost(geometry: GeometryInstance3D) -> Dictionary:
	var mesh: Mesh = null
	var instances := 1
	var aabb := AABB()
	if geometry is MultiMeshInstance3D:
		var multi := (geometry as MultiMeshInstance3D).multimesh
		if multi == null or multi.mesh == null:
			return {}
		mesh = multi.mesh
		instances = multi.visible_instance_count
		if instances < 0:
			instances = multi.instance_count
		if instances == 0:
			return {}
		aabb = multi.get_aabb()
		if aabb.size == Vector3.ZERO:
			aabb = _multimesh_aabb(multi, instances)
	elif geometry is MeshInstance3D:
		mesh = (geometry as MeshInstance3D).mesh
		if mesh == null:
			return {}
		aabb = mesh.get_aabb()
	elif geometry is GPUParticles3D:
		var particles := geometry as GPUParticles3D
		mesh = particles.draw_pass_1
		if mesh == null:
			return {}
		instances = particles.amount
		aabb = particles.visibility_aabb
	else:
		return {}
	var per_mesh := _mesh_triangles(mesh)
	return {
		"instances": instances,
		"triangles": int(per_mesh["triangles"]) * instances,
		"surfaces": per_mesh["surfaces"],
		"aabb": aabb,
	}


## Union of instance AABBs, for MultiMeshes whose renderer AABB is still empty.
func _multimesh_aabb(multi: MultiMesh, count: int) -> AABB:
	var local := multi.mesh.get_aabb()
	var result := multi.get_instance_transform(0) * local
	for index in range(1, count):
		result = result.merge(multi.get_instance_transform(index) * local)
	return result


func _mesh_triangles(mesh: Mesh) -> Dictionary:
	var key := mesh.get_instance_id()
	if _triangle_cache.has(key):
		return _triangle_cache[key]
	var triangles := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var count := 0
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
			count = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
		if count == 0 and arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
			count = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var primitive := Mesh.PRIMITIVE_TRIANGLES
		if mesh is ArrayMesh:
			primitive = (mesh as ArrayMesh).surface_get_primitive_type(surface)
		if primitive == Mesh.PRIMITIVE_TRIANGLES:
			triangles += count / 3
		elif primitive == Mesh.PRIMITIVE_TRIANGLE_STRIP:
			triangles += maxi(count - 2, 0)
	var result := {"triangles": triangles, "surfaces": mesh.get_surface_count()}
	_triangle_cache[key] = result
	return result


## Visibility range (distance to the AABB centre, as Godot's cull uses) and
## frustum tests for one node.
func _submitted(
	geometry: GeometryInstance3D, local_aabb: AABB, camera: Camera3D, planes: Array[Plane]
) -> bool:
	var world := geometry.global_transform * local_aabb
	var distance := camera.global_position.distance_to(world.get_center())
	if geometry.visibility_range_end > 0.0 and distance > geometry.visibility_range_end:
		return false
	if geometry.visibility_range_begin > 0.0 and distance < geometry.visibility_range_begin:
		return false
	for plane in planes:
		var outside := true
		for corner in 8:
			if not plane.is_point_over(world.get_endpoint(corner)):
				outside = false
				break
		if outside:
			return false
	return true


## Camera frustum planes oriented so "over" means outside.
func _frustum(camera: Camera3D) -> Array[Plane]:
	var inside := camera.global_position - camera.global_transform.basis.z * (camera.near + 1.0)
	var planes: Array[Plane] = []
	for plane: Plane in camera.get_frustum():
		planes.append(-plane if plane.is_point_over(inside) else plane)
	return planes


func _time_frames(frames: int) -> Dictionary:
	for ignored in 10:
		await _draw_ms()
	var frame_ms: Array[float] = []
	var draw_calls := 0
	var primitives := 0
	var objects := 0
	for ignored in frames:
		frame_ms.append(await _draw_ms())
		draw_calls = maxi(
			draw_calls,
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
			)
		)
		primitives = maxi(
			primitives,
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
			)
		)
		objects = maxi(
			objects,
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME
			)
		)
	return {
		"frame_ms_median": _median(frame_ms),
		"draw_calls_peak": draw_calls,
		"primitives_peak": primitives,
		"objects_peak": objects,
	}


## Frame-time saving per layer: alternate shown/hidden frames and take the
## median of the paired differences, so thermal or background drift cancels.
func _layer_timing(nodes: Dictionary, base: Dictionary, frames: int) -> Dictionary:
	var result := {}
	for layer in LAYERS:
		var members: Array = nodes[layer]
		if layer == &"other" or members.is_empty():
			continue
		var saved: Array[float] = []
		var shown_ms: Array[float] = []
		for ignored in frames:
			var shown := await _draw_ms()
			_set_visible(members, false)
			var hidden := await _draw_ms()
			_set_visible(members, true)
			saved.append(shown - hidden)
			shown_ms.append(shown)
		_set_visible(members, false)
		RenderingServer.force_draw(true, 0.0)
		var draws_hidden := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		)
		_set_visible(members, true)
		result[String(layer)] = {
			"frame_ms_saved": _median(saved),
			"frame_ms_shown": _median(shown_ms),
			"draw_calls_saved": base["draw_calls_peak"] - draws_hidden,
		}
	return result


## One synchronous frame: force_draw renders even while the godot_render.sh
## window is minimized (the main loop skips drawing then), and reading the
## render target back waits for the GPU, so the time is this frame's own cost
## plus a constant readback that cancels out in layer differences.
func _draw_ms() -> float:
	await process_frame
	var started := Time.get_ticks_usec()
	RenderingServer.force_draw(true, 0.0)
	_viewport.get_texture().get_image()
	return float(Time.get_ticks_usec() - started) / 1000.0


static func _set_visible(members: Array, state: bool) -> void:
	for geometry: GeometryInstance3D in members:
		geometry.visible = state


func _summary_line(entry: Dictionary) -> String:
	var parts: Array[String] = []
	for layer in LAYERS:
		var bucket: Dictionary = entry["layers"][String(layer)]
		if bucket["instances"] > 0:
			parts.append(
				(
					"%s=%d/%d/%d"
					% [layer, bucket["instances"], bucket["triangles"], bucket["draw_calls"]]
				)
			)
	return (
		"VEGETATION %s (inst/tris/draws): %s | vegetation share tris %.2f draws %.2f"
		% [
			entry["name"],
			" ".join(parts),
			entry["vegetation_share"]["triangles"],
			entry["vegetation_share"]["draw_calls"],
		]
	)


func _name_key(geometry: GeometryInstance3D, view: MapView3D) -> String:
	var path := String(view.get_path_to(geometry))
	var head := path.get_slice("/", 0)
	return "%s/%s" % [head, String(geometry.name).rstrip("0123456789_").replace("@", "")]


static func _share(part: int, whole: int) -> float:
	return snappedf(float(part) / float(whole), 0.0001) if whole > 0 else 0.0


static func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return snappedf(sorted[sorted.size() / 2], 0.01)


static func _round_vector(value: Vector3) -> Array[float]:
	return [snappedf(value.x, 0.01), snappedf(value.y, 0.01), snappedf(value.z, 0.01)]


func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _has_flag(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag)
