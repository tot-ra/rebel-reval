class_name AtmosphereCpu
extends RefCounted

## WS-11 CPU side of the physical atmosphere. Evaluates the sun colour, sky irradiance and
## horizon colour from the *static* WS-09 LUT images so the DirectionalLight, ambient, fog and
## water agree with the WS-10 sky dome without any GPU readback. The images are loaded once
## (Texture2D.get_image()) and copied into packed arrays; everything below is deterministic
## and runs headless.
##
## The maths mirrors sky_view_lut.gdshader (Hillaire EGSR 2020 section 5.3) with a coarser
## march: 16 fixed cosine-weighted directions x 12 steps for the irradiance, 8 azimuths at
## 2 degrees for the horizon. The sky is symmetric about the sun's vertical plane, so every
## direction is built once in a sun-relative frame (sun in the x-y plane, azimuth measured
## from the sun) and only the sun zenith cosine changes per evaluation.
## Ported from Tidewater (MIT), see notice.code.tidewater (skyViewKernel, atmoIrr).
##
## Colours are returned in linear light. Callers convert with linear_to_srgb() before they
## assign a Godot light/fog Color, whose components are sRGB-encoded.
##
## An instance is a small smoothing tracker (sample()): it re-evaluates at most every
## UPDATE_INTERVAL_SEC of real time and eases towards the new values with an exponential
## filter, so the compressed 60 s day never steps visibly.

const TRANSMITTANCE_PATH := "res://assets/sky/atmosphere/transmittance.exr"
const MULTISCATTER_PATH := "res://assets/sky/atmosphere/multiscatter.exr"

# Must match atmosphere_common.gdshaderinc and assets/sky/atmosphere/atmosphere_profile.json.
const RG := 6360.0
const RT := 6460.0
const RAYLEIGH_SCATTERING := Vector3(5.802e-3, 13.558e-3, 33.1e-3)
const RAYLEIGH_SCALE_HEIGHT := 8.0
const MIE_SCATTERING := 3.996e-3
const MIE_EXTINCTION := 4.440e-3
const MIE_SCALE_HEIGHT := 1.2
const MIE_G := 0.8
const OZONE_ABSORPTION := Vector3(0.650e-3, 1.881e-3, 0.085e-3)
const OZONE_CENTER := 25.0
const OZONE_HALF_WIDTH := 15.0
const TRANSMITTANCE_SIZE := Vector2i(256, 64)
const MULTISCATTER_SIZE := 32
## Same as SkyAtmosphereLut.SUN_ILLUMINANCE (Tidewater SkyParams default).
const SUN_ILLUMINANCE := 11.0
## sky_view_lut.gdshader constants: the viewer stands 2 m above the ground.
const VIEW_HEIGHT_OFFSET_KM := 0.002
const PLANET_RADIUS_OFFSET_KM := 0.01
const MARCH_SAMPLE_OFFSET := 0.3

const IRRADIANCE_DIRECTIONS := 16
const MARCH_STEPS := 12
const HORIZON_AZIMUTHS := 8
const HORIZON_ELEVATION_DEG := 2.0

const UPDATE_INTERVAL_SEC := 0.25
const SMOOTHING_TAU_SEC := 0.3
## A sun jump larger than this between evaluations (capture, save restore, time skip) snaps
## instead of easing. The 1x compressed day moves ~1.5 degrees per update interval.
const SNAP_ANGLE_DEG := 10.0

const LUMA := Vector3(0.2126, 0.7152, 0.0722)

static var _loaded := false
static var _available := false
static var _transmittance := PackedVector3Array()
static var _multiscatter := PackedVector3Array()
static var _zenith_sun_luminance := 1.0
## Precomputed march paths, see _build_path().
static var _irradiance_paths: Array[Dictionary] = []
static var _horizon_paths: Array[Dictionary] = []
static var _zenith_path: Dictionary = {}

