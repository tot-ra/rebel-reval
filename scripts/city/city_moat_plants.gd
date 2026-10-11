class_name CityMoatPlants
extends RefCounted

## Water plants of the moat and the Hareapea stream: reed and cattail clumps
## rooted in the shallows along both banks, and floating lily pads and duckweed
## mats on the open surface. Visual only, deterministic.
## Placement reads the water records ([a, b, surface_a, surface_b, half]) that
## CityWorld3D builds, so plants follow the water, not the plan line. On the
## stream the reed belt also climbs a little onto the wet bank (a slow lowland
## brook is fringed with reed and sedge, so the bank does not start bare) and
## floating plants are sparser. No visibility range: it measures from the node
## origin, which is far from the water.

const STEP := 1.7
const SEED := 4417
## Reeds root where the bed lies this far under the surface.
const REED_MIN_DEPTH := -0.05
const REED_MAX_DEPTH := 0.8
## Stream banks: reeds also root on wet ground up to this far above the surface.
const STREAM_REED_MIN_DEPTH := -0.3
## Share of floating-plant chances kept on the stream (the water moves).
const STREAM_FLOAT_SHARE := 0.4
## Floating plants need the bed at least this far under the surface.
const FLOAT_MIN_DEPTH := 0.5
const PAD_RADIUS := 0.3
const REED_GREEN := Color(0.42, 0.5, 0.2)
const REED_STRAW := Color(0.62, 0.5, 0.26)
const PAD_GREEN := Color(0.2, 0.42, 0.16)
const PAD_AUTUMN := Color(0.5, 0.4, 0.14)
const CATTAIL_STRAW := Color(0.78, 0.66, 0.44)


static func build(plan: CityPlan, records: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "MoatPlants"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var reeds: Array[Transform3D] = []
	var reed_colors: Array[Color] = []
	var cattails: Array[Transform3D] = []
	var cattail_colors: Array[Color] = []
	var pads: Array[Transform3D] = []
	var pad_colors: Array[Color] = []
	var mats: Array[Transform3D] = []
	var mat_colors: Array[Color] = []
	var flowers: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	var fronds: Array[Transform3D] = []
	var frond_colors: Array[Color] = []
	for rec: Array in records:
		var a: Vector2 = rec[0]
		var b: Vector2 = rec[1]
		var stream := not plan.in_moat((a + b) * 0.5, 1.0)
		var reed_min := STREAM_REED_MIN_DEPTH if stream else REED_MIN_DEPTH
		var float_chance := 0.22 * (STREAM_FLOAT_SHARE if stream else 1.0)
		var length := a.distance_to(b)
		var dir := (b - a) / maxf(length, 0.001)
		var side := dir.orthogonal()
		var half := float(rec[4])
		var steps := maxi(int(length / STEP), 1)
		for k in steps:
			var t := (float(k) + rng.randf()) / float(steps)
			var centre := a.lerp(b, t)
			var surface := lerpf(float(rec[2]), float(rec[3]), t)
			for bank: float in [-1.0, 1.0]:
				var p := centre + side * bank * rng.randf_range(half * 0.5, half * 1.02)
				var depth := surface - plan.ground_height(p)
				if depth < reed_min or depth > REED_MAX_DEPTH:
					continue
				if not is_nan(plan.bridge_deck_height(p)):
					continue
				var foot := Vector3(p.x, plan.ground_height(p) - 0.05, p.y)
				var yaw := Basis(Vector3.UP, rng.randf() * TAU)
				if rng.randf() < 0.5:
					cattails.append(
						Transform3D(yaw.scaled(Vector3.ONE * rng.randf_range(1.5, 2.3)), foot)
					)
					var tone := rng.randf_range(0.85, 1.1)
					cattail_colors.append(Color(tone, tone, tone, 1.0))
				else:
					for j in 6:
						var off := Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6))
						reeds.append(
							Transform3D(
								yaw.scaled(Vector3.ONE * rng.randf_range(1.5, 2.4)), foot + off
							)
						)
						var shade := rng.randf_range(0.8, 1.1)
						reed_colors.append(Color(shade * 0.9, shade, shade * 0.7, 1.0))
			# Floating plants out on the open water.
			if rng.randf() < float_chance:
				var c := centre + side * rng.randf_range(-half * 0.6, half * 0.6)
				if surface - plan.ground_height(c) < FLOAT_MIN_DEPTH:
					continue
				if not is_nan(plan.bridge_deck_height(c)):
					continue
				var y := surface + 0.05
				if rng.randf() < 0.5:
					for j in rng.randi_range(4, 9):
						var q := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 1.3)
						var s := rng.randf_range(1.6, 2.6)
						pads.append(
							Transform3D(
								Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, 1.0, s)),
								Vector3(q.x, y, q.y)
							)
						)
						var g := rng.randf_range(0.75, 1.1)
						pad_colors.append(Color(g * 0.8, g, g * 0.7, 1.0))
				else:
					var s := rng.randf_range(1.8, 3.4)
					mats.append(
						Transform3D(
							Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, 1.0, s * 0.7)),
							Vector3(c.x, y - 0.02, c.y)
						)
					)
					var g := rng.randf_range(0.85, 1.1)
					mat_colors.append(Color(g, g, g * 0.8, 1.0))
	# Shuffle each group so dying back thins the stand evenly, not along the bank.
	_shuffle_together(rng, reeds, reed_colors)
	_shuffle_together(rng, cattails, cattail_colors)
	_shuffle_together(rng, pads, pad_colors)
	_shuffle_together(rng, mats, mat_colors)
	_add_reeds(root, reeds, reed_colors)
	_add_cattails(root, cattails, cattail_colors)
	_add_floating(root, "LilyPads", _pad_mesh(), pads, pad_colors, PAD_GREEN)
	_add_floating(root, "Duckweed", _mat_mesh(), mats, mat_colors, Color(0.42, 0.52, 0.16))
	# Per-vertex colours carry the tone of these two, so the tint is white.
	_add_floating(root, "LilyFlowers", _flower_mesh(), flowers, flower_colors, Color.WHITE)
	_add_floating(root, "DuckweedFronds", _frond_cluster_mesh(), fronds, frond_colors, Color.WHITE)
	return root


static func _shuffle_together(
	rng: RandomNumberGenerator, xf: Array[Transform3D], colors: Array[Color]
) -> void:
	for i in range(xf.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := xf[i]
		xf[i] = xf[j]
		xf[j] = t
		var c := colors[i]
		colors[i] = colors[j]
		colors[j] = c


## ADR 0045: seasons for the water plants. Reeds and cattails yellow, then brown,
## then thin out to nothing in a hard winter; lily pads, flowers and duckweed die
## back with the cold water. Cheap: visible_instance_count and one tint per node.
static func apply_season(root: Node3D, day_of_year: float) -> void:
	if root == null:
		return
	var standing := SeasonState.reed_standing(day_of_year)
	var dead := SeasonState.reed_dead_share(day_of_year)
	var vigour := SeasonState.water_plant_vigour(day_of_year)
	var flowers := SeasonState.lily_flower_share(day_of_year)
	for child in root.get_children():
		var inst := child as MultiMeshInstance3D
		if inst == null or inst.multimesh == null:
			continue
		var count := inst.multimesh.instance_count
		match String(inst.name):
			"Reeds":
				_set_share(inst, count, standing)
				var mat := inst.material_override as StandardMaterial3D
				if mat == null:
					mat = inst.multimesh.mesh.surface_get_material(0) as StandardMaterial3D
				if mat != null:
					mat.albedo_color = REED_GREEN.lerp(REED_STRAW, dead)
			"Cattails":
				_set_share(inst, count, standing)
				var cat_mat := inst.material_override as StandardMaterial3D
				if cat_mat != null:
					cat_mat.albedo_color = Color.WHITE.lerp(CATTAIL_STRAW, dead)
			"LilyFlowers":
				_set_share(inst, count, flowers)
			"LilyPads", "Duckweed", "DuckweedFronds":
				_set_share(inst, count, vigour)
				var float_mat := inst.material_override as StandardMaterial3D
				if float_mat != null and inst.name == &"LilyPads":
					float_mat.albedo_color = PAD_GREEN.lerp(PAD_AUTUMN, dead)


static func _set_share(inst: MultiMeshInstance3D, count: int, share: float) -> void:
	inst.multimesh.visible_instance_count = int(round(float(count) * clampf(share, 0.0, 1.0)))
	inst.visible = inst.multimesh.visible_instance_count > 0


static func _add_reeds(root: Node3D, xf: Array[Transform3D], colors: Array[Color]) -> void:
	if xf.is_empty():
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = REED_GREEN
	material.vertex_color_use_as_albedo = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	var inst := MapViewMeshBuilderPrimitives.multi_mesh(
		"Reeds", MapViewMeshBuilderPrimitives.reed_stem_mesh(), xf, colors, material, Vector3.ZERO
	)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inst)


