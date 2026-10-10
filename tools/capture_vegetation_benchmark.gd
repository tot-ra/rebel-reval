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
## R-1536: the scene is the continuous Reval city (CityWorld3D, ADR 0031), where
## all of the game's vegetation now grows; the viru_gate_foreland and
## lower_town_slice maps it used to load were retired in 88b010506. Camera
## positions come from stable plan IDs (pastures, fields, woods, the Kalev
## smithy spawn), so they follow plan edits instead of pointing at stale cells.
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
const SCENE_ID := "reval_city"
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
## CityVegetationBuilder batch visibility range -> layer (see _layer_of).
const VEGETATION_RANGE_LAYERS := {
	CityVegetationBuilder.WOOD_RANGE: &"trees_lod0",
	CityVegetationBuilder.CROWN_RANGE: &"trees_lod1",
	CityVegetationBuilder.BUSH_RANGE: &"shrubs",
}
## Fixed calendar, time and weather: crop growth, crown density and wind follow them.
const DATE := {"year": 1343, "month": 6, "day": 15}
const NOON := 0.5
## Streaming (grass, forbs, farmland) must finish within this many frames; a
## camera that never settles fails the run.
const MAX_STREAM_FRAMES := 900
## Fixed camera set. Each camera names a plan anchor; offsets and heights are
## world units (1 unit = 1 m in the city plan). Eye cameras are perspective at
## standing height; gameplay cameras reproduce the orthographic follow camera.
const CAMERAS: Array[Dictionary] = [
	{
		"name": "meadow_eye_level",
		"anchor": "meadow",
		"mode": "eye",
		"look": Vector2(15, -9),
		"eye_height": 1.65,
		"look_height": 0.6,
		"fov": 65.0,
	},
	{
		"name": "meadow_gameplay",
		"anchor": "meadow",
		"mode": "gameplay",
	},
	{
		"name": "grain_field_eye_level",
		"anchor": "grain_field",
		"mode": "eye",
		"look": Vector2(-6, 16),
		"eye_height": 1.65,
		"look_height": 0.4,
		"fov": 65.0,
	},
	{
		"name": "woodland_interior",
		"anchor": "woodland",
		"mode": "eye",
		"look": Vector2(-26, 2),
		"eye_height": 1.65,
		"look_height": 2.0,
		"fov": 65.0,
	},
	{
		"name": "woodland_distance",
		"anchor": "woodland_edge",
		"mode": "eye",
		"look": Vector2(0, -42),
		"eye_height": 6.0,
		"look_height": 3.0,
		"fov": 65.0,
	},
	{
		"name": "lower_town_street",
		"anchor": "kalev_smithy",
		"mode": "eye",
		"look": Vector2(-2, -3),
		"eye_height": 1.65,
		"look_height": 0.35,
		"fov": 65.0,
	},
]

