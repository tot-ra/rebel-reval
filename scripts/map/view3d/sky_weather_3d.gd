class_name SkyWeather3D
extends Node3D

## Sky dome, sun/moon placement, real stars for medieval Reval, and a
## deterministic weather cycle for the MapView3D view layer. Owns the
## Environment sky (gradient + procedural clouds via sky_weather_3d.gdshader),
## blends clear/cloudy/rain profiles, and reports lighting multipliers back to
## MapView3D so sun and ambient follow the sky. Weather randomness comes from a
## fixed seed: the sequence repeats identically every run, keeping the
## deterministic-state rule intact.

const SKY_SHADER := preload("res://scripts/map/view3d/sky_weather_3d.gdshader")
const STAR_CATALOG := preload("res://scripts/map/view3d/estonia_star_catalog.gd")
const GAME_CALENDAR := preload("res://scripts/global/game_calendar.gd")

const WEATHER_CLEAR := &"clear"
const WEATHER_CLOUDY := &"cloudy"
## Full grey cover with no blue showing through — the "you can't see the sky" case.
const WEATHER_OVERCAST := &"overcast"
## Widespread overcast rain: the whole deck rains, with thunder.
const WEATHER_RAIN := &"rain"
## Isolated convection: mostly blue sky with one or a few heavy cells that tower,
## rain in distant walls, and throw lightning — the "specific raining cloud" case.
const WEATHER_STORM := &"storm"
const ALL_WEATHERS: Array[StringName] = [
	WEATHER_CLEAR, WEATHER_CLOUDY, WEATHER_OVERCAST, WEATHER_RAIN, WEATHER_STORM
]

## Fixed seed: same weather sequence on every launch (deterministic, reviewable).
const WEATHER_SEED := 24217
const TRANSITION_SECONDS := 5.0
## Bank masses cross the dome at this rate; detail churns faster for edge chaos.
const CLOUD_DRIFT_PER_SECOND := Vector2(0.0045, 0.0018)
const CLOUD_DETAIL_DRIFT_PER_SECOND := Vector2(0.0078, -0.0031)

## Approximate solar orbit used for the visible sun and directional light. World
## +X is east, -Z north, and +Y zenith, matching the star projection below.
## The axial tilt changes declination through the calendar year and therefore
## changes both the noon elevation and the sunrise/sunset times in Reval.
const EARTH_AXIAL_TILT_DEGREES := 23.44
## In 1343 the Julian calendar was about eight days behind the seasonal equinox.
const CAMPAIGN_VERNAL_EQUINOX_DAY_OF_YEAR := 72.0
const SUNSET_ELEVATION_BAND_DEG := 16.0
const SUNSET_ENERGY_DIM := 0.30
const SUNSET_AMBIENT_DIM := 0.15
const SUNSET_TINT_STRENGTH := 0.65

## Mean lunar orbit used for daily rise/set timing and phase lighting. One
## synodic month naturally divides into four roughly weekly phase quarters.
## The epoch is the 2000-01-06 18:14 UTC new moon (Julian day), projected back
## deterministically onto the campaign's Julian calendar.
const SYNODIC_MONTH_DAYS := 29.530588853
const NEW_MOON_EPOCH_JULIAN_DAY := 2451550.25972
## The moon moves east against the stars during each solar day, so its apparent
## westward crossing is slower than the sun's instead of sharing its rotation.
const LUNAR_APPARENT_ROTATIONS_PER_SOLAR_DAY := 1.0 - 1.0 / SYNODIC_MONTH_DAYS

## Astronomical reference for Reval (Tallinn) on St George's Night. The catalog
## is J2000, then precessed to the canonical campaign year so even Polaris and
## the circumpolar constellations sit where a 1343 observer would see them.
const OBSERVER_LATITUDE_DEGREES := 59.437
const SKY_EPOCH_YEAR := 1343.0
const REFERENCE_DATE := "1343-04-23"
## Local apparent sidereal angle at midnight on 1343-04-23 (Julian calendar).
## Earth turns once relative to the stars in a sidereal day (23h 56m), slightly
## faster than its once-per-solar-day turn relative to the sun.
const MIDNIGHT_SIDEREAL_DEGREES := 218.31
const SIDEREAL_ROTATIONS_PER_SOLAR_DAY := 1.00273790935
const STAR_MAP_WIDTH := 2048
const STAR_MAP_HEIGHT := 1024
const LUNAR_ALBEDO_MAP_SIZE := 512

## Per-weather visual targets blended during transitions.
## `wind` drives harbor boat heel/heave and water-shader sea state (0..1).
## `chaos` domain-warps cloud banks so clear weather stays partly cloudy with
## torn edges while storms shred into denser, more chaotic cover.
## `storm` drives cumulonimbus development in the shader: the squall wall,
## darkened flat bases, sunlit anvil crowns, and rain curtains. `locality`
## concentrates the storm into isolated cells (1) versus spreading it across the
## whole deck (0), so the same storm strength reads either as one raining
## thundercloud in blue sky or as a solid rain front. `thunder` scales how often
## lightning strikes. Fair-weather states keep all three near zero.
const PROFILES: Dictionary = {
	WEATHER_CLEAR: {
		"coverage": 0.30, "darken": 0.06,
		"sun_energy": 1.0, "ambient_energy": 1.0,
		"gray": 0.0, "rain": 0.0, "wind": 0.20, "chaos": 0.30,
		"storm": 0.0, "locality": 0.0, "thunder": 0.0,
	},
	WEATHER_CLOUDY: {
		"coverage": 0.66, "darken": 0.40,
		"sun_energy": 0.62, "ambient_energy": 0.86,
		"gray": 0.32, "rain": 0.0, "wind": 0.52, "chaos": 0.55,
		"storm": 0.16, "locality": 0.35, "thunder": 0.0,
	},
	WEATHER_OVERCAST: {
		"coverage": 0.98, "darken": 0.72,
		"sun_energy": 0.44, "ambient_energy": 0.80,
		"gray": 0.75, "rain": 0.0, "wind": 0.58, "chaos": 0.58,
		"storm": 0.30, "locality": 0.0, "thunder": 0.0,
	},
	WEATHER_RAIN: {
		"coverage": 0.94, "darken": 0.82,
		"sun_energy": 0.32, "ambient_energy": 0.70,
		"gray": 0.62, "rain": 1.0, "wind": 0.92, "chaos": 0.86,
		"storm": 1.0, "locality": 0.18, "thunder": 0.55,
	},
	WEATHER_STORM: {
		"coverage": 0.40, "darken": 0.34,
		"sun_energy": 0.74, "ambient_energy": 0.90,
		"gray": 0.18, "rain": 0.22, "wind": 0.70, "chaos": 0.82,
		"storm": 1.0, "locality": 0.9, "thunder": 1.0,
	},
}
## Seconds each weather state holds before the Markov step picks the next one.
## Sized against DayNightCycle.CYCLE_DURATION_SECONDS (60s days) so weather
## visibly turns over within one in-game day.
const DURATIONS: Dictionary = {
	WEATHER_CLEAR: Vector2(22.0, 45.0),
	WEATHER_CLOUDY: Vector2(16.0, 30.0),
	WEATHER_OVERCAST: Vector2(25.0, 45.0),
	WEATHER_RAIN: Vector2(22.0, 45.0),
	WEATHER_STORM: Vector2(20.0, 40.0),
}
## Cumulative odds for what a cloudy spell becomes next. Weighted so every regime
## — widespread rain, an isolated thunderstorm, full overcast, or clearing — is
## easy to catch in a short session. The remainder falls back to clearing.
const CLOUDY_TO_RAIN_CHANCE := 0.24
const CLOUDY_TO_STORM_CHANCE := 0.62
const CLOUDY_TO_OVERCAST_CHANCE := 0.82
## An overcast deck often breaks into rain before clearing.
const OVERCAST_TO_RAIN_CHANCE := 0.55

## Gust front: a real squall is preceded by a shove of wind ahead of the rain.
## When the machine commits to rain we fire a transient gust that spikes the wind
## (and, through it, cloud drift, sails, and sea state) then decays back to the
## sustained storm wind. Added on top of the profile wind and clamped to 1.
const GUST_PEAK := 0.4
const GUST_RISE_SECONDS := 1.0
const GUST_DECAY_SECONDS := 5.0

## Lightning. A storm's `thunder` factor scales the strike rate between these mean
## gaps (seconds); each strike picks a bearing (a cell to light up) and fires a
## short, flickering flash envelope that brightens that cell, glows the sky, and
## briefly lifts scene lighting. Deterministic off the weather RNG.
const LIGHTNING_GAP_SECONDS := Vector2(2.5, 9.0)
const LIGHTNING_FLASH_SECONDS := 0.42

const RAIN_EMITTER_HEIGHT := 11.0

## Cloud drift scales with wind so a gust visibly accelerates the sky and storms
## race while clear days barely stir. Base drift is the light fair-weather rate.
const WIND_DRIFT_FLOOR := 0.5
const WIND_DRIFT_GAIN := 1.6

var weather: StringName = WEATHER_CLEAR
## When false the current state holds until set_weather() is called.
var auto_weather := true
## Multiplies the per-frame step, so the shared time controls speed up, slow down,
## or (at 0) pause the whole sky together with the sun: cloud drift, the weather
## machine, gusts, and lightning. Tests call advance() directly and are unaffected.
var time_scale := 1.0
## 1 while the sun hugs the horizon (golden hour), 0 the rest of the cycle.
var sunset_factor := 0.0
var calendar_date: Dictionary = GAME_CALENDAR.DEFAULT_DATE.duplicate()

var _current: Dictionary = (PROFILES[WEATHER_CLEAR] as Dictionary).duplicate()
var _from: Dictionary = (PROFILES[WEATHER_CLEAR] as Dictionary).duplicate()
var _blend := 1.0
var _time_in_state := 0.0
var _state_duration := 60.0
var _rng := RandomNumberGenerator.new()
var _cloud_offset := Vector2.ZERO
var _cloud_detail_offset := Vector2.ZERO
## Transient gust magnitude on top of the profile wind. `_gust_time` < 0 is idle.
var _gust := 0.0
var _gust_time := -1.0
## Lightning flash level (0..1), the bearing of the flashing cell, elapsed flash
## time (< 0 while idle), and the countdown to the next strike.
var _lightning := 0.0
var _lightning_dir := Vector2(1.0, 0.0)
var _lightning_time := -1.0
var _time_to_strike := 0.0
## Separate stream so lightning draws never perturb the weather sequence.
var _lightning_rng := RandomNumberGenerator.new()
var _material: ShaderMaterial
var _star_map: ImageTexture
var _camera: Camera3D
var _rain: GPUParticles3D


