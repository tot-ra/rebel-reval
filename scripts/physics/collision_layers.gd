class_name CollisionLayers
extends RefCounted

## Shared 2D physics layer bits for the logic plane.
## World geometry keeps layer 1 so existing StaticBody2D defaults still work.

const WORLD := 1
const PLAYER := 2
const NPC := 4
## Traversable water (ADR 0021). The player does not mask it, so Kalev can wade and
## swim; NPCs still treat it as a wall until they get their own water rules.
const WATER := 8
## Ambient crowd (census citizens, people at work on sites). Timetable-driven, so
## the player never collides with them; CrowdYield moves them aside instead.
const CROWD := 16

const MASK_WORLD := WORLD
const MASK_PLAYER := WORLD | NPC
const MASK_NPC := WORLD | PLAYER | WATER
## Area2D sensors that should detect character logic bodies.
const MASK_ACTORS := PLAYER | NPC | CROWD


static func apply_player(body: CharacterBody2D) -> void:
	body.collision_layer = PLAYER
	body.collision_mask = MASK_PLAYER
	body.collision_priority = 1.0
	body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


static func apply_npc(body: CharacterBody2D) -> void:
	body.collision_layer = NPC
	body.collision_mask = MASK_NPC
	body.collision_priority = 0.5
	body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


## Crowd bodies are sensors for interaction only: they sit on their own layer and
## mask nothing, so nobody can be blocked by (or stuck behind) the crowd.
static func apply_crowd(body: CharacterBody2D) -> void:
	body.collision_layer = CROWD
	body.collision_mask = 0
	body.collision_priority = 0.5
	body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
