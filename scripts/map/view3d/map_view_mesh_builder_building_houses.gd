class_name MapViewMeshBuilderBuildingHouses
extends RefCounted

## House materials, structural dressing, chimneys, and historic civic silhouettes.


static func house_style(building: Dictionary) -> StringName:
	match StringName(building.get("wall_material", &"")):
		&"plaster", &"timber":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER
		&"brick":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK
		&"plank":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_PLANK
		&"log":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_LOG
		&"limestone", &"stone":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_STONE
	var roll := absi(String(building["id"]).hash()) % 20
	# 1343 mix: log dominates, plaster/plank common, limestone emerging, brick rare.
	if roll < 9:
		return MapViewMeshBuilderConfig.HOUSE_STYLE_LOG
	if roll < 13:
		return MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER
	if roll < 17:
		return MapViewMeshBuilderConfig.HOUSE_STYLE_PLANK
	if roll < 19:
		return MapViewMeshBuilderConfig.HOUSE_STYLE_STONE
	return MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK


static func house_wall_material(building: Dictionary, wall_color: Color, size: Vector3) -> StandardMaterial3D:
	match house_style(building):
		MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER:
			return MapViewMaterials.wall_surface_for_size(&"plaster", wall_color.lerp(MapViewMeshBuilderConfig.PLASTER_TONE, 0.55), size)
		MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK:
			return MapViewMaterials.wall_surface_for_size(&"brick", wall_color.lerp(MapViewMeshBuilderConfig.BRICK_TONE, 0.6), size)
		MapViewMeshBuilderConfig.HOUSE_STYLE_LOG:
			return MapViewMaterials.wall_surface_for_size(&"log", wall_color.lerp(MapViewMeshBuilderConfig.LOG_TONE, 0.45), size)
		MapViewMeshBuilderConfig.HOUSE_STYLE_STONE:
			return MapViewMaterials.wall_surface_for_size(&"limestone", wall_color.lerp(MapViewMeshBuilderConfig.LIMESTONE_TONE, 0.5), size)
		_:
			return MapViewMaterials.wall_surface_for_size(&"plank", wall_color, size)


static func roof_style(building: Dictionary) -> StringName:
	match StringName(building.get("roof_material", &"")):
		&"tile":
			return MapViewMeshBuilderConfig.ROOF_STYLE_TILE
		&"shingle":
			return MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE
		&"thatch", &"straw":
			return MapViewMeshBuilderConfig.ROOF_STYLE_THATCH
	match house_style(building):
		MapViewMeshBuilderConfig.HOUSE_STYLE_STONE, MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK:
			return MapViewMeshBuilderConfig.ROOF_STYLE_TILE
		MapViewMeshBuilderConfig.HOUSE_STYLE_LOG:
			if absi(String(building["id"]).hash() / 10) % 3 < 2:
				return MapViewMeshBuilderConfig.ROOF_STYLE_THATCH
			return MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE
		_:
			return MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE


static func house_roof_material(building: Dictionary) -> StandardMaterial3D:
	var color := Color(building.get("roof_color", MapViewMeshBuilderConfig.DEFAULT_ROOF_COLOR))
	var style := roof_style(building)
	if style == MapViewMeshBuilderConfig.ROOF_STYLE_THATCH:
		# Pull authored dark browns toward weathered reed so fishing-district
		# thatch stays golden-olive instead of reading as rotten wood.
		color = color.lerp(MapViewMeshBuilderConfig.THATCH_TONE, 0.45 if building.has("roof_material") else 0.55)
	return MapViewMaterials.roof_surface(style, color)


static func add_house_structure(
	root: Node3D,
	building: Dictionary,
	size: Vector2,
	height: float,
	along_ridge_x: bool
) -> void:
	var style := house_style(building)
	MapViewMeshBuilderPrimitives.box(
		root,
		"Plinth",
		Vector3(size.x + 0.12, MapViewMeshBuilderConfig.PLINTH_HEIGHT, size.y + 0.12),
		Vector3(0.0, MapViewMeshBuilderConfig.PLINTH_HEIGHT * 0.5, 0.0),
		&"stone"
	)
	match style:
		MapViewMeshBuilderConfig.HOUSE_STYLE_STONE, MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK:
			_add_masonry_dressing(root, size, height)
		MapViewMeshBuilderConfig.HOUSE_STYLE_LOG:
			_add_log_corner_ends(root, size, height)
		MapViewMeshBuilderConfig.HOUSE_STYLE_PLANK:
			_add_plank_battens(root, size, height)
		MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER:
			# Plastered wall with corner posts and wall plates only. Diagonal
			# Fachwerk braces are omitted: they were never characteristic of
			# 1343 Reval (see docs/HISTORICAL_AUDIT.md Building Materials Mix).
			_add_plaster_timber_posts(root, size, height)
	add_roof_trim(root, building, size, height, along_ridge_x)


