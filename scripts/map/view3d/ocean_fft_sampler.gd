class_name OceanFftSampler
extends RefCounted

## WS-05 CPU mirror of the WS-04 baked FFT ocean. Boats (and later the camera,
## swimmer and underwater waterline, WS-13..15) query the same C0 + C1 atlases,
## decode scales, wind rotation, standing-wave blend, sea state and ocean_time as
## the water shader, so a hull rides the exact crest the player sees.
##
## Keep in lockstep with map_view_water.gdshader _fft_* (the functions live in
## ocean_fft_common.gdshaderinc): _fft_sample, _fft_signed, _fft_displacement_at,
## _fft_displacement_foam and _fft_trough_floor.
##
## The atlases are decoded on the CPU once, at first use, from the imported files
## (no GPU readback, see _read_atlas()). Raw
## RGBA8 bytes are kept, laid out [frame][row z][column x][rgba]; expanding them
## to floats would quadruple the 8 MiB footprint.

const WATER_MATERIALS := preload("res://scripts/map/view3d/map_view_water_materials.gd")

## C2 (waves under 4 m) has no displacement atlas and cannot move a hull.
const DISP_CASCADES := 2
const DISP_ATLASES: Array[String] = ["c0_disp.png", "c1_disp.png"]
## Shader constants, see ocean_fft_common.gdshaderinc.
const HORIZONTAL_GEOMETRY := 0.5
const TROUGH_FLOOR := 0.0015
const STANDING_CHOP_REDUCTION := 0.65
const DEFAULT_WIND := Vector2(1.0, 0.28)
## Upwind probe for the WS-08 signed shore field (world units, ~7 m).
const FETCH_PROBE_UNITS := 8.0
## Open-water fetch / basin distance at which shelter eases to 1.
const FETCH_OPEN_UNITS := 12.0
## Near-shore basin floor. Signed distance below this still reads as sheltered.
const SHELTER_NEAR_UNITS := 1.5
## Amplitude and foam scale in the lee of a quay or headland.
const SHELTER_LEE_SCALE := 0.38
## Per-call surface terms that the shader reads from the material of one water
## terrain: x = fft_geometry_scale, y = choppiness ratio to open sea, z = standing
## ratio (negative = the sea-state default). PHYSICAL_SURFACE is the unscaled
## baked sea in world units, used by the tests and by physical queries.
const PHYSICAL_SURFACE := Vector3(1.0, 1.0, -1.0)
## Fixed-point iterations that invert horizontal chop in height_at(). Three
## converge under 1 mm for choppiness <= 1.2 (WS-05 contract).
const HEIGHT_ITERATIONS := 3

static var _loaded := false
static var _load_failed := false
static var _load_msec := 0.0
static var _bytes: Array[PackedByteArray] = []
static var _texels: PackedInt32Array = PackedInt32Array()
## Per cascade: patch size in world units, loop period s, frame count.
static var _patch: PackedFloat64Array = PackedFloat64Array()
static var _period: PackedFloat64Array = PackedFloat64Array()
static var _frames: PackedInt32Array = PackedInt32Array()
## Dx, Dy, Dz decode scale in metres per cascade.
static var _scale: Array[Vector3] = []
static var _meters_per_unit := 0.87

static var _weights: PackedFloat64Array = PackedFloat64Array([1.0, 1.0])
static var _choppiness := 0.9
static var _amplitude := 1.0
static var _wind_axis := DEFAULT_WIND.normalized()
static var _standing := 0.42
static var _has_time_override := false
static var _time_override := 0.0


## Decodes both displacement atlases once. False when the bake is missing, and
## callers then stay on the Gerstner fallback.
static func ensure_loaded() -> bool:
	if _loaded:
		return true
	if _load_failed:
		return false
	return load_profile()


static func load_profile() -> bool:
	var started := Time.get_ticks_usec()
	var profile: Dictionary = WATER_MATERIALS.ocean_fft_profile()
	var cascades: Array = profile.get("cascades", [])
	if cascades.size() < DISP_CASCADES:
		_load_failed = true
		return false
	_meters_per_unit = float(profile.get("meters_per_world_unit", 0.87))
	_bytes.clear()
	_texels.clear()
	_patch.clear()
	_period.clear()
	_frames.clear()
	_scale.clear()
	for index in DISP_CASCADES:
		var cascade: Dictionary = cascades[index]
		var atlas := _read_atlas(WATER_MATERIALS.OCEAN_FFT_DIR + DISP_ATLASES[index])
		if atlas.is_empty():
			_load_failed = true
			return false
		var bytes: PackedByteArray = atlas["bytes"]
		var frames := int(atlas["frames"])
		var size := int(atlas["size"])
		var scales: Dictionary = cascade.get("channel_scales", {})
		_bytes.append(bytes)
		_texels.append(size)
		_patch.append(float(cascade.get("patch_m", 1.0)) / _meters_per_unit)
		_period.append(float(cascade.get("period_s", 1.0)))
		_frames.append(frames)
		_scale.append(
			Vector3(
				float(scales.get("dx", 0.0)),
				float(scales.get("dy", 0.0)),
				float(scales.get("dz", 0.0))
			)
		)
	_loaded = true
	_load_msec = float(Time.get_ticks_usec() - started) / 1000.0
	if _weights.size() < DISP_CASCADES:
		reset_sea_state()
	return true


## Decodes every frame of one imported atlas into [frame][z][x][rgba] bytes.
##
## WHY the imported file is parsed instead of TextureLayered.get_layer_data():
## the headless and dummy renderers return null for layer data (the test suite
## runs headless), and on GL Compatibility the call is a GPU readback, which WS-05
## rules out. The .ctexarray holds the exact lossless WebP/PNG layers the GPU
## uploads, so decoding it gives the shader's texels byte for byte, in exports too
## (the .import remap and the imported file ship in the pck; source PNGs do not).
static func _read_atlas(source_path: String) -> Dictionary:
	var remap := ConfigFile.new()
	if remap.load(source_path + ".import") != OK:
		push_error("WS-05: missing import remap for %s" % source_path)
		return {}
	var imported_path := String(remap.get_value("remap", "path", ""))
	var file := FileAccess.open(imported_path, FileAccess.READ)
	if file == null:
		push_error("WS-05: cannot open imported ocean FFT atlas %s" % imported_path)
		return {}
	# CompressedTextureLayered header: "GSTL", version, layer count, type,
	# mipmap count, then four reserved words.
	if file.get_buffer(4).get_string_from_ascii() != "GSTL":
		push_error("WS-05: %s is not a CompressedTextureLayered file" % imported_path)
		return {}
	file.get_32()
	var layers := file.get_32()
	file.get_32()
	file.get_32()
	for reserved in 4:
		file.get_32()
	var bytes := PackedByteArray()
	var size := 0
	for layer in layers:
		var image := _read_layer_image(file)
		if image == null:
			push_error("WS-05: unreadable layer %d of %s" % [layer, imported_path])
			return {}
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		size = image.get_width()
		bytes.append_array(image.get_data())
	return {"bytes": bytes, "frames": layers, "size": size}


## One CompressedTexture2D image block: data format, width, height, mipmap count,
## image format, then one size-prefixed buffer per mip level (only mip 0 is kept;
## the FFT atlases import without mipmaps).
static func _read_layer_image(file: FileAccess) -> Image:
	const DATA_FORMAT_PNG := 1
	const DATA_FORMAT_WEBP := 2
	var data_format := file.get_32()
	file.get_16()
	file.get_16()
	var mipmaps := file.get_32()
	file.get_32()
	var image: Image = null
	for mip in mipmaps + 1:
		var buffer := file.get_buffer(file.get_32())
		if mip > 0:
			continue
		image = Image.new()
		var error := ERR_FILE_UNRECOGNIZED
		if data_format == DATA_FORMAT_WEBP:
			error = image.load_webp_from_buffer(buffer)
		elif data_format == DATA_FORMAT_PNG:
			error = image.load_png_from_buffer(buffer)
		if error != OK:
			return null
	return image


static func load_msec() -> float:
	return _load_msec


## Byte footprint of the decoded atlases (both cascades).
static func memory_bytes() -> int:
	var total := 0
	for bytes in _bytes:
		total += bytes.size()
	return total


## map_view_water_materials.apply_sea_weather() sends the same values here that it
## sends to the shader, so CPU hulls and GPU water share one sea.
static func set_sea_state(
	weights: PackedFloat32Array,
	choppiness: float,
	amplitude: float,
	wind_dir: Vector2,
	standing_ratio: float
) -> void:
	_weights = PackedFloat64Array()
	for index in DISP_CASCADES:
		_weights.append(float(weights[index]) if index < weights.size() else 0.0)
	_choppiness = choppiness
	_amplitude = amplitude
	# Same fallback as apply_sea_weather() and _fft_wind_axis().
	var heading := wind_dir if wind_dir.length_squared() >= 0.0001 else DEFAULT_WIND
	_wind_axis = heading.normalized()
	_standing = clampf(standing_ratio, 0.0, 1.0)


## Back to the baked reference sea (weights and ocean_amplitude 1.0).
static func reset_sea_state() -> void:
	var reference: Dictionary = WATER_MATERIALS.fft_sea_state(
		WATER_MATERIALS.OCEAN_FFT_REFERENCE_SEA_STATE, 0.0
	)
	var harbour: Dictionary = WATER_MATERIALS.WATER_WAVE_BASE[MapTypes.TERRAIN_WATER]
	set_sea_state(
		PackedFloat32Array(reference["weights"]),
		float(reference["choppiness"]),
		float(reference["amplitude"]),
		DEFAULT_WIND,
		float(harbour.get("standing", 0.42))
	)


