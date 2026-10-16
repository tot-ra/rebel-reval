extends Node

## ADR 0057 (R-2152..R-2154): lightning as a hazard in the seamless city. Hands the
## sky (SkyWeather3D.strike_target_provider) what stands near a ground stroke -
## fortification towers, houses, trees, residents and Kalev - and applies what the
## stroke hit: Kalev dies on a direct stroke and is hurt, stunned and briefly
## deafened by one close by; residents fall or flee. Trees and roofs only get the
## event for now (fire and char are R-2155/R-2156).
##
## Every roll is a hash of the strike itself, and the strike comes from the
## lightning RNG, so the same save plays the same outcome.

const Resolver := preload("res://scripts/world/lightning_strike_resolver.gd")

## A direct stroke stops a resident's heart this often (ADR 0057: about 70%);
## the rest survive with heavy burns.
const PERSON_DIRECT_DEATH_CHANCE := 0.7
const PERSON_DIRECT_INJURY := 0.8
## More than any health: a direct stroke on Kalev is always fatal.
const HERO_DIRECT_DAMAGE := 1.0e6
## Resident body height for targeting; children are shorter but rarely alone in
## the open, so one figure keeps the provider cheap.
const PERSON_HEIGHT_M := 1.7
## Ear ringing after a close stroke: the mix is muffled to this cutoff and opens
## back up over DEAFEN_SEC.
const DEAFEN_SEC := 3.5
const DEAFEN_CUTOFF_HZ := 320.0
const OPEN_CUTOFF_HZ := 20000.0
const DEAFEN_EFFECT_NAME := "LightningDeafen"
## Bucket size for the tree index (world units).
const TREE_CELL := 64.0

var plan: CityPlan
var player: Player
var world: CityWorld3D
## CityCitizens or null (the plan may run without residents).
var citizens: Node

var _tree_index: Dictionary = {}  # Vector2i -> Array[int] into plan trees
var _deafen_left := 0.0
var _deafen_effect: AudioEffectLowPassFilter


static func create(
	city_plan: CityPlan, hero: Player, city_world: CityWorld3D, residents: Node
) -> Node:
	var hazard: Node = load("res://scripts/world/lightning_hazard.gd").new()
	hazard.name = "LightningHazard"
	hazard.plan = city_plan
	hazard.player = hero
	hazard.world = city_world
	hazard.citizens = residents
	return hazard


func _ready() -> void:
	_index_trees()
	var sky: SkyWeather3D = world.sky_weather if world != null else null
	if sky == null:
		return
	sky.strike_target_provider = targets_near
	sky.lightning_struck.connect(apply_strike)


func _exit_tree() -> void:
	_remove_deafen()
	if world == null or not is_instance_valid(world):
		return
	var sky: SkyWeather3D = world.sky_weather
	if sky != null and is_instance_valid(sky) and sky.lightning_struck.is_connected(apply_strike):
		sky.lightning_struck.disconnect(apply_strike)
		sky.strike_target_provider = Callable()


## SkyWeather3D.strike_target_provider: the hero and everything that can catch a
## stroke falling at `ground` (world XZ).
func targets_near(ground: Vector2) -> Dictionary:
	if player == null or not is_instance_valid(player) or player.health <= 0.0:
		return {}
	var hero := CityPlan.to_world_xz(player.global_position)
	var radius := Resolver.CANDIDATE_RADIUS_M / plan.metres_per_unit
	var candidates: Array = []
	_collect_towers(ground, radius, candidates)
	_collect_buildings(ground, radius, candidates)
	_collect_trees(ground, radius, candidates)
	_collect_people(ground, radius, candidates)
	return {
		"hero": hero,
		"hero_base_y": plan.ground_height(hero),
		"hero_sheltered": hero_sheltered(hero),
		"candidates": candidates,
		"metres_per_unit": plan.metres_per_unit,
	}


