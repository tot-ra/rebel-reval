extends RefCounted

## CPU camera/buoyancy mirror of city sea displacement. Uses the baked CPU shore
## field, never GPU readback. Constants/formulas track shore_swash.gdshaderinc.
const PERIOD := 1638.4 / 182.0
## Mirrors CITY_C1_GEOMETRY / CITY_TROUGH_CLEARANCE in map_view_water.gdshader.
const CITY_C1_GEOMETRY := 0.0
const CITY_TROUGH_CLEARANCE := 0.05
## Backwash rundown below the still-water line (SHORE_RUNDOWN, CITY_RUNDOWN_BED).
const RUNDOWN := 0.3
const RUNDOWN_BED := 0.3
## WR-4 bed-aware surf, mirrors the BED_* constants in shore_swash.gdshaderinc.
const GAMMA := 0.78
const BED_L0 := 9.81 * PERIOD * PERIOD / TAU
const BED_REF_DEPTH := 4.0
const BED_MIN_DEPTH := 0.05
const BED_ONSET := 3.0
const BED_PHASE_VARIATION := 0.15
const BED_LOCAL_SLOPE_MAX := 0.1
const BED_PLUNGE_XI := Vector2(0.45, 0.8)
const BED_SURGE_XI := Vector2(1.6, 2.4)
const BED_CREST_WIDTH := 0.24
const BED_NONE := Vector4(0.0, -1.0, 0.0, 0.0)


static func field_at(shore: Dictionary, xz: Vector2) -> Vector4:
	return _bilinear(shore, "samples", xz, Vector4(8.0, 0.5, 0.5, 0.0))


## WR-4 bathymetry texel (CityShoreField "bed_samples"): depth, travel time,
## beach-face slope, controlling depth.
static func bed_at(shore: Dictionary, xz: Vector2) -> Vector4:
	return _bilinear(shore, "bed_samples", xz, BED_NONE)


## True when the shader runs the bed-aware surf (the city binds shore_bed).
static func bed_enabled(shore: Dictionary, mat: ShaderMaterial) -> bool:
	return shore.has("bed_samples") and _float_parameter(mat, &"shore_bed_valid", 0.0) > 0.5


## Clamp-to-edge bilinear filter over one of the baked RGBA float sample arrays.
static func _bilinear(shore: Dictionary, key: String, xz: Vector2, outside: Vector4) -> Vector4:
	if shore.is_empty() or not shore.has(key):
		return outside
	var extent: Vector2 = shore["size"]
	var uv := (xz - (shore["origin"] as Vector2)) / extent
	if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
		return outside
	var grid: Vector2i = shore["grid"]
	var p := uv * Vector2(grid) - Vector2.ONE * 0.5
	var cell := Vector2i(p.floor())
	var f := p - p.floor()
	var rows: Array[Vector4] = []
	var samples: PackedFloat32Array = shore[key]
	for j in 2:
		var pair: Array[Vector4] = []
		for i in 2:
			var idx := (
				(clampi(cell.y + j, 0, grid.y - 1) * grid.x + clampi(cell.x + i, 0, grid.x - 1)) * 4
			)
			pair.append(Vector4(samples[idx], samples[idx + 1], samples[idx + 2], samples[idx + 3]))
		rows.append(pair[0].lerp(pair[1], f.x))
	return rows[0].lerp(rows[1], f.y)


