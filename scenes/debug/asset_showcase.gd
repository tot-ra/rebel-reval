class_name AssetShowcase
extends "res://scripts/global/BaseLevel.gd"

## Walkable developer galleries for reviewing the current object catalog under the
## production renderer, scale, shadows, camera, and animation systems.

const Definition := preload("res://scenes/debug/asset_showcase_definition.gd")
const HUMANOID_SCENES: Array[PackedScene] = [
	preload("res://assets/characters/kalev/kalev.tscn"),
	preload("res://assets/characters/variants/danish_warrior.tscn"),
	preload("res://assets/characters/variants/henning.tscn"),
	preload("res://assets/characters/variants/innkeeper.tscn"),
	preload("res://assets/characters/variants/mart.tscn"),
	preload("res://assets/characters/variants/sergeant.tscn"),
	preload("res://assets/characters/variants/townswoman.tscn"),
	preload("res://assets/characters/variants/watchman.tscn"),
]
const CAT_SCENE := preload("res://assets/characters/cat/cat_rig.tscn")
const CatCoats := preload("res://assets/characters/cat/cat_coat_variants.gd")
const GroundWander := preload("res://scripts/map/view3d/map_view_ground_wander.gd")
const BirdMeshes := preload("res://scripts/map/view3d/map_view_bird_meshes.gd")
const BirdFlight := preload("res://scripts/map/view3d/map_view_bird_flight.gd")
const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")
const MammalMeshes := preload("res://scripts/map/view3d/map_view_mammal_meshes.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const MedievalAnimalModels := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const CART_SCENE_PATH := "res://assets/props/vehicles/wooden_cart.glb"
const FACADE_ASSETS: Array[Dictionary] = [
	{"label": "STONE POINTED WINDOW", "path": "res://assets/buildings/facades/stone_pointed_window_open_shutters.glb"},
	{"label": "TIMBER WINDOW OPEN", "path": "res://assets/buildings/facades/timber_window_open_shutters.glb"},
	{"label": "TIMBER WINDOW CLOSED", "path": "res://assets/buildings/facades/timber_window_closed_shutters.glb"},
]
const HUMANOID_ANIMATION_SPACING := 5.5
const CHARACTER_VARIANT_SPACING := 5.0
const CAT_ANIMATION_SPACING := 6.0
const CATALOG_COLUMNS := 10
const CATALOG_COLUMN_SPACING := 12.0
const CATALOG_ROW_SPACING := 8.0
const MAMMAL_CATALOG_START := Vector3(8.0, 0.0, 14.0)
const BIRD_CATALOG_START := Vector3(8.0, 0.0, 43.0)
const FAUNA_WANDER_SPEED := 0.38
const ONE_SHOT_REPLAY_DELAY := 0.6
const MIDDAY_PROGRESS := 0.5
const LARGE_ASSET_COLOR := Color8(255, 220, 132)

@export_enum("small", "large", "characters_animals") var showcase_kind: String = String(Definition.SHOWCASE_SMALL)

@onready var map_root: Node2D = $MapRoot
@onready var actors: Node2D = $Actors
@onready var player: Player = $Actors/Player

var _definition: MapDefinition
var _bootstrap: Dictionary = {}
var _view_runtime: MapViewRuntime
var _replay_rigs: Array[SharedCharacterRig] = []
var _replay_delays: Dictionary = {}
var _catalog_fauna: Array[Node3D] = []
var _catalog_birds: Array[Dictionary] = []
var _catalog_elapsed := 0.0


func _ready() -> void:
	_definition = Definition.create(StringName(showcase_kind))
	var errors := _definition.validate()
	if not errors.is_empty():
		push_error("Invalid debug asset showcase: %s" % ", ".join(errors))
		return

	_bootstrap = MapSceneBootstrap.assemble(self, _definition, actors, map_root)
	DoorNavigator.place_player(self, player, _definition.player_spawn)
	MapSceneBootstrap.configure_player_movement(player, _bootstrap)
	var navigation := _bootstrap.get("navigation") as NavigationRegion2D
	if navigation != null and player.navigation_agent != null:
		player.navigation_agent.set_navigation_map(navigation.get_navigation_map())

	_view_runtime = MapViewRuntime.install(self, _bootstrap, map_root, player)
	# The galleries are stable visual review environments, not weather/time tests.
	_view_runtime.set_time_of_day(MapView3D.TIME_DAY)
	_view_runtime.view.apply_cycle_progress(MIDDAY_PROGRESS)
	var sky := _view_runtime.view.sky_weather()
	if sky != null:
		sky.auto_weather = false
		sky.set_weather(SkyWeather3D.WEATHER_CLEAR)
		sky.advance(SkyWeather3D.TRANSITION_SECONDS)
	_view_runtime.view.activate_all_chunks()

	_add_fill_light()
	_add_section_labels()
	if is_large_showcase():
		_add_large_unbound_assets()
	elif is_characters_animals_showcase():
		_add_characters_and_animations()
		_add_animal_catalog()
	else:
		_add_small_unbound_assets()
	_add_review_hud()


func _process(delta: float) -> void:
	for rig in _replay_rigs:
		if not is_instance_valid(rig):
			continue
		var player_node := rig.animation_player()
		if player_node == null or player_node.is_playing():
			continue
		var remaining := float(_replay_delays.get(rig, ONE_SHOT_REPLAY_DELAY)) - delta
		if remaining > 0.0:
			_replay_delays[rig] = remaining
			continue
		rig.play_animation(rig.start_animation, 0.08)
		_replay_delays[rig] = ONE_SHOT_REPLAY_DELAY

	if not is_characters_animals_showcase() or _view_runtime == null:
		return
	_catalog_elapsed += delta
	var listener_position := _view_runtime.view.view_camera().global_position
	for actor in _catalog_fauna:
		if not is_instance_valid(actor):
			continue
		var previous_position := actor.position
		GroundWander.advance(actor, &"debug_characters_animals", listener_position, delta)
		MedievalAnimalModels.sync_animation(actor, previous_position, delta)
	for spec in _catalog_birds:
		var actor := spec.get("actor") as Node3D
		if actor == null or not is_instance_valid(actor):
			continue
		var phase := float(spec.get("phase", 2.0)) + delta / MapViewBirdFlight.FLAP_INTERVAL_S
		if phase >= 10.0:
			phase = 2.0
			var glide_skip := int(spec.get("glide_skip", 0))
			spec["pause"] = float(glide_skip) * MapViewBirdFlight.FLAP_INTERVAL_S
		var pause := maxf(float(spec.get("pause", 0.0)) - delta, 0.0)
		if pause > 0.0:
			phase = 2.0
		spec["phase"] = phase
		spec["pause"] = pause
		_apply_showcase_wing_pose(actor, phase)


func is_large_showcase() -> bool:
	return StringName(showcase_kind) == Definition.SHOWCASE_LARGE


func is_characters_animals_showcase() -> bool:
	return StringName(showcase_kind) == Definition.SHOWCASE_CHARACTERS_ANIMALS


func _add_fill_light() -> void:
	var fill := DirectionalLight3D.new()
	fill.name = "ShowcaseFillLight"
	fill.rotation_degrees = Vector3(-55.0, 145.0, 0.0)
	fill.light_color = Color8(196, 216, 255)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	_view_runtime.view.add_child(fill)


func _add_section_labels() -> void:
	var labels := Node3D.new()
	labels.name = "ShowcaseLabels"
	_view_runtime.view.add_child(labels)
	if is_large_showcase():
		_add_large_section_labels(labels)
	elif is_characters_animals_showcase():
		_add_characters_animals_section_labels(labels)
	else:
		_add_small_section_labels(labels)


func _add_large_section_labels(labels: Node3D) -> void:
	_add_label(labels, "LARGE ASSETS - TERRAIN MATERIALS (%d)" % MapTypes.ALL_TERRAINS.size(), Vector2(4.0, 2.0), 1.5, LARGE_ASSET_COLOR)
	for index in MapTypes.ALL_TERRAINS.size():
		_add_label(
			labels,
			String(MapTypes.ALL_TERRAINS[index]).to_upper(),
			Vector2(Definition.terrain_cell(index)) + Vector2(Definition.TERRAIN_PATCH_SIZE) * 0.5,
			0.15,
			Color.WHITE,
			44
		)

	_add_label(labels, "BUILDINGS, FORTIFICATIONS AND GATES", Vector2(4.0, 66.0), 1.5, LARGE_ASSET_COLOR)
	for spec in Definition.BUILDING_SPECS:
		var rect: Rect2i = spec["cell_rect"]
		_add_label(labels, spec["label"], Vector2(rect.position) + Vector2(rect.size.x * 0.5, rect.size.y + 1.0), 0.2)
	for spec in Definition.GATE_SPECS:
		var rect: Rect2i = spec["cell_rect"]
		_add_label(labels, spec["label"], Vector2(rect.position) + Vector2(rect.size.x * 0.5, rect.size.y + 1.0), 0.2)
	_add_label(labels, "WALL-WALK ACCESS", Vector2(88.0, 110.0), 0.2)

	_add_label(labels, "TREES AND SHIPS - LARGE GRID", Vector2(4.0, 116.0), 1.5, LARGE_ASSET_COLOR)
	for index in Definition.LARGE_PROP_KINDS.size():
		_add_label(
			labels,
			String(Definition.LARGE_PROP_KINDS[index]).to_upper(),
			Vector2(Definition.large_prop_cell(index)) + Vector2(0.5, 4.8),
			0.2,
			Color.WHITE,
			40
		)
	_add_label(labels, "ANCIENT OAK GLB", Vector2(108.5, 127.8), 0.2)
	_add_label(labels, "ARCHITECTURAL FACADE ASSETS", Vector2(4.0, 135.0), 1.5, LARGE_ASSET_COLOR)
	_add_label(labels, "PROCEDURAL TREE MODELS (%d) - MEDIUM SCALE" % MapViewTreeSpecies.ALL_SPECIES.size(), Vector2(4.0, 152.0), 1.5, LARGE_ASSET_COLOR)
	for index in MapViewTreeSpecies.ALL_SPECIES.size():
		_add_label(
			labels,
			String(MapViewTreeSpecies.ALL_SPECIES[index]).to_upper(),
			Vector2(Definition.tree_model_cell(index)) + Vector2(0.5, 3.5),
			0.15,
			Color.WHITE,
			34
		)


func _add_small_section_labels(labels: Node3D) -> void:
	var kinds := Definition.small_prop_kinds()
	_add_label(labels, "SMALL ASSETS - PROPS (%d)" % kinds.size(), Vector2(4.0, 2.0), 1.5, LARGE_ASSET_COLOR)
	for index in kinds.size():
		_add_label(
			labels,
			String(kinds[index]).to_upper(),
			Vector2(Definition.small_prop_cell(index)) + Vector2(0.5, 1.8),
			0.1,
			Color.WHITE,
			36
		)

	_add_label(labels, "UNBOUND PRODUCTION OBJECTS", Vector2(4.0, 104.0), 1.5, LARGE_ASSET_COLOR)


func _add_characters_animals_section_labels(labels: Node3D) -> void:
	_add_label(labels, "ALL MAMMALS - LIVING CATALOG (%d)" % MammalSpecies.ALL_SPECIES.size(), Vector2(4.0, 2.0), 1.5, LARGE_ASSET_COLOR)
	_add_label(labels, "ALL BIRDS - LIVING CATALOG (%d)" % BirdSpecies.ALL_SPECIES.size(), Vector2(4.0, 38.0), 1.5, LARGE_ASSET_COLOR)
	_add_label(labels, "CHARACTER VARIANTS", Vector2(4.0, 73.0), 1.5, LARGE_ASSET_COLOR)
	_add_label(labels, "ALL HUMANOID ANIMATIONS", Vector2(4.0, 83.0), 1.5, LARGE_ASSET_COLOR)
	_add_label(labels, "ALL CAT ANIMATIONS", Vector2(4.0, 103.0), 1.5, LARGE_ASSET_COLOR)


func _add_characters_and_animations() -> void:
	var root := Node3D.new()
	root.name = "CharacterShowcase"
	_view_runtime.add_child(root)

	for index in HUMANOID_SCENES.size():
		var rig := HUMANOID_SCENES[index].instantiate() as SharedCharacterRig
		rig.position = Vector3(8.0 + float(index) * CHARACTER_VARIANT_SPACING, 0.0, 78.0)
		rig.start_animation = &"idle"
		root.add_child(rig)
		_add_world_label(root, String(rig.name).to_upper(), rig.position + Vector3(0.0, 2.7, 0.0), 38)

	var animations: Array[StringName] = []
	animations.assign(SharedCharacterRig.CANONICAL_ANIMATIONS.keys())
	for index in animations.size():
		var animation_name := animations[index]
		var row := index / 8
		var column := index % 8
		var rig := HUMANOID_SCENES[0].instantiate() as SharedCharacterRig
		rig.position = Vector3(7.0 + float(column) * HUMANOID_ANIMATION_SPACING, 0.0, 88.0 + float(row) * 8.0)
		rig.start_animation = animation_name
		root.add_child(rig)
		_add_world_label(root, String(animation_name).to_upper(), rig.position + Vector3(0.0, 2.7, 0.0), 34)
		if animation_name not in SharedCharacterRig.LOOPING_ANIMATIONS:
			_replay_rigs.append(rig)
			_replay_delays[rig] = ONE_SHOT_REPLAY_DELAY

	for index in CatRig.REQUIRED_ANIMATIONS.size():
		var animation_name: StringName = CatRig.REQUIRED_ANIMATIONS[index]
		var cat := CAT_SCENE.instantiate() as CatRig
		cat.position = Vector3(8.0 + float(index) * CAT_ANIMATION_SPACING, 0.0, 108.0)
		cat.start_animation = animation_name
		root.add_child(cat)
		_add_world_label(root, "CAT %s" % String(animation_name).to_upper(), cat.position + Vector3(0.0, 1.25, 0.0), 34)
		if animation_name not in CatRig.LOOPING_CAT_ANIMATIONS:
			_replay_rigs.append(cat)
			_replay_delays[cat] = ONE_SHOT_REPLAY_DELAY


func _add_animal_catalog() -> void:
	var root := Node3D.new()
	root.name = "AnimalCatalog"
	_view_runtime.add_child(root)

	# Cattle, sheep, and horses are authored prop kinds. Their map samples have
	# moved here intact so this gallery remains the one place for all living assets.
	var moved_species: Array[StringName] = [
		MammalSpecies.SPECIES_COW,
		MammalSpecies.SPECIES_SHEEP,
		MammalSpecies.SPECIES_HORSE,
	]
	for index in moved_species.size():
		var cell := Definition.small_prop_cell(index)
		var position := Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)
		_add_world_label(root, String(moved_species[index]).to_upper(), position + Vector3(0.0, 2.7, 0.0), 34)

	# Goat is a shipped living actor even though it predates the signed 30-species
	# mammal catalog, so it receives an explicit production-model slot.
	var goat_position := Vector3(44.5, 0.0, 6.5)
	_add_catalog_fauna(root, &"goat", goat_position, 0)

	var catalog_index := 0
	for species: StringName in MammalSpecies.ALL_SPECIES:
		if species in moved_species:
			continue
		var position := _catalog_position(MAMMAL_CATALOG_START, catalog_index)
		_add_catalog_fauna(root, species, position, catalog_index + 1)
		catalog_index += 1

	for index in BirdSpecies.ALL_SPECIES.size():
		var species: StringName = BirdSpecies.ALL_SPECIES[index]
		var position := _catalog_position(BIRD_CATALOG_START, index)
		_add_catalog_bird(root, species, position, index)