static func _add_cattails(root: Node3D, xf: Array[Transform3D], colors: Array[Color]) -> void:
	if xf.is_empty():
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.95
	var inst := MapViewMeshBuilderPrimitives.multi_mesh(
		"Cattails",
		MapViewMeshBuilderPrimitives.cattail_cluster_mesh(),
		xf,
		colors,
		material,
		Vector3.ZERO
	)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inst)


static func _add_floating(
	root: Node3D,
	node_name: String,
	mesh: Mesh,
	xf: Array[Transform3D],
	colors: Array[Color],
	tint: Color
) -> void:
	if xf.is_empty():
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	var inst := MapViewMeshBuilderPrimitives.multi_mesh(
		node_name, mesh, xf, colors, material, Vector3.ZERO
	)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inst)


## A lily leaf: three rings of 14 segments with a V notch toward +X, a gently
## cupped rim that curls up, and alternating darker/lighter radial bands that
## read as veins. Vertex colours hold the vein pattern (tint is multiplied in).
static func _pad_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 14
	var radii := [0.0, 0.38, 0.72, 1.0]
	for ring in range(1, radii.size()):
		for i in segs:
			# Segment 0 is left open: the notch.
			if i == 0:
				continue
			var a0 := TAU * float(i) / segs
			var a1 := TAU * float(i + 1) / segs
			var r0: float = radii[ring - 1]
			var r1: float = radii[ring]
			var vein := 0.86 if i % 2 == 0 else 1.0
			var quad: Array[Vector3] = [
				_pad_point(a0, r0), _pad_point(a1, r0), _pad_point(a1, r1), _pad_point(a0, r1)
			]
			# Inner rings are paler (young leaf centre); the rim is darker.
			var shade := vein * (1.06 - 0.12 * float(ring))
			var col := Color(shade, shade, shade, 1.0)
			# Ring 1 is a fan: its inner points coincide at the hub.
			var order := [0, 3, 2] if ring == 1 else [0, 3, 2, 0, 2, 1]
			for idx: int in order:
				st.set_color(col)
				st.set_normal(Vector3.UP)
				st.add_vertex(quad[idx])
	return st.commit()


## Leaf surface point: the rim rises with r^3 so the pad is a shallow dish.
static func _pad_point(angle: float, radius: float) -> Vector3:
	var lift := 0.05 * pow(radius, 3.0) * PAD_RADIUS
	return Vector3(cos(angle) * radius * PAD_RADIUS, lift, sin(angle) * radius * PAD_RADIUS)


