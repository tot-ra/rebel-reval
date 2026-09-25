extends "res://tests/godot/test_case.gd"

## WS-09: the offline Hillaire LUTs import as float textures whose texels match
## the Python bake, and the GLSL include carries the same constants.

const PROFILE_PATH := "res://assets/sky/atmosphere/atmosphere_profile.json"
const TRANSMITTANCE_PATH := "res://assets/sky/atmosphere/transmittance.exr"
const MULTISCATTER_PATH := "res://assets/sky/atmosphere/multiscatter.exr"
const INCLUDE_PATH := "res://scripts/map/view3d/atmosphere_common.gdshaderinc"
const FLOAT_FORMATS := [
	Image.FORMAT_RGBH, Image.FORMAT_RGBAH, Image.FORMAT_RGBF, Image.FORMAT_RGBAF,
]


func _profile() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	return parsed if parsed is Dictionary else {}


func _image(path: String) -> Image:
	var texture := load(path) as Texture2D
	assert_true(texture != null, "%s must import as Texture2D" % path)
	if texture == null:
		return null
	var image := texture.get_image()
	assert_true(image != null, "%s must expose its image" % path)
	return image


func _assert_texel(
	image: Image, texel: Array, expected: Array, tolerance: float, label: String
) -> void:
	var pixel := image.get_pixel(int(texel[0]), int(texel[1]))
	for channel in 3:
		var message := "%s channel %d" % [label, channel]
		assert_almost_eq(pixel[channel], float(expected[channel]), tolerance, message)


func test_luts_import_as_uncompressed_float_textures() -> void:
	var profile := _profile()
	assert_false(profile.is_empty(), "atmosphere profile JSON must parse")
	var expected := {
		TRANSMITTANCE_PATH: profile["luts"]["transmittance"],
		MULTISCATTER_PATH: profile["luts"]["multiscatter"],
	}
	for path: String in expected:
		var image := _image(path)
		if image == null:
			continue
		var lut: Dictionary = expected[path]
		assert_eq(image.get_width(), int(lut["width"]), "%s width" % path)
		assert_eq(image.get_height(), int(lut["height"]), "%s height" % path)
		# Lossless import of an EXR must keep half floats; 8-bit would crush the multi-scatter LUT.
		assert_array_contains(FLOAT_FORMATS, image.get_format(), "%s must stay a float format" % path)
		assert_false(image.is_compressed(), "%s must not be VRAM-compressed" % path)
		assert_false(image.has_mipmaps(), "%s imports without mipmaps" % path)


func test_zenith_ground_texel_matches_python_oracle() -> void:
	var oracles: Dictionary = _profile()["oracles"]
	var transmittance := _image(TRANSMITTANCE_PATH)
	if transmittance == null:
		return
	var texel: Array = oracles["zenith_ground_transmittance_texel"]
	# Proves the EXR writer, the Godot import and the (r, mu) parameterisation agree.
	var analytic: Array = oracles["zenith_ground_transmittance_analytic"]
	var baked: Array = oracles["zenith_ground_transmittance_baked"]
	_assert_texel(transmittance, texel, analytic, 0.01, "zenith T vs analytic")
	_assert_texel(transmittance, texel, baked, 1e-4, "zenith T vs bake")


func test_multiscatter_texel_matches_bake() -> void:
	var oracles: Dictionary = _profile()["oracles"]
	var multiscatter := _image(MULTISCATTER_PATH)
	if multiscatter == null:
		return
	_assert_texel(
		multiscatter,
		oracles["ground_zenith_sun_multiscatter_texel"],
		oracles["ground_zenith_sun_multiscatter_baked"],
		1e-5,
		"ground Psi_ms with the sun at zenith",
	)


func test_include_constants_match_bake_profile() -> void:
	var include := load(INCLUDE_PATH) as ShaderInclude
	assert_true(include != null, "atmosphere_common.gdshaderinc must load as ShaderInclude")
	if include == null:
		return
	var code := include.code
	var constants: Dictionary = _profile()["constants"]
	var scalars := {
		"ATMO_RG": constants["r_ground_km"],
		"ATMO_RT": constants["r_top_km"],
		"ATMO_RAYLEIGH_SCALE_HEIGHT": constants["rayleigh_scale_height_km"],
		"ATMO_MIE_SCATTERING": constants["mie_scattering_per_km"],
		"ATMO_MIE_EXTINCTION": constants["mie_extinction_per_km"],
		"ATMO_MIE_SCALE_HEIGHT": constants["mie_scale_height_km"],
		"ATMO_MIE_G": constants["mie_g"],
		"ATMO_OZONE_CENTER": constants["ozone_center_km"],
		"ATMO_OZONE_HALF_WIDTH": constants["ozone_half_width_km"],
	}
	for name: String in scalars:
		var value := _const_value(code, "float", name)
		assert_true(value.size() == 1, "include declares const float %s" % name)
		if value.size() == 1:
			assert_almost_eq(value[0], float(scalars[name]), 1e-9, name)
	var vectors := {
		"ATMO_RAYLEIGH_SCATTERING": constants["rayleigh_scattering_per_km"],
		"ATMO_OZONE_ABSORPTION": constants["ozone_absorption_per_km"],
		"ATMO_GROUND_ALBEDO": constants["ground_albedo"],
	}
	for name: String in vectors:
		var value := _const_value(code, "vec3", name)
		assert_eq(value.size(), 3, "include declares const vec3 %s" % name)
		for channel in mini(value.size(), 3):
			assert_almost_eq(value[channel], float(vectors[name][channel]), 1e-9, "%s[%d]" % [name, channel])
	for function_name in [
		"atmosphere_medium(", "ray_sphere(", "transmittance_uv(", "transmittance_r_mu(",
		"multiscatter_uv(", "rayleigh_phase(", "mie_phase_cornette_shanks(",
	]:
		assert_true(code.contains(function_name), "include defines %s" % function_name)


func _const_value(code: String, type_name: String, name: String) -> PackedFloat64Array:
	var regex := RegEx.new()
	regex.compile("const %s %s = ([^;]+);" % [type_name, name])
	var found := regex.search(code)
	var values := PackedFloat64Array()
	if found == null:
		return values
	var literal := found.get_string(1).trim_prefix("vec3(").trim_suffix(")")
	for part in literal.split(","):
		values.append(part.strip_edges().to_float())
	return values