func _add_catalog_fauna(parent: Node3D, species: StringName, position: Vector3, index: int) -> void:
	var actor := Node3D.new()
	actor.name = "Fauna_%s" % String(species)
	var model := MedievalAnimalModels.add_model(actor, species)
	if model != null and species == MammalSpecies.SPECIES_CAT:
		CatCoats.apply(model, hash(["debug_characters_animals", index]))
	if model == null:
		var mesh := MammalMeshes.mesh_for(species)
		var proxy := MeshInstance3D.new()
		proxy.name = "Model"
		proxy.mesh = mesh
		if mesh != null:
			var aabb := mesh.get_aabb()
			proxy.position.y = -aabb.position.y
		_apply_catalog_material(proxy)
		actor.add_child(proxy)
	actor.position = position
	actor.set_meta(&"species", species)
	parent.add_child(actor)
	GroundWander.setup(actor, &"debug_characters_animals", index, {
		"home": position,
		"radius": 2.0,
		"speed": 0.85 if species == MammalSpecies.SPECIES_RAT else FAUNA_WANDER_SPEED,
		"roam_scale": 0.72,
		"pause_range": Vector2(1.0, 3.0),
	})
	_catalog_fauna.append(actor)
	_add_world_label(parent, String(species).replace("_", " ").to_upper(), position + Vector3(0.0, 2.7, 0.0), 30)