static func sea_state() -> Dictionary:
	return {
		"weights": _weights,
		"choppiness": _choppiness,
		"amplitude": _amplitude,
		"wind_axis": _wind_axis,
		"standing": _standing,
	}


## The surface terms one water terrain's material uses on the FFT path:
## fft_geometry_scale, choppiness ratio and standing ratio.
static func terrain_surface(terrain_id: StringName) -> Vector3:
	var wave: Dictionary = WATER_MATERIALS.WATER_WAVE_BASE.get(
		terrain_id, WATER_MATERIALS.WATER_WAVE_BASE[MapTypes.TERRAIN_WATER]
	)
	return Vector3(
		WATER_MATERIALS.ocean_fft_geometry_scale(float(wave["height"])),
		WATER_MATERIALS.ocean_fft_choppiness_ratio(wave),
		float(wave.get("standing", 0.12)),
	)


## The shared sea clock (MapViewRuntimeEnvironment, wrapped at 25.6 * 64 s).
static func ocean_time() -> float:
	if _has_time_override:
		return _time_override
	return MapViewRuntimeEnvironment.ocean_time()


## Test hook; clear_time_override() returns to the runtime clock.
static func set_time_override(seconds: float) -> void:
	_has_time_override = true
	_time_override = seconds


static func clear_time_override() -> void:
	_has_time_override = false


## Weighted C0 + C1 displacement in metres, bake frame (_fft_displacement_at).
## Each cascade is bilinear in space and linear between the two bracketing frames,
## exactly like _fft_sample with a repeat, linear-filtered sampler at LOD 0.
static func baked_displacement(p: Vector2, time: float) -> Vector3:
	var result := Vector3.ZERO
	for cascade in DISP_CASCADES:
		var weight := _weights[cascade]
		if weight == 0.0:
			continue
		var n := _texels[cascade]
		var frames := _frames[cascade]
		var f := time / _period[cascade]
		f = (f - floorf(f)) * frames
		var i0 := int(floorf(f))
		var ft := f - float(i0)
		i0 = posmod(i0, frames)
		var i1 := (i0 + 1) % frames
		# Texel centres sit at (i + 0.5) / n, so the bilinear footprint starts half
		# a texel back.
		var tx := p.x / _patch[cascade] * n - 0.5
		var tz := p.y / _patch[cascade] * n - 0.5
		var x0f := floorf(tx)
		var z0f := floorf(tz)
		var fx := tx - x0f
		var fz := tz - z0f
		var x0 := posmod(int(x0f), n)
		var z0 := posmod(int(z0f), n)
		var x1 := (x0 + 1) % n
		var z1 := (z0 + 1) % n
		var w00 := (1.0 - fx) * (1.0 - fz)
		var w10 := fx * (1.0 - fz)
		var w01 := (1.0 - fx) * fz
		var w11 := fx * fz
		var row0 := z0 * n
		var row1 := z1 * n
		var o00 := (row0 + x0) * 4
		var o10 := (row0 + x1) * 4
		var o01 := (row1 + x0) * 4
		var o11 := (row1 + x1) * 4
		var bytes: PackedByteArray = _bytes[cascade]
		var layer := n * n * 4
		var a := i0 * layer
		var b := i1 * layer
		var wa := 1.0 - ft
		# The decode (v - 0.5) * 2 * scale is linear and the filter weights sum to
		# one, so the weighted byte sums decode in one step per channel.
		var sx := (
			wa * (
				w00 * bytes[a + o00] + w10 * bytes[a + o10]
				+ w01 * bytes[a + o01] + w11 * bytes[a + o11]
			)
			+ ft * (
				w00 * bytes[b + o00] + w10 * bytes[b + o10]
				+ w01 * bytes[b + o01] + w11 * bytes[b + o11]
			)
		)
		var sy := (
			wa * (
				w00 * bytes[a + o00 + 1] + w10 * bytes[a + o10 + 1]
				+ w01 * bytes[a + o01 + 1] + w11 * bytes[a + o11 + 1]
			)
			+ ft * (
				w00 * bytes[b + o00 + 1] + w10 * bytes[b + o10 + 1]
				+ w01 * bytes[b + o01 + 1] + w11 * bytes[b + o11 + 1]
			)
		)
		var sz := (
			wa * (
				w00 * bytes[a + o00 + 2] + w10 * bytes[a + o10 + 2]
				+ w01 * bytes[a + o01 + 2] + w11 * bytes[a + o11 + 2]
			)
			+ ft * (
				w00 * bytes[b + o00 + 2] + w10 * bytes[b + o10 + 2]
				+ w01 * bytes[b + o01 + 2] + w11 * bytes[b + o11 + 2]
			)
		)
		var scale: Vector3 = _scale[cascade]
		result += Vector3(
			(sx / 127.5 - 1.0) * scale.x,
			(sy / 127.5 - 1.0) * scale.y,
			(sz / 127.5 - 1.0) * scale.z,
		) * weight
	return result


