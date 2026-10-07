class_name MapViewFishingBoatBuilder
extends RefCounted

const Primitives := preload("res://scripts/map/view3d/map_view_mesh_builder_primitives.gd")

## Procedural fourteenth-century inshore fishing boat used by the 3D map view.
##
## Scale: an actor is CharacterScale.VISIBLE_HEIGHT_WORLD (2.0 units, ~1.75 m), so
## one unit is ~0.88 m. The hull is ~5.9 units (~5.2 m) long and ~1.85 units
## (~1.6 m) wide: a four-oared clinker boat of the Baltic inshore fishery. The old
## 3.8-unit hull read as a dinghy under its own mast next to the player.

## Hull extents in local space (+X bow, +Z starboard), shared with BoatFloat3D
## sampling and the 2D collision capsule in MapSceneBootstrap.
const HULL_HALF_LENGTH := 2.95
const HULL_HALF_BEAM := 0.92
## Bottom boards sit above the still waterline (y = 0) plus the float heave, so
## the open shell never shows the sea plane inside the boat.
const FLOOR_Y := 0.16
const THWART_Y := 0.5
const MAST_X := 0.95
const MAST_TOP_Y := 3.6
const THWART_STATIONS: Array[float] = [-1.6, -0.35, MAST_X]

## Stations: x, half beam at the sheer, keel y, sheer y. Fine ends, a broad
## working middle and a sheer that rises into the stem and sternpost.
const STATIONS: Array[Vector4] = [
	Vector4(-2.72, 0.1, -0.2, 1.02),
	Vector4(-2.2, 0.56, -0.35, 0.86),
	Vector4(-1.2, 0.85, -0.42, 0.75),
	Vector4(0.0, 0.92, -0.44, 0.72),
	Vector4(1.2, 0.86, -0.42, 0.76),
	Vector4(2.2, 0.58, -0.33, 0.9),
	Vector4(2.8, 0.08, -0.12, 1.1),
]
## Profile from keel to sheer as (fraction of half beam, fraction of depth).
## Round bilges and a near-vertical topside give the clinker cross-section.
const PROFILE: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(0.42, 0.07),
	Vector2(0.83, 0.3),
	Vector2(0.98, 0.66),
	Vector2(1.0, 1.0),
]


static func add_to(root: Node3D) -> void:
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = _hull_mesh()
	hull.material_override = Primitives.role_material(&"wood")
	root.add_child(hull)

	var floor_boards := MeshInstance3D.new()
	floor_boards.name = "Floorboards"
	floor_boards.mesh = _floor_mesh()
	floor_boards.material_override = Primitives.role_material(&"timber")
	root.add_child(floor_boards)

	_add_keel_and_stems(root)
	_add_clinker_rails(root)
	_add_thwarts(root)
	_add_rig(root)
	_add_tholes(root)
	# Moored boats carry their oars shipped: laid fore-and-aft on the thwarts,
	# blades forward, instead of jutting sideways into the air.
	_add_stowed_oar(root, "OarPort", -0.44)
	_add_stowed_oar(root, "OarStarboard", 0.44)
	_add_rudder(root)
	Primitives.cylinder(
		root, "FishBasket", 0.18, 0.26, Vector3(-1.0, FLOOR_Y + 0.13, -0.05), &"hay"
	)


## Interpolated station at any x along the hull.
static func station_at(x: float) -> Vector4:
	if x <= STATIONS[0].x:
		return STATIONS[0]
	for index in STATIONS.size() - 1:
		var aft := STATIONS[index]
		var fore := STATIONS[index + 1]
		if x <= fore.x:
			return aft.lerp(fore, (x - aft.x) / (fore.x - aft.x))
	return STATIONS[STATIONS.size() - 1]


## Inside half beam of the shell at height y for one station (0 below the keel).
static func half_width_at(station: Vector4, y: float) -> float:
	var depth := station.w - station.z
	if y <= station.z or depth <= 0.0:
		return 0.0
	for index in PROFILE.size() - 1:
		var low_y := station.z + PROFILE[index].y * depth
		var high_y := station.z + PROFILE[index + 1].y * depth
		if y <= high_y:
			var t := (y - low_y) / maxf(high_y - low_y, 0.0001)
			return lerpf(PROFILE[index].x, PROFILE[index + 1].x, t) * station.y
	return station.y


static func _section(station: Vector4) -> Array[Vector3]:
	# Port sheer -> keel -> starboard sheer.
	var depth := station.w - station.z
	var points: Array[Vector3] = []
	for index in range(PROFILE.size() - 1, -1, -1):
		var p := PROFILE[index]
		points.append(Vector3(station.x, station.z + p.y * depth, -p.x * station.y))
	for index in range(1, PROFILE.size()):
		var p := PROFILE[index]
		points.append(Vector3(station.x, station.z + p.y * depth, p.x * station.y))
	return points