## State is seeded here, not in configure(), so headless tests can exercise the
## weather machine without building any rendering resources.
func _init() -> void:
	_rng.seed = WEATHER_SEED
	_lightning_rng.seed = WEATHER_SEED + 101
	_time_to_strike = _lightning_rng.randf_range(LIGHTNING_GAP_SECONDS.x, LIGHTNING_GAP_SECONDS.y)
	_state_duration = _roll_duration(weather)


func _process(delta: float) -> void:
	advance(delta * maxf(time_scale, 0.0))


## Replaces the environment's flat background with the sky dome and builds the
## rain emitter that shadows the gameplay camera.
func configure(camera: Camera3D, environment: Environment) -> void:
	_camera = camera
	_material = ShaderMaterial.new()
	_material.shader = SKY_SHADER
	_material.set_shader_parameter(&"cloud_noise", _build_cloud_noise())
	_material.set_shader_parameter(&"cloud_shape", _build_cloud_shape())
	_material.set_shader_parameter(&"lunar_albedo_map", _build_lunar_albedo_map())
	_star_map = _build_star_map()
	_material.set_shader_parameter(&"star_map", _star_map)
	_material.set_shader_parameter(&"observer_latitude", deg_to_rad(OBSERVER_LATITUDE_DEGREES))
	var sky := Sky.new()
	sky.sky_material = _material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY

	_rain = _build_rain()
	add_child(_rain)
	_push_cloud_uniforms()


## Deterministic seamless FBM noise used only to erode cloud edges and add
## surface texture. Authored in code so no runtime art assets are added while
## the asset pipeline freeze (P0-040) is in effect.
func _build_cloud_noise() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = WEATHER_SEED
	noise.frequency = 0.03
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	return texture


## Cellular (Worley) noise baked to a seamless tile. Its rounded cells are the
## puffy body of cumulus heaps. FBM alone reads as fluid smoke under thresholding,
## so the cloud silhouette comes from here; cloud_noise only carves the edges.
func _build_cloud_shape() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = WEATHER_SEED + 7
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.018
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	return texture


## Bakes a near-side lunar albedo disk in code so the sky shader can sample
## rich mare, crater, and ray detail without adding frozen pipeline texture assets.
func _build_lunar_albedo_map() -> ImageTexture:
	var size := LUNAR_ALBEDO_MAP_SIZE
	var image := Image.create(size, size, false, Image.FORMAT_RGBAF)
	image.fill(Color.TRANSPARENT)

	var crater_fine := FastNoiseLite.new()
	crater_fine.seed = WEATHER_SEED + 101
	crater_fine.noise_type = FastNoiseLite.TYPE_CELLULAR
	crater_fine.frequency = 0.11
	crater_fine.cellular_return_type = FastNoiseLite.RETURN_DISTANCE

	var crater_mid := FastNoiseLite.new()
	crater_mid.seed = WEATHER_SEED + 102
	crater_mid.noise_type = FastNoiseLite.TYPE_CELLULAR
	crater_mid.frequency = 0.042
	crater_mid.cellular_return_type = FastNoiseLite.RETURN_DISTANCE

	var crater_large := FastNoiseLite.new()
	crater_large.seed = WEATHER_SEED + 103
	crater_large.noise_type = FastNoiseLite.TYPE_CELLULAR
	crater_large.frequency = 0.018
	crater_large.cellular_return_type = FastNoiseLite.RETURN_DISTANCE

	var regolith := FastNoiseLite.new()
	regolith.seed = WEATHER_SEED + 104
	regolith.frequency = 0.06
	regolith.fractal_type = FastNoiseLite.FRACTAL_FBM
	regolith.fractal_octaves = 3

	# Major near-side maria in normalized disk space (center 0,0; radius 1).
	const MARIA: Array[Dictionary] = [
		{"c": Vector2(-0.44, 0.02), "r": Vector2(0.30, 0.24), "a": 0.18, "d": 0.24},
		{"c": Vector2(-0.24, 0.36), "r": Vector2(0.20, 0.17), "a": -0.28, "d": 0.22},
		{"c": Vector2(0.08, 0.40), "r": Vector2(0.14, 0.12), "a": 0.10, "d": 0.18},
		{"c": Vector2(0.16, 0.14), "r": Vector2(0.16, 0.11), "a": -0.12, "d": 0.16},
		{"c": Vector2(0.30, -0.18), "r": Vector2(0.12, 0.10), "a": 0.22, "d": 0.14},
		{"c": Vector2(0.54, 0.34), "r": Vector2(0.09, 0.08), "a": 0.0, "d": 0.13},
		{"c": Vector2(-0.08, -0.22), "r": Vector2(0.11, 0.09), "a": 0.35, "d": 0.12},
		{"c": Vector2(0.36, 0.02), "r": Vector2(0.10, 0.08), "a": -0.15, "d": 0.11},
	]

	for y in size:
		for x in size:
			var nx := (float(x) + 0.5) / float(size) * 2.0 - 1.0
			var ny := (float(y) + 0.5) / float(size) * 2.0 - 1.0
			var disk_r2 := nx * nx + ny * ny
			if disk_r2 > 1.0:
				continue
			var uv := Vector2(nx, ny)

			var albedo := 0.80
			for mare in MARIA:
				albedo -= _lunar_mare_darkness(uv, mare)

			var fine := crater_fine.get_noise_2d(uv.x * 42.0, uv.y * 42.0)
			var mid := crater_mid.get_noise_2d(uv.x * 17.0, uv.y * 17.0)
			var large := crater_large.get_noise_2d(uv.x * 7.0, uv.y * 7.0)
			albedo -= _lunar_crater_depth(fine, 0.10, 0.55)
			albedo -= _lunar_crater_depth(mid, 0.14, 0.62)
			albedo -= _lunar_crater_depth(large, 0.18, 0.70)

			albedo += regolith.get_noise_2d(uv.x * 9.0, uv.y * 9.0) * 0.035
			albedo += _lunar_tycho_rays(uv)

			var limb := sqrt(maxf(1.0 - disk_r2, 0.0))
			albedo *= 0.86 + 0.14 * limb
			albedo = clampf(albedo, 0.34, 0.96)
			image.set_pixel(
				x,
				y,
				Color(albedo, albedo * 0.985, albedo * 0.94, 1.0)
			)

	return ImageTexture.create_from_image(image)