## Indoors, in a landmark room or under any enterable roof: lightning cannot reach.
func hero_sheltered(hero: Vector2) -> bool:
	return (world != null and world.enclosed_interior) or plan.is_under_roof(hero)


## SkyWeather3D.lightning_struck handler.
func apply_strike(strike: Dictionary) -> void:
	_strike_hero(strike)
	_strike_people(strike)


func _strike_hero(strike: Dictionary) -> void:
	if player == null or not is_instance_valid(player):
		return
	if bool(strike.get("hits_hero", false)):
		player.take_lightning(HERO_DIRECT_DAMAGE)
		return
	var hero := CityPlan.to_world_xz(player.global_position)
	var at: Vector2 = strike.get("ground", Vector2.ZERO)
	var fraction := Resolver.near_hurt_fraction(
		at.distance_to(hero) * plan.metres_per_unit, hero_sheltered(hero)
	)
	if fraction <= 0.0:
		return
	player.take_lightning(player.max_health * fraction)
	_start_deafen()


## Residents: the struck one falls (or is badly burned), anyone else within the
## ground-current reach is hurt and runs.
func _strike_people(strike: Dictionary) -> void:
	if citizens == null or not citizens.has_method("strike_by_lightning"):
		return
	var at: Vector2 = strike.get("ground", Vector2.ZERO)
	var struck_id := String(strike.get("id", "")) if strike.get("kind") == Resolver.KIND_PERSON else ""
	for actor: CitizenActor in citizens.live_actors():
		if actor.is_combat_dead():
			continue
		var xz := CityPlan.to_world_xz(actor.global_position)
		var id := String(actor.record.get("id", actor.name))
		if id == struck_id:
			var lethal := Resolver.strike_roll(strike, id) < PERSON_DIRECT_DEATH_CHANCE
			citizens.strike_by_lightning(actor, PERSON_DIRECT_INJURY, lethal)
			continue
		var fraction := Resolver.near_hurt_fraction(
			at.distance_to(xz) * plan.metres_per_unit, plan.is_under_roof(xz)
		)
		if fraction > 0.0:
			citizens.strike_by_lightning(actor, fraction, false)


func _collect_towers(ground: Vector2, radius: float, out: Array) -> void:
	var mpu := plan.metres_per_unit
	for tower: Dictionary in plan.data.get("towers", []):
		var at_value: Array = tower.get("at", [])
		if at_value.size() < 2:
			continue
		var at := Vector2(float(at_value[0]), float(at_value[1]))
		if at.distance_to(ground) > radius:
			continue
		out.append({
			"kind": Resolver.KIND_TOWER,
			"id": String(tower.get("id", "")),
			"position": at,
			"base_y": plan.ground_height(at),
			"height": float(tower.get("h", 0.0)) * mpu,
		})


func _collect_buildings(ground: Vector2, radius: float, out: Array) -> void:
	var mpu := plan.metres_per_unit
	for index: int in plan.buildings_near(ground, radius):
		var building: Dictionary = plan.buildings[index]
		var outline := plan.footprint(index)
		if outline.is_empty():
			continue
		var bounds := Rect2(outline[0], Vector2.ZERO)
		for p: Vector2 in outline:
			bounds = bounds.expand(p)
		var centre := bounds.get_center()
		if centre.distance_to(ground) > radius:
			continue
		# Ridge height of a pitched roof over the narrow side of the footprint.
		var half_span := minf(bounds.size.x, bounds.size.y) * 0.5
		var rise := half_span * tan(deg_to_rad(float(building.get("roof_pitch_deg", 40.0))))
		var tower_h := float(building.get("tower_h", 0.0))
		var top_units := float(building.get("wall_h", 0.0)) + rise + tower_h
		out.append({
			"kind": Resolver.KIND_TOWER if tower_h > 0.0 else Resolver.KIND_BUILDING,
			"id": String(building.get("id", "")),
			"position": centre,
			"base_y": plan.ground_height(centre),
			"height": top_units * mpu,
			"roof": String(building.get("roof", "")),
		})


