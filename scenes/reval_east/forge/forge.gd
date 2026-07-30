extends Node2D

const DEFINITION_SCRIPT := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const COMMISSION_ANCHOR_SCRIPT := preload("res://scripts/forge/forge_commission_anchor.gd")
const PHASE_REST_ANCHOR_SCRIPT := preload("res://scripts/phase/phase_rest_anchor.gd")
const PROLOGUE_CONTROLLER_SCRIPT := preload("res://scripts/forge/forge_prologue_controller.gd")
const BITTER_BREW_CONTROLLER_SCRIPT := preload(
	"res://scripts/forge/bitter_brew_commission_controller.gd"
)
const BELL_AND_CHAIN_CONTROLLER_SCRIPT := preload(
	"res://scripts/forge/bell_and_chain_commission_controller.gd"
)
const BREAD_AND_IRON_CONTROLLER_SCRIPT := preload(
	"res://scripts/forge/bread_and_iron_commission_controller.gd"
)
const PRICE_OF_A_NAME_CONTROLLER_SCRIPT := preload(
	"res://scripts/forge/price_of_a_name_commission_controller.gd"
)
const ROOT_AND_EMBER_CONTROLLER_SCRIPT := preload(
	"res://scripts/forge/root_and_ember_commission_controller.gd"
)
const ROUTINE_CONTROLLER_SCRIPT := preload("res://scripts/world/smithy_routine_controller.gd")
const STATION_RESERVATIONS_SCRIPT := preload("res://scenes/reval_east/forge/smithy_station_reservations.gd")
const DOMESTIC_PRESENTER_SCRIPT := preload("res://scenes/reval_east/forge/smithy_domestic_life_presenter.gd")
const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

const KALEV_ROUTINE_PATH := "res://content/routines/kalev_smithy.json"
const KALEV_ID := &"char.kalev"
const DOMESTIC_RUNTIME_STATE_ID := &"runtime.smithy_domestic_vignette"
const HENNING_RUNTIME_STATE_ID := &"runtime.smithy_henning_visit"
const DOMESTIC_INTERACT_PROMPTS := {
	&"ap.wash.basin": "Wash",
	&"ap.prepare.board": "Prepare meal",
	&"ap.hearth.tend": "Tend hearth",
	&"ap.hearth.cookpot": "Stir pot",
	&"ap.eat.table": "Eat",
	&"ap.clear.table": "Clear table",
	&"ap.sweep.floor": "Sweep",
	&"ap.carry.fuel": "Carry fuel",
	&"ap.hearth.bank": "Bank hearth",
	&"ap.forge.bellows": "Work bellows",
	&"ap.forge.anvil": "Work anvil",
	&"ap.forge.quench": "Quench",
	&"ap.ledger.inspect": "Inspect ledger",
}

@onready var map_root: Node2D = $MapRoot
@onready var actors: Node2D = $Actors
@onready var player: Player = $Actors/Player
@onready var henning: SmithyHenning = $Actors/Henning
@onready var mart: SmithyMart = $Actors/Mart
@onready var cat: ForgeCat = $Actors/Cat

var _bootstrap: Dictionary = {}
var _map_definition: MapDefinition
var _view_runtime: MapViewRuntime
var _world_items: WorldItemController
var _phase_binder: MapPhaseBinder
var _commission_anchor: Node
var _rest_anchor: Node
var _interaction_controller: InteractionController
var _dialogue_encounter: ForgeDialogueEncounter
var _prompt_layer: CanvasLayer
var _prompt_label: Label
var _kalev_routine: SmithyRoutineController
var _station_reservations: SmithyStationReservations
var _domestic_presenter: SmithyDomesticLifePresenter
var _kalev_rig: SharedCharacterRig
var _domestic_interactables: Dictionary = {}
var _domestic_vignette_seconds := 0.0
var _domestic_vignette_activity := &""
var _last_domestic_time_band := &"any"


