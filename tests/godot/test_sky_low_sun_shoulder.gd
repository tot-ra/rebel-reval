extends "res://tests/godot/test_case.gd"

## A sun 10-16 degrees up must not blow a white dome over the horizon below it. The
## sky-view LUT's sun-side horizon grows ~2.2x from noon to 16 degrees and the dome's
## zenith-keyed adaptation and the low-sun exposure lift multiply it again, so the
## exposed LUT background goes through sky_highlight_shoulder() in the dome and in the
## water's sky reflection. The pixel check needs a GPU capture (tools/probe_hdr_output.gd
## --sun-map=smithy_courtyard --sun-progress=0.73), so this guards the contract and curve.

const COMMON_PATH := "res://scripts/map/view3d/atmosphere_common.gdshaderinc"
const SKY_SHADER_PATH := "res://scripts/map/view3d/sky_weather_3d.gdshader"
const WATER_SHADER_PATH := "res://scripts/map/view3d/map_view_water.gdshader"
## Exposed (art x adaptation) LUT luminance measured on the Mobile renderer: the brightest
## noon sky (sun 45 degrees) and the sun-side horizon at 16 and 7 degrees.
const NOON_SKY := 0.76
const HORIZON_16_DEG := 2.30
const HORIZON_7_DEG := 4.23


func test_dome_and_water_shoulder_the_exposed_lut() -> void:
	var sky := FileAccess.get_file_as_string(SKY_SHADER_PATH)
	assert_true(sky.contains("color = sky_highlight_shoulder(sky_lut_radiance(dir) * art)"),
		"the dome background must pass through the highlight shoulder")
	var water := FileAccess.get_file_as_string(WATER_SHADER_PATH)
	assert_true(water.contains("sky_highlight_shoulder(_sky_lut_radiance(dir) * art)"),
		"the water reflection must shoulder its sky like the dome")
	assert_true(water.contains("lut_horizon = sky_highlight_shoulder("),
		"the water's horizon colour must be shouldered too")


func test_shoulder_keeps_noon_and_caps_the_low_sun_horizon() -> void:
	var code := FileAccess.get_file_as_string(COMMON_PATH)
	var knee := _constant(code, "SKY_HIGHLIGHT_KNEE")
	var cap := _constant(code, "SKY_HIGHLIGHT_CAP")
	assert_true(knee > 0.0 and cap > knee, "knee and cap must be shader constants, cap > knee")
	if not (knee > 0.0 and cap > knee):
		return
	var noon := _shoulder(NOON_SKY, knee, cap)
	assert_true(noon >= NOON_SKY * 0.97, "noon sky must stay within 3%%, got %.3f" % noon)
	var low := _shoulder(HORIZON_16_DEG, knee, cap)
	var lower := _shoulder(HORIZON_7_DEG, knee, cap)
	assert_true(low < cap and lower < cap, "a low sun's horizon must stay under the cap")
	assert_true(low <= HORIZON_16_DEG * 0.45,
		"the 16 degree horizon must lose more than half, got %.3f" % low)
	assert_true(lower > low and low > noon, "the shoulder must stay monotonic")


## GDScript mirror of sky_highlight_shoulder() for luminance.
func _shoulder(value: float, knee: float, cap: float) -> float:
	if value <= knee:
		return value
	var excess := value - knee
	return knee + excess / (1.0 + excess / (cap - knee))


func _constant(code: String, constant_name: String) -> float:
	var found := RegEx.create_from_string(
		"const float %s = ([0-9.]+);" % constant_name).search(code)
	return float(found.get_string(1)) if found != null else -1.0