## World-unit displacement of the surface point that rests at world_xz, before the
## shader's shore fade (_fft_displacement_foam). The surface point is
## x' = x + lambda * D with the positive WS-03 sign.
static func displacement_at(
	world_xz: Vector2, time: float, surface: Vector3 = PHYSICAL_SURFACE
) -> Vector3:
	if not ensure_loaded():
		return Vector3.ZERO
	var axis := _wind_axis
	var p := Vector2(
		world_xz.x * axis.x + world_xz.y * axis.y, -world_xz.x * axis.y + world_xz.y * axis.x
	)
	var d := baked_displacement(p, time)
	var standing := clampf(surface.z if surface.z >= 0.0 else _standing, 0.0, 1.0)
	if standing > 0.01:
		# Mirror train F(-p) with its horizontal displacement negated back.
		var o := baked_displacement(-p, time)
		o.x = -o.x
		o.z = -o.z
		d = d.lerp(0.5 * (d + o), standing)
	var chop := maxf(_choppiness * surface.y, 0.0) * (1.0 - standing * STANDING_CHOP_REDUCTION)
	var hx := d.x * chop * HORIZONTAL_GEOMETRY
	var hz := d.z * chop * HORIZONTAL_GEOMETRY
	var k := _amplitude * surface.x / _meters_per_unit
	return Vector3((hx * axis.x - hz * axis.y) * k, d.y * k, (hx * axis.y + hz * axis.x) * k)


## Surface height above a fixed world point. Horizontal chop moves surface points,
## so the rest position whose displaced point lands on world_xz is found by a
## fixed-point iteration (Tidewater's ocean query does the same).
static func height_at(
	world_xz: Vector2,
	time: float,
	surface: Vector3 = PHYSICAL_SURFACE,
	iterations: int = HEIGHT_ITERATIONS
) -> float:
	var x0 := world_xz
	for i in iterations:
		var d := displacement_at(x0, time, surface)
		x0 = world_xz - Vector2(d.x, d.z)
	return displacement_at(x0, time, surface).y


## Height of the rendered mesh: height_at() through the shader's soft trough floor.
## Only meaningful with a geometry-scaled surface (terrain_surface()).
static func surface_height_at(
	world_xz: Vector2,
	time: float,
	surface: Vector3 = PHYSICAL_SURFACE,
	iterations: int = HEIGHT_ITERATIONS
) -> float:
	return trough_floor(height_at(world_xz, time, surface, iterations))


## _fft_trough_floor: troughs ease into a floor just above the recessed bed.
static func trough_floor(y: float) -> float:
	return -TROUGH_FLOOR * (1.0 - exp(y / TROUGH_FLOOR)) if y < 0.0 else y


## Water-mesh COLOR.r: inverse_lerp of combined coverage from the clip threshold
## to open water. Matches map_view_mesh_builder_terrain_water._add_water_vertex.
static func shore_factor_from_coverage(coverage: float) -> float:
	var threshold := MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD
	return clampf(inverse_lerp(threshold, 1.0, coverage), 0.0, 1.0)


## Shader vertex scale: fade * shoaling. WHY the CPU hull needs the same product:
## COLOR.r is a mesh vertex colour the sampler cannot see, and landing boats sit
## inside the last 1.5 units of that band.
static func shore_displacement_scale(shore_factor: float) -> float:
	var fade := smoothstep(0.0, 0.16, shore_factor)
	var shoaling := lerpf(1.32, 1.0, smoothstep(0.0, 0.65, shore_factor))
	return fade * shoaling


static func shore_scale_from_coverage(coverage: float) -> float:
	return shore_displacement_scale(shore_factor_from_coverage(coverage))


## Cheap fetch/shelter from the WS-08 signed shore field. Positive distance is
## water. A quay or headland upwind, or a tight basin, lowers the scale.
static func fetch_shelter_scale(local_distance: float, upwind_distance: float) -> float:
	var fetch := smoothstep(0.0, FETCH_OPEN_UNITS, upwind_distance)
	var basin := smoothstep(SHELTER_NEAR_UNITS, FETCH_OPEN_UNITS, local_distance)
	return lerpf(SHELTER_LEE_SCALE, 1.0, minf(fetch, basin))