## Smoothed outputs of sample(), linear light.
var sun_color := Color.WHITE
var sun_energy := 1.0
var sky_irradiance := Color(0.5, 0.6, 0.8)
var horizon_color := Color(0.6, 0.7, 0.8)
var horizon_sun_color := Color(0.6, 0.7, 0.8)
var zenith_color := Color(0.1, 0.2, 0.4)
## Evaluations run since construction; tests use it to observe the 4 Hz throttle.
var evaluation_count := 0

var _target := {}
var _last_eval_usec := -1
var _last_update_usec := -1
var _last_eval_sun := Vector3.ZERO


## Loads the WS-09 LUT images once. Returns false (and every evaluation returns neutral
## values) when either asset is missing, matching SkyAtmosphereLut's fail-closed rule.
static func load_luts(
	transmittance_path: String = TRANSMITTANCE_PATH,
	multiscatter_path: String = MULTISCATTER_PATH
) -> bool:
	_loaded = true
	_available = false
	var transmittance := _read_image(transmittance_path, TRANSMITTANCE_SIZE)
	var multiscatter := _read_image(multiscatter_path, Vector2i(MULTISCATTER_SIZE, MULTISCATTER_SIZE))
	if transmittance.is_empty() or multiscatter.is_empty():
		_transmittance = PackedVector3Array()
		_multiscatter = PackedVector3Array()
		return false
	_transmittance = transmittance
	_multiscatter = multiscatter
	_available = true
	_zenith_sun_luminance = maxf(_transmittance_at(RG + VIEW_HEIGHT_OFFSET_KM, 1.0).dot(LUMA), 1e-6)
	_build_fixed_paths()
	return true


static func is_available() -> bool:
	if not _loaded:
		load_luts()
	return _available


## Direct sun colour at the ground, linear, normalised so its brightest channel is 1.
static func sun_color_for(sun_dir: Vector3) -> Color:
	if not is_available():
		return Color.WHITE
	var t := ground_transmittance(sun_dir)
	var peak := maxf(maxf(t.x, t.y), maxf(t.z, 1e-6))
	return Color(t.x / peak, t.y / peak, t.z / peak)


## Sun illuminance luminance at the ground relative to the zenith sun (1 at the zenith).
static func sun_energy_for(sun_dir: Vector3) -> float:
	if not is_available():
		return 1.0
	return ground_transmittance(sun_dir).dot(LUMA) / _zenith_sun_luminance


## Transmittance from the viewer to the top of the atmosphere towards the sun. Below the
## horizon the LUT clamps to its horizon column, like the shaders.
static func ground_transmittance(sun_dir: Vector3) -> Vector3:
	if not is_available():
		return Vector3.ONE
	return _transmittance_at(RG + VIEW_HEIGHT_OFFSET_KM, clampf(sun_dir.normalized().y, -1.0, 1.0))


## Cosine-weighted hemisphere irradiance on an upward surface, linear, in units of
## SUN_ILLUMINANCE (same scale as the sky-view LUT before the sky's art exposure).
static func sky_irradiance_for(sun_dir: Vector3) -> Color:
	if not is_available():
		return Color(0.5, 0.6, 0.8)
	var mu := clampf(sun_dir.normalized().y, -1.0, 1.0)
	var sun_local := Vector3(sqrt(maxf(1.0 - mu * mu, 0.0)), mu, 0.0)
	var sum := Vector3.ZERO
	for path in _irradiance_paths:
		sum += _path_radiance(path, sun_local)
	# Cosine-weighted estimator: E = pi / N * sum(L).
	var e := sum * (PI / float(_irradiance_paths.size()))
	return Color(e.x, e.y, e.z)


