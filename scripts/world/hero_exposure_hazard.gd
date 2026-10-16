extends Node

## ADR 0061 (R-2183): cold and wetness for the hero in the seamless city. Each frame it reads what
## the world puts the hero in - the air temperature, rain, snow and wind of SkyWeather3D, whether
## he is inside a room or under a roof, how deep he stands in water, the nearest lit fire (group
## `heat_source`: house hearths while lit, the forge) - steps HeroExposure on the saved PlayerState
## and applies the result: shivering burns stamina, a frozen body takes `cold` damage and walks
## slower. ExposureStatusHud shows the wet and cold stages.

const HeroExposure := preload("res://scripts/player/hero_exposure.gd")
const ExposureStatusHud := preload("res://scripts/ui/exposure_status_hud.gd")
const MotionEnvironment := preload("res://scripts/motion/motion_environment.gd")

const HEAT_GROUP := &"heat_source"
## Cold damage is applied in chunks this long, so the health bar and its trail read one steady
## drain instead of sixty tiny hits a second.
const DAMAGE_TICK_SEC := 0.5

var plan: CityPlan
var player: Player
var world: CityWorld3D
var hud: CanvasLayer

var _damage_share := 0.0
var _damage_for := 0.0


static func create(city_plan: CityPlan, hero: Player, city_world: CityWorld3D) -> Node:
	var hazard: Node = load("res://scripts/world/hero_exposure_hazard.gd").new()
	hazard.name = "HeroExposureHazard"
	hazard.plan = city_plan
	hazard.player = hero
	hazard.world = city_world
	return hazard


func _ready() -> void:
	hud = ExposureStatusHud.new()
	hud.name = "ExposureStatusHud"
	add_child(hud)


func _process(delta: float) -> void:
	if not has_node("/root/SessionState") or SessionState.state == null:
		return
	if player == null or not is_instance_valid(player) or player.health <= 0.0:
		return
	var state: PlayerState = SessionState.state.player
	var dt := delta * maxf(player.time_flow_scale, 0.0)
	var env := environment()
	var result := HeroExposure.step(state, dt, env)
	player.stamina = maxf(0.0, player.stamina - float(result["stamina_cost"]))
	player.cold_speed_multiplier = HeroExposure.speed_multiplier(state.body_heat)
	_apply_damage(float(result["damage_share"]), dt)
	if hud != null:
		hud.show_exposure(state.wetness, state.body_heat, float(env.get("fire_m", INF)))


## What the world puts the hero in now (HeroExposure.step keys).
func environment() -> Dictionary:
	var xz := CityPlan.to_world_xz(player.global_position)
	var sky: SkyWeather3D = world.sky_weather if world != null else null
	var interior := world != null and world.enclosed_interior
	var moving := not player.velocity.is_zero_approx()
	var env := {
		"air_temp_c": sky.air_temperature_c() if sky != null else 15.0,
		"rain": sky.rain_intensity() if sky != null else 0.0,
		"snow_share": sky.precipitation_snow_share() if sky != null else 0.0,
		"wind": sky.wind_strength() if sky != null else 0.0,
		"interior": interior,
		"rain_shelter": interior or (plan != null and plan.is_under_roof(xz)),
		"fire_m": nearest_fire_m(xz),
		"immersion": immersion(player.water_medium(), player.water_depth()),
		"puddle": _puddle_wetness() if moving else 0.0,
		"stamina": player.stamina,
	}
	return env


## 0 on land, the depth share of a wade (ankle to chest), 1 swimming or diving.
static func immersion(medium: PlayerSwimState.Medium, depth: float) -> float:
	match medium:
		PlayerSwimState.Medium.SWIM, PlayerSwimState.Medium.DIVE:
			return 1.0
		PlayerSwimState.Medium.WADE:
			return clampf(depth / PlayerSwimState.SWIM_ENTER_DEPTH, 0.1, 0.9)
	return 0.0


## Metres from `xz` (plan world units) to the nearest lit fire, INF when none is near.
func nearest_fire_m(xz: Vector2) -> float:
	if not is_inside_tree():
		return INF
	var best := INF
	for node in get_tree().get_nodes_in_group(HEAT_GROUP):
		var at := Vector3.INF
		if node.has_method(&"heat_position"):
			at = node.call(&"heat_position")
		elif node is Node3D and (node as Node3D).is_inside_tree():
			at = (node as Node3D).global_position
		if at == Vector3.INF:
			continue
		best = minf(best, Vector2(at.x, at.z).distance_to(xz))
	var metres_per_unit := plan.metres_per_unit if plan != null else 1.0
	return best * metres_per_unit if best < INF else INF


## Wetness of the ground underfoot from the shared motion snapshot (puddles after rain).
static func _puddle_wetness() -> float:
	var shared: RefCounted = MotionEnvironment.current()
	var v: Variant = shared.get(&"puddle_wetness") if shared != null else null
	return float(v) if v != null else 0.0


func _apply_damage(share: float, dt: float) -> void:
	if share <= 0.0:
		_damage_share = 0.0
		_damage_for = 0.0
		return
	_damage_share += share
	_damage_for += dt
	if _damage_for < DAMAGE_TICK_SEC:
		return
	player.take_cold(_damage_share * player.max_health)
	_damage_share = 0.0
	_damage_for = 0.0