func _ready() -> void:
	var definition: MapDefinition = DEFINITION_SCRIPT.create()
	_map_definition = definition
	_bootstrap = MapSceneBootstrap.assemble(self, definition, actors, map_root)
	DoorNavigator.place_player(self, player, definition.player_spawn)
	_wire_player_navigation()
	MapSceneBootstrap.configure_player_movement(player, _bootstrap)
	_wire_henning_navigation(definition)
	_wire_mart_navigation()
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
	var prologue = PROLOGUE_CONTROLLER_SCRIPT.new()
	prologue.name = "ForgePrologueController"
	add_child(prologue)
	prologue.setup(
		self,
		definition,
		player,
		_commission_anchor,
		_rest_anchor,
		_dialogue_encounter,
		henning,
		_interaction_controller
	)
	var bitter_brew = BITTER_BREW_CONTROLLER_SCRIPT.new()
	bitter_brew.name = "BitterBrewCommissionController"
	add_child(bitter_brew)
	bitter_brew.setup(_commission_anchor, _rest_anchor, player)
	var bell_and_chain = BELL_AND_CHAIN_CONTROLLER_SCRIPT.new()
	bell_and_chain.name = "BellAndChainCommissionController"
	add_child(bell_and_chain)
	bell_and_chain.setup(_commission_anchor, _rest_anchor, player)
	var bread_and_iron = BREAD_AND_IRON_CONTROLLER_SCRIPT.new()
	bread_and_iron.name = "BreadAndIronCommissionController"
	add_child(bread_and_iron)
	bread_and_iron.setup(_commission_anchor, _rest_anchor, player)
	var price_of_a_name = PRICE_OF_A_NAME_CONTROLLER_SCRIPT.new()
	price_of_a_name.name = "PriceOfANameCommissionController"
	add_child(price_of_a_name)
	price_of_a_name.setup(_commission_anchor, _rest_anchor, player)
	var root_and_ember = ROOT_AND_EMBER_CONTROLLER_SCRIPT.new()
	root_and_ember.name = "RootAndEmberCommissionController"
	add_child(root_and_ember)
	root_and_ember.setup(_commission_anchor, _rest_anchor, player)
	_connect_ambient_actor_refresh()
	_setup_kalev_domestic_presentation(definition)


func _process(delta: float) -> void:
	_tick_domestic_presentation(delta)
	_persist_henning_runtime_state()


func _connect_ambient_actor_refresh() -> void:
	if has_node("/root/SessionState"):
		if not SessionState.state_replaced.is_connected(_on_session_state_replaced):
			SessionState.state_replaced.connect(_on_session_state_replaced)
		if not SessionState.state.phase_changed.is_connected(_on_campaign_phase_changed):
			SessionState.state.phase_changed.connect(_on_campaign_phase_changed)
		_refresh_smithy_ambient_actors(SessionState.state)
	else:
		_refresh_smithy_ambient_actors(null)


func _on_session_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	_clear_domestic_vignette(false, false)
	_refresh_smithy_ambient_actors(current)
	if _domestic_presenter != null:
		_domestic_presenter.configure(_kalev_rig, current, SessionState.content_db)
	_restore_domestic_runtime_state(current)
	_restore_henning_runtime_state(current)


func _on_campaign_phase_changed(_previous: StringName, _next: StringName) -> void:
	_clear_domestic_vignette(false)
	_refresh_smithy_ambient_actors(SessionState.state if has_node("/root/SessionState") else null)
	_apply_phase_entry_domestic_presentation()


func _refresh_smithy_ambient_actors(current: GameState) -> void:
	var phase_id := GameState.PHASE_PROLOGUE_DAY
	var mart_missing := true
	if current != null:
		phase_id = current.get_phase()
		mart_missing = current.get_flag(&"flag.mart_missing")
	if mart != null:
		mart.set_routine_context(phase_id, &"any", mart_missing)
	if cat != null:
		cat.set_routine_context(phase_id, &"any")


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
	if mart != null:
		# Do not default-anchor Mart to the anvil prop; that snaps him onto the iron.
		_phase_binder.register_npc(&"mart", mart)


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


func _wire_henning_navigation(definition: MapDefinition) -> void:
	var navigation: NavigationRegion2D = _bootstrap.get("navigation")
	if henning != null and navigation != null:
		henning.configure_navigation(
			navigation.get_navigation_map(),
			MapVerification.prop_position(definition, &"work_chair")
		)
		henning.set_phase_visibility(false)


func _wire_mart_navigation() -> void:
	var navigation: NavigationRegion2D = _bootstrap.get("navigation")
	if mart != null and navigation != null:
		# WHY: spawn on the south anvil apron, never on forge_anvil's prop center,
		# otherwise Mart (and any anvil-bound beat) reads as standing on the iron.
		mart.configure_navigation(
			navigation.get_navigation_map(),
			_anvil_stand_position()
		)


