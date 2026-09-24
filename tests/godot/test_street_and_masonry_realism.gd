extends "res://tests/godot/test_case.gd"

## Street surface and fortification masonry realism contract.
##
## These checks defend the properties that made packed earth, paving and city
## walls read as real material rather than painted prototype fills: an earth
## plate with its own grain and hue, masonry courses at a plausible physical
## size, relief normals on masonry, and a gate passage that springs into an arch
## without narrowing its authored clear opening.

const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MeshBuilderConfig := preload("res://scripts/map/view3d/map_view_mesh_builder_config.gd")
const MeshBuilderLandmarks := preload(
	"res://scripts/map/view3d/map_view_mesh_builder_landmarks.gd"
)

## One world unit is one logic cell. The frozen character height is 2.0 units for
## a roughly 1.75 m adult, so a world unit is about 0.87 m.
const METRES_PER_UNIT := 0.875


func test_dirt_streets_use_the_packed_earth_plate() -> void:
	assert_eq(
		MapViewMaterials.TERRAIN_PATTERN[MapTypes.TERRAIN_DIRT],
		MapViewMaterials.PATTERN_EARTH,
		"packed-earth streets must not fall back to the generic speckle plate"
	)
	var image := (
		MapViewMaterialPatterns
		. pattern_texture(MapViewMaterials.PATTERN_EARTH, 4177)
		. get_image()
	)
	var minimum := 1.0
	var maximum := 0.0
	var hue_varied := false
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			var pixel := image.get_pixel(x, y)
			minimum = minf(minimum, pixel.r)
			maximum = maxf(maximum, pixel.r)
			if absf(pixel.r - pixel.b) > 0.04:
				hue_varied = true
	var earth_range := maximum - minimum
	assert_true(
		earth_range > 0.30,
		"trodden earth needs gravel, ruts and cracks, not a near-flat fill (range %.2f)" % earth_range
	)
	assert_true(hue_varied, "earth must carry dry/damp hue variation, not brightness alone")


func test_street_earth_is_not_saturated_red_clay() -> void:
	var dirt := OutdoorTerrainPalette.color(MapTypes.TERRAIN_DIRT)
	assert_true(dirt.s < 0.30, "Reval street earth is grey-ochre, not terracotta (s=%.2f)" % dirt.s)
	assert_true(
		dirt.r - dirt.b < 0.20,
		"packed earth must not run far warmer than a limestone-dust street"
	)


func test_masonry_courses_match_real_stone_sizes() -> void:
	for pattern: StringName in [
		MapViewMaterials.PATTERN_LIMESTONE, MapViewMaterials.PATTERN_BRICK
	]:
		var image := MapViewMaterialPatterns.pattern_texture(pattern, 8123).get_image()
		var size := image.get_height()
		var courses := _count_horizontal_joints(image)
		assert_true(courses > 0, "%s must be laid in courses" % String(pattern))
		var repeats_per_unit: float = (
			MapViewMaterials.building_uv_density(pattern).y
		)
		var course_metres := METRES_PER_UNIT / (repeats_per_unit * float(courses))
		# Split limestone runs about 0.2-0.45 m per course; a hand-moulded brick
		# course with its bed joint is about 0.08-0.16 m.
		var lower := 0.20 if pattern == MapViewMaterials.PATTERN_LIMESTONE else 0.07
		var upper := 0.45 if pattern == MapViewMaterials.PATTERN_LIMESTONE else 0.18
		assert_true(
			course_metres > lower and course_metres < upper,
			(
				"%s course reads as %.3f m on a wall (%d joints over %d px)"
				% [String(pattern), course_metres, courses, size]
			)
		)