## Bargeboards on gable ends, eaves fascia on the long sides, and a thin ridge
## board break the pure prism roof silhouette at dimetric distance. Reed thatch
## swaps the timber trim for soft ridge/edge rolls and a hanging eaves fringe.
static func add_roof_trim(
	root: Node3D,
	building: Dictionary,
	size: Vector2,
	height: float,
	along_ridge_x: bool
) -> void:
	if roof_style(building) == MapViewMeshBuilderConfig.ROOF_STYLE_THATCH:
		_add_thatch_dressing(root, building, size, height, along_ridge_x)
		return
	var half := size * 0.5
	var overhang := MapViewMeshBuilderConfig.ROOF_OVERHANG
	var rise := ((size.y if along_ridge_x else size.x) * 0.5 + overhang) * MapViewMeshBuilderConfig.ROOF_PITCH
	var barge := MapViewMeshBuilderConfig.HOUSE_BARGEBOARD_THICKNESS
	var fascia_h := MapViewMeshBuilderConfig.HOUSE_EAVES_FASCIA_HEIGHT
	if along_ridge_x:
		var gable_span := size.y + overhang * 2.0
		var rake := sqrt(pow(gable_span * 0.5, 2.0) + pow(rise, 2.0))
		for side_x in [-1.0, 1.0]:
			for slope in [-1.0, 1.0]:
				var board := MeshInstance3D.new()
				board.name = "Bargeboard_%d_%d" % [int(side_x), int(slope)]
				var board_mesh := BoxMesh.new()
				board_mesh.size = Vector3(barge, barge * 0.85, rake)
				board.mesh = board_mesh
				board.position = Vector3(
					side_x * (half.x + overhang * 0.35),
					height + rise * 0.5,
					slope * gable_span * 0.25
				)
				board.rotation.x = slope * atan2(rise, gable_span * 0.5)
				board.material_override = MapViewMaterials.role(&"timber")
				root.add_child(board)
		for side_z in [-1.0, 1.0]:
			MapViewMeshBuilderPrimitives.box(
				root,
				"EavesFascia_%d" % int(side_z),
				Vector3(size.x + overhang * 2.0, fascia_h, barge),
				Vector3(0.0, height + fascia_h * 0.35, side_z * (half.y + overhang * 0.55)),
				&"timber"
			)
		MapViewMeshBuilderPrimitives.box(
			root,
			"RidgeBoard",
			Vector3(size.x + overhang * 2.0, MapViewMeshBuilderConfig.HOUSE_RIDGE_BOARD_HEIGHT, barge),
			Vector3(0.0, height + rise + MapViewMeshBuilderConfig.HOUSE_RIDGE_BOARD_HEIGHT * 0.35, 0.0),
			&"timber"
		)
	else:
		var gable_span := size.x + overhang * 2.0
		var rake := sqrt(pow(gable_span * 0.5, 2.0) + pow(rise, 2.0))
		for side_z in [-1.0, 1.0]:
			for slope in [-1.0, 1.0]:
				var board := MeshInstance3D.new()
				board.name = "Bargeboard_%d_%d" % [int(side_z), int(slope)]
				var board_mesh := BoxMesh.new()
				board_mesh.size = Vector3(rake, barge * 0.85, barge)
				board.mesh = board_mesh
				board.position = Vector3(
					slope * gable_span * 0.25,
					height + rise * 0.5,
					side_z * (half.y + overhang * 0.35)
				)
				board.rotation.z = -slope * atan2(rise, gable_span * 0.5)
				board.material_override = MapViewMaterials.role(&"timber")
				root.add_child(board)
		for side_x in [-1.0, 1.0]:
			MapViewMeshBuilderPrimitives.box(
				root,
				"EavesFascia_%d" % int(side_x),
				Vector3(barge, fascia_h, size.y + overhang * 2.0),
				Vector3(side_x * (half.x + overhang * 0.55), height + fascia_h * 0.35, 0.0),
				&"timber"
			)
		MapViewMeshBuilderPrimitives.box(
			root,
			"RidgeBoard",
			Vector3(barge, MapViewMeshBuilderConfig.HOUSE_RIDGE_BOARD_HEIGHT, size.y + overhang * 2.0),
			Vector3(0.0, height + rise + MapViewMeshBuilderConfig.HOUSE_RIDGE_BOARD_HEIGHT * 0.35, 0.0),
			&"timber"
		)


