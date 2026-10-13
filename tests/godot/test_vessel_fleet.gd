extends "res://tests/godot/test_case.gd"

## CO-06 (R-953): the working-craft fleet replaces the primitive boat builders.


func test_every_design_builds_with_its_named_sub_nodes() -> void:
	for design: StringName in VesselFleet.designs():
		var variant := VesselFleet.variant_for(design, 1343, "test.%s" % design)
		var vessel := VesselFleet.build(variant)
		var wanted := VesselFleet.RIG_NODES if VesselFleet.is_rigged(design) else VesselFleet.ROW_NODES
		for node_name: String in wanted:
			assert_true(
				vessel.find_child(node_name, true, false) != null,
				"%s exposes %s for CO-07" % [design, node_name]
			)
		var oars := 0
		for child in vessel.get_children():
			if child.name.begins_with("Oar"):
				oars += 1
		assert_eq(oars, int(VesselFleet.spec(design)["oars"]), "%s oar count" % design)
		vessel.free()


func test_hulls_follow_their_co05_card_dimensions() -> void:
	for design: StringName in VesselFleet.designs():
		var s := VesselFleet.spec(design)
		var size := VesselFleet.hull_mesh(design, VesselFleet.WEAR_WEATHERED).get_aabb().size
		# Stem and sternpost heads stand a little proud of the planking.
		assert_almost_eq(size.x, float(s["length"]), 0.5, "%s length over the stems" % design)
		assert_almost_eq(size.z, float(s["beam"]), 0.2, "%s beam at the sheer" % design)
	var small := VesselFleet.spec(VesselFleet.FISHING_SMALL)
	var rowing := VesselFleet.spec(VesselFleet.ROWING_OPEN)
	var large := VesselFleet.spec(VesselFleet.FISHING_LARGE)
	assert_true(float(small["length"]) >= 5.0 and float(small["length"]) <= 7.0, "V2 stays 5-7 m")
	assert_true(float(rowing["length"]) >= 6.0 and float(rowing["length"]) <= 8.0, "V4 stays 6-8 m")
	assert_true(float(large["length"]) <= 12.5, "Gedesby is the V3 ceiling, not the target")
	assert_true(
		float(rowing["beam"]) / float(rowing["length"])
		< float(large["beam"]) / float(large["length"]),
		"V4 reads slimmer than V3"
	)
	assert_false(VesselFleet.is_rigged(VesselFleet.ROWING_OPEN), "the ferry boat is rowed")


func test_sails_are_segmented_for_billow() -> void:
	for design: StringName in VesselFleet.designs():
		if not VesselFleet.is_rigged(design):
			continue
		var mesh := VesselFleet.sail_mesh(design)
		var vertices := mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		assert_eq(vertices.size(), VesselFleet.SAIL_COLS * VesselFleet.SAIL_ROWS * 6, design)
		assert_true(
			VesselFleet.SAIL_COLS >= 8 and VesselFleet.SAIL_ROWS >= 6, "sail grid is at least 8x6"
		)
		var vessel := VesselFleet.build(VesselFleet.variant_for(design, 1, "sail"))
		var sail := vessel.get_node("Mast/Yard/Sail") as MeshInstance3D
		assert_true(sail.material_override is ShaderMaterial, "%s sail fills from the wind" % design)
		assert_false(sail.visible, "a moored or beached boat has its sail furled")
		VesselFleet.set_sail(vessel, true)
		assert_true(sail.visible, "set_sail shows the cloth")
		assert_false((vessel.get_node("Mast/Yard/FurledSail") as Node3D).visible)
		vessel.free()


func test_variant_selection_is_deterministic_and_varied() -> void:
	var a := VesselFleet.variant_for(VesselFleet.FISHING_SMALL, 1343, "boat.kalamaja.0")
	var b := VesselFleet.variant_for(VesselFleet.FISHING_SMALL, 1343, "boat.kalamaja.0")
	assert_eq(VesselFleet.appearance_key(a), VesselFleet.appearance_key(b), "same seed and id")
	assert_eq(
		VesselFleet.fishing_design_for(1343, "boat.kalamaja.4"),
		VesselFleet.fishing_design_for(1343, "boat.kalamaja.4")
	)
	# Pinned values: a change here reshuffles every shipped shore.
	assert_eq(VesselFleet.stable_hash("1343:boat.kalamaja.0"), 1324323961, "stable hash pinned")


func test_six_kalamaja_fishing_boats_look_different() -> void:
	var plan := CityPlan.load_default()
	var ids: Array[String] = []
	for boat: Dictionary in plan.data["harbour"]["boats"]:
		if String(boat["type"]) == "clinker":
			ids.append(String(boat["id"]))
	assert_eq(ids.size(), 6, "six working boats on the Kalamaja sand")
	var looks := {}
	for id in ids:
		var design := VesselFleet.fishing_design_for(CityShips.FLEET_SEED, id)
		looks[VesselFleet.appearance_key(VesselFleet.variant_for(design, CityShips.FLEET_SEED, id))] = id
	assert_true(looks.size() >= 3, "at least three distinct hulls among six, got %d" % looks.size())


