extends "res://tests/godot/test_case.gd"

## R-913: view-only Air Gust cone. Gameplay tests stay in test_magic_air_gust.gd.


func test_knockback_cone_spawns_wedge_and_smoke() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := MapViewMagicVfx.new()
	tree.root.add_child(host)
	var burst := host.play_knockback_cone(Vector2.ZERO, Vector2.RIGHT, 112.0, 90.0, 32)
	assert_true(burst != null)
	assert_eq(host.active_burst_count(), 1)
	var wedge := burst.get_node_or_null("WindWedge") as MeshInstance3D
	assert_true(wedge != null)
	assert_true(wedge.mesh is ArrayMesh)
	var mesh := wedge.mesh as ArrayMesh
	assert_true(mesh.get_surface_count() >= 1)
	assert_true(mesh.surface_get_array_len(0) > 8)
	var smoke := burst.get_node_or_null("WindSmoke") as GPUParticles3D
	assert_true(smoke != null)
	assert_true(smoke.one_shot)
	assert_eq(smoke.material_override, MapViewMaterials.smoke())
	# +Z is cone forward after yaw; +X logic maps to world +X, so yaw is +90.
	assert_almost_eq(burst.rotation.y, TAU * 0.25, 0.001)
	host.free()


func test_bind_draws_knockback_cone_and_ignores_stagger_circle() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var root := Node2D.new()
	tree.root.add_child(root)
	var vfx := MapViewMagicVfx.new()
	root.add_child(vfx)
	vfx.bind(32, root)
	var caster := Node2D.new()
	root.add_child(caster)
	var knock := MagicAreaPulse2D.new()
	assert_true(knock.configure(
		caster,
		&"spell.test",
		112.0,
		{"kind": "knockback", "distance": 96.0, "duration_sec": 0.6},
		Vector2.RIGHT,
		90.0
	))
	root.add_child(knock)
	assert_eq(vfx.active_burst_count(), 1)
	var stagger := MagicAreaPulse2D.new()
	assert_true(stagger.configure(
		caster, &"spell.test", 96.0, {"kind": "stagger", "duration_sec": 1.5}
	))
	root.add_child(stagger)
	assert_eq(vfx.active_burst_count(), 1, "full-circle stagger must not grow a wind wedge")
	root.free()


func test_invalid_cone_is_rejected() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := MapViewMagicVfx.new()
	tree.root.add_child(host)
	assert_true(host.play_knockback_cone(Vector2.ZERO, Vector2.RIGHT, 0.0, 90.0, 32) == null)
	assert_true(host.play_knockback_cone(Vector2.ZERO, Vector2.RIGHT, 112.0, 0.0, 32) == null)
	assert_eq(host.active_burst_count(), 0)
	host.free()
