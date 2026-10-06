extends Node3D

## Atmospheric god rays (crepuscular rays) from the sun or, at night, the moon.
## GL Compatibility has no volumetric fog, so this is a screen-space additive
## overlay (god_ray_pass.gdshader) fanned out from the light's screen position.
## The rays only appear when the camera looks toward the light and the air holds
## something to scatter: ground mist, rain haze, or the gaps of broken cloud.
## Clear dry noon stays clean; a foggy dawn or a low sun through cloud gets shafts.

const PASS_SHADER := preload("res://scripts/map/view3d/god_ray_pass.gdshader")
const Lighting := preload("res://scripts/map/view3d/map_view_lighting.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const RENDER_PRIORITY := 97
const GROUP := &"god_ray_pass"
## Dust and aerosol that always scatters a little, so a clear low sun is not bare.
const BASE_HAZE := 0.10
## Broken cloud (not overcast) opens and shuts the beam into distinct shafts.
const CLOUD_GAP_HAZE := 0.35
const RAIN_HAZE_WEIGHT := 0.6
## Moonlight is a few percent of sunlight; keep its rays a faint veil.
const MOON_STRENGTH_SCALE := 0.3
const MAX_STRENGTH := 0.55
## Below this strength the overlay is hidden and costs nothing.
const STRENGTH_SKIP := 0.01
const SUN_COLOR := Color(1.0, 0.86, 0.62)
const MOON_COLOR := Color(0.55, 0.65, 0.9)
## Orthographic maps place the light this far (in half-screens) along its screen direction.
const ORTHO_LIGHT_REACH := 0.9

var strength := 0.0
var _material: ShaderMaterial
var _overlay: MeshInstance3D
var _camera: Camera3D
var _time := 0.0


static func should_create(indoor: bool) -> bool:
	return not indoor


## Scatter amount 0..1: how much the air in front of the light can show a beam.
static func haze_amount(
	presentation: SkyWeather.WeatherPresentation, enclosed_interior: bool = false
) -> float:
	var mist := Lighting.ground_mist_amount(presentation, enclosed_interior)
	var rain_haze := Lighting.ground_rain_haze(presentation, enclosed_interior)
	# Peaks at half cover: clear sky has no gaps to shape a beam, overcast hides the sun.
	var broken := 1.0 - absf(presentation.cloud_coverage * 2.0 - 1.0)
	return clampf(
		BASE_HAZE + mist + rain_haze * RAIN_HAZE_WEIGHT + broken * CLOUD_GAP_HAZE, 0.0, 1.0
	)


## Beam strength before the camera-facing term. A low sun crosses more air, so rays
## fade out as it climbs; below the horizon the moon takes over at a fraction of it.
static func light_strength(presentation: SkyWeather.WeatherPresentation) -> float:
	var sun_elevation := clampf(presentation.sun_direction.y, 0.0, 1.0)
	var sun_beam := presentation.sun_visibility * presentation.sun_cloud_clear
	sun_beam *= 1.0 - smoothstep(0.25, 0.85, sun_elevation) * 0.75
	var moon_beam := (
		presentation.lunar_light_strength
		* presentation.moon_cloud_clear
		* clampf(presentation.moon_direction.y * 4.0, 0.0, 1.0)
		* MOON_STRENGTH_SCALE
	)
	var beam := maxf(sun_beam, moon_beam)
	return clampf(beam * haze_amount(presentation), 0.0, MAX_STRENGTH)


## True when the sun (not the moon) is the dominant source for the rays.
static func uses_sun(presentation: SkyWeather.WeatherPresentation) -> bool:
	return presentation.sun_visibility * presentation.sun_cloud_clear >= (
		presentation.lunar_light_strength * presentation.moon_cloud_clear * MOON_STRENGTH_SCALE
	)


func configure(camera: Camera3D) -> void:
	name = "GodRayPass"
	_camera = camera
	add_to_group(GROUP)
	_material = ShaderMaterial.new()
	_material.shader = PASS_SHADER
	_material.render_priority = RENDER_PRIORITY
	_material.set_shader_parameter(&"strength", 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.flip_faces = true
	quad.material = _material
	_overlay = MeshInstance3D.new()
	_overlay.name = "GodRayOverlay"
	_overlay.mesh = quad
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay.ignore_occlusion_culling = true
	_overlay.extra_cull_margin = 16384.0
	_overlay.visible = false
	add_child(_overlay)


func _exit_tree() -> void:
	remove_from_group(GROUP)


## Screen position of a light direction in 0..1 viewport UV, plus how directly the
## camera faces the light (0 = light behind the camera, 1 = looking straight at it).
static func screen_light(camera: Camera3D, light_direction: Vector3, aspect: float) -> Dictionary:
	var basis := camera.global_transform.basis
	var forward := -basis.z
	var facing := light_direction.dot(forward)
	var lateral := Vector2(light_direction.dot(basis.x), -light_direction.dot(basis.y))
	var uv := Vector2(0.5, 0.5)
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		uv += lateral * ORTHO_LIGHT_REACH * 0.5
	else:
		var half_tan := tan(deg_to_rad(camera.fov) * 0.5)
		var depth := maxf(facing, 0.05)
		uv += Vector2(lateral.x / (depth * half_tan * aspect), lateral.y / (depth * half_tan)) * 0.5
	return {"uv": uv, "facing": smoothstep(-0.1, 0.5, facing)}


func update(delta: float, presentation: SkyWeather.WeatherPresentation) -> void:
	if _material == null or _camera == null:
		return
	_time += delta
	# Hosted neighbours each build a pass over the same camera; additive overlays would
	# stack, so only the first pass in the tree draws.
	var first := get_tree().get_first_node_in_group(GROUP)
	var base := light_strength(presentation) if first == self else 0.0
	var use_sun := uses_sun(presentation)
	var direction := presentation.sun_direction if use_sun else presentation.moon_direction
	var viewport := get_viewport().get_visible_rect().size
	var aspect := viewport.x / maxf(viewport.y, 1.0)
	var light := screen_light(_camera, direction.normalized(), aspect)
	strength = base * float(light["facing"])
	_overlay.visible = strength > STRENGTH_SKIP
	if not _overlay.visible:
		return
	var ray_color := SUN_COLOR if use_sun else MOON_COLOR
	if use_sun:
		# Golden hour warms the beam; the physical sun colour already carries it.
		ray_color = presentation.physical_sun_color.lerp(SUN_COLOR, 0.35)
	_material.set_shader_parameter(&"light_uv", light["uv"])
	_material.set_shader_parameter(&"ray_color", ray_color)
	_material.set_shader_parameter(&"strength", strength)
	_material.set_shader_parameter(&"aspect", aspect)
	_material.set_shader_parameter(&"time_s", _time)