func _add_catalog_bird(parent: Node3D, species: StringName, position: Vector3, index: int) -> void:
	var actor := Node3D.new()
	actor.name = "Bird_%s" % String(species)
	actor.position = position + Vector3(0.0, 1.8, 0.0)
	parent.add_child(actor)
	var frame := BirdMeshes.modular_rig_for(species)
	if frame.is_empty():
		return
	_install_showcase_modular_rig(actor, frame)
	_catalog_birds.append({
		"actor": actor,
		"phase": 2.0 + float(index % 4) * 0.35,
		"pause": 0.0,
		"glide_skip": _showcase_glide_skip(species),
	})
	_add_world_label(parent, String(species).replace("_", " ").to_upper(), position + Vector3(0.0, 3.2, 0.0), 28)


func _install_showcase_modular_rig(actor: Node3D, frame: Dictionary) -> void:
	var body := _showcase_mesh_node("Body", frame["body"] as ArrayMesh)
	actor.add_child(body)
	for side in [-1, 1]:
		var side_name := "L" if side < 0 else "R"
		var side_key := "left" if side < 0 else "right"
		var shoulder := Node3D.new()
		shoulder.name = "WingRoot%s" % side_name
		shoulder.position = frame["%s_shoulder" % side_key]
		actor.add_child(shoulder)
		var elbow := Node3D.new()
		elbow.name = "WingElbow%s" % side_name
		elbow.position = frame["%s_elbow" % side_key] - shoulder.position
		shoulder.add_child(elbow)
		var upper := _showcase_mesh_node("WingUpper%s" % side_name, frame["%s_upper" % side_key] as ArrayMesh)
		shoulder.add_child(upper)
		var primary := _showcase_mesh_node("WingPrimary%s" % side_name, frame["%s_primary" % side_key] as ArrayMesh)
		elbow.add_child(primary)


