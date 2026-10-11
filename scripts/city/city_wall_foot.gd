class_name CityWallFoot
extends RefCounted

## Where the houses meet the ground (ADR 0031): weed tufts and nettles along
## the wall foot, thickest at corners and yard sides, never in a doorway, and
## climbing hop/ivy on a few walls. Together with the splat's drip-line mud and
## the wall shader's rising damp this hides the hard building/ground seam.
## The vine leaf card is drawn procedurally at startup (no texture asset).

const CHUNK := 96.0
const TUFT_RANGE := 90.0
const VINE_RANGE := 220.0
const TUFT_SPACING := 0.9
const TUFT_CHANCE := 0.45
## Share of houses with a climber on one wall.
const VINE_SHARE := 0.09
const LEAF := 0.42

static var _vine_material: StandardMaterial3D


static func build(plan: CityPlan, parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "WallFoot"
	parent.add_child(root)
	var tufts: Dictionary = {}
	var vines := SurfaceTool.new()
	vines.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vine_count := 0
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		var ring := CityBuildingBuilder.wall_ring(b, plan.footprint(i))
		if ring.size() < 3:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(b["id"]) + ":foot")
		var door := Vector2.INF
		if b.get("door") != null:
			door = Vector2(b["door"][0], b["door"][1])
		var center := Vector2.ZERO
		for p in ring:
			center += p
		center /= ring.size()
		for e in ring.size():
			var a := ring[e]
			var c := ring[(e + 1) % ring.size()]
			var length := a.distance_to(c)
			var out := (a + c) * 0.5 - center
			var normal := Vector2(-(c - a).y, (c - a).x).normalized()
			if normal.dot(out) < 0.0:
				normal = -normal
			var steps := int(length / TUFT_SPACING)
			for k in steps:
				var t := (float(k) + rng.randf()) / maxf(steps, 1)
				var p := a.lerp(c, t)
				if p.distance_to(door) < 1.6:
					continue
				# Corners gather more: the broom and the cart wheel miss them.
				var corner := minf(t, 1.0 - t) * length < 1.2
				if rng.randf() > (0.85 if corner else TUFT_CHANCE):
					continue
				var at := p + normal * rng.randf_range(0.05, 0.35)
				var key := Vector2i(floori(at.x / CHUNK), floori(at.y / CHUNK))
				if not tufts.has(key):
					tufts[key] = {"xf": [] as Array[Transform3D], "c": [] as Array[Color]}
				var s := rng.randf_range(0.35, 0.75) * (1.3 if corner else 1.0)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.8, s))
				(tufts[key]["xf"] as Array[Transform3D]).append(
					Transform3D(basis, Vector3(at.x, plan.ground_height(at) - 0.03, at.y))
				)
				var tone := rng.randf_range(0.7, 1.0)
				(tufts[key]["c"] as Array[Color]).append(Color(tone * 0.95, tone, tone * 0.8))
		if String(b.get("kind", "")) == "house" and rng.randf() < VINE_SHARE:
			var e := rng.randi() % ring.size()
			var a := ring[e]
			var c := ring[(e + 1) % ring.size()]
			if a.distance_to(c) > 2.5 and (a.lerp(c, 0.5)).distance_to(door) > 2.5:
				var top := plan.floor_height(i) + float(b["wall_h"]) * rng.randf_range(0.45, 0.95)
				vine_count += _vine(vines, plan, a, c, center, top, rng)
	var keys := tufts.keys()
	keys.sort()
	for key: Vector2i in keys:
		var inst := MapViewMeshBuilderPrimitives.multi_mesh(
			"Tufts_%d_%d" % [key.x, key.y],
			MapViewMeshBuilderPrimitives.grass_tuft_mesh(),
			tufts[key]["xf"],
			tufts[key]["c"],
			MapViewMaterials.grass_blades(),
			Vector3.ZERO
		)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.visibility_range_end = TUFT_RANGE
		root.add_child(inst)
	if vine_count > 0:
		var inst := MeshInstance3D.new()
		inst.name = "Climbers"
		vines.generate_normals()
		inst.mesh = vines.commit()
		inst.material_override = vine_material()
		inst.visibility_range_end = VINE_RANGE
		root.add_child(inst)


## Leaf cards over part of the wall a-c, dense at the foot, thinning upward
## in a few climbing runs. Returns the number of cards.
static func _vine(
	st: SurfaceTool,
	plan: CityPlan,
	a: Vector2,
	c: Vector2,
	center: Vector2,
	top: float,
	rng: RandomNumberGenerator
) -> int:
	var dir := (c - a).normalized()
	var normal := Vector2(-dir.y, dir.x)
	if normal.dot((a + c) * 0.5 - center) < 0.0:
		normal = -normal
	var length := a.distance_to(c)
	var span := minf(length * rng.randf_range(0.35, 0.8), 5.5)
	var start := rng.randf_range(0.0, length - span)
	var runs := 2 + rng.randi() % 3
	var cards := 0
	var green := Color(rng.randf_range(0.75, 0.95), 1.0, rng.randf_range(0.7, 0.85))
	for r in runs:
		var x := start + span * (float(r) + 0.5) / runs
		var base := plan.ground_height(a + dir * x)
		var y := base
		while y < top:
			# Each run spreads wider as it climbs, then thins out near its tip.
			var spread := 0.3 + (y - base) * 0.25
			var tip := clampf((top - y) / 1.2, 0.2, 1.0)
			for k in int(3 * tip) + 1:
				var px := x + rng.randf_range(-spread, spread)
				if px < 0.1 or px > length - 0.1:
					continue
				var p := a + dir * px + normal * rng.randf_range(0.03, 0.09)
				var s := LEAF * rng.randf_range(0.7, 1.15)
				var o := Vector3(p.x, y + rng.randf_range(-0.1, 0.1), p.y)
				var du := Vector3(dir.x * s * 0.5, 0, dir.y * s * 0.5)
				var dv := Vector3(0, s * 0.5, 0)
				var tilt := Vector3(normal.x, 0, normal.y) * rng.randf_range(0.0, 0.12)
				var q := [o - du - dv, o + du - dv, o + du + dv + tilt, o - du + dv + tilt]
				var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
				var shade := green * rng.randf_range(0.75, 1.05)
				shade.a = 1.0
				for idx: int in [0, 1, 2, 0, 2, 3]:
					st.set_color(shade)
					st.set_uv(uv[idx])
					st.add_vertex(q[idx])
				cards += 1
			y += rng.randf_range(0.18, 0.3)
	return cards


static func vine_material() -> StandardMaterial3D:
	if _vine_material != null:
		return _vine_material
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(_leaf_image())
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_vine_material = mat
	return mat


## A small cluster of lobed leaves (hop / ivy) on transparent ground.
static func _leaf_image() -> Image:
	var size := 64
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for leaf in 6:
		var cx := rng.randf_range(16, 48)
		var cy := rng.randf_range(16, 48)
		var r := rng.randf_range(9, 14)
		var col := Color(
			rng.randf_range(0.18, 0.28), rng.randf_range(0.34, 0.46), rng.randf_range(0.10, 0.16)
		)
		for y in size:
			for x in size:
				var d := Vector2(x - cx, y - cy)
				# Three lobes: radius pulses with the angle.
				var lobe := r * (0.78 + 0.22 * cos(3.0 * d.angle()))
				if d.length() < lobe:
					var vein := 0.85 if absf(d.x) < 0.8 or absf(d.y) < 0.8 else 1.0
					img.set_pixel(x, y, Color(col.r * vein, col.g * vein, col.b * vein, 1.0))
	img.generate_mipmaps()
	return img