static func shore_lift(
	xz: Vector2, field: Vector4, time: float, mat: ShaderMaterial, shore := {}
) -> float:
	if bed_enabled(shore, mat):
		var bed := bed_state(shore, xz, time, mat)
		return float(bed["height"]) * _float_parameter(mat, &"shore_geometry_scale", 0.12) \
			* float(bed["valid"])
	var direction := Vector2(field.y, field.z) * 2.0 - Vector2.ONE
	if direction.length() < 0.2:
		return 0.0
	var x := field.x + _float_parameter(mat, &"shore_tide_offset", 0.0)
	if x < 0.0:
		return 0.0
	var valid := 1.0 - smoothstep(7.0, 8.0, absf(field.x))
	var beach := smoothstep(0.35, 0.65, field.w)
	var sea := clampf(_float_parameter(mat, &"shore_sea_state", 0.35), 0.0, 1.0)
	var energy := lerpf(0.35, 1.0, sea) * _float_parameter(mat, &"shore_strength", 1.0)
	var h_deep := 0.34 * energy * _float_parameter(mat, &"shore_wave_gain", 1.0)
	var u := fposmod(time / PERIOD + 0.55 * _noise(xz * 0.05 + Vector2(0.0, 3.7)), 1.0)
	var scale := 0.87 * 0.05 * _float_parameter(mat, &"shore_depth_scale", 1.0)
	var crest_x := 8.0 * pow(clampf((1.0 - u) / 0.45, 0.0, 1.0), 0.8)
	var depth := maxf(crest_x, 0.02) * scale
	var height := h_deep * pow(8.0 * scale / maxf(depth, 0.00001), 0.25)
	var steep := clampf(height / maxf(0.78 * depth, 0.00001), 0.0, 1.0)
	height = minf(height, 0.78 * depth)
	var rel := x - crest_x
	var round_crest := clampf(_float_parameter(mat, &"shore_crest_shape", 0.0), 0.0, 1.0)
	var width := lerpf(2.4, 1.4, steep) * lerpf(1.0, 1.3, round_crest)
	var face := width * lerpf(1.0, lerpf(0.4, 0.65, round_crest), steep) if rel < 0.0 else width
	var phase := clampf(rel / face, -1.0, 1.0) * PI
	var profile := pow(
		maxf(0.5 + 0.5 * cos(phase), 0.000001), 1.0 + lerpf(2.0, 0.8, round_crest) * steep
	)
	var incoming := (1.0 if u >= 0.55 else 0.0) * (1.0 - smoothstep(6.5, 8.0, crest_x))
	var crest := height / 0.87 * profile * incoming * beach
	var slosh := h_deep * 0.5 * sin(TAU * u) / 0.87 * exp(-x / 1.5) * (1.0 - beach)
	return (crest + maxf(slosh, 0.0)) * _float_parameter(mat, &"shore_geometry_scale", 0.12) * valid


static func sea_height(world: CityWorld3D, xz: Vector2) -> float:
	var mat := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	var bed := world.plan.ground_height(xz)
	var depth := maxf(-bed, 0.0)
	var range_m: Vector2 = _parameter(mat, &"sea_depth_range", Vector2(1.0, 3.6))
	var shallow: Vector4 = _parameter(mat, &"sea_wave_shallow", Vector4(0.85, 1.0, 0.18, 0.07))
	var deep: Vector4 = _parameter(mat, &"sea_wave_deep", Vector4(1.05, 1.0, 0.08, 0.12))
	var params := shallow.lerp(deep, smoothstep(range_m.x, range_m.y, depth))
	var sea := OceanFftSampler.sea_state()
	var surface := Vector3(params.y, params.x / maxf(float(sea["choppiness"]), 0.001), params.z)
	var time := OceanFftSampler.ocean_time()
	var wind: Vector2 = sea["wind_axis"]
	var field := field_at(world.sea_shore, xz)
	var upwind := field_at(world.sea_shore, xz - wind * 8.0)
	var shelter := (
		OceanFftSampler.fetch_shelter_scale(field.x, upwind.x)
		if not world.sea_shore.is_empty()
		else 1.0
	)
	# WR-1: same geometry as the shader's city path (bed-relative troughs). WR-3:
	# the ring LOD decides the C0/C1 share by mesh spacing and camera distance
	# (CitySeaLod.displacement_weights mirrors _sea_lod_weights); without it the
	# fixed-grid rule (no C1) holds. C0 scales the height only, not the horizontal
	# inversion inside height_at; it is 1 within ~250 m of the camera.
	var weights := Vector2(1.0, CITY_C1_GEOMETRY)
	if world.sea_lod != null:
		weights = world.sea_lod.displacement_weights(xz)
	var wave := OceanFftSampler.height_at(xz, time, surface, 2, weights.y) * weights.x * shelter
	wave *= OceanFftSampler.shore_displacement_scale(
		clampf(depth / CityWorld3D.SEA_SHORE_DEPTH, 0.0, 1.0)
	)
	var tide := (
		_float_parameter(mat, &"tide_height", 0.0) * _float_parameter(mat, &"tide_level", 0.0)
	)
	var room := tide - (bed + CITY_TROUGH_CLEARANCE)
	var ocean_y := (
		tide + OceanFftSampler.bed_trough(wave, room)
		+ shore_lift(xz, field, time, mat, world.sea_shore)
	)
	return float(runup_profile(xz, field, time, mat, bed, ocean_y, world.sea_shore)["height"])