func _showcase_mesh_node(node_name: String, mesh: ArrayMesh) -> MeshInstance3D:
	var model := MeshInstance3D.new()
	model.name = node_name
	model.mesh = mesh
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_apply_catalog_material(model)
	return model


func _apply_showcase_wing_pose(actor: Node3D, phase: float) -> void:
	var root_l := actor.get_node_or_null("WingRootL") as Node3D
	var elbow_l := actor.get_node_or_null("WingRootL/WingElbowL") as Node3D
	var root_r := actor.get_node_or_null("WingRootR") as Node3D
	var elbow_r := actor.get_node_or_null("WingRootR/WingElbowR") as Node3D
	if root_l == null or elbow_l == null or root_r == null or elbow_r == null:
		return
	var root_angle := _showcase_flap_angle(BirdFlight.WING_ROOT_ANGLES, phase)
	var elbow_angle := _showcase_flap_angle(BirdFlight.WING_ELBOW_ANGLES, phase)
	var sweep_angle := _showcase_flap_angle(BirdFlight.WING_SWEEP_ANGLES, phase)
	root_l.rotation = Vector3(0.0, -sweep_angle, -root_angle)
	elbow_l.rotation = Vector3(0.0, sweep_angle * 0.65, -elbow_angle)
	root_r.rotation = Vector3(0.0, sweep_angle, root_angle)
	elbow_r.rotation = Vector3(0.0, -sweep_angle * 0.65, elbow_angle)