## Soft reed ridge roll, gable-edge rolls, and a hanging eaves fringe so thatch
## roofs read as bundled reed volume rather than a thin timber-trimmed prism.
static func _add_thatch_dressing(
	root: Node3D,
	building: Dictionary,
	size: Vector2,
	height: float,
	along_ridge_x: bool
) -> void:
	var half := size * 0.5
	var overhang := MapViewMeshBuilderConfig.THATCH_ROOF_OVERHANG
	var rise := ((size.y if along_ridge_x else size.x) * 0.5 + overhang) * MapViewMeshBuilderConfig.ROOF_PITCH
	var thatch_mat := house_roof_material(building)
	var fringe_mat := MapViewMaterials.roof_surface(
		MapViewMeshBuilderConfig.ROOF_STYLE_THATCH,
		MapViewMeshBuilderConfig.THATCH_TONE.darkened(0.12)
	)
	var ridge_r := MapViewMeshBuilderConfig.THATCH_RIDGE_RADIUS
	var edge_r := MapViewMeshBuilderConfig.THATCH_EDGE_ROLL
	var fringe_h := MapViewMeshBuilderConfig.THATCH_EAVES_FRINGE_HEIGHT
	var fringe_d := MapViewMeshBuilderConfig.THATCH_EAVES_FRINGE_DEPTH

	var ridge := MeshInstance3D.new()
	ridge.name = "ThatchRidge"
	var ridge_mesh := CylinderMesh.new()
	ridge_mesh.top_radius = ridge_r
	ridge_mesh.bottom_radius = ridge_r * 1.05
	ridge_mesh.radial_segments = 10
	if along_ridge_x:
		ridge_mesh.height = size.x + overhang * 2.0 + ridge_r
		ridge.rotation.z = PI * 0.5
	else:
		ridge_mesh.height = size.y + overhang * 2.0 + ridge_r
		ridge.rotation.x = PI * 0.5
	ridge.mesh = ridge_mesh
	ridge.position = Vector3(0.0, height + rise + ridge_r * 0.35, 0.0)
	ridge.material_override = thatch_mat
	root.add_child(ridge)

	if along_ridge_x:
		var gable_span := size.y + overhang * 2.0
		var rake := sqrt(pow(gable_span * 0.5, 2.0) + pow(rise, 2.0))
		var rake_angle := atan2(rise, gable_span * 0.5)
		for side_x in [-1.0, 1.0]:
			for slope in [-1.0, 1.0]:
				var roll := MeshInstance3D.new()
				roll.name = "ThatchEdge_%d_%d" % [int(side_x), int(slope)]
				var roll_mesh := CylinderMesh.new()
				roll_mesh.top_radius = edge_r
				roll_mesh.bottom_radius = edge_r
				roll_mesh.height = rake
				roll_mesh.radial_segments = 8
				roll.mesh = roll_mesh
				roll.position = Vector3(
					side_x * (half.x + overhang * 0.55),
					height + rise * 0.5,
					slope * gable_span * 0.25
				)
				roll.rotation.x = slope * rake_angle
				roll.material_override = thatch_mat
				root.add_child(roll)
		for side_z in [-1.0, 1.0]:
			var fringe := MeshInstance3D.new()
			fringe.name = "ThatchEavesFringe_%d" % int(side_z)
			var fringe_mesh := BoxMesh.new()
			fringe_mesh.size = Vector3(size.x + overhang * 2.0, fringe_h, fringe_d)
			fringe.mesh = fringe_mesh
			fringe.position = Vector3(
				0.0,
				height - fringe_h * 0.15,
				side_z * (half.y + overhang * 0.85)
			)
			fringe.material_override = fringe_mat
			root.add_child(fringe)
	else:
		var gable_span := size.x + overhang * 2.0
		var rake := sqrt(pow(gable_span * 0.5, 2.0) + pow(rise, 2.0))
		var rake_angle := atan2(rise, gable_span * 0.5)
		for side_z in [-1.0, 1.0]:
			for slope in [-1.0, 1.0]:
				var roll := MeshInstance3D.new()
				roll.name = "ThatchEdge_%d_%d" % [int(side_z), int(slope)]
				var roll_mesh := CylinderMesh.new()
				roll_mesh.top_radius = edge_r
				roll_mesh.bottom_radius = edge_r
				roll_mesh.height = rake
				roll_mesh.radial_segments = 8
				roll.mesh = roll_mesh
				roll.position = Vector3(
					slope * gable_span * 0.25,
					height + rise * 0.5,
					side_z * (half.y + overhang * 0.55)
				)
				roll.rotation.z = -slope * rake_angle
				roll.material_override = thatch_mat
				root.add_child(roll)
		for side_x in [-1.0, 1.0]:
			var fringe := MeshInstance3D.new()
			fringe.name = "ThatchEavesFringe_%d" % int(side_x)
			var fringe_mesh := BoxMesh.new()
			fringe_mesh.size = Vector3(fringe_d, fringe_h, size.y + overhang * 2.0)
			fringe.mesh = fringe_mesh
			fringe.position = Vector3(
				side_x * (half.x + overhang * 0.85),
				height - fringe_h * 0.15,
				0.0
			)
			fringe.material_override = fringe_mat
			root.add_child(fringe)


static func _add_masonry_dressing(root: Node3D, size: Vector2, height: float) -> void:
	var half := size * 0.5
	var qw := MapViewMeshBuilderConfig.HOUSE_QUOIN_WIDTH
	var qd := MapViewMeshBuilderConfig.HOUSE_QUOIN_DEPTH
	var course := 0
	var y := MapViewMeshBuilderConfig.PLINTH_HEIGHT + qw * 0.55
	while y + qw * 0.4 < height - 0.15:
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			MapViewMeshBuilderPrimitives.box(
				root,
				"Quoin_%d_%d_%d" % [course, int(corner.x), int(corner.y)],
				Vector3(qw, qw * 0.85, qd),
				Vector3(corner.x * (half.x - qw * 0.15), y, corner.y * (half.y + qd * 0.35)),
				&"stone"
			)
			MapViewMeshBuilderPrimitives.box(
				root,
				"QuoinSide_%d_%d_%d" % [course, int(corner.x), int(corner.y)],
				Vector3(qd, qw * 0.85, qw),
				Vector3(corner.x * (half.x + qd * 0.35), y, corner.y * (half.y - qw * 0.15)),
				&"stone"
			)
		course += 1
		y += qw * 1.15
	var cornice_h := MapViewMeshBuilderConfig.HOUSE_CORNICE_HEIGHT
	var cornice_d := MapViewMeshBuilderConfig.HOUSE_CORNICE_DEPTH
	MapViewMeshBuilderPrimitives.box(
		root,
		"Cornice",
		Vector3(size.x + cornice_d * 2.0, cornice_h, size.y + cornice_d * 2.0),
		Vector3(0.0, height - cornice_h * 0.35, 0.0),
		&"stone"
	)


static func _add_log_corner_ends(root: Node3D, size: Vector2, height: float) -> void:
	var half := size * 0.5
	var thick := MapViewMeshBuilderConfig.HOUSE_LOG_END_THICKNESS
	var protrude := MapViewMeshBuilderConfig.HOUSE_LOG_END_PROTRUSION
	var spacing := MapViewMeshBuilderConfig.HOUSE_LOG_END_SPACING
	var row := 0
	var y := MapViewMeshBuilderConfig.PLINTH_HEIGHT + thick * 0.55
	while y + thick * 0.4 < height - 0.1:
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			# Alternating axis per course mimics notched log corners without
			# inventing a full log mesh (reads from dimetric distance).
			if row % 2 == 0:
				MapViewMeshBuilderPrimitives.box(
					root,
					"LogEnd_%d_%d_%d" % [row, int(corner.x), int(corner.y)],
					Vector3(thick * 1.15, thick, protrude),
					Vector3(corner.x * half.x, y, corner.y * (half.y + protrude * 0.35)),
					&"timber"
				)
			else:
				MapViewMeshBuilderPrimitives.box(
					root,
					"LogEnd_%d_%d_%d" % [row, int(corner.x), int(corner.y)],
					Vector3(protrude, thick, thick * 1.15),
					Vector3(corner.x * (half.x + protrude * 0.35), y, corner.y * half.y),
					&"timber"
				)
		row += 1
		y += spacing


