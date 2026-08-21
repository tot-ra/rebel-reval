class_name MapViewMonasticModels
extends RefCounted

## Monastic building fabric for the pre-1343 Padise reconstruction.
##
## WHY: the earlier Padise pass expressed a monastery as roofless interior-wall
## panels, which renders as a stockade rather than a religious house. Two forms
## carry the reading instead:
##
## * `cloister_walk` - a view-only landmark, so the covered walk stays walkable
##   while showing posts, dwarf sill, plate, braces, and a lean-to roof. Villu
##   Kadakas (AVE 2011) records Armin Raam's reading that the Padise cloister
##   galleries may have been timber-framed; this is that timber form, not the
##   later stone gallery.
## * `timber_oratory_1343` - a modest aisle-less timber oratory with a west
##   bellcote, lancet lights, and an east gable cross. The Padise abbey church
##   was consecrated only in 1448, so no stone church may appear in 1343.
##
## Both are uncertainty-aware gameplay reconstructions of a Cistercian house of
## the period, not measured archaeology of a surviving Padise elevation.

const ORATORY_PRIMITIVE := &"timber_oratory_1343"
## Dorter, chapter range and mill floor carried no hearth. Without this opt-out
## the shared house pass puts a plastered flue stack on every timber range and
## the house reads as a row of heated cottages.
const UNHEATED_RANGE_PRIMITIVE := &"unheated_timber_range_1343"
const CLOISTER_WALK_KIND := &"cloister_walk"
const POST_SECTION := 0.17
const POST_SPACING := 1.75
const POST_HEIGHT := 2.45
const PLATE_DEPTH := 0.2
const SILL_HEIGHT := 0.36
const ROOF_THICKNESS := 0.12
const RANGE_EAVES_LIFT := 0.85
const BRACE_LENGTH := 0.55
const PORTAL_WIDTH := 1.18
const PORTAL_HEIGHT := 2.25

const ST_MICHAELS_PRECINCT_PRIMITIVE := &"st_michaels_precinct_1343"
const ST_MICHAELS_CHAPEL_PRIMITIVE := &"st_michaels_chapel_1343"
const ST_MICHAELS_SERVICE_PRIMITIVE := &"st_michaels_service_wing_1343"


static func is_st_michaels_precinct(building: Dictionary) -> bool:
	return StringName(building.get("primitive", &"")) in [
		ST_MICHAELS_PRECINCT_PRIMITIVE,
		ST_MICHAELS_CHAPEL_PRIMITIVE,
		ST_MICHAELS_SERVICE_PRIMITIVE,
	]


