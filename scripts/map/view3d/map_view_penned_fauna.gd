class_name MapViewPennedFauna
extends Node3D

## Deterministic penned livestock and wild-margin mammals (P0-106). Visual actors
## only: no collision, gameplay interaction, or GameState writes.

const FaunaContext := preload("res://scripts/map/view3d/map_view_fauna_context.gd")
const GroundWander := preload("res://scripts/map/view3d/map_view_ground_wander.gd")
const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const MammalMeshes := preload("res://scripts/map/view3d/map_view_mammal_meshes.gd")
const MedievalAnimalModels := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const UrbanFauna := preload("res://scripts/map/view3d/map_view_urban_fauna.gd")

const MAX_CONCURRENT_FAUNA := 10
const FLEE_RADIUS := 6.5
const FLEE_SPEED := 5.0
const PEN_SPEED := 0.34
const TETHER_SPEED := 0.22
const WILD_SPEED := 0.85

const DOMESTIC_SPECIES: Array[StringName] = [
	MammalSpecies.SPECIES_CHICKEN,
	MammalSpecies.SPECIES_DUCK,
	MammalSpecies.SPECIES_GOOSE,
	MammalSpecies.SPECIES_PIG,
	MammalSpecies.SPECIES_COW,
]

const WILD_SPECIES: Array[StringName] = [
	MammalSpecies.SPECIES_HARE,
	MammalSpecies.SPECIES_RED_FOX,
	MammalSpecies.SPECIES_WOLF,
	MammalSpecies.SPECIES_BROWN_BEAR,
]

const BEHAVIOR_PEN := &"pen"
const BEHAVIOR_TETHER := UrbanFauna.BEHAVIOR_TETHER
const BEHAVIOR_FLEE := UrbanFauna.BEHAVIOR_FLEE

## Lower Town service-yard pens beside brewery and cooper rows. Wild mammals stay
## off dense urban maps per the signed P0-072 fauna bands.
const LOWER_TOWN_PLACEMENTS: Array[Dictionary] = [
	{"cell": Vector2i(74, 76), "species": MammalSpecies.SPECIES_CHICKEN, "behavior": BEHAVIOR_PEN, "radius": 1.8},
	{"cell": Vector2i(77, 78), "species": MammalSpecies.SPECIES_DUCK, "behavior": BEHAVIOR_PEN, "radius": 1.6},
	{"cell": Vector2i(80, 74), "species": MammalSpecies.SPECIES_GOOSE, "behavior": BEHAVIOR_PEN, "radius": 2.0},
	{"cell": Vector2i(28, 66), "species": MammalSpecies.SPECIES_PIG, "behavior": BEHAVIOR_PEN, "radius": 2.2},
	{"cell": Vector2i(82, 80), "species": MammalSpecies.SPECIES_COW, "behavior": BEHAVIOR_TETHER, "radius": 2.6},
]

## Merchant District west-yard pens beside Pikk/Lai. Static fence props remain on
## the map; cattle and sheep are runtime actors only (P4-023g).
const NORTH_QUARTER_PLACEMENTS: Array[Dictionary] = [
	{"cell": Vector2i(13, 68), "species": MammalSpecies.SPECIES_COW, "behavior": BEHAVIOR_TETHER, "radius": 2.4},
	{"cell": Vector2i(15, 72), "species": MammalSpecies.SPECIES_COW, "behavior": BEHAVIOR_PEN, "radius": 2.0},
	{"cell": Vector2i(11, 65), "species": MammalSpecies.SPECIES_COW, "behavior": BEHAVIOR_PEN, "radius": 1.8},
	{"cell": Vector2i(13, 97), "species": MammalSpecies.SPECIES_SHEEP, "behavior": BEHAVIOR_PEN, "radius": 2.0},
	{"cell": Vector2i(15, 100), "species": MammalSpecies.SPECIES_SHEEP, "behavior": BEHAVIOR_PEN, "radius": 1.8},
	{"cell": Vector2i(11, 93), "species": MammalSpecies.SPECIES_SHEEP, "behavior": BEHAVIOR_PEN, "radius": 1.8},
]