var _triangle_cache := {}
## Fixed-size render target, so the window size and display scale never change
## what is measured; own world so nothing else shares the scene.
var _viewport: SubViewport
var _plan: CityPlan
var _world: CityWorld3D
var _camera: Camera3D


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
	_build_city()
	var anchors := _anchors()
	var reports: Array[Dictionary] = []
	for spec in CAMERAS:
		if not only.is_empty() and spec["name"] != only:
			continue
		if not anchors.has(spec["anchor"]):
			push_error("capture_vegetation_benchmark: plan has no %s anchor" % spec["anchor"])
			quit(1)
			return
		var entry: Dictionary = await _measure(spec, anchors[spec["anchor"]], timed, layer_timing, frames)
		if entry.is_empty():
			quit(1)
			return
		reports.append(entry)
	_world.queue_free()
	await process_frame
	if reports.is_empty():
		push_error("capture_vegetation_benchmark: no camera matched %s" % only)
		quit(1)
		return
	var report := {
		"schema": SCHEMA,
		"scene": SCENE_ID,
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


func _build_city() -> void:
	_plan = CityPlan.load_default()
	_world = CityWorld3D.create(_plan)
	_viewport.add_child(_world)
	_camera = Camera3D.new()
	_camera.far = 4000.0
	_viewport.add_child(_camera)
	_camera.current = true
	_world.setup_lighting(_camera)
	# Stop the sky clock: otherwise noon drifts and the weather evolves over a
	# several-minute run, and time-driven city content (lamps, smoke, particles)
	# makes `other` counts depend on how long earlier cameras took.
	_world.sky_weather.time_scale = 0.0
	MapViewMaterials.apply_vegetation_season(DATE)
	_world.farmland.set_calendar_date(DATE)
	_world.apply_time(NOON)


## Plan anchors in world XZ, each with the stable plan ID it came from. The
## first match by ID wins, so the choice only changes when the plan does.
func _anchors() -> Dictionary:
	var result := {}
	var meadows: Array = _plan.data.get("pastures", []).filter(
		func(p: Dictionary) -> bool: return p["kind"] == "meadow"
	)
	meadows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	if not meadows.is_empty():
		result["meadow"] = _polygon_anchor(meadows[0])
	var fields: Array = _plan.data.get("fields", []).filter(
		func(f: Dictionary) -> bool: return f["crop"] == "wheat"
	)
	fields.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	if not fields.is_empty():
		result["grain_field"] = _polygon_anchor(fields[0])
	# The largest wood; its edge camera stands outside it, looking back in.
	var woods: Array = _plan.data.get("woods", []).duplicate()
	woods.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a["area_m2"] > b["area_m2"] or (a["area_m2"] == b["area_m2"] and a["id"] < b["id"])
	)
	if not woods.is_empty():
		var wood: Dictionary = woods[0]
		var at := Vector2(wood["at"][0], wood["at"][1])
		result["woodland"] = {"id": wood["id"], "at": at}
		var radius := sqrt(float(wood["area_m2"]) / PI) / _plan.metres_per_unit
		result["woodland_edge"] = {"id": wood["id"], "at": at + Vector2(0, radius + 42.0)}
	# The street outside Kalev's smithy door, where CityTravel spawns "kalev_smithy"
	# (CityTravel itself needs the DoorNavigator autoload, absent under --script).
	for b: Dictionary in _plan.buildings:
		if b["landmark_id"] == "landmark.kalev_smithy" and b.get("door") != null:
			var door := Vector2(b["door"][0], b["door"][1])
			var out := Vector2(cos(float(b["door"][2])), sin(float(b["door"][2])))
			result["kalev_smithy"] = {"id": "landmark.kalev_smithy", "at": door + out * 2.5}
			break
	return result


func _polygon_anchor(feature: Dictionary) -> Dictionary:
	var poly := CityPlan.points(feature["polygon"])
	var centre := Vector2.ZERO
	for p in poly:
		centre += p
	return {"id": feature["id"], "at": centre / maxf(poly.size(), 1.0)}


func _measure(
	spec: Dictionary, anchor: Dictionary, timed: bool, layer_timing: bool, frames: int
) -> Dictionary:
	var at: Vector2 = anchor["at"]
	var ground := _plan.ground_height(at)
	var entry := {
		"name": spec["name"], "map_id": SCENE_ID, "anchor": anchor["id"], "mode": spec["mode"]
	}
	if spec["mode"] == "gameplay":
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.rotation_degrees = Vector3(
			MapView3D.CAMERA_PITCH_DEGREES, MapView3D.CAMERA_YAW_DEGREES, 0.0
		)
		_camera.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
		_camera.position = (
			Vector3(at.x, ground, at.y) + _camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
		)
		entry["projection"] = "orthogonal"
		entry["size"] = _camera.size
	else:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_camera.fov = spec["fov"]
		_camera.near = 0.05
		_camera.position = Vector3(at.x, ground + float(spec["eye_height"]), at.y)
		var look: Vector2 = at + (spec["look"] as Vector2)
		_camera.look_at(Vector3(look.x, _plan.ground_height(look) + float(spec["look_height"]), look.y))
		entry["projection"] = "perspective"
		entry["fov"] = _camera.fov
		entry["look_cell"] = [snappedf(look.x, 0.01), snappedf(look.y, 0.01)]
	entry["cell"] = [snappedf(at.x, 0.01), snappedf(at.y, 0.01)]
	entry["position"] = _round_vector(_camera.position)
	# Stream round the anchor as the game streams round Kalev.
	if not await _settle_streaming(at):
		push_error("capture_vegetation_benchmark: streaming never settled at %s" % spec["name"])
		return {}
	var census := _census(_world, _camera)
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


