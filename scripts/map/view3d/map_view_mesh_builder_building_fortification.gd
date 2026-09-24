class_name MapViewMeshBuilderBuildingFortification
extends RefCounted

## Fortification towers, battlements, and wall-walk dressing.

## Slant length of one tile course on conical tower roofs (world units).
const TOWER_ROOF_COURSE_LENGTH := 0.26
## How far each course lip steps out over the course below it.
const TOWER_ROOF_COURSE_LIP := 0.035
## Target width of one monk/nun tile column at a course's lower edge.
const TOWER_ROOF_TILE_WIDTH := 0.2
const TOWER_ROOF_SEGMENTS := 36
## Oak rafters under wall-walk gallery roofs.
const GALLERY_RAFTER_SPACING := 0.9
const GALLERY_RAFTER_SIZE := 0.09

static var _cone_cache: Dictionary = {}


static func sealed_wall_size(size: Vector3) -> Vector3:
	if size.x <= size.z:
		return Vector3(size.x + MapViewMeshBuilderConfig.WALL_SEAL_OVERHANG * 2.0, size.y, size.z)
	return Vector3(size.x, size.y, size.z + MapViewMeshBuilderConfig.WALL_SEAL_OVERHANG * 2.0)


## World-space footprint of a sealed fortification prism. Like sealed_wall_size
## it pads the short axis on both sides, but never grows a side into a gate
## passage: the padding on the Viru throat jambs narrowed the rendered 4-unit
## road to ~3 units, buried the open gate leaves inside the masonry, and left
## the visible wall disagreeing with the collision the player walks against.
static func sealed_wall_footprint(footprint: Rect2, gate_passages: Array[Rect2]) -> Rect2:
	var overhang := MapViewMeshBuilderConfig.WALL_SEAL_OVERHANG
	var grow_x := footprint.size.x <= footprint.size.y
	var result := footprint
	for side: float in [-1.0, 1.0]:
		var strip := (
			Rect2(
				footprint.position.x - overhang if side < 0.0 else footprint.end.x,
				footprint.position.y,
				overhang,
				footprint.size.y
			)
			if grow_x
			else Rect2(
				footprint.position.x,
				footprint.position.y - overhang if side < 0.0 else footprint.end.y,
				footprint.size.x,
				overhang
			)
		)
		var blocked := false
		for passage in gate_passages:
			if passage.intersects(strip):
				blocked = true
				break
		if not blocked:
			result = result.merge(strip)
	return result


static func add_tower_wall_walk_passage(
	root: Node3D,
	radius: float,
	passage_floor_y: float,
	tower_top_y: float,
	axis: StringName,
	wall_color: Color
) -> void:
	if axis not in [&"x", &"z"] or tower_top_y <= passage_floor_y:
		return
	var upper_height := tower_top_y - passage_floor_y
	var clear_width := minf(MapViewMeshBuilderConfig.WALL_WALK_PASSAGE_WIDTH, radius * 1.45)
	var clear_height := upper_height + MapViewMeshBuilderConfig.WALL_WALK_PASSAGE_CUT_DROP

	# WHY: primitive meshes cannot receive a doorway cut. CSG is limited to the
	# upper band so the dominant tower mass stays a cheap cylinder while the wall
	# walk gets a real tunnel through both sides of the circular drum.
	var upper_drum := CSGCylinder3D.new()
	upper_drum.name = "TowerUpperDrum"
	upper_drum.radius = radius
	upper_drum.height = upper_height
	upper_drum.sides = 24
	upper_drum.smooth_faces = true
	upper_drum.position.y = passage_floor_y + upper_height * 0.5
	upper_drum.material = MapViewMaterials.fortification_masonry(wall_color.lightened(0.08))
	root.add_child(upper_drum)

	var opening := CSGBox3D.new()
	opening.name = "WallWalkPassage"
	opening.operation = CSGShape3D.OPERATION_SUBTRACTION
	opening.size = (
		Vector3(radius * 2.4, clear_height, clear_width)
		if axis == &"x"
		else Vector3(clear_width, clear_height, radius * 2.4)
	)
	opening.position.y = (
		-upper_height * 0.5
		+ clear_height * 0.5
		- MapViewMeshBuilderConfig.WALL_WALK_PASSAGE_CUT_DROP
	)
	upper_drum.add_child(opening)


