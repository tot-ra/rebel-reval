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
	# R-2125 dedicated shrubs: leaf plate chosen for leaf shape (elder's compound
	# leaves read like rowan, guelder rose is lobed like maple, sea buckthorn's
	# narrow silver leaf like willow, spindle's elliptic serrated leaf like cherry).
	&"elder": &"rowan",
	&"guelder_rose": &"maple",
	&"willow_shrub": &"willow",
	&"alder_shrub": &"alder",
	&"spindle": &"cherry",
	&"sea_buckthorn": &"willow",
	&"juniper_shrub": &"juniper",
}
## Cane habit: count, outward arch (fraction of spread) and tip droop (fraction
## of height). Raspberry canes stand nearly upright; dog rose arches over.
## Optional per-species keys: card (leaf card metres), narrow (card width share),
## stem (cane radius), low (lowest cane height share), reach (arch scatter).
const CITY_CANES := {
	&"dog_rose": {"canes": 14, "arch": 0.85, "droop": 0.30},
	&"raspberry": {"canes": 15, "arch": 0.40, "droop": 0.10},
	# Elder: thick pithy stems, big compound leaves, wide arching crown.
	&"elder": {"canes": 16, "arch": 1.0, "droop": 0.22, "card": 0.26, "stem": 0.020},
	&"guelder_rose": {"canes": 13, "arch": 0.9, "droop": 0.18, "card": 0.26, "stem": 0.016},
	# Willow shrub: many long whip stems, narrow silvery leaves.
	&"willow_shrub":
	{"canes": 24, "arch": 0.7, "droop": 0.14, "card": 0.20, "narrow": 0.55, "stem": 0.010},
	&"alder_shrub": {"canes": 12, "arch": 0.8, "droop": 0.15, "card": 0.24, "stem": 0.018},
	&"spindle": {"canes": 11, "arch": 0.75, "droop": 0.10, "card": 0.20, "stem": 0.012},
	&"sea_buckthorn":
	{"canes": 17, "arch": 0.85, "droop": 0.12, "card": 0.15, "narrow": 0.45, "stem": 0.012},
	# Juniper: low, spreading, dense short needle sprays.
	&"juniper_shrub":
	{"canes": 14, "arch": 1.05, "droop": 0.04, "card": 0.13, "narrow": 1.0, "stem": 0.012},
}
## Seasonal flowers and fruit carried on the cane tips (R-2125). Kind shapes:
## umbel (flat flower head), catkin (hanging spike), blossom (five-petal disc),
## berry (octahedron cluster). Windows live in VegetationPhenology.
const CITY_ADORNMENTS := {
	&"elder":
	{
		"flower": {"shape": "umbel", "color": Color(0.96, 0.93, 0.78), "size": 0.32, "count": 3},
		"fruit": {"shape": "berry", "color": Color(0.07, 0.04, 0.09), "size": 0.02, "count": 3},
	},
	&"guelder_rose":
	{
		"flower": {"shape": "umbel", "color": Color(0.98, 0.97, 0.90), "size": 0.24, "count": 3},
		"fruit": {"shape": "berry", "color": Color(0.72, 0.06, 0.07), "size": 0.02, "count": 3},
	},
	&"willow_shrub":
	{"flower": {"shape": "catkin", "color": Color(0.78, 0.76, 0.62), "size": 0.07, "count": 4}},
	&"alder_shrub":
	{"flower": {"shape": "catkin", "color": Color(0.46, 0.34, 0.22), "size": 0.08, "count": 4}},
	&"spindle":
	{"fruit": {"shape": "berry", "color": Color(0.95, 0.38, 0.40), "size": 0.028, "count": 2}},
	&"sea_buckthorn":
	{"fruit": {"shape": "berry", "color": Color(0.98, 0.55, 0.06), "size": 0.02, "count": 4}},
	&"juniper_shrub":
	{"fruit": {"shape": "berry", "color": Color(0.20, 0.26, 0.42), "size": 0.018, "count": 2}},
	&"dog_rose":
	{
		"flower": {"shape": "blossom", "color": Color(0.96, 0.62, 0.72), "size": 0.09, "count": 2},
		"fruit": {"shape": "berry", "color": Color(0.82, 0.14, 0.08), "size": 0.024, "count": 2},
	},
	&"raspberry":
	{
		"flower": {"shape": "blossom", "color": Color(0.96, 0.95, 0.90), "size": 0.05, "count": 2},
		"fruit": {"shape": "berry", "color": Color(0.74, 0.08, 0.16), "size": 0.02, "count": 3},
	},
}
const ADORN_ANCHORS_PER_CANE := 3
const CITY_CANE_RADIUS := 0.012

static var _city_cache: Dictionary = {}