## Sky radiance 2 degrees above the horizon, linear, LUT scale. With towards_dir == ZERO it
## is the average over HORIZON_AZIMUTHS azimuths (fog colour); otherwise the radiance
## towards that direction's azimuth (pass sun_dir for the sun-scatter side).
## The average weights every azimuth's *hue* equally and keeps the mean luminance: a plain
## radiance mean is dominated by the Mie glow around a low sun (7x brighter than the rest of
## the horizon at sunrise), and that glow is Godot's fog sun scatter, not the base colour.
static func horizon_color_for(sun_dir: Vector3, towards_dir: Vector3 = Vector3.ZERO) -> Color:
	if not is_available():
		return Color(0.6, 0.7, 0.8)
	var mu := clampf(sun_dir.normalized().y, -1.0, 1.0)
	var sun_local := Vector3(sqrt(maxf(1.0 - mu * mu, 0.0)), mu, 0.0)
	var l := Vector3.ZERO
	if towards_dir == Vector3.ZERO:
		var mean_luminance := 0.0
		for path in _horizon_paths:
			var radiance := _path_radiance(path, sun_local)
			var y := maxf(radiance.dot(LUMA), 1e-9)
			l += radiance / y
			mean_luminance += y
		var count := float(_horizon_paths.size())
		l *= mean_luminance / (count * count)
	else:
		var cos_azimuth := 1.0
		var sun_h := Vector2(sun_dir.x, sun_dir.z)
		var view_h := Vector2(towards_dir.x, towards_dir.z)
		if sun_h.length_squared() > 1e-8 and view_h.length_squared() > 1e-8:
			cos_azimuth = clampf(sun_h.normalized().dot(view_h.normalized()), -1.0, 1.0)
		l = _path_radiance(_build_path(_horizon_direction(acos(cos_azimuth))), sun_local)
	return Color(l.x, l.y, l.z)


## Zenith sky radiance, linear, LUT scale: the WS-10 dome's eye-adaptation input.
static func zenith_color_for(sun_dir: Vector3) -> Color:
	if not is_available():
		return Color(0.1, 0.2, 0.4)
	var mu := clampf(sun_dir.normalized().y, -1.0, 1.0)
	var l := _path_radiance(_zenith_path, Vector3(sqrt(maxf(1.0 - mu * mu, 0.0)), mu, 0.0))
	return Color(l.x, l.y, l.z)


static func luminance(color: Color) -> float:
	return Vector3(color.r, color.g, color.b).dot(LUMA)


## Rescales a linear colour so its luminance equals `target_luminance` (hue kept). Returns
## `fallback` when the colour has no energy (deep night, missing LUTs).
static func with_luminance(color: Color, target_luminance: float, fallback: Color) -> Color:
	var l := luminance(color)
	if l <= 1e-6:
		return fallback
	var k := target_luminance / l
	return Color(color.r * k, color.g * k, color.b * k)


## Tracker entry point: returns false when the LUTs are missing. Otherwise updates the
## smoothed public colours for `sun_dir` at real time `now_usec` (Time.get_ticks_usec()).
func sample(sun_dir: Vector3, now_usec: int) -> bool:
	if not is_available():
		return false
	var dir := sun_dir.normalized()
	var first := _last_eval_usec < 0 or now_usec < _last_update_usec
	var jumped := (
		not first
		and rad_to_deg(dir.angle_to(_last_eval_sun)) > SNAP_ANGLE_DEG
	)
	if first or jumped:
		_evaluate(dir, now_usec)
		_apply_blend(1.0)
		_last_update_usec = now_usec
		return true
	if float(now_usec - _last_eval_usec) >= UPDATE_INTERVAL_SEC * 1e6:
		_evaluate(dir, now_usec)
	var dt := float(now_usec - _last_update_usec) / 1e6
	_last_update_usec = now_usec
	if dt > 0.0:
		_apply_blend(1.0 - exp(-dt / SMOOTHING_TAU_SEC))
	return true


