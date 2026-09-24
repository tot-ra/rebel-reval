extends "res://tests/godot/test_case.gd"

## City wall / Viru gate realism: masonry scale, seam-safe mapping, roof tiles
## with relief, gate throat fitting and hewn timber.

const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const Fortification := preload(
	"res://scripts/map/view3d/map_view_mesh_builder_building_fortification.gd"
)
const Landmarks := preload("res://scripts/map/view3d/map_view_mesh_builder_landmarks.gd")


func test_fortification_masonry_is_world_space_and_course_scaled() -> void:
	MapViewMaterials.reset()
	var material := MapViewMaterials.fortification_masonry(Color(0.56, 0.55, 0.5))
	assert_true(material.uv1_triplanar, "fortification masonry must be triplanar")
	assert_true(
		material.uv1_world_triplanar,
		"overlapping wall boxes must share one world-space texture phase (seam flicker)"
	)
	# Plate carries ~10 courses; at least 5 plate repeats per 10 units keeps
	# courses under ~0.2 units instead of fifth-of-a-character boulders.
	assert_true(material.uv1_scale.y >= 0.5, "masonry courses must be denser than the house plate")
	assert_true(material.normal_enabled, "masonry keeps its relief normal map")


func test_wall_seal_never_grows_into_a_gate_passage() -> void:
	var jamb := Rect2(107.0, 49.0, 10.0, 3.0)
	var passage := Rect2(110.0, 51.0, 7.0, 6.0)
	var sealed := Fortification.sealed_wall_footprint(jamb, [passage])
	assert_eq(sealed.end.y, jamb.end.y, "the passage-facing side must stay on the collision face")
	assert_true(sealed.position.y < jamb.position.y, "the outer side still seals against towers")
	var open := Fortification.sealed_wall_footprint(jamb, [])
	assert_true(open.end.y > jamb.end.y, "without a passage both sides keep the seal overhang")


func test_viru_gate_fits_its_collision_throat_and_shows_leaves() -> void:
	var definition := LowerTownSlice.create()
	var arch: Dictionary = {}
	for landmark: Dictionary in definition.view_landmarks:
		if landmark.get("id", &"") == &"viru_gate_arch":
			arch = landmark
	assert_false(arch.is_empty(), "lower_town_slice must keep the Viru gate arch landmark")
	var footprints := Landmarks.fortification_wall_footprints(definition)
	var node := Landmarks.build_landmark(arch, definition.cell_size, -1.0, footprints)
	var scale := MapViewBridge.world_scale(definition.cell_size)
	# The Viru road runs between the jamb walls at y=52 and y=56 (map cells).
	var road_half := 2.0 * definition.cell_size * scale
	var jamb := node.get_node("Jamb0") as MeshInstance3D
	var jamb_box := jamb.mesh as BoxMesh
	var inner_face := absf(jamb.position.z) - jamb_box.size.z * 0.5
	assert_true(
		absf(inner_face - road_half) < 0.01,
		"arch jambs must meet the collision throat (%.2f vs %.2f)" % [inner_face, road_half]
	)
	var leaves := node.get_node("GateLeaves") as Node3D
	var leaf_found := false
	for child in leaves.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var override := mesh_instance.get_surface_override_material(0)
		if override == null:
			continue
		leaf_found = true
		assert_true(
			(override as StandardMaterial3D).normal_enabled,
			"gate leaf surfaces need relief, not flat painted plates"
		)
	assert_true(leaf_found, "gate kit surfaces must be remapped to hewn oak and forged iron")
	node.free()


func test_roof_tiles_carry_relief_and_world_scaled_density() -> void:
	MapViewMaterials.reset()
	var gabled := MapViewMaterials.roof_tile_world(Color8(150, 66, 48))
	assert_true(gabled.normal_enabled, "tile roofs need a relief normal map")
	assert_true(
		gabled.uv1_scale.x < 1.0 and gabled.uv1_scale.y < 1.0,
		"world-unit gabled UVs need under one plate per unit, not ~50 tiles per metre"
	)
	var house := MapViewMaterials.roof_surface_for_building(&"roof.test", &"tile", Color8(150, 66, 48))
	assert_true(house.uv1_scale.x < 1.0, "tile houses share the world-unit tile density")
	assert_eq(
		gabled.albedo_texture.get_width(),
		MapViewMaterials.RESOLUTION.ROOF_TILE_TEXTURE_SIZE,
		"roof tiles use the dedicated tile plate resolution"
	)


func test_tower_cone_roof_has_stepped_tile_courses() -> void:
	var mesh := Fortification.tower_cone_roof_mesh(3.0, 4.3)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var max_radius := 0.0
	var top := -INF
	for vertex in vertices:
		max_radius = maxf(max_radius, Vector2(vertex.x, vertex.z).length())
		top = maxf(top, vertex.y)
	assert_true(max_radius > 3.0, "course lips must step out past the smooth cone")
	assert_true(absf(top - 4.3) < 0.001, "the apex keeps the authored roof height")
	assert_true(arrays[Mesh.ARRAY_TANGENT] != null, "stepped roof needs tangents for tile relief")


func test_wall_walk_gallery_uses_hewn_timber_and_rafters() -> void:
	var root := Node3D.new()
	Fortification.add_wall_walk_roof(root, Vector2(4.0, 20.0), 6.0)
	assert_true(root.has_node("GalleryRidgeBeam"), "gallery roofs need a visible ridge beam")
	assert_true(root.has_node("GalleryRafter0_1"), "gallery roofs need oak rafters")
	var post := root.get_node("RoofPost0_1") as MeshInstance3D
	var material := post.material_override as StandardMaterial3D
	assert_true(material.normal_enabled, "gallery posts need hewn-oak relief")
	assert_true(material.albedo_texture != null, "gallery posts need wood grain")
	root.free()
