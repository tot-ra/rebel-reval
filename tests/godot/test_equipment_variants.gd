extends "res://tests/godot/test_case.gd"

## Prestige and wear variants at runtime (docs/SYSTEMS/EQUIPMENT_VARIANTS.md, task R-2004):
## a missing variant falls back to the base item, player items keep their variant on save/load.

const EquipmentVariant := preload("res://scripts/city/equipment_variant.gd")
const BODY := "citizen_m_adult_average"
const SPEAR_BASE := "res://assets/props/weapons/spear/variants/spear_p1_w1.glb"


func _rig() -> SharedCharacterRig:
	var scene := load("res://assets/characters/variants/%s.tscn" % BODY) as PackedScene
	var rig := scene.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	return rig


func _overridden(root: Node) -> int:
	var count := 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			if mesh_instance.get_surface_override_material(surface) != null:
				count += 1
	return count


func test_cells_parse() -> void:
	assert_eq(EquipmentVariant.split("kettle_hat@p1_w2"), PackedStringArray(["kettle_hat", "p1_w2"]))
	assert_eq(EquipmentVariant.split("hood"), PackedStringArray(["hood", ""]))
	assert_true(EquipmentVariant.is_cell("p3_w0"))
	assert_false(EquipmentVariant.is_cell("p4_w0"))
	assert_false(EquipmentVariant.is_cell(""))
	assert_eq(EquipmentVariant.wear("p2_w2"), 2)
	assert_eq(EquipmentVariant.wear("junk"), 1)
	assert_eq(EquipmentVariant.prestige("p3_w1"), 3)


func test_shipped_variant_is_mounted_as_is() -> void:
	var rig := _rig()
	CitizenGear.arm(rig, {"body": BODY, "wear": [], "duty": {"kit": "watch"}, "gear_variant": "p1_w1"})
	var spear := rig.equipped(&"right_hand")
	assert_true(spear != null, "spear mounted")
	if spear != null:
		assert_eq(spear.scene_file_path, SPEAR_BASE)
		assert_eq(String(spear.get_meta(&"variant", "")), "spear_p1_w1")
		assert_eq(_overridden(spear), 0, "the shipped cell keeps its own materials")
	rig.queue_free()


func test_missing_variant_falls_back_to_the_base_item() -> void:
	var rig := _rig()
	CitizenGear.arm(rig, {"body": BODY, "wear": [], "duty": {"kit": "crown"}, "gear_variant": "p3_w2"})
	var spear := rig.equipped(&"right_hand")
	assert_true(spear != null, "base spear mounted for a missing cell")
	if spear != null:
		assert_eq(spear.scene_file_path, SPEAR_BASE)
		assert_eq(String(spear.get_meta(&"variant", "")), "spear_p3_w2")
		assert_true(_overridden(spear) > 0, "battered stand-in finish on the fallback")
	rig.queue_free()
	# Malformed or absent cells read as the base cell.
	assert_eq(CitizenGear.gear_cell({}), EquipmentVariant.BASE_CELL)
	assert_eq(CitizenGear.gear_cell({"gear_variant": "p9"}), EquipmentVariant.BASE_CELL)


func test_variant_wear_entry_mounts_the_base_layer() -> void:
	var rig := _rig()
	var record := {"body": BODY, "status": "labourer", "trade": "mason", "id": "cit.test.var",
		"wear": ["gambeson@p1_w2", "kettle_hat@p1_w2"]}
	assert_eq(CitizenWardrobe.dress(rig, record), 2, "both layers fall back to the base GLBs")
	assert_true(rig.has_garment(&"wear_gambeson") and rig.has_garment(&"wear_kettle_hat"))
	rig.queue_free()
	# A battered layer shows more patches and fading than the resident's base wear.
	var base := CitizenWardrobe.wear_of(record)
	var battered := CitizenWardrobe.cell_wear(base, 2)
	var fresh := CitizenWardrobe.cell_wear(base, 0)
	assert_true(battered[1].x > base[1].x and battered[1].y > base[1].y, "w2 patches and fade")
	assert_true(fresh[1].x <= base[1].x and fresh[0].x <= base[0].x, "w0 cleaner")
	assert_eq(CitizenWardrobe.cell_wear(base, 1), base)


