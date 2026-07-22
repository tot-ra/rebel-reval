class_name MapViewMeshBuilderHouseStructure
extends RefCounted

## Wall construction details and plinths shared by ordinary houses.

const _Styles := preload("res://scripts/map/view3d/map_view_mesh_builder_house_styles.gd")
const _RoofDressing := preload("res://scripts/map/view3d/map_view_mesh_builder_house_roof_dressing.gd")


static func add_house_structure(
	root: Node3D,
	building: Dictionary,
	size: Vector2,
	height: float,
	along_ridge_x: bool
) -> void:
	var style := _Styles.house_style(building)
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
	_RoofDressing.add_roof_trim(root, building, size, height, along_ridge_x)

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