## CPU mirror of the continuous city run-up, for camera sampling and regression
## checks. Coverage below the actual sea plane cannot depend on the field's zero.
static func runup_profile(
	xz: Vector2, field: Vector4, time: float, mat: ShaderMaterial, bed: float, ocean_y: float,
	shore := {}
) -> Dictionary:
	var tide := _float_parameter(mat, &"tide_height", 0.0) * _float_parameter(mat, &"tide_level", 0.0)
	var valid := 1.0 - smoothstep(7.0, 8.0, absf(field.x))
	if (Vector2(field.y, field.z) * 2.0 - Vector2.ONE).length() < 0.2:
		valid = 0.0
	var beach := smoothstep(0.35, 0.65, field.w)
	var sea := clampf(_float_parameter(mat, &"shore_sea_state", 0.35), 0.0, 1.0)
	var energy := lerpf(0.35, 1.0, sea) * _float_parameter(mat, &"shore_strength", 1.0)
	var cycle := time / PERIOD + 0.55 * _noise(xz * 0.05 + Vector2(0.0, 3.7))
	var scale := 0.87 * 0.05 * _float_parameter(mat, &"shore_depth_scale", 1.0)
	var h_deep := 0.34 * energy * _float_parameter(mat, &"shore_wave_gain", 1.0)
	var break_depth := pow(h_deep * pow(8.0 * scale, 0.25) / 0.78, 0.8)
	var break_x := minf(break_depth / scale, 7.5)
	var breaker_height := 0.78 * maxf(break_x, 0.02) * scale
	var drain := 0.0
	if bed_enabled(shore, mat):
		var state := bed_state(shore, xz, time, mat)
		valid = state["valid"]
		cycle = state["cycle"]
		# Run-up reach keeps the calibrated district breaker height (shore_state).
		drain = state["surging"]
	var u := fposmod(cycle, 1.0)
	var wave_index := floorf(cycle)
	var base_reach := breaker_height * 1.8 / 0.87 * _float_parameter(mat, &"shore_runup_gain", 3.2)
	var reach := base_reach * reach_variation(xz, wave_index)
	var envelope := 0.62 + 0.38 * (0.5 + 0.5 * sin(TAU * wave_index / 7.0 + 1.3))
	reach = minf(reach * envelope, 2.9)
	var front: float
	if u < 0.35:
		front = reach * (1.0 - pow(1.0 - u / 0.35, 2.0))
	else:
		var b := (u - 0.35) / 0.65
		front = reach * (1.0 - (pow(b, lerpf(2.0, 1.2, drain)) if drain > 0.0 else b * b))
	var distance := field.x + _float_parameter(mat, &"shore_tide_offset", 0.0)
	# Mirrors the bed-mode rundown in shore_state: the backwash drains below the
	# still-water line before the next bore.
	var rundown := 0.0
	if bed_enabled(shore, mat):
		var drained := maxf(smoothstep(0.6, 1.0, u), 1.0 - smoothstep(0.0, 0.12, u))
		var steady := _noise(xz * 0.11 + Vector2(0.0, 17.3))
		rundown = RUNDOWN * base_reach * (0.6 + 0.8 * steady) * drained
	var front_distance := front - rundown + distance
	var sheet := 0.045 * energy * sqrt(clampf(front_distance / maxf(front, 0.05), 0.0, 1.0))
	sheet *= 1.0 if u < 0.35 else lerpf(0.45, 0.9, drain)
	var backwash := clampf((u - 0.35) / 0.65, 0.0, 1.0)
	var roller := exp(-pow((front_distance - 0.28) / 0.32, 2.0))
	roller *= lerpf(1.0, 0.15, smoothstep(0.0, 0.25, backwash))
	var thickness := (sheet * 3.0 + roller * lerpf(0.10, 0.42, sea))
	thickness *= smoothstep(0.001, 0.04, front) * smoothstep(0.0, 0.12, front_distance)
	var shore_blend := smoothstep(-0.45, 0.12, bed) * beach * valid
	var bed_surface := bed + 0.018 + thickness
	var merge := maxf(0.12 - absf(ocean_y - bed_surface), 0.0) / 0.12
	var joined := maxf(ocean_y, bed_surface) + merge * merge * 0.03
	var height := maxf(lerpf(ocean_y, joined, shore_blend), bed + 0.018)
	var coverage := 1.0
	if bed > tide - RUNDOWN_BED:
		var runs_up := valid * beach >= 0.01
		var tip := smoothstep(0.0, edge_feather(xz, wave_index, u), front_distance) if runs_up else 0.0
		if bed > tide + 0.002:
			coverage = tip
			if not runs_up or front < 0.001 or front_distance <= 0.0:
				coverage = 0.0
		elif runs_up:
			coverage = lerpf(1.0, tip, smoothstep(0.0, 0.05, rundown))
			if coverage < 0.001:
				coverage = 0.0
	return {"height": height, "coverage": coverage, "front_distance": front_distance}


