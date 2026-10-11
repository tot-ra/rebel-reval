extends "res://tests/godot/test_case.gd"

## Trail ring buffer behind a walker in grass (R-1327).


func test_cap_and_eviction_order() -> void:
	var buffer := VegetationInteractionBuffer.new()
	for i in VegetationInteractionBuffer.CAPACITY + 3:
		assert_true(buffer.push(Vector2(float(i), 0.0), Vector2.RIGHT, float(i) * 0.1))
	assert_eq(buffer.size(), VegetationInteractionBuffer.CAPACITY, "buffer stays capped")
	assert_eq(buffer.position_of(0), Vector2(3.0, 0.0), "oldest three were evicted first")


func test_close_steps_are_not_recorded() -> void:
	var buffer := VegetationInteractionBuffer.new()
	assert_true(buffer.push(Vector2.ZERO, Vector2.RIGHT, 0.0))
	assert_false(buffer.push(Vector2(0.1, 0.0), Vector2.RIGHT, 0.1), "under min spacing")
	assert_eq(buffer.size(), 1)


func test_press_decays_to_zero() -> void:
	var buffer := VegetationInteractionBuffer.new()
	buffer.push(Vector2.ZERO, Vector2.RIGHT, 0.0)
	assert_almost_eq(buffer.strength(0, 0.0), 1.0, 0.001)
	var half := buffer.strength(0, VegetationInteractionBuffer.LIFETIME * 0.5)
	assert_true(half > 0.0 and half < 1.0, "partway sprung back")
	assert_almost_eq(buffer.strength(0, VegetationInteractionBuffer.LIFETIME + 1.0), 0.0, 0.001)


func test_same_history_gives_same_array() -> void:
	var a := VegetationInteractionBuffer.new()
	var b := VegetationInteractionBuffer.new()
	for i in 5:
		a.push(Vector2(i, i * 0.5), Vector2(1, 0.5), i * 0.3)
		b.push(Vector2(i, i * 0.5), Vector2(1, 0.5), i * 0.3)
	assert_eq(a.to_shader_array(2.0), b.to_shader_array(2.0))
	assert_eq(a.to_shader_array(2.0).size(), VegetationInteractionBuffer.CAPACITY)
