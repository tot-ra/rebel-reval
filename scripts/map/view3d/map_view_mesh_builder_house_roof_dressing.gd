class_name MapViewMeshBuilderHouseRoofDressing
extends RefCounted

## Roof-edge dressing for timber, tile, shingle, and reed-thatch houses.

const _Styles := preload("res://scripts/map/view3d/map_view_mesh_builder_house_styles.gd")


static func add_roof_trim(
	root: Node3D,
	building: Dictionary,
	size: Vector2,
	height: float,
	along_ridge_x: bool
) -> void:
	if _Styles.roof_style(building) == MapViewMeshBuilderConfig.ROOF_STYLE_THATCH:
		_add_thatch_dressing(root, building, size, height, along_ridge_x)
		return
	var half := size * 0.5
	var overhang := MapViewMeshBuilderConfig.ROOF_OVERHANG
	var rise := ((size.y if along_ridge_x else size.x) * 0.5 + overhang) * MapViewMeshBuilderConfig.ROOF_PITCH
	# Flat board face (width) with a thin edge (thickness). Near-square sticks
	# silhouette as empty flagpoles from the dimetric camera.
	var barge_w := MapViewMeshBuilderConfig.HOUSE_BARGEBOARD_WIDTH
	var barge_t := MapViewMeshBuilderConfig.HOUSE_BARGEBOARD_THICKNESS
	var fascia_h := MapViewMeshBuilderConfig.HOUSE_EAVES_FASCIA_HEIGHT
	if along_ridge_x:
		var gable_span := size.y + overhang * 2.0
		# Inset from the apex so boards hug the rake instead of poking into the sky.
		var rake := sqrt(pow(gable_span * 0.5, 2.0) + pow(rise, 2.0)) * 0.94
		for side_x in [-1.0, 1.0]:
			for slope in [-1.0, 1.0]:
				var board := MeshInstance3D.new()
				board.name = "Bargeboard_%d_%d" % [int(side_x), int(slope)]
				var board_mesh := BoxMesh.new()
				board_mesh.size = Vector3(barge_t, barge_w, rake)
				board.mesh = board_mesh
				board.position = Vector3(
					side_x * (half.x + overhang * 0.12),
					height + rise * 0.48,
					slope * gable_span * 0.24
				)
				board.rotation.x = slope * atan2(rise, gable_span * 0.5)
				board.material_override = MapViewMaterials.role(&"timber")
				root.add_child(board)
		for side_z in [-1.0, 1.0]:
			MapViewMeshBuilderPrimitives.box(
				root,
				"EavesFascia_%d" % int(side_z),
				Vector3(size.x + overhang * 2.0, fascia_h, barge_t),
				Vector3(0.0, height + fascia_h * 0.35, side_z * (half.y + overhang * 0.55)),
				&"timber"
			)
		MapViewMeshBuilderPrimitives.box(
			root,
			"RidgeBoard",
			Vector3(size.x + overhang * 2.0, MapViewMeshBuilderConfig.HOUSE_RIDGE_BOARD_HEIGHT, barge_w * 0.55),
			Vector3(0.0, height + rise + MapViewMeshBuilderConfig.HOUSE_RIDGE_BOARD_HEIGHT * 0.35, 0.0),
			&"timber"
		)
	else:
		var gable_span := size.x + overhang * 2.0
		var rake := sqrt(pow(gable_span * 0.5, 2.0) + pow(rise, 2.0)) * 0.94
		for side_z in [-1.0, 1.0]:
			for slope in [-1.0, 1.0]:
				var board := MeshInstance3D.new()
				board.name = "Bargeboard_%d_%d" % [int(side_z), int(slope)]
				var board_mesh := BoxMesh.new()
				board_mesh.size = Vector3(rake, barge_w, barge_t)
				board.mesh = board_mesh
				board.position = Vector3(
					slope * gable_span * 0.24,
					height + rise * 0.48,
					side_z * (half.y + overhang * 0.12)
				)
				board.rotation.z = -slope * atan2(rise, gable_span * 0.5)
				board.material_override = MapViewMaterials.role(&"timber")
				root.add_child(board)
		for side_x in [-1.0, 1.0]:
			MapViewMeshBuilderPrimitives.box(
				root,
				"EavesFascia_%d" % int(side_x),
				Vector3(barge_t, fascia_h, size.y + overhang * 2.0),
				Vector3(side_x * (half.x + overhang * 0.55), height + fascia_h * 0.35, 0.0),
				&"timber"
			)
		MapViewMeshBuilderPrimitives.box(
			root,
			"RidgeBoard",
			Vector3(barge_w * 0.55, MapViewMeshBuilderConfig.HOUSE_RIDGE_BOARD_HEIGHT, size.y + overhang * 2.0),
			Vector3(0.0, height + rise + MapViewMeshBuilderConfig.HOUSE_RIDGE_BOARD_HEIGHT * 0.35, 0.0),
			&"timber"
		)


