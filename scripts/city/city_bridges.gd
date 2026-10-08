class_name CityBridges
extends RefCounted

## Timber bridges where the extramural roads cross the Hareapea, and the short
## harbour jetties and beach decks (plan `bridges`, `rails: false` for decks).
## No 1343 bridge is attested; a plank deck on pile trestles is a reversible
## reconstruction (docs/SYSTEMS/FARMLAND.md, Bridges). Kalev walks the deck
## through CityPlan.bridge_deck_height; the water under it is not swimmable there.

const TRESTLE_STEP := 4.0
const PLANK_THICKNESS := 0.09
const PLANK_WIDTH := 0.26
const PLANK_GAP := 0.025
const STRINGER_SIZE := 0.2
const RAIL_HEIGHT := 1.0
## Piles are wet (dark, mossy) this far above the waterline.
const SPLASH_HEIGHT := 0.45


static func build(plan: CityPlan, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Bridges"
	parent.add_child(root)
	for b: Dictionary in plan.data.get("bridges", []):
		root.add_child(_bridge(plan, b, parent))
	return root


## Shared look: adzed silvered oak (normal-mapped hewn timber) instead of the old
## stretched procedural plank pattern, which smeared over large box faces. WHY:
## every piece gets UVs fitted to its own size (hewn_timber_for_size) so grain
## stays crisp, and decay is layered on top: per-plank tone, cracks, lichen on
## the dry deck, and dark rotten moss-grown piles at the waterline.
static func _beam(size: Vector3, seed_value: int, tint: Color) -> StandardMaterial3D:
	var material := MapViewMaterials.hewn_timber_for_size(size, seed_value).duplicate()
	material.albedo_color = material.albedo_color * tint
	return material


static func _wet_timber(size: Vector3, seed_value: int) -> StandardMaterial3D:
	# Water-soaked oak: near black-brown with a green cast, glossier than dry wood.
	var material := _beam(size, seed_value, Color(0.78, 0.84, 0.66))
	material.roughness = 0.62
	return material


static func _moss_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.09
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.seamless = true
	texture.width = 128
	texture.height = 128
	material.albedo_texture = texture
	material.albedo_color = Color(0.36, 0.5, 0.22)
	material.roughness = 1.0
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(3.0, 3.0, 3.0)
	return material


static func _lichen_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.76, 0.52)
	material.roughness = 1.0
	return material


static func _crack_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.05, 0.04, 0.035)
	material.roughness = 1.0
	return material


