extends "res://tests/godot/test_case.gd"

const Models := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const PennedFauna := preload("res://scripts/map/view3d/map_view_penned_fauna.gd")
const UrbanFauna := preload("res://scripts/map/view3d/map_view_urban_fauna.gd")


func test_production_models_load_with_mesh_material_and_ground_contact() -> void:
	for species: StringName in [MammalSpecies.SPECIES_COW, MammalSpecies.SPECIES_SHEEP, MammalSpecies.SPECIES_HORSE]:
		var host := Node3D.new()
		var model := Models.add_model(host, species)
		assert_true(model != null, "%s needs an imported production model" % species)
		assert_true(model.get_meta(&"production_animal_model", false))
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		assert_true(meshes.size() >= 1, "%s GLB needs render geometry" % species)
		var mesh_instance := meshes[0] as MeshInstance3D
		assert_true(mesh_instance.mesh.get_surface_count() >= 1)
		assert_true(mesh_instance.mesh.surface_get_material(0) != null, "%s needs portable PBR material" % species)
		var aabb := mesh_instance.get_aabb()
		assert_true(absf(aabb.position.y) < 0.001, "%s feet must touch Y=0" % species)
		host.free()


func test_static_livestock_props_use_production_models() -> void:
	for kind: StringName in [MapTypes.PROP_KIND_CATTLE, MapTypes.PROP_KIND_SHEEP, MapTypes.PROP_KIND_HORSE]:
		var prop := MapViewMeshBuilder.build_prop({"id": kind, "kind": kind, "position": Vector2.ZERO}, MapTypes.DEFAULT_CELL_SIZE)
		assert_true((prop.get_node("Model") as Node3D).get_meta(&"production_animal_model", false))
		prop.free()


func test_ambient_livestock_actors_share_production_models_without_collision() -> void:
	var penned := PennedFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(penned)
	penned.configure(&"north_quarter", MammalSpecies.CONTEXT_MARKET, 32)
	for actor in penned.get_children():
		assert_true((actor.get_node("Model") as Node3D).get_meta(&"production_animal_model", false))
		assert_false(penned.actor_has_collision(actor))
	penned.queue_free()

	var urban := UrbanFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(urban)
	urban.configure(&"south_quarter", MammalSpecies.CONTEXT_TOOMPEA, 32)
	for actor in urban.get_children():
		if actor.get_meta(&"species", &"") == MammalSpecies.SPECIES_HORSE:
			assert_true((actor.get_node("Model") as Node3D).get_meta(&"production_animal_model", false))
		assert_false(urban.actor_has_collision(actor))
	urban.queue_free()