## A white water-lily bloom: two rings of pointed petals around a yellow heart,
## sized to sit on a pad (petal tips curl up and out).
static func _flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var layers := [[8, 0.17, 0.05, 0.0], [6, 0.12, 0.09, 0.26]]
	for layer: Array in layers:
		var count: int = layer[0]
		var reach: float = layer[1]
		var rise: float = layer[2]
		var twist: float = layer[3]
		for i in count:
			var a := TAU * float(i) / count + twist
			var half := TAU / count * 0.4
			var base_l := Vector3(cos(a - half * 0.5), 0.0, sin(a - half * 0.5)) * reach * 0.2
			var base_r := Vector3(cos(a + half * 0.5), 0.0, sin(a + half * 0.5)) * reach * 0.2
			# Broad middle, pointed tip that lifts: a petal, not a spike.
			var wide := Vector3(reach * 0.62, 1.0, reach * 0.62)
			var mid_l := Vector3(cos(a - half), rise, sin(a - half)) * wide
			var mid_r := Vector3(cos(a + half), rise, sin(a + half)) * wide
			var tip := Vector3(cos(a), rise * 2.0, sin(a)) * Vector3(reach, 1.0, reach)
			var white := Color(1.0, 0.98, 0.95, 1.0)
			var blush := Color(0.98, 0.86, 0.9, 1.0)
			for tri: Array in [
				[base_l, base_r, mid_r, white, white, white],
				[base_l, mid_r, mid_l, white, white, white],
				[mid_l, mid_r, tip, white, white, blush]
			]:
				for k in 3:
					st.set_color(tri[k + 3])
					st.set_normal(Vector3.UP)
					st.add_vertex(tri[k])
	# Yellow stamen disc.
	for i in 8:
		var a0 := TAU * float(i) / 8.0
		var a1 := TAU * float(i + 1) / 8.0
		for v: Vector3 in [
			Vector3(0.0, 0.05, 0.0),
			Vector3(cos(a1), 0.04, sin(a1)) * 0.035,
			Vector3(cos(a0), 0.04, sin(a0)) * 0.035
		]:
			st.set_color(Color(1.0, 0.82, 0.2, 1.0))
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


## Duckweed (Lemna): a cluster of ~110 tiny, almost perfectly round fronds
## (each ~5 cm across) that float flat and slightly overlap, thick in the middle
## and thinning to scattered singles at the edge. Deterministic layout.
static func _frond_cluster_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var segs := 8
	for i in 110:
		# sqrt-free radius bias toward the centre gives a dense core.
		var dist := pow(rng.randf(), 1.4)
		var pos := Vector2.from_angle(rng.randf() * TAU) * dist
		var r := rng.randf_range(0.022, 0.038)
		var y := rng.randf_range(0.0, 0.012)
		var shade := rng.randf_range(0.8, 1.15)
		var col := Color(shade * 0.9, shade, shade * 0.55, 1.0)
		for k in segs:
			var a0 := TAU * float(k) / segs
			var a1 := TAU * float(k + 1) / segs
			for v: Vector3 in [
				Vector3(pos.x, y, pos.y),
				Vector3(pos.x + cos(a1) * r, y, pos.y + sin(a1) * r),
				Vector3(pos.x + cos(a0) * r, y, pos.y + sin(a0) * r)
			]:
				st.set_color(col)
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	return st.commit()


## An irregular duckweed film: a flat fan with a ragged outline.
static func _mat_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	var radii := PackedFloat32Array()
	for i in n:
		radii.append(0.6 + 0.4 * absf(sin(float(i) * 2.399)))
	for i in n:
		var a0 := TAU * float(i) / n
		var a1 := TAU * float(i + 1) / n
		for v: Vector3 in [
			Vector3.ZERO,
			Vector3(cos(a1), 0.0, sin(a1)) * radii[(i + 1) % n],
			Vector3(cos(a0), 0.0, sin(a0)) * radii[i]
		]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()
