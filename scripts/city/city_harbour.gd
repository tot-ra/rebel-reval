class_name CityHarbour
extends RefCounted

## Dressing of the two 1343 shores (history/dossiers/topography/harbour-and-shoreline.md,
## kalamaja-fishing-shore-1343.md): the treadwheel crane and cargo stacks of the
## merchant landing under the Coastal Gate, and the Kalamaja fishing shore's
## fenced net yards with drying racks and the boatwright's timber and cart. The
## jetties and beach decks are `bridges` (CityBridges); the sheds are plan
## `outbuilding` buildings; boats are CityShips. Visual only: no collision.

const NET_COLOR := Color(0.2, 0.17, 0.12)


static func build(plan: CityPlan, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Harbour"
	parent.add_child(root)
	var harbour: Dictionary = plan.data.get("harbour", {})
	if harbour.is_empty():
		return root
	var wood := MapViewMaterials.role(&"wood")
	var timber := MapViewMaterials.role(&"timber")
	var hay := MapViewMaterials.role(&"hay")
	var crane: Variant = harbour.get("crane")
	if crane is Dictionary:
		_crane(plan, root, crane, timber, wood)
	for stack: Dictionary in harbour.get("stacks", []):
		_stack(plan, root, stack, wood, hay)
	for yard: Dictionary in harbour.get("net_yards", []):
		_net_yard(plan, root, yard, wood, timber)
	var bw: Variant = harbour.get("boatwright")
	if bw is Dictionary:
		_boatwright(plan, root, bw, timber, wood)
	return root


static func _box(
	parent: Node3D, size: Vector3, at: Vector3, material: Material, rot := Vector3.ZERO
) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	inst.mesh = mesh
	inst.material_override = material
	inst.position = at
	inst.rotation = rot
	parent.add_child(inst)
	return inst


static func _cylinder(
	parent: Node3D, radius: float, height: float, at: Vector3, material: Material, rot := Vector3.ZERO
) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	inst.mesh = mesh
	inst.material_override = material
	inst.position = at
	inst.rotation = rot
	parent.add_child(inst)
	return inst


## Double treadwheel crane on a timber frame: two trestle legs, an axle with a
## man-sized wheel, and a jib reaching over the water.
static func _crane(
	plan: CityPlan, root: Node3D, c: Dictionary, timber: Material, wood: Material
) -> void:
	var at := Vector2(c["at"][0], c["at"][1])
	var ground := plan.ground_height(at)
	var node := Node3D.new()
	node.name = "TreadwheelCrane"
	node.position = Vector3(at.x, ground, at.y)
	# The jib points seaward (plan angle); the frame stands across it.
	node.rotation.y = -float(c["angle"])
	root.add_child(node)
	for side: float in [-1.0, 1.0]:
		_box(
			node,
			Vector3(0.35, 6.0, 0.35),
			Vector3(0.0, 3.0, side * 1.6),
			timber,
			Vector3(side * 0.12, 0.0, 0.0),
		)
		_box(
			node,
			Vector3(0.3, 4.4, 0.3),
			Vector3(-1.4, 2.0, side * 1.9),
			timber,
			Vector3(side * 0.1, 0.0, 0.5),
		)
		# Wheel: a drum between the legs with spoke planks.
		_cylinder(node, 2.2, 0.35, Vector3(0.0, 3.6, side * 0.9), wood, Vector3(PI * 0.5, 0.0, 0.0))
	_box(node, Vector3(0.28, 0.28, 3.8), Vector3(0.0, 5.9, 0.0), timber)
	# Jib (towards +x, the sea) with a hanging rope and a cargo hook block.
	_box(node, Vector3(6.5, 0.3, 0.3), Vector3(3.0, 6.1, 0.0), timber, Vector3(0.0, 0.0, -0.1))
	_cylinder(node, 0.03, 4.4, Vector3(6.0, 3.9, 0.0), wood)
	_box(node, Vector3(0.3, 0.3, 0.3), Vector3(6.0, 1.6, 0.0), timber)


static func _stack(
	plan: CityPlan, root: Node3D, s: Dictionary, wood: Material, hay: Material
) -> void:
	var at := Vector2(s["at"][0], s["at"][1])
	var y := plan.ground_height(at)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(s["id"])
	var node := Node3D.new()
	node.name = String(s["id"]).replace(".", "_")
	node.position = Vector3(at.x, y, at.y)
	root.add_child(node)
	match String(s["kind"]):
		"barrel":
			for i in 4:
				var off := Vector3(rng.randf_range(-0.9, 0.9), 0.45, rng.randf_range(-0.9, 0.9))
				_cylinder(node, 0.34, 0.9, off, wood)
		"bale":
			for i in 3:
				_box(
					node,
					Vector3(1.0, 0.6, 0.7),
					Vector3(i * 1.05 - 1.0, 0.3, 0.0),
					hay,
					Vector3(0.0, rng.randf_range(-0.2, 0.2), 0.0),
				)
			_box(node, Vector3(1.0, 0.6, 0.7), Vector3(-0.5, 0.9, 0.0), hay)
		_:
			for i in 3:
				_box(
					node,
					Vector3(0.9, 0.7, 0.7),
					Vector3(i * 0.95 - 0.9, 0.35, rng.randf_range(-0.2, 0.2)),
					wood,
				)
			_box(node, Vector3(0.9, 0.7, 0.7), Vector3(0.0, 1.05, 0.0), wood)


## A fenced yard: post-and-rail on all four sides, pole racks with nets hung to dry.
static func _net_yard(
	plan: CityPlan, root: Node3D, yard: Dictionary, wood: Material, timber: Material
) -> void:
	var poly := CityPlan.points(yard["polygon"])
	var node := Node3D.new()
	node.name = String(yard["id"]).replace(".", "_")
	root.add_child(node)
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var span := a.distance_to(b)
		var dir := (b - a) / maxf(span, 0.001)
		var posts := maxi(int(span / 2.5), 1)
		for k in posts + 1:
			var p := a + dir * (span * float(k) / posts)
			_box(
				node,
				Vector3(0.1, 1.1, 0.1),
				Vector3(p.x, plan.ground_height(p) + 0.55, p.y),
				timber,
			)
		var mid := (a + b) * 0.5
		_box(
			node,
			Vector3(span, 0.06, 0.06),
			Vector3(mid.x, plan.ground_height(mid) + 0.85, mid.y),
			wood,
			Vector3(0.0, -atan2(dir.y, dir.x), 0.0)
		)
	var net := StandardMaterial3D.new()
	net.albedo_color = NET_COLOR
	net.roughness = 1.0
	net.cull_mode = BaseMaterial3D.CULL_DISABLED
	for r: Array in yard["racks"]:
		var p := Vector2(r[0], r[1])
		var length := float(r[3])
		var g := plan.ground_height(p)
		for side: float in [-1.0, 1.0]:
			_box(
				node,
				Vector3(0.12, 2.4, 0.12),
				Vector3(p.x + side * length * 0.5, g + 1.2, p.y),
				timber,
			)
		_box(node, Vector3(length + 0.2, 0.1, 0.1), Vector3(p.x, g + 2.35, p.y), timber)
		# Net hung over the pole: a thin hemp-coloured sheet that sags in the middle.
		_box(node, Vector3(length * 0.92, 1.3, 0.03), Vector3(p.x, g + 1.65, p.y), net)


## Boatwright ground: stacked timber, a handcart and a keel on trestles.
static func _boatwright(
	plan: CityPlan, root: Node3D, bw: Dictionary, timber: Material, wood: Material
) -> void:
	var at := Vector2(bw["at"][0], bw["at"][1])
	var g := plan.ground_height(at)
	var node := Node3D.new()
	node.name = "Boatwright"
	node.position = Vector3(at.x, g, at.y)
	root.add_child(node)
	for layer in 3:
		for i in 4 - layer:
			_box(
				node,
				Vector3(4.0, 0.22, 0.22),
				Vector3(0.0, 0.11 + layer * 0.24, i * 0.26 - 0.4 + layer * 0.13),
				timber,
			)
	_box(node, Vector3(1.6, 0.18, 1.0), Vector3(5.0, 0.7, 1.0), wood)
	for side: float in [-1.0, 1.0]:
		_cylinder(
			node,
			0.38,
			0.1,
			Vector3(5.0, 0.38, 1.0 + side * 0.6),
			wood,
			Vector3(PI * 0.5, 0.0, 0.0),
		)
	_box(node, Vector3(7.0, 0.22, 0.3), Vector3(-1.0, 0.9, 5.0), timber)
	for x: float in [-3.5, -1.0, 1.5]:
		_box(node, Vector3(0.2, 0.9, 0.2), Vector3(x, 0.45, 5.0), timber)