static func _add_plank_battens(root: Node3D, size: Vector2, height: float) -> void:
	var half := size * 0.5
	var bw := MapViewMeshBuilderConfig.HOUSE_PLANK_BATTEN_WIDTH
	var bd := MapViewMeshBuilderConfig.HOUSE_PLANK_BATTEN_DEPTH
	var post_h := height - MapViewMeshBuilderConfig.PLINTH_HEIGHT
	var post_y := MapViewMeshBuilderConfig.PLINTH_HEIGHT + post_h * 0.5
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		MapViewMeshBuilderPrimitives.box(
			root,
			"CornerBoard_%d_%d" % [int(corner.x), int(corner.y)],
			Vector3(bw * 1.4, post_h, bw * 1.4),
			Vector3(corner.x * half.x, post_y, corner.y * half.y),
			&"timber"
		)
	# Mid-wall vertical battens on the longer street faces only.
	var along_x := size.x >= size.y
	var face_len := size.x if along_x else size.y
	var count := clampi(int(face_len / 1.6), 1, 4)
	for index in count:
		var along := (float(index + 1) / float(count + 1) - 0.5) * face_len
		if along_x:
			MapViewMeshBuilderPrimitives.box(
				root,
				"BattenN%d" % index,
				Vector3(bw, post_h * 0.92, bd),
				Vector3(along, post_y, half.y),
				&"timber"
			)
			MapViewMeshBuilderPrimitives.box(
				root,
				"BattenS%d" % index,
				Vector3(bw, post_h * 0.92, bd),
				Vector3(along, post_y, -half.y),
				&"timber"
			)
		else:
			MapViewMeshBuilderPrimitives.box(
				root,
				"BattenE%d" % index,
				Vector3(bd, post_h * 0.92, bw),
				Vector3(half.x, post_y, along),
				&"timber"
			)
			MapViewMeshBuilderPrimitives.box(
				root,
				"BattenW%d" % index,
				Vector3(bd, post_h * 0.92, bw),
				Vector3(-half.x, post_y, along),
				&"timber"
			)


static func _add_plaster_timber_posts(root: Node3D, size: Vector2, height: float) -> void:
	var half := size * 0.5
	var beam := MapViewMeshBuilderConfig.FRAME_BEAM_THICKNESS
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		MapViewMeshBuilderPrimitives.box(
			root,
			"CornerPost_%d_%d" % [int(corner.x), int(corner.y)],
			Vector3(beam, height, beam),
			Vector3(corner.x * half.x, height * 0.5, corner.y * half.y),
			&"timber"
		)
	var beam_heights := [
		MapViewMeshBuilderConfig.PLINTH_HEIGHT + beam * 0.5,
		height * 0.55,
		height - beam * 0.5,
	]
	for beam_y: float in beam_heights:
		MapViewMeshBuilderPrimitives.box(
			root,
			"BeamNS%d" % int(beam_y * 100.0),
			Vector3(size.x + beam, beam, beam),
			Vector3(0.0, beam_y, half.y),
			&"timber"
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"BeamNS%dB" % int(beam_y * 100.0),
			Vector3(size.x + beam, beam, beam),
			Vector3(0.0, beam_y, -half.y),
			&"timber"
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"BeamEW%d" % int(beam_y * 100.0),
			Vector3(beam, beam, size.y + beam),
			Vector3(half.x, beam_y, 0.0),
			&"timber"
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"BeamEW%dB" % int(beam_y * 100.0),
			Vector3(beam, beam, size.y + beam),
			Vector3(-half.x, beam_y, 0.0),
			&"timber"
		)


static func add_historic_building_details(
	root: Node3D,
	building: Dictionary,
	size: Vector2,
	height: float,
	along_ridge_x: bool
) -> void:
	match StringName(building.get("primitive", &"")):
		&"town_hall_1343":
			_add_early_town_hall_details(root, size, height)
		&"holy_spirit_chapel_1343":
			_add_holy_spirit_chapel_details(root, size, height)
		&"stepped_gable_merchant":
			_add_stepped_merchant_gable(root, size, height, along_ridge_x)