static func reset_cache() -> void:
	_city_cache.clear()
	_adornment_materials.clear()


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
	var card_m := float(habit.get("card", CITY_CARD_METRES))
	var narrow := float(habit.get("narrow", 0.9))
	var stem := float(habit.get("stem", CITY_CANE_RADIUS))
	for cane in cane_count:
		var out := _cane_out(cane, cane_count)
		var points := _cane_points(habit, cane, cane_count, height, radius)
		var wood := leaf.darkened(0.45)
		for i in 5:
			_append_city_tube(surface, points[i], points[i + 1], stem, wood)
		var length := 0.0
		for i in 5:
			length += points[i].distance_to(points[i + 1])
		# Leaves from just above the ground litter up, one alternate pair per station.
		var stations := maxi(2, ceili(length * 0.85 / (card_m * 0.42)))
		for station in stations:
			var t := lerpf(0.06, 1.0, (float(station) + 0.5) / float(stations))
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
				var size := card_m * lerpf(0.8, 1.12, MeshMath.hash01(seed, 83, 4337))
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
					Vector2(size * narrow, size),
					color,
					MeshMath.hash01(seed, 97, 4357),
					MeshMath.hash01(seed, 101, 4363) > 0.5
				)
	return surface.commit()


## Outward direction of cane `cane` (golden-ish scatter around the root).
static func _cane_out(cane: int, cane_count: int) -> Vector3:
	var yaw := TAU * (float(cane) + MeshMath.hash01(cane, 61, 4271) * 0.7) / float(cane_count)
	return Vector3(cos(yaw), 0.0, sin(yaw))


## Six control points of one arching cane, shared by the leaf and the
## flower/fruit meshes so adornments sit exactly on the canes.
static func _cane_points(
	habit: Dictionary, cane: int, cane_count: int, height: float, radius: float
) -> Array[Vector3]:
	var out := _cane_out(cane, cane_count)
	var root := out * radius * 0.32 * MeshMath.hash01(cane, 67, 4283)
	var cane_height := height * lerpf(0.72, 1.0, MeshMath.hash01(cane, 71, 4297))
	var reach := radius * float(habit["arch"]) * lerpf(0.75, 1.25, MeshMath.hash01(cane, 73, 4307))
	# Quadratic arch: up from the root, bending outward, the tip hanging back down.
	var control := root + Vector3.UP * cane_height * 1.05 + out * reach * 0.35
	var tip := root + out * reach + Vector3.UP * cane_height * (1.0 - float(habit["droop"]))
	var points: Array[Vector3] = []
	for i in 6:
		var t := float(i) / 5.0
		points.append(root.lerp(control, t).lerp(control.lerp(tip, t), t))
	return points


## True when the species carries `kind` (&"flower" or &"fruit") at some time of year.
static func has_adornment(species: StringName, kind: StringName) -> bool:
	return CITY_ADORNMENTS.get(species, {}).has(String(kind))


## Vertex-coloured flower heads or fruit clusters near the cane tips, in the same
## metre space as city_mesh_for (R-2125). Drawn with adornment_material, which
## the season switches on and off, so the leaf mesh never rebuilds.
static func city_adornment_mesh(species: StringName, size_m: Vector2, kind: StringName) -> ArrayMesh:
	var key := "%s:%.2f:%.2f:%s" % [species, size_m.x, size_m.y, kind]
	if not _city_cache.has(key):
		_city_cache[key] = _build_adornments(species, size_m, kind)
	return _city_cache[key]


static func _build_adornments(species: StringName, size_m: Vector2, kind: StringName) -> ArrayMesh:
	var spec: Dictionary = CITY_ADORNMENTS.get(species, {}).get(String(kind), {})
	if spec.is_empty():
		return ArrayMesh.new()
	var habit: Dictionary = CITY_CANES[species] if CITY_CANES.has(species) else CITY_CANES[&"raspberry"]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cane_count := int(habit["canes"])
	var colour: Color = spec["color"]
	var unit := float(spec["size"])
	for cane in cane_count:
		var points := _cane_points(habit, cane, cane_count, size_m.x, size_m.y * 0.5)
		for slot in int(spec["count"]):
			# Upper third of the cane, where flowers open and fruit hangs.
			var t := lerpf(0.62, 1.0, (float(slot) + 0.5) / float(spec["count"]))
			var segment := mini(int(t * 5.0), 4)
			var at := points[segment].lerp(points[segment + 1], t * 5.0 - float(segment))
			var seed := cane * 11 + slot
			var tone := lerpf(0.85, 1.12, MeshMath.hash01(seed, 103, 4373))
			var tinted := Color(colour.r * tone, colour.g * tone, colour.b * tone, 1.0)
			match String(spec["shape"]):
				"umbel":
					_append_disc(surface, at + Vector3.UP * unit * 0.4, unit * 0.5, 7, tinted)
				"blossom":
					_append_disc(surface, at + Vector3.UP * unit * 0.3, unit * 0.5, 5, tinted)
				"catkin":
					_append_catkin(surface, at, unit, tinted, seed)
				_:
					_append_berry_cluster(surface, at, unit, tinted, seed)
	return surface.commit()


