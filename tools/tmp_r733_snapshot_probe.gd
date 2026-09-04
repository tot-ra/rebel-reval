extends SceneTree

const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const SkyWeatherState := preload("res://scripts/map/view3d/sky_weather_state.gd")


func _init() -> void:
	var source := SkyWeather.new()
	source.auto_weather = false
	source.set_weather(SkyWeather.WEATHER_RAIN)
	source.advance(SkyWeather.TRANSITION_SECONDS * 0.4)
	var expected = source.snapshot_state(0.75, 3)
	var encoded := JSON.stringify(expected.to_dict())
	var decoded: Variant = JSON.parse_string(encoded)
	var restored := SkyWeatherState.from_dict(decoded as Dictionary)
	var target := SkyWeather.new()
	print("APPLY=", target.apply_state(restored))
	var expected_dict: Dictionary = expected.to_dict()
	var actual_dict: Dictionary = target.snapshot_state(0.75, 3).to_dict()
	for key in expected_dict:
		if expected_dict[key] != actual_dict.get(key):
			print("DIFF ", key, " expected=", expected_dict[key], " actual=", actual_dict.get(key))
			if key == "current_profile":
				for profile_key in expected_dict[key]:
					print(
						"PROFILE_KEY ",
						profile_key,
						" type=",
						typeof(profile_key),
						" expected=",
						expected_dict[key][profile_key],
						" actual=",
						actual_dict[key].get(profile_key)
					)
			else:
				print("TYPES ", typeof(expected_dict[key]), " / ", typeof(actual_dict.get(key)))
				if expected_dict[key] is float and actual_dict.get(key) is float:
					print("FLOAT_DIFF ", float(expected_dict[key]) - float(actual_dict.get(key)))
	quit()
