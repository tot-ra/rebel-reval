extends "res://scripts/global/BaseLevel.gd"

const DEFINITION_SCRIPT := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const INVESTIGATION_SCRIPT := preload("res://scripts/investigation/bitter_brew_investigation.gd")
const NIGHT_CONSEQUENCE_SCRIPT := preload(
	"res://scripts/investigation/bitter_brew_night_consequence.gd"
)
const AFTERMATH_SCRIPT := preload("res://scripts/investigation/bitter_brew_aftermath.gd")
const REPUTATION_SCRIPT := preload("res://scripts/faction/social_reputation_controller.gd")
const MARKET_DAY_SCRIPT := preload("res://scripts/world/market_day_controller.gd")
const SUPPLY_CHAIN_SCRIPT := preload("res://scripts/world/supply_chain_controller.gd")
const ENVIRONMENT_SCRIPT := preload("res://scripts/world/environmental_consequence_controller.gd")
const BELL_INVESTIGATION_SCRIPT := preload(
	"res://scripts/investigation/bell_and_chain_investigation.gd"
)
const BELL_NIGHT_SCRIPT := preload(
	"res://scripts/investigation/bell_and_chain_night_consequence.gd"
)
const BELL_AFTERMATH_SCRIPT := preload(
	"res://scripts/investigation/bell_and_chain_aftermath.gd"
)
const BREAD_INVESTIGATION_SCRIPT := preload(
	"res://scripts/investigation/bread_and_iron_investigation.gd"
)
const BREAD_INSTALL_SCRIPT := preload(
	"res://scripts/investigation/bread_and_iron_install_consequence.gd"
)
const BREAD_AFTERMATH_SCRIPT := preload(
	"res://scripts/investigation/bread_and_iron_aftermath.gd"
)
const PRICE_INVESTIGATION_SCRIPT := preload(
	"res://scripts/investigation/price_of_a_name_investigation.gd"
)
const PRICE_INSTALL_SCRIPT := preload(
	"res://scripts/investigation/price_of_a_name_install_consequence.gd"
)
const PRICE_AFTERMATH_SCRIPT := preload(
	"res://scripts/investigation/price_of_a_name_aftermath.gd"
)

@onready var map_root: Node2D = $MapRoot
@onready var actors: Node2D = $Actors
@onready var player: Player = $Actors/Player

var _bootstrap: Dictionary = {}
var _view_runtime: MapViewRuntime
var _mart_encounter: DemoMartEncounter
var _bitter_brew_investigation: Node
var _bitter_brew_night: Node
var _bitter_brew_aftermath: Node
var _social_reputation: Node
var _market_day: Node
var _supply_chain: Node
var _environmental_consequence: Node
var _bell_and_chain_investigation: Node
var _bell_and_chain_night: Node
var _bell_and_chain_aftermath: Node
var _bread_and_iron_investigation: Node
var _bread_and_iron_install: Node
var _bread_and_iron_aftermath: Node
var _price_of_a_name_investigation: Node
var _price_of_a_name_install: Node
var _price_of_a_name_aftermath: Node
var _phase_binder: MapPhaseBinder
var _patrol_controller: MapPatrolController