static func _bridge(plan: CityPlan, b: Dictionary, parent: Node3D) -> Node3D:
	var node := Node3D.new()
	node.name = String(b["id"]).replace(".", "_")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(b["id"]))
	var at := Vector2(b["at"][0], b["at"][1])
	var angle := float(b["angle"])
	var length := float(b["length"])
	var width := float(b["width"])
	var along := Vector2.from_angle(angle)
	var across := along.orthogonal()
	var yaw := -angle
	var tilt := atan2(float(b["hb"]) - float(b["ha"]), length)
	var frame := Basis.from_euler(Vector3(0.0, yaw, tilt))
	var steps := maxi(int(ceil(length / 2.0)), 2)
	var moss := _moss_material()
	var lichen := _lichen_material()
	var lichen_transforms: Array[Transform3D] = []
	var moss_transforms: Array[Transform3D] = []
	var crack_transforms: Array[Transform3D] = []

	# Deck planks: individual boards across the span, each slightly off-true,
	# batched into one MultiMesh per grain variant (instance colour = wear tone).
	var plank_mesh := BoxMesh.new()
	plank_mesh.size = Vector3(width, PLANK_THICKNESS, PLANK_WIDTH)
	var plank_count := int(length / (PLANK_WIDTH + PLANK_GAP))
	var variant_xforms: Array = [[], [], []]
	var variant_colors: Array = [[], [], []]
	for i in plank_count:
		var s := (float(i) + 0.5) * (PLANK_WIDTH + PLANK_GAP)
		var t := s / length
		var p := at + along * (s - length * 0.5)
		var top := CityPlan.bridge_deck_at(b, t) + rng.randf_range(-0.012, 0.004)
		var basis := (
			frame
			* Basis(Vector3.UP, PI * 0.5 + rng.randf_range(-0.025, 0.025))
			* Basis(Vector3.RIGHT, rng.randf_range(-0.02, 0.02))
		)
		basis = basis * Basis.from_scale(Vector3(rng.randf_range(0.97, 1.0), 1.0, 1.0))
		var v := rng.randi() % 3
		variant_xforms[v].append(
			Transform3D(basis, Vector3(p.x, top - PLANK_THICKNESS * 0.5, p.y))
		)
		# Tone: mostly silver-grey, some boards dark and rotten, a few greened.
		var tone := rng.randf_range(0.85, 1.12)
		var color := Color(tone, tone, tone)
		var roll := rng.randf()
		if roll < 0.14:
			color = Color(0.46, 0.44, 0.38)
		elif roll < 0.24:
			color = Color(tone * 0.82, tone * 0.95, tone * 0.72)
		variant_colors[v].append(color)
		var top_point := Vector3(p.x, top + 0.004, p.y)
		# Checks along the grain (across the span) and lichen rosettes.
		if rng.randf() < 0.45:
			var off := across * rng.randf_range(-width * 0.4, width * 0.4)
			var crack_len := rng.randf_range(0.3, 1.1)
			var cb := frame * Basis(Vector3.UP, PI * 0.5 + rng.randf_range(-0.05, 0.05))
			cb = cb * Basis.from_scale(Vector3(crack_len, 1.0, 1.0))
			crack_transforms.append(
				Transform3D(cb, top_point + Vector3(off.x, 0.0, off.y))
			)
		if rng.randf() < 0.2:
			var off := across * rng.randf_range(-width * 0.5, width * 0.5)
			var r := rng.randf_range(0.5, 1.6)
			lichen_transforms.append(
				Transform3D(frame * Basis.from_scale(Vector3(r, 1.0, r)),
					top_point + Vector3(off.x, 0.002, off.y))
			)
	for v in 3:
		if variant_xforms[v].is_empty():
			continue
		var material := _beam(plank_mesh.size, v, Color.WHITE)
		material.vertex_color_use_as_albedo = true
		var xforms: Array[Transform3D] = []
		xforms.assign(variant_xforms[v])
		var colors: Array[Color] = []
		colors.assign(variant_colors[v])
		var inst := MapViewMeshBuilderPrimitives.multi_mesh(
			"Planks%d" % v, plank_mesh, xforms, colors, material, Vector3.ZERO
		)
		node.add_child(inst)

	# Stringers: three longitudinal beams under the planks.
	for offset_w: float in [-width * 0.5 + 0.2, 0.0, width * 0.5 - 0.2]:
		var off := across * offset_w
		for i in steps:
			var t0 := float(i) / steps
			var t1 := float(i + 1) / steps
			var p0 := at + along * (t0 - 0.5) * length + off
			var p1 := at + along * (t1 - 0.5) * length + off
			var y0 := CityPlan.bridge_deck_at(b, t0) - PLANK_THICKNESS - STRINGER_SIZE * 0.5
			var y1 := CityPlan.bridge_deck_at(b, t1) - PLANK_THICKNESS - STRINGER_SIZE * 0.5
			var seg := p0.distance_to(p1)
			var beam_size := Vector3(seg + 0.05, STRINGER_SIZE, STRINGER_SIZE)
			var beam := MeshInstance3D.new()
			var bmesh := BoxMesh.new()
			bmesh.size = beam_size
			beam.mesh = bmesh
			beam.material_override = _beam(beam_size, i + int(offset_w * 10.0), Color(1.0, 0.97, 0.9))
			var mid := (p0 + p1) * 0.5
			beam.position = Vector3(mid.x, (y0 + y1) * 0.5, mid.y)
			beam.rotation = Vector3(0.0, yaw, atan2(y1 - y0, seg))
			node.add_child(beam)

	# Rails and trestles on both sides.
	var railed: bool = b.get("rails", true)
	var has_water := parent.has_method("water_surface_at")
	for side: float in [-1.0, 1.0]:
		var offset := across * side * (width * 0.5 - 0.1)
		for i in steps if railed else 0:
			var t0 := float(i) / steps
			var t1 := float(i + 1) / steps
			var p0 := at + along * (t0 - 0.5) * length + offset
			var p1 := at + along * (t1 - 0.5) * length + offset
			var seg := p0.distance_to(p1)
			var mid := (p0 + p1) * 0.5
			for h: float in [RAIL_HEIGHT * 0.8, RAIL_HEIGHT * 0.4]:
				var y0 := CityPlan.bridge_deck_at(b, t0) + h
				var y1 := CityPlan.bridge_deck_at(b, t1) + h
				var rail_size := Vector3(seg + 0.05, 0.1, 0.14) if h > 0.5 else Vector3(seg + 0.05, 0.08, 0.1)  # gdlint: ignore=max-line-length
				var rail := MeshInstance3D.new()
				var rbox := BoxMesh.new()
				rbox.size = rail_size
				rail.mesh = rbox
				rail.material_override = _beam(rail_size, i + int(side), Color(1.15, 1.1, 1.0))
				rail.position = Vector3(mid.x, (y0 + y1) * 0.5, mid.y)
				rail.rotation = Vector3(0.0, yaw, atan2(y1 - y0, seg))
				node.add_child(rail)
				if h > 0.5 and rng.randf() < 0.35:
					lichen_transforms.append(
						Transform3D(
							Basis.from_euler(rail.rotation) * Basis.from_scale(Vector3.ONE * rng.randf_range(0.5, 1.2)),
							rail.position + Vector3(0.0, 0.052, 0.0)
						)
					)
		var posts := maxi(int(length / TRESTLE_STEP), 1) + 1
		for k in posts:
			var t := float(k) / maxf(posts - 1, 1)
			var p := at + along * (t - 0.5) * length + offset
			var deck := CityPlan.bridge_deck_at(b, t)
			var bed := plan.ground_height(p) - 0.4
			var post_top := deck + (RAIL_HEIGHT if railed else 0.35)
			var water: float = parent.water_surface_at(p) if has_water else -INF
			# Dry bank: no water line, the whole post stays dry timber.
			var wet_top := minf(water + SPLASH_HEIGHT, post_top - 0.3) if water > -INF else bed
			wet_top = maxf(wet_top, bed)
			var wet_size := Vector3(0.34, wet_top - bed, 0.34)
			if wet_size.y > 0.05:
				var wet := MeshInstance3D.new()
				var wmesh := BoxMesh.new()
				wmesh.size = wet_size
				wet.mesh = wmesh
				wet.material_override = _wet_timber(wet_size, k)
				wet.position = Vector3(p.x, (wet_top + bed) * 0.5, p.y)
				node.add_child(wet)
				if water > -INF:
					# Moss collar riding the waterline, thicker on shaded sides.
					for _m in 4:
						var collar := Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0))
						moss_transforms.append(
							Transform3D(
								collar * Basis.from_scale(Vector3(rng.randf_range(0.9, 1.4), rng.randf_range(0.7, 1.4), rng.randf_range(0.9, 1.4))),  # gdlint: ignore=max-line-length
								Vector3(p.x, water + rng.randf_range(0.0, 0.3), p.y)
							)
						)
			var dry_size := Vector3(0.28, post_top - wet_top, 0.28)
			var dry := MeshInstance3D.new()
			var dmesh := BoxMesh.new()
			dmesh.size = dry_size
			dry.mesh = dmesh
			dry.material_override = _beam(dry_size, k + 1, Color(1.1, 1.06, 0.98))
			dry.position = Vector3(p.x, (post_top + wet_top) * 0.5, p.y)
			node.add_child(dry)

	_add_scatter(node, "Lichen", lichen_transforms, lichen, 0.16)
	_add_scatter(node, "Moss", moss_transforms, moss, 0.2)
	_add_cracks(node, crack_transforms)
	return node


static func _add_scatter(
	node: Node3D, node_name: String, xforms: Array[Transform3D], material: Material, radius: float
) -> void:
	if xforms.is_empty():
		return
	var mesh: Mesh
	if node_name == "Moss":
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 1.1
		sphere.radial_segments = 8
		sphere.rings = 4
		mesh = sphere
	else:
		var disc := CylinderMesh.new()
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.008
		disc.radial_segments = 8
		disc.rings = 1
		mesh = disc
	var colors: Array[Color] = []
	for _i in xforms.size():
		colors.append(Color.WHITE)
	node.add_child(
		MapViewMeshBuilderPrimitives.multi_mesh(node_name, mesh, xforms, colors, material, Vector3.ZERO)
	)


static func _add_cracks(node: Node3D, xforms: Array[Transform3D]) -> void:
	if xforms.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.006, 0.014)
	var colors: Array[Color] = []
	for _i in xforms.size():
		colors.append(Color.WHITE)
	node.add_child(
		MapViewMeshBuilderPrimitives.multi_mesh(
			"Cracks", mesh, xforms, colors, _crack_material(), Vector3.ZERO
		)
	)
