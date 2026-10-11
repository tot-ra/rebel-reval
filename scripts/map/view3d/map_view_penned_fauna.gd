class_name MapViewPennedFauna
extends Node3D

## Deterministic penned livestock and wild-margin mammals (P0-106). Visual actors
## only: no collision, gameplay interaction, or GameState writes.

const CrowdRenderer := preload("res://scripts/map/view3d/map_view_crowd_renderer.gd")
const FaunaContext := preload("res://scripts/map/view3d/map_view_fauna_context.gd")
const GroundWander := preload("res://scripts/map/view3d/map_view_ground_wander.gd")
const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const MammalMeshes := preload("res://scripts/map/view3d/map_view_mammal_meshes.gd")
const MedievalAnimalModels := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const UrbanFauna := preload("res://scripts/map/view3d/map_view_urban_fauna.gd")

const MAX_CONCURRENT_FAUNA := 11
const FLEE_RADIUS := 6.5
const FLEE_SPEED := 5.0
const PEN_SPEED := 0.34
const TETHER_SPEED := 0.22
const WILD_SPEED := 0.85

## Herd LOD (P0-159). Wandering actors keep their animated GLB only inside
## FAUNA_DETAIL_RANGE; past it the same model is drawn by a per-model
## MultiMesh stand-in in bind pose. A placement's optional `herd` count adds
## static companions on the P0-152 crowd path so pens read as flocks without
## more animated actors. Both instanced layers cull at HERD_VISIBILITY_RANGE.
const FAUNA_DETAIL_RANGE := 55.0
const HERD_VISIBILITY_RANGE := 120.0
## Concurrent cap for instanced herd companions across all pens on a map.
const MAX_HERD_COMPANIONS := 24
## Companions stand inside this share of the pen radius so the wandering actor
## keeps room to move between them.
const HERD_RADIUS_SCALE := 0.85

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
	MammalSpecies.SPECIES_ELK,
]

const BEHAVIOR_PEN := &"pen"
const BEHAVIOR_TETHER := UrbanFauna.BEHAVIOR_TETHER
const BEHAVIOR_FLEE := UrbanFauna.BEHAVIOR_FLEE

## Lower Town service-yard pens beside brewery and cooper rows. Wild mammals stay
## off dense urban maps per the signed P0-072 fauna bands.
const LOWER_TOWN_PLACEMENTS: Array[Dictionary] = [
	{
		"cell": Vector2i(74, 76),
		"species": MammalSpecies.SPECIES_CHICKEN,
		"behavior": BEHAVIOR_PEN,
		"radius": 1.8,
		"herd": 4
	},
	{
		"cell": Vector2i(77, 78),
		"species": MammalSpecies.SPECIES_DUCK,
		"behavior": BEHAVIOR_PEN,
		"radius": 1.6,
		"herd": 2
	},
	{
		"cell": Vector2i(80, 74),
		"species": MammalSpecies.SPECIES_GOOSE,
		"behavior": BEHAVIOR_PEN,
		"radius": 2.0,
		"herd": 2
	},
	{
		"cell": Vector2i(24, 72),
		"species": MammalSpecies.SPECIES_PIG,
		"behavior": BEHAVIOR_PEN,
		"radius": 2.2
	},
	{
		"cell": Vector2i(80, 76),
		"species": MammalSpecies.SPECIES_COW,
		"behavior": BEHAVIOR_TETHER,
		"radius": 2.0
	},
]

## Merchant District west-yard pens beside Pikk/Lai. Static fence props remain on
## the map; cattle and sheep are runtime actors only (P4-023g).
const NORTH_QUARTER_PLACEMENTS: Array[Dictionary] = [
	{
		"cell": Vector2i(13, 68),
		"species": MammalSpecies.SPECIES_COW,
		"behavior": BEHAVIOR_TETHER,
		"radius": 2.4
	},
	{
		"cell": Vector2i(15, 72),
		"species": MammalSpecies.SPECIES_COW,
		"behavior": BEHAVIOR_PEN,
		"radius": 2.0
	},
	{
		"cell": Vector2i(11, 65),
		"species": MammalSpecies.SPECIES_COW,
		"behavior": BEHAVIOR_PEN,
		"radius": 1.8
	},
	{
		"cell": Vector2i(13, 97),
		"species": MammalSpecies.SPECIES_SHEEP,
		"behavior": BEHAVIOR_PEN,
		"radius": 2.0,
		"herd": 2
	},
	{
		"cell": Vector2i(15, 100),
		"species": MammalSpecies.SPECIES_SHEEP,
		"behavior": BEHAVIOR_PEN,
		"radius": 1.8,
		"herd": 2
	},
	{
		"cell": Vector2i(11, 93),
		"species": MammalSpecies.SPECIES_SHEEP,
		"behavior": BEHAVIOR_PEN,
		"radius": 1.8
	},
]

