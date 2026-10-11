extends "res://tests/godot/test_case.gd"

const LifeProps := preload("res://scripts/map/view3d/map_view_mesh_builder_district_life_props.gd")
const RackModels := preload("res://scripts/map/view3d/map_view_fish_drying_rack_models.gd")
const DriedFishMeshes := preload("res://scripts/map/view3d/map_view_dried_fish_meshes.gd")
const PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")


func test_empty_fish_drying_rack_is_a_reusable_grounded_frame() -> void:
	var root := Node3D.new()
	var frame := RackModels.add_frame(root)
	for path in [
		"EndFrame0FrontLeg",
		"EndFrame0BackLeg",
		"EndFrame1FrontLeg",
		"EndFrame1BackLeg",
		"RidgePole",
		"FrontDryingPole",
		"BackDryingPole",
		"FrontBrace",
		"BackBrace",
	]:
		assert_true(frame.has_node(path), "fish rack needs structural member %s" % path)
	assert_true(frame.get_meta(&"empty_drying_frame", false), "frame must remain independently reusable")
	assert_true(root.find_child("DryingCatch", true, false) == null, "standalone frame must not create catch")

	var bounds := _bounds_for(root)
	assert_true(bounds.size.x >= 1.45 and bounds.size.x <= 1.6, "rack must stay inside its 2-cell length band: %s" % bounds)
	assert_true(bounds.size.z >= 0.8 and bounds.size.z <= 0.97, "splayed feet must stay inside the 1-cell depth band: %s" % bounds)
	assert_true(bounds.size.y >= 1.35 and bounds.size.y <= 1.45, "rack must read as a standing work frame: %s" % bounds)
	assert_true(bounds.position.y >= -0.001, "rack feet must rest on the prop ground plane: %s" % bounds)
	root.free()


func test_dried_fish_species_are_shaped_reusable_meshes() -> void:
	var herring := DriedFishMeshes.geometry_stats(DriedFishMeshes.SPECIES_HERRING)
	var cod := DriedFishMeshes.geometry_stats(DriedFishMeshes.SPECIES_COD)
	for stats in [herring, cod]:
		var bounds: AABB = stats["aabb"]
		assert_true(int(stats["triangles"]) >= 90 and int(stats["triangles"]) <= 120, "fish needs a readable lightweight silhouette")
		assert_true(bounds.size.y >= 0.37 and bounds.size.y <= 0.55, "dried fish needs a plausible hand-length body")
		assert_true(bounds.size.x > bounds.size.z * 2.0, "fish must be laterally compressed rather than tubular")
	assert_true((cod["aabb"] as AABB).size.y > (herring["aabb"] as AABB).size.y, "cod must read larger than herring")
	assert_true((cod["aabb"] as AABB).size.x > (herring["aabb"] as AABB).size.x, "cod needs the deeper body profile")

	var loose_catch := Node3D.new()
	var fish := DriedFishMeshes.add_hanging_fish(loose_catch, "ReusableCod", DriedFishMeshes.SPECIES_COD, Vector3.ZERO)
	assert_eq(fish.get_meta(&"dried_fish_species"), DriedFishMeshes.SPECIES_COD)
	assert_true(fish.has_node("FishMesh"), "reusable fish component must expose one render mesh")
	loose_catch.free()


func test_fish_rack_style_variants_have_a_strict_domain_allowlist() -> void:
	for variant in PropStyleVariants.FISH_RACK_VARIANTS:
		assert_true(PropStyleVariants.is_known(MapTypes.PROP_KIND_FISH_DRYING_RACK, variant))
	assert_false(PropStyleVariants.is_known(MapTypes.PROP_KIND_FISH_DRYING_RACK, &"fish_rack.emtpy"), "variant typos must fail map compilation")


func test_fish_rack_variants_compose_frame_and_catch_independently() -> void:
	var empty := _build_variant(&"fish_rack.empty")
	assert_true(empty.has_node("FishDryingRackFrame"), "empty variant keeps the timber frame")
	assert_false(empty.has_node("DryingCatch"), "empty variant must not instantiate fish")
	empty.free()

	var herring := _build_variant(&"fish_rack.herring")
	assert_true(herring.has_node("FishDryingRackFrame"), "loaded variant reuses the same frame")
	assert_eq(herring.get_node("DryingCatch").find_children("Fish*", "Node3D", false, false).size(), 5, "herring rack needs five separate fish")
	for fish in herring.get_node("DryingCatch").find_children("Fish*", "Node3D", false, false):
		assert_eq(fish.get_meta(&"dried_fish_species"), DriedFishMeshes.SPECIES_HERRING)
	herring.free()

	var mixed := _build_variant(&"fish_rack.mixed")
	var mixed_species: Dictionary = {}
	for fish in mixed.get_node("DryingCatch").find_children("Fish*", "Node3D", false, false):
		mixed_species[fish.get_meta(&"dried_fish_species")] = true
	assert_true(mixed_species.has(DriedFishMeshes.SPECIES_HERRING), "mixed rack needs herring")
	assert_true(mixed_species.has(DriedFishMeshes.SPECIES_COD), "mixed rack needs cod")
	mixed.free()


func _build_variant(variant: StringName) -> Node3D:
	var root := Node3D.new()
	LifeProps.add_to(
		root,
		MapTypes.PROP_KIND_FISH_DRYING_RACK,
		{"id": &"test.fish_drying_rack", "style_variant": variant}
	)
	return root


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
