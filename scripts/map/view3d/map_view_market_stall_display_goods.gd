class_name MapViewMarketStallDisplayGoods
extends RefCounted

## Interchangeable countertop modules for the shared market-stall frame.
##
## Each module owns only display geometry. The stall owns placement, scale, and
## gameplay footprint, so merchandise can change without duplicating the frame.

const GOODS_FISH := &"fish"
const GOODS_CLOTH := &"cloth"
const GOODS_GRAIN := &"grain"
const GOODS_POTTERY := &"pottery"

static var _materials: Dictionary = {}


static func add_module(parent: Node3D, goods_kind: StringName) -> Node3D:
	var module := Node3D.new()
	module.name = "Goods%s" % String(goods_kind).capitalize().replace(" ", "")
	module.set_meta(&"market_stall_goods_kind", goods_kind)
	parent.add_child(module)
	match goods_kind:
		GOODS_FISH:
			_add_fish(module)
		GOODS_CLOTH:
			_add_cloth(module)
		GOODS_GRAIN:
			_add_grain(module)
		GOODS_POTTERY:
			_add_pottery(module)
		_:
			assert(false, "Unknown market-stall display module: %s" % String(goods_kind))
	return module


static func _add_fish(root: Node3D) -> void:
	_box(
		root,
		"WoodenTray",
		Vector3(0.72, 0.035, 0.38),
		Vector3(0.0, 0.018, 0.0),
		_material(&"tray_wood", Color8(91, 57, 34))
	)
	_box(
		root,
		"TrayBack",
		Vector3(0.72, 0.07, 0.035),
		Vector3(0.0, 0.055, 0.19),
		_material(&"tray_dark", Color8(70, 43, 29))
	)
	_box(
		root,
		"TrayFront",
		Vector3(0.72, 0.07, 0.035),
		Vector3(0.0, 0.055, -0.19),
		_material(&"tray_dark", Color8(70, 43, 29))
	)
	for spec in [
		{"name": "HerringA", "position": Vector3(-0.09, 0.105, -0.105), "yaw": -0.08},
		{"name": "HerringB", "position": Vector3(0.08, 0.11, 0.0), "yaw": 0.06},
		{"name": "HerringC", "position": Vector3(-0.05, 0.115, 0.11), "yaw": -0.03},
	]:
		var fish := Node3D.new()
		fish.name = spec["name"]
		fish.position = spec["position"]
		fish.rotation.y = spec["yaw"]
		root.add_child(fish)
		_sphere(
			fish,
			"Body",
			0.11,
			Vector3.ZERO,
			Vector3(2.05, 0.48, 0.62),
			_material(&"herring", Color8(112, 137, 141), 0.62, 0.18)
		)
		_sphere(
			fish,
			"Head",
			0.075,
			Vector3(0.19, 0.0, 0.0),
			Vector3(0.95, 0.78, 0.82),
			_material(&"herring_head", Color8(92, 116, 121), 0.65, 0.15)
		)
		var tail := Node3D.new()
		tail.name = "Tail"
		tail.position = Vector3(-0.25, 0.0, 0.0)
		fish.add_child(tail)
		for side in [-1.0, 1.0]:
			var fin := _box(
				tail,
				"Fin%s" % ("L" if side < 0.0 else "R"),
				Vector3(0.12, 0.018, 0.075),
				Vector3(-0.025, 0.0, side * 0.025),
				_material(&"herring_fin", Color8(80, 105, 111), 0.7, 0.1)
			)
			fin.rotation.y = side * 0.48


static func _add_cloth(root: Node3D) -> void:
	var cloth_specs = [
		{
			"name": "IndigoFold",
			"position": Vector3(-0.18, 0.085, 0.08),
			"size": Vector3(0.42, 0.16, 0.28),
			"material": _material(&"cloth_indigo", Color8(74, 88, 104))
		},
		{
			"name": "OatFold",
			"position": Vector3(0.17, 0.07, -0.08),
			"size": Vector3(0.4, 0.13, 0.3),
			"material": _material(&"cloth_oat", Color8(173, 151, 111))
		},
		{
			"name": "MadderFold",
			"position": Vector3(0.02, 0.205, 0.02),
			"size": Vector3(0.48, 0.11, 0.25),
			"material": _material(&"cloth_madder", Color8(126, 68, 58))
		},
	]
	for spec in cloth_specs:
		var fold := _box(root, spec["name"], spec["size"], spec["position"], spec["material"])
		fold.rotation.y = -0.08 if spec["name"] == "IndigoFold" else 0.06
		_box(
			fold,
			"Binding",
			Vector3(0.045, spec["size"].y + 0.012, spec["size"].z + 0.012),
			Vector3.ZERO,
			_material(&"cloth_binding", Color8(99, 77, 46))
		)


