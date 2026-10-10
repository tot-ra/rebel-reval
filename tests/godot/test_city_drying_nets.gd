extends "res://tests/godot/test_case.gd"

## R-1640: Kalamaja drying nets (MapViewDryingNet wind cloth) and the full-size
## shore fish racks beside the Kalarand huts.

const RackModels := preload("res://scripts/map/view3d/map_view_fish_drying_rack_models.gd")


func _net(id: String = "test.net", length: float = 11.0) -> MapViewDryingNet:
	var net := MapViewDryingNet.create(id, length, 2.0, 2.7)
	net.wind_override = WindField.params_for(Vector2(1.0, 0.0), 0.0)
	return net


func test_drying_net_is_a_big_draped_grey_net() -> void:
	var net := _net()
	var aabb := net.cloth_mesh().get_aabb()
	assert_true(aabb.size.x >= 10.5, "an 11 m rack carries an 11 m net: %s" % aabb)
	var top := aabb.position.y + aabb.size.y
	assert_true(top >= 2.6, "net drapes over a pole at head height and more: %s" % aabb)
	assert_true(aabb.position.y < 1.0, "the float side hangs most of the way down: %s" % aabb)
	assert_true(aabb.size.z > 0.1, "the net hangs on both sides of the pole: %s" % aabb)
	var shader := net.cloth_material().shader
	assert_true(
		shader.code.contains("ALPHA_SCISSOR_THRESHOLD"), "net mesh must show holes, not a sheet"
	)
	var c: Color = net.cloth_material().get_shader_parameter(&"twine_color")
	assert_true(
		absf(c.r - c.b) < 0.07 and absf(c.r - c.g) < 0.05,
		"weathered hemp reads grey, not brown: %s" % c
	)
	assert_true(
		c.get_luminance() > 0.35 and c.get_luminance() < 0.7, "grey twine stays mid-tone: %s" % c
	)
	for part in ["Rack/Pole", "Rack/Post0", "Rack/EndBraceW", "Floats", "Sinkers", "NetCloth"]:
		assert_true(net.has_node(part), "drying net needs %s" % part)
	net.free()


func test_pole_row_stays_pinned_and_hem_follows_the_wind() -> void:
	var net := _net()
	var grid := net.particle_grid()
	var pole := net.pole_row_index()
	var mid := grid.x / 2
	var pinned_before := net.particle_position(mid, pole)
	var hem_rest := net.particle_position(mid, 0)
	net.wind_override = WindField.params_for(Vector2(0.0, 1.0), 0.9)
	net.simulate(150, 10.0)
	assert_true(
		net.particle_position(mid, pole).is_equal_approx(pinned_before),
		"row on the pole never moves"
	)
	var hem_wind := net.particle_position(mid, 0)
	assert_true(
		hem_wind.z - hem_rest.z > 0.25,
		"a strong +z wind swings the float hem downwind: %s -> %s" % [hem_rest, hem_wind]
	)
	assert_true(hem_wind.y > hem_rest.y, "a swung net lifts its hem")
	net.wind_override = WindField.params_for(Vector2(0.0, 1.0), 0.0)
	net.simulate(240, 20.0)
	var hem_calm := net.particle_position(mid, 0)
	assert_true(
		absf(hem_calm.z - hem_rest.z) < 0.15,
		"in calm air the net falls back to hanging: %s vs %s" % [hem_calm, hem_rest]
	)
	net.free()


func test_drying_net_is_deterministic_per_id() -> void:
	var a := _net("netyard.0.net0")
	var b := _net("netyard.0.net0")
	var c := _net("netyard.1.net0")
	for net in [a, b, c]:
		(net as MapViewDryingNet).wind_override = WindField.params_for(Vector2(0.6, 0.8), 0.5)
		(net as MapViewDryingNet).simulate(60, 3.0)
	var grid := a.particle_grid()
	assert_true(
		a.particle_position(3, 0).is_equal_approx(b.particle_position(3, 0)), "same id, same pose"
	)
	assert_true(
		a.particle_position(grid.x - 2, grid.y - 1).is_equal_approx(
			b.particle_position(grid.x - 2, grid.y - 1)
		)
	)
	assert_false(
		a.particle_position(3, 0).is_equal_approx(c.particle_position(3, 0)),
		"another rack hangs its own folds"
	)
	for net in [a, b, c]:
		(net as Node).free()


