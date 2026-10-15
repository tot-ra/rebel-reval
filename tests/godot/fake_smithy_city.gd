extends Node
## City-free fixture for SmithyOpening tests: what the opening reads from the city level
## (player, world, plan). Without a plan the almshouse set falls back to offsets from the boy.
## Build one with `make()`; the caller frees it.

## Prologue flags each fixture city starts without (the session state is shared by tests).
const CLEARED_FLAGS: Array[StringName] = [
	&"flag.prologue.apprenticed",
	&"flag.prologue.saw_makers_mark",
	&"flag.prologue.lambert_calmed",
	&"flag.prologue.lambert_frightened",
	&"flag.prologue.struck_porter",
	&"flag.prologue.broke_porter",
	&"flag.prologue.punished_by_porter",
	&"flag.prologue.spared_porter",
]

var player: Node2D
var world: Node3D
var plan: Variant = null


## A city stand-in in the scene tree with the prologue flags cleared.
static func make() -> Node:
	for flag in CLEARED_FLAGS:
		SessionState.state.set_flag(flag, false)
	var city: Node = (load("res://tests/godot/fake_smithy_city.gd") as GDScript).new()
	city.player = Node2D.new()
	city.player.global_position = Vector2(10, 10) * CityPlan.LOGIC_PX_PER_UNIT
	city.add_child(city.player)
	city.world = Node3D.new()
	city.add_child(city.world)
	(Engine.get_main_loop() as SceneTree).root.add_child(city)
	return city


## Mounts the opening on `city` and opens the duel in place.
static func open_duel(city: Node) -> SmithyOpening:
	SmithyOpening.pending = true
	var opening := SmithyOpening.consume(city)
	opening.begin_duel()
	return opening