static func _add_grain(root: Node3D) -> void:
	for spec in [
		{
			"name": "SackA",
			"position": Vector3(-0.19, 0.14, 0.03),
			"scale": Vector3(0.75, 1.0, 0.62)
		},
		{
			"name": "SackB",
			"position": Vector3(0.18, 0.12, 0.08),
			"scale": Vector3(0.68, 0.86, 0.58)
		},
	]:
		_sphere(
			root,
			spec["name"],
			0.18,
			spec["position"],
			spec["scale"],
			_material(&"grain_sack", Color8(159, 135, 91))
		)
		_cylinder(
			root,
			"%sTie" % spec["name"],
			0.038,
			0.045,
			spec["position"] + Vector3(0.0, 0.18 * spec["scale"].y, 0.0),
			_material(&"sack_tie", Color8(91, 69, 39))
		)
	_cylinder(
		root,
		"Measure",
		0.16,
		0.07,
		Vector3(0.0, 0.04, -0.19),
		_material(&"grain_measure", Color8(105, 66, 37))
	)
	for index in 9:
		var angle := TAU * float(index) / 9.0
		var radius := 0.035 + 0.055 * float(index % 3) / 2.0
		_sphere(
			root,
			"Grain%d" % index,
			0.018,
			Vector3(
				cos(angle) * radius, 0.09 + 0.004 * float(index % 2), -0.19 + sin(angle) * radius
			),
			Vector3(1.0, 0.65, 1.0),
			_material(&"grain", Color8(198, 157, 66))
		)


static func _add_pottery(root: Node3D) -> void:
	var pottery_specs = [
		{
			"name": "Jug",
			"position": Vector3(-0.2, 0.0, 0.04),
			"radius": 0.14,
			"height": 0.28,
			"color": Color8(134, 79, 51)
		},
		{
			"name": "CookingPot",
			"position": Vector3(0.14, 0.0, -0.08),
			"radius": 0.17,
			"height": 0.22,
			"color": Color8(104, 71, 54)
		},
		{
			"name": "Cup",
			"position": Vector3(0.25, 0.0, 0.14),
			"radius": 0.09,
			"height": 0.15,
			"color": Color8(154, 96, 61)
		},
	]
	for spec in pottery_specs:
		var pot := Node3D.new()
		pot.name = spec["name"]
		pot.position = spec["position"]
		root.add_child(pot)
		var clay := _material(StringName("clay_%s" % spec["name"]), spec["color"])
		_frustum(
			pot,
			"LowerBody",
			spec["radius"] * 0.68,
			spec["radius"],
			spec["height"] * 0.48,
			Vector3(0.0, spec["height"] * 0.24, 0.0),
			clay
		)
		_frustum(
			pot,
			"UpperBody",
			spec["radius"],
			spec["radius"] * 0.68,
			spec["height"] * 0.42,
			Vector3(0.0, spec["height"] * 0.69, 0.0),
			clay
		)
		_torus(
			pot,
			"Rim",
			spec["radius"] * 0.54,
			spec["radius"] * 0.68,
			Vector3(0.0, spec["height"] * 0.92, 0.0),
			clay
		)
		_cylinder(
			pot,
			"MouthShadow",
			spec["radius"] * 0.49,
			0.012,
			Vector3(0.0, spec["height"] * 0.915, 0.0),
			_material(&"pot_interior", Color8(54, 39, 32))
		)


static func _material(
	key: StringName, color: Color, roughness: float = 0.88, metallic: float = 0.0
) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.resource_name = String(key)
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_materials[key] = material
	return material


static func _box(
	parent: Node3D, name: String, size: Vector3, position: Vector3, material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func _sphere(
	parent: Node3D,
	name: String,
	radius: float,
	position: Vector3,
	scale: Vector3,
	material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	instance.mesh = mesh
	instance.position = position
	instance.scale = scale
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func _cylinder(
	parent: Node3D,
	name: String,
	radius: float,
	height: float,
	position: Vector3,
	material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func _frustum(
	parent: Node3D,
	name: String,
	bottom_radius: float,
	top_radius: float,
	height: float,
	position: Vector3,
	material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = 10
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func _torus(
	parent: Node3D,
	name: String,
	inner_radius: float,
	outer_radius: float,
	position: Vector3,
	material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 10
	mesh.ring_segments = 6
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance
