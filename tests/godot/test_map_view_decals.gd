extends "res://tests/godot/test_case.gd"

const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewDecals := preload("res://scripts/map/view3d/map_view_decals.gd")
const SmithyCourtyard := preload("res://scripts/map/smithy_courtyard_definition.gd")


class _DummyDefinition:
	extends RefCounted
	var map_id := &"test"
	var seed := 42042
	var cell_size := 32
	var size_cells := Vector2i(10, 10)
	var base_terrain := MapTypes.TERRAIN_GRASS
	var ground_elevation := 0.0
	var zones: Array[Dictionary] = []
	var buildings: Array[Dictionary] = []
	var props: Array[Dictionary] = []
	var decals: Array[Dictionary] = []
	var player_spawn := Vector2(5.0, 5.0)
	var location := &"test"
	var scope := &"prototype"
	var active := false
	var palette := &"clean_painted"
	var transitions: Array[Dictionary] = []
	var direction_signs: Array[Dictionary] = []
	var excluded_areas: Array[Rect2i] = []
	var patrols: Array[Dictionary] = []
	var interaction_anchors: Array[Dictionary] = []
	var camera_bounds := Rect2(0, 0, 320, 320)
	var fade_volumes: Array[Dictionary] = []
	var source_references: Array[String] = []
	var fingerprint := "test"
	var view_landmarks: Array[Dictionary] = []
	var surroundings_town_sides: Array[StringName] = []
	var surroundings_sides: Dictionary = {}

	func cell_rect_to_world_rect(rect: Rect2i) -> Rect2:
		var s := float(cell_size)
		return Rect2(Vector2(rect.position) * s, Vector2(rect.size) * s)

	func cell_rect_center(rect: Rect2i) -> Vector2:
		return cell_rect_to_world_rect(rect).position + cell_rect_to_world_rect(rect).size * 0.5

	func cell_rects() -> Array[Rect2i]:
		return []

	func world_size() -> Vector2:
		return Vector2(size_cells) * float(cell_size)

	func suppresses_exterior_surroundings() -> bool:
		return false

	func validate() -> Array[String]:
		return []

	func fingerprint_valid() -> bool:
		return true

	func has_transition(_id: StringName) -> bool:
		return false

	func find_transition(_id: StringName) -> Dictionary:
		return {}

	func transition_rect(_transition: Dictionary) -> Rect2:
		return Rect2()

	func building_rects() -> Array[Rect2i]:
		return []


func test_decals_placed_from_map_data() -> void:
	var def := _DummyDefinition.new()
	def.decals = [
		{"id": &"soot_1", "kind": MapTypes.DECAL_KIND_SOOT, "position": Vector2(16.0, 16.0)},
		{"id": &"mud_1", "kind": MapTypes.DECAL_KIND_MUD, "position": Vector2(32.0, 32.0), "radius": 1.2},
		{"id": &"blood_1", "kind": MapTypes.DECAL_KIND_BLOOD, "position": Vector2(48.0, 24.0), "rotation": 0.5},
	]
	var grid := MapBuilder.build(def)
	var view := MapView3D.create(def, grid)
	var decals_node := view.get_node_or_null("Decals") as Node3D
	assert_true(decals_node != null, "Decals node must be added during assembly")
	assert_eq(decals_node.get_child_count(), 3, "Three authored decals must produce three child nodes")
	var soot := decals_node.get_node("Decal_soot_1") as MeshInstance3D
	assert_true(soot != null, "Soot decal must exist")
	assert_eq(soot.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Decals must not cast shadows")
	assert_eq(soot.gi_mode, GeometryInstance3D.GI_MODE_DISABLED, "Decals must not affect GI")
	var material := soot.material_override as StandardMaterial3D
	assert_true(material != null, "Decal must have a StandardMaterial3D override")
	assert_eq(material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "Decal material must be alpha-transparent")
	view.free()


func test_decals_ignore_invalid_kind() -> void:
	var def := _DummyDefinition.new()
	def.decals = [
		{"id": &"bad", "kind": &"nonexistent_kind", "position": Vector2(10.0, 10.0)},
		{"id": &"good", "kind": MapTypes.DECAL_KIND_GRIME, "position": Vector2(20.0, 20.0)},
	]
	var grid := MapBuilder.build(def)
	var view := MapView3D.create(def, grid)
	var decals_node := view.get_node_or_null("Decals") as Node3D
	assert_true(decals_node != null, "Decals node must exist even with invalid entries")
	assert_eq(decals_node.get_child_count(), 1, "Invalid decal kind must be skipped")
	view.free()


func test_clearing_decals_does_not_affect_gameplay() -> void:
	var def := _DummyDefinition.new()
	def.decals = [
		{"id": &"soot_1", "kind": MapTypes.DECAL_KIND_SOOT, "position": Vector2(16.0, 16.0)},
	]
	var grid_before := MapBuilder.build(def)
	var fingerprint_before := grid_before.fingerprint()
	def.decals.clear()
	var grid_after := MapBuilder.build(def)
	var fingerprint_after := grid_after.fingerprint()
	assert_eq(fingerprint_before, fingerprint_after, "Removing decals must not change grid fingerprint")


func test_smithy_has_no_decals_yet() -> void:
	var definition := SmithyCourtyard.create()
	assert_eq(definition.decals.size(), 0, "Smithy courtyard starts with no decals (P0-157 integration point)")