func _anvil_stand_position() -> Vector2:
	# Cell (19, 7): south of forge_anvil rect (18,5)-(20,6), matches ap.forge.anvil.
	return SmithyActivityPoint.cell_center_to_position(Vector2i(19, 7))


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


func _setup_kalev_domestic_presentation(definition: MapDefinition) -> void:
	_station_reservations = STATION_RESERVATIONS_SCRIPT.new()
	_station_reservations.name = "SmithyStationReservations"
	add_child(_station_reservations)
	if mart != null:
		mart.set_station_reservations(_station_reservations)
	if henning != null:
		henning.set_station_reservations(_station_reservations)
	_kalev_routine = ROUTINE_CONTROLLER_SCRIPT.new()
	_kalev_routine.name = "KalevDomesticRoutineController"
	add_child(_kalev_routine)
	_kalev_routine.configure_from_file(KALEV_ROUTINE_PATH)
	_kalev_routine.set_station_reservations(_station_reservations)
	_kalev_rig = _find_kalev_rig()
	_domestic_presenter = DOMESTIC_PRESENTER_SCRIPT.new()
	_domestic_presenter.name = "SmithyDomesticLifePresenter"
	_view_runtime.add_child(_domestic_presenter)
	_domestic_presenter.configure(
		_kalev_rig,
		SessionState.state if has_node("/root/SessionState") else null,
		SessionState.content_db if has_node("/root/SessionState") else null
	)
	if not _kalev_routine.presentation_changed.is_connected(_on_kalev_presentation_changed):
		_kalev_routine.presentation_changed.connect(_on_kalev_presentation_changed)
	if SessionState.state != null:
		_kalev_routine.restore_prop_variants_from_state(SessionState.state, definition)
	_apply_phase_entry_domestic_presentation()
	_spawn_domestic_interactables(definition)
	if SessionState.state != null:
		_restore_domestic_runtime_state(SessionState.state)
		_restore_henning_runtime_state(SessionState.state)


func _find_kalev_rig() -> SharedCharacterRig:
	if _view_runtime == null:
		return null
	for child: Node in _view_runtime.get_children():
		if child is SharedCharacterRig and (child as SharedCharacterRig).variant_id() == KALEV_ID:
			return child as SharedCharacterRig
	return null


func _apply_phase_entry_domestic_presentation() -> void:
	if _kalev_routine == null or _map_definition == null:
		return
	var state := SessionState.state if has_node("/root/SessionState") else null
	var time_band := _current_domestic_time_band()
	_last_domestic_time_band = time_band
	var phase_id := state.get_phase() if state != null else GameState.PHASE_PROLOGUE_DAY
	var variants := _kalev_routine.phase_entry_prop_variants(phase_id, time_band)
	if variants.is_empty():
		return
	_apply_domestic_prop_variants(variants, state)


func _current_domestic_time_band() -> StringName:
	if _view_runtime != null:
		return ROUTINE_CONTROLLER_SCRIPT.time_band_for_cycle_progress(_view_runtime.cycle_progress)
	return ROUTINE_CONTROLLER_SCRIPT.time_band_for_cycle_progress(DayNightCycle.DEFAULT_PROGRESS)


func _on_kalev_presentation_changed(prop_variants: Dictionary, held_socket: StringName) -> void:
	var state := SessionState.state if has_node("/root/SessionState") else null
	if not prop_variants.is_empty():
		_apply_domestic_prop_variants(prop_variants, state)
	if player != null and not held_socket.is_empty():
		var facing := _kalev_routine.station_facing(_domestic_vignette_activity)
		if not facing.is_zero_approx():
			player.set_view_facing(facing)


func _apply_domestic_prop_variants(prop_variants: Dictionary, state: GameState) -> void:
	if _map_definition == null or prop_variants.is_empty():
		return
	for prop in _map_definition.props:
		var prop_id := String(prop.get("id", ""))
		if prop_variants.has(prop_id):
			prop["style_variant"] = StringName(String(prop_variants[prop_id]))
	if state != null:
		_kalev_routine.persist_prop_variants(state, prop_variants)