static func _lunar_mare_darkness(uv: Vector2, mare: Dictionary) -> float:
	var center: Vector2 = mare["c"]
	var radii: Vector2 = mare["r"]
	var angle: float = mare["a"]
	var depth: float = mare["d"]
	var offset := uv - center
	var ca := cos(angle)
	var sa := sin(angle)
	var rotated := Vector2(offset.x * ca + offset.y * sa, -offset.x * sa + offset.y * ca)
	var normalized := (
		(rotated.x * rotated.x) / maxf(radii.x * radii.x, 1e-4)
		+ (rotated.y * rotated.y) / maxf(radii.y * radii.y, 1e-4)
	)
	if normalized >= 1.0:
		return 0.0
	return depth * (1.0 - smoothstep(0.25, 1.0, normalized))


static func _lunar_crater_depth(cell_distance: float, rim_boost: float, threshold: float) -> float:
	var bowl := 1.0 - clampf(cell_distance, 0.0, 1.0)
	if bowl < threshold:
		return 0.0
	var t := (bowl - threshold) / maxf(1.0 - threshold, 1e-4)
	return t * t * rim_boost


static func _lunar_tycho_rays(uv: Vector2) -> float:
	var tycho := Vector2(0.05, -0.53)
	var from_tycho := uv - tycho
	var dist := from_tycho.length()
	if dist > 0.72 or dist < 0.018:
		return 0.0
	var angle := atan2(from_tycho.y, from_tycho.x)
	var spokes := absf(sin(angle * 7.0 + dist * 11.0))
	spokes = pow(spokes, 10.0)
	var falloff := 1.0 - dist / 0.72
	return spokes * falloff * falloff * 0.16


## Bakes the real star catalog into an equatorial equirectangular map. A texture
## keeps the sky shader to one sample per pixel instead of looping over 1,600
## stars, while preserving exact catalog positions, brightness, and B-V color.
func _build_star_map() -> ImageTexture:
	var image := Image.create(STAR_MAP_WIDTH, STAR_MAP_HEIGHT, false, Image.FORMAT_RGBAH)
	image.fill(Color.TRANSPARENT)
	for j2000_star in STAR_CATALOG.STARS:
		var star: Vector4 = precess_equatorial(j2000_star, STAR_CATALOG.CATALOG_EPOCH, SKY_EPOCH_YEAR)
		var x := wrapi(roundi(star.x / 360.0 * float(STAR_MAP_WIDTH)), 0, STAR_MAP_WIDTH)
		var y := clampi(roundi((90.0 - star.y) / 180.0 * float(STAR_MAP_HEIGHT - 1)), 0, STAR_MAP_HEIGHT - 1)
		var luminosity := magnitude_to_luminance(star.z)
		var color := bv_to_rgb(star.w) * luminosity
		# Brighter stars receive a compact cross-shaped bloom. Dim stars remain a
		# single texel so recognisable constellation geometry is not distorted.
		_set_star_texel(image, x, y, color)
		if star.z <= 2.5:
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				_set_star_texel(image, x + offset.x, y + offset.y, color * 0.28)
	return ImageTexture.create_from_image(image)


func _set_star_texel(image: Image, x: int, y: int, color: Color) -> void:
	var wrapped_x := wrapi(x, 0, STAR_MAP_WIDTH)
	var clamped_y := clampi(y, 0, STAR_MAP_HEIGHT - 1)
	var existing := image.get_pixel(wrapped_x, clamped_y)
	image.set_pixel(wrapped_x, clamped_y, Color(
		maxf(existing.r, color.r),
		maxf(existing.g, color.g),
		maxf(existing.b, color.b),
		1.0
	))


static func magnitude_to_luminance(magnitude: float) -> float:
	# Pogson's relation: five magnitudes equal a factor of 100 in brightness.
	return clampf(pow(10.0, -0.4 * (magnitude - STAR_CATALOG.LIMITING_MAGNITUDE)), 1.0, 180.0)