func test_drying_net_sleeps_without_a_camera() -> void:
	var net := _net()
	net.wind_override = WindField.params_for(Vector2(0.0, 1.0), 1.0)
	var hem := net.particle_position(2, 0)
	for i in 10:
		net._process(0.1)
	assert_true(net.is_sleeping(), "no camera in range: the cloth must not simulate")
	assert_true(net.particle_position(2, 0).is_equal_approx(hem), "a sleeping net keeps its pose")
	net.free()


func test_shore_fish_rack_is_full_size_with_two_tiers_of_catch() -> void:
	var root := Node3D.new()
	var rack := RackModels.add_shore_rack(root, "fishrack.test.00", 3.4, &"fish_rack.herring")
	var bounds := _bounds_for(root)
	assert_true(
		bounds.size.x >= 3.4 and bounds.size.x <= 4.0, "rack spans its drying poles: %s" % bounds
	)
	assert_true(
		bounds.size.y >= 2.1 and bounds.size.y <= 2.6, "rack stands above head height: %s" % bounds
	)
	for member in [
		"RidgePole",
		"DryingPole0Front",
		"DryingPole0Back",
		"DryingPole1Front",
		"DryingPole1Back",
		"Trestle0LegFront",
		"Trestle1LegBack",
		"Trestle0CrossLashing",
		"BackBrace"
	]:
		assert_true(rack.has_node(member), "shore rack needs %s" % member)
	var catch_root := rack.get_node("DryingCatch")
	assert_true(int(catch_root.get_meta(&"fish_count")) >= 30, "a loaded rack holds dozens of fish")
	assert_true(catch_root.get_child_count() <= 3, "catch is merged into a few draw calls")
	var empty_root := Node3D.new()
	var empty := RackModels.add_shore_rack(empty_root, "fishrack.test.01", 3.4, &"fish_rack.empty")
	assert_false(empty.has_node("DryingCatch"), "empty rack has no fish")
	var mixed_root := Node3D.new()
	var mixed := RackModels.add_shore_rack(mixed_root, "fishrack.test.02", 3.6, &"fish_rack.mixed")
	assert_true(mixed.get_node("DryingCatch").has_node("Catch_cod"), "mixed rack carries cod")
	assert_true(
		mixed.get_node("DryingCatch").has_node("Catch_herring"), "mixed rack carries herring"
	)
	for node in [root, empty_root, mixed_root]:
		(node as Node).free()


func test_plan_places_kalarand_fish_racks_clear_of_huts() -> void:
	var plan := CityPlan.load_default()
	var harbour: Dictionary = plan.data.get("harbour", {})
	var racks: Array = harbour.get("fish_racks", [])
	assert_true(racks.size() >= 8, "shore-side huts get fish racks: %d" % racks.size())
	var ids := {}
	var polys: Array = []
	for b: Dictionary in plan.data["buildings"]:
		polys.append(CityPlan.points(b["footprint"]))
	for rack: Dictionary in racks:
		var id := String(rack["id"])
		assert_true(id.begins_with("fishrack.kalarand."), "stable id: %s" % id)
		assert_false(ids.has(id), "unique id: %s" % id)
		ids[id] = true
		assert_true(
			String(rack["hut"]).begins_with("bldg.kalarand."), "rack belongs to a fisher hut"
		)
		var at := Vector2(rack["at"][0], rack["at"][1])
		for poly: PackedVector2Array in polys:
			assert_false(
				Geometry2D.is_point_in_polygon(at, poly), "%s stands inside a building" % id
			)
		assert_true(plan.ground_height(at) > 0.6, "%s stands on dry ground" % id)
	for yard: Dictionary in harbour.get("net_yards", []):
		for r: Array in yard["racks"]:
			assert_true(float(r[3]) >= 9.0, "net yard racks carry long nets")


func _bounds_for(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var child_bounds := _transform_relative_to(mesh_instance, root) * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
	return bounds


func _transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent() as Node3D
	while parent != null and parent != ancestor:
		result = parent.transform * result
		parent = parent.get_parent() as Node3D
	return result