static func add_tower_door(root: Node3D, radius: float, height: float, side: StringName) -> void:
	if side not in [&"north", &"south", &"east", &"west"]:
		return
	var door_height := minf(MapViewMeshBuilderConfig.TOWER_DOOR_HEIGHT, height - 0.2)
	var width := MapViewMeshBuilderConfig.TOWER_DOOR_WIDTH
	var frame_width := MapViewMeshBuilderConfig.TOWER_DOOR_FRAME_WIDTH
	var frame_depth := MapViewMeshBuilderConfig.TOWER_DOOR_FRAME_DEPTH
	var panel_depth := MapViewMeshBuilderConfig.DOOR_THICKNESS

	# WHY: explicit door_side is authored toward the city. The renderer must not
	# infer a side from camera/map position because gate and castle towers can sit
	# on internal circuits where map-center heuristics point outside that circuit.
	MapViewMeshBuilderBuildingFacade.facade_box(
		root,
		"TowerDoor",
		Vector3(width, door_height, panel_depth),
		0.0,
		door_height * 0.5,
		side,
		radius,
		&"wood"
	)
	for post_side in [-1.0, 1.0]:
		MapViewMeshBuilderBuildingFacade.facade_box(
			root,
			"TowerDoorFrame%d" % int(post_side),
			Vector3(frame_width, door_height + frame_width, frame_depth),
			post_side * (width + frame_width) * 0.5,
			(door_height + frame_width) * 0.5,
			side,
			radius,
			&"stone"
		)
	MapViewMeshBuilderBuildingFacade.facade_box(
		root,
		"TowerDoorLintel",
		Vector3(width + frame_width * 2.0, frame_width, frame_depth),
		0.0,
		door_height + frame_width * 0.5,
		side,
		radius,
		&"stone"
	)
	MapViewMeshBuilderBuildingFacade.facade_box(
		root,
		"TowerDoorStep",
		Vector3(width + frame_width, 0.1, MapViewMeshBuilderConfig.TOWER_DOOR_STEP_DEPTH),
		0.0,
		0.05,
		side,
		radius + MapViewMeshBuilderConfig.TOWER_DOOR_STEP_DEPTH * 0.25,
		&"stone"
	)
	var face_offset := radius + panel_depth * 0.5
	MapViewMeshBuilderBuildingFacade.facade_box(
		root,
		"TowerDoorStrap0",
		Vector3(width * 0.88, 0.07, 0.04),
		0.0,
		door_height * 0.32,
		side,
		face_offset,
		&"metal"
	)
	MapViewMeshBuilderBuildingFacade.facade_box(
		root,
		"TowerDoorStrap1",
		Vector3(width * 0.88, 0.07, 0.04),
		0.0,
		door_height * 0.7,
		side,
		face_offset,
		&"metal"
	)
	MapViewMeshBuilderBuildingFacade.facade_box(
		root,
		"TowerDoorLatch",
		Vector3(0.09, 0.14, 0.06),
		width * 0.3,
		door_height * 0.5,
		side,
		face_offset,
		&"metal"
	)


