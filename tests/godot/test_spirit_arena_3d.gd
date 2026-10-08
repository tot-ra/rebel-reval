extends "res://tests/godot/test_case.gd"

## ADR 0038 / SA3D-1: arena disc, radius clamp, room hiding and exact restore.

var _root: Node3D
var _arena: SpiritArena3D
var _hero: Node3D
var _wall: Node3D
var _hidden_already: Node3D
var _lamp: OmniLight3D


func before_each() -> void:
	super.before_each()
	_root = Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_root)
	var actors := Node3D.new()
	_root.add_child(actors)
	_hero = Node3D.new()
	actors.add_child(_hero)
	_wall = Node3D.new()
	_root.add_child(_wall)
	_hidden_already = Node3D.new()
	_hidden_already.visible = false
	_root.add_child(_hidden_already)
	_lamp = OmniLight3D.new()
	_root.add_child(_lamp)
	_arena = SpiritArena3D.new()


func after_each() -> void:
	if _arena != null and _arena.is_open():
		_arena.close()
	_root.free()
	super.after_each()


func test_clamp_keeps_fighters_on_the_disc() -> void:
	assert_true(_arena.open(_root, Vector3(10, 2, 10), [_hero], false, 5.0))
	var inside := Vector3(12, 2, 10)
	assert_eq(_arena.clamp_position(inside), inside)
	var pulled := _arena.clamp_position(Vector3(30, 7, 10))
	assert_almost_eq(pulled.x, 15.0, 0.001)
	assert_almost_eq(pulled.z, 10.0, 0.001)
	assert_almost_eq(pulled.y, 7.0, 0.001)
	assert_true(_arena.contains(pulled))
	assert_false(_arena.contains(Vector3(30, 0, 10)))


func test_outdoors_hides_nothing() -> void:
	_arena.open(_root, Vector3.ZERO, [_hero], false)
	assert_true(_wall.visible)
	assert_eq(_arena.hidden_nodes().size(), 0)


func test_indoors_strips_room_but_keeps_fighters_and_lights() -> void:
	_arena.open(_root, Vector3.ZERO, [_hero], true)
	assert_false(_wall.visible)
	assert_true(_hero.visible)
	assert_true(_hero.get_parent().visible, "fighter's ancestor stays")
	assert_true(_lamp.visible)
	assert_true(_arena.visible)


func test_close_restores_exact_visibility() -> void:
	_arena.open(_root, Vector3.ZERO, [_hero], true)
	_arena.close()
	assert_true(_wall.visible)
	assert_false(_hidden_already.visible, "already-hidden nodes stay hidden")
	assert_false(_arena.is_open())


func test_open_twice_and_bad_radius_refuse() -> void:
	assert_false(_arena.open(_root, Vector3.ZERO, [], false, 0.0))
	assert_true(_arena.open(_root, Vector3.ZERO))
	assert_false(_arena.open(_root, Vector3.ZERO))
