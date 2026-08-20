extends "res://tests/godot/test_case.gd"

const Definition := preload("res://scenes/debug/asset_showcase_definition.gd")
const SMALL_SHOWCASE_SCENE := "res://scenes/debug/asset_showcase.tscn"
const LARGE_SHOWCASE_SCENE := "res://scenes/debug/asset_showcase_large.tscn"
const CHARACTERS_ANIMALS_SHOWCASE_SCENE := "res://scenes/debug/characters_animals_showcase.tscn"

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const HERO_BODY_SCENE := preload("res://assets/characters/shared/heroic_humanoid.glb")
# WHY: Keep the acceptance contract executable in Godot without importing the
# Python budget module; these values mirror the frozen Tier-0 caps in
# tools/character_fidelity_tiers.py.
const TIER_0_TRIANGLE_CAP := 60000
const TIER_0_TEXTURE_MAX_PX := 2048
const REQUIRED_PBR_FAMILIES: Array[String] = ["skin", "cloth", "leather", "hair"]


func test_showcase_definitions_are_valid_and_complete() -> void:
	var small_definition := Definition.create_small()
	var large_definition := Definition.create_large()
	var characters_animals_definition := Definition.create_characters_animals()
	assert_eq(small_definition.validate(), [], "small-item showcase must satisfy the production map contract")
	assert_eq(large_definition.validate(), [], "large-item showcase must satisfy the production map contract")
	assert_eq(
		characters_animals_definition.validate(),
		[],
		"characters/animals showcase must satisfy the production map contract"
	)
	assert_true(large_definition.zones.size() >= MapTypes.ALL_TERRAINS.size())
	assert_true(small_definition.zones.is_empty(), "terrain catalog belongs only on the large-item map")
	assert_true(characters_animals_definition.zones.is_empty(), "terrain catalog belongs only on the large-item map")

	var shown_terrains: Array[StringName] = []
	for zone in large_definition.zones:
		shown_terrains.append(zone["terrain"] as StringName)
	for terrain in MapTypes.ALL_TERRAINS:
		assert_true(shown_terrains.has(terrain), "missing large showcase terrain: %s" % terrain)

	var small_props := _prop_kinds(small_definition)
	var large_props := _prop_kinds(large_definition)
	var characters_animals_props := _prop_kinds(characters_animals_definition)
	for kind in MapTypes.ALL_PROP_KINDS:
		assert_true(
			small_props.has(kind) or large_props.has(kind) or characters_animals_props.has(kind),
			"missing showcase prop kind: %s" % kind
		)
		if kind in Definition.LARGE_PROP_KINDS:
			assert_true(large_props.has(kind), "large prop is on the wrong map: %s" % kind)
			assert_false(small_props.has(kind), "large prop leaked onto the small map: %s" % kind)
			assert_false(
				characters_animals_props.has(kind),
				"large prop leaked onto the characters/animals map: %s" % kind
			)
		elif kind in Definition.LIVE_PROP_KINDS:
			assert_true(
				characters_animals_props.has(kind),
				"live prop is on the wrong map: %s" % kind
			)
			assert_false(small_props.has(kind), "live prop leaked onto the small map: %s" % kind)
			assert_false(large_props.has(kind), "live prop leaked onto the large map: %s" % kind)
		else:
			assert_true(small_props.has(kind), "small prop is on the wrong map: %s" % kind)
			assert_false(
				characters_animals_props.has(kind),
				"small prop leaked onto the characters/animals map: %s" % kind
			)
	# wall_walk_access is an architectural variant on the large map; its generic
	# stairs sample remains in the small-object catalog.
	assert_true(large_props.has(MapTypes.PROP_KIND_STAIRS))

	var tree_models: Dictionary = {}
	for prop in large_definition.props:
		if prop.get("kind") != MapTypes.PROP_KIND_TREE or prop.get("primitive", &"") == &"ancient_tree":
			continue
		var parsed := MapViewTreeSpecies.parse_variant(prop.get("style_variant", &""))
		if parsed.has("species") and parsed.get("size") == MapViewTreeSpecies.SIZE_MEDIUM:
			tree_models[parsed["species"]] = prop
	assert_eq(tree_models.size(), MapViewTreeSpecies.ALL_SPECIES.size(), "large showcase needs every procedural tree model")
	for species in MapViewTreeSpecies.ALL_SPECIES:
		assert_true(tree_models.has(species), "missing showcase tree model: %s" % species)
		var model: Dictionary = tree_models[species]
		assert_eq(model.get("position"), _cell_center(Definition.tree_model_cell(MapViewTreeSpecies.ALL_SPECIES.find(species))))
		assert_eq(StringName(model.get("style_variant", &"")), StringName("tree.%s.medium" % String(species)))

	var shown_buildings: Array[StringName] = []
	for building in large_definition.buildings:
		shown_buildings.append(building["kind"] as StringName)
	for kind in MapTypes.ALL_BUILDING_KINDS:
		assert_true(shown_buildings.has(kind), "missing large showcase building kind: %s" % kind)
	assert_true(small_definition.buildings.is_empty(), "building catalog belongs only on the large-item map")
	assert_true(
		characters_animals_definition.buildings.is_empty(),
		"building catalog belongs only on the large-item map"
	)


