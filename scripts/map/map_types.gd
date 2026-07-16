class_name MapTypes
extends RefCounted

## Shared identifiers and sizing for programmatic map authoring (P0-042).

const TERRAIN_GRASS := &"grass"
const TERRAIN_SAND := &"sand"
const TERRAIN_HAY := &"hay"
const TERRAIN_DIRT := &"dirt"
const TERRAIN_COBBLESTONE := &"cobblestone"
const TERRAIN_WATER := &"water"
const TERRAIN_STONE := &"stone"

const ALL_TERRAINS: Array[StringName] = [
	TERRAIN_GRASS,
	TERRAIN_SAND,
	TERRAIN_HAY,
	TERRAIN_DIRT,
	TERRAIN_COBBLESTONE,
	TERRAIN_WATER,
	TERRAIN_STONE,
]

const BUILDING_KIND_HOUSE := &"house"
const BUILDING_KIND_WALL := &"wall"

const ALL_BUILDING_KINDS: Array[StringName] = [
	BUILDING_KIND_HOUSE,
	BUILDING_KIND_WALL,
]

const PROP_KIND_ANVIL := &"anvil"
const PROP_KIND_HAY_STACK := &"hay_stack"
const PROP_KIND_CART := &"cart"
const PROP_KIND_WELL := &"well"
const PROP_KIND_BARRELS := &"barrels"

const ALL_PROP_KINDS: Array[StringName] = [
	PROP_KIND_ANVIL,
	PROP_KIND_HAY_STACK,
	PROP_KIND_CART,
	PROP_KIND_WELL,
	PROP_KIND_BARRELS,
]

const DEFAULT_CELL_SIZE := 32
const DEFAULT_SEED := 42042
