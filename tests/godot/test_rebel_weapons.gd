extends "res://tests/godot/test_case.gd"

## Rebel levy weapons (task R-2014, docs/SYSTEMS/EQUIPMENT_VARIANTS.md "Rebel levy weapons"):
## ten p1 variants, origin at the grip, sockets exported, real sizes, held scenes that keep
## the pole upright (flail, hayfork) or let the head hang by the leg (clubs, sickle).

const DIR := "res://assets/props/weapons/rebel"
## family -> [min, max] metres along the item's long axis (Godot +Y), and the held turn sign.
const FAMILIES := {
	"club_oak": [0.78, 0.92, -1.0],
	"club_ironbound": [0.74, 0.88, -1.0],
	"sickle": [0.2, 0.5, -1.0],
	"threshing_flail": [1.25, 1.4, 1.0],
	"hayfork": [1.6, 1.75, 1.0],
}


func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var b := mesh.transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func test_every_variant_is_shipped_with_sockets_and_real_size() -> void:
	for family: String in FAMILIES:
		for wear in ["w1", "w2"]:
			var id := "%s_p1_%s" % [family, wear]
			var scene := load("%s/%s/variants/%s.glb" % [DIR, family, id]) as PackedScene
			assert_true(scene != null, id)
			if scene == null:
				continue
			var item := scene.instantiate() as Node3D
			for sock in ["socket_grip", "socket_butt", "socket_tip"]:
				assert_true(item.find_child(sock, true, false) != null, "%s %s" % [id, sock])
			var box := _bounds(item)
			var lo: float = FAMILIES[family][0]
			var hi: float = FAMILIES[family][1]
			var extent := maxf(box.size.y, box.size.x)
			assert_true(extent >= lo and extent <= hi, "%s extent %.3f" % [id, extent])
			# Origin is the grip: inside the item, near the butt end of the long axis.
			assert_true(box.grow(0.03).has_point(Vector3.ZERO), "%s grip %s" % [id, box])
			item.free()


func test_held_scenes_carry_the_variant_and_the_carry_turn() -> void:
	for family: String in FAMILIES:
		for wear in ["w1", "w2"]:
			var id := "%s_p1_%s" % [family, wear]
			var path := "%s/%s/scenes/%s_held.tscn" % [DIR, family, id]
			var held := (load(path) as PackedScene).instantiate() as Node3D
			assert_eq(String(held.get_meta(&"variant", "")), id)
			assert_almost_eq(held.rotation.z, float(FAMILIES[family][2]) * PI * 0.5, 0.001, id)
			held.free()


func test_no_rehafted_scythe_is_shipped() -> void:
	# Research note R-2014: the straightened war scythe is first attested 1499, excluded for 1343.
	assert_false(DirAccess.dir_exists_absolute(DIR + "/scythe"), "re-hafted scythe must not ship")
	assert_false(DirAccess.dir_exists_absolute(DIR + "/war_scythe"), "re-hafted scythe must not ship")