static func add_tower_roof(
	root: Node3D, radius: float, height: float, building: Dictionary = {}
) -> void:
	var roof_radius := radius + 0.34
	var cone_height := roof_radius * MapViewMeshBuilderConfig.TOWER_ROOF_PITCH
	var roof := MeshInstance3D.new()
	roof.name = "TowerRoof"
	roof.mesh = tower_cone_roof_mesh(roof_radius, cone_height)
	roof.position = Vector3(0.0, height + MapViewMeshBuilderConfig.CAP_HEIGHT * 2.0, 0.0)
	roof.material_override = MapViewMaterials.tower_roof_tiles(
		StringName(String(building.get("id", "tower_roof"))),
		MapViewMeshBuilderConfig.TOWER_ROOF_COLOR
	)
	root.add_child(roof)
	var finial := MeshInstance3D.new()
	finial.name = "Finial"
	var knob := SphereMesh.new()
	knob.radius = 0.09
	knob.height = 0.18
	finial.mesh = knob
	var finial_y := height + MapViewMeshBuilderConfig.CAP_HEIGHT * 2.0 + cone_height + 0.06
	finial.position = Vector3(0.0, finial_y, 0.0)
	finial.material_override = MapViewMaterials.role(&"metal")
	root.add_child(finial)
	# WHY: tower pennants mark only faction seats (explicit faction= or the
	# sparse BUILDING_DEFAULTS allowlist). Ordinary wall towers stay bare so
	# the skyline is not a forest of empty poles.
	var faction := FactionHeraldry.resolve(building)
	if FactionHeraldry.shows_flag(faction):
		_add_tower_pennant(root, finial_y, faction)


## Stepped conical tile roof. A smooth CylinderMesh cone could only fake tile
## relief with a texture, so the roof read flatter than the masonry below it.
## Here every tile course is its own frustum band whose lower edge steps out and
## down over the next course: the silhouette gains real serrated course lips and
## sunlight breaks into shaded bands. Each band maps exactly one plate course and
## a whole number of tiles, so tiles taper toward the apex like a laid cone and
## the ring seam always falls on a tile joint. Base sits at local y = 0.
static func tower_cone_roof_mesh(radius: float, height: float) -> ArrayMesh:
	var key := "tower_cone:%.3f:%.3f" % [radius, height]
	if _cone_cache.has(key):
		return _cone_cache[key]
	var slant := sqrt(radius * radius + height * height)
	var courses := maxi(6, roundi(slant / TOWER_ROOF_COURSE_LENGTH))
	var plate_courses := MapViewMaterialPatterns.ROOF_TILE_COURSES
	var plate_columns := float(MapViewMaterialPatterns.ROOF_TILE_COLUMNS)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in courses:
		var t0 := float(band) / float(courses)
		var t1 := float(band + 1) / float(courses)
		var r_top := radius * t0
		var y_top := height * (1.0 - t0)
		# The lip steps outward and down so it overlaps the band below it.
		var r_bottom := radius * t1 + TOWER_ROOF_COURSE_LIP
		var y_bottom := height * (1.0 - t1) - TOWER_ROOF_COURSE_LIP * 0.7
		var profile_normal := Vector2(y_top - y_bottom, r_bottom - r_top).normalized()
		# Whole plates per ring: the monk cover straddling the ring seam then
		# samples one tile on both sides instead of two different tones.
		var plates := maxi(1, roundi(TAU * r_bottom / TOWER_ROOF_TILE_WIDTH / plate_columns))
		var u_span := float(plates)
		var row := posmod(band, plate_courses)
		var v_top := float(row) / float(plate_courses)
		var v_bottom := float(row + 1) / float(plate_courses)
		for segment in TOWER_ROOF_SEGMENTS:
			var a0 := TAU * float(segment) / float(TOWER_ROOF_SEGMENTS)
			var a1 := TAU * float(segment + 1) / float(TOWER_ROOF_SEGMENTS)
			var d0 := Vector3(sin(a0), 0.0, cos(a0))
			var d1 := Vector3(sin(a1), 0.0, cos(a1))
			var n0 := (d0 * profile_normal.x + Vector3.UP * profile_normal.y).normalized()
			var n1 := (d1 * profile_normal.x + Vector3.UP * profile_normal.y).normalized()
			var u0 := u_span * float(segment) / float(TOWER_ROOF_SEGMENTS)
			var u1 := u_span * float(segment + 1) / float(TOWER_ROOF_SEGMENTS)
			var top0 := d0 * r_top + Vector3.UP * y_top
			var top1 := d1 * r_top + Vector3.UP * y_top
			var bottom0 := d0 * r_bottom + Vector3.UP * y_bottom
			var bottom1 := d1 * r_bottom + Vector3.UP * y_bottom
			_cone_vertex(surface, top0, n0, Vector2(u0, v_top))
			_cone_vertex(surface, top1, n1, Vector2(u1, v_top))
			_cone_vertex(surface, bottom1, n1, Vector2(u1, v_bottom))
			_cone_vertex(surface, top0, n0, Vector2(u0, v_top))
			_cone_vertex(surface, bottom1, n1, Vector2(u1, v_bottom))
			_cone_vertex(surface, bottom0, n0, Vector2(u0, v_bottom))
	# Soffit disc closes the eaves when the roof is seen from the wall walk.
	var eave_y := -TOWER_ROOF_COURSE_LIP * 0.7
	var eave_radius := radius + TOWER_ROOF_COURSE_LIP
	for segment in TOWER_ROOF_SEGMENTS:
		var a0 := TAU * float(segment) / float(TOWER_ROOF_SEGMENTS)
		var a1 := TAU * float(segment + 1) / float(TOWER_ROOF_SEGMENTS)
		var p0 := Vector3(sin(a0), 0.0, cos(a0)) * eave_radius + Vector3.UP * eave_y
		var p1 := Vector3(sin(a1), 0.0, cos(a1)) * eave_radius + Vector3.UP * eave_y
		var center := Vector3.UP * eave_y
		_cone_vertex(surface, center, Vector3.DOWN, Vector2(0.5, 0.5))
		_cone_vertex(surface, p1, Vector3.DOWN, Vector2(0.5, 0.5))
		_cone_vertex(surface, p0, Vector3.DOWN, Vector2(0.5, 0.5))
	surface.generate_tangents()
	var mesh := surface.commit()
	_cone_cache[key] = mesh
	return mesh


