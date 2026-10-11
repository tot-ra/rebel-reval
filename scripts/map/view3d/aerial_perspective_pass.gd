class_name AerialPerspectivePass
extends Node3D

## R-1482 aerial perspective for third- and first-person cameras outdoors: a full-screen
## pass (aerial_perspective_pass.gdshader) that tints far surfaces toward the colour of
## the air (Rayleigh blue by day, warm at low sun, dark blue at night, grey in rain),
## softens them with a depth-aware blur, and on hot clear days makes the far ground
## near the horizon waver. Near the player everything stays sharp and untinted.
## GL Compatibility has no engine DOF (MapViewRuntimeCameraPerspective leaves it off
## there), so this pass is the only distance blur. It stacks on the faint exponential
## horizon fog of MapViewLighting.apply_ground_mist. Presentation only: nothing persists.

const PASS_SHADER := preload("res://scripts/map/view3d/aerial_perspective_pass.gdshader")
const Lighting := preload("res://scripts/map/view3d/map_view_lighting.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")

## Before CloudShadowPass (-100): the pass rewrites the frame from the screen copy, which
## holds only opaque geometry and sky. Drawn first, it replaces exactly what is already
## there, and cloud shadows, god rays, fog banks and water still composite on top.
const RENDER_PRIORITY := -110
const GROUP := &"aerial_perspective_pass"

## Extinction per metre in clear dry air: about 17% at 300 m, 35% at 1 km after the
## HAZE_MAX cap. Stronger than real Baltic visibility on purpose, so depth reads at game
## camera distances, where the far town edge is only a few hundred metres away.
const HAZE_DENSITY_CLEAR := 0.001
const HAZE_DENSITY_MIN_SCALE := 0.55
const HAZE_DENSITY_MAX_SCALE := 2.4
const HAZE_MAX := 0.6
const HAZE_MAX_NIGHT := 0.45
const CLEAR_RADIUS := 25.0
## Rain washes aerosol out and wind ventilates it: crisp air after a shower.
const WASHED_CLEARING := 0.4
const WIND_CLEARING := 0.25
const DAMP_THICKENING := 0.9
const HEAT_THICKENING := 0.6
const RAIN_THICKENING := 1.4
## Air hues (sRGB). Daytime haze leans from the horizon colour toward sky blue.
const RAYLEIGH_BLUE := Color8(132, 166, 222)
const RAYLEIGH_SHARE := 0.6
const NIGHT_HAZE := Color8(22, 30, 50)
const RAIN_HAZE := Color8(150, 158, 168)

## Blur radius at full distance, in pixels of a 720-line frame (scaled to the viewport).
const BLUR_PIXELS_CLEAR := 2.2
const BLUR_PIXELS_MAX := 4.0
const BLUR_REFERENCE_HEIGHT := 720.0
const BLUR_START := 30.0
const BLUR_FULL := 500.0
## The minimum quality tier (fog_quality 0.65) skips the blur and shimmer taps.
const BLUR_MIN_QUALITY := 0.8

## Heat shimmer: sine of solar elevation where it starts and peaks. In Reval (59.4 N)
## noon is sin 0.68 on 21 April (barely any), 0.77 on 21 May and 0.81 at midsummer
## (full), 0.70 in mid-August (a little). Afternoons fade it as the sun sinks.
const HEAT_SUN_MIN := 0.7
const HEAT_SUN_FULL := 0.78
const SHIMMER_PIXELS := 3.0
const FAIR_CUMULUS_COVER := 0.3
const SHIMMER_START := 90.0
const SHIMMER_FULL := 600.0

const STRENGTH_SKIP := 0.002
const FAR_DISTANCE := 2000.0

var haze_density := 0.0
var blur_pixels := 0.0
var shimmer_pixels := 0.0
## Review tools hide the pass for before plates without touching the weather inputs.
var suppressed := false
var _camera: Camera3D
var _material: ShaderMaterial
var _overlay: MeshInstance3D


static func should_create(indoor: bool) -> bool:
	return not indoor