## WR-4 depth (m) at which this sea state breaks (_shore_bed_break_depth).
static func bed_break_depth(h_deep: float) -> float:
	return pow(h_deep * pow(BED_REF_DEPTH, 0.25) / GAMMA, 0.8)


## WR-4 crest profile, mirrors _shore_bed_profile.
static func bed_profile(
	rel: float, wavelength: float, steep: float, plunge: float, surging: float
) -> float:
	var width := maxf(BED_CREST_WIDTH * wavelength, 1.5)
	var face_k := lerpf(lerpf(0.65, 0.42, plunge), 0.9, surging)
	var face := width * lerpf(1.0, face_k, steep) if rel < 0.0 else width
	var phase := clampf(rel / face, -1.0, 1.0) * PI
	var base := maxf(0.5 + 0.5 * cos(phase), 0.000001)
	return pow(base, 1.0 + lerpf(lerpf(0.8, 1.8, plunge), 0.5, surging) * steep)


## CPU mirror of the bed-aware branch of shore_state (shore_swash.gdshaderinc):
## validity, travel direction, phase, breaker class and the water-side height
## (world units before shore_geometry_scale). Same three bed taps as the GPU.
static func bed_state(
	shore: Dictionary, xz: Vector2, time: float, mat: ShaderMaterial
) -> Dictionary:
	var out := {
		"valid": 0.0, "distance": 8.0, "beach": 0.0, "to_land": Vector2.ZERO, "plunge": 0.0,
		"surging": 0.0, "cycle": 0.0, "height": 0.0, "breaking": 0.0, "reformed": 0.0, "xi": 0.0,
	}
	var extent: Vector2 = shore["size"]
	var uv := (xz - (shore["origin"] as Vector2)) / extent
	if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
		return out
	if _float_parameter(mat, &"shore_strength", 1.0) <= 0.0:
		return out
	var field := field_at(shore, xz)
	var cell := extent / Vector2(shore["grid"])
	var bed := bed_at(shore, xz)
	var bed_dx := bed_at(shore, xz + Vector2(cell.x, 0.0))
	var bed_dz := bed_at(shore, xz + Vector2(0.0, cell.y))
	var dir := Vector2(field.y, field.z) * 2.0 - Vector2.ONE
	var dir_length := dir.length()
	dir = dir / dir_length if dir_length > 0.0001 else Vector2.ZERO
	var x := field.x + _float_parameter(mat, &"shore_tide_offset", 0.0)
	var beach := smoothstep(0.35, 0.65, field.w)
	var valid := (
		smoothstep(-0.9, -0.1, bed.y) * smoothstep(-0.9, -0.1, minf(bed_dx.y, bed_dz.y))
		* (1.0 - smoothstep(7.0, 8.0, maxf(-field.x, 0.0)))
	)
	var grad_tau := Vector2(bed_dx.y - bed.y, bed_dz.y - bed.y) / cell
	var ray := smoothstep(0.02, 0.06, grad_tau.length()) * (1.0 if valid >= 0.2 else 0.0)
	var travel := dir.lerp(grad_tau / maxf(grad_tau.length(), 0.0001), ray)
	var to_land := travel.normalized() if travel.length() > 0.0001 else Vector2.ZERO
	var sea := clampf(_float_parameter(mat, &"shore_sea_state", 0.35), 0.0, 1.0)
	var strength := _float_parameter(mat, &"shore_strength", 1.0)
	var energy := lerpf(0.35, 1.0, sea) * strength
	var h_deep := 0.34 * energy * _float_parameter(mat, &"shore_wave_gain", 1.0)
	var cycle := (
		(time - maxf(bed.y, 0.0)) / PERIOD
		+ BED_PHASE_VARIATION * _noise(xz * 0.02 + Vector2(0.0, 3.7))
	)
	var u := cycle - floorf(cycle)
	var h := maxf(bed.x, BED_MIN_DEPTH)
	var h_ctrl := clampf(bed.w, BED_MIN_DEPTH, h)
	var grad_h := Vector2(bed_dx.x - bed.x, bed_dz.x - bed.x) / cell
	var up := clampf(-grad_h.dot(to_land), 0.0, BED_LOCAL_SLOPE_MAX)
	var breaker := GAMMA * bed_break_depth(h_deep)
	var steepness := sqrt(maxf(breaker, 0.02) / BED_L0)
	var xi := maxf(bed.z, up) / steepness
	var plunge := smoothstep(BED_PLUNGE_XI.x, BED_PLUNGE_XI.y, xi)
	var surging := smoothstep(BED_SURGE_XI.x, BED_SURGE_XI.y, xi)
	out.merge({
		"valid": valid, "distance": x, "beach": beach, "to_land": to_land, "plunge": plunge,
		"surging": surging, "cycle": cycle, "xi": xi,
	}, true)
	if x < 0.0:
		return out
	var shoal := h_deep * pow(BED_REF_DEPTH / h, 0.25)
	var height := minf(shoal, GAMMA * h_ctrl)
	var steep := clampf(height / (GAMMA * h), 0.0, 1.0)
	var breaking := smoothstep(0.9, 1.0, steep)
	var broke_before := smoothstep(
		0.92, 1.0, h_deep * pow(BED_REF_DEPTH / h_ctrl, 0.25) / (GAMMA * h_ctrl)
	)
	var wavelength := BED_L0 * sqrt(tanh(TAU * h / BED_L0))
	var onset := smoothstep(0.0, BED_ONSET, bed.y)
	var rel := (u if u < 0.5 else u - 1.0) * wavelength
	var incident := height * onset * bed_profile(rel, wavelength, steep, plunge, surging)
	var xi_face := bed.z / steepness
	var reflect_k := clampf(0.1 * xi_face * xi_face, 0.0, 1.0)
	var to_shore := maxf(x, 0.0) * _float_parameter(mat, &"shore_depth_scale", 1.0)
	var u_back := fposmod(u - 2.0 * to_shore / wavelength, 1.0)
	var reflected := (
		reflect_k * 0.5 * height * onset * exp(-to_shore / (0.5 * wavelength))
		* bed_profile((u_back if u_back < 0.5 else u_back - 1.0) * wavelength, wavelength,
			steep, 0.0, 1.0)
	)
	out["height"] = incident + reflected
	out["breaking"] = breaking
	out["reformed"] = broke_before * (1.0 - breaking)
	return out


