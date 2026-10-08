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
	_add_reeds(root, reeds, reed_colors)
	_add_cattails(root, cattails, cattail_colors)
	_add_floating(root, "LilyPads", _pad_mesh(), pads, pad_colors, Color(0.2, 0.42, 0.16))
	_add_floating(root, "Duckweed", _mat_mesh(), mats, mat_colors, Color(0.42, 0.52, 0.16))
	return root


static func _add_reeds(root: Node3D, xf: Array[Transform3D], colors: Array[Color]) -> void:
	if xf.is_empty():
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.5, 0.2)
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


## A flat round lily leaf with a notch, face up.
static func _pad_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 10
	for i in range(1, n):
		var a0 := TAU * float(i) / n + 0.25
		var a1 := TAU * float(i + 1) / n + 0.25
		for v: Vector3 in [
			Vector3.ZERO,
			Vector3(cos(a1), 0.0, sin(a1)) * PAD_RADIUS,
			Vector3(cos(a0), 0.0, sin(a0)) * PAD_RADIUS
		]:
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
