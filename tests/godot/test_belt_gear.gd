extends "res://tests/godot/test_case.gd"

## Belt gear (task R-2033, docs/SYSTEMS/EQUIPMENT_VARIANTS.md "Belt gear"): rigid buckle,
## strap-end, mounts, purse, keys and beads hung by prestige on the body's baked belt.

const BeltGear := preload("res://scripts/city/belt_gear.gd")
const EquipmentVariant := preload("res://scripts/city/equipment_variant.gd")
const BODY := "citizen_m_adult_average"
const CENSUS := "res://content/world/reval_city/citizens.json"
const RICH_WEAR := ["hood@p3_w0", "keys@p3_w0", "paternoster@p3_w0"]


func _rig() -> SharedCharacterRig:
	var scene := load("res://assets/characters/variants/%s.tscn" % BODY) as PackedScene
	var rig := scene.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	return rig


func _record(status: String, wear: Array) -> Dictionary:
	return {
		"id": "cit.test.%s" % status, "body": BODY, "sex": "m", "age": 40, "status": status,
		"trade": "merchant", "faction": "none", "wear": wear,
		"wear_dye": {"paternoster": [0.70, 0.42, 0.12]},
	}


## Variant ids of the parts hung on `rig`.
func _parts(rig: SharedCharacterRig) -> Array[String]:
	var out: Array[String] = []
	var gear := rig.skeleton().get_node_or_null(NodePath(BeltGear.NODE_NAME))
	if gear == null:
		return out
	for node: Node in gear.find_children("*", "Node3D", true, false):
		if node.has_meta(&"variant"):
			out.append(String(node.get_meta(&"variant")))
	return out


func test_every_part_is_shipped() -> void:
	for id: String in [
		"buckle_p1_w1", "buckle_p2_w1", "buckle_p3_w1", "strap_end_p2_w1", "strap_end_p3_w1",
		"mount_p3_w1", "purse_p1_w1", "purse_p2_w1", "purse_p3_w1", "keys_p1_w1", "paternoster_p1_w1",
	]:
		assert_true(ResourceLoader.exists("%s/%s.glb" % [BeltGear.DIR, id]), id)


func test_prestige_matches_the_census_cells() -> void:
	# The runtime mirror of citizen_wardrobe.py prestige_of must agree with every own-cell layer.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CENSUS))
	var checked := 0
	for record: Dictionary in data["residents"]:
		if (record.get("duty", {}) as Dictionary).get("kit", "") != "":
			continue
		for entry: String in record.get("wear", []):
			var cell := EquipmentVariant.split(entry)[1]
			if EquipmentVariant.is_cell(cell):
				assert_eq(BeltGear.prestige_of(record), EquipmentVariant.prestige(cell), String(record["id"]))
				checked += 1
				break
	assert_true(checked > 1000, "census residents with an own cell: %d" % checked)
	# Unknown statuses are poor, as citizen_wardrobe.py wealth_of defaults them.
	assert_eq(BeltGear.prestige_of({"status": "vagrant", "trade": "beggar"}), 1)


func test_the_baked_belt_is_found() -> void:
	var rig := _rig()
	var ring := BeltGear.girdle(rig)
	assert_false(ring.is_empty(), "the base outfit carries a *_belt_leather band")
	var radii: Vector2 = ring["radii"]
	assert_true(radii.x > 0.1 and radii.x < 0.3 and radii.y > 0.08 and radii.y < 0.3, str(radii))
	rig.free()


func test_tiers_hang_their_own_parts() -> void:
	var poor := _rig()
	CitizenWardrobe.dress(poor, _record("labourer", ["coif@p1_w2"]))
	var parts := _parts(poor)
	assert_true("buckle_p1_w2" in parts and "purse_p1_w2" in parts, str(parts))
	var strap_end := func(p: String) -> bool: return p.begins_with("strap_end")
	assert_false(parts.any(strap_end), "p1 has no strap-end")
	poor.free()
	var rich := _rig()
	CitizenWardrobe.dress(rich, _record("patrician", RICH_WEAR))
	parts = _parts(rich)
	var expected := [
		"buckle_p3_w0", "strap_end_p3_w0", "purse_p3_w0", "keys_p1_w0", "paternoster_p1_w1"
	]
	for id: String in expected:
		assert_true(id in parts, "%s in %s" % [id, parts])
	assert_true(parts.count("mount_p3_w0") >= 3, "a patrician's belt is mounted: %s" % [parts])
	# Beads take no wear finish (bone, wood and amber do not rust). Keys and beads are
	# rigid parts now, not the fitted layers.
	assert_false(rich.has_garment(&"wear_keys"))
	assert_false(rich.has_garment(&"wear_paternoster"))
	# Dressing twice hangs nothing twice.
	CitizenWardrobe.dress(rich, _record("patrician", RICH_WEAR))
	assert_eq(rich.skeleton().get_children().filter(
		func(n: Node) -> bool: return n.name == BeltGear.NODE_NAME
	).size(), 1)
	rich.free()


func test_armour_and_aprons_cover_the_belt() -> void:
	var armed := _rig()
	CitizenWardrobe.dress(armed, _record("burgher_merchant", ["gambeson@p2_w1"]))
	assert_true(_parts(armed).is_empty(), "nothing hangs under an aketon")
	armed.free()
	var smith := _rig()
	CitizenWardrobe.dress(smith, _record("master_craftsman", ["smith_apron@p2_w1"]))
	var parts := _parts(smith)
	var buckle := func(p: String) -> bool: return p.begins_with("buckle")
	assert_false(parts.any(buckle), "no buckle behind an apron")
	assert_true("purse_p2_w1" in parts, str(parts))
	smith.free()


func test_bead_kind_follows_the_dye() -> void:
	var record := _record("patrician", [])
	assert_eq(BeltGear.bead_kind(record, 3), "amber")
	record["wear_dye"] = {"paternoster": [0.55, 0.40, 0.22]}
	assert_eq(BeltGear.bead_kind(record, 1), "boxwood")
	assert_eq(BeltGear.bead_kind(record, 2), "bone")
	record["wear_dye"] = {"paternoster": [0.62, 0.16, 0.12]}
	assert_eq(BeltGear.bead_kind(record, 3), "coral")