## CPU mirror of the WS-10 dome's LUT-branch horizon (sky() in sky_weather_3d.gdshader):
## smoothed horizon x art exposure/tint x zenith-driven eye adaptation, plus the night
## gradient floor x (1 - day_blend). `sky_uniform(name, fallback)` returns the dome shader's
## live uniform; source_color uniforms are stored sRGB and decoded here like the shader does.
func displayed_horizon(
	exposure: float, tint: Color, day_blend: float, sky_uniform: Callable
) -> Color:
	var reference := float(sky_uniform.call(&"sky_adaptation_reference", 0.155))
	var adaptation := clampf(
		pow(
			reference / maxf(luminance(zenith_color), 1e-6),
			float(sky_uniform.call(&"sky_adaptation", 0.6))
		),
		1.0,
		float(sky_uniform.call(&"sky_adaptation_max_gain", 4.0))
	)
	var night_value: Variant = sky_uniform.call(&"night_horizon_color", Color(0.05, 0.1, 0.22))
	if night_value is Vector4:
		var v := night_value as Vector4
		night_value = Color(v.x, v.y, v.z, v.w)
	var night_horizon := Color.BLACK
	if night_value is Color:
		night_horizon = (night_value as Color).srgb_to_linear()
	var art := tint.srgb_to_linear() * (exposure * adaptation)
	var night := 1.0 - day_blend
	return Color(
		horizon_color.r * art.r + night_horizon.r * night,
		horizon_color.g * art.g + night_horizon.g * night,
		horizon_color.b * art.b + night_horizon.b * night
	)


func _evaluate(dir: Vector3, now_usec: int) -> void:
	_target = {
		"sun_color": sun_color_for(dir),
		"sun_energy": sun_energy_for(dir),
		"sky_irradiance": sky_irradiance_for(dir),
		"horizon_color": horizon_color_for(dir),
		"horizon_sun_color": horizon_color_for(dir, dir),
		"zenith_color": zenith_color_for(dir),
	}
	_last_eval_usec = now_usec
	_last_eval_sun = dir
	evaluation_count += 1


func _apply_blend(weight: float) -> void:
	sun_color = sun_color.lerp(_target["sun_color"], weight)
	sun_energy = lerpf(sun_energy, float(_target["sun_energy"]), weight)
	sky_irradiance = sky_irradiance.lerp(_target["sky_irradiance"], weight)
	horizon_color = horizon_color.lerp(_target["horizon_color"], weight)
	horizon_sun_color = horizon_sun_color.lerp(_target["horizon_sun_color"], weight)
	zenith_color = zenith_color.lerp(_target["zenith_color"], weight)


static func _read_image(path: String, expected_size: Vector2i) -> PackedVector3Array:
	var texels := PackedVector3Array()
	if path.is_empty() or not ResourceLoader.exists(path):
		return texels
	var texture := load(path) as Texture2D
	if texture == null:
		return texels
	var image := texture.get_image()
	if image == null or image.get_size() != expected_size:
		return texels
	if image.is_compressed():
		image.decompress()
	texels.resize(expected_size.x * expected_size.y)
	for y in expected_size.y:
		for x in expected_size.x:
			var c := image.get_pixel(x, y)
			texels[y * expected_size.x + x] = Vector3(c.r, c.g, c.b)
	return texels


## Bilinear lookup with the shader's texel-centre convention (uv 0.5/N is texel 0).
static func _bilinear(texels: PackedVector3Array, size: Vector2i, uv: Vector2) -> Vector3:
	var x := clampf(uv.x * size.x - 0.5, 0.0, size.x - 1.0)
	var y := clampf(uv.y * size.y - 0.5, 0.0, size.y - 1.0)
	var x0 := int(x)
	var y0 := int(y)
	var x1 := mini(x0 + 1, size.x - 1)
	var y1 := mini(y0 + 1, size.y - 1)
	var fx := x - x0
	var fy := y - y0
	var top := texels[y0 * size.x + x0].lerp(texels[y0 * size.x + x1], fx)
	var bottom := texels[y1 * size.x + x0].lerp(texels[y1 * size.x + x1], fx)
	return top.lerp(bottom, fy)


