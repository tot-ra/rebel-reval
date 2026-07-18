class_name ComparisonRoomSpecs
extends RefCounted

## Shared layout data for the P0-035 comparison room variants.

const ROOM_SIZE := Vector2(1280, 720)

const WALL_SPECS := [
	{"name": "LeftCollisionWall", "center": Vector2(80, 360), "size": Vector2(60, 600)},
	{"name": "RightCollisionWall", "center": Vector2(1200, 360), "size": Vector2(60, 600)},
	{"name": "TopCollisionWallA", "center": Vector2(375, 80), "size": Vector2(590, 55)},
	{"name": "TopCollisionWallB", "center": Vector2(1015, 80), "size": Vector2(370, 55)},
	{"name": "BottomCollisionWall", "center": Vector2(640, 650), "size": Vector2(1120, 60)},
	{"name": "CollisionTable", "center": Vector2(520, 370), "size": Vector2(180, 70)},
]

const NPC_SPECS := [
	{"name": "Mart", "position": Vector2(390, 305), "color": Color(0.64, 0.64, 0.68, 1.0), "role": "ambient"},
	{"name": "Aita", "position": Vector2(615, 280), "color": Color(0.68, 0.44, 0.85, 1.0), "role": "dialogue"},
	{"name": "Kaja", "position": Vector2(760, 505), "color": Color(0.90, 0.63, 0.33, 1.0), "role": "ambient"},
	{"name": "Henning", "position": Vector2(965, 345), "color": Color(0.88, 0.25, 0.22, 1.0), "role": "combat"},
	{"name": "Jürgen", "position": Vector2(995, 515), "color": Color(0.30, 0.70, 0.46, 1.0), "role": "ambient"},
	{"name": "Greybox Guard", "position": Vector2(325, 535), "color": Color(0.76, 0.76, 0.32, 1.0), "role": "ambient"},
]
