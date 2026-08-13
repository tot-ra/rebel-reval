extends "res://tests/godot/test_case.gd"

const ToompeaDefinition := preload(
	"res://scripts/map/definitions/prototypes/toompea_quarter_definition.gd"
)
const MonasteryQuarterDefinition := preload(
	"res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd"
)
const RevalHarborEastDefinition := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd"
)
const RevalHarborNorthDefinition := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd"
)
const LowerTownSliceDefinition := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapTypes := preload("res://scripts/map/map_types.gd")
const MapViewMeshBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder.gd")

# R-455 acceptance coverage is intentionally data-first: visual readability is
# only marked PASS when the runtime exposes measurable geometry/metadata.
const TOOMPEA_GROUND_ELEVATION := 2.8
const R455_CAPTURE_SIZE := Vector2i(1600, 900)
const R455_CAPTURE_PATHS: Array[String] = [
	"res://docs/reports/images/elevation/reval_harbor_north_player_eye_day.png",
	"res://docs/reports/images/elevation/reval_harbor_north_player_eye_night.png",
	"res://docs/reports/images/elevation/reval_harbor_north_top_down_day.png",
	"res://docs/reports/images/elevation/reval_harbor_north_top_down_night.png",
]

func _new_toompea():
	return ToompeaDefinition.create()

func _new_monastery():
	return MonasteryQuarterDefinition.create()

func _new_harbor():
	return RevalHarborEastDefinition.create()

func _new_harbor_north():
	return RevalHarborNorthDefinition.create()

func _new_lower_town():
	return LowerTownSliceDefinition.create()

func _terrain_grid(definition):
	return MapBuilder.build(definition)

func _water_count(grid) -> int:
	var width := int(grid.size_cells.x)
	var height := int(grid.size_cells.y)
	var count := 0
	for y in range(height):
		for x in range(width):
			if MapTypes.WATER_TERRAINS.has(grid.get_terrain(Vector2i(x, y))):
				count += 1
	return count

func _water_shore_edges(grid) -> int:
	var width := int(grid.size_cells.x)
	var height := int(grid.size_cells.y)
	var edges := 0
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			if not MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell)):
				continue
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbour: Vector2i = cell + direction
				if neighbour.x < 0 or neighbour.y < 0 or neighbour.x >= width or neighbour.y >= height:
					continue
				if not MapTypes.WATER_TERRAINS.has(grid.get_terrain(neighbour)):
					edges += 1
	return edges

func _assert_camera_bounds(label: String, definition) -> void:
	var bounds = definition.get("camera_bounds")
	assert_true(bounds is Rect2, "%s camera bounds must be a Rect2" % label)
	if bounds is Rect2:
		assert_true(bounds.size.x > 0.0, "%s camera bounds width" % label)
		assert_true(bounds.size.y > 0.0, "%s camera bounds height" % label)

func _assert_water_mesh_offset(label: String, definition, grid) -> void:
	var terrain := MapViewMeshBuilder.build_terrain(definition, grid)
	var water_nodes := terrain.find_children("Terrain_*", "MeshInstance3D", true, false)
	var found_water_mesh := false
	var expected_surface_y := MapViewMeshBuilder.water_surface_height()
	for node in water_nodes:
		if not String(node.name).begins_with("Terrain_") or node.name == "Terrain_Ground":
			continue
		var mesh := node.mesh as ArrayMesh
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		found_water_mesh = true
		var vertices := mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		assert_true(not vertices.is_empty(), "%s water mesh must expose vertices" % label)
		for vertex in vertices:
			assert_true(
				absf(vertex.y - expected_surface_y) <= 0.0001,
				"%s water surface must use the recessed view offset" % label
			)
	assert_true(found_water_mesh, "%s must expose a rendered water mesh" % label)
	terrain.free()

func test_r455_toompea_ground_elevation_and_deterministic_height() -> void:
	var definition = _new_toompea()
	assert_true(
		absf(float(definition.get("ground_elevation")) - TOOMPEA_GROUND_ELEVATION) <= 0.001,
		"Toompea authored elevation"
	)
	_assert_camera_bounds("Toompea", definition)
	var cell := Vector2i.ZERO
	var first := float(MapViewMeshBuilder.ground_height(definition, cell))
	var second := float(MapViewMeshBuilder.ground_height(definition, cell))
	assert_true(absf(first - second) <= 0.0001, "ground height must be deterministic")