func _showcase_flap_angle(keyframes: Array[float], phase: float) -> float:
	var wrapped := fposmod(phase, float(keyframes.size()))
	var first := floori(wrapped)
	var second := (first + 1) % keyframes.size()
	return lerpf(keyframes[first], keyframes[second], wrapped - float(first))


func _showcase_glide_skip(species: StringName) -> int:
	match BirdSpecies.group_for(species):
		BirdSpecies.GROUP_RAPTOR:
			return 6
		BirdSpecies.GROUP_GULL, BirdSpecies.GROUP_WATERFOWL:
			return 4
		BirdSpecies.GROUP_OWL:
			return 5
		BirdSpecies.GROUP_SWALLOW:
			return 1
		BirdSpecies.GROUP_TERN:
			return 2
		_:
			return 3


func _catalog_position(start: Vector3, index: int) -> Vector3:
	return start + Vector3(
		float(index % CATALOG_COLUMNS) * CATALOG_COLUMN_SPACING,
		0.0,
		float(index / CATALOG_COLUMNS) * CATALOG_ROW_SPACING
	)


func _apply_catalog_material(model: MeshInstance3D) -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.metallic = 0.0
	material.roughness = 0.9
	# Mirrored low-poly wing cards can have opposite winding on the far side.
	# Do not let the showcase hide that wing while reviewing flap frames.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	model.material_override = material