func test_beached_hulls_do_not_bob_and_afloat_hulls_sit_at_draught() -> void:
	var plan := CityPlan.load_default()
	var ships := CityShips.create(plan)
	var root := Node3D.new()
	Engine.get_main_loop().root.add_child(root)
	root.add_child(ships)
	var beached := 0
	var afloat := 0
	for h: Dictionary in ships._hulls:
		if bool(h["cog"]) or StringName(h["design"]).is_empty():
			continue
		var hull := (h["node"] as Node3D).get_child(0) as Node3D
		if float(h["lift"]) > 0.0:
			beached += 1
			assert_almost_eq(hull.position.y, 0.0, 1e-5, "beached keel rests on the sand")
		else:
			afloat += 1
			assert_almost_eq(
				hull.position.y, -VesselFleet.draught(h["design"]), 1e-5, "afloat keel at draught"
			)
	# The first tick places every hull; after it a beached hull must stay put.
	ships._process_timed(0.1)
	var before: Array[float] = []
	for h: Dictionary in ships._hulls:
		before.append((h["node"] as Node3D).position.y)
	ships._process_timed(0.7)
	ships._process_timed(0.9)
	for i in ships._hulls.size():
		var h: Dictionary = ships._hulls[i]
		if float(h["lift"]) > 0.0:
			assert_almost_eq(
				(h["node"] as Node3D).position.y, before[i], 1e-5, "%s must not float" % h["id"]
			)
	assert_true(beached >= 6, "Kalamaja boats are hauled up, got %d" % beached)
	assert_true(afloat >= 5, "landing boats and lighters float, got %d" % afloat)
	root.queue_free()
	plan.dynamic_deck = Callable()


func test_cogs_ship_two_wear_variants() -> void:
	var weathered := CogModel.build(FactionHeraldry.HANSEATIC, false, true, 0)
	var tarred := CogModel.build(FactionHeraldry.HANSEATIC, false, true, 1)
	var m0 := (weathered.get_node("Hull") as MeshInstance3D).material_override
	var m1 := (tarred.get_node("Hull") as MeshInstance3D).material_override
	assert_ne(m0, m1, "the tarred cog uses its own hull material")
	weathered.free()
	tarred.free()


func test_map_boat_props_use_the_fleet() -> void:
	var definition := MapDefinition.new()
	var fishing := MapViewMeshBuilder.build_prop(
		{"id": &"kalamaja_a", "kind": MapTypes.PROP_KIND_FISHING_BOAT, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE,
		definition
	)
	var vessel := fishing.get_node("Vessel") as Node3D
	assert_true(vessel.has_meta(&"design"), "fishing props build a VesselFleet hull")
	assert_true(vessel.has_node("Hull"))
	var merchant := MapViewMeshBuilder.build_prop(
		{"id": &"roads_a", "kind": MapTypes.PROP_KIND_MERCHANT_BOAT, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE,
		definition
	)
	assert_true(merchant.get_node("Vessel").has_node("RudderPivot/Rudder"), "merchant props are cogs")
	assert_true(merchant.find_child("MastheadPennant", true, false) != null, "Hanseatic pennant kept")
	fishing.free()
	merchant.free()


func test_no_reference_to_the_deleted_builders_remains() -> void:
	var banned: Array[String] = [
		"MapViewFishingBoatBuilder", "MapViewMerchantBoatBuilder", "CityBoats",
		"map_view_fishing_boat_builder", "map_view_merchant_boat_builder", "city_boats.gd",
	]
	var hits: Array[String] = []
	_scan("res://scripts", banned, hits)
	assert_eq(hits, [] as Array[String], "deleted builders still referenced")


func _scan(dir_path: String, banned: Array[String], hits: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan(dir_path.path_join(sub), banned, hits)
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string(dir_path.path_join(file))
		for word in banned:
			if text.contains(word):
				hits.append("%s: %s" % [file, word])


func test_boats_of_a_design_share_fitting_meshes() -> void:
	var a := VesselFleet.build(VesselFleet.variant_for(VesselFleet.FISHING_SMALL, 1, "share.a"))
	var b := VesselFleet.build(VesselFleet.variant_for(VesselFleet.FISHING_SMALL, 1, "share.b"))
	for path: String in ["Oar0/Shaft", "Sheet", "Shroud0", "Mast/Spar", "Rudder/Blade"]:
		assert_true(
			(a.get_node(path) as MeshInstance3D).mesh == (b.get_node(path) as MeshInstance3D).mesh,
			"%s mesh is shared, not rebuilt per boat" % path
		)
	a.free()
	b.free()
