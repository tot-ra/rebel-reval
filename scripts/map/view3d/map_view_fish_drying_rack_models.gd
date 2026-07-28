class_name MapViewFishDryingRackModels
extends RefCounted

## Reusable timber frame for harbor drying yards. Catch geometry is deliberately
## excluded so maps can author empty, lightly loaded, or mixed-species racks.

const DRYING_POLE_HEIGHT := 1.16
const FRONT_POLE_Z := -0.24
const BACK_POLE_Z := 0.24

const _Primitives := preload("res://scripts/map/view3d/map_view_mesh_builder_primitives.gd")


static func add_frame(parent: Node3D) -> Node3D:
	var frame := Node3D.new()
	frame.name = "FishDryingRackFrame"
	frame.set_meta(&"empty_drying_frame", true)
	parent.add_child(frame)

	for end_index in 2:
		var end_x := -0.66 if end_index == 0 else 0.66
		_add_spar(
			frame,
			"EndFrame%dFrontLeg" % end_index,
			Vector3(end_x, 0.015, -0.43),
			Vector3(end_x, 1.34, 0.0),
			0.045,
			&"timber"
		)
		_add_spar(
			frame,
			"EndFrame%dBackLeg" % end_index,
			Vector3(end_x, 0.015, 0.43),
			Vector3(end_x, 1.34, 0.0),
			0.045,
			&"timber"
		)
		_add_spar(
			frame,
			"EndFrame%dTie" % end_index,
			Vector3(end_x, 0.45, -0.32),
			Vector3(end_x, 0.45, 0.32),
			0.035,
			&"wood"
		)

	_add_spar(frame, "RidgePole", Vector3(-0.74, 1.34, 0.0), Vector3(0.74, 1.34, 0.0), 0.05, &"wood")
	_add_spar(frame, "FrontDryingPole", Vector3(-0.7, DRYING_POLE_HEIGHT, FRONT_POLE_Z), Vector3(0.7, DRYING_POLE_HEIGHT, FRONT_POLE_Z), 0.035, &"wood")
	_add_spar(frame, "BackDryingPole", Vector3(-0.7, DRYING_POLE_HEIGHT, BACK_POLE_Z), Vector3(0.7, DRYING_POLE_HEIGHT, BACK_POLE_Z), 0.035, &"wood")
	_add_spar(frame, "FrontBrace", Vector3(-0.6, 0.18, -0.39), Vector3(0.6, 0.72, -0.3), 0.025, &"timber")
	_add_spar(frame, "BackBrace", Vector3(0.6, 0.18, 0.39), Vector3(-0.6, 0.72, 0.3), 0.025, &"timber")
	return frame


static func attachment_point(x: float, back_row: bool = false) -> Vector3:
	return Vector3(x, DRYING_POLE_HEIGHT, BACK_POLE_Z if back_row else FRONT_POLE_Z)


static func add_hanging_cord(parent: Node3D, node_name: String, start: Vector3, length: float) -> void:
	_add_spar(parent, node_name, start, start + Vector3(0.0, -length, 0.0), 0.008, &"timber")


static func _add_spar(
	parent: Node3D,
	node_name: String,
	start: Vector3,
	end: Vector3,
	radius: float,
	role: StringName
) -> void:
	var direction := end - start
	if direction.is_zero_approx():
		return
	var spar := MeshInstance3D.new()
	spar.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.08
	mesh.height = direction.length()
	mesh.radial_segments = 6
	mesh.rings = 1
	spar.mesh = mesh
	spar.position = (start + end) * 0.5
	spar.quaternion = Quaternion(Vector3.UP, direction.normalized())
	spar.material_override = _Primitives.role_material(role)
	parent.add_child(spar)