static func _cone_vertex(
	surface: SurfaceTool, position: Vector3, normal: Vector3, uv: Vector2
) -> void:
	surface.set_normal(normal)
	surface.set_uv(uv)
	surface.add_vertex(position)


static func _add_tower_pennant(root: Node3D, finial_y: float, faction_id: StringName) -> void:
	var staff := MeshInstance3D.new()
	staff.name = "PennantStaff"
	var staff_mesh := CylinderMesh.new()
	staff_mesh.top_radius = 0.018
	staff_mesh.bottom_radius = 0.022
	staff_mesh.height = 0.72
	staff_mesh.radial_segments = 6
	staff.mesh = staff_mesh
	staff.position = Vector3(0.0, finial_y + 0.36, 0.0)
	staff.material_override = MapViewMaterials.role(&"timber")
	root.add_child(staff)

	var pennant := MeshInstance3D.new()
	pennant.name = "Pennant"
	pennant.mesh = FactionHeraldry.pennant_mesh(faction_id)
	pennant.position = Vector3(0.0, finial_y + 0.58, 0.0)
	pennant.set_meta(&"faction", faction_id)
	pennant.material_override = MapViewMaterials.flag_cloth()
	pennant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pennant)


static func add_tower_slits(root: Node3D, radius: float, height: float) -> void:
	var slit_center_y := height * 0.62
	var index := 0
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var outward := Vector3(sin(angle), 0.0, cos(angle))
		var frame_size := Vector3(
			(
				MapViewMeshBuilderConfig.ARROW_SLIT_SIZE.x
				+ MapViewMeshBuilderConfig.ARROW_SLIT_FRAME_PAD.x * 2.0
			),
			(
				MapViewMeshBuilderConfig.ARROW_SLIT_SIZE.y
				+ MapViewMeshBuilderConfig.ARROW_SLIT_FRAME_PAD.y * 2.0
			),
			MapViewMeshBuilderConfig.ARROW_SLIT_FRAME_DEPTH
		)
		var frame := MeshInstance3D.new()
		frame.name = "SlitFrame%d" % index
		var frame_mesh := BoxMesh.new()
		frame_mesh.size = frame_size
		frame.mesh = frame_mesh
		frame.position = outward * (radius + MapViewMeshBuilderConfig.ARROW_SLIT_FRAME_DEPTH * 0.5)
		frame.position.y = slit_center_y
		frame.rotation.y = angle
		frame.material_override = MapViewMaterials.wall_surface_for_size(
			&"brick", MapViewMeshBuilderConfig.BRICK_TONE, frame_size
		)
		root.add_child(frame)

		var slit := MeshInstance3D.new()
		slit.name = "Slit%d" % index
		var mesh := BoxMesh.new()
		mesh.size = MapViewMeshBuilderConfig.ARROW_SLIT_SIZE
		slit.mesh = mesh
		slit.position = (
			outward
			* (
				radius
				+ MapViewMeshBuilderConfig.ARROW_SLIT_FRAME_DEPTH
				+ MapViewMeshBuilderConfig.ARROW_SLIT_SIZE.z * 0.5
				- 0.01
			)
		)
		slit.position.y = slit_center_y
		slit.rotation.y = angle
		slit.material_override = MapViewMaterials.role(&"ink")
		root.add_child(slit)
		index += 1


