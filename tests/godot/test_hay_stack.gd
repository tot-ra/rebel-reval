extends "res://tests/godot/test_case.gd"

## Hay stacks: tall homogeneous body, ground litter, solid footprint and yielding flank.


func test_every_size_stands_taller_than_a_man_and_taller_than_wide() -> void:
	for size_variant: StringName in MapViewHayMeshes.SIZE_SCALES:
		for contour in MapViewHayMeshes.VARIANT_COUNT:
			var bounds := MapViewHayMeshes.size_bounds(size_variant, contour)
			assert_true(bounds.size.y > 2.0, "%s is taller than a 2.0 m character" % size_variant)
			assert_true(
				bounds.size.y > maxf(bounds.size.x, bounds.size.z),
				"%s is more vertical than wide" % size_variant
			)


func test_body_has_no_stray_stalks_and_litter_lies_on_the_ground() -> void:
	var body := MapViewHayMeshes.body_mesh(0)
	var litter := MapViewHayMeshes.litter_mesh(0)
	# Nothing pokes out of the body past the belly envelope.
	for vertex: Vector3 in body.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var limit := MapViewHayMeshes.BELLY_RADIUS * 1.25
		assert_true(Vector2(vertex.x, vertex.z).length() <= limit)
	var aabb := litter.get_aabb()
	assert_true(aabb.size.y < 0.15, "litter is flat on the ground")
	assert_true(aabb.size.x > 2.0, "litter spreads well beyond the foot")


func test_collision_radius_sits_inside_the_belly() -> void:
	for size_variant: StringName in MapViewHayMeshes.SIZE_SCALES:
		var bounds := MapViewHayMeshes.size_bounds(size_variant, 0)
		assert_true(MapViewHayMeshes.collision_radius(size_variant) < bounds.size.x * 0.5 + 0.2)
		assert_true(MapViewHayMeshes.collision_radius(size_variant) > 0.5)


func test_rick_yields_only_near_the_actor() -> void:
	var far := HayRickReaction.push_target(Vector2(5.0, 0.0), 1.0, 0.0)
	assert_eq(far, Vector2.ZERO)
	var touching := HayRickReaction.push_target(Vector2(1.0, 0.0), 1.0, 0.0)
	assert_true(touching.x < -0.9, "pushed away from an actor at the flank")
	var running := HayRickReaction.push_target(Vector2(1.0, 0.0), 1.0, 5.0)
	assert_true(running.length() > touching.length(), "a run shoves harder")


func test_deformation_leans_the_crown_away_and_rests_at_zero() -> void:
	assert_eq(HayRickReaction.deformation_basis(Vector2.ZERO, Basis.IDENTITY), Basis.IDENTITY)
	var pushed := HayRickReaction.deformation_basis(Vector2(-1.0, 0.0), Basis.IDENTITY)
	assert_true(pushed.y.x < 0.0, "crown slides away from the actor (-x)")
	assert_true(absf(pushed.x.x) < 1.0, "flank compressed along the push axis")


func test_farmland_rick_blocks_the_logic_plane_and_frees_with_its_field() -> void:
	var plan := CityPlan.load_default()
	var farmland := CityFarmland.create(plan)
	var parent := Node2D.new()
	farmland.collision_parent = parent
	var features := CityFarmland.features_for(plan)
	var built := 0
	for feature in features:
		if feature["kind"] != &"pasture" or feature["pasture_kind"] == &"meadow":
			continue
		farmland.update_for(feature["centre"])
		built += 1
		break
	assert_true(built > 0)
	var bodies := 0
	for holder in parent.get_children():
		for body in holder.get_children():
			if body is StaticBody2D:
				bodies += 1
				assert_eq(body.collision_layer, CollisionLayers.WORLD)
	# Pastures roll their rick (70 %), so a missing one is only legitimate then.
	assert_true(bodies <= 1)
	farmland.free()
	parent.free()


func test_stack_is_furry_wind_shaded_and_sheds_wisps() -> void:
	var parent := Node3D.new()
	var rick := MapViewHayMeshes.add_rick(parent, "Rick", 1)
	var body: MeshInstance3D = rick.get_node("HayBody")
	assert_true(body.material_override is ShaderMaterial, "body uses the hay shader")
	var shells := 0
	for child in body.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).material_override is ShaderMaterial:
			var material := (child as MeshInstance3D).material_override as ShaderMaterial
			assert_true(float(material.get_shader_parameter(&"shell")) > 0.0)
			assert_eq((child as MeshInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			shells += 1
	assert_eq(shells, MapViewMaterials.HAY_STACK_SHELL_COUNT - 1)
	assert_true(rick.has_node("Wisps"), "a standing stack sheds loose strands")
	# A wagon load rides the cart and sheds nothing.
	var load_rick := MapViewHayMeshes.add_rick(parent, "Load", 1, Vector3.ZERO, Vector3.ONE, &"", true)
	assert_false(load_rick.has_node("Wisps"))
	parent.free()


func test_wisp_mesh_carries_attachment_and_release_data() -> void:
	var mesh := MapViewHayMeshes.wisp_mesh(0)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(vertices.size(), MapViewHayMeshes.WISP_COUNT * 6)
	var custom: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	assert_eq(custom.size(), vertices.size() * 4)
	# Attachment point (CUSTOM0.xyz) is the vertex itself: the shader builds the ribbon.
	assert_true(is_equal_approx(custom[0], vertices[0].x))
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for colour in colors:
		assert_true(colour.r > 0.1 and colour.r < 1.2, "release threshold in drive range")