static func bv_to_rgb(bv: float) -> Color:
	# Ballesteros temperature approximation followed by a black-body RGB fit.
	# This preserves blue Rigel/Vega and warm Betelgeuse/Arcturus at a glance.
	var clamped_bv := clampf(bv, -0.4, 2.0)
	var temperature := 4600.0 * (
		1.0 / (0.92 * clamped_bv + 1.7) + 1.0 / (0.92 * clamped_bv + 0.62)
	)
	var scaled := temperature / 100.0
	var red: float
	var green: float
	var blue: float
	if scaled <= 66.0:
		red = 1.0
		green = clampf((99.4708025861 * log(scaled) - 161.1195681661) / 255.0, 0.0, 1.0)
	else:
		red = clampf(329.698727446 * pow(scaled - 60.0, -0.1332047592) / 255.0, 0.0, 1.0)
		green = clampf(288.1221695283 * pow(scaled - 60.0, -0.0755148492) / 255.0, 0.0, 1.0)
	if scaled >= 66.0:
		blue = 1.0
	elif scaled <= 19.0:
		blue = 0.0
	else:
		blue = clampf((138.5177312231 * log(scaled - 10.0) - 305.0447927307) / 255.0, 0.0, 1.0)
	return Color(red, green, blue)


## IAU 1976 precession is sufficiently accurate across the 657-year offset and
## moves the entire constellation pattern together from J2000 to spring 1343.
static func precess_equatorial(star: Vector4, from_epoch: float, to_epoch: float) -> Vector4:
	var centuries := (to_epoch - from_epoch) / 100.0
	var zeta := deg_to_rad((
		2306.2181 * centuries
		+ 0.30188 * centuries * centuries
		+ 0.017998 * centuries * centuries * centuries
	) / 3600.0)
	var z := deg_to_rad((
		2306.2181 * centuries
		+ 1.09468 * centuries * centuries
		+ 0.018203 * centuries * centuries * centuries
	) / 3600.0)
	var theta := deg_to_rad((
		2004.3109 * centuries
		- 0.42665 * centuries * centuries
		- 0.041833 * centuries * centuries * centuries
	) / 3600.0)
	var right_ascension := deg_to_rad(star.x)
	var declination := deg_to_rad(star.y)
	var a := cos(declination) * sin(right_ascension + zeta)
	var b := (
		cos(theta) * cos(declination) * cos(right_ascension + zeta)
		- sin(theta) * sin(declination)
	)
	var c := (
		sin(theta) * cos(declination) * cos(right_ascension + zeta)
		+ cos(theta) * sin(declination)
	)
	return Vector4(
		wrapf(rad_to_deg(atan2(a, b) + z), 0.0, 360.0),
		rad_to_deg(asin(clampf(c, -1.0, 1.0))),
		star.z,
		star.w
	)