static func add_wall_walk_roof(root: Node3D, size: Vector2, height: float) -> void:
	var along_x := size.x >= size.y
	var length := (size.x if along_x else size.y) + 0.3
	var span := maxf(
		(size.y if along_x else size.x) + 0.7, MapViewMeshBuilderConfig.WALL_WALK_MIN_WIDTH
	)
	var deck_y := height + MapViewMeshBuilderConfig.CAP_HEIGHT
	var clear_height := MapViewMeshBuilderConfig.WALL_WALK_CLEAR_HEIGHT
	var roof := MeshInstance3D.new()
	roof.name = "WalkRoof"
	roof.mesh = MapViewMeshBuilderPrimitives.gabled_roof_mesh(
		Vector2(length, span) if along_x else Vector2(span, length), along_x
	)
	roof.position = Vector3(0.0, deck_y + clear_height, 0.0)
	roof.material_override = MapViewMaterials.roof_tile_world(MapViewMeshBuilderConfig.WALL_ROOF_COLOR)
	root.add_child(roof)

	var post_count := maxi(2, ceili(length / MapViewMeshBuilderConfig.WALL_WALK_POST_SPACING))
	var post_height := clear_height + 0.1
	var side_offset := span * 0.5 - 0.3
	for post_index in post_count + 1:
		var along := (float(post_index) / float(post_count) - 0.5) * (length - 0.4)
		for side in [-1.0, 1.0]:
			var offset: float = side * side_offset
			var post_position := Vector3(along, deck_y + post_height * 0.5, offset)
			if not along_x:
				post_position = Vector3(offset, post_position.y, along)
			_timber_box(
				root,
				"RoofPost%d_%d" % [post_index, int(side)],
				(
					Vector3.ONE * MapViewMeshBuilderConfig.WALL_WALK_POST_SIZE
					+ Vector3(0.0, post_height - MapViewMeshBuilderConfig.WALL_WALK_POST_SIZE, 0.0)
				),
				post_position
			)

	# Continuous rails and eaves beams make the top read as a usable timber
	# gallery rather than a roof balanced on isolated sticks.
	for side in [-1.0, 1.0]:
		var offset: float = side * side_offset
		for rail_y in [
			MapViewMeshBuilderConfig.WALL_WALK_RAIL_HEIGHT * 0.52,
			MapViewMeshBuilderConfig.WALL_WALK_RAIL_HEIGHT,
		]:
			var rail_size := (
				Vector3(
					length,
					MapViewMeshBuilderConfig.WALL_WALK_RAIL_SIZE,
					MapViewMeshBuilderConfig.WALL_WALK_RAIL_SIZE
				)
				if along_x
				else Vector3(
					MapViewMeshBuilderConfig.WALL_WALK_RAIL_SIZE,
					MapViewMeshBuilderConfig.WALL_WALK_RAIL_SIZE,
					length
				)
			)
			var rail_position := (
				Vector3(0.0, deck_y + rail_y, offset)
				if along_x
				else Vector3(offset, deck_y + rail_y, 0.0)
			)
			_timber_box(
				root,
				"GalleryRail%d_%d" % [int(side), int(rail_y * 100.0)],
				rail_size,
				rail_position
			)
		var eaves_size := (
			Vector3(
				length,
				MapViewMeshBuilderConfig.WALL_WALK_POST_SIZE,
				MapViewMeshBuilderConfig.WALL_WALK_POST_SIZE
			)
			if along_x
			else Vector3(
				MapViewMeshBuilderConfig.WALL_WALK_POST_SIZE,
				MapViewMeshBuilderConfig.WALL_WALK_POST_SIZE,
				length
			)
		)
		var eaves_position := (
			Vector3(0.0, deck_y + clear_height, offset)
			if along_x
			else Vector3(offset, deck_y + clear_height, 0.0)
		)
		_timber_box(root, "GalleryEaves%d" % int(side), eaves_size, eaves_position)

	_add_gallery_rafters(root, along_x, length, span, deck_y + clear_height)

	# Short diagonal brackets visibly transfer the projecting gallery load back
	# into the masonry instead of leaving the deck visually unsupported.
	for end in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			var along: float = end * (length * 0.5 - 0.3)
			var offset: float = side * side_offset
			var upper := Vector3(along, deck_y + 0.12, offset)
			var lower := Vector3(
				along, deck_y - MapViewMeshBuilderConfig.WALL_WALK_BRACKET_DROP, offset * 0.45
			)
			if not along_x:
				upper = Vector3(offset, upper.y, along)
				lower = Vector3(offset * 0.45, lower.y, along)
			_add_timber_beam(root, "GalleryBracket%d_%d" % [int(end), int(side)], lower, upper, 0.1)


