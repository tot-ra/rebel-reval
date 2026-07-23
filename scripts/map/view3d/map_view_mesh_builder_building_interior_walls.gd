class_name MapViewMeshBuilderBuildingInteriorWalls
extends RefCounted

## Interior wall dressing for enclosed room segments.

## Interior wall dressing is intentionally shallow: enough relief for warm
## directional light without narrowing navigation or changing collision.
const INTERIOR_WALL_RELIEF := 0.025
const INTERIOR_WALL_DRESSING_DEPTH := 0.075
const INTERIOR_WALL_SOOT_DEPTH := 0.03
const INTERIOR_WALL_PLINTH_HEIGHT := 0.48
const INTERIOR_WALL_RAIL_HEIGHT := 1.42
const INTERIOR_WALL_UPPER_RAIL_DROP := 0.18
const INTERIOR_WALL_TIMBER_WIDTH := 0.11
const INTERIOR_WALL_POST_SPACING := 2.25


static func interior_wall_material(
	building: Dictionary,
	wall_color: Color,
	size: Vector3
) -> StandardMaterial3D:
	var authored_family: StringName = building.get("wall_material", &"plaster")
	var pattern_family: StringName = &"plaster" if authored_family == &"smoked_plaster" else authored_family
	var material := MapViewMaterials.wall_surface_for_building(
		building.get("id", &"interior_wall"),
		pattern_family,
		wall_color,
		size
	)
	# Interior wall strips are thin along one axis; triplanar keeps plaster
	# courses readable when a segment runs north-south instead of east-west.
	material.uv1_triplanar = true
	material.uv1_world_triplanar = false
	if authored_family == &"smoked_plaster":
		material.roughness = 0.96
	return material


static func add_interior_wall_structure(
	root: Node3D,
	building: Dictionary,
	size: Vector2,
	height: float
) -> void:
	var along_x := size.x >= size.y
	var run_length := size.x if along_x else size.y
	var wall_depth := size.y if along_x else size.x
	var face_offset := wall_depth * 0.5 + INTERIOR_WALL_RELIEF
	var plinth_height := minf(INTERIOR_WALL_PLINTH_HEIGHT, height * 0.22)
	var rail_height := minf(INTERIOR_WALL_RAIL_HEIGHT, height * 0.46)
	var upper_rail_y := maxf(height - INTERIOR_WALL_UPPER_RAIL_DROP, rail_height)
	var faces: Array[StringName] = []
	if along_x:
		faces.assign([&"south", &"north"])
	else:
		faces.assign([&"east", &"west"])
	for face in faces:
		MapViewMeshBuilderBuildingFacade.facade_box(
			root,
			"StonePlinth_%s" % String(face),
			Vector3(run_length, plinth_height, INTERIOR_WALL_DRESSING_DEPTH),
			0.0,
			plinth_height * 0.5,
			face,
			face_offset,
			&"stone"
		)
		for rail in [
			["MidRail", rail_height],
			["UpperRail", upper_rail_y],
		]:
			MapViewMeshBuilderBuildingFacade.facade_box(
				root,
				"%s_%s" % [rail[0], String(face)],
				Vector3(run_length, INTERIOR_WALL_TIMBER_WIDTH, INTERIOR_WALL_DRESSING_DEPTH),
				0.0,
				float(rail[1]),
				face,
				face_offset + 0.01,
				&"timber"
			)
		var post_count := maxi(2, ceili(run_length / INTERIOR_WALL_POST_SPACING) + 1)
		for index in post_count:
			var along := lerpf(-run_length * 0.5, run_length * 0.5, float(index) / float(post_count - 1))
			MapViewMeshBuilderBuildingFacade.facade_box(
				root,
				"Post_%s_%02d" % [String(face), index],
				Vector3(INTERIOR_WALL_TIMBER_WIDTH, height, INTERIOR_WALL_DRESSING_DEPTH),
				along,
				height * 0.5,
				face,
				face_offset + 0.02,
				&"timber"
			)

	if StringName(building.get("wall_material", &"")) == &"smoked_plaster":
		add_forge_soot_wash(root, size, height, along_x, faces, face_offset)


static func add_forge_soot_wash(
	root: Node3D,
	size: Vector2,
	height: float,
	along_x: bool,
	faces: Array[StringName],
	face_offset: float
) -> void:
	var run_length := size.x if along_x else size.y
	var band_height := clampf(height * 0.16, 0.35, 0.62)
	for face in faces:
		MapViewMeshBuilderBuildingFacade.facade_box(
			root,
			"Soot_%s_00" % String(face),
			Vector3(run_length, band_height, INTERIOR_WALL_SOOT_DEPTH),
			0.0,
			height - band_height * 0.5,
			face,
			face_offset + 0.015,
			&"soot"
		)
