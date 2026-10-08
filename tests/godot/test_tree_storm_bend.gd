extends "res://tests/godot/test_case.gd"

## R-1433: calibrated against the real coarse gust at storm strength 0.70,
## not an unreachable hand-picked pressure. Constants are read from the shader.
const WIND := "res://scripts/map/view3d/tree_wind.gdshaderinc"


func test_species_bark_and_all_crown_lods_share_bend_parameters() -> void:
	for species: StringName in [&"pine", &"spruce", &"birch", &"oak"]:
		var bark := MapViewMaterials.bark_plate_wind(
			MapViewTreeSpecies.bark_plate_for(species), species
		)
		var crown := MapViewMaterials.canopy_for_species(species)
		for key in ["tree_top", "slender"]:
			assert_eq(bark.get_shader_parameter(key), crown.get_shader_parameter(key))
		assert_true(float(crown.get_shader_parameter("tree_top")) > 0.5)
	var pine := MapViewMaterials.canopy_for_species(&"pine")
	var oak := MapViewMaterials.canopy_for_species(&"oak")
	assert_true(
		float(pine.get_shader_parameter("slender")) > float(oak.get_shader_parameter("slender"))
	)
	assert_true(MapViewMaterialShaders.CANOPY_SHADER.code.contains("tree_top, slender, strength"))


func test_real_storm_pine_reaches_twenty_to_thirty_degrees_and_sways_sideways() -> void:
	var peak := 0.0
	var min_side := 0.0
	var max_side := 0.0
	for i in 3600:
		var tilt := _tilt(0.70, float(i) / 60.0)
		peak = maxf(peak, tilt.length())
		min_side = minf(min_side, tilt.y)
		max_side = maxf(max_side, tilt.y)
	assert_true(rad_to_deg(peak) >= 20.0, "storm peak %.2f degrees" % rad_to_deg(peak))
	assert_true(rad_to_deg(peak) <= 30.01, "storm bend is bounded")
	assert_true(min_side < -0.1 and max_side > 0.1, "sway crosses both sides of wind")
	var calm_peak := 0.0
	for i in 600:
		calm_peak = maxf(calm_peak, _tilt(0.04, float(i) / 10.0).length())
	assert_true(rad_to_deg(calm_peak) < 1.0, "calm does not thrash")
	assert_eq(_tilt(0.0, 9.0), Vector2.ZERO, "no wind means no bend")


func test_arc_has_fixed_root_curved_bole_and_preserved_length() -> void:
	var lean := _constant("TREE_MAX_LEAN")
	assert_eq(_arc(0.0, lean), Vector2.ZERO)
	var mid := _arc(0.5, lean)
	var top := _arc(1.0, lean)
	assert_true(mid.x < top.x * 0.4, "curvature, not a rigid pivot")
	assert_true(top.y < 1.0 and top.y > 0.8, "crown drops while bending")
	assert_true(rad_to_deg(atan2(top.x, top.y)) > 29.0)
	var length_sum := 0.0
	var previous := Vector2.ZERO
	for i in range(1, 101):
		var point := _arc(float(i) / 100.0, lean)
		length_sum += previous.distance_to(point)
		previous = point
	assert_almost_eq(length_sum, 1.0, 0.0001, "centreline does not stretch")


func _constant(key: String) -> float:
	var regex := RegEx.new()
	regex.compile("const float " + key + " = ([0-9.]+)")
	var result := regex.search(FileAccess.get_file_as_string(WIND))
	assert_true(result != null, "shader constant " + key)
	return float(result.get_string(1)) if result != null else 0.0


func _tilt(strength: float, t: float) -> Vector2:
	var params := WindField.params_for(Vector2.RIGHT, strength)
	var push := 0.48 + params.gust_amplitude * 2.0 * WindField.gust_coarse(Vector2.ZERO, t, params)
	var q := pow(strength * push, 1.4)
	q /= 1.0 + q / _constant("TREE_Q_MAX")
	var veer := params.turbulence * (0.5 * sin(t * 0.37) + 0.25 * sin(t * 0.91))
	var wind := Vector2(cos(veer), sin(veer))
	var across := Vector2(-wind.y, wind.x)
	var ring := t * 3.1 * 9.0 / 18.0
	var tilt := _constant("TREE_TRUNK_BEND") * 1.5 * q * (
		wind * (1.0 + 0.45 * minf(q, 1.5) * sin(ring))
		+ across * 0.5 * minf(q, 1.5) * sin(ring * 0.73)
	)
	return tilt.limit_length(_constant("TREE_MAX_LEAN"))


func _arc(h: float, lean: float) -> Vector2:
	var arc := Vector2.ZERO
	var nodes := [0.112701665, 0.5, 0.887298335]
	var weights := [0.277777778, 0.444444444, 0.277777778]
	for i in 3:
		var u: float = h * nodes[i]
		var angle := lean * (3.0 * u - 1.5 * u * u)
		arc += h * float(weights[i]) * Vector2(sin(angle), cos(angle))
	return arc
