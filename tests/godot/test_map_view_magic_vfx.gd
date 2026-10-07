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


func test_bind_draws_knockback_cone_and_stagger_ground_ring() -> void:
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
	assert_eq(
		vfx.active_burst_count(),
		2,
		"stagger pulse draws a ground ring, not a second wind wedge"
	)
	assert_true(vfx.find_child("AreaPulseBurst", true, false) is Node3D)
	assert_true(vfx.find_child("AirGustBurst", true, false) is Node3D)
	root.free()


func test_bind_draws_projectile_orb_and_follows_logic_position() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var root := Node2D.new()
	tree.root.add_child(root)
	var vfx := MapViewMagicVfx.new()
	root.add_child(vfx)
	vfx.bind(32, root)
	var caster := Node2D.new()
	root.add_child(caster)
	var projectile := MagicProjectile2D.new()
	assert_true(
		projectile.configure(
			caster,
			&"spell.test",
			Vector2.RIGHT,
			{
				"delivery": {"kind": "projectile", "speed": 320.0, "range": 640.0},
				"impact": {"kind": "damage", "amount": 1.0, "damage_type": "fire"},
			}
		)
	)
	projectile.global_position = Vector2(64.0, 0.0)
	root.add_child(projectile)
	assert_eq(vfx.active_projectile_count(), 1)
	var orb := vfx.find_child("MagicProjectileOrb", true, false) as Node3D
	assert_true(orb != null)
	var start := orb.position
	projectile.advance(0.1)
	vfx.sync_tracked_projectiles(0.1)
	assert_true(orb.position.x > start.x)
	assert_almost_eq(orb.position.y, MapViewMagicVfx.PROJECTILE_HEIGHT, 0.001)
	root.free()


func test_sync_drops_orb_when_projectile_is_freed() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var root := Node2D.new()
	tree.root.add_child(root)
	var vfx := MapViewMagicVfx.new()
	root.add_child(vfx)
	vfx.bind(32, root)
	var caster := Node2D.new()
	root.add_child(caster)
	var projectile := MagicProjectile2D.new()
	assert_true(
		projectile.configure(
			caster,
			&"spell.test",
			Vector2.RIGHT,
			{
				"delivery": {"kind": "projectile", "speed": 320.0, "range": 640.0},
				"impact": {"kind": "damage", "amount": 1.0, "damage_type": "fire"},
			}
		)
	)
	root.add_child(projectile)
	assert_eq(vfx.active_projectile_count(), 1)
	# Fireball impact/expire free the logic node before the next view _process.
	projectile.free()
	assert_eq(vfx.active_projectile_count(), 0)
	root.free()


func test_invalid_cone_is_rejected() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := MapViewMagicVfx.new()
	tree.root.add_child(host)
	assert_true(host.play_knockback_cone(Vector2.ZERO, Vector2.RIGHT, 0.0, 90.0, 32) == null)
	assert_true(host.play_knockback_cone(Vector2.ZERO, Vector2.RIGHT, 112.0, 0.0, 32) == null)
	assert_eq(host.active_burst_count(), 0)
	host.free()


## R-1198: realistic Fireball / Earth Tremor / Iron Skin presentation.
func test_fire_projectile_streams_flame_and_explodes_on_impact() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var root := Node2D.new()
	tree.root.add_child(root)
	var vfx := MapViewMagicVfx.new()
	root.add_child(vfx)
	vfx.bind(32, root)
	var caster := Node2D.new()
	root.add_child(caster)
	var target := CombatTestDummy.new()
	root.add_child(target)
	target.global_position = Vector2(40.0, 0.0)
	var projectile := MagicProjectile2D.new()
	assert_true(
		projectile.configure(
			caster,
			&"spell.test",
			Vector2.RIGHT,
			{
				"delivery": {"kind": "projectile", "speed": 320.0, "range": 640.0},
				"impact": {"kind": "damage", "amount": 1.0, "damage_type": "fire"},
				"area": {"radius": 72.0, "effect": {"kind": "damage", "amount": 1.0}},
			}
		)
	)
	root.add_child(projectile)
	var orb := vfx.find_child("MagicProjectileOrb", true, false) as Node3D
	assert_true(orb != null)
	assert_true(orb.get_node_or_null("FlameTrail") is GPUParticles3D)
	assert_true(orb.get_node_or_null("SmokeTrail") is GPUParticles3D)
	assert_true(orb.get_node_or_null("Glow") is OmniLight3D)
	projectile.advance(0.1)
	var burst := vfx.find_child("FireBurst", true, false) as Node3D
	assert_true(burst != null, "fire impact spawns an explosion")
	for part: String in ["Scorch", "Flash", "Fireball", "Soot", "Embers"]:
		assert_true(burst.get_node_or_null(part) != null, "explosion part %s" % part)
	vfx.sync_tracked_projectiles(0.0)
	assert_eq(vfx.active_projectile_count(), 0)
	# The spent trail lingers as a burst so its world-space flame dies out.
	assert_true(vfx.find_child("MagicProjectileTrail", true, false) is Node3D)
	root.free()


