class_name CityBlowingSnow
extends GPUParticles3D

## Drifting and blowing snow for the seamless city (docs/SYSTEMS/SEASONS.md). Wind
## picks dry, loose snow off the ground and off the snowed moat ice: low streams
## that skim the surface (drifting snow) from a fresh breeze, and in a gale grains
## thrown up to a few metres (blowing snow, a ground blizzard). Wet, thawing or
## crusted snow stays put. One pooled GPUParticles3D around the player
## (city_blowing_snow.gdshader); grains are born only where snow lies (CitySnow
## depth map) and ride the shared wind. Presentation only: no state, no saving.

## Horizontal metres per second at wind strength 1 (SkyWeather3D.WIND_MS_AT_FULL).
const WIND_MS_AT_FULL := 16.0
## Loose dry snow starts to drift at about 5 m/s (10 m wind) and streams by
## 9 m/s; it is thrown above head height (blowing snow) from about 9-14 m/s.
## Old, settled snow needs more; these are for the loose top layer.
const DRIFT_START_MS := 5.0
const DRIFT_FULL_MS := 9.0
const BLOW_START_MS := 9.0
const BLOW_FULL_MS := 14.0
## Snow is dry enough to blow below DRY_FULL_C, sticky from WET_C up.
const DRY_FULL_C := -3.0
const WET_C := -0.5
## Settled cover below this is too patchy to feed a stream.
const COVER_START := 0.08
const COVER_FULL := 0.35
const GRAIN_LIFETIME := 3.5
## Half width of the emission square and how far ahead of the camera it sits.
const EMIT_HALF := 26.0
const EMIT_AHEAD := 12.0
const SHADER := preload("res://scripts/city/city_blowing_snow.gdshader")

## Last strength() result: x drifting, y blowing (0..1).
var level := Vector2.ZERO
var _params: ShaderMaterial
var _material: StandardMaterial3D


## Drifting (x) and blowing (y) share, 0..1, for `wind_strength` 0..1 (gusts
## included), the air temperature, the ice-weather melt and glaze, and the
## settled snow cover. Pure, for tests.
static func strength(
	wind_strength: float, air_c: float, melt: float, glaze: float, cover: float
) -> Vector2:
	var ms := wind_strength * WIND_MS_AT_FULL
	var dry := 1.0 - smoothstep(DRY_FULL_C, WET_C, air_c)
	# A wet film binds the snow; a refrozen crust holds most of it down.
	dry *= (1.0 - clampf(melt, 0.0, 1.0)) * (1.0 - 0.75 * clampf(glaze, 0.0, 1.0))
	var supply := dry * smoothstep(COVER_START, COVER_FULL, cover)
	return Vector2(
		smoothstep(DRIFT_START_MS, DRIFT_FULL_MS, ms) * supply,
		smoothstep(BLOW_START_MS, BLOW_FULL_MS, ms) * supply
	)


func configure(plan: CityPlan, budget: int = 1600) -> void:
	name = "CityBlowingSnow"
	amount = budget
	lifetime = GRAIN_LIFETIME
	local_coords = false
	visibility_aabb = AABB(Vector3(-60.0, -20.0, -60.0), Vector3(120.0, 40.0, 120.0))
	_params = ShaderMaterial.new()
	_params.shader = SHADER
	_params.set_shader_parameter("emit_half", Vector3(EMIT_HALF, 0.0, EMIT_HALF))
	_params.set_shader_parameter("ground_height", plan.height_texture())
	_params.set_shader_parameter("ground_rect", plan.height_texture_rect())
	process_material = _params
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_material = StandardMaterial3D.new()
	# Lit like the snow it came off: unshaded grains read grey on dusk snow and
	# vanish on sunlit snow. Wrapped diffuse and backlight stand in for the
	# light a cloud of ice grains scatters through itself.
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_material.roughness = 1.0
	_material.backlight_enabled = true
	_material.backlight = Color(0.6, 0.62, 0.66)
	_material.albedo_color = Color(0.9, 0.93, 0.97)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_material.billboard_keep_scale = true
	_material.vertex_color_use_as_albedo = true
	_material.albedo_texture = _grain_texture()
	quad.material = _material
	draw_pass_1 = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitting = false
	visible = false


## Per-frame hook. `focus` the player, `look` the camera forward, `wind_direction`
## the unit world x,z heading, `wind_strength` 0..1 with gusts; `ice_snow` the snow
## on load-bearing ice (0 on open water) and `ice_level` its top near the player
## (NAN without ice).
func update_blowing(
	focus: Vector3,
	look: Vector3,
	wind_direction: Vector2,
	wind_strength: float,
	air_c: float,
	melt: float,
	glaze: float,
	cover: float,
	ice_snow: float,
	ice_level: float
) -> void:
	if _params == null:
		return
	level = strength(wind_strength, air_c, melt, glaze, cover)
	var snow_map: Variant = null
	var ground := CityTerrainBuilder.shared_material()
	if ground != null:
		snow_map = ground.get_shader_parameter("snow_depth_map")
	var on := maxf(level.x, level.y) > 0.01 and snow_map != null
	if on != emitting:
		emitting = on
	visible = on or emitting
	if not on:
		return
	var ahead := Vector3(look.x, 0.0, look.z)
	ahead = ahead.normalized() * EMIT_AHEAD if ahead.length() > 0.01 else Vector3.ZERO
	# Upwind by half a grain's run so the streams fill the view, not leave it.
	var wind_ms := wind_direction * wind_strength * WIND_MS_AT_FULL
	var upwind := -wind_ms * 0.55 * GRAIN_LIFETIME * 0.5
	global_position = focus + ahead + Vector3(upwind.x, 0.0, upwind.y)
	_params.set_shader_parameter("wind_velocity", Vector3(wind_ms.x, 0.0, wind_ms.y))
	_params.set_shader_parameter("drift", level.x)
	_params.set_shader_parameter("blowing", level.y)
	_params.set_shader_parameter("snow_map", snow_map)
	_params.set_shader_parameter("snow_rect", CitySnow.map_rect())
	_params.set_shader_parameter("shelter_map", CitySnow.shelter_texture())
	_params.set_shader_parameter("shelter_rect", CitySnow.shelter_rect())
	_params.set_shader_parameter("snow_cover", cover)
	_params.set_shader_parameter("ice_snow", ice_snow)
	_params.set_shader_parameter("ice_level", -1000.0 if is_nan(ice_level) else ice_level)
	# Particles spawn only where the gate passes, so the full budget is offered and
	# the shader thins it by snow supply and gust puffs.
	amount_ratio = clampf(0.35 + 0.65 * maxf(level.x, level.y), 0.0, 1.0)


## Soft round grain (no texture asset), like Snowfall3D's flake.
static func _grain_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture
