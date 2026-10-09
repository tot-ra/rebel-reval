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


# WR-4 (R-1509): waves feel the seabed.

const Surface := preload("res://scripts/city/city_water_surface.gd")
const ShoreField := preload("res://scripts/city/city_shore_field.gd")
const SWASH := "res://scripts/map/view3d/shore_swash.gdshaderinc"


func _sandbox() -> Node3D:
	return (load(SANDBOX) as Script).create()


func _bed_material(sea_state: float) -> ShaderMaterial:
	var material := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	material.set_shader_parameter("shore_sea_state", sea_state)
	return material


## Straight beach whose depth contours run at 30 degrees to the grid.
func _oblique_plan() -> CityPlan:
	var plan := CityPlan.new()
	plan._nx = 121
	plan._ny = 121
	plan._cell = 2.0
	plan._origin = Vector2(-120.0, -200.0)
	plan.bounds = Rect2(plan._origin, Vector2(240.0, 240.0))
	var normal := Vector2(sin(deg_to_rad(30.0)), cos(deg_to_rad(30.0)))
	for j in plan._ny:
		for i in plan._nx:
			var p := plan._origin + Vector2(i, j) * plan._cell
			plan._heights.append(maxf(p.dot(normal) * 0.04, -6.0))
	return plan


func test_bed_bake_slows_trains_and_turns_crests_to_the_contours() -> void:
	var plan := _oblique_plan()
	var shore := ShoreField.bake(plan)
	assert_true(shore.has("bed_texture") and shore.has("bed_samples"), "bathymetry atlas baked")
	var atlas: Texture2D = shore["bed_texture"]
	assert_eq(atlas.get_width(), plan.height_grid_size().x * 2, "field and bed side by side")
	var normal := Vector2(sin(deg_to_rad(30.0)), cos(deg_to_rad(30.0)))
	var cell := plan.height_cell()
	var previous_pace := 0.0
	for d: float in [60.0, 40.0, 20.0, 8.0]:
		# Point d world units seaward of the waterline, off-centre along the shore.
		var p := Vector2(-20.0, 0.0) - normal * d + normal.orthogonal() * 10.0
		var bed := Surface.bed_at(shore, p)
		assert_true(bed.y > 0.0, "inside the wave zone at %d m" % int(d))
		var grad := Vector2(
			Surface.bed_at(shore, p + Vector2(cell, 0)).y - Surface.bed_at(shore, p - Vector2(cell, 0)).y,
			Surface.bed_at(shore, p + Vector2(0, cell)).y - Surface.bed_at(shore, p - Vector2(0, cell)).y
		) / (2.0 * cell)
		# Refraction: crests (equal travel time) run parallel to the depth contours.
		assert_true(
			absf(rad_to_deg(grad.angle_to(normal))) < 4.0,
			"crest normal follows the bed at %d m: %.1f deg" % [int(d), rad_to_deg(grad.angle_to(normal))]
		)
		# Shoaling: the train slows (time per metre rises) as the water shallows.
		var pace := grad.length()
		assert_true(pace > previous_pace, "slower in shallower water at %d m" % int(d))
		assert_almost_eq(pace, 1.0 / ShoreField.bed_celerity(bed.x), 0.12 / ShoreField.bed_celerity(bed.x))
		previous_pace = pace


func test_bar_and_reef_break_then_reform_and_break_again() -> void:
	var sandbox := _sandbox()
	var shore: Dictionary = sandbox.world.sea_shore
	var material := _bed_material(0.95)
	for id: String in ["sand", "reef"]:
		var cx: float = sandbox.bay_centres[id]
		var bar_z := -48.0 if id == "sand" else -34.0
		var lagoon_z := -38.0 if id == "sand" else -30.0
		var at_bar := Surface.bed_state(shore, Vector2(cx + 7.0, bar_z), 2.0, material)
		var behind := Surface.bed_state(shore, Vector2(cx + 7.0, lagoon_z), 2.0, material)
		var inshore := Surface.bed_state(shore, Vector2(cx + 7.0, -8.0), 2.0, material)
		assert_true(float(at_bar["breaking"]) > 0.9, "%s: breaks on the bar / reef" % id)
		assert_true(float(behind["breaking"]) < 0.2, "%s: unbroken in the trough behind it" % id)
		assert_true(float(behind["reformed"]) > 0.8, "%s: the wave re-forms" % id)
		assert_true(float(inshore["breaking"]) > 0.9, "%s: breaks again near the shore" % id)
		var control := Surface.bed_at(shore, Vector2(cx + 7.0, lagoon_z))
		assert_true(control.w < control.x - 0.05, "%s: controlling depth carries the bar" % id)
	sandbox.free()


