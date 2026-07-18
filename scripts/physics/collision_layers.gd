class_name CollisionLayers
extends RefCounted

## Shared 2D physics layer bits for the logic plane.
## World geometry keeps layer 1 so existing StaticBody2D defaults still work.

const WORLD := 1
const PLAYER := 2
const NPC := 4

const MASK_WORLD := WORLD
const MASK_PLAYER := WORLD
const MASK_NPC := WORLD
## Area2D sensors that should detect character logic bodies.
const MASK_ACTORS := PLAYER | NPC


static func apply_player(body: CharacterBody2D) -> void:
	body.collision_layer = PLAYER
	body.collision_mask = MASK_PLAYER
	body.collision_priority = 1.0


static func apply_npc(body: CharacterBody2D) -> void:
	body.collision_layer = NPC
	body.collision_mask = MASK_NPC
	body.collision_priority = 0.0