## Drives grass, forb, farmland and tree-LOD streaming round `focus` until no
## chunk or feature inside its build radius is missing, so the census sees the
## steady state. Streaming is time-budgeted and empty chunks add no node, so a
## node-count signature can stall mid-stream; the missing count cannot.
func _settle_streaming(focus: Vector2) -> bool:
	var tree_lod := _world.get_node_or_null("Vegetation/TreeLod") as CityTreeLod
	await _reset_streaming(tree_lod)
	for ignored in MAX_STREAM_FRAMES:
		_world.grass.update_for(focus)
		_world.farmland.update_for(focus)
		if tree_lod != null:
			tree_lod.update_for(_camera.global_position)
		await process_frame
		if _missing_streamed(focus) == 0:
			# Chunks that left the radius were queue_free()d this frame.
			await process_frame
			return true
	return false


## Forb chunks, farmland features and near tree crowns outlive their build
## radius (hysteresis), so without a reset the counts would depend on which
## camera ran before and a --camera= run would not match the full set. Grass
## chunks need no reset: their content is seeded by chunk key alone and the
## stream frees every chunk outside the radius.
func _reset_streaming(tree_lod: CityTreeLod) -> void:
	var farmland := _world.farmland
	for id: String in farmland._live.keys():
		farmland._free_feature(id)
	farmland._live.clear()
	var forbs := _world.grass.forbs
	forbs._chunks.clear()
	forbs._centre = Vector2i(0x7fffffff, 0x7fffffff)
	if tree_lod != null:
		tree_lod.update_for(Vector3(1.0e7, 0.0, 1.0e7))
	await process_frame


## Chunks and features the city would still build round `focus`. Reads the
## streamers' own chunk tables and radius constants (scripts/city/city_grass.gd,
## city_forbs.gd, city_farmland.gd), so it follows their tuning.
func _missing_streamed(focus: Vector2) -> int:
	var grass := _world.grass
	var missing := (
		_missing_chunks(grass._near_chunks, focus, CityGrass.NEAR_CHUNK, CityGrass.NEAR_RADIUS_CHUNKS)
		+ _missing_chunks(grass._mid_chunks, focus, CityGrass.MID_CHUNK, CityGrass.MID_RADIUS_CHUNKS)
		+ _missing_chunks(grass._far_chunks, focus, CityGrass.FAR_CHUNK, CityGrass.FAR_RADIUS_CHUNKS)
		+ _missing_chunks(grass.forbs._chunks, focus, CityForbs.CHUNK, CityForbs.RADIUS_CHUNKS)
	)
	var farmland := _world.farmland
	for feature: Dictionary in farmland._features:
		if (
			not farmland._live.has(feature["id"])
			and CityFarmland._edge_distance(feature, focus) <= CityFarmland.BUILD_RANGE
		):
			missing += 1
	return missing


static func _missing_chunks(chunks: Dictionary, focus: Vector2, size: float, radius: int) -> int:
	var centre := Vector2i(floori(focus.x / size), floori(focus.y / size))
	var missing := 0
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if not chunks.has(centre + Vector2i(dx, dy)):
				missing += 1
	return missing