func _spawn_domestic_interactables(definition: MapDefinition) -> void:
	_clear_domestic_interactables()
	var root := Node2D.new()
	root.name = "DomesticInteractables"
	add_child(root)
	for activity_id in DOMESTIC_INTERACT_PROMPTS.keys():
		var point := _kalev_routine.get_activity_point(activity_id)
		if point == null:
			continue
		var interactable: Interactable = INTERACTABLE_SCENE.instantiate()
		interactable.name = "Domestic_%s" % String(activity_id).replace(".", "_")
		interactable.interactable_id = StringName("interact.domestic.%s" % String(activity_id))
		interactable.interaction_kind = InteractionKinds.USE
		interactable.prompt = String(DOMESTIC_INTERACT_PROMPTS[activity_id])
		interactable.global_position = point.approach_position
		interactable.set_interact_callback(_on_domestic_interact.bind(activity_id))
		root.add_child(interactable)
		_domestic_interactables[activity_id] = interactable
	_sync_domestic_interactables()


func _clear_domestic_interactables() -> void:
	for interactable: Interactable in _domestic_interactables.values():
		if interactable != null and is_instance_valid(interactable):
			interactable.free()
	_domestic_interactables.clear()
	var existing := get_node_or_null("DomesticInteractables")
	if existing != null:
		existing.free()


func _sync_domestic_interactables() -> void:
	if _kalev_routine == null:
		return
	var state := SessionState.state if has_node("/root/SessionState") else null
	var context := _kalev_routine.build_kalev_context(state, _current_domestic_time_band())
	var available := _kalev_routine.list_available_activities(KALEV_ID, context)
	var blocked := _domestic_story_blocks_player()
	for activity_id: StringName in _domestic_interactables.keys():
		var interactable: Interactable = _domestic_interactables[activity_id]
		if interactable == null or not is_instance_valid(interactable):
			continue
		var enabled := not blocked and available.has(activity_id)
		interactable.enabled = enabled
		interactable.visible = enabled


func _domestic_story_blocks_player() -> bool:
	if _dialogue_encounter != null:
		var runner := _dialogue_encounter.get_dialogue_runner()
		if runner != null and runner.is_active():
			return true
	var commission := player.get_node_or_null("ForgeCommissionController")
	if commission != null and commission.has_method("is_active") and commission.call("is_active"):
		return true
	return false


func _on_domestic_interact(_actor: Node, activity_id: StringName) -> void:
	if _domestic_story_blocks_player() or _kalev_routine == null or player == null:
		return
	var state := SessionState.state if has_node("/root/SessionState") else null
	var context := _kalev_routine.build_kalev_context(state, _current_domestic_time_band())
	if not _kalev_routine.can_begin(KALEV_ID, activity_id, context):
		return
	var point := _kalev_routine.get_activity_point(activity_id)
	if point != null and not _kalev_routine.station_within_tolerance(player.global_position, activity_id):
		return
	_domestic_vignette_activity = activity_id
	_domestic_vignette_seconds = point.sample_duration_sec(1343) if point != null else 2.0
	# Prop-variant maps may be empty for some beats; still accept when the
	# routine controller successfully owns the activity.
	var presentation := _kalev_routine.apply_kalev_activity_presentation(activity_id, context)
	if not presentation.is_empty() or _kalev_routine.active_activity_for(KALEV_ID) == activity_id:
		if _domestic_presenter != null:
			_domestic_presenter.begin_activity(
				activity_id,
				_kalev_routine.activity_held_socket(activity_id),
				_domestic_vignette_seconds
			)
		_set_domestic_player_lock(true)
		_persist_domestic_runtime_state()
	else:
		_domestic_vignette_activity = &""
		_domestic_vignette_seconds = 0.0


func _tick_domestic_presentation(delta: float) -> void:
	if _kalev_routine == null:
		return
	var time_band := _current_domestic_time_band()
	if time_band != _last_domestic_time_band:
		_last_domestic_time_band = time_band
		_apply_phase_entry_domestic_presentation()
		_sync_domestic_interactables()
	_sync_domestic_interactables()
	if _domestic_vignette_seconds <= 0.0 or _domestic_vignette_activity.is_empty():
		return
	if _domestic_story_blocks_player() or not _kalev_routine.station_within_tolerance(
		player.global_position,
		_domestic_vignette_activity
	):
		_clear_domestic_vignette(false)
		return
	_domestic_vignette_seconds -= delta
	if _domestic_presenter != null:
		_domestic_presenter.global_position = _kalev_rig.global_position if _kalev_rig != null else Vector3.ZERO
	if _domestic_vignette_seconds > 0.0:
		_persist_domestic_runtime_state()
		return
	_clear_domestic_vignette(true)