func test_large_showcase_uses_a_spacious_grid() -> void:
	assert_true(Definition.TERRAIN_PATCH_SIZE.x > 12)
	assert_true(Definition.TERRAIN_PATCH_SIZE.y > 10)
	assert_true(Definition.LARGE_PROP_SPACING_CELLS.x > Definition.SMALL_PROP_SPACING_CELLS.x * 2)
	assert_true(Definition.LARGE_PROP_SPACING_CELLS.y > Definition.SMALL_PROP_SPACING_CELLS.y * 2)
	for left_index in Definition.BUILDING_SPECS.size():
		var left: Rect2i = Definition.BUILDING_SPECS[left_index]["cell_rect"]
		for right_index in range(left_index + 1, Definition.BUILDING_SPECS.size()):
			var right: Rect2i = Definition.BUILDING_SPECS[right_index]["cell_rect"]
			assert_false(left.intersects(right), "large building samples must not overlap")


func test_showcases_include_review_variants_and_animation_catalogs() -> void:
	assert_eq(Definition.GATE_SPECS.size(), 3, "oak, ironbound, and portcullis need dedicated samples")
	assert_true(
		AssetShowcase.HUMANOID_SCENES.size() >= 12,
		"showcase must retain production variants plus the full core-cast lineup"
	)
	var required_scenes: Array[String] = [
		"mart.tscn",
		"aita.tscn",
		"kaja.tscn",
		"henning.tscn",
		"jurgen.tscn",
		"ellen.tscn",
		"danish_warrior.tscn",
	]
	for required_scene: String in required_scenes:
		assert_true(
			AssetShowcase.HUMANOID_SCENES.any(
				func(scene: PackedScene) -> bool: return scene.resource_path.ends_with(required_scene)
			),
			"debug showcase must include %s" % required_scene
		)
	assert_true(SharedCharacterRig.CANONICAL_ANIMATIONS.size() >= 15,
		"shared rig must retain the full canonical animation minimum")
	assert_eq(CatRig.REQUIRED_ANIMATIONS.size(), 5)
	assert_true(ResourceLoader.exists(AssetShowcase.CART_SCENE_PATH, "PackedScene"))
	for facade in AssetShowcase.FACADE_ASSETS:
		assert_true(
			ResourceLoader.exists(facade["path"], "PackedScene"),
			"missing facade sample: %s" % facade["path"]
		)