## Foreland farmstead pens plus signed outer-margin wild actors only.
const FORELAND_PLACEMENTS: Array[Dictionary] = [
	{
		"cell": Vector2i(35, 39),
		"species": MammalSpecies.SPECIES_CHICKEN,
		"behavior": BEHAVIOR_PEN,
		"radius": 1.6,
		"herd": 3
	},
	{
		"cell": Vector2i(119, 89),
		"species": MammalSpecies.SPECIES_DUCK,
		"behavior": BEHAVIOR_PEN,
		"radius": 1.8
	},
	{
		"cell": Vector2i(121, 79),
		"species": MammalSpecies.SPECIES_GOOSE,
		"behavior": BEHAVIOR_PEN,
		"radius": 2.0
	},
	{
		"cell": Vector2i(146, 89),
		"species": MammalSpecies.SPECIES_PIG,
		"behavior": BEHAVIOR_PEN,
		"radius": 2.4
	},
	{
		"cell": Vector2i(125, 86),
		"species": MammalSpecies.SPECIES_COW,
		"behavior": BEHAVIOR_TETHER,
		"radius": 3.0
	},
	{"cell": Vector2i(132, 84), "species": &"goat", "behavior": BEHAVIOR_TETHER, "radius": 2.2},
	{
		"cell": Vector2i(20, 8),
		"species": MammalSpecies.SPECIES_HARE,
		"behavior": BEHAVIOR_FLEE,
		"radius": 4.0
	},
	{
		"cell": Vector2i(8, 30),
		"species": MammalSpecies.SPECIES_RED_FOX,
		"behavior": BEHAVIOR_FLEE,
		"radius": 5.0
	},
	{
		"cell": Vector2i(155, 115),
		"species": MammalSpecies.SPECIES_WOLF,
		"behavior": BEHAVIOR_FLEE,
		"radius": 6.0
	},
	{
		"cell": Vector2i(155, 8),
		"species": MammalSpecies.SPECIES_BROWN_BEAR,
		"behavior": BEHAVIOR_FLEE,
		"radius": 7.0
	},
	{
		"cell": Vector2i(12, 110),
		"species": MammalSpecies.SPECIES_ELK,
		"behavior": BEHAVIOR_FLEE,
		"radius": 6.5
	},
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
var _definition: MapDefinition = null
var _cell_size := 32
var _elapsed := 0.0
var _herd_root: Node3D = null
var _herd_renderers: Array[MapViewCrowdRenderer] = []
var _stand_in_renderers: Dictionary = {}  # model key -> MapViewCrowdRenderer
var _herd_companion_count := 0
var _parts_cache: Dictionary = {}  # model key -> parts (CPU-posed meshes are costly)


func set_fauna_enabled(enabled: bool) -> void:
	_fauna_enabled = enabled
	for actor in _actors:
		actor.visible = enabled
	if _herd_root != null:
		_herd_root.visible = enabled


## Wandering visual actors only; the instanced `Herds` layer is separate.
func fauna_actors() -> Array[Node3D]:
	return _actors


## Static companions drawn on the instanced crowd path (0 when disabled).
func herd_companion_count() -> int:
	if _herd_root == null or not _herd_root.visible:
		return 0
	return _herd_companion_count


## Every instanced renderer (companions and far stand-ins), for LOD checks.
func herd_renderers() -> Array[MapViewCrowdRenderer]:
	var renderers: Array[MapViewCrowdRenderer] = _herd_renderers.duplicate()
	for renderer: MapViewCrowdRenderer in _stand_in_renderers.values():
		renderers.append(renderer)
	return renderers


static func herd_count_for_map(map_id: StringName) -> int:
	var total := 0
	for placement: Dictionary in MAP_PLACEMENTS.get(map_id, []):
		total += int(placement.get("herd", 0))
	return total


func active_fauna_count() -> int:
	var count := 0
	for actor in _actors:
		if actor.visible:
			count += 1
	return count


func configure(
	map_id: StringName, context: StringName, cell_size: int, map_definition: MapDefinition = null
) -> void:
	_map_id = map_id
	_definition = map_definition
	_context = context
	_cell_size = maxi(cell_size, 1)
	_elapsed = 0.0
	_rebuild_actors()


func sync(
	context: StringName, delta: float, listener_position: Vector3, enabled: bool = true
) -> void:
	_fauna_enabled = enabled
	_context = context
	if not _should_run():
		for actor in _actors:
			actor.visible = false
		if _herd_root != null:
			_herd_root.visible = false
		return
	_elapsed += delta
	for actor in _actors:
		actor.visible = true
		_advance_actor(actor, listener_position, delta)
	if _herd_root != null:
		_herd_root.visible = true
		_sync_stand_ins()


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
	map_id: StringName, required_pool: Array[StringName]
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
	return (
		_fauna_enabled and FaunaContext.supports_penned_fauna(_map_id) and not _context.is_empty()
	)


func _rebuild_actors() -> void:
	for actor in _actors:
		actor.queue_free()
	_actors.clear()
	if _herd_root != null:
		_herd_root.queue_free()
		_herd_root = null
	_herd_renderers.clear()
	_stand_in_renderers.clear()
	_parts_cache.clear()
	_herd_companion_count = 0
	if not FaunaContext.supports_penned_fauna(_map_id):
		return
	_herd_root = Node3D.new()
	_herd_root.name = "Herds"
	add_child(_herd_root)
	var placements: Array = MAP_PLACEMENTS.get(_map_id, [])
	var limit := mini(placements.size(), MAX_CONCURRENT_FAUNA)
	var companions_by_key: Dictionary = {}  # model key -> {actor_id: Transform3D}
	for index in limit:
		var placement: Dictionary = placements[index]
		var actor := _make_actor(index, placement)
		add_child(actor)
		_actors.append(actor)
		if _definition != null:
			UrbanFauna.snap_actor_visual_to_ground(actor, _ground_height_at(actor.position))
		_add_herd_companions(index, placement, actor, companions_by_key)
	for key: String in companions_by_key:
		var renderer := _make_herd_renderer(key, 0.0, MAX_HERD_COMPANIONS)
		if renderer == null:
			continue
		renderer.name = "Herd_%d" % _herd_renderers.size()
		renderer.replace_actor_transforms(companions_by_key[key])
		_herd_renderers.append(renderer)


func _make_actor(index: int, placement: Dictionary) -> Node3D:
	var species: StringName = placement.get("species", &"")
	var behavior: StringName = placement.get("behavior", BEHAVIOR_PEN)
	var radius := float(placement.get("radius", 1.0))
	var cell: Vector2i = placement.get("cell", Vector2i.ZERO)
	var pose := _pose_for_behavior(behavior, species)
	# Pens sit on the visible relief, not on the flat logic plane, so a yard that
	# was carved below Y=0 must not leave its livestock hovering in the air.
	var blocked := _blocked_rects(species)
	# Homes must sit in the yard. A cell authored inside a house would otherwise
	# become the wander fallback and keep the animal occluded by the facade.
	var home := _nudge_home_out_of_buildings(
		MapViewBridge.cell_center_to_world(cell, _cell_size, _ground_height_for_cell(cell)),
		blocked
	)
	var actor := Node3D.new()
	actor.name = "PennedFauna%d" % index
	if MedievalAnimalModels.add_model(actor, species, hash_seed(_map_id, index, 53)) == null:
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
	actor.set_meta(&"herd_model_key", _model_key(species, pose, hash_seed(_map_id, index, 53)))
	actor.set_meta(&"herd_variant_seed", hash_seed(_map_id, index))
	actor.set_meta(&"herd_home", home)
	actor.set_meta(&"herd_blocked", blocked)
	for geometry: Node in actor.find_children("*", "GeometryInstance3D", true, false):
		_apply_detail_range(geometry as GeometryInstance3D)
	var wander_config := _wander_config(behavior, home, radius)
	wander_config["blocked_rects"] = blocked
	GroundWander.setup(actor, _map_id, index, wander_config)
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
	if _definition != null:
		# Follow the terrain while crossing a pen; the logic plane stays flat and
		# authoritative for the wander waypoints.
		actor.position.y = _ground_height_at(actor.position)
		UrbanFauna.snap_actor_visual_to_ground(actor, actor.position.y)
	MedievalAnimalModels.sync_animation(actor, previous_position, delta)


func _ground_height_for_cell(cell: Vector2i) -> float:
	if _definition == null:
		return 0.0
	return _ground_height_at(MapViewBridge.cell_center_to_world(cell, _cell_size))


func _ground_height_at(world: Vector3) -> float:
	return (
		MapViewMeshBuilder.ground_height(_definition, Vector2(world.x, world.z))
		if _definition != null
		else 0.0
	)


func _blocked_rects(species: StringName) -> Array[Rect2]:
	var blocked: Array[Rect2] = []
	if _definition == null:
		return blocked
	# Visual actors have no physics bodies, so expand authored solid footprints by
	# approximate shoulder radius and reject movement before the model intersects.
	var clearance := 0.18
	if species in [MammalSpecies.SPECIES_COW, MammalSpecies.SPECIES_HORSE]:
		clearance = 0.85
	elif species in [MammalSpecies.SPECIES_PIG, MammalSpecies.SPECIES_SHEEP, &"goat"]:
		clearance = 0.32
	for building: Dictionary in _definition.buildings:
		var footprint: Rect2 = building.get("footprint", Rect2())
		if footprint.size == Vector2.ZERO:
			continue
		blocked.append(
			MapViewBridge.logic_rect_to_world_xz(footprint, _cell_size).grow(clearance)
		)
	return blocked


static func _nudge_home_out_of_buildings(home: Vector3, blocked: Array[Rect2]) -> Vector3:
	if not _world_point_blocked(home, blocked):
		return home
	for distance in [1.0, 1.5, 2.0, 2.5, 3.0, 4.0]:
		for attempt in 8:
			var angle := float(attempt) * TAU / 8.0
			var candidate := home + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
			if not _world_point_blocked(candidate, blocked):
				return candidate
	return home


static func _world_point_blocked(position: Vector3, blocked: Array[Rect2]) -> bool:
	var point := Vector2(position.x, position.z)
	for blocked_rect: Rect2 in blocked:
		if blocked_rect.has_point(point):
			return true
	return false


static func _pose_for_behavior(behavior: StringName, species: StringName) -> StringName:
	match behavior:
		BEHAVIOR_TETHER:
			return MammalSpecies.POSE_GRAZING
		BEHAVIOR_FLEE:
			return MammalSpecies.POSE_STANDING
		_:
			if (
				species
				in [
					MammalSpecies.SPECIES_CHICKEN,
					MammalSpecies.SPECIES_DUCK,
					MammalSpecies.SPECIES_GOOSE
				]
			):
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


## Model identity for instancing: the GLB path (cattle coats differ by seed) or
## the procedural species/pose pair.
static func _model_key(species: StringName, pose: StringName, variant_seed: int) -> String:
	if MedievalAnimalModels.has_model(species):
		return "glb|%s|%s" % [species, MedievalAnimalModels.model_path(species, variant_seed)]
	return "proc|%s|%s|%d" % [species, pose, variant_seed]


static func _apply_detail_range(geometry: GeometryInstance3D) -> void:
	geometry.visibility_range_end = FAUNA_DETAIL_RANGE
	geometry.visibility_range_end_margin = CrowdRenderer.FAUNA_RANGE_MARGIN
	geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


## Scatter the placement's `herd` companions inside the pen radius, outside
## building footprints, on the visible relief. Deterministic per map/index.
func _add_herd_companions(
	index: int, placement: Dictionary, actor: Node3D, companions_by_key: Dictionary
) -> void:
	var wanted := mini(int(placement.get("herd", 0)), MAX_HERD_COMPANIONS - _herd_companion_count)
	if wanted <= 0:
		return
	var key: String = actor.get_meta(&"herd_model_key")
	var parts := _parts_for_key(key, int(actor.get_meta(&"herd_variant_seed")))
	if parts.is_empty():
		return
	var lowest := _parts_lowest_y(parts)
	var home: Vector3 = actor.get_meta(&"herd_home")
	var blocked: Array[Rect2] = actor.get_meta(&"herd_blocked")
	var radius := float(placement.get("radius", 1.0)) * HERD_RADIUS_SCALE
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_seed(_map_id, index, 71)
	var transforms: Dictionary = companions_by_key.get(key, {})
	for companion in wanted:
		for _attempt in 8:
			var angle := rng.randf_range(0.0, TAU)
			var distance := radius * sqrt(rng.randf_range(0.15, 1.0))
			var spot := home + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
			if _world_point_blocked(spot, blocked):
				continue
			spot.y = (
				_ground_height_at(spot) if _definition != null else home.y
			) + UrbanFauna.GROUND_CLEARANCE - lowest
			var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
			transforms[index * 64 + companion] = Transform3D(basis, spot)
			_herd_companion_count += 1
			break
	companions_by_key[key] = transforms


## Far LOD: every actor beyond FAUNA_DETAIL_RANGE is drawn by the stand-in for
## its model key at the actor's live transform. Few actors (<= 11), one upload
## per model key.
func _sync_stand_ins() -> void:
	var per_key: Dictionary = {}
	for actor_index in _actors.size():
		var actor := _actors[actor_index]
		var key: String = actor.get_meta(&"herd_model_key", "")
		if key.is_empty():
			continue
		if not _stand_in_renderers.has(key):
			var renderer := _make_herd_renderer(
				key, FAUNA_DETAIL_RANGE, MAX_CONCURRENT_FAUNA, actor
			)
			if renderer == null:
				actor.remove_meta(&"herd_model_key")
				continue
			renderer.name = "StandIn_%d" % _stand_in_renderers.size()
			_stand_in_renderers[key] = renderer
		var transforms: Dictionary = per_key.get(key, {})
		transforms[actor_index] = actor.transform
		per_key[key] = transforms
	for key: String in _stand_in_renderers:
		(_stand_in_renderers[key] as MapViewCrowdRenderer).replace_actor_transforms(
			per_key.get(key, {})
		)


func _make_herd_renderer(
	key: String, range_begin: float, capacity: int, actor: Node3D = null
) -> MapViewCrowdRenderer:
	var variant_seed := int(actor.get_meta(&"herd_variant_seed", 0)) if actor != null else 0
	var parts := _parts_for_key(key, variant_seed)
	if parts.is_empty():
		return null
	var renderer := CrowdRenderer.new()
	# Livestock is close to the camera; keep companion shadows so they sit on
	# the ground like the animated actor does.
	renderer.configure_parts(parts, capacity, range_begin, HERD_VISIBILITY_RANGE, true)
	_herd_root.add_child(renderer)
	return renderer


## Build instancing parts from the same model the animated actor uses so the
## LOD swap and the companions cannot drift in coat, scale, or facing.
func _parts_for_key(key: String, variant_seed: int) -> Array:
	if not _parts_cache.has(key):
		_parts_cache[key] = _build_parts_for_key(key, variant_seed)
	return _parts_cache[key]


func _build_parts_for_key(key: String, variant_seed: int) -> Array:
	var fields := key.split("|")
	if fields.size() < 3:
		return []
	var species := StringName(fields[1])
	var holder := Node3D.new()
	var parts: Array = []
	if fields[0] == "glb":
		# add_model picks the coat by seed; the key already names that path.
		var model := MedievalAnimalModels.add_model(
			holder, species, _variant_seed_for_path(species, fields[2])
		)
		if model != null:
			# Some rigs (the storybook duck) are bound with spread wings. Bake
			# the first Idle frame so instanced livestock stands at rest; the
			# player only evaluates inside the tree, else bind pose is used.
			var posed := false
			if is_inside_tree():
				add_child(holder)
				posed = _pose_idle(model)
			parts = CrowdRenderer.mesh_parts_from_scene(model, posed)
			if holder.get_parent() != null:
				remove_child(holder)
	else:
		var mesh := MammalMeshes.mesh_for(species, StringName(fields[2]))
		if mesh != null:
			var model := MeshInstance3D.new()
			model.mesh = mesh
			model.position.y = -mesh.get_aabb().position.y
			_apply_variant_material(model, species, variant_seed)
			parts = [
				{
					"mesh": mesh,
					"transform": model.transform,
					"material": model.material_override,
				}
			]
			model.free()
	holder.free()
	return parts


static func _pose_idle(model: Node3D) -> bool:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return false
	var player := players[0] as AnimationPlayer
	var clip := &""
	for name: StringName in player.get_animation_list():
		if String(name).to_lower().ends_with("idle"):
			clip = name
			break
	if clip.is_empty():
		return false
	player.play(clip)
	player.seek(0.0, true)
	player.stop(true)
	return true


static func _variant_seed_for_path(species: StringName, path: String) -> int:
	if species != MammalSpecies.SPECIES_COW:
		return 0
	return maxi(MedievalAnimalModels.COW_VARIANT_PATHS.find(path), 0)


static func _parts_lowest_y(parts: Array) -> float:
	var lowest := INF
	for part: Dictionary in parts:
		var bounds := (part["mesh"] as Mesh).get_aabb()
		var xform: Transform3D = part["transform"]
		for corner_index in 8:
			lowest = minf(lowest, (xform * bounds.get_endpoint(corner_index)).y)
	return 0.0 if is_inf(lowest) else lowest


func _node_has_collision(node: Node) -> bool:
	if node is CollisionObject3D:
		return true
	for child in node.get_children():
		if _node_has_collision(child):
			return true
	return false