## Rafter pairs and a ridge beam under the gallery roof. Seen from the wall
## walk the roof underside was a bare tile plane; a medieval covered walk shows
## its oak rafters. Rafters sit just under the gabled_roof_mesh slope (default
## overhang and pitch) so they never poke through the tiles.
static func _add_gallery_rafters(
	root: Node3D, along_x: bool, length: float, span: float, eaves_y: float
) -> void:
	var half_span := span * 0.5 + MapViewMeshBuilderConfig.ROOF_OVERHANG
	var rise := half_span * MapViewMeshBuilderConfig.ROOF_PITCH
	var drop := GALLERY_RAFTER_SIZE * 0.9
	var count := maxi(2, ceili(length / GALLERY_RAFTER_SPACING))
	for index in count + 1:
		var along := (float(index) / float(count) - 0.5) * (length - 0.3)
		for side: float in [-1.0, 1.0]:
			var eave := Vector3(along, eaves_y - drop, side * (half_span - 0.12))
			var ridge := Vector3(along, eaves_y + rise - drop * 1.4, side * 0.05)
			if not along_x:
				eave = Vector3(eave.z, eave.y, eave.x)
				ridge = Vector3(ridge.z, ridge.y, ridge.x)
			_add_timber_beam(
				root, "GalleryRafter%d_%d" % [index, int(side)], eave, ridge, GALLERY_RAFTER_SIZE
			)
	var ridge_size := (
		Vector3(length, GALLERY_RAFTER_SIZE * 1.3, GALLERY_RAFTER_SIZE * 1.3)
		if along_x
		else Vector3(GALLERY_RAFTER_SIZE * 1.3, GALLERY_RAFTER_SIZE * 1.3, length)
	)
	_timber_box(
		root,
		"GalleryRidgeBeam",
		ridge_size,
		Vector3(0.0, eaves_y + rise - drop * 2.2, 0.0)
	)


