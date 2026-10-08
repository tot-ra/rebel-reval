class_name CityFarmland
extends Node3D

## The farmed country round Reval (docs/SYSTEMS/FARMLAND.md): strip fields of
## rye, wheat, barley, oats, peas and flax, kitchen-garden beds of cabbage,
## turnips and onions, fenced crofts and common pastures with hay ricks. Plans
## come from `fields` and `pastures` in the city plan. Crops follow the campaign
## date (the slice opens on 21 April: winter grain is green and knee-high, spring
## grain has just been sown, gardens are seedlings). Visual only: no collision.
##
## Streamed like CityGrass: a feature is built when Kalev is within BUILD_RANGE
## of its edge and freed beyond FREE_RANGE, at most one per call.

const PlantMeshes := preload("res://scripts/map/view3d/map_view_plant_meshes.gd")
const HayMeshes := preload("res://scripts/map/view3d/map_view_hay_meshes.gd")

const BUILD_RANGE := 95.0
const FREE_RANGE := 135.0
const DRAW_RANGE := 150.0
## Plants stay off the headland: the cart track round the strip.
const HEADLAND := 0.9
const MIN_GROWTH := 0.08
const FENCE_POST_STEP := 2.4
const FENCE_HEIGHT := 1.05

## Plan crop id -> plant species, with (row gap, plant step, width factor) in
## metres. Cereals are tufts, so they are drawn wider than the mesh.
const CROPS := {
	&"rye": {"species": &"rye", "row": 0.8, "step": 0.55, "width": 1.5},
	&"wheat": {"species": &"wheat", "row": 0.8, "step": 0.55, "width": 1.5},
	&"barley": {"species": &"barley", "row": 0.8, "step": 0.55, "width": 1.5},
	&"oat": {"species": &"oat", "row": 0.8, "step": 0.6, "width": 1.4},
	&"pea": {"species": &"pea", "row": 0.9, "step": 0.6, "width": 1.2},
	&"flax": {"species": &"flax", "row": 0.8, "step": 0.55, "width": 1.5},
	&"cabbage": {"species": &"cabbage", "row": 1.2, "step": 1.0, "width": 0.8},
	&"turnip": {"species": &"turnip", "row": 0.9, "step": 0.75, "width": 1.0},
	&"onion": {"species": &"onion", "row": 0.5, "step": 0.4, "width": 1.5},
}
## Day-of-year anchors per sowing group: sprout (first green), full (full
## height), ripe (gold), cut (harvested). Winter grain is sown the autumn before.
const SEASONS := {
	&"winter": {"sprout": 105, "full": 175, "ripe": 205, "cut": 225, "start": 0.3},
	&"spring": {"sprout": 118, "full": 190, "ripe": 215, "cut": 240, "start": 0.0},
	&"garden": {"sprout": 112, "full": 200, "ripe": 400, "cut": 290, "start": 0.35},
}
const RIPE_COLOR := Color(1.25, 1.0, 0.55)
const STUBBLE_GROWTH := 0.14

var plan: CityPlan
var day_of_year := 111
var _features: Array[Dictionary] = []
var _live: Dictionary = {}


static func create(city_plan: CityPlan) -> CityFarmland:
	var node := CityFarmland.new()
	node.name = "Farmland"
	node.plan = city_plan
	node._features = features_for(city_plan)
	return node


## Plant height factor 0..1 on a day of year; 0 means bare soil. Pure function.
static func growth(sowing: StringName, doy: int) -> float:
	var season: Dictionary = SEASONS.get(sowing, {})
	if season.is_empty():
		return 0.0
	if doy >= int(season["cut"]):
		return STUBBLE_GROWTH if sowing == &"winter" or sowing == &"spring" else 0.0
	if doy < int(season["sprout"]):
		return float(season["start"])
	var t := clampf(
		float(doy - int(season["sprout"])) / maxf(float(int(season["full"]) - int(season["sprout"])), 1.0),  # gdlint: ignore=max-line-length
		0.0,
		1.0
	)
	return lerpf(float(season["start"]), 1.0, t)