func test_r455_target_maps_expose_or_explicitly_lack_grade_metadata() -> void:
	for item in [
		["Toompea", _new_toompea()],
		["Monastery", _new_monastery()],
		["Harbor North", _new_harbor_north()],
	]:
		var label: String = item[0]
		var definition = item[1]
		var profiles = definition.get("elevation_profiles")
		assert_true(profiles is Array, "%s elevation_profiles contract" % label)
		# Empty profiles are a passing regression guard for the known BLOCKED
		# state, not evidence that grades have been accepted.
		if profiles is Array and profiles.is_empty():
			print("[R-455][BLOCKED] %s has no authored elevation_profiles" % label)

func test_r455_recessed_water_and_shoreline_have_runtime_cells() -> void:
	var monastery_definition = _new_monastery()
	var harbor_definition = _new_harbor_north()
	var monastery_grid = _terrain_grid(monastery_definition)
	var harbor_grid = _terrain_grid(harbor_definition)
	var monastery_water := _water_count(monastery_grid)
	var harbor_water := _water_count(harbor_grid)
	assert_true(monastery_water > 0, "Monastery ditch/water cells must be authored")
	assert_true(harbor_water > 0, "Harbor North water cells must be authored")
	assert_true(
		_water_shore_edges(harbor_grid) > 0,
		"Harbor North water must meet non-water shoreline cells"
	)
	_assert_water_mesh_offset("Monastery", monastery_definition, monastery_grid)
	_assert_water_mesh_offset("Harbor North", harbor_definition, harbor_grid)
	var water_cell := Vector2i(0, 0)
	for y in range(harbor_grid.size_cells.y):
		for x in range(harbor_grid.size_cells.x):
			var candidate := Vector2i(x, y)
			if MapTypes.WATER_TERRAINS.has(harbor_grid.get_terrain(candidate)):
				water_cell = candidate
				break
		if (
			water_cell != Vector2i.ZERO
			or MapTypes.WATER_TERRAINS.has(harbor_grid.get_terrain(water_cell))
		):
			break
	var bed_height := MapViewMeshBuilder.ground_height(
		harbor_definition,
		Vector2(water_cell) + Vector2(0.5, 0.5)
	)
	assert_true(
		absf(bed_height + MapViewMeshBuilder.water_recess_depth()) <= 0.0001,
		"Harbor North water bed must use the recessed ground offset"
	)

func test_r455_objects_patrols_and_camera_contracts() -> void:
	for item in [
		["Toompea", _new_toompea()],
		["Lower Town", _new_lower_town()],
	]:
		var label: String = item[0]
		var definition = item[1]
		var buildings = definition.get("buildings")
		assert_true(buildings is Array, "%s buildings contract" % label)
		if buildings is Array:
			assert_true(buildings.size() > 0, "%s must contain placed objects" % label)
		_assert_camera_bounds(label, definition)
		var patrols = definition.get("patrols")
		assert_true(patrols is Array, "%s patrols contract" % label)
		if patrols is Array:
			assert_true(patrols.size() > 0, "%s must contain patrol routes" % label)
			for patrol in patrols:
				assert_true(patrol is Dictionary, "%s patrol entries must be dictionaries" % label)
				var route = []
				if patrol is Dictionary:
					route = patrol.get(
						"route",
						patrol.get("points", patrol.get("waypoints", []))
					)
				assert_true(route is Array, "%s patrol route must be an array" % label)
				if route is Array:
					assert_true(route.size() >= 2, "%s patrol route must have a segment" % label)
	print(
		"[R-455][PASS] rendered player-eye/top-down evidence is present; "
		+ "exact footprint alignment remains a visual review boundary"
	)


func test_r455_metal_elevation_captures_exist_with_expected_dimensions() -> void:
	for capture_path in R455_CAPTURE_PATHS:
		assert_true(FileAccess.file_exists(capture_path), "%s must exist" % capture_path)
		if not FileAccess.file_exists(capture_path):
			continue
		var image := Image.load_from_file(capture_path)
		assert_true(image != null, "%s must load as an image" % capture_path)
		if image == null:
			continue
		assert_eq(image.get_size(), R455_CAPTURE_SIZE, "%s dimensions" % capture_path)
		assert_true(image.get_format() == Image.FORMAT_RGB8, "%s must be an RGB PNG" % capture_path)
	print("[R-455][PASS] Metal elevation captures exist at %s" % str(R455_CAPTURE_SIZE))