static func _add_early_town_hall_details(root: Node3D, size: Vector2, height: float) -> void:
	var facade_z := -size.y * 0.5 - 0.13
	var rear_z := size.y * 0.5 + 0.11
	var bay_count := clampi(int(size.x / 1.95), 5, 9)
	var bay_width := minf(1.35, size.x / float(bay_count) * 0.62)
	for index in bay_count:
		var x := (float(index + 1) / float(bay_count + 1) - 0.5) * size.x
		var arch_height := minf(1.45, height * 0.40)
		MapViewMeshBuilderPrimitives.box(
			root,
			"ArcadePier%02d" % index,
			Vector3(0.20, arch_height, 0.26),
			Vector3(x - bay_width * 0.5, arch_height * 0.5, facade_z),
			&"stone"
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"ArcadeLintel%02d" % index,
			Vector3(bay_width, 0.18, 0.26),
			Vector3(x, arch_height, facade_z),
			&"stone"
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"ArcadeShadow%02d" % index,
			Vector3(maxf(0.24, bay_width - 0.26), maxf(0.45, arch_height - 0.28), 0.04),
			Vector3(x, maxf(0.45, arch_height - 0.28) * 0.5, facade_z - 0.05),
			&"window"
		)
	MapViewMeshBuilderPrimitives.box(
		root,
		"CouncilDoorSurround",
		Vector3(1.18, minf(2.05, height * 0.56), 0.14),
		Vector3(size.x * 0.28, minf(2.05, height * 0.56) * 0.5, facade_z - 0.09),
		&"stone"
	)
	for side_x in [-size.x * 0.5 + 0.55, size.x * 0.5 - 0.55]:
		MapViewMeshBuilderPrimitives.box(
			root,
			"TownHallCornerButtress%.0f" % side_x,
			Vector3(0.34, height * 0.92, 0.34),
			Vector3(side_x, height * 0.46, facade_z + 0.05),
			&"stone"
		)
	var step_count := 5
	for index in step_count:
		var step_width := size.y * (0.55 - float(index) * 0.075)
		var step_height := height + 0.18 + float(index) * 0.24
		for x_side in [-1.0, 1.0]:
			MapViewMeshBuilderPrimitives.box(
				root,
				"TownHallGableStep%02d_%s" % [index, "E" if x_side > 0.0 else "W"],
				Vector3(0.24, 0.22, maxf(0.32, step_width)),
				Vector3(x_side * (size.x * 0.5 + 0.05), step_height, 0.0),
				&"stone"
			)
	var dais_height := minf(0.24, height * 0.08)
	MapViewMeshBuilderPrimitives.box(
		root,
		"TownHallMarketStoop",
		Vector3(size.x * 0.72, dais_height, 0.78),
		Vector3(0.0, dais_height * 0.5, facade_z - 0.42),
		&"stone"
	)
	var rear_window_count := clampi(int(size.x / 3.2), 3, 6)
	for index in rear_window_count:
		var x := (float(index + 1) / float(rear_window_count + 1) - 0.5) * size.x
		MapViewMeshBuilderPrimitives.box(
			root,
			"TownHallRearLancet%02d" % index,
			Vector3(0.36, minf(1.25, height * 0.34), 0.05),
			Vector3(x, height * 0.55, rear_z),
			&"window"
		)


static func _add_holy_spirit_chapel_details(root: Node3D, size: Vector2, height: float) -> void:
	var facade_z := size.y * 0.5 + 0.13
	var window_count := clampi(int(size.x / 2.7), 3, 6)
	for index in window_count:
		var x := (float(index + 1) / float(window_count + 1) - 0.5) * size.x
		var opening_height := minf(1.75, height * 0.42)
		MapViewMeshBuilderPrimitives.box(
			root,
			"Lancet%02d" % index,
			Vector3(0.42, opening_height, 0.06),
			Vector3(x, height * 0.52, facade_z),
			&"window"
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"LancetMullion%02d" % index,
			Vector3(0.055, opening_height, 0.09),
			Vector3(x, height * 0.52, facade_z + 0.04),
			&"stone"
		)
	var cote_x := -size.x * 0.24
	var cote_base := height + 0.2
	MapViewMeshBuilderPrimitives.box(root, "SanctusCote", Vector3(0.72, 1.1, 0.72), Vector3(cote_x, cote_base + 0.55, 0.0), &"stone")
	var cote_roof := MeshInstance3D.new()
	cote_roof.name = "SanctusCoteRoof"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.62
	cone.height = 1.15
	cone.radial_segments = 4
	cote_roof.mesh = cone
	cote_roof.position = Vector3(cote_x, cote_base + 1.1 + cone.height * 0.5, 0.0)
	cote_roof.rotation.y = PI * 0.25
	cote_roof.material_override = MapViewMaterials.roof(Color8(82, 47, 38))
	root.add_child(cote_roof)