## The shell is open from above, so it gets an inner surface with reversed
## winding: with back-face culling a single-sided shell let the camera look
## straight through the far planking onto the sea ("water inside the boat").
static func _hull_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for inner in [false, true]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for station_index in STATIONS.size() - 1:
			var aft := _section(STATIONS[station_index])
			var fore := _section(STATIONS[station_index + 1])
			for i in aft.size() - 1:
				_add_quad(surface, aft[i], fore[i], fore[i + 1], aft[i + 1], inner)
		for station_index in [0, STATIONS.size() - 1]:
			var section := _section(STATIONS[station_index])
			for i in range(1, section.size() - 1):
				_add_triangle(surface, section[0], section[i], section[i + 1], inner)
		surface.generate_normals()
		surface.commit(mesh)
	return mesh


## Bottom boards follow the shell's inside width at FLOOR_Y, both faces emitted
## so heel and pitch never expose an edge-on gap.
static func _floor_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 16
	var start_x := STATIONS[0].x
	var end_x := STATIONS[STATIONS.size() - 1].x
	for step in steps:
		var x0 := lerpf(start_x, end_x, float(step) / steps)
		var x1 := lerpf(start_x, end_x, float(step + 1) / steps)
		var w0 := half_width_at(station_at(x0), FLOOR_Y) * 0.98
		var w1 := half_width_at(station_at(x1), FLOOR_Y) * 0.98
		if w0 <= 0.0 and w1 <= 0.0:
			continue
		var a := Vector3(x0, FLOOR_Y, -w0)
		var b := Vector3(x1, FLOOR_Y, -w1)
		var c := Vector3(x1, FLOOR_Y, w1)
		var d := Vector3(x0, FLOOR_Y, w0)
		_add_quad(surface, a, b, c, d, false)
		_add_quad(surface, a, b, c, d, true)
	surface.generate_normals()
	return surface.commit()


static func _add_keel_and_stems(root: Node3D) -> void:
	for index in range(1, STATIONS.size() - 2):
		var aft := STATIONS[index]
		var fore := STATIONS[index + 1]
		_add_spar(
			root,
			"Keel%d" % index,
			Vector3(aft.x, aft.z - 0.03, 0.0),
			Vector3(fore.x, fore.z - 0.03, 0.0),
			0.05,
			&"timber"
		)
	var stern := STATIONS[0]
	var bow := STATIONS[STATIONS.size() - 1]
	_add_spar(
		root,
		"Sternpost",
		Vector3(STATIONS[1].x, STATIONS[1].z - 0.03, 0.0),
		Vector3(stern.x - 0.16, stern.w + 0.16, 0.0),
		0.055,
		&"timber"
	)
	_add_spar(
		root,
		"BowStem",
		Vector3(STATIONS[5].x, STATIONS[5].z - 0.03, 0.0),
		Vector3(bow.x + 0.15, bow.w + 0.2, 0.0),
		0.06,
		&"timber"
	)


static func _add_clinker_rails(root: Node3D) -> void:
	# Gunwale on the sheer plus two plank-lap lines on the upper strake and bilge
	# break the side into readable overlapping strakes.
	var rails := {
		"Gunwale": [PROFILE.size() - 1, 0.045], "Strake": [3, 0.025], "Bilge": [2, 0.025]
	}
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		for rail_name in rails:
			var profile_index: int = rails[rail_name][0]
			var radius: float = rails[rail_name][1]
			for index in STATIONS.size() - 1:
				var start := _profile_point(STATIONS[index], profile_index, side)
				var end := _profile_point(STATIONS[index + 1], profile_index, side)
				_add_spar(
					root, "%s%s%d" % [rail_name, side_name, index], start, end, radius, &"timber"
				)


static func _profile_point(station: Vector4, profile_index: int, side: float) -> Vector3:
	var p := PROFILE[profile_index]
	var y := station.z + p.y * (station.w - station.z)
	# Sit the rail a hair proud of the planking so it never z-fights the shell.
	return Vector3(station.x, y, side * (p.x * station.y + 0.012))


static func _add_thwarts(root: Node3D) -> void:
	for index in THWART_STATIONS.size():
		var x := THWART_STATIONS[index]
		var half := half_width_at(station_at(x), THWART_Y)
		Primitives.box(
			root,
			"Bench%d" % index,
			Vector3(0.24, 0.06, half * 2.0),
			Vector3(x, THWART_Y, 0.0),
			&"timber"
		)


