extends "res://tests/godot/test_case.gd"

## WR-0..WR-2 (R-1498..R-1500, docs/SYSTEMS/CITY_SEA.md "Water realism v2"):
## the sandbox builds the runtime city water on a synthetic coast; the city sea
## keeps real troughs and band-limited geometry; its foam is attached to the water.

const WATER_SHADER := "res://scripts/map/view3d/map_view_water.gdshader"
const FFT_INCLUDE := "res://scripts/map/view3d/ocean_fft_common.gdshaderinc"
const SANDBOX := "res://tools/water_sandbox/water_sandbox.gd"


func test_bed_trough_keeps_deep_troughs_and_eases_into_a_shallow_bed() -> void:
	# Deep water: the trough is untouched (the old floor clamped it to -1.5 mm).
	assert_almost_eq(OceanFftSampler.bed_trough(-0.6, 5.0), -0.6, 0.0001, "deep trough kept")
	assert_almost_eq(OceanFftSampler.bed_trough(0.4, 5.0), 0.4, 0.0001, "crest kept")
	# 20 cm of room: the trough stops at the bed instead of cutting through it.
	var shallow := OceanFftSampler.bed_trough(-0.6, 0.2)
	assert_true(shallow >= -0.2 and shallow < -0.15, "shallow trough eases onto the bed: %f" % shallow)
	# Continuous across the soft band (no kink at the floor).
	var a := OceanFftSampler.bed_trough(-0.2 - 0.001, 0.2)
	var b := OceanFftSampler.bed_trough(-0.2 + 0.001, 0.2)
	assert_true(absf(a - b) < 0.005, "smooth at the floor")


func test_c1_geometry_weight_only_removes_cascade_one() -> void:
	if not OceanFftSampler.ensure_loaded():
		skip("FFT atlases unavailable")
		return
	var p := Vector2(37.0, -11.0)
	var full := OceanFftSampler.displacement_at(p, 3.0)
	var same := OceanFftSampler.displacement_at(p, 3.0, OceanFftSampler.PHYSICAL_SURFACE, 1.0)
	assert_eq(full, same, "default weight keeps the district displacement")
	var no_c1 := OceanFftSampler.displacement_at(p, 3.0, OceanFftSampler.PHYSICAL_SURFACE, 0.0)
	assert_ne(full, no_c1, "C1 contributes to the full displacement")


func test_city_shader_band_limits_geometry_and_floors_troughs_on_the_bed() -> void:
	var shader := FileAccess.get_file_as_string(WATER_SHADER)
	var include := FileAccess.get_file_as_string(FFT_INCLUDE)
	assert_true(include.contains("vec3 _fft_displacement_at_c1("), "C1-weighted displacement")
	assert_true(include.contains("float _fft_bed_trough("), "bed-relative trough")
	assert_true(
		shader.contains("sea_physical_depth ? CITY_C1_GEOMETRY : 1.0"),
		"only the city sea drops C1 from geometry"
	)
	assert_true(shader.contains("_fft_bed_trough(displacement.y, room)"), "city troughs use the bed")


func test_city_foam_is_lagrangian_and_dissolves_with_age() -> void:
	var shader := FileAccess.get_file_as_string(WATER_SHADER)
	var start := shader.find("vec2 _city_foam_cells(")
	assert_true(start >= 0, "city foam cells exist")
	var body := shader.substr(start, shader.find("\n}\n", start) - start)
	# The old pattern scrolled with the ocean clock; foam must ride the water.
	assert_false(body.contains("ocean_time") or body.contains("TIME"), "no clock-driven drift")
	assert_true(shader.contains("float _foam_dissolve("), "age dissolve")
	assert_true(shader.contains("shore_now.surge"), "surf foam follows the swash excursion")
	assert_true(shader.contains("shore_now.foam_age"), "surf foam coverage follows bore age")


func test_crest_shape_resets_for_district_maps() -> void:
	var material := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	MapViewMaterials.apply_shore_field(null, Vector2.ZERO, Vector2.ONE)
	MapViewMaterials.apply_surf_gain(2.0, 1.8, 1.3, 3.0, 2.2, 1.0)
	var shape := float(material.get_shader_parameter("shore_crest_shape"))
	assert_almost_eq(shape, 1.0, 0.0001, "city rounds")
	MapViewMaterials.apply_shore_field(null, Vector2.ZERO, Vector2.ONE)
	assert_almost_eq(
		float(material.get_shader_parameter("shore_crest_shape")), 0.0, 0.0001, "district profile"
	)


func test_sandbox_builds_every_bay_with_sea_land_and_obstacles() -> void:
	var builder: Script = load(SANDBOX)
	var sandbox: Node3D = builder.create()

	var plan: CityPlan = sandbox.plan
	assert_eq(sandbox.case_ids().size(), 6, "six bays")
	for id: String in sandbox.case_ids():
		var x: float = sandbox.bay_centres[id]
		assert_true(plan.ground_height(Vector2(x, -80.0)) < -1.0, "%s: sea offshore" % id)
		assert_true(plan.ground_height(Vector2(x, 40.0)) > 0.3, "%s: land inshore" % id)
		assert_true(sandbox.shots_for(id).has("close"), "%s: camera poses" % id)
	var stamped := 0
	for rock: Dictionary in sandbox.rocks["boulders"]:
		if rock["stamped"]:
			stamped += 1
			var at: Vector3 = rock["at"]
			assert_true(
				plan.ground_height(Vector2(at.x, at.z)) > at.y,
				"large boulders reshape the ground for the shore field"
			)
	assert_true(stamped > 0, "the boulder bay has obstacle-sized rocks")
	assert_true(sandbox.world.sea_shore.has("contour"), "runtime shore field baked on the sandbox")
	assert_true(sandbox.world.get_node_or_null("Water/Sea") != null, "runtime sea mesh built")
	sandbox.free()
