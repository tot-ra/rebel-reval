extends Node2D

const DEFINITION_SCRIPT := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const COMMISSION_ANCHOR_SCRIPT := preload("res://scripts/forge/forge_commission_anchor.gd")
const PHASE_REST_ANCHOR_SCRIPT := preload("res://scripts/phase/phase_rest_anchor.gd")

@onready var map_root: Node2D = $MapRoot
@onready var actors: Node2D = $Actors
@onready var player: Player = $Actors/Player
@onready var henning: SmithyHenning = $Actors/Henning
@onready var cat: ForgeCat = $Actors/Cat

var _bootstrap: Dictionary = {}
var _view_runtime: MapViewRuntime
var _world_items: WorldItemController
var _phase_binder: MapPhaseBinder
var _commission_anchor: Node
var _rest_anchor: Node
var _interaction_controller: InteractionController
var _dialogue_encounter: ForgeDialogueEncounter
var _prompt_layer: CanvasLayer
var _prompt_label: Label


func _ready() -> void:
	var definition: MapDefinition = DEFINITION_SCRIPT.create()
	_bootstrap = MapSceneBootstrap.assemble(self, definition, actors, map_root)
	DoorNavigator.place_player(self, player, definition.player_spawn)
	_wire_player_navigation()
	MapSceneBootstrap.configure_player_movement(player, _bootstrap)
	_wire_henning_navigation()
	_wire_cat_navigation()
	if player == null:
		player = _find_player(get_tree().root)
	_view_runtime = MapViewRuntime.install(self, _bootstrap, map_root, player)
	_build_interaction_prompt()
	_setup_dialogue_encounter(definition)
	_setup_phase_binder(definition)
	_world_items = WorldItemController.new()
	_world_items.name = "WorldItemController"
	add_child(_world_items)
	_world_items.setup(self, definition, _view_runtime, player, &"loc.kalev_smithy")
	_view_runtime.configure_click_input(_world_items)
	_phase_binder.register_prop(
		&"spearhead_anvil",
		func(visible_state: bool) -> void:
			_world_items.set_prop_visibility(&"world.spearhead_anvil", visible_state)
	)
	_commission_anchor = COMMISSION_ANCHOR_SCRIPT.new()
	_commission_anchor.name = "ForgeCommissionAnchor"
	add_child(_commission_anchor)
	_commission_anchor.setup(self, definition, player)
	_rest_anchor = PHASE_REST_ANCHOR_SCRIPT.new()
	_rest_anchor.name = "PhaseRestAnchor"
	add_child(_rest_anchor)
	_rest_anchor.setup(self, definition, player)


func _setup_dialogue_encounter(definition: MapDefinition) -> void:
	_dialogue_encounter = ForgeDialogueEncounter.new()
	_dialogue_encounter.name = "ForgeDialogueEncounter"
	add_child(_dialogue_encounter)
	_dialogue_encounter.wire(
		self,
		player,
		henning,
		cat,
		_view_runtime,
		definition,
		_interaction_controller
	)


func _setup_phase_binder(definition: MapDefinition) -> void:
	_phase_binder = MapPhaseBinder.new()
	_phase_binder.name = "MapPhaseBinder"
	add_child(_phase_binder)
	_phase_binder.setup(&"loc.kalev_smithy", definition, _view_runtime)
	if henning != null:
		_phase_binder.register_npc(&"henning", henning, &"ledger")


func _build_interaction_prompt() -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "ForgeInteractionPrompt"
	_prompt_layer.layer = 25
	add_child(_prompt_layer)

	_prompt_label = Label.new()
	_prompt_label.position = Vector2(24, 24)
	_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9, 1.0))
	_prompt_label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.08, 1.0))
	_prompt_label.add_theme_constant_override("outline_size", 4)
	_prompt_label.visible = false
	_prompt_layer.add_child(_prompt_label)

	_interaction_controller = InteractionController.new()
	_interaction_controller.name = "InteractionController"
	_interaction_controller.actor = player
	_interaction_controller.prompt_label = _prompt_label
	add_child(_interaction_controller)


func _wire_player_navigation() -> void:
	var navigation: NavigationRegion2D = _bootstrap.get("navigation")
	if player != null and navigation != null and player.navigation_agent != null:
		player.navigation_agent.set_navigation_map(navigation.get_navigation_map())


func _wire_henning_navigation() -> void:
	var navigation: NavigationRegion2D = _bootstrap.get("navigation")
	if henning != null and navigation != null:
		henning.configure_navigation(navigation.get_navigation_map())


func _wire_cat_navigation() -> void:
	var navigation: NavigationRegion2D = _bootstrap.get("navigation")
	if cat != null and navigation != null:
		cat.configure_navigation(navigation.get_navigation_map())
func _find_player(node: Node) -> Player:
	if node is Player:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null