func _add_small_unbound_assets() -> void:
	var root := Node3D.new()
	root.name = "UnboundSmallAssetShowcase"
	_view_runtime.add_child(root)
	var cart_scene := load(CART_SCENE_PATH) as PackedScene
	if cart_scene == null:
		return
	var cart := cart_scene.instantiate() as Node3D
	root.add_child(cart)
	cart.position = Vector3(8.0, 0.0, 109.0)
	_add_world_label(root, "WOODEN CART GLB", cart.position + Vector3(0.0, 2.8, 0.0), 38)


func _add_large_unbound_assets() -> void:
	var root := Node3D.new()
	root.name = "UnboundLargeAssetShowcase"
	_view_runtime.add_child(root)
	for index in FACADE_ASSETS.size():
		var spec := FACADE_ASSETS[index]
		var scene := load(spec["path"]) as PackedScene
		if scene == null:
			continue
		var asset := scene.instantiate() as Node3D
		root.add_child(asset)
		asset.position = Vector3(12.0 + float(index) * 32.0, 0.0, 142.0)
		_add_world_label(root, spec["label"], asset.position + Vector3(0.0, 3.8, 0.0), 34)


func _add_label(
	parent: Node3D,
	text: String,
	cell_position: Vector2,
	height: float,
	color: Color = Color.WHITE,
	font_size: int = 38
) -> void:
	_add_world_label(parent, text, Vector3(cell_position.x, height, cell_position.y), font_size, color)


func _add_world_label(
	parent: Node3D,
	text: String,
	position: Vector3,
	font_size: int,
	color: Color = Color.WHITE
) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.font_size = font_size
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 7
	label.outline_modulate = Color(0.02, 0.025, 0.03, 0.94)
	label.modulate = color
	parent.add_child(label)


func _add_review_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AssetShowcaseHud"
	layer.layer = 9
	add_child(layer)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -510.0
	panel.offset_top = 16.0
	panel.offset_right = -16.0
	panel.offset_bottom = 128.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var label := Label.new()
	if is_large_showcase():
		label.text = (
			"LARGE ASSET REVIEW GALLERY\n"
			+ "%d terrains | %d large prop kinds | %d procedural trees | %d building samples | %d facade assets\n"
			% [
				MapTypes.ALL_TERRAINS.size(),
				Definition.LARGE_PROP_KINDS.size(),
				MapViewTreeSpecies.ALL_SPECIES.size(),
				Definition.BUILDING_SPECS.size(),
				FACADE_ASSETS.size(),
			]
			+ "WASD/arrows - move | C - camera | right-drag - look | Debug - switch/return"
		)
	else:
		label.text = (
			"SMALL ASSET REVIEW GALLERY\n"
			+ "%d prop kinds | %d characters | %d humanoid clips | %d cat clips\n"
			% [Definition.small_prop_kinds().size(), HUMANOID_SCENES.size(), SharedCharacterRig.CANONICAL_ANIMATIONS.size(), CatRig.REQUIRED_ANIMATIONS.size()]
			+ "WASD/arrows - move | C - camera | right-drag - look | Debug - switch/return"
		)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82))
	margin.add_child(label)
