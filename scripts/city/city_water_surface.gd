extends RefCounted

## CPU camera/buoyancy mirror of city sea displacement. Uses the baked CPU shore
## field, never GPU readback. Constants/formulas track shore_swash.gdshaderinc.
const PERIOD := 1638.4 / 182.0
## Mirrors CITY_C1_GEOMETRY / CITY_TROUGH_CLEARANCE in map_view_water.gdshader.
const CITY_C1_GEOMETRY := 0.0
const CITY_TROUGH_CLEARANCE := 0.05


static func field_at(shore: Dictionary, xz: Vector2) -> Vector4:
	if shore.is_empty():
		return Vector4(8.0, 0.5, 0.5, 0.0)
	var extent: Vector2 = shore["size"]
	var uv := (xz - (shore["origin"] as Vector2)) / extent
	if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
		return Vector4(8.0, 0.5, 0.5, 0.0)
	var grid: Vector2i = shore["grid"]
	var p := uv * Vector2(grid) - Vector2.ONE * 0.5
	var cell := Vector2i(p.floor())
	var f := p - p.floor()
	var rows: Array[Vector4] = []
	var samples: PackedFloat32Array = shore["samples"]
	for j in 2:
		var pair: Array[Vector4] = []
		for i in 2:
			var idx := (
				(clampi(cell.y + j, 0, grid.y - 1) * grid.x + clampi(cell.x + i, 0, grid.x - 1)) * 4
			)
			pair.append(Vector4(samples[idx], samples[idx + 1], samples[idx + 2], samples[idx + 3]))
		rows.append(pair[0].lerp(pair[1], f.x))
	return rows[0].lerp(rows[1], f.y)


static func shore_lift(xz: Vector2, field: Vector4, time: float, mat: ShaderMaterial) -> float:
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
	# WR-1: same geometry as the shader's city path (no C1, bed-relative troughs).
	var wave := OceanFftSampler.height_at(xz, time, surface, 2, CITY_C1_GEOMETRY) * shelter
	wave *= OceanFftSampler.shore_displacement_scale(
		clampf(depth / CityWorld3D.SEA_SHORE_DEPTH, 0.0, 1.0)
	)
	var tide := (
		_float_parameter(mat, &"tide_height", 0.0) * _float_parameter(mat, &"tide_level", 0.0)
	)
	var room := tide - (bed + CITY_TROUGH_CLEARANCE)
	var ocean_y := tide + OceanFftSampler.bed_trough(wave, room) + shore_lift(xz, field, time, mat)
	return float(runup_profile(xz, field, time, mat, bed, ocean_y)["height"])


## CPU mirror of the continuous city run-up, for camera sampling and regression
## checks. Coverage below the actual sea plane cannot depend on the field's zero.
static func runup_profile(
	xz: Vector2, field: Vector4, time: float, mat: ShaderMaterial, bed: float, ocean_y: float
) -> Dictionary:
	var tide := _float_parameter(mat, &"tide_height", 0.0) * _float_parameter(mat, &"tide_level", 0.0)
	var valid := 1.0 - smoothstep(7.0, 8.0, absf(field.x))
	if (Vector2(field.y, field.z) * 2.0 - Vector2.ONE).length() < 0.2:
		valid = 0.0
	var beach := smoothstep(0.35, 0.65, field.w)
	var sea := clampf(_float_parameter(mat, &"shore_sea_state", 0.35), 0.0, 1.0)
	var energy := lerpf(0.35, 1.0, sea) * _float_parameter(mat, &"shore_strength", 1.0)
	var cycle := time / PERIOD + 0.55 * _noise(xz * 0.05 + Vector2(0.0, 3.7))
	var u := fposmod(cycle, 1.0)
	var scale := 0.87 * 0.05 * _float_parameter(mat, &"shore_depth_scale", 1.0)
	var h_deep := 0.34 * energy * _float_parameter(mat, &"shore_wave_gain", 1.0)
	var break_depth := pow(h_deep * pow(8.0 * scale, 0.25) / 0.78, 0.8)
	var break_x := minf(break_depth / scale, 7.5)
	var breaker_height := 0.78 * maxf(break_x, 0.02) * scale
	var variation := 0.8 + 0.4 * _noise(xz * 0.11 + Vector2(0.0, 17.3))
	var reach := (
		breaker_height * 1.8 / 0.87 * _float_parameter(mat, &"shore_runup_gain", 3.2) * variation
	)
	var envelope := 0.62 + 0.38 * (0.5 + 0.5 * sin(TAU * floor(cycle) / 7.0 + 1.3))
	reach = minf(reach * envelope, 2.9)
	var front: float
	if u < 0.35:
		front = reach * (1.0 - pow(1.0 - u / 0.35, 2.0))
	else:
		front = reach * (1.0 - pow((u - 0.35) / 0.65, 2.0))
	var distance := field.x + _float_parameter(mat, &"shore_tide_offset", 0.0)
	var front_distance := front + distance
	var sheet := 0.045 * energy * sqrt(clampf(front_distance / maxf(front, 0.05), 0.0, 1.0))
	sheet *= 1.0 if u < 0.35 else 0.45
	var roller := exp(-pow((front_distance - 0.28) / 0.32, 2.0))
	var thickness := (sheet * 3.0 + roller * lerpf(0.10, 0.42, sea))
	thickness *= smoothstep(0.001, 0.04, front) * smoothstep(0.0, 0.12, front_distance)
	var shore_blend := smoothstep(-0.45, 0.12, bed) * beach * valid
	var bed_surface := bed + 0.018 + thickness
	var merge := maxf(0.12 - absf(ocean_y - bed_surface), 0.0) / 0.12
	var joined := maxf(ocean_y, bed_surface) + merge * merge * 0.03
	var height := maxf(lerpf(ocean_y, joined, shore_blend), bed + 0.018)
	var coverage := 1.0
	if bed > tide + 0.002:
		coverage = smoothstep(0.0, 0.12, front_distance)
		if valid * beach < 0.01 or front < 0.001 or front_distance <= 0.0:
			coverage = 0.0
	return {"height": height, "coverage": coverage, "front_distance": front_distance}


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