## Foreland farmstead pens plus signed outer-margin wild actors only.
const FORELAND_PLACEMENTS: Array[Dictionary] = [
	{"cell": Vector2i(35, 39), "species": MammalSpecies.SPECIES_CHICKEN, "behavior": BEHAVIOR_PEN, "radius": 1.6},
	{"cell": Vector2i(119, 89), "species": MammalSpecies.SPECIES_DUCK, "behavior": BEHAVIOR_PEN, "radius": 1.8},
	{"cell": Vector2i(121, 79), "species": MammalSpecies.SPECIES_GOOSE, "behavior": BEHAVIOR_PEN, "radius": 2.0},
	{"cell": Vector2i(146, 89), "species": MammalSpecies.SPECIES_PIG, "behavior": BEHAVIOR_PEN, "radius": 2.4},
	{"cell": Vector2i(125, 86), "species": MammalSpecies.SPECIES_COW, "behavior": BEHAVIOR_TETHER, "radius": 3.0},
	{"cell": Vector2i(132, 84), "species": &"goat", "behavior": BEHAVIOR_TETHER, "radius": 2.2},
	{"cell": Vector2i(20, 8), "species": MammalSpecies.SPECIES_HARE, "behavior": BEHAVIOR_FLEE, "radius": 4.0},
	{"cell": Vector2i(8, 30), "species": MammalSpecies.SPECIES_RED_FOX, "behavior": BEHAVIOR_FLEE, "radius": 5.0},
	{"cell": Vector2i(155, 115), "species": MammalSpecies.SPECIES_WOLF, "behavior": BEHAVIOR_FLEE, "radius": 6.0},
	{"cell": Vector2i(155, 8), "species": MammalSpecies.SPECIES_BROWN_BEAR, "behavior": BEHAVIOR_FLEE, "radius": 7.0},
]

const MAP_PLACEMENTS: Dictionary = {
	&"lower_town_slice": LOWER_TOWN_PLACEMENTS,
	&"north_quarter": NORTH_QUARTER_PLACEMENTS,
	&"viru_gate_foreland": FORELAND_PLACEMENTS,
}

var _actors: Array[Node3D] = []
var _fauna_enabled := true
var _map_id := &""
var _context := &""
var _cell_size := 32
var _elapsed := 0.0


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


static func distinct_domestic_species_for_map(map_id: StringName) -> Array[StringName]:
	return _distinct_species_from_placements(map_id, DOMESTIC_SPECIES)


static func distinct_wild_species_for_map(map_id: StringName) -> Array[StringName]:
	return _distinct_species_from_placements(map_id, WILD_SPECIES)


static func placement_count_for_map(map_id: StringName) -> int:
	return (MAP_PLACEMENTS.get(map_id, []) as Array).size()


static func hash_seed(seed_key: StringName, placement_index: int, salt: int = 0) -> int:
	return UrbanFauna.hash_seed(seed_key, placement_index, salt)


func actor_has_collision(actor: Node3D) -> bool:
	return _node_has_collision(actor)


func actor_offset_from_home(actor: Node3D) -> float:
	var home: Vector3 = actor.get_meta(&"home", Vector3.ZERO)
	return Vector2(actor.position.x - home.x, actor.position.z - home.z).length()


static func _distinct_species_from_placements(
	map_id: StringName,
	required_pool: Array[StringName]
) -> Array[StringName]:
	var placements: Array = MAP_PLACEMENTS.get(map_id, [])
	var seen: Dictionary = {}
	var species_list: Array[StringName] = []
	for placement: Dictionary in placements:
		var species: StringName = placement.get("species", &"")
		if species.is_empty() or seen.has(species) or not species in required_pool:
			continue
		seen[species] = true
		species_list.append(species)
	return species_list


func _should_run() -> bool:
	return _fauna_enabled and FaunaContext.supports_penned_fauna(_map_id) and not _context.is_empty()


func _rebuild_actors() -> void:
	for actor in _actors:
		actor.queue_free()
	_actors.clear()
	if not FaunaContext.supports_penned_fauna(_map_id):
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
	var behavior: StringName = placement.get("behavior", BEHAVIOR_PEN)
	var radius := float(placement.get("radius", 1.0))
	var cell: Vector2i = placement.get("cell", Vector2i.ZERO)
	var pose := _pose_for_behavior(behavior, species)
	var home := MapViewBridge.cell_center_to_world(cell, _cell_size)
	var actor := Node3D.new()
	actor.name = "PennedFauna%d" % index
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
			config["pause_range"] = Vector2(2.4, 6.0)
		BEHAVIOR_FLEE:
			config["speed"] = WILD_SPEED
			config["roam_scale"] = 0.78
			config["pause_range"] = Vector2(0.8, 2.6)
			config["flee_speed"] = FLEE_SPEED
			config["flee_radius"] = FLEE_RADIUS
		_:
			config["speed"] = PEN_SPEED
			config["roam_scale"] = 0.62
			config["pause_range"] = Vector2(1.6, 4.4)
	return config


func _advance_actor(actor: Node3D, listener_position: Vector3, delta: float) -> void:
	var previous_position := actor.position
	GroundWander.advance(actor, _map_id, listener_position, delta)
	MedievalAnimalModels.sync_animation(actor, previous_position, delta)


static func _pose_for_behavior(behavior: StringName, species: StringName) -> StringName:
	match behavior:
		BEHAVIOR_TETHER:
			return MammalSpecies.POSE_GRAZING
		BEHAVIOR_FLEE:
			return MammalSpecies.POSE_STANDING
		_:
			if species in [MammalSpecies.SPECIES_CHICKEN, MammalSpecies.SPECIES_DUCK, MammalSpecies.SPECIES_GOOSE]:
				return MammalSpecies.POSE_STANDING
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