static func _unit_to_sub_uv(x: float, size: float) -> float:
	return 0.5 / size + x * (size - 1.0) / size


## atmosphere_common.gdshaderinc transmittance_uv().
static func _transmittance_at(r: float, mu: float) -> Vector3:
	var h := sqrt(RT * RT - RG * RG)
	var rho := sqrt(maxf(r * r - RG * RG, 0.0))
	var disc := r * r * (mu * mu - 1.0) + RT * RT
	var d := maxf(0.0, -r * mu + sqrt(maxf(disc, 0.0)))
	var d_min := RT - r
	var d_max := rho + h
	var uv := Vector2(
		_unit_to_sub_uv((d - d_min) / (d_max - d_min), TRANSMITTANCE_SIZE.x),
		_unit_to_sub_uv(rho / h, TRANSMITTANCE_SIZE.y)
	)
	return _bilinear(_transmittance, TRANSMITTANCE_SIZE, uv)


## atmosphere_common.gdshaderinc multiscatter_uv().
static func _multiscatter_at(r: float, mu_sun: float) -> Vector3:
	var uv := Vector2(
		_unit_to_sub_uv(mu_sun * 0.5 + 0.5, MULTISCATTER_SIZE),
		_unit_to_sub_uv(clampf((r - RG) / (RT - RG), 0.0, 1.0), MULTISCATTER_SIZE)
	)
	return _bilinear(_multiscatter, Vector2i(MULTISCATTER_SIZE, MULTISCATTER_SIZE), uv)


static func _ray_sphere(ro: Vector3, rd: Vector3, radius: float) -> float:
	var b := ro.dot(rd)
	var c := ro.dot(ro) - radius * radius
	var disc := b * b - c
	if disc < 0.0:
		return -1.0
	var sq := sqrt(disc)
	var t0 := -b - sq
	var t1 := -b + sq
	if t0 > 0.0:
		return t0
	return t1 if t1 > 0.0 else -1.0


static func _horizon_direction(azimuth_from_sun: float) -> Vector3:
	var e := deg_to_rad(HORIZON_ELEVATION_DEG)
	return Vector3(cos(e) * cos(azimuth_from_sun), sin(e), cos(e) * sin(azimuth_from_sun))


static func _build_fixed_paths() -> void:
	_irradiance_paths.clear()
	for i in IRRADIANCE_DIRECTIONS:
		# Deterministic cosine-weighted hemisphere set: stratified in sin^2(theta), golden-ratio
		# azimuths. Mirrored azimuths give the same radiance, so no symmetry fix-up is needed.
		var u1 := (float(i) + 0.5) / float(IRRADIANCE_DIRECTIONS)
		var phi := TAU * fposmod(float(i) * 0.6180339887, 1.0)
		var sin_theta := sqrt(u1)
		var cos_theta := sqrt(1.0 - u1)
		_irradiance_paths.append(
			_build_path(Vector3(sin_theta * cos(phi), cos_theta, sin_theta * sin(phi)))
		)
	_horizon_paths.clear()
	for k in HORIZON_AZIMUTHS:
		_horizon_paths.append(_build_path(_horizon_direction(TAU * float(k) / HORIZON_AZIMUTHS)))
	_zenith_path = _build_path(Vector3.UP)