static func _add_stepped_merchant_gable(
	root: Node3D,
	size: Vector2,
	height: float,
	along_ridge_x: bool
) -> void:
	var front_side := &"south"
	var facade_width := size.x
	var face_offset := size.y * 0.5
	if along_ridge_x:
		front_side = &"east"
		facade_width = size.y
		face_offset = size.x * 0.5
	var step_widths := [0.78, 0.54, 0.30]
	for index in step_widths.size():
		var step_width := facade_width * float(step_widths[index])
		var step_height := 0.32 + float(index) * 0.18
		MapViewMeshBuilderBuildingFacade.facade_box(
			root,
			"GableStep%02d" % index,
			Vector3(step_width, step_height, 0.32),
			0.0,
			height + 0.18 + float(index) * 0.34,
			front_side,
			face_offset,
			&"stone"
		)
	MapViewMeshBuilderBuildingFacade.facade_box(root, "GablePinnacle", Vector3(0.22, 0.78, 0.28), 0.0, height + 1.42, front_side, face_offset, &"stone")


static func add_chimney(root: Node3D, building: Dictionary, size: Vector2, wall_height: float, ridge_along_x: bool) -> void:
	var building_id: StringName = building["id"]
	var seed := String(building_id).hash()
	var chimney_size := MapViewMeshBuilderConfig.CHIMNEY_SIZE
	var chimney_half := chimney_size * 0.5
	var half_span := (size.y if ridge_along_x else size.x) * 0.5 + MapViewMeshBuilderConfig.ROOF_OVERHANG
	var rise := half_span * MapViewMeshBuilderConfig.ROOF_PITCH
	# Near one ridge end, fully on one slope face so the shaft pierces tiles
	# instead of balancing on the peak like a cube.
	var along := ((size.x if ridge_along_x else size.y) * 0.5 - chimney_size) * 0.62
	if seed % 2 == 0:
		along = -along
	var slope_side := 1.0 if (seed >> 1) % 2 == 0 else -1.0
	var across := slope_side * (chimney_half + MapViewMeshBuilderConfig.CHIMNEY_RIDGE_CLEARANCE)
	var offset := Vector3(along, 0.0, across) if ridge_along_x else Vector3(across, 0.0, along)
	# Embed from the downhill roof edge under the footprint so the whole stack
	# volume intersects the roof plane.
	var across_edge := minf(absf(across) + chimney_half, half_span)
	var roof_y_edge := wall_height + rise * (1.0 - across_edge / half_span)
	var stack_bottom := roof_y_edge - MapViewMeshBuilderConfig.CHIMNEY_STACK_EMBED
	var stack_height := MapViewMeshBuilderConfig.CHIMNEY_STACK_HEIGHT
	var stack_center_y := stack_bottom + stack_height * 0.5
	var top := stack_bottom + stack_height
	MapViewMeshBuilderPrimitives.add_chimney_stack(
		root,
		"Chimney",
		chimney_size,
		stack_height,
		offset + Vector3(0.0, stack_center_y, 0.0)
	)

	if ChimneySmoke3D.schedule_for(seed) == ChimneySmoke3D.Schedule.NEVER:
		return
	var smoke: ChimneySmoke3D = MapViewMeshBuilderConfig.CHIMNEY_SMOKE_SCRIPT.new()
	smoke.position = offset + Vector3(0.0, top + 0.1, 0.0)
	smoke.configure(building_id)
	root.add_child(smoke)


static func add_window_lights(root: Node3D, building_id: StringName) -> void:
	var lights: BuildingWindowLights3D = MapViewMeshBuilderConfig.WINDOW_LIGHTS_SCRIPT.new()
	root.add_child(lights)
	lights.configure(building_id)