func test_breaker_class_follows_the_iribarren_number() -> void:
	var sandbox := _sandbox()
	var shore: Dictionary = sandbox.world.sea_shore
	for wind: float in [0.55, 0.95]:
		var material := _bed_material(wind)
		var classes := {}
		for id: String in ["sand", "shingle", "quay"]:
			var cx: float = sandbox.bay_centres[id]
			classes[id] = Surface.bed_state(shore, Vector2(cx + 7.0, -4.0), 2.0, material)
		var sand: Dictionary = classes["sand"]
		var shingle: Dictionary = classes["shingle"]
		var quay: Dictionary = classes["quay"]
		assert_true(float(sand["plunge"]) < 0.3 and float(sand["surging"]) == 0.0,
			"wind %.2f: gentle sand spills (xi %.2f)" % [wind, sand["xi"]])
		assert_true(float(shingle["surging"]) > 0.3,
			"wind %.2f: steep shingle collapses / surges (xi %.2f)" % [wind, shingle["xi"]])
		assert_true(float(quay["surging"]) > 0.99, "wind %.2f: a quay wall reflects" % wind)
		assert_true(float(sand["xi"]) < float(shingle["xi"]) and float(shingle["xi"]) < float(quay["xi"]))
	# Calmer sea, same shingle: lower waves raise xi towards surging.
	var cx: float = sandbox.bay_centres["shingle"]
	var calm := Surface.bed_state(shore, Vector2(cx + 7.0, -4.0), 2.0, _bed_material(0.1))
	var gale := Surface.bed_state(shore, Vector2(cx + 7.0, -4.0), 2.0, _bed_material(0.95))
	assert_true(float(calm["xi"]) > float(gale["xi"]), "xi rises as the sea calms")
	sandbox.free()


func test_bed_surf_is_seamless_across_the_ocean_time_wrap() -> void:
	var sandbox := _sandbox()
	var shore: Dictionary = sandbox.world.sea_shore
	var material := _bed_material(0.75)
	for id: String in ["sand", "reef", "quay"]:
		var cx: float = sandbox.bay_centres[id]
		for z: float in [-60.0, -30.0, -10.0, -2.0]:
			var p := Vector2(cx + 3.0, z)
			for t: float in [0.0, 0.4, 5.1]:
				var a := Surface.shore_lift(p, Surface.field_at(shore, p), t, material, shore)
				var b := Surface.shore_lift(p, Surface.field_at(shore, p), t + 1638.4, material, shore)
				assert_almost_eq(a, b, 0.0005, "%s z %d t %.1f wraps seamlessly" % [id, int(z), t])
	sandbox.free()


func test_district_maps_keep_the_idealised_beach() -> void:
	var material := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	MapViewMaterials.apply_shore_field(null, Vector2.ZERO, Vector2.ONE)
	MapViewMaterials.apply_shore_bed(ImageTexture.create_from_image(
		Image.create_empty(4, 2, false, Image.FORMAT_RGBAH)
	))
	assert_almost_eq(float(material.get_shader_parameter("shore_bed_valid")), 1.0, 0.0001, "city on")
	MapViewMaterials.apply_shore_field(null, Vector2.ZERO, Vector2.ONE)
	assert_almost_eq(
		float(material.get_shader_parameter("shore_bed_valid")), 0.0, 0.0001, "district off"
	)
	assert_false(Surface.bed_enabled({"bed_samples": PackedFloat32Array()}, material))
	var swash := FileAccess.get_file_as_string(SWASH)
	assert_true(swash.contains("if (x >= 0.0 && !bed_mode)"), "district crest path untouched")
	assert_true(swash.contains("shore_atlas_uv(uv, 0.0)"), "plain uv without the atlas")
	assert_false(swash.contains("uniform sampler2D shore_bed"), "no extra sampler (GL limit 16)")