static func _add_rig(root: Node3D) -> void:
	_add_spar(
		root, "Mast", Vector3(MAST_X, FLOOR_Y, 0.0), Vector3(MAST_X, MAST_TOP_Y, 0.0), 0.06, &"timber"
	)
	# A small square sail stays furled on a lowered yard: the yard spans about the
	# hull beam, so the rig no longer dwarfs the boat.
	var yard := Node3D.new()
	yard.name = "Yard"
	root.add_child(yard)
	var yard_y := MAST_TOP_Y - 0.4
	_add_spar(
		yard,
		"Spar",
		Vector3(MAST_X + 0.12, yard_y + 0.06, -1.15),
		Vector3(MAST_X + 0.12, yard_y - 0.06, 1.15),
		0.035,
		&"timber"
	)
	_add_spar(
		yard,
		"FurledSail",
		Vector3(MAST_X + 0.15, yard_y - 0.05, -0.95),
		Vector3(MAST_X + 0.15, yard_y - 0.15, 0.95),
		0.09,
		&"plaster"
	)

	var rigging := Node3D.new()
	rigging.name = "Rigging"
	root.add_child(rigging)
	var bow := STATIONS[STATIONS.size() - 1]
	var mast_head := Vector3(MAST_X, MAST_TOP_Y - 0.08, 0.0)
	_add_spar(
		rigging, "Forestay", mast_head, Vector3(bow.x + 0.12, bow.w + 0.14, 0.0), 0.012, &"ink"
	)
	var shroud_station := station_at(MAST_X - 0.35)
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_add_spar(
			rigging,
			"Shroud%s" % side_name,
			mast_head,
			Vector3(shroud_station.x, shroud_station.w, side * shroud_station.y),
			0.012,
			&"ink"
		)


## Paired thole pins on the gunwale at each rowing thwart.
static func _add_tholes(root: Node3D) -> void:
	for index in 2:
		var x := THWART_STATIONS[index] + 0.32
		var station := station_at(x)
		for side in [-1.0, 1.0]:
			var side_name := "Port" if side < 0.0 else "Starboard"
			Primitives.cylinder(
				root,
				"Thole%s%d" % [side_name, index],
				0.025,
				0.2,
				Vector3(x, station.w + 0.1, side * station.y),
				&"timber"
			)


## A ~3.6-unit (~3.2 m) oar: grip, round loom and a long narrow blade, resting
## on the thwarts parallel to the keel.
static func _add_stowed_oar(root: Node3D, node_name: String, z: float) -> void:
	var oar := Node3D.new()
	oar.name = node_name
	root.add_child(oar)
	var y := THWART_Y + 0.03 + 0.035
	_add_spar(oar, "Grip", Vector3(-2.0, y, z), Vector3(-1.72, y, z), 0.024, &"timber")
	_add_spar(oar, "Shaft", Vector3(-1.72, y, z), Vector3(0.82, y, z), 0.035, &"timber")
	# Period oar blades are long and narrow; it lies flat on the forward thwart.
	var blade := MeshInstance3D.new()
	blade.name = "Blade"
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.8, 0.028, 0.15)
	blade.mesh = blade_mesh
	blade.position = Vector3(1.22, y - 0.01, z)
	blade.material_override = Primitives.role_material(&"wood")
	oar.add_child(blade)


static func _add_rudder(root: Node3D) -> void:
	var stern := STATIONS[0]
	var rudder_x := stern.x - 0.26
	Primitives.box(
		root, "Rudder", Vector3(0.38, 1.25, 0.05), Vector3(rudder_x - 0.12, 0.42, 0.0), &"timber"
	)
	_add_spar(
		root,
		"Tiller",
		Vector3(rudder_x, stern.w + 0.08, 0.0),
		Vector3(STATIONS[1].x + 0.05, STATIONS[1].w + 0.14, 0.0),
		0.03,
		&"timber"
	)


static func _add_spar(
	parent: Node3D, node_name: String, start: Vector3, end: Vector3, radius: float, role: StringName
) -> void:
	var direction := end - start
	if direction.is_zero_approx():
		return
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = direction.length()
	mesh.radial_segments = 6
	mesh.rings = 1
	instance.mesh = mesh
	instance.position = (start + end) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
	instance.material_override = Primitives.role_material(role)
	parent.add_child(instance)


static func _add_quad(
	surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, reverse: bool
) -> void:
	var vertices := [a, d, c, a, c, b] if reverse else [a, b, c, a, c, d]
	for vertex in vertices:
		surface.set_uv(Vector2(vertex.x, vertex.y + vertex.z))
		surface.add_vertex(vertex)


static func _add_triangle(
	surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, reverse: bool
) -> void:
	var vertices := [a, c, b] if reverse else [a, b, c]
	for vertex in vertices:
		surface.set_uv(Vector2(vertex.x, vertex.y + vertex.z))
		surface.add_vertex(vertex)