## Estonian thatch is a packed weatherproof cover, not a sparse layer of poles.
## Each cached slope contains a solid circa 25 cm shell plus many short,
## overlapping courses of reed bundles. This keeps the eaves and verges visibly
## thick while preserving one draw node per slope.
static var _thatch_slope_mesh_cache: Dictionary = {}
static var _thatch_gable_mesh_cache: Dictionary = {}


static func _add_thatch_dressing(
	root: Node3D,
	building: Dictionary,
	size: Vector2,
	height: float,
	along_ridge_x: bool
) -> void:
	var overhang := MapViewMeshBuilderConfig.THATCH_ROOF_OVERHANG
	var slope_half := (size.y if along_ridge_x else size.x) * 0.5 + overhang
	var rise := slope_half * MapViewMeshBuilderConfig.THATCH_ROOF_PITCH
	var thatch_mat := _Styles.house_roof_material(building)
	var ridge_r := MapViewMeshBuilderConfig.THATCH_RIDGE_RADIUS
	var ridge_span := (size.x if along_ridge_x else size.y) + overhang * 2.0

	# A compact bundle ridge closes both thick slope shells. It stops at the
	# verges rather than extending beyond them like a timber ridge pole.
	var ridge := MeshInstance3D.new()
	ridge.name = "ThatchRidge"
	var ridge_mesh := CylinderMesh.new()
	ridge_mesh.top_radius = ridge_r
	ridge_mesh.bottom_radius = ridge_r * 1.05
	ridge_mesh.radial_segments = 12
	ridge_mesh.height = ridge_span
	if along_ridge_x:
		ridge.rotation.z = PI * 0.5
	else:
		ridge.rotation.x = PI * 0.5
	ridge.mesh = ridge_mesh
	ridge.position = Vector3(
		0.0,
		height + rise
			+ MapViewMeshBuilderConfig.THATCH_COVER_THICKNESS * 0.55
			+ ridge_r * 0.35,
		0.0
	)
	ridge.material_override = thatch_mat
	root.add_child(ridge)

	_add_thatch_reed_slopes(root, size, height, along_ridge_x, thatch_mat)
	_add_thatch_gable_infill(root, building, size, height, along_ridge_x)
	_add_thatch_gable_framing(root, size, height, along_ridge_x)


static func _add_thatch_reed_slopes(
	root: Node3D,
	size: Vector2,
	height: float,
	along_ridge_x: bool,
	material: Material
) -> void:
	for side in [-1.0, 1.0]:
		var reeds := MeshInstance3D.new()
		# Keep the established node name for callers. The mesh now carries the
		# complete packed cover, its cut edges, and all overlapping surface bundles.
		reeds.name = "ThatchEavesFringe_%d" % int(side)
		reeds.mesh = _thatch_slope_mesh(size, along_ridge_x, side)
		reeds.position = Vector3(0.0, height, 0.0)
		reeds.material_override = material
		var down_direction := _thatch_down_direction(size, along_ridge_x, side)
		reeds.set_meta("stem_direction", down_direction)
		reeds.set_meta("ridge_direction", Vector3.RIGHT if along_ridge_x else Vector3.FORWARD)
		reeds.set_meta("course_count", _thatch_course_count(size, along_ridge_x))
		reeds.set_meta("stem_count", _thatch_stem_count(size, along_ridge_x))
		reeds.set_meta("cover_thickness", MapViewMeshBuilderConfig.THATCH_COVER_THICKNESS)
		root.add_child(reeds)