func _clear_domestic_vignette(completed: bool, persist: bool = true) -> void:
	if _kalev_routine != null and not _domestic_vignette_activity.is_empty():
		_kalev_routine.complete_kalev_activity_presentation(
			_domestic_vignette_activity,
			ROUTINE_CONTROLLER_SCRIPT.REASON_COMPLETED if completed else ROUTINE_CONTROLLER_SCRIPT.REASON_CANCELLED
		)
	if _domestic_presenter != null:
		_domestic_presenter.clear_activity(completed)
	_domestic_vignette_activity = &""
	_domestic_vignette_seconds = 0.0
	_set_domestic_player_lock(false)
	if persist:
		_persist_domestic_runtime_state()


func _set_domestic_player_lock(locked: bool) -> void:
	if player == null:
		return
	player.velocity = Vector2.ZERO
	player.set_physics_process(not locked)


func _persist_domestic_runtime_state() -> void:
	var state := SessionState.state if has_node("/root/SessionState") else null
	if state == null:
		return
	var presenter_snapshot := _domestic_presenter.snapshot() if _domestic_presenter != null else {}
	state.map_world_state.record_object_delta(
		&"loc.kalev_smithy",
		DOMESTIC_RUNTIME_STATE_ID,
		{
			"snapshot_version": 1,
			"active": not _domestic_vignette_activity.is_empty(),
			"activity_id": String(_domestic_vignette_activity),
			"remaining_sec": _domestic_vignette_seconds,
			"presenter": presenter_snapshot,
		}
	)


func _restore_domestic_runtime_state(state: GameState) -> void:
	if state == null or _kalev_routine == null:
		return
	var snapshot := state.map_world_state.object_delta(&"loc.kalev_smithy", DOMESTIC_RUNTIME_STATE_ID)
	if not bool(snapshot.get("active", false)):
		return
	var activity_id := StringName(String(snapshot.get("activity_id", "")))
	var point := _kalev_routine.get_activity_point(activity_id)
	if activity_id.is_empty() or point == null:
		return
	var context := _kalev_routine.build_kalev_context(state, _current_domestic_time_band())
	if not _kalev_routine.begin_activity(KALEV_ID, activity_id, context):
		return
	_domestic_vignette_activity = activity_id
	_domestic_vignette_seconds = maxf(float(snapshot.get("remaining_sec", 0.05)), 0.05)
	_kalev_routine.apply_kalev_activity_presentation(activity_id, context)
	if _domestic_presenter != null:
		var presenter_snapshot := snapshot.get("presenter", {}) as Dictionary
		if not _domestic_presenter.restore_snapshot(presenter_snapshot):
			_domestic_presenter.begin_activity(
				activity_id,
				_kalev_routine.activity_held_socket(activity_id),
				_domestic_vignette_seconds,
				true
			)
	_set_domestic_player_lock(true)


func _persist_henning_runtime_state() -> void:
	var state := SessionState.state if has_node("/root/SessionState") else null
	if state == null or henning == null:
		return
	state.map_world_state.record_object_delta(
		&"loc.kalev_smithy",
		HENNING_RUNTIME_STATE_ID,
		{"snapshot_version": 1, "visitor": henning.runtime_snapshot()}
	)


func _restore_henning_runtime_state(state: GameState) -> void:
	if state == null or henning == null:
		return
	var saved := state.map_world_state.object_delta(&"loc.kalev_smithy", HENNING_RUNTIME_STATE_ID)
	if int(saved.get("snapshot_version", 0)) != 1:
		return
	henning.restore_runtime_snapshot(saved.get("visitor", {}) as Dictionary)


func smithy_domestic_telemetry() -> Dictionary:
	return {
		"reservations": _station_reservations.telemetry() if _station_reservations != null else {},
		"presentation": _domestic_presenter.telemetry() if _domestic_presenter != null else {},
		"active_activity": String(_domestic_vignette_activity),
	}