## 0..1 hot-air shimmer: a high sun in a clear, calm, dry sky. Wider than the old
## midsummer-noon gate so any warm sunny late-spring or summer midday shows some.
static func heat_amount(presentation: SkyWeather.WeatherPresentation) -> float:
	if presentation == null:
		return 0.0
	var heat := smoothstep(HEAT_SUN_MIN, HEAT_SUN_FULL, presentation.sun_direction.y)
	heat *= presentation.sun_visibility * presentation.sun_cloud_clear
	# Fair-weather cumulus (clear profile, about 0.3 cover) grow from that same heating;
	# only a fuller sky cools the ground enough to stop the shimmer.
	heat *= 1.0 - clampf((presentation.cloud_coverage - FAIR_CUMULUS_COVER) * 1.6, 0.0, 1.0)
	heat *= 1.0 - clampf(presentation.wind_strength * 0.8, 0.0, 1.0)
	heat *= 1.0 - clampf(presentation.rain_intensity * 2.0 + presentation.puddle_wetness, 0.0, 1.0)
	return clampf(heat, 0.0, 1.0)


## 0..1 air freshly washed by rain and still ventilated: puddles on the ground but no
## longer raining.
static func washed_amount(presentation: SkyWeather.WeatherPresentation) -> float:
	return clampf(presentation.puddle_wetness, 0.0, 1.0) * (
		1.0 - clampf(presentation.rain_intensity * 3.0, 0.0, 1.0)
	)


## Extinction per metre for this weather and hour.
static func haze_density_for(presentation: SkyWeather.WeatherPresentation) -> float:
	if presentation == null:
		return 0.0
	var scale := 1.0
	scale += DAMP_THICKENING * presentation.overcast
	scale += HEAT_THICKENING * heat_amount(presentation)
	scale += RAIN_THICKENING * presentation.rain_intensity
	scale -= WASHED_CLEARING * washed_amount(presentation)
	scale -= WIND_CLEARING * clampf(presentation.wind_strength, 0.0, 1.0)
	scale = clampf(scale, HAZE_DENSITY_MIN_SCALE, HAZE_DENSITY_MAX_SCALE)
	return HAZE_DENSITY_CLEAR * scale * clampf(presentation.fog_quality, 0.0, 1.0)


## sRGB colour of the air: the horizon the dome draws, pulled toward sky blue when the
## sun is up in clear air, toward the sun's colour at golden hour, toward grey in rain
## and overcast, and to a dark moonlit blue at night.
static func haze_color_for(presentation: SkyWeather.WeatherPresentation) -> Color:
	var horizon := Lighting.FOG_MORNING_COLOR
	if presentation.atmosphere_available:
		horizon = Lighting.physical_hue(presentation.horizon_display_color, horizon)
	var sun_up := smoothstep(0.0, 0.35, presentation.sun_direction.y)
	var clear := 1.0 - clampf(presentation.overcast * 1.3, 0.0, 1.0)
	var day := horizon.lerp(RAYLEIGH_BLUE, RAYLEIGH_SHARE * sun_up * clear)
	# Golden hour: the low sun's light dominates what the air scatters.
	var low_sun := presentation.sunset_factor * clear
	day = day.lerp(presentation.physical_sun_color.lerp(horizon, 0.5), 0.45 * low_sun)
	var grey := clampf(presentation.rain_intensity + presentation.overcast * 0.6, 0.0, 1.0)
	day = day.lerp(RAIN_HAZE, grey)
	return NIGHT_HAZE.lerp(day, clampf(presentation.day_blend, 0.0, 1.0))


static func haze_max_for(presentation: SkyWeather.WeatherPresentation) -> float:
	return lerpf(HAZE_MAX_NIGHT, HAZE_MAX, clampf(presentation.day_blend, 0.0, 1.0))


