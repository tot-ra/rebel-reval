class_name MapViewDoorBuilder
extends RefCounted

## Historically grounded boarded doors shared by house facades and transitions.
## Geometry stays procedural because doors are part of streamed MapView3D output,
## while dedicated PBR materials keep the small surface readable up close.

const MIN_PLANKS := 4
const MAX_PLANKS := 7
const PLANK_GAP := 0.012
const STRAP_HEIGHT := 0.055
const STRAP_DEPTH := 0.026
const HINGE_RADIUS := 0.034
const HINGE_HEIGHT := 0.17
const RIVET_RADIUS := 0.018


static func facade_transform(
	along: float, side: StringName, face_offset: float, leaf_depth: float
) -> Transform3D:
	var out := face_offset + leaf_depth * 0.5 - MapViewMeshBuilderConfig.FACADE_RELIEF + 0.06
	match side:
		&"north":
			return Transform3D(Basis(Vector3.UP, PI), Vector3(along, 0.0, -out))
		&"east":
			return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(out, 0.0, along))
		&"west":
			return Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-out, 0.0, along))
	return Transform3D(Basis.IDENTITY, Vector3(along, 0.0, out))


static func add_leaf(
	parent: Node3D,
	panel_name: String,
	part_prefix: String,
	width: float,
	height: float,
	depth: float,
	assembly_transform: Transform3D = Transform3D.IDENTITY,
	material_seed: int = 0,
	add_rear_braces: bool = true
) -> void:
	# A recessed backing closes the hairline gaps without turning the visible face
	# back into one flat slab. Each face board keeps an independent tone and depth.
	_add_box(
		parent,
		panel_name,
		Vector3(width - 0.025, height - 0.025, depth * 0.72),
		Vector3(0.0, height * 0.5, -depth * 0.12),
		MapViewMaterials.door_wood(material_seed - 31),
		assembly_transform
	)

	var plank_count := clampi(roundi(width / 0.22), MIN_PLANKS, MAX_PLANKS)
	var weights: Array[float] = [0.96, 1.05, 0.99, 1.07, 0.94, 1.03, 0.98]
	var weight_sum := 0.0
	for index in plank_count:
		weight_sum += weights[index]
	var usable_width := width - PLANK_GAP * float(plank_count - 1)
	var cursor := -width * 0.5
	for index in plank_count:
		var plank_width := usable_width * weights[index] / weight_sum
		var top_wear := float((index * 7 + absi(material_seed)) % 4) * 0.004
		var plank_height := height - 0.035 - top_wear
		var center_x := cursor + plank_width * 0.5
		var depth_offset := (float((index * 5 + absi(material_seed)) % 3) - 1.0) * 0.003
		_add_box(
			parent,
			_part_name(part_prefix, "Plank%d" % index),
			Vector3(plank_width, plank_height, depth),
			Vector3(center_x, 0.015 + plank_height * 0.5, depth_offset),
			MapViewMaterials.door_wood(material_seed + index * 97),
			assembly_transform
		)
		cursor += plank_width + PLANK_GAP

	_add_hardware(parent, part_prefix, width, height, depth, assembly_transform)
	if add_rear_braces:
		_add_rear_battens(
			parent, part_prefix, width, height, depth, material_seed, assembly_transform
		)


static func add_frame(
	parent: Node3D,
	part_prefix: String,
	width: float,
	height: float,
	frame_width: float,
	depth: float,
	assembly_transform: Transform3D = Transform3D.IDENTITY,
	material_seed: int = 0,
	masonry: bool = false
) -> void:
	var frame_height := height + frame_width
	var frame_x := width * 0.5 + frame_width * 0.5
	var vertical_material: Material = (
		MapViewMaterials.role_for_size(&"stone", Vector3(frame_width, frame_height, depth))
		if masonry
		else MapViewMaterials.door_wood(material_seed + 701)
	)
	var lintel_size := Vector3(width + frame_width * 2.0, frame_width, depth)
	var lintel_material: Material = (
		MapViewMaterials.role_for_size(&"stone", lintel_size)
		if masonry
		else MapViewMaterials.role_for_size(&"timber", lintel_size)
	)
	_add_box(
		parent,
		_part_name(part_prefix, "FrameLeft"),
		Vector3(frame_width, frame_height, depth),
		Vector3(-frame_x, frame_height * 0.5, 0.0),
		vertical_material,
		assembly_transform
	)
	_add_box(
		parent,
		_part_name(part_prefix, "FrameRight"),
		Vector3(frame_width, frame_height, depth),
		Vector3(frame_x, frame_height * 0.5, 0.0),
		vertical_material,
		assembly_transform
	)
	_add_box(
		parent,
		_part_name(part_prefix, "Lintel"),
		lintel_size,
		Vector3(0.0, height + frame_width * 0.5, 0.0),
		lintel_material,
		assembly_transform
	)