static func _thatch_slope_mesh(size: Vector2, along_ridge_x: bool, side: float) -> ArrayMesh:
	var key := "%.3f:%.3f:%s:%d" % [size.x, size.y, str(along_ridge_x), int(side)]
	if _thatch_slope_mesh_cache.has(key):
		return _thatch_slope_mesh_cache[key]

	var overhang := MapViewMeshBuilderConfig.THATCH_ROOF_OVERHANG
	var ridge_half := (size.x if along_ridge_x else size.y) * 0.5 + overhang
	var slope_half := (size.y if along_ridge_x else size.x) * 0.5 + overhang
	var rise := slope_half * MapViewMeshBuilderConfig.THATCH_ROOF_PITCH
	var rake := sqrt(slope_half * slope_half + rise * rise)
	var across_direction := Vector3.RIGHT if along_ridge_x else Vector3.FORWARD
	var surface_normal := (
		Vector3(0.0, 1.0, side * MapViewMeshBuilderConfig.THATCH_ROOF_PITCH)
		if along_ridge_x
		else Vector3(side * MapViewMeshBuilderConfig.THATCH_ROOF_PITCH, 1.0, 0.0)
	).normalized()
	var cover_lift := surface_normal * MapViewMeshBuilderConfig.THATCH_COVER_THICKNESS
	var stems_per_course := _thatch_stems_per_course(size, along_ridge_x)
	var course_count := _thatch_course_count(size, along_ridge_x)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	# The continuous shell makes the historical packed depth legible at every
	# viewing distance. The eave cap is deliberately darker like cut reed butts.
	_add_thatch_cover_shell(
		surface,
		ridge_half,
		slope_half,
		rise,
		along_ridge_x,
		side,
		surface_normal,
		cover_lift
	)

	# Bundles are fixed in overlapping eaves-to-ridge courses. Only their exposed
	# lower portions sit above the packed shell, avoiding the modern combed look
	# of uninterrupted grooves running from ridge to gutter.
	for course_index in course_count:
		var course_end_distance := minf(
			float(course_index + 1) * MapViewMeshBuilderConfig.THATCH_COURSE_EXPOSURE,
			rake
		)
		var course_start_distance := maxf(
			0.0,
			course_end_distance
				- MapViewMeshBuilderConfig.THATCH_COURSE_EXPOSURE
				- MapViewMeshBuilderConfig.THATCH_COURSE_OVERLAP
		)
		var is_eaves_course := course_index == course_count - 1
		for index in stems_per_course:
			var phase := float(index) * 2.399963 + float(course_index) * 1.618034 + side * 0.71
			var variation := sin(phase) * 0.5 + 0.5
			var secondary := sin(phase * 1.73 + 1.9) * 0.5 + 0.5
			var stagger := 0.5 if course_index % 2 == 0 else 0.0
			var ridge_position := lerpf(
				-ridge_half,
				ridge_half,
				(float(index) + stagger) / float(stems_per_course)
			)
			# Internal course edges stay softly uneven; the final cut eave varies more.
			var butt_variation := (
				MapViewMeshBuilderConfig.THATCH_STEM_EAVES_VARIATION
				if is_eaves_course
				else MapViewMeshBuilderConfig.THATCH_STEM_EAVES_VARIATION * 0.32
			)
			var start_t := course_start_distance / rake
			var end_t := (course_end_distance + butt_variation * (secondary - 0.35)) / rake
			end_t = clampf(end_t, start_t + 0.015, 1.035 if is_eaves_course else 1.0)
			var start := _thatch_surface_point(
				ridge_position,
				start_t,
				slope_half,
				rise,
				along_ridge_x,
				side
			) + cover_lift
			var end := _thatch_surface_point(
				ridge_position,
				end_t,
				slope_half,
				rise,
				along_ridge_x,
				side
			) + cover_lift
			end += across_direction * MapViewMeshBuilderConfig.THATCH_STEM_DRIFT * sin(phase * 1.37)
			var width := MapViewMeshBuilderConfig.THATCH_STEM_WIDTH * (0.76 + variation * 0.38)
			var tone := 0.78 + secondary * 0.22
			_add_reed_prism(
				surface,
				start,
				end,
				across_direction,
				surface_normal,
				width,
				MapViewMeshBuilderConfig.THATCH_STEM_RELIEF,
				Color(tone, tone, tone, 1.0)
			)

	var mesh := surface.commit()
	_thatch_slope_mesh_cache[key] = mesh
	return mesh