## Blur radius at full distance for a 720-line frame: wider in thick air.
static func blur_pixels_for(presentation: SkyWeather.WeatherPresentation) -> float:
	if presentation == null or presentation.fog_quality < BLUR_MIN_QUALITY:
		return 0.0
	var thickness := inverse_lerp(
		HAZE_DENSITY_CLEAR * HAZE_DENSITY_MIN_SCALE,
		HAZE_DENSITY_CLEAR * HAZE_DENSITY_MAX_SCALE,
		haze_density_for(presentation)
	)
	return lerpf(BLUR_PIXELS_CLEAR * 0.7, BLUR_PIXELS_MAX, clampf(thickness, 0.0, 1.0))


static func shimmer_pixels_for(presentation: SkyWeather.WeatherPresentation) -> float:
	if presentation == null or presentation.fog_quality < BLUR_MIN_QUALITY:
		return 0.0
	return SHIMMER_PIXELS * heat_amount(presentation)


## Share of the air colour at `distance` (mirrors the shader).
static func haze_factor(distance: float, density: float, haze_max: float = HAZE_MAX) -> float:
	return haze_max * (1.0 - exp(-maxf(distance - CLEAR_RADIUS, 0.0) * density))


## 0..1 blur weight at `distance` (mirrors the shader).
static func blur_factor(distance: float) -> float:
	return smoothstep(BLUR_START, BLUR_FULL, distance)


func configure(camera: Camera3D) -> void:
	name = "AerialPerspectivePass"
	_camera = camera
	add_to_group(GROUP)
	_material = ShaderMaterial.new()
	_material.shader = PASS_SHADER
	_material.render_priority = RENDER_PRIORITY
	_material.set_shader_parameter(&"clear_radius", CLEAR_RADIUS)
	_material.set_shader_parameter(&"blur_start", BLUR_START)
	_material.set_shader_parameter(&"blur_full", BLUR_FULL)
	_material.set_shader_parameter(&"shimmer_start", SHIMMER_START)
	_material.set_shader_parameter(&"shimmer_full", SHIMMER_FULL)
	_material.set_shader_parameter(&"far_distance", FAR_DISTANCE)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.flip_faces = true
	quad.material = _material
	_overlay = MeshInstance3D.new()
	_overlay.name = "AerialPerspectiveOverlay"
	_overlay.mesh = quad
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay.ignore_occlusion_culling = true
	_overlay.extra_cull_margin = 16384.0
	_overlay.visible = false
	add_child(_overlay)


func _exit_tree() -> void:
	remove_from_group(GROUP)


func material() -> ShaderMaterial:
	return _material


func overlay_visible() -> bool:
	return _overlay != null and _overlay.visible


## Debug views for captures: 0 normal, 1 haze, 2 blur, 3 screen passthrough.
func set_debug_mode(mode: int) -> void:
	if _material != null:
		_material.set_shader_parameter(&"debug_mode", mode)


func update(presentation: SkyWeather.WeatherPresentation, enabled: bool = true) -> void:
	if _material == null or _camera == null or presentation == null:
		return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		camera = _camera
	# Hosted neighbours share one camera; a second full-screen rewrite would double the haze.
	var first: Node = null
	for layer in get_tree().get_nodes_in_group(GROUP):
		if layer.get_viewport() == get_viewport():
			first = layer
			break
	var perspective := camera.projection != Camera3D.PROJECTION_ORTHOGONAL
	var active := enabled and perspective and first == self and not suppressed
	haze_density = haze_density_for(presentation) if active else 0.0
	blur_pixels = blur_pixels_for(presentation) if active else 0.0
	shimmer_pixels = shimmer_pixels_for(presentation) if active else 0.0
	_overlay.visible = haze_density > 0.0 and haze_factor(BLUR_FULL, haze_density) > STRENGTH_SKIP
	if not _overlay.visible:
		return
	var scale := get_viewport().get_visible_rect().size.y / BLUR_REFERENCE_HEIGHT
	_material.set_shader_parameter(&"haze_color", haze_color_for(presentation))
	_material.set_shader_parameter(&"haze_density", haze_density)
	_material.set_shader_parameter(&"haze_max", haze_max_for(presentation))
	_material.set_shader_parameter(&"blur_pixels", blur_pixels * scale)
	_material.set_shader_parameter(&"shimmer_pixels", shimmer_pixels * scale)
