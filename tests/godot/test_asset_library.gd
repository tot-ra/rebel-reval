extends "res://tests/godot/test_case.gd"

const Catalog := preload("res://scripts/ui/asset_library_catalog.gd")
const LibraryScene := preload("res://scenes/menu/assets_library.tscn")
const MainMenuScene := preload("res://scenes/menu/main_menu.tscn")
const DOG_PATH := "res://assets/animals/medieval/medieval_dog.glb"
const ANVIL_PATH := "res://assets/props/forge/smithy_anvil.glb"


func test_catalog_lists_imported_models_by_folder() -> void:
	var entries: Array[Dictionary] = Catalog.list_models()
	assert_true(entries.size() >= 20, "catalog should find imported GLB models")
	var paths: Array[String] = []
	var categories: Array[String] = []
	for entry in entries:
		paths.append(String(entry["path"]))
		categories.append(String(entry["category"]))
	assert_true(paths.has(DOG_PATH), "medieval dog should be in the catalog")
	assert_true(paths.has(ANVIL_PATH), "smithy anvil should be in the catalog")
	assert_true(categories.has("animals"), "animals category should exist")
	assert_true(categories.has("props"), "props category should exist")


func test_catalog_filter_matches_name_and_category() -> void:
	var entries: Array[Dictionary] = Catalog.list_models()
	var dogs := Catalog.filter_entries(entries, "dog", "animals")
	assert_true(dogs.size() >= 1, "dog filter should return animal models")
	assert_eq(String(dogs[0]["category"]), "animals")
	var empty := Catalog.filter_entries(entries, "definitely-not-a-model", "")
	assert_eq(empty.size(), 0)


func test_preferred_clip_picks_idle_then_first() -> void:
	var clips := PackedStringArray(["Run", "Idle", "Walk"])
	assert_eq(Catalog.preferred_clip(clips), "Idle")
	assert_eq(Catalog.preferred_clip(PackedStringArray(["Hop"])), "Hop")
	assert_eq(Catalog.preferred_clip(PackedStringArray()), "")


func test_library_scene_lists_models_and_can_orbit() -> void:
	var library := LibraryScene.instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(library)
	assert_true(library.filtered_count() >= 1)
	var listed := library.find_child("ModelList", true, false) as ItemList
	assert_true(listed.item_count >= 1)
	assert_true(library.show_model(DOG_PATH))
	assert_eq(library.current_path(), DOG_PATH)
	var clips: PackedStringArray = library.current_clips()
	assert_true(clips.size() >= 1, "dog model should expose animation clips")
	assert_true(library.play_clip(clips[0]))
	var camera := library.find_child("PreviewCamera", true, false) as Camera3D
	var before := camera.position
	library.apply_orbit(0.4, 0.0)
	assert_true(camera.position.distance_to(before) > 0.01)
	var clip_list := library.find_child("ClipList", true, false) as OptionButton
	assert_true(clip_list.item_count >= 1)
	library.free()


func test_library_static_prop_has_no_clip_dropdown() -> void:
	var library := LibraryScene.instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(library)
	assert_true(library.show_model(ANVIL_PATH))
	assert_eq(library.current_clips().size(), 0)
	var clip_list := library.find_child("ClipList", true, false) as OptionButton
	assert_true(clip_list.disabled)
	assert_eq(clip_list.get_item_text(0), "No animations")
	library.free()


func test_main_menu_has_assets_library_focus_ring() -> void:
	var menu := MainMenuScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	var credits := menu.get_node("Credits label") as Control
	var library := menu.get_node("Assets library label") as Control
	var exit_label := menu.get_node("Exit label") as Control
	assert_true(library.visible)
	assert_eq(library.focus_mode, Control.FOCUS_ALL)
	assert_eq(credits.focus_neighbor_bottom, NodePath("../Assets library label"))
	assert_eq(library.focus_neighbor_top, NodePath("../Credits label"))
	assert_eq(library.focus_neighbor_bottom, NodePath("../Exit label"))
	assert_eq(exit_label.focus_neighbor_top, NodePath("../Assets library label"))
	menu.free()