## Mirrors _swash_wave_seed: per-wave offset, periodic over the 182-wave wrap.
static func _wave_seed(wave_index: float) -> Vector2:
	var m := fposmod(wave_index, 182.0)
	return Vector2(fposmod(m * 0.6180340, 1.0), fposmod(m * 0.7548777, 1.0)) * 61.0


## Mirrors _swash_reach_variation: per-wave tongues and fingers of the run-up front.
static func reach_variation(xz: Vector2, wave_index: float) -> float:
	var seed := _wave_seed(wave_index)
	var steady := _noise(xz * 0.11 + Vector2(0.0, 17.3))
	var lobes := _noise(xz * 0.23 + seed)
	var fingers := _noise(xz * 0.9 + Vector2(seed.y, seed.x) * 1.7)
	return 0.6 + 0.25 * steady + 0.4 * lobes + 0.15 * fingers


## Mirrors _swash_edge_feather: width of the thinning film tip, world units,
## morphing into the next wave's pattern over the cycle u.
static func edge_feather(xz: Vector2, wave_index: float, u: float) -> float:
	var now := _noise(xz * 2.7 + _wave_seed(wave_index) * 0.37)
	var next := _noise(xz * 2.7 + _wave_seed(wave_index + 1.0) * 0.37)
	return 0.12 + 0.55 * lerpf(now, next, u)


static func _hash(p: Vector2) -> float:
	return fposmod(sin(p.dot(Vector2(127.1, 311.7))) * 43758.5453123, 1.0)


static func _noise(p: Vector2) -> float:
	var cell := p.floor()
	var f := p - cell
	f = f * f * (Vector2.ONE * 3.0 - f * 2.0)
	return lerpf(
		lerpf(_hash(cell), _hash(cell + Vector2.RIGHT), f.x),
		lerpf(_hash(cell + Vector2.DOWN), _hash(cell + Vector2.ONE), f.x),
		f.y
	)


# Dummy rendering has no shader defaults; match the declared GPU defaults.
static func _parameter(mat: ShaderMaterial, key: StringName, fallback: Variant) -> Variant:
	var value: Variant = mat.get_shader_parameter(key)
	return fallback if value == null else value


static func _float_parameter(mat: ShaderMaterial, key: StringName, fallback: float) -> float:
	return float(_parameter(mat, key, fallback))