## Per-layer census of what the camera submits. Deterministic for a given build.
func _census(world: CityWorld3D, camera: Camera3D) -> Dictionary:
	var planes := _frustum(camera)
	var layers := {}
	var nodes := {}
	for layer in LAYERS:
		layers[String(layer)] = {
			"nodes": 0, "instances": 0, "triangles": 0, "draw_calls": 0, "shadow_draw_calls": 0
		}
		nodes[layer] = [] as Array[GeometryInstance3D]
	var other_names := {}
	var stack: Array[Node] = [world]
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
		var layer := _layer_of(geometry, world)
		var bucket: Dictionary = layers[String(layer)]
		bucket["nodes"] += 1
		bucket["instances"] += cost["instances"]
		bucket["triangles"] += cost["triangles"]
		bucket["draw_calls"] += cost["surfaces"]
		if geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			bucket["shadow_draw_calls"] += cost["surfaces"]
		(nodes[layer] as Array).append(geometry)
		if layer == &"other":
			var key := _name_key(geometry, world)
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


## City attribution. An explicit `veg_layer` tag wins; otherwise the owning city
## builder decides (its class, or the fixed root names CityVegetationBuilder and
## CityMoatPlants give), and within an owner the fixed node-name prefixes that
## builder writes. Anything else, fences and hay ricks included, is `other`.
##   CityGrass: NearBlades_* grass_near; MidGrass_*/Blades and FarGrass_* grass_mid;
##     the yarrow accents of a MidGrass chunk flowers. CityForbs: flowers.
##   CityFarmland: Crop_* and FarFields grain. MoatPlants: veg_misc.
##   CityTreeLod (real-size near and macro crowns): trees_lod0; CITY_SHRUBS
##     species (by the "<Kind>_<species>" name) shrubs.
##   Vegetation root, by the visibility range CityVegetationBuilder gives each
##     batch (its per-chunk batches share a name, so Godot renames duplicates):
##     WOOD_RANGE trunks trees_lod0 (the only trunk mesh), CROWN_RANGE far card
##     crowns trees_lod1, BUSH_RANGE shrubs (bushes and shrub-species trees).
## trees_lod2 has no city producer and stays zero.
func _layer_of(geometry: GeometryInstance3D, world: CityWorld3D) -> StringName:
	if geometry.has_meta(LAYER_META):
		return StringName(geometry.get_meta(LAYER_META))
	var own := String(geometry.name)
	var under_far_fields := false
	var node: Node = geometry
	while node != null and node != world:
		if node is TreeLeafFall3D:
			return &"litter"
		var parent := node.get_parent()
		if parent is CityForbs:
			return &"flowers"
		if parent is CityGrass:
			if own.begins_with("NearBlades"):
				return &"grass_near"
			if own == "Blades" or own.begins_with("FarGrass"):
				return &"grass_mid"
			return &"flowers"
		if node.name == &"FarFields":
			under_far_fields = true
		if parent is CityFarmland:
			return &"grain" if under_far_fields or own.begins_with("Crop_") else &"other"
		if parent is CityTreeLod:
			return _tree_layer(own, &"trees_lod0")
		if parent != null and parent.name == &"MoatPlants":
			return &"veg_misc"
		if parent != null and parent.name == &"Vegetation" and parent.get_parent() == world:
			return VEGETATION_RANGE_LAYERS.get(geometry.visibility_range_end, &"veg_misc")
		node = parent
	return &"other"


## Tree batches are named "<Kind>_<species>"; city shrub species count as shrubs.
static func _tree_layer(node_name: String, tree_layer: StringName) -> StringName:
	var species := StringName(node_name.substr(node_name.find("_") + 1))
	return &"shrubs" if species in MapViewTreeMeshes.CITY_SHRUBS else tree_layer


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


func _name_key(geometry: GeometryInstance3D, world: CityWorld3D) -> String:
	var path := String(world.get_path_to(geometry))
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
