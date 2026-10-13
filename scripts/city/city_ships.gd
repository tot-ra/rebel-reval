class_name CityShips
extends Node3D

## Shipping off Reval (ADR 0031): Hanseatic cogs riding at anchor in the roads
## north of the Coastal Gate, fishing boats drawn up off the fish landing and
## one cog under way along the shore. Cogs are `CogModel` (true metres, ~21 m
## long, sail furled at anchor and wind-filled under way, two wear variants);
## working craft are `VesselFleet` designs (CO-06) with a per-id wear, load and
## rig variant, so no two boats on the Kalamaja sand look alike.
## Anchored hulls weathervane bow-to-wind and bob on a cheap swell; they carry
## no collision (Kalev swims around and under nothing). Beached hulls never bob.

const PerfProbeScript := preload("res://scripts/debug/perf_probe.gd")
const ANCHORAGE_COGS := 7
const LANDING_BOATS := 5
## The cog under way: a slow loop along the shore (metres per second).
const SAIL_SPEED := 2.2
const SAIL_RADIUS := Vector2(420.0, 90.0)
## Map seed of the seamless city for VesselFleet variant selection.
const FLEET_SEED := 1343
## plan.json harbour boat `type` -> VesselFleet design. `clinker` slots split
## between the small and the larger fishing boat by their stable id.
const PLAN_TYPES := {
	&"skiff": VesselFleet.ROWING_OPEN,
	&"lighter": VesselFleet.LIGHTER_LODJA,
	&"overturned": VesselFleet.FISHING_SMALL,
}

var plan: CityPlan
var _hulls: Array[Dictionary] = []
var _sailing: Node3D
var _sail_center := Vector2.ZERO
var _time := 0.0
var _wind := Vector2(1, 0)
## Built once per wear variant and duplicated per hull (meshes are shared resources).
var _cog_anchored: Array[Node3D] = []


static func create(city_plan: CityPlan) -> CityShips:
	var node := CityShips.new()
	node.name = "Ships"
	node.plan = city_plan
	node._build()
	city_plan.dynamic_deck = node.deck_height_at
	return node