func test_city_walls_use_authored_limestone_rubble_plate() -> void:
	assert_true(
		ResourceLoader.exists(MapViewMaterialPatterns.LIMESTONE_RUBBLE_PATH),
		"city walls need the authored limestone rubble plate"
	)
	var image := (
		MapViewMaterialPatterns
		. pattern_texture(MapViewMaterials.PATTERN_LIMESTONE, 8123)
		. get_image()
	)
	assert_eq(image.get_width(), MapViewMaterials.MASONRY_TEXTURE_SIZE)
	var minimum := 1.0
	var maximum := 0.0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var value := image.get_pixel(x, y).r
			minimum = minf(minimum, value)
			maximum = maxf(maximum, value)
	assert_true(
		maximum - minimum > 0.18,
		"limestone rubble must keep joint and face contrast (range %.2f)" % (maximum - minimum)
	)


func test_masonry_carries_relief_normals_at_masonry_resolution() -> void:
	for family: StringName in [&"limestone", &"brick"]:
		var material := MapViewMaterials.wall_surface(family, Color(0.56, 0.55, 0.50))
		assert_true(material.normal_enabled, "%s walls need relief, not a flat plane" % String(family))
		assert_true(material.normal_texture != null, "%s walls need a normal map" % String(family))
		assert_eq(
			material.albedo_texture.get_width(),
			MapViewMaterials.MASONRY_TEXTURE_SIZE,
			"%s needs the masonry source resolution" % String(family)
		)
		assert_eq(
			material.normal_texture.get_width(),
			MapViewMaterials.MASONRY_TEXTURE_SIZE,
			"%s relief must match its albedo resolution" % String(family)
		)


func test_gate_passage_springs_into_an_arch_without_narrowing_the_opening() -> void:
	var definition := LowerTownSlice.create()
	var arch: Dictionary = {}
	for landmark: Dictionary in definition.view_landmarks:
		if landmark.get("id", &"") == &"viru_gate_arch":
			arch = landmark
			break
	assert_true(not arch.is_empty(), "lower_town_slice must keep the Viru gate arch landmark")

	var node := MeshBuilderLandmarks.build_landmark(arch, definition.cell_size)
	var scale := MapViewBridge.world_scale(definition.cell_size)
	var size: Vector2 = (arch["rect"] as Rect2).size * scale
	var passage_along_x: bool = size.x >= size.y
	var footprint_half: float = (size.y if passage_along_x else size.x) * 0.5
	var opening_half := footprint_half - MeshBuilderConfig.GATE_JAMB_THICKNESS
	var springing := (
		MeshBuilderConfig.GATE_ARCH_CLEARANCE * MeshBuilderConfig.GATE_ARCH_SPRINGING_RATIO
	)

	var bands := 0
	for child in node.get_children():
		if not String(child.name).begins_with("ArchBand"):
			continue
		bands += 1
		var mesh_instance := child as MeshInstance3D
		var box := mesh_instance.mesh as BoxMesh
		var lateral: float = (
			mesh_instance.position.z if passage_along_x else mesh_instance.position.x
		)
		var half_width: float = (box.size.z if passage_along_x else box.size.x) * 0.5
		var inner_face := absf(lateral) - half_width
		var bottom := mesh_instance.position.y - box.size.y * 0.5
		assert_true(
			bottom >= springing - 0.001,
			"arch masonry must not drop below the springing line (%.2f)" % bottom
		)
		assert_true(
			inner_face >= opening_half - 0.001,
			"arch band at y=%.2f intrudes into the authored clear opening" % bottom
		)
	assert_true(bands >= 4, "the gate head must read as coursed voussoirs, not a flat lintel")
	node.free()


## Count rows whose mean value drops well below the plate mean: the bed joints.
func _count_horizontal_joints(image: Image) -> int:
	var size := image.get_height()
	var width := image.get_width()
	var rows := PackedFloat32Array()
	var total := 0.0
	for y in size:
		var row_total := 0.0
		for x in range(0, width, 4):
			row_total += image.get_pixel(x, y).r
		var mean := row_total / float(width / 4)
		rows.append(mean)
		total += mean
	var plate_mean := total / float(size)
	var joints := 0
	var inside := false
	for y in size:
		var is_joint := rows[y] < plate_mean - 0.06
		if is_joint and not inside:
			joints += 1
		inside = is_joint
	return joints