func _ready() -> void:
	super()
	var definition: MapDefinition = DEFINITION_SCRIPT.create()
	_bootstrap = MapSceneBootstrap.assemble(self, definition, actors, map_root)
	DoorNavigator.place_player(self, player, definition.player_spawn)
	_wire_player_navigation()
	MapSceneBootstrap.configure_player_movement(player, _bootstrap)

	_mart_encounter = DemoMartEncounter.new()
	_mart_encounter.name = "DemoMartEncounter"
	add_child(_mart_encounter)
	_mart_encounter.spawn_mart(actors, definition)

	_view_runtime = MapViewRuntime.install(self, _bootstrap, map_root, player)
	_setup_phase_binder(definition)
	_mart_encounter.wire(self, definition, player, _view_runtime)
	_bitter_brew_investigation = INVESTIGATION_SCRIPT.new()
	_bitter_brew_investigation.name = "BitterBrewInvestigation"
	add_child(_bitter_brew_investigation)
	_bitter_brew_investigation.setup(
		self,
		definition,
		player,
		_view_runtime,
		_mart_encounter.get_interaction_controller()
	)
	_bitter_brew_night = NIGHT_CONSEQUENCE_SCRIPT.new()
	_bitter_brew_night.name = "BitterBrewNightConsequence"
	add_child(_bitter_brew_night)
	_bitter_brew_night.setup(
		self,
		definition,
		player,
		_mart_encounter.get_interaction_controller(),
		actors
	)
	_bitter_brew_aftermath = AFTERMATH_SCRIPT.new()
	_bitter_brew_aftermath.name = "BitterBrewAftermath"
	add_child(_bitter_brew_aftermath)
	_bitter_brew_aftermath.setup(
		self,
		definition,
		player,
		_mart_encounter.get_interaction_controller(),
		_mart_encounter,
		_phase_binder,
		_patrol_controller,
		_bitter_brew_night,
		actors
	)
	_social_reputation = REPUTATION_SCRIPT.new()
	_social_reputation.name = "SocialReputationController"
	add_child(_social_reputation)
	_social_reputation.setup(self, &"loc.lower_town_slice", player)
	_market_day = MARKET_DAY_SCRIPT.new()
	_market_day.name = "MarketDayController"
	add_child(_market_day)
	_market_day.setup(
		self,
		definition,
		player,
		_view_runtime,
		_mart_encounter.get_interaction_controller(),
		&"loc.lower_town_slice"
	)
	_supply_chain = SUPPLY_CHAIN_SCRIPT.new()
	_supply_chain.name = "SupplyChainController"
	add_child(_supply_chain)
	_supply_chain.setup(
		self,
		definition,
		player,
		_view_runtime,
		actors,
		_mart_encounter.get_interaction_controller(),
		&"loc.lower_town_slice"
	)
	_environmental_consequence = ENVIRONMENT_SCRIPT.new()
	_environmental_consequence.name = "EnvironmentalConsequenceController"
	add_child(_environmental_consequence)
	_environmental_consequence.setup(_view_runtime, &"loc.lower_town_slice")
	_bell_and_chain_investigation = BELL_INVESTIGATION_SCRIPT.new()
	_bell_and_chain_investigation.name = "BellAndChainInvestigation"
	add_child(_bell_and_chain_investigation)
	_bell_and_chain_investigation.setup(
		self,
		definition,
		_view_runtime,
		_mart_encounter.get_interaction_controller()
	)
	_bell_and_chain_night = BELL_NIGHT_SCRIPT.new()
	_bell_and_chain_night.name = "BellAndChainNightConsequence"
	add_child(_bell_and_chain_night)
	_bell_and_chain_night.setup(self, definition, player, actors)
	_bell_and_chain_aftermath = BELL_AFTERMATH_SCRIPT.new()
	_bell_and_chain_aftermath.name = "BellAndChainAftermath"
	add_child(_bell_and_chain_aftermath)
	_bell_and_chain_aftermath.setup(
		self,
		player,
		_patrol_controller,
		_bell_and_chain_night
	)
	_bread_and_iron_investigation = BREAD_INVESTIGATION_SCRIPT.new()
	_bread_and_iron_investigation.name = "BreadAndIronInvestigation"
	add_child(_bread_and_iron_investigation)
	_bread_and_iron_investigation.setup(
		self,
		definition,
		_view_runtime,
		_mart_encounter.get_interaction_controller()
	)
	_bread_and_iron_install = BREAD_INSTALL_SCRIPT.new()
	_bread_and_iron_install.name = "BreadAndIronInstallConsequence"
	add_child(_bread_and_iron_install)
	_bread_and_iron_install.setup(self, definition, player, actors)
	_bread_and_iron_aftermath = BREAD_AFTERMATH_SCRIPT.new()
	_bread_and_iron_aftermath.name = "BreadAndIronAftermath"
	add_child(_bread_and_iron_aftermath)
	_bread_and_iron_aftermath.setup(
		self,
		player,
		_patrol_controller,
		_bread_and_iron_install
	)
	_price_of_a_name_investigation = PRICE_INVESTIGATION_SCRIPT.new()
	_price_of_a_name_investigation.name = "PriceOfANameInvestigation"
	add_child(_price_of_a_name_investigation)
	_price_of_a_name_investigation.setup(
		self,
		definition,
		_view_runtime,
		_mart_encounter.get_interaction_controller()
	)
	_price_of_a_name_install = PRICE_INSTALL_SCRIPT.new()
	_price_of_a_name_install.name = "PriceOfANameInstallConsequence"
	add_child(_price_of_a_name_install)
	_price_of_a_name_install.setup(self, definition, player, actors)
	_price_of_a_name_aftermath = PRICE_AFTERMATH_SCRIPT.new()
	_price_of_a_name_aftermath.name = "PriceOfANameAftermath"
	add_child(_price_of_a_name_aftermath)
	_price_of_a_name_aftermath.setup(
		self,
		player,
		_patrol_controller,
		_price_of_a_name_install
	)


func _setup_phase_binder(definition: MapDefinition) -> void:
	_phase_binder = MapPhaseBinder.new()
	_phase_binder.name = "MapPhaseBinder"
	add_child(_phase_binder)
	_phase_binder.setup(&"loc.lower_town_slice", definition, _view_runtime)
	_patrol_controller = MapPatrolController.new()
	_patrol_controller.name = "ViruWatchPatrol"
	add_child(_patrol_controller)
	_patrol_controller.setup(definition, &"viru_watch", actors)
	_phase_binder.register_patrol(&"viru_watch", _patrol_controller)
	if _mart_encounter != null:
		_mart_encounter.register_phase_binder(_phase_binder, definition)


func _wire_player_navigation() -> void:
	var navigation: NavigationRegion2D = _bootstrap.get("navigation")
	if player != null and navigation != null and player.navigation_agent != null:
		player.navigation_agent.set_navigation_map(navigation.get_navigation_map())
