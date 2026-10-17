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


func test_afloat_working_craft_have_dry_fitted_floorboards() -> void:
	for design: StringName in VesselFleet.designs():
		var s: Dictionary = VesselFleet.spec(design)
		var floor_y := VesselFleet.deck(design).z
		assert_true(
			floor_y >= VesselFleet.draught(design) + VesselFleet.DRY_FLOOR_CLEARANCE - 0.001,
			"%s floorboards clear the still-water plane" % design
		)
		var mesh := VesselFleet.hull_mesh(design, VesselFleet.WEAR_WEATHERED)
		var arrays := mesh.surface_get_arrays(0)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var floor_vertex_count := 0
		var floor_min_x := INF
		var floor_max_x := -INF
		for i in vertices.size():
			if absf(vertices[i].y - floor_y) > 0.001 or normals[i].y < 0.99:
				continue
			floor_vertex_count += 1
			floor_min_x = minf(floor_min_x, vertices[i].x)
			floor_max_x = maxf(floor_max_x, vertices[i].x)
		var floor_triangle_count := 0
		for i in range(0, vertices.size(), 3):
			if (
				absf(vertices[i].y - floor_y) > 0.001
				or absf(vertices[i + 1].y - floor_y) > 0.001
				or absf(vertices[i + 2].y - floor_y) > 0.001
				or normals[i].y < 0.99
				or normals[i + 1].y < 0.99
				or normals[i + 2].y < 0.99
			):
				continue
			var edge_a := vertices[i + 1] - vertices[i]
			var edge_b := vertices[i + 2] - vertices[i]
			var top_winding := edge_a.x * edge_b.z - edge_a.z * edge_b.x
			assert_true(top_winding > 0.0, "%s floor triangles face upward" % design)
			floor_triangle_count += 1
		assert_true(floor_triangle_count > 0, "%s has visible top-facing floor triangles" % design)
		assert_true(
			floor_vertex_count >= VesselFleet.FLOORBOARD_SEGMENTS * 3,
			"%s mesh contains the fitted floor surface" % design
		)
		assert_true(
			floor_min_x < -float(s["length"]) * 0.3
			and floor_max_x > float(s["length"]) * 0.3,
			"%s floorboards span most of the hull length" % design
		)
		for station: float in VesselFleet._thwart_stations(s):
			var t := 0.5 + station
			var thwart_y := VesselFleet._thwart_y(s, t, floor_y)
			var gunwale_y := VesselFleet._sheer(s, absf(t * 2.0 - 1.0))
			assert_true(
				thwart_y - 0.025 > floor_y and thwart_y + 0.025 < gunwale_y,
				"%s thwart stays between floorboards and gunwale" % design
			)
		assert_true(
			VesselFleet._floor_half_width(
				s, 0.5, floor_y - VesselFleet.FLOORBOARD_EDGE_SAMPLE_DEPTH
			)
			> float(s["beam"]) * 0.4,
			"%s floorboards cover most of the bilge at midships" % design
		)


## R-2150: looking into the boat at a strake seam must hit a front face of the
## inner skin. A lap-stepped inner skin left a slot of culled back faces there,
## and the sea showed through between the planks.
func test_strake_seams_are_closed_from_inside() -> void:
	for design: StringName in VesselFleet.designs():
		var s: Dictionary = VesselFleet.spec(design)
		var arrays := VesselFleet.hull_mesh(design, VesselFleet.WEAR_WEATHERED).surface_get_arrays(0)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var strakes := int(s["strakes"])
		for b in range(1, strakes):
			for t: float in [0.3, 0.5, 0.72]:
				var a := float(b) / strakes
				var seam := VesselFleet._point(s, t, a)
				# Middle of the old slot between the stepped inner skins.
				var target := seam - VesselFleet._normal(s, t, a) * 0.019
				var origin := Vector3(seam.x, float(s["depth"]) + 1.5, 0.0)
				var dir := (target - origin).normalized()
				var nearest := INF
				var front := false
				for i in range(0, vertices.size(), 3):
					var hit: Variant = Geometry3D.ray_intersects_triangle(
						origin, dir, vertices[i], vertices[i + 1], vertices[i + 2]
					)
					if hit == null:
						continue
					var dist := origin.distance_to(hit as Vector3)
					if dist < nearest:
						nearest = dist
						# Godot front faces wind clockwise: front normal = -(e1 x e2).
						var e1 := vertices[i + 1] - vertices[i]
						var e2 := vertices[i + 2] - vertices[i]
						front = -e1.cross(e2).dot(dir) < 0.0
				assert_true(front, "%s strake seam %d at t=%.2f is closed" % [design, b, t])


func test_sea_mask_footprint_stays_inside_the_hull() -> void:
	for design: StringName in VesselFleet.designs():
		var s: Dictionary = VesselFleet.spec(design)
		var shape := VesselFleet.water_mask_shape(design)
		var levels := VesselFleet.water_mask_heights(design)
		var outer_waterline := VesselFleet._floor_half_width(s, 0.5, float(s["draught"])) + 0.04
		assert_true(shape.x < float(s["length"]) * 0.5, "%s mask shorter than the hull" % design)
		assert_true(
			shape.y > 0.0 and shape.y < outer_waterline, "%s mask inside the waterline" % design
		)
		assert_true(shape.z < float(s["beam"]) * 0.5, "%s mask inside the sheer" % design)
		assert_true(levels.x < levels.y and levels.y < levels.z, "%s mask heights rise" % design)
	CityShips._set_hull_masks(
		PackedVector4Array([Vector4.ONE]), PackedVector4Array([Vector4.ONE]),
		PackedVector4Array([Vector4.ONE])
	)
	var mat := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	assert_eq(int(mat.get_shader_parameter(&"hull_mask_count")), 1, "one hull masked")
	assert_eq(
		(mat.get_shader_parameter(&"hull_mask_frame") as PackedVector4Array).size(),
		CityShips.HULL_MASK_MAX,
		"mask arrays padded to the shader size"
	)
	CityShips._set_hull_masks(PackedVector4Array(), PackedVector4Array(), PackedVector4Array())
	assert_eq(int(mat.get_shader_parameter(&"hull_mask_count")), 0, "mask cleared")


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