## Precomputes everything along one view ray that does not depend on the sun: sample radius,
## local up, and the step weights of the energy-conserving integration
## s_int = s * (1 - T_step) / extinction, pre-multiplied by the throughput and by the
## Rayleigh, Mie and total scattering so the per-sun loop is a few multiply-adds.
static func _build_path(view_dir: Vector3) -> Dictionary:
	var r0 := RG + VIEW_HEIGHT_OFFSET_KM
	var origin := Vector3(0.0, r0, 0.0)
	var t_ground := _ray_sphere(origin, view_dir, RG)
	var t_top := _ray_sphere(origin, view_dir, RT)
	var t_max := t_ground if t_ground > 0.0 else maxf(t_top, 0.0)
	var dt := t_max / float(MARCH_STEPS)
	var radii := PackedFloat32Array()
	var ups := PackedVector3Array()
	var w_rayleigh := PackedVector3Array()
	var w_mie := PackedVector3Array()
	var w_scatter := PackedVector3Array()
	var throughput := Vector3.ONE
	for i in MARCH_STEPS:
		var t := (float(i) + MARCH_SAMPLE_OFFSET) * dt
		var p := origin + view_dir * t
		var p_height := p.length()
		var h := maxf(p_height - RG, 0.0)
		var rayleigh := RAYLEIGH_SCATTERING * exp(-h / RAYLEIGH_SCALE_HEIGHT)
		var mie_density := exp(-h / MIE_SCALE_HEIGHT)
		var mie := MIE_SCATTERING * mie_density
		var ozone := maxf(0.0, 1.0 - absf(h - OZONE_CENTER) / OZONE_HALF_WIDTH)
		var extinction := (
			rayleigh + Vector3.ONE * (MIE_EXTINCTION * mie_density) + OZONE_ABSORPTION * ozone
		)
		var step_t := Vector3(
			exp(-extinction.x * dt), exp(-extinction.y * dt), exp(-extinction.z * dt)
		)
		var w := throughput * (Vector3.ONE - step_t) / extinction.max(Vector3.ONE * 1e-7)
		radii.append(p_height)
		ups.append(p / p_height)
		w_rayleigh.append(w * rayleigh)
		w_mie.append(w * mie)
		w_scatter.append(w * (rayleigh + Vector3.ONE * mie))
		throughput *= step_t
	return {
		"view": view_dir,
		"radii": radii,
		"ups": ups,
		"w_rayleigh": w_rayleigh,
		"w_mie": w_mie,
		"w_scatter": w_scatter,
	}


## Single scattering (Earth-shadowed, sun transmittance from the LUT) plus the Psi_ms
## multi-scattering term along one precomputed path, times SUN_ILLUMINANCE.
static func _path_radiance(path: Dictionary, sun_local: Vector3) -> Vector3:
	var cos_theta: float = (path["view"] as Vector3).dot(sun_local)
	var phase_r := 3.0 / (16.0 * PI) * (1.0 + cos_theta * cos_theta)
	var g2 := MIE_G * MIE_G
	var phase_m := (
		3.0 / (8.0 * PI) * ((1.0 - g2) * (1.0 + cos_theta * cos_theta))
		/ ((2.0 + g2) * pow(maxf(1.0 + g2 - 2.0 * MIE_G * cos_theta, 1e-4), 1.5))
	)
	var radii: PackedFloat32Array = path["radii"]
	var ups: PackedVector3Array = path["ups"]
	var w_rayleigh: PackedVector3Array = path["w_rayleigh"]
	var w_mie: PackedVector3Array = path["w_mie"]
	var w_scatter: PackedVector3Array = path["w_scatter"]
	var radiance := Vector3.ZERO
	for i in radii.size():
		var r := radii[i]
		var sun_cos := ups[i].dot(sun_local)
		radiance += _multiscatter_at(r, sun_cos) * w_scatter[i]
		# Earth shadow, as the kernel's ray_sphere test from p + up * offset: the sun ray
		# hits the ground when it points below that sample's geometric horizon.
		var ro := r + PLANET_RADIUS_OFFSET_KM
		var shadow_cos := -sqrt(maxf(1.0 - (RG * RG) / (ro * ro), 0.0))
		if sun_cos >= shadow_cos:
			radiance += _transmittance_at(r, sun_cos) * (w_rayleigh[i] * phase_r + w_mie[i] * phase_m)
	return radiance * SUN_ILLUMINANCE