## Tint on a day of year: green until full height, then ripening to gold.
static func tint(sowing: StringName, doy: int) -> Color:
	var season: Dictionary = SEASONS.get(sowing, {})
	if season.is_empty() or sowing == &"garden":
		return Color.WHITE
	var t := clampf(
		float(doy - int(season["full"])) / maxf(float(int(season["ripe"]) - int(season["full"])), 1.0),
		0.0,
		1.0
	)
	return Color.WHITE.lerp(RIPE_COLOR, t)


## Deterministic feature list: {id, kind, polygon, centre, radius, ...}. Pure
## data, so tests and tools can audit the layout without building any mesh.
static func features_for(city_plan: CityPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f: Dictionary in city_plan.data.get("fields", []):
		var poly := CityPlan.points(f["polygon"])
		var centre := _centroid(poly)
		out.append(
			{
				"id": String(f["id"]),
				"kind": &"field",
				"crop": StringName(f["crop"]),
				"sowing": StringName(f["sowing"]),
				"angle": float(f["angle"]),
				"polygon": poly,
				"centre": centre,
				"radius": _radius(poly, centre),
			}
		)
	for p: Dictionary in city_plan.data.get("pastures", []):
		var poly := CityPlan.points(p["polygon"])
		var centre := _centroid(poly)
		out.append(
			{
				"id": String(p["id"]),
				"kind": &"pasture",
				"fence": bool(p["fence"]),
				"pasture_kind": StringName(p["kind"]),
				"polygon": poly,
				"centre": centre,
				"radius": _radius(poly, centre),
			}
		)
	return out


func set_calendar_date(date: Dictionary) -> void:
	var doy := GameCalendar.day_of_year(date)
	if doy == day_of_year:
		return
	day_of_year = doy
	for id: String in _live.keys():
		(_live[id] as Node).queue_free()
	_live.clear()


func live_count() -> int:
	return _live.size()


func update_for(world_xz: Vector2) -> void:
	for id: String in _live.keys():
		var feature := _feature(id)
		if _edge_distance(feature, world_xz) > FREE_RANGE:
			(_live[id] as Node).queue_free()
			_live.erase(id)
	for feature in _features:
		var id: String = feature["id"]
		if _live.has(id) or _edge_distance(feature, world_xz) > BUILD_RANGE:
			continue
		_live[id] = _build(feature)
		return  # at most one feature per call


func _feature(id: String) -> Dictionary:
	for feature in _features:
		if feature["id"] == id:
			return feature
	return {}


static func _edge_distance(feature: Dictionary, xz: Vector2) -> float:
	return (feature["centre"] as Vector2).distance_to(xz) - float(feature["radius"])


static func _centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / maxf(points.size(), 1)


static func _radius(points: PackedVector2Array, centre: Vector2) -> float:
	var r := 0.0
	for p in points:
		r = maxf(r, p.distance_to(centre))
	return r


func _build(feature: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Farm_%s" % String(feature["id"]).replace(".", "_")
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(feature["id"])
	if feature["kind"] == &"field":
		_plant_field(root, feature, rng)
		if feature["sowing"] == &"fallow" and rng.randf() < 0.4:
			_hay_rick(root, feature, rng)
	else:
		if feature["fence"]:
			_fence(root, feature)
		if feature["pasture_kind"] != &"meadow" and rng.randf() < 0.7:
			_hay_rick(root, feature, rng)
	return root


## Rows run along the field's long axis; the four plan corners give the frame.
func _plant_field(root: Node3D, feature: Dictionary, rng: RandomNumberGenerator) -> void:
	var crop: Dictionary = CROPS.get(feature["crop"], {})
	var amount := growth(feature["sowing"], day_of_year)
	if crop.is_empty() or amount < MIN_GROWTH:
		return
	var poly: PackedVector2Array = feature["polygon"]
	var along := (poly[1] - poly[0])
	var across := (poly[3] - poly[0])
	var length := along.length()
	var width := across.length()
	var u := along / maxf(length, 0.001)
	var v := across / maxf(width, 0.001)
	var species: StringName = crop["species"]
	var base_scale := float(crop["width"])
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var colour := tint(feature["sowing"], day_of_year)
	var row_gap: float = crop["row"]
	var step: float = crop["step"]
	var rows := int((width - HEADLAND * 2.0) / row_gap)
	var per_row := int((length - HEADLAND * 2.0) / step)
	for r in rows:
		for c in per_row:
			var jitter := Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.1, 0.1))
			var p := poly[0] + u * (HEADLAND + c * step + jitter.x) + v * (HEADLAND + r * row_gap + jitter.y)
			var size := growth_scale(amount, rng)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(
				Vector3(size.x * base_scale, size.y, size.x * base_scale)
			)
			transforms.append(Transform3D(basis, Vector3(p.x, plan.ground_height(p) - 0.03, p.y)))
			var shade := rng.randf_range(0.88, 1.08)
			colors.append(Color(colour.r * shade, colour.g * shade, colour.b * shade, 1.0))
	if transforms.is_empty():
		return
	var inst := MapViewMeshBuilderPrimitives.multi_mesh(
		"Crop_%s" % species,
		PlantMeshes.mesh_for(species),
		transforms,
		colors,
		MapViewMaterials.grass_blades(),
		Vector3.ZERO
	)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.visibility_range_end = DRAW_RANGE
	root.add_child(inst)


## (width, height) multipliers: young plants are low and thin.
static func growth_scale(amount: float, rng: RandomNumberGenerator) -> Vector2:
	var variety := rng.randf_range(0.88, 1.12)
	return Vector2(lerpf(0.55, 1.0, amount) * variety, amount * variety)


func _fence(root: Node3D, feature: Dictionary) -> void:
	var poly: PackedVector2Array = feature["polygon"]
	var posts: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	var plain: Array[Color] = []
	var rail_colors: Array[Color] = []
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var span := a.distance_to(b)
		var count := maxi(int(ceil(span / FENCE_POST_STEP)), 1)
		var dir := (b - a) / maxf(span, 0.001)
		for k in count:
			var p := a + dir * (span * float(k) / count)
			var q := a + dir * (span * float(k + 1) / count)
			posts.append(_post(p))
			plain.append(Color.WHITE)
			var seg := p.distance_to(q)
			for y: float in [0.35, 0.8]:
				var mid := (p + q) * 0.5
				var ground := plan.ground_height(mid)
				var basis := Basis(Vector3.UP, atan2(-dir.y, dir.x)).scaled(Vector3(seg, 1.0, 1.0))
				rails.append(Transform3D(basis, Vector3(mid.x, ground + y, mid.y)))
				rail_colors.append(Color.WHITE)
	var material := MapViewMaterials.role(&"wood").duplicate() as StandardMaterial3D
	material.albedo_color = Color(0.5, 0.42, 0.34)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.1, FENCE_HEIGHT, 0.1)
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(1.0, 0.07, 0.06)
	var post_inst := MapViewMeshBuilderPrimitives.multi_mesh(
		"Posts", post_mesh, posts, plain, material, Vector3.ZERO
	)
	var rail_inst := MapViewMeshBuilderPrimitives.multi_mesh(
		"Rails", rail_mesh, rails, rail_colors, material, Vector3.ZERO
	)
	for inst: MultiMeshInstance3D in [post_inst, rail_inst]:
		inst.visibility_range_end = DRAW_RANGE
		root.add_child(inst)


func _post(p: Vector2) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(p.x, plan.ground_height(p) + FENCE_HEIGHT * 0.5 - 0.05, p.y))  # gdlint: ignore=max-line-length


## One hay rick just inside the feature edge.
func _hay_rick(root: Node3D, feature: Dictionary, rng: RandomNumberGenerator) -> void:
	var poly: PackedVector2Array = feature["polygon"]
	var centre: Vector2 = feature["centre"]
	var corner := poly[rng.randi() % poly.size()]
	var at := corner.lerp(centre, 0.22)
	HayMeshes.add_rick(
		root,
		"Rick",
		rng.randi() % 997,
		Vector3(at.x, plan.ground_height(at), at.y),
		Vector3.ONE,
		HayMeshes.SIZE_MEDIUM
	)