func test_non_fire_projectile_keeps_plain_orb_without_explosion() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := MapViewMagicVfx.new()
	tree.root.add_child(host)
	var caster := Node2D.new()
	tree.root.add_child(caster)
	var projectile := MagicProjectile2D.new()
	assert_true(
		projectile.configure(
			caster,
			&"spell.test",
			Vector2.RIGHT,
			{
				"delivery": {"kind": "projectile", "speed": 320.0, "range": 640.0},
				"impact": {"kind": "damage", "amount": 1.0, "damage_type": "magic"},
			}
		)
	)
	var orb := host.play_projectile_orb(projectile)
	assert_true(orb.get_node_or_null("FlameTrail") == null)
	projectile.free()
	host.sync_tracked_projectiles(0.0)
	assert_eq(host.active_burst_count(), 0)
	caster.free()
	host.free()


func test_ground_pulse_draws_shock_cracks_dust_and_debris() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := MapViewMagicVfx.new()
	tree.root.add_child(host)
	var burst := host.play_area_pulse_ring(Vector2.ZERO, 96.0, 32)
	assert_true(burst != null)
	for part: String in ["PulseRing", "GroundCracks", "DustWave", "RimDust", "Debris"]:
		assert_true(burst.get_node_or_null(part) != null, "tremor part %s" % part)
	var rim := burst.get_node("RimDust") as GPUParticles3D
	assert_false(rim.emitting, "rim dust waits for the shock front")
	host._process(0.35)
	assert_true(rim.emitting)
	var ring := burst.get_node("PulseRing") as MeshInstance3D
	assert_true(ring.scale.x > 0.12 and ring.scale.x <= 1.0)
	host._process(MapViewMagicVfx.PULSE_DURATION_SEC)
	assert_eq(host.active_burst_count(), 0)
	host.free()


func test_damage_reduction_wraps_rig_overlay_in_iron_and_restores_it() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := MapViewMagicVfx.new()
	tree.root.add_child(host)
	var actor := CombatTestDummy.new()
	tree.root.add_child(actor)
	var rig := Node3D.new()
	tree.root.add_child(rig)
	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	rig.add_child(body)
	var silhouette := StandardMaterial3D.new()
	body.material_overlay = silhouette
	host.bind_world(null, actor, rig)
	host.sync_ward(0.1)
	assert_eq(body.material_overlay, silhouette, "no ward without a modifier")
	assert_true(
		CombatTimedModifiers.apply_module_to(
			actor,
			{
				"kind": "damage_reduction",
				"modifier_id": "modifier.test_ward",
				"amount": 0.35,
				"duration_sec": 8.0,
			}
		)
	)
	host.sync_ward(0.1)
	var overlay := body.material_overlay as ShaderMaterial
	assert_true(overlay != null, "iron overlay applied")
	assert_eq(overlay.next_pass, silhouette, "occlusion silhouette stays chained")
	assert_true(host.ward_strength() > 0.0)
	assert_true(host.find_child("WardCastBurst", true, false) is Node3D)
	actor.combat_vitals.modifiers.clear()
	for _i: int in range(10):
		host.sync_ward(0.1)
	assert_eq(body.material_overlay, silhouette, "overlay restored after expiry")
	assert_eq(host.ward_strength(), 0.0)
	host.free()
	actor.free()
	rig.free()
