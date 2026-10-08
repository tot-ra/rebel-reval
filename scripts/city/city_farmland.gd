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
const FAR_STEP := 10.0
const FAR_BAND := 1.8
const FAR_LIFT := 0.07
## The far crop sheet is a translucent wash so the ground's soil shows through it.
const FAR_SHEET_ALPHA := 0.45
const FAR_SOIL := Color(0.38, 0.29, 0.2)
const FAR_GREEN := {
	&"rye": Color(0.3, 0.46, 0.2),
	&"wheat": Color(0.4, 0.55, 0.22),
	&"barley": Color(0.42, 0.56, 0.22),
	&"oat": Color(0.4, 0.54, 0.25),
	&"pea": Color(0.3, 0.5, 0.24),
	&"flax": Color(0.34, 0.52, 0.28),
	&"cabbage": Color(0.34, 0.52, 0.28),
	&"turnip": Color(0.32, 0.5, 0.24),
	&"onion": Color(0.36, 0.52, 0.26),
}
const FAR_GOLD := {
	&"rye": Color(0.7, 0.58, 0.26),
	&"wheat": Color(0.9, 0.72, 0.28),
	&"barley": Color(0.84, 0.68, 0.28),
	&"oat": Color(0.8, 0.66, 0.3),
}
const RIPE_COLOR := Color(1.25, 1.0, 0.55)
const STUBBLE_GROWTH := 0.14

var plan: CityPlan
var day_of_year := 111
var _features: Array[Dictionary] = []
var _live: Dictionary = {}
var _far: MeshInstance3D


static func create(city_plan: CityPlan) -> CityFarmland:
	var node := CityFarmland.new()
	node.name = "Farmland"
	node.plan = city_plan
	node._features = features_for(city_plan)
	node._rebuild_far()
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
	# Fenced fruit gardens: the trees themselves are plan `trees` (apple, cherry,
	# plum, pear); the feature only streams the enclosure fence.
	for o: Dictionary in city_plan.data.get("orchards", []):
		var poly := CityPlan.points(o["polygon"])
		var centre := _centroid(poly)
		out.append(
			{
				"id": String(o["id"]),
				"kind": &"orchard",
				"fence": bool(o["fence"]),
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
	_rebuild_far()


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
	elif feature["kind"] == &"orchard":
		if feature["fence"]:
			_fence(root, feature)
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


## Enclosure fence: wattle, pole or dry-stone by pastures' id (CityFences).
func _fence(root: Node3D, feature: Dictionary) -> void:
	CityFences.build(root, String(feature["id"]), feature["polygon"], plan.ground_height, DRAW_RANGE)


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


## Far layer: every cropped field as one coloured, row-banded sheet that follows
## the ground, so fields read from the whole city and far beyond DRAW_RANGE,
## where the plants are no longer drawn. Colour follows crop and date.
func _rebuild_far() -> void:
	if _far != null:
		_far.queue_free()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	for f in _features:
		if f["kind"] != &"field" or f["sowing"] == &"fallow":
			continue
		var colour := far_color(f["crop"], f["sowing"], day_of_year)
		# Bare soil is left to the ground shader (black earth, clods, stones); the sheet
		# only shows a crop, and it fades in with the plants so no flat coloured box
		# lies on the soil.
		var cover := clampf(growth(f["sowing"], day_of_year) * 2.5, 0.0, 1.0)
		if cover <= 0.02:
			continue
		var poly: PackedVector2Array = f["polygon"]
		var u := poly[1] - poly[0]
		var v := poly[3] - poly[0]
		var cols := maxi(int(u.length() / FAR_STEP), 1)
		var rows := maxi(int(v.length() / FAR_BAND), 1)
		var length := u.length()
		var width := v.length()
		for r in rows:
			var shade := 1.0 if r % 2 == 0 else 0.93
			for c in cols:
				var a := poly[0] + u * (float(c) / cols) + v * (float(r) / rows)
				var b := a + u / cols
				var d := a + v / rows
				var e := b + v / rows
				var corners: Array[Vector2] = [a, b, e, a, e, d]
				var fractions: Array[Vector2] = [
					Vector2(float(c) / cols, float(r) / rows),
					Vector2(float(c + 1) / cols, float(r) / rows),
					Vector2(float(c + 1) / cols, float(r + 1) / rows),
					Vector2(float(c) / cols, float(r) / rows),
					Vector2(float(c + 1) / cols, float(r + 1) / rows),
					Vector2(float(c) / cols, float(r + 1) / rows),
				]
				for k in 6:
					var q := corners[k]
					var t := fractions[k]
					# Ragged margin: the sheet thins towards the strip edge and is mottled
					# inside, so the field ends in a soft crop edge, not a ruler line.
					var edge := minf(
						minf(t.x * length, (1.0 - t.x) * length),
						minf(t.y * width, (1.0 - t.y) * width)
					)
					var fade := smoothstep(0.4, 3.2 + 2.0 * noise.get_noise_2d(q.x, q.y), edge)
					var mottle := 0.8 + 0.4 * (noise.get_noise_2d(q.x * 3.0, q.y * 3.0) + 0.5)
					var tone := colour * (shade * mottle)
					tone.a = fade * cover * FAR_SHEET_ALPHA
					st.set_color(tone)
					st.set_normal(Vector3.UP)
					st.add_vertex(Vector3(q.x, plan.ground_height(q) + FAR_LIFT, q.y))
				count += 2
	_far = null
	if count == 0:
		return
	_far = MeshInstance3D.new()
	_far.name = "FarFields"
	_far.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	_far.material_override = material
	_far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_far)


## Sheet colour of a field on a day of year: tilled soil, greening, then gold.
static func far_color(crop: StringName, sowing: StringName, doy: int) -> Color:
	var green := FAR_GREEN.get(crop, Color(0.34, 0.5, 0.2)) as Color
	var amount := clampf(growth(sowing, doy) * 1.5, 0.0, 1.0)
	var colour := FAR_SOIL.lerp(green, amount)
	var ripe := tint(sowing, doy)
	if ripe != Color.WHITE:
		var t := clampf((ripe.r - 1.0) / (RIPE_COLOR.r - 1.0), 0.0, 1.0)
		colour = colour.lerp(FAR_GOLD.get(crop, Color(0.8, 0.64, 0.24)) as Color, t)
	return colour
