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
	var thatch_mat := _Styles.house_roof_material(building)
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