static func _add_thatch_cover_shell(
	surface: SurfaceTool,
	ridge_half: float,
	slope_half: float,
	rise: float,
	along_ridge_x: bool,
	side: float,
	surface_normal: Vector3,
	cover_lift: Vector3
) -> void:
	var base_ridge_a := _thatch_surface_point(-ridge_half, 0.0, slope_half, rise, along_ridge_x, side)
	var base_ridge_b := _thatch_surface_point(ridge_half, 0.0, slope_half, rise, along_ridge_x, side)
	var base_eave_a := _thatch_surface_point(-ridge_half, 1.0, slope_half, rise, along_ridge_x, side)
	var base_eave_b := _thatch_surface_point(ridge_half, 1.0, slope_half, rise, along_ridge_x, side)
	var top_ridge_a := base_ridge_a + cover_lift
	var top_ridge_b := base_ridge_b + cover_lift
	var top_eave_a := base_eave_a + cover_lift
	var top_eave_b := base_eave_b + cover_lift
	_add_colored_quad(
		surface,
		top_ridge_a,
		top_ridge_b,
		top_eave_b,
		top_eave_a,
		surface_normal,
		Color.WHITE
	)
	var down_direction := (base_eave_a - base_ridge_a).normalized()
	_add_colored_quad(
		surface,
		base_eave_a,
		top_eave_a,
		top_eave_b,
		base_eave_b,
		down_direction,
		Color(0.62, 0.58, 0.48, 1.0)
	)
	# Close both gable-side cuts so the quarter-metre packed layer is also visible
	# at the verges, not only along the eaves.
	for ridge_sign in [-1.0, 1.0]:
		var base_ridge := base_ridge_a if ridge_sign < 0.0 else base_ridge_b
		var base_eave := base_eave_a if ridge_sign < 0.0 else base_eave_b
		var top_ridge := top_ridge_a if ridge_sign < 0.0 else top_ridge_b
		var top_eave := top_eave_a if ridge_sign < 0.0 else top_eave_b
		var verge_normal: Vector3 = (Vector3.LEFT if along_ridge_x else Vector3.FORWARD) * -ridge_sign
		_add_colored_quad(
			surface,
			base_ridge,
			top_ridge,
			top_eave,
			base_eave,
			verge_normal,
			Color(0.78, 0.75, 0.66, 1.0)
		)


static func _thatch_surface_point(
	ridge_position: float,
	slope_t: float,
	slope_half: float,
	rise: float,
	along_ridge_x: bool,
	side: float
) -> Vector3:
	if along_ridge_x:
		return Vector3(ridge_position, rise * (1.0 - slope_t), side * slope_half * slope_t)
	return Vector3(side * slope_half * slope_t, rise * (1.0 - slope_t), ridge_position)


static func _thatch_down_direction(size: Vector2, along_ridge_x: bool, side: float) -> Vector3:
	var slope_half := (
		(size.y if along_ridge_x else size.x) * 0.5
		+ MapViewMeshBuilderConfig.THATCH_ROOF_OVERHANG
	)
	var rise := slope_half * MapViewMeshBuilderConfig.THATCH_ROOF_PITCH
	if along_ridge_x:
		return Vector3(0.0, -rise, side * slope_half).normalized()
	return Vector3(side * slope_half, -rise, 0.0).normalized()


static func _thatch_stems_per_course(size: Vector2, along_ridge_x: bool) -> int:
	var ridge_span := (
		(size.x if along_ridge_x else size.y)
		+ MapViewMeshBuilderConfig.THATCH_ROOF_OVERHANG * 2.0
	)
	return maxi(18, ceili(ridge_span / MapViewMeshBuilderConfig.THATCH_STEM_SPACING))


static func _thatch_course_count(size: Vector2, along_ridge_x: bool) -> int:
	var slope_half := (
		(size.y if along_ridge_x else size.x) * 0.5
		+ MapViewMeshBuilderConfig.THATCH_ROOF_OVERHANG
	)
	var rise := slope_half * MapViewMeshBuilderConfig.THATCH_ROOF_PITCH
	var rake := sqrt(slope_half * slope_half + rise * rise)
	return maxi(4, ceili(rake / MapViewMeshBuilderConfig.THATCH_COURSE_EXPOSURE))


static func _thatch_stem_count(size: Vector2, along_ridge_x: bool) -> int:
	return _thatch_stems_per_course(size, along_ridge_x) * _thatch_course_count(size, along_ridge_x)


static func _add_reed_prism(
	surface: SurfaceTool,
	start: Vector3,
	end: Vector3,
	across: Vector3,
	surface_normal: Vector3,
	width: float,
	relief: float,
	color: Color
) -> void:
	var base_lift := relief * 0.10
	var start_left := start - across * width * 0.5 + surface_normal * base_lift
	var start_right := start + across * width * 0.5 + surface_normal * base_lift
	var start_crown := start + surface_normal * relief
	var end_left := end - across * width * 0.5 + surface_normal * base_lift
	var end_right := end + across * width * 0.5 + surface_normal * base_lift
	var end_crown := end + surface_normal * relief

	_add_colored_quad(
		surface,
		start_left,
		end_left,
		end_crown,
		start_crown,
		surface_normal,
		color
	)
	_add_colored_quad(
		surface,
		start_crown,
		end_crown,
		end_right,
		start_right,
		surface_normal,
		color
	)
	# The eave cap is what turns the silhouette into many cut reed butts rather
	# than another flat fringe texture.
	_add_colored_triangle(
		surface,
		end_left,
		end_right,
		end_crown,
		(end - start).normalized(),
		color.darkened(0.12)
	)


static func _add_colored_quad(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal_hint: Vector3,
	color: Color
) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot(normal_hint) < 0.0:
		normal = -normal
	var vertices := [a, b, c, a, c, d]
	var uvs := [
		Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0),
		Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0),
	]
	for index in vertices.size():
		surface.set_normal(normal)
		surface.set_color(color)
		surface.set_uv(uvs[index])
		surface.add_vertex(vertices[index])


static func _add_colored_triangle(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	normal_hint: Vector3,
	color: Color
) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot(normal_hint) < 0.0:
		normal = -normal
	for index in 3:
		surface.set_normal(normal)
		surface.set_color(color)
		surface.set_uv([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.5, 1.0)][index])
		surface.add_vertex([a, b, c][index])


static func _add_thatch_gable_infill(
	root: Node3D,
	building: Dictionary,
	size: Vector2,
	height: float,
	along_ridge_x: bool
) -> void:
	var infill := MeshInstance3D.new()
	infill.name = "ThatchGableInfill"
	infill.mesh = _thatch_gable_mesh(size, along_ridge_x)
	infill.position = Vector3(0.0, height, 0.0)
	var wall_tone := Color(building.get("wall_color", MapViewMeshBuilderConfig.LOG_TONE))
	infill.material_override = MapViewMaterials.wall_surface(
		&"plank",
		wall_tone.lerp(MapViewMeshBuilderConfig.LOG_TONE, 0.55).darkened(0.08)
	)
	root.add_child(infill)


static func _thatch_gable_mesh(size: Vector2, along_ridge_x: bool) -> ArrayMesh:
	var key := "%.3f:%.3f:%s" % [size.x, size.y, str(along_ridge_x)]
	if _thatch_gable_mesh_cache.has(key):
		return _thatch_gable_mesh_cache[key]
	var overhang := MapViewMeshBuilderConfig.THATCH_ROOF_OVERHANG
	var slope_half := (size.y if along_ridge_x else size.x) * 0.5 + overhang
	var rise := slope_half * MapViewMeshBuilderConfig.THATCH_ROOF_PITCH
	var face_offset := MapViewMeshBuilderConfig.THATCH_GABLE_RECESS
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		if along_ridge_x:
			var x: float = side * (size.x * 0.5 + face_offset)
			_add_gable_triangle(
				surface,
				Vector3(x, 0.0, -slope_half),
				Vector3(x, 0.0, slope_half),
				Vector3(x, rise, 0.0),
				Vector3.RIGHT * side,
				slope_half,
				rise
			)
		else:
			var z: float = side * (size.y * 0.5 + face_offset)
			_add_gable_triangle(
				surface,
				Vector3(-slope_half, 0.0, z),
				Vector3(slope_half, 0.0, z),
				Vector3(0.0, rise, z),
				Vector3.FORWARD * side,
				slope_half,
				rise
			)
	var mesh := surface.commit()
	_thatch_gable_mesh_cache[key] = mesh
	return mesh


