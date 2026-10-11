class_name MapViewBushMeshes
extends RefCounted

## Seamless-city shrub geometry. The legacy P0-115 vertex-colour shrub mesh
## (mesh_for, archetype blobs) was removed: it read as odd green balloons, so
## district maps no longer scatter bushes and bush props have no 3D model.

const MeshMath := preload("res://scripts/map/view3d/map_view_mesh_builder_math.gd")
const BushSpecies := preload("res://scripts/map/view3d/map_view_bush_species.gd")
const LeafGeometry := preload("res://scripts/map/view3d/map_view_leaf_geometry.gd")

## Seamless city (ADR 0031, 1 wu = 1 m). City variants are built directly in
## metres: arching canes carrying leaf-cluster cards of a real size, so the
## shrub keeps its mass with many small cards.
const CITY_CARD_METRES := 0.24
## Leafy shrubs with a city variant, mapped to the tree species whose atlas
## tile, seasonal phenology and canopy material their leaves borrow (rose
## leaflets are pinnate like rowan; raspberry leaves are broad and serrated).
const CITY_LEAF_PROXY := {
	&"dog_rose": &"rowan",
	&"raspberry": &"hazel",
}
## Cane habit: count, outward arch (fraction of spread) and tip droop (fraction
## of height). Raspberry canes stand nearly upright; dog rose arches over.
const CITY_CANES := {
	&"dog_rose": {"canes": 14, "arch": 0.85, "droop": 0.30},
	&"raspberry": {"canes": 15, "arch": 0.40, "droop": 0.10},
}
const CITY_CANE_RADIUS := 0.012

static var _city_cache: Dictionary = {}


static func reset_cache() -> void:
	_city_cache.clear()


static func has_city_variant(species: StringName) -> bool:
	return CITY_LEAF_PROXY.has(species)


## Tree species whose canopy material (atlas tile, phenology) the city variant uses.
static func city_leaf_proxy(species: StringName) -> StringName:
	return CITY_LEAF_PROXY.get(species, &"hazel")


## City shrub sized in metres (size_m = height, spread). Uses the canopy shader's
## card contract (UV2 = (1, 1), CUSTOM0 = twig base + seed), so leaves sway,
## green up, colour and fall with the proxy species; canes stay bare in winter.
static func city_mesh_for(species: StringName, size_m: Vector2) -> ArrayMesh:
	var key := "%s:%.2f:%.2f" % [species, size_m.x, size_m.y]
	if not _city_cache.has(key):
		_city_cache[key] = _build_city_canes(species, size_m)
	return _city_cache[key]


static func _build_city_canes(species: StringName, size_m: Vector2) -> ArrayMesh:
	var profile := BushSpecies.profile_for(species)
	var habit: Dictionary = CITY_CANES.get(species, CITY_CANES[&"raspberry"])
	var height := size_m.x
	var radius := size_m.y * 0.5
	var leaf: Color = profile["color"]
	# Cards are lit like tree cards (vertex colour near 1, the atlas carries the
	# detail): normalise the profile green so the species keeps only its tint.
	var tint := leaf / maxf(maxf(leaf.r, leaf.g), leaf.b)
	var centre := Vector3.UP * height * 0.55
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var cane_count := int(habit["canes"])
	for cane in cane_count:
		var yaw := TAU * (float(cane) + MeshMath.hash01(cane, 61, 4271) * 0.7) / float(cane_count)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var root := out * radius * 0.32 * MeshMath.hash01(cane, 67, 4283)
		var cane_height := height * lerpf(0.72, 1.0, MeshMath.hash01(cane, 71, 4297))
		var reach := (
			radius * float(habit["arch"]) * lerpf(0.75, 1.25, MeshMath.hash01(cane, 73, 4307))
		)
		# Quadratic arch: up from the root, bending outward, the tip hanging back down.
		var control := root + Vector3.UP * cane_height * 1.05 + out * reach * 0.35
		var tip := root + out * reach + Vector3.UP * cane_height * (1.0 - float(habit["droop"]))
		var points: Array[Vector3] = []
		for i in 6:
			var t := float(i) / 5.0
			points.append(root.lerp(control, t).lerp(control.lerp(tip, t), t))
		var wood := leaf.darkened(0.45)
		for i in 5:
			_append_city_tube(surface, points[i], points[i + 1], CITY_CANE_RADIUS, wood)
		var length := 0.0
		for i in 5:
			length += points[i].distance_to(points[i + 1])
		# Leaves from just above the ground litter up, one alternate pair per station.
		var stations := maxi(2, ceili(length * 0.85 / (CITY_CARD_METRES * 0.42)))
		for station in stations:
			var t := lerpf(0.15, 1.0, (float(station) + 0.5) / float(stations))
			var segment := mini(int(t * 5.0), 4)
			var local := t * 5.0 - float(segment)
			var at := points[segment].lerp(points[segment + 1], local)
			var tangent := (points[segment + 1] - points[segment]).normalized()
			var side := tangent.cross(Vector3.UP)
			if side.length_squared() < 0.0001:
				side = out.cross(Vector3.UP)
			side = side.normalized()
			for pair: float in [-1.0, 1.0]:
				var seed := cane * 97 + station * 2 + (0 if pair < 0.0 else 1)
				var roll := (MeshMath.hash01(seed, 79, 4327) - 0.5) * 0.9
				var spoke := (side * pair + Vector3.UP * roll).normalized()
				var axis := (spoke * 0.8 + tangent * 0.35 + Vector3.UP * 0.12).normalized()
				var size := CITY_CARD_METRES * lerpf(0.8, 1.12, MeshMath.hash01(seed, 83, 4337))
				var light := lerpf(0.84, 1.08, MeshMath.hash01(seed, 89, 4349))
				var color := Color(tint.r * light, tint.g * light, tint.b * light, 1.0)
				# Alpha is self-occlusion (inner, low leaves get less sky light).
				color.a = lerpf(0.62, 1.0, clampf(at.y / height, 0.0, 1.0))
				LeafGeometry.append_card(
					surface,
					at - axis * size * 0.12,
					axis,
					(Vector3.UP * 0.7 + spoke * 0.4).normalized(),
					at - centre,
					Vector2(size * 0.9, size),
					color,
					MeshMath.hash01(seed, 97, 4357),
					MeshMath.hash01(seed, 101, 4363) > 0.5
				)
	return surface.commit()


## Untagged cane segment (UV2 = 0): the canopy shader treats it as wood, with no
## seasonal collapse. Normals are set so the mixed surface lights correctly.
static func _append_city_tube(
	surface: SurfaceTool, base: Vector3, tip: Vector3, radius: float, color: Color
) -> void:
	var axis := (tip - base).normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	var forward := side.cross(axis).normalized()
	for corner in 4:
		var a0 := TAU * float(corner) / 4.0
		var a1 := TAU * float(corner + 1) / 4.0
		var n0 := side * cos(a0) + forward * sin(a0)
		var n1 := side * cos(a1) + forward * sin(a1)
		var quad := [
			[base + n0 * radius, n0],
			[tip + n0 * radius, n0],
			[tip + n1 * radius, n1],
			[base + n0 * radius, n0],
			[tip + n1 * radius, n1],
			[base + n1 * radius, n1],
		]
		for vertex: Array in quad:
			surface.set_normal(vertex[1])
			surface.set_color(color)
			surface.set_uv(Vector2.ZERO)
			surface.set_uv2(Vector2.ZERO)
			surface.set_custom(0, Color(0.0, 0.0, 0.0, 0.0))
			surface.add_vertex(vertex[0])