func _build() -> void:
	var landing := plan.point_of_interest("poi.fish_landing")
	var shore := (
		Vector2(landing["at"][0], landing["at"][1])
		if not landing.is_empty()
		else Vector2(230, -650)
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1343
	for wear in 2:
		_cog_anchored.append(
			CogModel.build(FactionHeraldry.HANSEATIC, CogModel.SAIL_FURLED, true, wear)
		)
	# Cogs in water deeper than their draft, a few hundred metres out.
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < ANCHORAGE_COGS and tries < 4000:
		tries += 1
		var p := shore + Vector2(rng.randf_range(-520, 380), rng.randf_range(-420, -140))
		if not _clear(p, -4.0, placed, 45.0):
			continue
		placed.append(p)
		_add_hull(p, true, rng, 0.0, NAN, "cog.roads.%d" % placed.size())
	placed.clear()
	tries = 0
	while placed.size() < LANDING_BOATS and tries < 4000:
		tries += 1
		var p := shore + Vector2(rng.randf_range(-90, 90), rng.randf_range(-70, -8))
		if not _clear(p, -0.9, placed, 9.0) or plan.ground_height(p) < -3.0:
			continue
		placed.append(p)
		_add_hull(p, false, rng, 0.0, NAN, "boat.landing.%d" % placed.size())
	# Kalamaja: small clinker boats drawn up on the sand beside the beach decks.
	for boat: Dictionary in plan.data.get("harbour", {}).get("boats", []):
		_add_hull(
			Vector2(boat["at"][0], boat["at"][1]),
			false,
			rng,
			float(boat["lift"]),
			float(boat["angle"]),
			String(boat["id"]),
			StringName(boat.get("type", "clinker"))
		)
	_sail_center = shore + Vector2(-80, -520)
	_sailing = Node3D.new()
	_sailing.name = "CogUnderWay"
	_sailing.add_child(CogModel.build(FactionHeraldry.HANSEATIC, CogModel.SAIL_SET, false))
	add_child(_sailing)
	for template in _cog_anchored:
		template.free()
	_cog_anchored.clear()


func _clear(p: Vector2, deeper_than: float, placed: Array[Vector2], spacing: float) -> bool:
	if plan.ground_height(p) > deeper_than or not plan.bounds.grow(-60).has_point(p):
		return false
	for q in placed:
		if p.distance_to(q) < spacing:
			return false
	return true


## `lift` > 0 beaches the hull on sand at that height (no bobbing); `yaw` pins it.
## `id` is the stable boat id that seeds its VesselFleet / cog wear variant.
func _add_hull(
	p: Vector2,
	cog: bool,
	rng: RandomNumberGenerator,
	lift := 0.0,
	yaw := NAN,
	id := "",
	type := &"clinker"
) -> void:
	var root := Node3D.new()
	root.name = ("Cog_%d" if cog else "Boat_%d") % _hulls.size()
	root.position = Vector3(p.x, 0.0, p.y)
	var hull := Node3D.new()
	var design := &""
	var keel_y := 0.0
	if cog:
		var wear := VesselFleet.stable_hash(id) % _cog_anchored.size()
		hull.add_child(_cog_anchored[wear].duplicate())
	else:
		design = PLAN_TYPES.get(type, &"")
		if design.is_empty():
			design = VesselFleet.fishing_design_for(FLEET_SEED, id)
		var hauled := lift > 0.0
		var variant := VesselFleet.variant_for(design, FLEET_SEED, id, hauled)
		if type == &"overturned":
			hull.add_child(VesselFleet.overturned(design, variant["wear"]))
			design = &""
		else:
			hull.add_child(VesselFleet.build(variant))
			# The vessel origin is its keel: afloat it sits at its draught.
			keel_y = 0.0 if hauled else -VesselFleet.draught(design)
			hull.position.y = keel_y
	root.add_child(hull)
	add_child(root)
	(
		_hulls
		. append(
			{
				"node": root,
				"phase": rng.randf() * TAU,
				"swing": rng.randf_range(-0.35, 0.35),
				"yaw": rng.randf() * TAU if is_nan(yaw) else yaw,
				"cog": cog,
				"lift": lift,
				"design": design,
				"keel_y": keel_y,
				"id": id,
			}
		)
	)


## Height of the deck of the anchored or beached hull under `world_xz`, or NAN.
## The hull's own roll and heave carry the deck, so Kalev rides the swell aboard.
func deck_height_at(world_xz: Vector2) -> float:
	for h: Dictionary in _hulls:
		var node: Node3D = h["node"]
		if not node.is_inside_tree():
			continue
		var local := (
			node.global_transform.affine_inverse()
			* Vector3(world_xz.x, node.global_position.y, world_xz.y)
		)
		if bool(h["cog"]):
			var height := CogModel.walk_height(local.x, local.z)
			if not is_nan(height):
				return node.global_position.y + height
			continue
		var design: StringName = h["design"]
		if design.is_empty():
			continue  # overturned hulls are not boarded
		var deck := VesselFleet.deck(design)
		# The hull tapers to the stems: the usable beam closes over the last quarter.
		var taper := clampf((deck.x - absf(local.x)) / (deck.x * 0.3), 0.0, 1.0)
		if absf(local.x) <= deck.x and absf(local.z) <= deck.y * taper:
			return node.global_position.y + float(h["keel_y"]) + deck.z
	return NAN


func set_wind(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		_wind = direction.normalized()



func _process(delta: float) -> void:
	var probe_start := PerfProbeScript.start()
	_process_timed(delta)
	PerfProbeScript.stop(&"ships", probe_start)


func _process_timed(delta: float) -> void:
	_time += delta
	# Bow into the wind: the hull's +X points where the wind comes from.
	var into_wind := atan2(_wind.y, _wind.x) + PI
	for h: Dictionary in _hulls:
		var node: Node3D = h["node"]
		var phase: float = h["phase"]
		var target := into_wind + float(h["swing"]) if bool(h["cog"]) else float(h["yaw"])
		var yaw := lerp_angle(-node.rotation.y, target, minf(delta * 0.05, 1.0))
		var big := 0.35 if bool(h["cog"]) else 0.6
		node.rotation = Vector3(
			sin(_time * 0.9 + phase) * 0.025 * big,
			-yaw,
			sin(_time * 0.7 + phase * 1.3) * 0.05 * big
		)
		if bool(h["cog"]):
			# The helm lazily works the rudder against the swing at anchor.
			var rudder := CogModel.rudder_of(node.get_child(0).get_child(0) as Node3D)
			if rudder != null:
				rudder.rotation.y = sin(_time * 0.31 + phase) * 0.07
		var lift: float = h["lift"]
		node.position.y = lift if lift > 0.0 else sin(_time * 1.1 + phase) * 0.12 * big
		if lift > 0.0:
			node.rotation = Vector3(0.0, -float(h["yaw"]), 0.0)
	var under_way_rudder := CogModel.rudder_of(_sailing.get_child(0) as Node3D)
	if under_way_rudder != null:
		# Constant helm of the long turn along the loop.
		under_way_rudder.rotation.y = -0.1
	var t := _time * SAIL_SPEED / SAIL_RADIUS.x
	var at := _sail_center + Vector2(cos(t) * SAIL_RADIUS.x, sin(t) * SAIL_RADIUS.y)
	var ahead := Vector2(-sin(t) * SAIL_RADIUS.x, cos(t) * SAIL_RADIUS.y).normalized()
	_sailing.position = Vector3(at.x, sin(_time * 0.8) * 0.15, at.y)
	_sailing.rotation = Vector3(0.0, -atan2(ahead.y, ahead.x), 0.06)