static func add_base_arcades(
	root: Node3D, building: Dictionary, size: Vector2, world_bounds: Rect2 = Rect2()
) -> void:
	var along_x := size.x >= size.y
	var length := size.x if along_x else size.y
	var depth := size.y if along_x else size.x
	var bay_count := maxi(1, floori(length / MapViewMeshBuilderConfig.WALL_BASE_ARCADE_BAY_WIDTH))
	var bay_width := length / float(bay_count)
	var radius := minf(bay_width * 0.42, MapViewMeshBuilderConfig.WALL_BASE_ARCADE_MAX_RADIUS)
	var spring_y := MapViewMeshBuilderConfig.WALL_BASE_ARCADE_SPRING_HEIGHT
	var face_offset := depth * 0.5 + MapViewMeshBuilderConfig.WALL_BASE_ARCADE_DEPTH * 0.5
	var stone_color := (
		Color(building.get("wall_color", MapViewMeshBuilderConfig.DEFAULT_WALL_COLOR))
		. lightened(0.1)
	)
	var material := MapViewMaterials.fortification_masonry(stone_color)
	var pier_transforms: Array[Transform3D] = []
	var pier_colors: Array[Color] = []
	var arc_transforms: Array[Transform3D] = []
	var arc_colors: Array[Color] = []
	var segment_count := 9
	var segment_length := PI * radius / float(segment_count) * 1.12
	var side := _interior_arcade_side(building, along_x, world_bounds)
	var normal := Vector3(0.0, 0.0, side) if along_x else Vector3(side, 0.0, 0.0)

	for pier_index in bay_count + 1:
		var along := -length * 0.5 + float(pier_index) * bay_width
		var pier_position := (
			Vector3(along, spring_y * 0.5, side * face_offset)
			if along_x
			else Vector3(side * face_offset, spring_y * 0.5, along)
		)
		pier_transforms.append(Transform3D(Basis.IDENTITY, pier_position))
		pier_colors.append(Color.WHITE)
	for bay_index in bay_count:
		var center := -length * 0.5 + (float(bay_index) + 0.5) * bay_width
		for segment_index in segment_count:
			var angle := (float(segment_index) + 0.5) / float(segment_count) * PI
			var along := center + cos(angle) * radius
			var position := (
				Vector3(along, spring_y + sin(angle) * radius, side * face_offset)
				if along_x
				else Vector3(side * face_offset, spring_y + sin(angle) * radius, along)
			)
			var tangent := (
				(
					(Vector3.RIGHT if along_x else Vector3.BACK) * -sin(angle)
					+ Vector3.UP * cos(angle)
				)
				. normalized()
			)
			var radial := normal.cross(tangent).normalized()
			arc_transforms.append(Transform3D(Basis(tangent, radial, normal), position))
			arc_colors.append(Color.WHITE)

	var pier_mesh := BoxMesh.new()
	pier_mesh.size = (
		Vector3(
			MapViewMeshBuilderConfig.WALL_BASE_ARCADE_STONE_WIDTH,
			spring_y,
			MapViewMeshBuilderConfig.WALL_BASE_ARCADE_DEPTH
		)
		if along_x
		else Vector3(
			MapViewMeshBuilderConfig.WALL_BASE_ARCADE_DEPTH,
			spring_y,
			MapViewMeshBuilderConfig.WALL_BASE_ARCADE_STONE_WIDTH
		)
	)
	root.add_child(
		MapViewMeshBuilderPrimitives.multi_mesh(
			"BaseArcadePiers", pier_mesh, pier_transforms, pier_colors, material, Vector3.ZERO
		)
	)
	var arc_mesh := BoxMesh.new()
	arc_mesh.size = Vector3(
		segment_length,
		MapViewMeshBuilderConfig.WALL_BASE_ARCADE_STONE_WIDTH,
		MapViewMeshBuilderConfig.WALL_BASE_ARCADE_DEPTH
	)
	root.add_child(
		MapViewMeshBuilderPrimitives.multi_mesh(
			"BaseArcades", arc_mesh, arc_transforms, arc_colors, material, Vector3.ZERO
		)
	)