func _build_rain() -> GPUParticles3D:
	var rain := GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 2200
	rain.lifetime = 1.1
	# World-space particles so camera motion does not drag the rain volume along.
	rain.local_coords = false
	rain.visibility_aabb = AABB(Vector3(-36.0, -20.0, -36.0), Vector3(72.0, 40.0, 72.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(26.0, 0.5, 26.0)
	process.direction = Vector3(0.06, -1.0, 0.02)
	process.spread = 2.0
	process.initial_velocity_min = 15.0
	process.initial_velocity_max = 19.0
	process.gravity = Vector3(0.0, -10.0, 0.0)
	process.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	rain.process_material = process
	# Stretched unshaded streaks; built from primitives, no texture assets.
	var streak := BoxMesh.new()
	streak.size = Vector3(0.018, 0.5, 0.018)
	var streak_material := StandardMaterial3D.new()
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_material.albedo_color = Color(0.68, 0.76, 0.88, 0.5)
	streak.material = streak_material
	rain.draw_pass_1 = streak
	rain.visible = false
	return rain


## Steps the weather state machine and cloud drift. Public so headless tests
## can drive time without a scene tree; _process is the only other caller.
func advance(delta: float) -> void:
	_advance_gust(delta)
	_advance_lightning(delta)
	# Wind carries the clouds: gusts race the sky, calm clear days barely stir.
	# Bank and detail drift share the multiplier so detail keeps outpacing banks.
	var wind_scale := WIND_DRIFT_FLOOR + wind_strength() * WIND_DRIFT_GAIN
	_cloud_offset += CLOUD_DRIFT_PER_SECOND * wind_scale * delta
	_cloud_detail_offset += CLOUD_DETAIL_DRIFT_PER_SECOND * wind_scale * delta
	if _blend < 1.0:
		_blend = minf(1.0, _blend + delta / TRANSITION_SECONDS)
		for key in _current:
			_current[key] = lerpf(float(_from[key]), float((PROFILES[weather] as Dictionary)[key]), _blend)
	elif auto_weather:
		_time_in_state += delta
		if _time_in_state >= _state_duration:
			_pick_next_weather()
	_update_rain()
	_push_cloud_uniforms()


## Starts a blended transition to the requested weather state.
func set_weather(next_weather: StringName) -> void:
	assert(next_weather in ALL_WEATHERS)
	if next_weather == weather:
		return
	# A gust front shoves ahead of the rain, so arm the pulse as the storm commits.
	if next_weather == WEATHER_RAIN:
		_gust_time = 0.0
	_from = _current.duplicate()
	weather = next_weather
	_blend = 0.0
	_time_in_state = 0.0
	_state_duration = _roll_duration(next_weather)


## Solar declination follows the campaign's Julian calendar. The approximation is
## intentionally deterministic and is accurate enough to reproduce Reval's long
## summer days, short winter days, and east-to-west daily traversal.
static func solar_declination_degrees(date: Dictionary) -> float:
	var year := int(date.get("year", GAME_CALENDAR.DEFAULT_DATE["year"]))
	var year_length := float(GAME_CALENDAR.days_in_year(year))
	var ordinal := float(GAME_CALENDAR.day_of_year(date))
	return EARTH_AXIAL_TILT_DEGREES * sin(TAU * (ordinal - CAMPAIGN_VERNAL_EQUINOX_DAY_OF_YEAR) / year_length)


## Returns the observer-to-sun direction in the sky shader's ENU world frame:
## +X east, -Z north, and +Y up. Local solar noon is progress 0.5.
static func solar_direction(progress: float, date: Dictionary = {}) -> Vector3:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	var latitude := deg_to_rad(OBSERVER_LATITUDE_DEGREES)
	var declination := deg_to_rad(solar_declination_degrees(effective_date))
	var hour_angle := (wrapf(progress, 0.0, 1.0) - 0.5) * TAU
	var east := -cos(declination) * sin(hour_angle)
	var north := (
		cos(latitude) * sin(declination)
		- sin(latitude) * cos(declination) * cos(hour_angle)
	)
	var up := (
		sin(latitude) * sin(declination)
		+ cos(latitude) * cos(declination) * cos(hour_angle)
	)
	return Vector3(east, up, -north).normalized()


static func solar_elevation_degrees(progress: float, date: Dictionary = {}) -> float:
	return rad_to_deg(asin(clampf(solar_direction(progress, date).y, -1.0, 1.0)))


## Matches `sun_visibility` in sky_weather_3d.gdshader. Water specular uses the
## same fade so open water cannot keep a sun glint after the disk has set.
const SUN_DISK_FADE_START := -0.05
const SUN_DISK_FADE_END := 0.05


static func sun_disk_visibility(sun_direction: Vector3) -> float:
	return smoothstep(SUN_DISK_FADE_START, SUN_DISK_FADE_END, sun_direction.y)


static func sunrise_sunset_hours(date: Dictionary = {}) -> Dictionary:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	var latitude := deg_to_rad(OBSERVER_LATITUDE_DEGREES)
	var declination := deg_to_rad(solar_declination_degrees(effective_date))
	var horizon_hour_angle := acos(clampf(-tan(latitude) * tan(declination), -1.0, 1.0))
	var half_day_hours := rad_to_deg(horizon_hour_angle) / 15.0
	return {
		"sunrise": 12.0 - half_day_hours,
		"sunset": 12.0 + half_day_hours,
		"day_length": half_day_hours * 2.0,
	}


static func daylight_blend(progress: float, date: Dictionary = {}) -> float:
	# Civil twilight keeps dawn/dusk gradual while 0.5 still marks the geometric
	# horizon, so the day bucket spans exactly the date-dependent daylight hours.
	return smoothstep(-6.0, 6.0, solar_elevation_degrees(progress, date))


## Converts a Julian-calendar campaign date to astronomical Julian day at
## midnight for the deterministic lunar-phase calculation below.
static func julian_day(date: Dictionary) -> float:
	var year := int(date.get("year", GAME_CALENDAR.DEFAULT_DATE["year"]))
	var month := clampi(int(date.get("month", GAME_CALENDAR.DEFAULT_DATE["month"])), 1, 12)
	var day := clampi(
		int(date.get("day", GAME_CALENDAR.DEFAULT_DATE["day"])),
		1,
		GAME_CALENDAR.days_in_month(month, year)
	)
	if month <= 2:
		year -= 1
		month += 12
	return (
		floor(365.25 * float(year + 4716))
		+ floor(30.6001 * float(month + 1))
		+ float(day)
		- 1524.5
	)


## 0 is new moon, 0.25 first quarter, 0.5 full moon, and 0.75 last
## quarter. The campaign date owns the phase because the accelerated visual day
## intentionally loops without advancing story time.
static func lunar_phase(date: Dictionary = {}) -> float:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	var days_since_epoch := julian_day(effective_date) - NEW_MOON_EPOCH_JULIAN_DAY
	return fposmod(days_since_epoch / SYNODIC_MONTH_DAYS, 1.0)


static func lunar_illumination(phase: float) -> float:
	return (1.0 - cos(wrapf(phase, 0.0, 1.0) * TAU)) * 0.5


## Whether the pre-dawn air is primed for radiation fog on a given date: a
## deterministic per-day stand-in for the humidity and overnight temperature drop
## that morning mist needs. 0 is a dry, well-mixed night; 1 is damp, still, and
## fog-prone. Only some mornings clear the bar in MapView3D, so fog stays an
## occasional event rather than a daily one, and repeats identically per the
## deterministic-state rule since it is keyed to the calendar day.
static func morning_fog_potential(date: Dictionary = {}) -> float:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	var day := julian_day(effective_date)
	return fract(sin(day * 12.9898 + 4.1) * 43758.5453)


static func moonlight_strength(progress: float, date: Dictionary = {}) -> float:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	var horizon_visibility := smoothstep(-0.04, 0.03, lunar_direction(progress, effective_date).y)
	return lunar_illumination(lunar_phase(effective_date)) * horizon_visibility


## Uses the same local horizon frame and seasonal declination model as the sun.
## The date phase sets the rise time, while the eastward lunar orbit makes the
## moon cross about 12.2 degrees less sky than the sun during each solar day.
static func lunar_direction(progress: float, date: Dictionary = {}) -> Vector3:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	var wrapped_progress := wrapf(progress, 0.0, 1.0)
	var phase := lunar_phase(effective_date)
	var lunar_progress := wrapf(
		wrapped_progress * LUNAR_APPARENT_ROTATIONS_PER_SOLAR_DAY - phase,
		0.0,
		1.0
	)
	return solar_direction(lunar_progress, effective_date)


static func lunar_elevation_degrees(progress: float, date: Dictionary = {}) -> float:
	return rad_to_deg(asin(clampf(lunar_direction(progress, date).y, -1.0, 1.0)))


func set_calendar_date(date: Dictionary) -> void:
	calendar_date = date.duplicate()


## Pushes shared physical sun/moon directions and cycle tints into the sky
## shader. MapView3D uses the same vectors for directional lighting, keeping
## disks, moving shadows, and east-to-west travel in agreement.
func apply_sky_state(progress: float, day_blend: float, sun_direction: Vector3) -> void:
	var elevation := rad_to_deg(asin(clampf(sun_direction.y, -1.0, 1.0)))
	sunset_factor = clampf(1.0 - absf(elevation) / SUNSET_ELEVATION_BAND_DEG, 0.0, 1.0)
	var phase := lunar_phase(calendar_date)
	var moon_direction := lunar_direction(progress, calendar_date)
	_material.set_shader_parameter(&"sun_direction", sun_direction)
	_material.set_shader_parameter(&"moon_direction", moon_direction)
	_material.set_shader_parameter(&"moon_phase", phase)
	_material.set_shader_parameter(&"day_blend", day_blend)
	_material.set_shader_parameter(&"sunset_factor", sunset_factor)
	_material.set_shader_parameter(&"sidereal_angle", sidereal_angle_for_progress(progress))


## Multipliers/tints MapView3D applies on top of its day/night lerp. Overcast
## skies also mute the sunset tint: gray clouds do not glow orange.
func lighting_modifiers() -> Dictionary:
	return {
		"sun_energy": float(_current["sun_energy"]) * (1.0 - SUNSET_ENERGY_DIM * sunset_factor),
		"ambient_energy": float(_current["ambient_energy"]) * (1.0 - SUNSET_AMBIENT_DIM * sunset_factor),
		"sunset_tint": sunset_factor * SUNSET_TINT_STRENGTH * float(_current["sun_energy"]),
		"overcast": float(_current["gray"]),
		"lightning": _lightning,
	}


func cloud_coverage() -> float:
	return float(_current["coverage"])


func cloud_chaos() -> float:
	return float(_current["chaos"])


## Bank-layer UV drift. Exposed for tests that prove clouds translate across
## the dome instead of only changing a global coverage threshold.
func cloud_offset() -> Vector2:
	return _cloud_offset


func cloud_detail_offset() -> Vector2:
	return _cloud_detail_offset


func rain_intensity() -> float:
	return float(_current["rain"])


## Sustained profile wind plus any transient gust front, clamped to the 0..1
## range the sea-state and world-wind materials expect.
func wind_strength() -> float:
	return clampf(float(_current["wind"]) + _gust, 0.0, 1.0)


## The transient gust component alone (0 when no squall is rolling in). Exposed so
## callers can react to the shove of wind that precedes rain, not just steady wind.
func wind_gust() -> float:
	return _gust


## Cumulonimbus development, 0 (fair weather) to 1 (towering anvil). Mirrors the
## `storm_intensity` uniform the sky shader uses for the squall wall and crowns.
func storm_intensity() -> float:
	return float(_current["storm"])


## How concentrated the storm is: 0 spreads it across the whole deck (a rain
## front), 1 isolates it into a few heavy cells in otherwise open sky.
func storm_locality() -> float:
	return float(_current.get("locality", 0.0))


## Current lightning flash level (0..1). Exposed so scene lighting and audio can
## react to the same strike the sky shader draws.
func lightning_flash() -> float:
	return _lightning


## Ground bearing (unit vec2, x = east, y = north) of the cell currently flashing.
func lightning_direction() -> Vector2:
	return _lightning_dir


## Prevailing wind follows the authored cloud drift so smoke, sails, and floating
## hulls lean the same way as the sky weather field.
func wind_direction_xz() -> Vector2:
	return CLOUD_DRIFT_PER_SECOND.normalized()


## Returns the exact catalog texture bound to the sky shader. Water reuses this
## resource so reflected constellations cannot drift from their visible source.
func star_map_texture() -> Texture2D:
	return _star_map


## Sky and water use the same sidereal rotation. The small excess over one turn
## per solar day keeps stars moving faster than the sun instead of locked to it.
static func sidereal_angle_for_progress(progress: float) -> float:
	return (
		deg_to_rad(MIDNIGHT_SIDEREAL_DEGREES)
		+ wrapf(progress, 0.0, 1.0) * TAU * SIDEREAL_ROTATIONS_PER_SOLAR_DAY
	)


## Clouds must gather before rain, so wet regimes are only ever reached through
## cloudy or overcast — never straight off a clear sky. From cloudy the roll
## fans out into every regime for variety; storms and overcast settle back down
## through cloudy.
func _pick_next_weather() -> void:
	match weather:
		WEATHER_CLEAR:
			set_weather(WEATHER_CLOUDY)
		WEATHER_CLOUDY:
			var roll := _rng.randf()
			if roll < CLOUDY_TO_RAIN_CHANCE:
				set_weather(WEATHER_RAIN)
			elif roll < CLOUDY_TO_STORM_CHANCE:
				set_weather(WEATHER_STORM)
			elif roll < CLOUDY_TO_OVERCAST_CHANCE:
				set_weather(WEATHER_OVERCAST)
			else:
				set_weather(WEATHER_CLEAR)
		WEATHER_OVERCAST:
			if _rng.randf() < OVERCAST_TO_RAIN_CHANCE:
				set_weather(WEATHER_RAIN)
			else:
				set_weather(WEATHER_CLOUDY)
		WEATHER_RAIN:
			set_weather(WEATHER_CLOUDY)
		WEATHER_STORM:
			set_weather(WEATHER_CLOUDY)


func _roll_duration(for_weather: StringName) -> float:
	var span: Vector2 = DURATIONS[for_weather]
	return _rng.randf_range(span.x, span.y)


## Envelopes the gust front: a quick rise to the peak, then an exponential decay
## back to calm. Deterministic in delta, so the seeded weather run stays reviewable.
func _advance_gust(delta: float) -> void:
	if _gust_time < 0.0:
		_gust = 0.0
		return
	_gust_time += delta
	if _gust_time < GUST_RISE_SECONDS:
		_gust = GUST_PEAK * (_gust_time / GUST_RISE_SECONDS)
	else:
		_gust = GUST_PEAK * exp(-(_gust_time - GUST_RISE_SECONDS) / GUST_DECAY_SECONDS)
	if _gust < 0.005:
		_gust = 0.0
		_gust_time = -1.0


## Runs the lightning: decays any flash in progress, then, while the current
## state has thunder, counts down (faster the stronger the thunder) to the next
## strike and fires one at a fresh bearing. An in-flight flash always finishes,
## even if the storm ends mid-stroke.
func _advance_lightning(delta: float) -> void:
	if _lightning_time >= 0.0:
		_lightning_time += delta
		_lightning = _lightning_envelope(_lightning_time)
		if _lightning_time >= LIGHTNING_FLASH_SECONDS:
			_lightning = 0.0
			_lightning_time = -1.0
	else:
		_lightning = 0.0
	var thunder := float(_current.get("thunder", 0.0))
	if thunder <= 0.01:
		return
	_time_to_strike -= delta * thunder
	if _time_to_strike <= 0.0 and _lightning_time < 0.0:
		var angle := _lightning_rng.randf() * TAU
		_lightning_dir = Vector2(cos(angle), sin(angle))
		_lightning_time = 0.0
		_lightning = _lightning_envelope(0.0)
		_time_to_strike = _lightning_rng.randf_range(LIGHTNING_GAP_SECONDS.x, LIGHTNING_GAP_SECONDS.y)


## Flash shape: a sharp leader stroke plus a fast return-stroke flicker, both
## decaying within a few tenths of a second so lightning reads as a flicker.
func _lightning_envelope(t: float) -> float:
	var leader := exp(-t / 0.09)
	var flicker := 0.0
	if t > 0.11:
		flicker = 0.75 * exp(-(t - 0.11) / 0.06)
	return clampf(maxf(leader, flicker), 0.0, 1.0)


func _update_rain() -> void:
	# Headless tests drive advance() without configure(); no emitter exists then.
	if _rain == null:
		return
	var intensity := rain_intensity()
	_rain.visible = intensity > 0.02
	if _rain.visible:
		_rain.amount_ratio = clampf(intensity, 0.05, 1.0)
	if _camera != null:
		_rain.global_position = _camera.global_position + Vector3.UP * RAIN_EMITTER_HEIGHT


func _push_cloud_uniforms() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"cloud_coverage", cloud_coverage())
	_material.set_shader_parameter(&"cloud_darken", float(_current["darken"]))
	_material.set_shader_parameter(&"cloud_offset", _cloud_offset)
	_material.set_shader_parameter(&"cloud_detail_offset", _cloud_detail_offset)
	_material.set_shader_parameter(&"cloud_chaos", cloud_chaos())
	_material.set_shader_parameter(&"storm_intensity", storm_intensity())
	_material.set_shader_parameter(&"storm_locality", storm_locality())
	_material.set_shader_parameter(&"lightning", _lightning)
	_material.set_shader_parameter(&"lightning_dir", _lightning_dir)
	_material.set_shader_parameter(&"wind_dir", wind_direction_xz())
