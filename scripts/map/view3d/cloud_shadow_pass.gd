extends Node3D

## WS-12 outdoor screen pass. Projects the shared sky cloud field along the sun
## onto reconstructed world depth so partly cloudy days throw moving patches
## across town, harbour and sea. Hidden when sun_share is ~0.

const PASS_SHADER := preload("res://scripts/map/view3d/cloud_shadow_pass.gdshader")
const Lighting := preload("res://scripts/map/view3d/map_view_lighting.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const RENDER_PRIORITY := 96
const OVERCAST_FADE_START := 0.45
const OVERCAST_FADE_END := 0.75

var sun_share := 0.0
var _material: ShaderMaterial
var _overlay: MeshInstance3D


static func should_create(indoor: bool, enabled: bool) -> bool:
	return enabled and not indoor


## Direct-sun share from the shared weather snapshot and the MapView lighting
## energies. About 0.58 at a clear noon; ~0 at night or full overcast.
static func sun_share_from_presentation(presentation: SkyWeather.WeatherPresentation) -> float:
	var sun_energy := Lighting.SUN_DAY_ENERGY * maxf(presentation.sun_energy, 0.0)
	var ambient_energy := (
		Lighting.AMBIENT_DAY_ENERGY * maxf(presentation.ambient_energy, 0.0)
	)
	var denom := sun_energy + ambient_energy
	var raw := 0.0 if denom <= 0.0001 else sun_energy / denom
	var sun_up := clampf((presentation.sun_direction.y + 0.02) / 0.20, 0.0, 1.0)
	var overcast_fade := 1.0 - smoothstep(
		OVERCAST_FADE_START, OVERCAST_FADE_END, presentation.overcast
	)
	return clampf(raw * presentation.day_blend * overcast_fade * sun_up, 0.0, 1.0)


func configure(_camera: Camera3D, samples: int) -> void:
	name = "CloudShadowPass"
	_material = ShaderMaterial.new()
	_material.shader = PASS_SHADER
	_material.render_priority = RENDER_PRIORITY
	_material.set_shader_parameter(&"shadow_samples", clampi(samples, 1, 3))
	_material.set_shader_parameter(&"sun_share", 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.flip_faces = true
	quad.material = _material
	_overlay = MeshInstance3D.new()
	_overlay.name = "CloudShadowOverlay"
	_overlay.mesh = quad
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay.ignore_occlusion_culling = true
	_overlay.extra_cull_margin = 16384.0
	add_child(_overlay)


func update_share(presentation: SkyWeather.WeatherPresentation) -> void:
	sun_share = sun_share_from_presentation(presentation)
	if _material != null:
		_material.set_shader_parameter(&"sun_share", sun_share)
	if _overlay != null:
		_overlay.visible = sun_share > 0.01
