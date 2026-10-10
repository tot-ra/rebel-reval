extends "res://tests/godot/test_case.gd"

## R-1607: a low sun must not paint a vertical pillar up to the zenith. The sky reuses
## one horizon colour per azimuth for the whole column (ambient, overcast tint, cloud
## haze); sampled at the sun's azimuth it carried the sharp Mie aureole. The pixel check
## needs a GPU capture, so this guards the shader contract.

const SKY_SHADER_PATH := "res://scripts/map/view3d/sky_weather_3d.gdshader"


func test_horizon_colour_skips_the_sun_aureole() -> void:
	var code := FileAccess.get_file_as_string(SKY_SHADER_PATH)
	assert_true(
		code.contains("vec3 lut_horizon = sky_lut_horizon_radiance(dir) * art;"),
		"the column horizon colour must come from the aureole-free horizon lookup"
	)
	var regex := RegEx.create_from_string("const float HORIZON_AZIMUTH_FLOOR = ([0-9.]+);")
	var found := regex.search(code)
	assert_true(found != null, "HORIZON_AZIMUTH_FLOOR must stay a shader constant")
	if found == null:
		return
	# The LUT azimuth coordinate is sin(angle / 2); the floor keeps the lookup at least
	# ~20 degrees from the sun, where the Mie forward peak has fallen about tenfold.
	var min_angle := rad_to_deg(2.0 * asin(float(found.get_string(1))))
	assert_true(min_angle >= 20.0 and min_angle <= 40.0,
		"horizon lookup must stay 20-40 degrees off the sun azimuth, got %.1f" % min_angle)
