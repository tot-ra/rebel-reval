extends RefCounted

## WB-07b (R-1005): the cold height field and the terrain mesh as budgeted
## assembly units. Pure array work (height field, ground splat bands, water
## surfaces, shore field, swash sheet, seabed apron) runs on WorkerThreadPool
## into job-local data; the following main-thread unit publishes it into the
## static height-field cache, an ArrayMesh or a node. Units run in the order of
## the old single build_terrain() call, so the tree and every array match it.
##
## Thread rule: while any job of one build is running, the main thread does not
## write the shared field dictionary. The only field write (the shore field
## cache) happens after every job of that build has been joined.

const _Assembly := preload("res://scripts/map/view3d/map_view_assembly.gd")
const _Job := preload("res://scripts/map/view3d/map_view_worker_job.gd")

const HEIGHT_FIELD_STAGE := &"height_field"
const TERRAIN_STAGE := &"terrain_mesh"


## An empty named root added to `parent`, for stages that fill it unit by unit.
static func add_root(parent: Node, root_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = root_name
	parent.add_child(root)
	return root


## Nothing when the field is cached. Otherwise the bake runs on a worker and a
## main-thread unit publishes it, before any later stage reads ground height.
static func height_field_units(
	definition: MapDefinition, grid: MapTerrainGrid
) -> Array[Dictionary]:
	if not MapViewMeshBuilderTerrain.cached_height_field(definition, grid).is_empty():
		return []
	var job: RefCounted = _Job.run(
		func() -> Dictionary: return MapViewMeshBuilderTerrain.compute_height_field(definition, grid),
		"height_field %s" % String(definition.map_id)
	)
	var publish := func() -> void:
		MapViewMeshBuilderTerrain.publish_height_field(definition, grid, job.value())
	return [
		_Assembly.await_job(HEIGHT_FIELD_STAGE, "height_field", job),
		_Assembly.unit(HEIGHT_FIELD_STAGE, "publish_height_field", publish),
	]


## Fills `root` (the "Terrain" node) with the ground, water surfaces, shore swash,
## seabed apron and pier cribs, in that child order.
static func terrain_units(
	definition: MapDefinition, grid: MapTerrainGrid, root: Node3D
) -> Array[Dictionary]:
	return [
		_Assembly.unit(TERRAIN_STAGE, "terrain_start", _start.bind(definition, grid, root)),
	]


## Starts every independent bake at once so they share the pool, then queues
## their joins and publishes in tree order.
static func _start(
	definition: MapDefinition, grid: MapTerrainGrid, root: Node3D
) -> Array[Dictionary]:
	# Published by the height_field stage; a bare build_terrain() bakes it here.
	var field := MapViewMeshBuilderTerrain.ensure_height_field(definition, grid)
	var units: Array[Dictionary] = []
	var noise_seed := definition.seed
	if grid.size_cells.x > 0 and grid.size_cells.y > 0:
		var bands: RefCounted = _Job.run_group(
			func(band: int) -> Dictionary:
				return MapViewMeshBuilderTerrain.ground_band(field, grid, noise_seed, band),
			MapViewMeshBuilderTerrain.ground_band_count(
				MapViewMeshBuilderTerrain.ground_vertex_rows(grid)
			),
			"terrain ground bands"
		)
		units.append(_Assembly.await_job(TERRAIN_STAGE, "ground_bands", bands))
		units.append(
			_Assembly.unit(
				TERRAIN_STAGE, "ground_join", _join_ground.bind(field, bands, root, noise_seed)
			)
		)
	for terrain_id in grid.used_terrain_ids():
		if not MapViewMaterials.WATER_TERRAINS.has(terrain_id):
			continue
		var water: RefCounted = _Job.run(
			func() -> Array:
				return MapViewMeshBuilderTerrainWater.water_surface_arrays(field, grid, terrain_id),
			"terrain water %s" % String(terrain_id)
		)
		var label := "water_%s" % String(terrain_id)
		units.append(_Assembly.await_job(TERRAIN_STAGE, label, water))
		units.append(
			_Assembly.unit(TERRAIN_STAGE, label, _publish_water.bind(water, terrain_id, root))
		)
	var shore := _start_shore(field, grid)
	var apron: RefCounted = _Job.run(
		func() -> Array: return MapViewMeshBuilderTerrain.seabed_apron_arrays(field),
		"terrain seabed apron"
	)
	var cribs: RefCounted = _Job.run(
		func() -> Dictionary: return MapViewPierCribBuilder.crib_arrays(field),
		"terrain pier cribs"
	)
	units.append(_Assembly.await_job(TERRAIN_STAGE, "shore_swash", shore))
	# Joined before the shore publish writes the field cache; see the thread rule.
	units.append(_Assembly.await_job(TERRAIN_STAGE, "seabed_apron", apron))
	units.append(_Assembly.await_job(TERRAIN_STAGE, "pier_cribs", cribs))
	units.append(
		_Assembly.unit(TERRAIN_STAGE, "shore_swash", _publish_shore.bind(field, grid, shore, root))
	)
	units.append(_Assembly.unit(TERRAIN_STAGE, "seabed_apron", _publish_apron.bind(apron, root)))
	units.append(_Assembly.unit(TERRAIN_STAGE, "pier_cribs", _publish_cribs.bind(cribs, root)))
	return units


## Joining the bands (a few MB of copies) also runs on a worker; only the
## ArrayMesh upload stays on the main thread.
static func _join_ground(
	field: Dictionary, bands: RefCounted, root: Node3D, noise_seed: int
) -> Array[Dictionary]:
	var band_values: Array = bands.values()
	var join: RefCounted = _Job.run(
		func() -> Array: return MapViewMeshBuilderTerrain.ground_arrays(field, band_values),
		"terrain ground join"
	)
	var publish := func() -> void:
		var ground := MeshInstance3D.new()
		ground.name = "Terrain_Ground"
		ground.mesh = MapViewMeshBuilderTerrain.ground_mesh_from_arrays(join.value())
		ground.material_override = MapViewMaterials.blended_ground(noise_seed)
		root.add_child(ground)
	return [
		_Assembly.await_job(TERRAIN_STAGE, "ground_join", join),
		_Assembly.unit(TERRAIN_STAGE, "ground_publish", publish),
	]


static func _publish_water(water: RefCounted, terrain_id: StringName, root: Node3D) -> void:
	var arrays: Array = water.value()
	if arrays.is_empty():
		return
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.name = "Terrain_%s" % String(terrain_id)
	instance.mesh = mesh
	instance.material_override = MapViewMaterials.water_surface(terrain_id)
	root.add_child(instance)


## WS-08 shore field plus swash sheet arrays. A field baked earlier keeps its
## cached shore field (and texture), exactly like bake_shore_field().
static func _start_shore(field: Dictionary, grid: MapTerrainGrid) -> RefCounted:
	var sheet_enabled := MapViewMaterials.shore_swash_sheet_enabled()
	if field.get("flat_floor", false):
		return _Job.done({"shore": {}, "sheet": []})
	var cached: Dictionary = field.get("shore_field", {})
	var has_cached := field.has("shore_field")
	return _Job.run(
		func() -> Dictionary:
			var shore := (
				cached
				if has_cached
				else MapViewMeshBuilderTerrainWater.compute_shore_field(field, grid)
			)
			var sheet: Array = []
			if sheet_enabled:
				sheet = MapViewMeshBuilderTerrainWater.swash_sheet_arrays(field, shore)
			return {"shore": shore, "sheet": sheet, "fresh": not has_cached},
		"terrain shore swash"
	)


static func _publish_shore(
	field: Dictionary, grid: MapTerrainGrid, job: RefCounted, root: Node3D
) -> void:
	var result: Dictionary = job.value()
	var shore: Dictionary = result["shore"]
	if result.get("fresh", false):
		if field.has("shore_field"):
			# Another build of this map cached it meanwhile; reuse its texture.
			shore = field["shore_field"]
		else:
			shore = MapViewMeshBuilderTerrainWater.finish_shore_field(shore)
			field["shore_field"] = shore
	MapViewMeshBuilderTerrainWater.attach_shore_swash(root, grid, shore, result["sheet"])


static func _publish_apron(job: RefCounted, root: Node3D) -> void:
	var arrays: Array = job.value()
	if arrays.is_empty():
		return
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var apron := MeshInstance3D.new()
	# Not "Terrain_*": that prefix marks water surface meshes for tests and tools.
	apron.name = "SeaBedApron"
	apron.mesh = mesh
	apron.material_override = MapViewMeshBuilderTerrain.seabed_apron_material()
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(apron)


## WS-13d: timber crib cladding on the steep bed face beside landing decks.
static func _publish_cribs(job: RefCounted, root: Node3D) -> void:
	var cribs := MapViewPierCribBuilder.build_from_arrays(job.value())
	if cribs != null:
		root.add_child(cribs)
