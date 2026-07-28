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
const CART_SCENE_PATH := "res://assets/props/vehicles/wooden_cart.glb"
const FACADE_ASSETS: Array[Dictionary] = [
	{"label": "STONE POINTED WINDOW", "path": "res://assets/buildings/facades/stone_pointed_window_open_shutters.glb"},
	{"label": "TIMBER WINDOW OPEN", "path": "res://assets/buildings/facades/timber_window_open_shutters.glb"},
	{"label": "TIMBER WINDOW CLOSED", "path": "res://assets/buildings/facades/timber_window_closed_shutters.glb"},
]
const HUMANOID_ANIMATION_SPACING := 5.5
const CHARACTER_VARIANT_SPACING := 5.0
const CAT_ANIMATION_SPACING := 6.0
const ONE_SHOT_REPLAY_DELAY := 0.6
const MIDDAY_PROGRESS := 0.5
const LARGE_ASSET_COLOR := Color8(255, 220, 132)

@export_enum("small", "large") var showcase_kind: String = String(Definition.SHOWCASE_SMALL)

@onready var map_root: Node2D = $MapRoot
@onready var actors: Node2D = $Actors
@onready var player: Player = $Actors/Player

var _definition: MapDefinition
var _bootstrap: Dictionary = {}
var _view_runtime: MapViewRuntime
var _replay_rigs: Array[SharedCharacterRig] = []
var _replay_delays: Dictionary = {}


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
	else:
		_add_characters_and_animations()
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


func is_large_showcase() -> bool:
	return StringName(showcase_kind) == Definition.SHOWCASE_LARGE


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


func _add_small_section_labels(labels: Node3D) -> void:
	var kinds := Definition.small_prop_kinds()
	_add_label(labels, "SMALL ASSETS - PEOPLE, ANIMALS AND PROPS (%d)" % kinds.size(), Vector2(4.0, 2.0), 1.5, LARGE_ASSET_COLOR)
	for index in kinds.size():
		_add_label(
			labels,
			String(kinds[index]).to_upper(),
			Vector2(Definition.small_prop_cell(index)) + Vector2(0.5, 1.8),
			0.1,
			Color.WHITE,
			36
		)

	_add_label(labels, "CHARACTER VARIANTS", Vector2(4.0, 63.0), 1.5, LARGE_ASSET_COLOR)
	_add_label(labels, "ALL HUMANOID ANIMATIONS", Vector2(4.0, 73.0), 1.5, LARGE_ASSET_COLOR)
	_add_label(labels, "ALL CAT ANIMATIONS", Vector2(4.0, 93.0), 1.5, LARGE_ASSET_COLOR)
	_add_label(labels, "UNBOUND PRODUCTION OBJECTS", Vector2(4.0, 104.0), 1.5, LARGE_ASSET_COLOR)


func _add_characters_and_animations() -> void:
	var root := Node3D.new()
	root.name = "CharacterShowcase"
	_view_runtime.add_child(root)

	for index in HUMANOID_SCENES.size():
		var rig := HUMANOID_SCENES[index].instantiate() as SharedCharacterRig
		rig.position = Vector3(8.0 + float(index) * CHARACTER_VARIANT_SPACING, 0.0, 68.0)
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
		rig.position = Vector3(7.0 + float(column) * HUMANOID_ANIMATION_SPACING, 0.0, 78.0 + float(row) * 8.0)
		rig.start_animation = animation_name
		root.add_child(rig)
		_add_world_label(root, String(animation_name).to_upper(), rig.position + Vector3(0.0, 2.7, 0.0), 34)
		if animation_name not in SharedCharacterRig.LOOPING_ANIMATIONS:
			_replay_rigs.append(rig)
			_replay_delays[rig] = ONE_SHOT_REPLAY_DELAY

	for index in CatRig.REQUIRED_ANIMATIONS.size():
		var animation_name: StringName = CatRig.REQUIRED_ANIMATIONS[index]
		var cat := CAT_SCENE.instantiate() as CatRig
		cat.position = Vector3(8.0 + float(index) * CAT_ANIMATION_SPACING, 0.0, 98.0)
		cat.start_animation = animation_name
		root.add_child(cat)
		_add_world_label(root, "CAT %s" % String(animation_name).to_upper(), cat.position + Vector3(0.0, 1.25, 0.0), 34)
		if animation_name not in CatRig.LOOPING_CAT_ANIMATIONS:
			_replay_rigs.append(cat)
			_replay_delays[cat] = ONE_SHOT_REPLAY_DELAY


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
			+ "%d terrains | %d large prop kinds | %d building samples | %d facade assets\n"
			% [MapTypes.ALL_TERRAINS.size(), Definition.LARGE_PROP_KINDS.size(), Definition.BUILDING_SPECS.size(), FACADE_ASSETS.size()]
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