func test_shield_resolves_to_a_modelled_variant() -> void:
	# R-2013: shipped GLBs, nearest cell of the kind when the exact one is not made.
	var crown := CitizenShield.scene("crown", Color.GRAY, "p2_w1")
	assert_true(crown != null and crown.instantiate().get_node_or_null("socket_forearm") != null)
	assert_eq(CitizenShield.scene("crown", Color.GRAY, "p2_w2"), crown, "only one crown cell")
	var fresh := CitizenShield.scene("plain", Color.GRAY, "p1_w0")
	var battered := CitizenShield.scene("plain", Color.GRAY, "p1_w2")
	assert_true(fresh != battered, "plain wear picks its own file")
	assert_true(CitizenShield.scene("buckler") != null and CitizenShield.scene("pavise") != null)
	assert_true(CitizenShield.scene("field", Color.RED) != CitizenShield.scene("field", Color.BLUE))


func _state() -> GameState:
	var state := GameState.new()
	state.bag.set_content_db(SessionState.content_db)
	return state


func _json_round_trip(state: GameState) -> GameState:
	var payload: Variant = JSON.parse_string(JSON.stringify(state.save_payload()))
	var restored := _state()
	var errors := restored.load_payload(payload as Dictionary)
	assert_eq(errors.size(), 0, str(errors))
	return restored


func test_save_load_keeps_item_variants() -> void:
	var state := _state()
	assert_eq(state.bag.try_add(&"item.forge_spear", 1, &"spear_p2_w0"), InventoryBag.AddResult.OK)
	state.place_world_item(&"loc.reval_city", &"world.dropped.test.0", &"item.forge_spear",
		Vector2(3, 4), &"spear_p1_w2")
	var restored := _json_round_trip(state)
	var placement := restored.bag.find_placement(&"item.forge_spear")
	assert_true(placement != null, "spear still in the bag")
	if placement != null:
		assert_eq(placement.item_id, &"item.forge_spear", "item id unchanged")
		assert_eq(placement.variant, &"spear_p2_w0")
	var ground := restored.get_world_items(&"loc.reval_city")
	assert_eq(ground.size(), 1)
	assert_eq(String(ground[0].get("variant", "")), "spear_p1_w2")
	assert_eq(String(restored.take_world_item(&"loc.reval_city", &"world.dropped.test.0")["variant"]),
		"spear_p1_w2")


func test_equipped_variant_round_trips_and_returns_to_the_bag() -> void:
	var state := _state()
	state.bag.try_add(&"item.forge_spear", 1, &"spear_p3_w0")
	assert_true(state.equip_from_bag(&"right_hand", &"item.forge_spear"), "spear equipped")
	assert_eq(state.equipped_variant(&"right_hand"), &"spear_p3_w0")
	var restored := _json_round_trip(state)
	assert_eq(restored.equipped_item(&"right_hand"), &"item.forge_spear")
	assert_eq(restored.equipped_variant(&"right_hand"), &"spear_p3_w0")
	assert_true(restored.unequip_to_bag(&"right_hand"))
	assert_eq(restored.equipped_variant(&"right_hand"), &"")
	assert_eq(restored.bag.find_placement(&"item.forge_spear").variant, &"spear_p3_w0")


func test_old_saves_load_the_base_item() -> void:
	var state := _state()
	state.bag.try_add(&"item.forge_spear")
	var payload := state.save_payload()
	payload.erase("equipped_variants")
	var restored := _state()
	assert_eq(restored.load_payload(payload).size(), 0)
	assert_eq(restored.bag.find_placement(&"item.forge_spear").variant, &"")
	var row := payload["bag"]["placements"][0] as Dictionary
	assert_false(row.has("variant"), "base item writes no variant")


func test_battered_layer_iron_is_worn_once() -> void:
	var rig := _rig()
	var record := {"body": BODY, "id": "cit.test.rust", "wear": ["kettle_hat@p1_w2"]}
	CitizenWardrobe.dress(rig, record)
	var iron: BaseMaterial3D = null
	for child: Node in rig.skeleton().get_children():
		if child is MeshInstance3D and String(child.name).begins_with("Garment_wear_kettle_hat_"):
			iron = (child as MeshInstance3D).get_surface_override_material(0) as BaseMaterial3D
	assert_true(iron != null, "kettle hat iron keeps a StandardMaterial override")
	if iron != null:
		assert_eq(int(iron.get_meta(&"variant_wear", -1)), 2)
		var metallic := iron.metallic
		assert_true(metallic < 0.9, "battered iron is less bare metal (%.2f)" % metallic)
		CitizenWardrobe.weave(rig, record)
		assert_eq(iron.metallic, metallic, "a second weave does not wear it again")
	rig.queue_free()
