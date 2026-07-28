class_name MapViewUrbanFauna
extends Node3D

## Deterministic ambient urban mammals for Lower Town (P2-024). Visual actors
## only: no collision, gameplay interaction, or GameState writes.

const BirdAmbientAudio := preload("res://scripts/map/view3d/map_view_bird_ambient_audio.gd")
const FaunaContext := preload("res://scripts/map/view3d/map_view_fauna_context.gd")
const GroundWander := preload("res://scripts/map/view3d/map_view_ground_wander.gd")
const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const MammalMeshes := preload("res://scripts/map/view3d/map_view_mammal_meshes.gd")
const MedievalAnimalModels := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")

const MAX_CONCURRENT_FAUNA := 8
const FLEE_RADIUS := 5.5
const FLEE_SPEED := 4.2
const TETHER_SPEED := 0.24
const WANDER_SPEED := 0.62
const SCURRY_SPEED := 1.35

const URBAN_SPECIES: Array[StringName] = [
	MammalSpecies.SPECIES_CAT,
	MammalSpecies.SPECIES_DOG,
	MammalSpecies.SPECIES_HORSE,
	MammalSpecies.SPECIES_RAT,
]

const BEHAVIOR_TETHER := &"tether"
const BEHAVIOR_WANDER := &"wander"
const BEHAVIOR_IDLE := &"idle"
const BEHAVIOR_FLEE := &"flee"

## Authored Lower Town placements in map cell coordinates beside service yards and
## patrol spines. Radii stay inside yards so actors never overlap quest anchors.
const LOWER_TOWN_PLACEMENTS: Array[Dictionary] = [
	{"cell": Vector2i(90, 70), "species": MammalSpecies.SPECIES_HORSE, "behavior": BEHAVIOR_TETHER, "radius": 2.4},
	{"cell": Vector2i(74, 56), "species": MammalSpecies.SPECIES_DOG, "behavior": BEHAVIOR_WANDER, "radius": 3.6},
	{"cell": Vector2i(80, 62), "species": MammalSpecies.SPECIES_CAT, "behavior": BEHAVIOR_IDLE, "radius": 1.4},
	{"cell": Vector2i(66, 52), "species": MammalSpecies.SPECIES_RAT, "behavior": BEHAVIOR_FLEE, "radius": 2.8},
	{"cell": Vector2i(85, 58), "species": MammalSpecies.SPECIES_CAT, "behavior": BEHAVIOR_IDLE, "radius": 1.2},
	{"cell": Vector2i(72, 54), "species": MammalSpecies.SPECIES_DOG, "behavior": BEHAVIOR_WANDER, "radius": 3.2},
	{"cell": Vector2i(68, 48), "species": MammalSpecies.SPECIES_RAT, "behavior": BEHAVIOR_FLEE, "radius": 2.4},
	{"cell": Vector2i(92, 66), "species": MammalSpecies.SPECIES_HORSE, "behavior": BEHAVIOR_TETHER, "radius": 2.0},
]

## Knights' stable yard and court beside knights_hall. Authored west of the
## south_watch spine so horses never block King Street or Karja transitions.
const SOUTH_QUARTER_PLACEMENTS: Array[Dictionary] = [
	{"cell": Vector2i(249, 44), "species": MammalSpecies.SPECIES_HORSE, "behavior": BEHAVIOR_TETHER, "radius": 2.2},
	{"cell": Vector2i(254, 46), "species": MammalSpecies.SPECIES_HORSE, "behavior": BEHAVIOR_TETHER, "radius": 2.0},
	{"cell": Vector2i(275, 30), "species": MammalSpecies.SPECIES_DOG, "behavior": BEHAVIOR_WANDER, "radius": 2.8},
]

const MAP_PLACEMENTS: Dictionary = {
	&"lower_town_slice": LOWER_TOWN_PLACEMENTS,
	&"south_quarter": SOUTH_QUARTER_PLACEMENTS,
}

var _actors: Array[Node3D] = []
var _fauna_enabled := true
var _map_id := &""
var _context := &""
var _cell_size := 32
var _elapsed := 0.0


func _ready() -> void:
	pass


func set_fauna_enabled(enabled: bool) -> void:
	_fauna_enabled = enabled
	for actor in _actors:
		actor.visible = enabled


func active_fauna_count() -> int:
	var count := 0
	for actor in _actors:
		if actor.visible:
			count += 1
	return count


func configure(map_id: StringName, context: StringName, cell_size: int) -> void:
	_map_id = map_id
	_context = context
	_cell_size = maxi(cell_size, 1)
	_elapsed = 0.0
	_rebuild_actors()


func sync(context: StringName, delta: float, listener_position: Vector3, enabled: bool = true) -> void:
	_fauna_enabled = enabled
	_context = context
	if not _should_run():
		for actor in _actors:
			actor.visible = false
		return
	_elapsed += delta
	for actor in _actors:
		actor.visible = true
		_advance_actor(actor, listener_position, delta)


static func distinct_species_for_map(map_id: StringName) -> Array[StringName]:
	var placements: Array = MAP_PLACEMENTS.get(map_id, [])
	var seen: Dictionary = {}
	var species_list: Array[StringName] = []
	for placement: Dictionary in placements:
		var species: StringName = placement.get("species", &"")
		if species.is_empty() or seen.has(species):
			continue
		seen[species] = true
		species_list.append(species)
	return species_list