func test_showcase_scenes_and_debug_destinations_are_loadable() -> void:
	assert_eq(DebugOverlay.ASSET_SHOWCASE_SCENE, SMALL_SHOWCASE_SCENE)
	assert_eq(DebugOverlay.LARGE_ASSET_SHOWCASE_SCENE, LARGE_SHOWCASE_SCENE)
	assert_eq(DebugOverlay.CHARACTERS_ANIMALS_SHOWCASE_SCENE, CHARACTERS_ANIMALS_SHOWCASE_SCENE)
	assert_eq(
		DebugOverlay.ASSET_SHOWCASE_SCENES,
		[SMALL_SHOWCASE_SCENE, LARGE_SHOWCASE_SCENE, CHARACTERS_ANIMALS_SHOWCASE_SCENE]
	)
	_assert_showcase_scene(SMALL_SHOWCASE_SCENE, Definition.SHOWCASE_SMALL)
	_assert_showcase_scene(LARGE_SHOWCASE_SCENE, Definition.SHOWCASE_LARGE)
	_assert_showcase_scene(CHARACTERS_ANIMALS_SHOWCASE_SCENE, Definition.SHOWCASE_CHARACTERS_ANIMALS)


func test_kalev_tier_zero_hero_contract_is_showcase_ready() -> void:
	var body := HERO_BODY_SCENE.instantiate()
	var total_triangles := 0
	var max_texture_px := 0
	var pbr_families: Dictionary = {}
	var textured_surfaces := 0
	var hair_surfaces := 0
	var head_mesh: MeshInstance3D
	var left_hand_mesh: MeshInstance3D
	var right_hand_mesh: MeshInstance3D

	for found: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		total_triangles += _mesh_triangle_count(mesh_instance.mesh)
		if found.name == "Character_Head":
			head_mesh = mesh_instance
		elif found.name == "Anatomy_HandL":
			left_hand_mesh = mesh_instance
		elif found.name == "Anatomy_HandR":
			right_hand_mesh = mesh_instance

		for surface_index: int in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if material == null or material.albedo_texture == null:
				continue
			textured_surfaces += 1
			assert_true(material.normal_enabled and material.normal_texture != null,
				"%s must carry a normal map" % material.resource_name)
			assert_true(material.roughness_texture != null,
				"%s must carry a roughness map" % material.resource_name)
			assert_true(material.ao_texture != null,
				"%s must carry an AO map" % material.resource_name)
			for family: String in REQUIRED_PBR_FAMILIES:
				if material.albedo_texture.resource_path.contains("_hero_tex_%s_" % family):
					pbr_families[family] = true
					break
			max_texture_px = max(
				max_texture_px,
				material.albedo_texture.get_width(),
				material.albedo_texture.get_height(),
				material.normal_texture.get_width() if material.normal_texture != null else 0,
				material.normal_texture.get_height() if material.normal_texture != null else 0,
				material.roughness_texture.get_width() if material.roughness_texture != null else 0,
				material.roughness_texture.get_height() if material.roughness_texture != null else 0,
			)
			if StringName(material.resource_name) in SharedCharacterRig.HAIR_MATERIAL_NAMES:
				hair_surfaces += 1

	assert_true(head_mesh != null, "Kalev needs a dedicated detailed head mesh")
	if head_mesh != null:
		assert_true(_mesh_triangle_count(head_mesh.mesh) >= 20000,
			"Kalev head must retain close-up facial detail")
	assert_true(left_hand_mesh != null and right_hand_mesh != null,
		"Kalev needs separate left and right hand meshes")
	if left_hand_mesh != null and right_hand_mesh != null:
		assert_true(_mesh_triangle_count(left_hand_mesh.mesh) >= 64,
			"left hand mesh must retain authored detail")
		assert_true(_mesh_triangle_count(right_hand_mesh.mesh) >= 64,
			"right hand mesh must retain authored detail")
	assert_true(textured_surfaces > 0, "hero body must expose authored PBR surfaces")
	for family: String in REQUIRED_PBR_FAMILIES:
		assert_true(pbr_families.has(family), "%s PBR family is missing from Kalev" % family)
	assert_true(hair_surfaces > 0, "Kalev must carry dedicated hair/beard surfaces")
	assert_true(total_triangles <= TIER_0_TRIANGLE_CAP,
		"Kalev must remain within the frozen Tier-0 triangle budget")
	assert_true(max_texture_px <= TIER_0_TEXTURE_MAX_PX,
		"Kalev must remain within the frozen Tier-0 texture budget")
	body.free()

	var kalev := KALEV_SCENE.instantiate() as SharedCharacterRig
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(kalev)
	assert_eq(kalev.validation_errors(), [], "Kalev must remain valid on the shared rig")
	assert_true(kalev.skeleton().find_bone("head") >= 0,
		"shared rig must expose a head attachment bone")
	assert_true(kalev.skeleton().find_bone("hand.l") >= 0,
		"shared rig must expose the left hand bone")
	assert_true(kalev.skeleton().find_bone("hand.r") >= 0,
		"shared rig must expose the right hand bone")
	assert_true(kalev.lod_visibility_configured(),
		"Kalev showcase must mount configured distance LODs")
	assert_true(kalev.lod_mesh_count(1) > 0 and kalev.lod_mesh_count(2) > 0,
		"Kalev showcase must include both distance LOD levels")

	var canonical_animations := kalev.canonical_animation_names()
	assert_true(
		canonical_animations.size() >= 15,
		"Kalev must retain the full canonical animation catalog"
	)
	for animation_name: StringName in canonical_animations:
		assert_true(kalev.has_animation(animation_name), "Kalev is missing %s" % animation_name)
		assert_true(kalev.play_animation(animation_name, 0.0), "Kalev must play %s" % animation_name)
	assert_true(kalev.animation_player().get_animation_list().size() >= 70,
		"Kalev must retain the imported full animation library")

	var checked_hair_shader := false
	var hair_shader_code := SharedCharacterRig.HAIR_MATERIAL_SHADER.code
	assert_true(
		hair_shader_code.contains("ANISOTROPY"),
		"hair shader must preserve directional fibre response"
	)
	assert_true(
		hair_shader_code.contains("ALPHA_SCISSOR_THRESHOLD"),
		"hair shader must support hair-card cutout"
	)
	for found: Node in kalev.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index: int in mesh_instance.mesh.get_surface_count():
			var source_material := mesh_instance.mesh.surface_get_material(surface_index)
			if (
				source_material == null
				or StringName(source_material.resource_name) not in SharedCharacterRig.HAIR_MATERIAL_NAMES
			):
				continue
			var active_material := mesh_instance.get_active_material(surface_index) as ShaderMaterial
			assert_true(active_material != null, "%s hair surface must use the hair shader" % found.name)
			if active_material == null:
				continue
			assert_eq(active_material.shader, SharedCharacterRig.HAIR_MATERIAL_SHADER)
			assert_true(active_material.get_shader_parameter("albedo_texture") != null,
				"%s hair surface must preserve its albedo map" % found.name)
			assert_true(active_material.get_shader_parameter("normal_texture") != null,
				"%s hair surface must preserve its normal map" % found.name)
			assert_true(active_material.get_shader_parameter("roughness_texture") != null,
				"%s hair surface must preserve its roughness map" % found.name)
			checked_hair_shader = true
	assert_true(checked_hair_shader, "Kalev must expose a runtime hair-card material")
	kalev.queue_free()


func _mesh_triangle_count(mesh: Mesh) -> int:
	var triangles := 0
	for surface_index: int in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		if indices.is_empty():
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			triangles += vertices.size() / 3
		else:
			triangles += indices.size() / 3
	return triangles

func _prop_kinds(definition: MapDefinition) -> Array[StringName]:
	var kinds: Array[StringName] = []
	for prop in definition.props:
		var kind: StringName = prop["kind"]
		if kind not in kinds:
			kinds.append(kind)
	return kinds


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * float(Definition.CELL_SIZE)


func _assert_showcase_scene(path: String, expected_kind: StringName) -> void:
	assert_true(ResourceLoader.exists(path, "PackedScene"))
	var scene := load(path) as PackedScene
	assert_true(scene != null)
	var root := scene.instantiate() as AssetShowcase
	assert_true(root != null)
	assert_eq(StringName(root.showcase_kind), expected_kind)
	assert_true(
		root.has_node("Actors/Player"),
		"gallery must remain walkable with the production player"
	)
	root.free()