func _collect_trees(ground: Vector2, radius: float, out: Array) -> void:
	var trees: Array = plan.data.get("trees", [])
	var lo := Vector2i(floori((ground.x - radius) / TREE_CELL), floori((ground.y - radius) / TREE_CELL))
	var hi := Vector2i(floori((ground.x + radius) / TREE_CELL), floori((ground.y + radius) / TREE_CELL))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			for index: int in _tree_index.get(Vector2i(x, y), []):
				var entry: Array = trees[index]
				var at := Vector2(float(entry[0]), float(entry[1]))
				if at.distance_to(ground) > radius:
					continue
				var species := StringName(entry[2])
				var height_m := (
					float(CityVegetationBuilder.HEIGHT_M.get(species, 8.0))
					* CityVegetationBuilder.size_factor(float(entry[3]))
				)
				out.append({
					"kind": Resolver.KIND_TREE,
					"id": tree_id(at),
					"position": at,
					"base_y": plan.ground_height(at),
					"height": height_m,
					"species": String(species),
				})


func _collect_people(ground: Vector2, radius: float, out: Array) -> void:
	if citizens == null or not citizens.has_method("live_actors"):
		return
	for actor: CitizenActor in citizens.live_actors():
		if actor.is_combat_dead():
			continue
		var xz := CityPlan.to_world_xz(actor.global_position)
		if xz.distance_to(ground) > radius or plan.is_under_roof(xz):
			continue
		out.append({
			"kind": Resolver.KIND_PERSON,
			"id": String(actor.record.get("id", actor.name)),
			"position": xz,
			"base_y": plan.ground_height(xz),
			"height": PERSON_HEIGHT_M,
		})


## Stable key of a plan tree (its position to a decimetre), the same key the
## charred-tree state will be saved under (R-2155).
static func tree_id(at: Vector2) -> String:
	return "tree@%d,%d" % [roundi(at.x * 10.0), roundi(at.y * 10.0)]


func _index_trees() -> void:
	_tree_index.clear()
	if plan == null:
		return
	var trees: Array = plan.data.get("trees", [])
	for index in trees.size():
		var entry: Array = trees[index]
		var at := Vector2(float(entry[0]), float(entry[1]))
		if plan.in_moat(at, 1.0):
			continue  # CityVegetationBuilder plants nothing in the ditch water
		var key := Vector2i(floori(at.x / TREE_CELL), floori(at.y / TREE_CELL))
		if not _tree_index.has(key):
			_tree_index[key] = []
		(_tree_index[key] as Array).append(index)


func _process(delta: float) -> void:
	if _deafen_effect == null:
		return
	_deafen_left = maxf(0.0, _deafen_left - delta)
	# Hearing comes back fast at first and the last of the ringing lingers.
	var muffle := pow(_deafen_left / DEAFEN_SEC, 2.0)
	_deafen_effect.cutoff_hz = lerpf(OPEN_CUTOFF_HZ, DEAFEN_CUTOFF_HZ, muffle)
	if _deafen_left <= 0.0:
		_remove_deafen()


func _start_deafen() -> void:
	_deafen_left = DEAFEN_SEC
	if _deafen_effect != null:
		return
	var bus := AudioServer.get_bus_index(&"Master")
	if bus < 0:
		return
	_deafen_effect = AudioEffectLowPassFilter.new()
	_deafen_effect.resource_name = DEAFEN_EFFECT_NAME
	_deafen_effect.cutoff_hz = DEAFEN_CUTOFF_HZ
	AudioServer.add_bus_effect(bus, _deafen_effect)


func _remove_deafen() -> void:
	if _deafen_effect == null:
		return
	var bus := AudioServer.get_bus_index(&"Master")
	for index in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, index) == _deafen_effect:
			AudioServer.remove_bus_effect(bus, index)
			break
	_deafen_effect = null
	_deafen_left = 0.0