static func _add_gable_triangle(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	normal: Vector3,
	half_span: float,
	rise: float
) -> void:
	var vertices := [a, b, c]
	var uvs := [Vector2(-half_span, 0.0), Vector2(half_span, 0.0), Vector2(0.0, rise)]
	for index in vertices.size():
		surface.set_normal(normal)
		surface.set_uv(uvs[index])
		surface.add_vertex(vertices[index])


static func _add_thatch_gable_framing(
	root: Node3D,
	size: Vector2,
	height: float,
	along_ridge_x: bool
) -> void:
	var overhang := MapViewMeshBuilderConfig.THATCH_ROOF_OVERHANG
	var slope_half := (size.y if along_ridge_x else size.x) * 0.5 + overhang
	var rise := slope_half * MapViewMeshBuilderConfig.THATCH_ROOF_PITCH
	var rake := sqrt(slope_half * slope_half + rise * rise)
	var rake_angle := atan2(rise, slope_half)
	var board_width := MapViewMeshBuilderConfig.THATCH_GABLE_BOARD_WIDTH
	var board_thickness := MapViewMeshBuilderConfig.THATCH_GABLE_BOARD_THICKNESS
	var face_offset := MapViewMeshBuilderConfig.THATCH_GABLE_RECESS + board_thickness * 0.6
	var post_height := maxf(rise - board_width * 0.5, board_width)

	for gable_side in [-1.0, 1.0]:
		for slope_side in [-1.0, 1.0]:
			var board := MeshInstance3D.new()
			board.name = "ThatchVergeBoard_%d_%d" % [int(gable_side), int(slope_side)]
			var board_mesh := BoxMesh.new()
			if along_ridge_x:
				board_mesh.size = Vector3(board_thickness, board_width, rake)
				board.position = Vector3(
					gable_side * (size.x * 0.5 + face_offset),
					height + rise * 0.5,
					slope_side * slope_half * 0.5
				)
				board.rotation.x = slope_side * rake_angle
			else:
				board_mesh.size = Vector3(rake, board_width, board_thickness)
				board.position = Vector3(
					slope_side * slope_half * 0.5,
					height + rise * 0.5,
					gable_side * (size.y * 0.5 + face_offset)
				)
				board.rotation.z = -slope_side * rake_angle
			board.mesh = board_mesh
			board.material_override = MapViewMaterials.role(&"timber")
			root.add_child(board)

		# A tie beam and king post make the recessed plank triangle read as a built
		# gable frame, not another texture painted across the roof's cut end.
		if along_ridge_x:
			MapViewMeshBuilderPrimitives.box(
				root,
				"ThatchGableTieBeam_%d" % int(gable_side),
				Vector3(board_thickness, board_width, slope_half * 2.0),
				Vector3(gable_side * (size.x * 0.5 + face_offset), height + board_width * 0.4, 0.0),
				&"timber"
			)
			MapViewMeshBuilderPrimitives.box(
				root,
				"ThatchGableKingPost_%d" % int(gable_side),
				Vector3(board_thickness, post_height, board_width),
				Vector3(gable_side * (size.x * 0.5 + face_offset), height + post_height * 0.5, 0.0),
				&"timber"
			)
		else:
			MapViewMeshBuilderPrimitives.box(
				root,
				"ThatchGableTieBeam_%d" % int(gable_side),
				Vector3(slope_half * 2.0, board_width, board_thickness),
				Vector3(0.0, height + board_width * 0.4, gable_side * (size.y * 0.5 + face_offset)),
				&"timber"
			)
			MapViewMeshBuilderPrimitives.box(
				root,
				"ThatchGableKingPost_%d" % int(gable_side),
				Vector3(board_width, post_height, board_thickness),
				Vector3(0.0, height + post_height * 0.5, gable_side * (size.y * 0.5 + face_offset)),
				&"timber"
			)