static func placement_count_for_map(map_id: StringName) -> int:
	return (MAP_PLACEMENTS.get(map_id, []) as Array).size()


static func hash_seed(seed_key: StringName, placement_index: int, salt: int = 0) -> int:
	return hash([String(seed_key), placement_index, salt])


func actor_has_collision(actor: Node3D) -> bool:
	return _node_has_collision(actor)


func actor_offset_from_home(actor: Node3D) -> float:
	var home: Vector3 = actor.get_meta(&"home", Vector3.ZERO)
	return Vector2(actor.position.x - home.x, actor.position.z - home.z).length()


func _should_run() -> bool:
	return _fauna_enabled and FaunaContext.supports_urban_fauna(_map_id) and not _context.is_empty()


func _rebuild_actors() -> void:
	for actor in _actors:
		actor.queue_free()
	_actors.clear()
	if not FaunaContext.supports_urban_fauna(_map_id):
		return
	var placements: Array = MAP_PLACEMENTS.get(_map_id, [])
	var limit := mini(placements.size(), MAX_CONCURRENT_FAUNA)
	for index in limit:
		var placement: Dictionary = placements[index]
		var actor := _make_actor(index, placement)
		add_child(actor)
		_actors.append(actor)


func _make_actor(index: int, placement: Dictionary) -> Node3D:
	var species: StringName = placement.get("species", &"")
	var behavior: StringName = placement.get("behavior", BEHAVIOR_IDLE)
	var radius := float(placement.get("radius", 1.0))
	var cell: Vector2i = placement.get("cell", Vector2i.ZERO)
	var pose := _pose_for_behavior(behavior, species)
	var home := MapViewBridge.cell_center_to_world(cell, _cell_size)
	var actor := Node3D.new()
	actor.name = "UrbanFauna%d" % index
	if MedievalAnimalModels.add_model(actor, species) == null:
		var mesh := MammalMeshes.mesh_for(species, pose)
		var model := MeshInstance3D.new()
		model.name = "Model"
		if mesh != null:
			model.mesh = mesh
			var aabb := mesh.get_aabb()
			model.position.y = -aabb.position.y
		_apply_variant_material(model, species, hash_seed(_map_id, index))
		actor.add_child(model)
	actor.position = home
	actor.rotation.y = _yaw_for_placement(index)
	actor.set_meta(&"species", species)
	actor.set_meta(&"behavior", behavior)
	GroundWander.setup(actor, _map_id, index, _wander_config(behavior, home, radius))
	return actor


static func _wander_config(behavior: StringName, home: Vector3, radius: float) -> Dictionary:
	var config := {"home": home, "radius": radius}
	match behavior:
		BEHAVIOR_TETHER:
			config["speed"] = TETHER_SPEED
			config["roam_scale"] = 0.42
			config["pause_range"] = Vector2(1.8, 4.8)
		BEHAVIOR_FLEE:
			config["speed"] = SCURRY_SPEED
			config["roam_scale"] = 0.82
			config["pause_range"] = Vector2(0.6, 2.0)
			config["flee_speed"] = FLEE_SPEED
			config["flee_radius"] = FLEE_RADIUS
		BEHAVIOR_IDLE:
			# Resting cats hold their pose; a dozing animal that slides around
			# reads worse than one that simply sits still.
			config["speed"] = 0.0
		_:
			config["speed"] = WANDER_SPEED
			config["roam_scale"] = 0.82
			config["pause_range"] = Vector2(0.9, 3.2)
	return config


func _advance_actor(actor: Node3D, listener_position: Vector3, delta: float) -> void:
	var previous_position := actor.position
	GroundWander.advance(actor, _map_id, listener_position, delta)
	MedievalAnimalModels.sync_animation(actor, previous_position, delta)


static func _pose_for_behavior(behavior: StringName, species: StringName) -> StringName:
	match behavior:
		BEHAVIOR_IDLE:
			return MammalSpecies.POSE_RESTING if species == MammalSpecies.SPECIES_CAT else MammalSpecies.POSE_STANDING
		BEHAVIOR_TETHER:
			return MammalSpecies.POSE_GRAZING if species == MammalSpecies.SPECIES_HORSE else MammalSpecies.POSE_STANDING
		_:
			return MammalSpecies.default_pose(species)


func _yaw_for_placement(index: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_seed(_map_id, index, 31)
	return rng.randf_range(0.0, TAU)


func _apply_variant_material(model: MeshInstance3D, species: StringName, variant_seed: int) -> void:
	var colors := MammalSpecies.colors_for(species)
	var rng := RandomNumberGenerator.new()
	rng.seed = variant_seed
	var tint := colors[0].lerp(colors[mini(1, colors.size() - 1)], rng.randf_range(0.15, 0.55))
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.vertex_color_use_as_albedo = true
	material.metallic = 0.0
	material.roughness = 0.9
	model.material_override = material


func _node_has_collision(node: Node) -> bool:
	if node is CollisionObject3D:
		return true
	for child in node.get_children():
		if _node_has_collision(child):
			return true
	return false