static func _add_hardware(
	parent: Node3D,
	prefix: String,
	width: float,
	height: float,
	depth: float,
	assembly_transform: Transform3D
) -> void:
	var iron := MapViewMaterials.door_iron()
	var face_z := depth * 0.5 + STRAP_DEPTH * 0.5 + 0.006
	var hinge_x := -width * 0.5 + HINGE_RADIUS * 0.8
	for index in 2:
		var y := height * (0.31 + float(index) * 0.40)
		var strap_width := width * (0.76 if index == 0 else 0.70)
		var strap_center_x := -width * 0.5 + strap_width * 0.5 + HINGE_RADIUS * 0.35
		_add_box(
			parent,
			_part_name(prefix, "Strap%d" % index),
			Vector3(strap_width, STRAP_HEIGHT, STRAP_DEPTH),
			Vector3(strap_center_x, y, face_z),
			iron,
			assembly_transform
		)
		_add_sphere(
			parent,
			_part_name(prefix, "Strap%dTip" % index),
			STRAP_HEIGHT * 0.56,
			Vector3(
				-width * 0.5 + strap_width + HINGE_RADIUS * 0.35, y, face_z + STRAP_DEPTH * 0.35
			),
			Vector3(1.35, 1.0, 0.45),
			iron,
			assembly_transform
		)
		_add_cylinder(
			parent,
			_part_name(prefix, "HingeBarrel%d" % index),
			HINGE_RADIUS,
			HINGE_HEIGHT,
			Vector3(hinge_x, y, face_z + HINGE_RADIUS * 0.25),
			iron,
			assembly_transform
		)
		for rivet_index in 3:
			var rivet_x := lerpf(
				-width * 0.34, width * (0.20 if index == 0 else 0.14), float(rivet_index) * 0.5
			)
			_add_sphere(
				parent,
				_part_name(prefix, "Strap%dRivet%d" % [index, rivet_index]),
				RIVET_RADIUS,
				Vector3(rivet_x, y, face_z + STRAP_DEPTH * 0.7),
				Vector3(1.0, 1.0, 0.45),
				iron,
				assembly_transform
			)

	var latch_x := width * 0.33
	var latch_y := height * 0.53
	_add_box(
		parent,
		_part_name(prefix, "Latch"),
		Vector3(0.095, 0.18, STRAP_DEPTH * 1.2),
		Vector3(latch_x, latch_y, face_z),
		iron,
		assembly_transform
	)
	_add_ring(
		parent,
		_part_name(prefix, "Handle"),
		0.078,
		0.052,
		Vector3(latch_x, latch_y - 0.095, face_z + 0.026),
		iron,
		assembly_transform
	)


static func _add_rear_battens(
	parent: Node3D,
	prefix: String,
	width: float,
	height: float,
	depth: float,
	material_seed: int,
	assembly_transform: Transform3D
) -> void:
	# The surviving fourteenth-century Tallinn Dome door uses inclined connecting
	# bars. Keeping these on the inner face explains the leaf construction without
	# adding later decorative Gothic tracery to an ordinary urban doorway.
	var run := width * 0.78
	var rise := height * 0.16
	var length := Vector2(run, rise).length()
	var angle := atan2(rise, run)
	for index in 2:
		var local_basis := Basis(Vector3.FORWARD, angle)
		_add_box(
			parent,
			_part_name(prefix, "RearBrace%d" % index),
			Vector3(length, 0.09, 0.045),
			Vector3(0.0, height * (0.32 + float(index) * 0.37), -depth * 0.5 - 0.025),
			MapViewMaterials.door_wood(material_seed + 1103 + index),
			assembly_transform,
			local_basis
		)


static func _part_name(prefix: String, part: String) -> String:
	return "%s%s" % [prefix, part] if not prefix.is_empty() else part


static func _add_box(
	parent: Node3D,
	name: String,
	size: Vector3,
	position: Vector3,
	material: Material,
	assembly_transform: Transform3D,
	local_basis: Basis = Basis.IDENTITY
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.transform = assembly_transform * Transform3D(local_basis, position)
	instance.material_override = material
	parent.add_child(instance)


static func _add_cylinder(
	parent: Node3D,
	name: String,
	radius: float,
	height: float,
	position: Vector3,
	material: Material,
	assembly_transform: Transform3D
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	instance.mesh = mesh
	instance.transform = assembly_transform * Transform3D(Basis.IDENTITY, position)
	instance.material_override = material
	parent.add_child(instance)


static func _add_sphere(
	parent: Node3D,
	name: String,
	radius: float,
	position: Vector3,
	scale: Vector3,
	material: Material,
	assembly_transform: Transform3D
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	instance.mesh = mesh
	instance.transform = assembly_transform * Transform3D(Basis.IDENTITY.scaled(scale), position)
	instance.material_override = material
	parent.add_child(instance)


static func _add_ring(
	parent: Node3D,
	name: String,
	outer_radius: float,
	inner_radius: float,
	position: Vector3,
	material: Material,
	assembly_transform: Transform3D
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := TorusMesh.new()
	mesh.outer_radius = outer_radius
	mesh.inner_radius = inner_radius
	mesh.rings = 16
	mesh.ring_segments = 6
	instance.mesh = mesh
	var local_basis := Basis(Vector3.RIGHT, PI * 0.5)
	instance.transform = assembly_transform * Transform3D(local_basis, position)
	instance.material_override = material
	parent.add_child(instance)
