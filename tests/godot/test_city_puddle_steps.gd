extends "res://tests/godot/test_case.gd"

const VfxScript := preload("res://scripts/city/city_puddle_step_vfx.gd")
const PUDDLE_SURFACE := &"puddle"


func test_only_filled_puddle_surface_requests_a_splash() -> void:
	assert_true(CityMapView.should_splash_on_footstep(PUDDLE_SURFACE))
	assert_false(CityMapView.should_splash_on_footstep(&"mud"))
	assert_false(CityMapView.should_splash_on_footstep(&"water_shallow"))
	assert_false(CityMapView.should_splash_on_footstep(&"stone"))


func test_puddle_contact_creates_bounded_transient_ring_and_splash() -> void:
	var vfx := VfxScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(vfx)
	assert_true(vfx.play_step(Vector3(1.0, 0.0, 2.0), Vector2.RIGHT))
	assert_eq(vfx.active_effect_count(), 1)
	var effect := vfx.get_child(0) as Node3D
	assert_ne(effect.get_node_or_null("RippleRing"), null)
	assert_ne(effect.get_node_or_null("Splash"), null)
	for _i in VfxScript.MAX_ACTIVE + 2:
		vfx.play_step(Vector3.ZERO)
	assert_eq(vfx.active_effect_count(), VfxScript.MAX_ACTIVE)
	vfx._process(VfxScript.RING_LIFETIME + 0.01)
	assert_eq(vfx.active_effect_count(), 0)
	vfx.free()