## Conservative St Michael's precinct forms for the 1343 snapshot. The source
## does not locate every above-ground range, so the renderer uses a low-detail
## mass, chapel, and service wing instead of inventing a later cloister plan.
static func build_st_michaels_precinct(building: Dictionary, cell_size: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_%s" % String(building["id"])
	root.set_meta(&"renderer_boundary", &"exceptional")
	root.set_meta(&"exceptional_category", &"monastic_precinct")
	root.set_meta(&"monastic_renderer", ST_MICHAELS_PRECINCT_PRIMITIVE)
	root.set_meta(&"historical_confidence", &"reconstructed")

	var scale := MapViewBridge.world_scale(cell_size)
	var footprint: Rect2 = building["footprint"]
	var size := footprint.size * scale
	var height := MapTypes.resolved_wall_height_px(building) * scale
	var center := footprint.get_center() * scale
	root.position = Vector3(center.x, 0.0, center.y)

	var primitive := StringName(building.get("primitive", &""))
	var service := primitive == ST_MICHAELS_SERVICE_PRIMITIVE
	var wall_family: StringName = &"plaster" if service else &"limestone"
	var roof_family: StringName = &"shingle" if service else &"tile"
	var wall_color := Color(building.get("wall_color", Color(0.52, 0.49, 0.43)))
	var roof_color := Color(building.get("roof_color", Color(0.26, 0.16, 0.12)))

	var walls := MeshInstance3D.new()
	walls.name = "PrecinctMass"
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(size.x, height, size.y)
	walls.mesh = wall_mesh
	walls.position = Vector3(0.0, height * 0.5, 0.0)
	walls.material_override = MapViewMaterials.wall_surface_for_building(
		StringName(building.get("id", &"st_michaels_precinct")),
		wall_family,
		wall_color,
		wall_mesh.size
	)
	root.add_child(walls)

	var roof := MeshInstance3D.new()
	roof.name = "PrecinctRoof"
	var along_ridge_x := StringName(building.get("ridge_axis", &"x")) == &"x"
	roof.mesh = MapViewMeshBuilderPrimitives.gabled_roof_mesh(
		size,
		along_ridge_x,
		0.14 if service else 0.18,
		true,
		0.68 if service else 0.78
	)
	roof.position = Vector3(0.0, height, 0.0)
	roof.material_override = MapViewMaterials.roof_surface_for_building(
		StringName(building.get("id", &"st_michaels_precinct")), roof_family, roof_color
	)
	root.add_child(roof)

	if primitive == ST_MICHAELS_CHAPEL_PRIMITIVE:
		_add_st_michaels_chapel_details(root, size, height, along_ridge_x)
	elif service:
		_add_st_michaels_service_details(root, size, height, along_ridge_x)
	else:
		_add_st_michaels_convent_details(root, size, height, along_ridge_x)
	return root


static func _add_st_michaels_convent_details(
	root: Node3D, size: Vector2, height: float, along_ridge_x: bool
) -> void:
	# A plain entry and a few openings establish a convent mass without a later
	# cloister arcade, grand tower, or tourist-restored facade.
	_add_precinct_portal(root, "PrecinctPortal", height, &"east", 0.0)
	var face := size.y * 0.5 + 0.055 if along_ridge_x else size.x * 0.5 + 0.055
	for index in 3:
		var along := (float(index + 1) / 4.0 - 0.5) * (size.x if along_ridge_x else size.y)
		var position := (
			Vector3(along, height * 0.56, face)
			if along_ridge_x
			else Vector3(face, height * 0.56, along)
		)
		var window_size := Vector3(0.28, minf(1.1, height * 0.34), 0.08)
		if not along_ridge_x:
			window_size = Vector3(0.08, minf(1.1, height * 0.34), 0.28)
		MapViewMeshBuilderPrimitives.box(
			root,
			"PrecinctWindow_%02d" % index,
			window_size,
			position,
			&"window"
		)


static func _add_st_michaels_chapel_details(
	root: Node3D, size: Vector2, height: float, along_ridge_x: bool
) -> void:
	var face := size.y * 0.5 + 0.06 if along_ridge_x else size.x * 0.5 + 0.06
	for index in 2:
		var along := (float(index + 1) / 3.0 - 0.5) * (size.x if along_ridge_x else size.y)
		var position := (
			Vector3(along, height * 0.52, face)
			if along_ridge_x
			else Vector3(face, height * 0.52, along)
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"ChapelLancet_%02d" % index,
			Vector3(0.24, minf(1.4, height * 0.4), 0.08)
			if along_ridge_x
			else Vector3(0.08, minf(1.4, height * 0.4), 0.24),
			position,
			&"window"
		)
	_add_precinct_portal(root, "ChapelPortal", height, &"south", 0.0)
	# A small timber bellcote keeps the chapel legible without a later stone tower.
	var bellcote := Node3D.new()
	bellcote.name = "ChapelBellcote"
	bellcote.position = (
		Vector3(-size.x * 0.32, height, 0.0)
		if along_ridge_x
		else Vector3(0.0, height, -size.y * 0.32)
	)
	root.add_child(bellcote)
	MapViewMeshBuilderPrimitives.box(
		bellcote,
		"BellcotePostA",
		Vector3(0.12, 0.8, 0.12),
		Vector3(-0.28, 0.4, 0.0),
		&"timber"
	)
	MapViewMeshBuilderPrimitives.box(
		bellcote,
		"BellcotePostB",
		Vector3(0.12, 0.8, 0.12),
		Vector3(0.28, 0.4, 0.0),
		&"timber"
	)
	MapViewMeshBuilderPrimitives.box(
		bellcote,
		"BellcoteBeam",
		Vector3(0.7, 0.12, 0.12),
		Vector3(0.0, 0.76, 0.0),
		&"timber"
	)


static func _add_st_michaels_service_details(
	root: Node3D, size: Vector2, height: float, along_ridge_x: bool
) -> void:
	_add_precinct_portal(root, "ServiceDoor", height, &"north", 0.0)
	var beam_size := (
		Vector3(size.x * 0.72, 0.12, 0.12)
		if along_ridge_x
		else Vector3(0.12, 0.12, size.y * 0.72)
	)
	MapViewMeshBuilderPrimitives.box(
		root,
		"ServiceWallPlate",
		beam_size,
		Vector3(0.0, height * 0.48, -size.y * 0.5 - 0.06)
		if along_ridge_x
		else Vector3(-size.x * 0.5 - 0.06, height * 0.48, 0.0),
		&"timber"
	)


static func _add_precinct_portal(
	root: Node3D, node_name: String, height: float, side: StringName, along: float
) -> void:
	var transform := MapViewDoorBuilder.facade_transform(
		along, side, 0.0, MapViewMeshBuilderConfig.DOOR_THICKNESS
	)
	MapViewDoorBuilder.add_leaf(
		root,
		node_name,
		node_name,
		minf(PORTAL_WIDTH, 1.0),
		minf(PORTAL_HEIGHT, height - 0.2),
		MapViewMeshBuilderConfig.DOOR_THICKNESS,
		transform,
		String(node_name).hash()
	)
	MapViewDoorBuilder.add_frame(
		root,
		node_name,
		minf(PORTAL_WIDTH, 1.0),
		minf(PORTAL_HEIGHT, height - 0.2),
		MapViewMeshBuilderConfig.HOUSE_DOOR_FRAME_WIDTH,
		MapViewMeshBuilderConfig.HOUSE_DOOR_FRAME_DEPTH,
		transform,
		String(node_name).hash(),
		false
	)


static func is_oratory(building: Dictionary) -> bool:
	return StringName(building.get("primitive", &"")) == ORATORY_PRIMITIVE


static func is_unheated_range(building: Dictionary) -> bool:
	return StringName(building.get("primitive", &"")) == UNHEATED_RANGE_PRIMITIVE


## Covered timber walk around a cloister garth. `passage_axis` names the run
## direction and `interior_side` names the range side, which is the high eaves
## side of the lean-to. Both are authored landmark keys, so the same model
## serves all four walks without a per-side primitive.
static func add_cloister_walk(root: Node3D, landmark: Dictionary, size: Vector2) -> void:
	var axis_x := _walk_runs_along_x(landmark, size)
	var run := size.x if axis_x else size.y
	var depth := maxf(size.y if axis_x else size.x, 1.0)
	if run <= 0.5:
		return
	var high_sign := _high_side_sign(landmark, axis_x)
	var timber_tone := Color(landmark.get("wall_color", Color(0.42, 0.34, 0.25)))
	var eaves_height := float(landmark.get("top_px", 0.0)) / 32.0
	if eaves_height <= 0.5:
		eaves_height = POST_HEIGHT
	var range_eaves := eaves_height + RANGE_EAVES_LIFT

	var along := Vector3(1.0, 0.0, 0.0) if axis_x else Vector3(0.0, 0.0, 1.0)
	var cross := Vector3(0.0, 0.0, 1.0) if axis_x else Vector3(1.0, 0.0, 0.0)
	# Posts stand on the garth edge; the opposite edge is carried by the range wall.
	var post_offset := cross * (-high_sign * (depth * 0.5 - POST_SECTION))
	var post_section := _axis_box(POST_SECTION, POST_HEIGHT, POST_SECTION, axis_x)

	var count := maxi(2, int(round(run / POST_SPACING)) + 1)
	for index in count:
		var t := float(index) / float(count - 1)
		var offset := along * lerpf(-run * 0.5 + POST_SECTION, run * 0.5 - POST_SECTION, t)
		MapViewMeshBuilderPrimitives.box(
			root,
			"WalkPost%02d" % index,
			post_section,
			offset + post_offset + Vector3(0.0, POST_HEIGHT * 0.5, 0.0),
			&"timber"
		)
		# Curved braces are beyond the box vocabulary; a short canted strut still
		# reads as the timber frame that keeps the plate from racking.
		var brace := MeshInstance3D.new()
		brace.name = "WalkBrace%02d" % index
		var brace_mesh := BoxMesh.new()
		brace_mesh.size = Vector3(0.1, BRACE_LENGTH, 0.1)
		brace.mesh = brace_mesh
		brace.material_override = MapViewMaterials.role(&"timber")
		brace.position = (
			offset
			+ post_offset
			+ cross * (high_sign * BRACE_LENGTH * 0.3)
			+ Vector3(0.0, POST_HEIGHT - BRACE_LENGTH * 0.35, 0.0)
		)
		if axis_x:
			brace.rotation.x = high_sign * PI * 0.25
		else:
			brace.rotation.z = -high_sign * PI * 0.25
		root.add_child(brace)

	MapViewMeshBuilderPrimitives.box(
		root,
		"WalkPlate",
		_axis_box(run, PLATE_DEPTH, PLATE_DEPTH * 1.2, axis_x),
		post_offset + Vector3(0.0, POST_HEIGHT + PLATE_DEPTH * 0.5, 0.0),
		&"timber"
	)
	# Dwarf sill wall: the garth side of a cloister walk is open above a low
	# masonry base, which is also what keeps rain off the walk floor.
	MapViewMeshBuilderPrimitives.box(
		root,
		"WalkSill",
		_axis_box(run, SILL_HEIGHT, 0.26, axis_x),
		post_offset + Vector3(0.0, SILL_HEIGHT * 0.5, 0.0),
		&"stone"
	)

	var slope_run := depth
	var slope_length := sqrt(slope_run * slope_run + pow(range_eaves - eaves_height, 2.0))
	var roof := MeshInstance3D.new()
	roof.name = "WalkRoof"
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = _axis_box(run + 0.3, ROOF_THICKNESS, slope_length + 0.25, axis_x)
	roof.mesh = roof_mesh
	roof.material_override = MapViewMaterials.roof(timber_tone.darkened(0.45))
	roof.position = Vector3(0.0, (range_eaves + eaves_height) * 0.5 + ROOF_THICKNESS, 0.0)
	var slope_angle := atan2(range_eaves - eaves_height, slope_run)
	# Rotating about the run axis drops the garth edge; the sign differs between
	# the X and Z runs because R_x and R_z tilt opposite ends of the cross axis.
	if axis_x:
		roof.rotation.x = -high_sign * slope_angle
	else:
		roof.rotation.z = high_sign * slope_angle
	root.add_child(roof)

## The oratory authors its own openings. The generic house pass would otherwise
## add shuttered domestic windows to a church, which is the single detail that
## made the earlier Padise oratory read as a hall.
static func add_oratory_facade(
	root: Node3D, building: Dictionary, size: Vector2, height: float
) -> void:
	var side := StringName(String(building.get("door_side", "west")))
	if side == &"none":
		return
	var along_x := side in [&"north", &"south"]
	var face_offset := (size.y if along_x else size.x) * 0.5
	var door_height := minf(PORTAL_HEIGHT, height - 0.2)
	var transform := MapViewDoorBuilder.facade_transform(
		0.0, side, face_offset, MapViewMeshBuilderConfig.DOOR_THICKNESS
	)
	var seed := String(building.get("id", &"oratory")).hash()
	MapViewDoorBuilder.add_leaf(
		root,
		"OratoryPortal",
		"OratoryPortal",
		PORTAL_WIDTH,
		door_height,
		MapViewMeshBuilderConfig.DOOR_THICKNESS,
		transform,
		seed
	)
	MapViewDoorBuilder.add_frame(
		root,
		"OratoryPortal",
		PORTAL_WIDTH,
		door_height,
		MapViewMeshBuilderConfig.HOUSE_DOOR_FRAME_WIDTH,
		MapViewMeshBuilderConfig.HOUSE_DOOR_FRAME_DEPTH,
		transform,
		seed,
		false
	)


## Aisle-less timber oratory dressing: paired lancet lights on both long walls,
## a west bellcote, and an east gable cross.
static func add_oratory_details(
	root: Node3D, _building: Dictionary, size: Vector2, height: float, along_ridge_x: bool
) -> void:
	var long_face := size.y * 0.5 if along_ridge_x else size.x * 0.5
	var run := size.x if along_ridge_x else size.y
	var narrow_half := (
		(size.y * 0.5 if along_ridge_x else size.x * 0.5) + MapViewMeshBuilderConfig.ROOF_OVERHANG
	)
	var apex := height + narrow_half * MapViewMeshBuilderConfig.ROOF_PITCH

	var light_count := clampi(int(run / 3.2), 3, 7)
	for index in light_count:
		var along := (float(index + 1) / float(light_count + 1) - 0.5) * run
		for side: float in [-1.0, 1.0]:
			var face := side * (long_face + 0.07)
			var position := Vector3(along, height * 0.55, face)
			if not along_ridge_x:
				position = Vector3(face, height * 0.55, along)
			var opening := Vector3(0.36, minf(1.65, height * 0.46), 0.08)
			if not along_ridge_x:
				opening = Vector3(0.08, minf(1.65, height * 0.46), 0.36)
			MapViewMeshBuilderPrimitives.box(
				root,
				"OratoryLight%02d%s" % [index, "N" if side < 0.0 else "S"],
				opening,
				position,
				&"window"
			)
			var frame := opening * Vector3(1.5, 1.12, 0.6)
			MapViewMeshBuilderPrimitives.box(
				root,
				"OratoryLightFrame%02d%s" % [index, "N" if side < 0.0 else "S"],
				Vector3(maxf(frame.x, 0.06), frame.y, maxf(frame.z, 0.06)),
				(
					(position + Vector3(0.0, 0.0, -side * 0.03))
					if along_ridge_x
					else (position + Vector3(-side * 0.03, 0.0, 0.0))
				),
				&"timber"
			)

	# Cistercian statutes barred stone bell towers on ordinary houses; a framed
	# west bellcote for the single office bell is the modest permitted form.
	var gable_offset := run * 0.5
	var west := (
		Vector3(-gable_offset + 0.35, 0.0, 0.0)
		if along_ridge_x
		else Vector3(0.0, 0.0, -gable_offset + 0.35)
	)
	var post_span := 0.62
	for side: float in [-1.0, 1.0]:
		var lateral := (
			Vector3(0.0, 0.0, side * post_span * 0.5)
			if along_ridge_x
			else Vector3(side * post_span * 0.5, 0.0, 0.0)
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"BellcotePost%s" % ("A" if side < 0.0 else "B"),
			Vector3(0.14, 1.35, 0.14),
			west + lateral + Vector3(0.0, apex + 0.55, 0.0),
			&"timber"
		)
	MapViewMeshBuilderPrimitives.box(
		root,
		"BellcoteHead",
		(
			Vector3(0.16, 0.14, post_span + 0.3)
			if along_ridge_x
			else Vector3(post_span + 0.3, 0.14, 0.16)
		),
		west + Vector3(0.0, apex + 1.2, 0.0),
		&"timber"
	)
	var cap := MeshInstance3D.new()
	cap.name = "BellcoteCap"
	cap.mesh = MapViewMeshBuilderPrimitives.gabled_roof_mesh(
		Vector2(0.42, post_span + 0.34) if along_ridge_x else Vector2(post_span + 0.34, 0.42),
		along_ridge_x,
		0.08,
		true,
		1.1
	)
	cap.position = west + Vector3(0.0, apex + 1.28, 0.0)
	cap.material_override = MapViewMaterials.roof(Color8(66, 54, 42))
	root.add_child(cap)
	var bell := MeshInstance3D.new()
	bell.name = "BellcoteBell"
	var bell_mesh := CylinderMesh.new()
	bell_mesh.top_radius = 0.09
	bell_mesh.bottom_radius = 0.16
	bell_mesh.height = 0.3
	bell_mesh.radial_segments = 12
	bell.mesh = bell_mesh
	bell.position = west + Vector3(0.0, apex + 0.95, 0.0)
	bell.material_override = MapViewMaterials.role(&"metal")
	root.add_child(bell)

	var east := (
		Vector3(gable_offset - 0.2, 0.0, 0.0)
		if along_ridge_x
		else Vector3(0.0, 0.0, gable_offset - 0.2)
	)
	MapViewMeshBuilderPrimitives.box(
		root,
		"OratoryCrossStem",
		Vector3(0.1, 0.86, 0.1),
		east + Vector3(0.0, apex + 0.43, 0.0),
		&"timber"
	)
	MapViewMeshBuilderPrimitives.box(
		root,
		"OratoryCrossArm",
		Vector3(0.1, 0.1, 0.46) if along_ridge_x else Vector3(0.46, 0.1, 0.1),
		east + Vector3(0.0, apex + 0.62, 0.0),
		&"timber"
	)


static func _walk_runs_along_x(landmark: Dictionary, size: Vector2) -> bool:
	match StringName(String(landmark.get("passage_axis", ""))):
		&"x":
			return true
		&"z":
			return false
	return size.x >= size.y


## Which side of the walk carries the range wall. -1 means the range stands on
## the negative cross axis (north for an X run, west for a Z run).
static func _high_side_sign(landmark: Dictionary, axis_x: bool) -> float:
	match StringName(String(landmark.get("interior_side", ""))):
		&"north":
			if axis_x:
				return -1.0
		&"south":
			if axis_x:
				return 1.0
		&"west":
			if not axis_x:
				return -1.0
		&"east":
			if not axis_x:
				return 1.0
	return -1.0


static func _axis_box(run: float, vertical: float, cross: float, axis_x: bool) -> Vector3:
	if axis_x:
		return Vector3(run, vertical, cross)
	return Vector3(cross, vertical, run)