static func _interior_arcade_side(
	building: Dictionary, along_x: bool, world_bounds: Rect2
) -> float:
	var authored_side := StringName(building.get("interior_side", &""))
	if along_x and authored_side in [&"north", &"south"]:
		return -1.0 if authored_side == &"north" else 1.0
	if not along_x and authored_side in [&"west", &"east"]:
		return -1.0 if authored_side == &"west" else 1.0
	if world_bounds.has_area():
		var footprint: Rect2 = building["footprint"]
		var center := footprint.get_center()
		var map_center := world_bounds.get_center()
		# WHY: boundary city walls face the playable city toward the map centre.
		# Ambiguous interior circuits may author interior_side instead.
		return 1.0 if (center.y < map_center.y if along_x else center.x < map_center.x) else -1.0
	return 1.0


static func _add_timber_beam(
	root: Node3D, name: String, from: Vector3, to: Vector3, thickness: float
) -> void:
	var direction := to - from
	if direction.is_zero_approx():
		return
	var beam := MeshInstance3D.new()
	beam.name = name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, direction.length())
	beam.mesh = mesh
	beam.position = (from + to) * 0.5
	var up := Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
	beam.basis = Basis.looking_at(direction.normalized(), up)
	beam.material_override = MapViewMaterials.hewn_timber_for_size(mesh.size, name.hash())
	root.add_child(beam)


## Hewn-oak gallery member. Grain follows the long axis of the box so posts,
## rails and eaves read as adzed timber rather than painted sticks.
static func _timber_box(root: Node3D, name: String, size: Vector3, position: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = MapViewMaterials.hewn_timber_for_size(size, name.hash())
	root.add_child(instance)


static func add_battlements(
	root: Node3D, building: Dictionary, size: Vector2, height: float
) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var half := size * 0.5
	var tower := size.x <= 3.4 and size.y <= 3.4
	var edges: Array = []
	if tower or size.x >= size.y:
		edges.append([Vector3(-half.x, 0.0, -half.y), Vector3(half.x, 0.0, -half.y)])
		edges.append([Vector3(-half.x, 0.0, half.y), Vector3(half.x, 0.0, half.y)])
	if tower or size.y > size.x:
		edges.append([Vector3(-half.x, 0.0, -half.y), Vector3(-half.x, 0.0, half.y)])
		edges.append([Vector3(half.x, 0.0, -half.y), Vector3(half.x, 0.0, half.y)])
	for edge in edges:
		var from: Vector3 = edge[0]
		var to: Vector3 = edge[1]
		var length := from.distance_to(to)
		var count := maxi(2, int(length / MapViewMeshBuilderConfig.MERLON_SPACING))
		for step in count + 1:
			var origin := from.lerp(to, float(step) / float(count))
			origin.y = (
				height
				+ MapViewMeshBuilderConfig.CAP_HEIGHT
				+ MapViewMeshBuilderConfig.MERLON_SIZE.y * 0.5
			)
			transforms.append(Transform3D(Basis.IDENTITY, origin))
			colors.append(Color.WHITE)
	var merlon_mesh := BoxMesh.new()
	merlon_mesh.size = MapViewMeshBuilderConfig.MERLON_SIZE
	var merlons := MapViewMeshBuilderPrimitives.multi_mesh(
		"Merlons",
		merlon_mesh,
		transforms,
		colors,
		MapViewMaterials.fortification_masonry(
			Color(building.get("wall_color", MapViewMeshBuilderConfig.DEFAULT_WALL_COLOR))
			. lightened(0.12)
		),
		Vector3.ZERO
	)
	root.add_child(merlons)
