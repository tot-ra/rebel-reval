class_name CityShips
extends Node3D

## Shipping off Reval (ADR 0031): Hanseatic cogs riding at anchor in the roads
## north of the Coastal Gate, fishing boats drawn up off the fish landing and
## one cog under way along the shore. Hull models are the game's
## MapViewMerchantBoatBuilder / MapViewFishingBoatBuilder, rescaled from their
## 0.88 m units to the city's metres (a cog ~24 m, a fishing boat ~5 m).
## Anchored hulls weathervane bow-to-wind and bob on a cheap swell; they carry
## no collision (Kalev swims around and under nothing).

const COG_SCALE := 3.4
const BOAT_SCALE := 0.88
const COG_DRAFT := 0.55
const ANCHORAGE_COGS := 7
const LANDING_BOATS := 5
## The cog under way: a slow loop along the shore (metres per second).
const SAIL_SPEED := 2.2
const SAIL_RADIUS := Vector2(420.0, 90.0)
## Boardable decks (half length, half beam, deck height above the waterline, metres):
## the usable part of the hull, inside the gunwales. Kalev swims alongside and
## climbs aboard by stepping over the hull footprint.
const COG_DECK := Vector3(9.6, 3.9, 2.9)
const BOAT_DECK := Vector3(2.1, 0.62, 0.38)
## Per CityBoats kind: (half length, half beam, floor height) of the boardable floor.
const BOAT_DECKS := {
	&"clinker": Vector3(2.9, 0.8, 0.3),
	&"skiff": Vector3(1.7, 0.55, 0.25),
	&"lighter": Vector3(4.3, 1.4, 0.4),
	&"overturned": Vector3(0.0, 0.0, 0.0),
}

var plan: CityPlan
var _hulls: Array[Dictionary] = []
var _sailing: Node3D
var _sail_center := Vector2.ZERO
var _time := 0.0
var _wind := Vector2(1, 0)


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
	# Cogs in water deeper than their draft, a few hundred metres out.
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < ANCHORAGE_COGS and tries < 4000:
		tries += 1
		var p := shore + Vector2(rng.randf_range(-520, 380), rng.randf_range(-420, -140))
		if not _clear(p, -4.0, placed, 45.0):
			continue
		placed.append(p)
		_add_hull(p, true, rng)
	placed.clear()
	tries = 0
	while placed.size() < LANDING_BOATS and tries < 4000:
		tries += 1
		var p := shore + Vector2(rng.randf_range(-90, 90), rng.randf_range(-70, -8))
		if not _clear(p, -0.9, placed, 9.0) or plan.ground_height(p) < -3.0:
			continue
		placed.append(p)
		_add_hull(p, false, rng)
	# Kalamaja: small clinker boats drawn up on the sand beside the beach decks.
	for boat: Dictionary in plan.data.get("harbour", {}).get("boats", []):
		_add_hull(Vector2(boat["at"][0], boat["at"][1]), false, rng, float(boat["lift"]), float(boat["angle"]), StringName(boat.get("type", "clinker")))
	_sail_center = shore + Vector2(-80, -520)
	_sailing = Node3D.new()
	_sailing.name = "CogUnderWay"
	var hull := Node3D.new()
	hull.scale = Vector3.ONE * COG_SCALE
	hull.position.y = -COG_DRAFT
	MapViewMerchantBoatBuilder.add_to(hull, FactionHeraldry.HANSEATIC)
	_sailing.add_child(hull)
	add_child(_sailing)


func _clear(p: Vector2, deeper_than: float, placed: Array[Vector2], spacing: float) -> bool:
	if plan.ground_height(p) > deeper_than or not plan.bounds.grow(-60).has_point(p):
		return false
	for q in placed:
		if p.distance_to(q) < spacing:
			return false
	return true


## `lift` > 0 beaches the hull on sand at that height (no bobbing); `yaw` pins it.
func _add_hull(
	p: Vector2, cog: bool, rng: RandomNumberGenerator, lift := 0.0, yaw := NAN, kind := &"fishing"
) -> void:
	var root := Node3D.new()
	root.name = ("Cog_%d" if cog else "Boat_%d") % _hulls.size()
	root.position = Vector3(p.x, 0.0, p.y)
	var hull := Node3D.new()
	if cog:
		hull.scale = Vector3.ONE * COG_SCALE
		hull.position.y = -COG_DRAFT
		MapViewMerchantBoatBuilder.add_to(hull, FactionHeraldry.HANSEATIC)
	elif kind == &"fishing":
		hull.scale = Vector3.ONE * BOAT_SCALE
		MapViewFishingBoatBuilder.add_to(hull)
	elif kind == &"overturned":
		hull.add_child(CityBoats.overturned(&"clinker"))
	else:
		hull.add_child(CityBoats.build(kind))
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
				"kind": kind,
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
		var deck: Vector3 = COG_DECK if bool(h["cog"]) else BOAT_DECKS.get(h["kind"], BOAT_DECK)
		if deck.x <= 0.0:
			continue
		var local := node.global_transform.affine_inverse() * Vector3(world_xz.x, node.global_position.y, world_xz.y)
		# The hull tapers to the stems: the usable beam closes over the last quarter.
		var taper := clampf((deck.x - absf(local.x)) / (deck.x * 0.3), 0.0, 1.0)
		if absf(local.x) <= deck.x and absf(local.z) <= deck.y * taper:
			return node.global_position.y + deck.z
	return NAN


func set_wind(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		_wind = direction.normalized()


func _process(delta: float) -> void:
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
		var lift: float = h["lift"]
		node.position.y = lift if lift > 0.0 else sin(_time * 1.1 + phase) * 0.12 * big
		if lift > 0.0:
			node.rotation = Vector3(0.0, -float(h["yaw"]), 0.0)
	var t := _time * SAIL_SPEED / SAIL_RADIUS.x
	var at := _sail_center + Vector2(cos(t) * SAIL_RADIUS.x, sin(t) * SAIL_RADIUS.y)
	var ahead := Vector2(-sin(t) * SAIL_RADIUS.x, cos(t) * SAIL_RADIUS.y).normalized()
	_sailing.position = Vector3(at.x, sin(_time * 0.8) * 0.15, at.y)
	_sailing.rotation = Vector3(0.0, -atan2(ahead.y, ahead.x), 0.06)