static func _append_disc(
	surface: SurfaceTool, centre: Vector3, radius: float, sides: int, color: Color
) -> void:
	# A shallow dome (centre raised) so the head reads from a side-on camera too.
	var apex := centre + Vector3.UP * radius * 0.45
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var rim0 := centre + Vector3(cos(a0), 0.0, sin(a0)) * radius
		var rim1 := centre + Vector3(cos(a1), 0.0, sin(a1)) * radius
		var normal := (rim1 - rim0).cross(apex - rim0).normalized()
		if normal.y < 0.0:
			normal = -normal
		for vertex: Vector3 in [apex, rim0, rim1]:
			surface.set_normal(normal)
			surface.set_color(color)
			surface.add_vertex(vertex)


## Hanging spike: a four-sided tapering prism, `unit` wide and six times as long.
static func _append_catkin(
	surface: SurfaceTool, top: Vector3, unit: float, color: Color, seed: int
) -> void:
	var length := unit * 6.0 * lerpf(0.8, 1.2, MeshMath.hash01(seed, 107, 4391))
	var tip := top + Vector3.DOWN * length
	var half := unit * 0.35
	var ring: Array[Vector3] = [
		Vector3(half, 0.0, 0.0), Vector3(0.0, 0.0, half),
		Vector3(-half, 0.0, 0.0), Vector3(0.0, 0.0, -half),
	]
	for i in 4:
		var a := top + ring[i]
		var b := top + ring[(i + 1) % 4]
		var normal := (ring[i] + ring[(i + 1) % 4]).normalized()
		for vertex: Vector3 in [a, b, tip]:
			surface.set_normal(normal)
			surface.set_color(color)
			surface.add_vertex(vertex)


## A few berries clumped around `at`, each an octahedron of radius `unit`.
static func _append_berry_cluster(
	surface: SurfaceTool, at: Vector3, unit: float, color: Color, seed: int
) -> void:
	for berry in 5:
		var s := seed * 7 + berry
		var offset := Vector3(
			MeshMath.hash01(s, 109, 4397) - 0.5,
			-MeshMath.hash01(s, 113, 4409) * 0.8,
			MeshMath.hash01(s, 127, 4421) - 0.5
		) * unit * 4.0
		var c := at + offset
		var r := unit * lerpf(0.85, 1.15, MeshMath.hash01(s, 131, 4423))
		var corners: Array[Vector3] = [
			c + Vector3.RIGHT * r, c + Vector3.LEFT * r, c + Vector3.UP * r,
			c + Vector3.DOWN * r, c + Vector3.BACK * r, c + Vector3.FORWARD * r,
		]
		for face: Array in [
			[2, 0, 4], [2, 4, 1], [2, 1, 5], [2, 5, 0],
			[3, 4, 0], [3, 1, 4], [3, 5, 1], [3, 0, 5],
		]:
			var normal := (
				(corners[face[0]] + corners[face[1]] + corners[face[2]]) / 3.0 - c
			).normalized()
			for index: int in face:
				surface.set_normal(normal)
				surface.set_color(color)
				surface.add_vertex(corners[index])


static var _adornment_materials: Dictionary = {}
## Last date applied, so a material built after the season push starts in season.
static var _adornment_date: Dictionary = GameCalendar.DEFAULT_DATE


## Shared unlit-colour material for flowers or fruit. Alpha scissor lets the season
## hide it through one uniform (same trick as MapViewPropMaterials.tree_fruit).
static func adornment_material(species: StringName, kind: StringName) -> StandardMaterial3D:
	var key := "%s:%s" % [species, kind]
	if not _adornment_materials.has(key):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.7
		# Pale heads and berries stay readable in leaf shade.
		material.emission_enabled = true
		material.emission = Color(0.12, 0.12, 0.11)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		material.set_meta(&"shrub_species", species)
		material.set_meta(&"shrub_kind", kind)
		_adornment_materials[key] = material
		_set_adornment_season(material, _adornment_date)
	return _adornment_materials[key]


## Shows or hides every shrub flower/fruit material for the campaign date.
static func apply_adornment_season(date: Dictionary) -> void:
	_adornment_date = date
	for material: StandardMaterial3D in _adornment_materials.values():
		_set_adornment_season(material, date)


static func _set_adornment_season(material: StandardMaterial3D, date: Dictionary) -> void:
	var visible := VegetationPhenology.shrub_adornment_visible(
		material.get_meta(&"shrub_species"), material.get_meta(&"shrub_kind"), date
	)
	material.albedo_color = Color(1.0, 1.0, 1.0, 1.0 if visible else 0.0)


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
