extends Node2D

## One immutable Smithy Courtyard composition rendered through P0-036 style profiles.

const DEFINITION_SCRIPT := preload("res://scripts/map/smithy_courtyard_definition.gd")

@export_enum("pixel", "digital_woodcut", "clean_painted") var visual_target: String = "clean_painted"
@export_enum("day", "night") var time_of_day: String = "day"

@onready var camera: Camera2D = $Camera2D
@onready var actors: Node2D = $Actors
@onready var player: MapPrototypePlayer = $Actors/Player
@onready var target_label: Label = $CaptureOverlay/TargetLabel

var definition: MapDefinition
var grid: MapTerrainGrid
var assembled: Dictionary


func configure_style(target: StringName, day_phase: StringName = MapVisualStyle.TIME_DAY) -> void:
	assert(MapVisualStyle.is_valid_target(target))
	assert(MapVisualStyle.is_valid_time(day_phase))
	visual_target = String(target)
	time_of_day = String(day_phase)


func _ready() -> void:
	var target := StringName(visual_target)
	var day_phase := StringName(time_of_day)
	definition = DEFINITION_SCRIPT.create()
	grid = MapBuilder.build(definition)
	assembled = MapAssembler.assemble(self, definition, grid, actors, target, day_phase)

	player.configure_style(target, day_phase)
	player.global_position = definition.player_spawn
	camera.position = definition.world_size() * 0.5
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(definition.world_size().x)
	camera.limit_bottom = int(definition.world_size().y)
	target_label.text = "%s / %s" % [visual_target.replace("_", " ").to_upper(), time_of_day.to_upper()]


func comparison_signature() -> String:
	if definition == null or grid == null:
		return "not-ready"
	var footprint_rows: PackedStringArray = []
	for building in definition.buildings:
		footprint_rows.append("%s=%s" % [String(building["id"]), str(building["footprint"])])
	var prop_rows: PackedStringArray = []
	for prop in definition.props:
		prop_rows.append("%s=%s" % [String(prop["id"]), str(prop["position"])])
	return "world=%s;camera=%s@%s;grid=%s;terrain=%s;buildings=%s;props=%s;spawn=%s;collision=%s;pivot=%s;ysort=%s" % [
		str(definition.world_size()),
		str(camera.position),
		str(camera.zoom),
		grid.fingerprint(),
		str(grid.used_terrain_ids()),
		"|".join(footprint_rows),
		"|".join(prop_rows),
		str(definition.player_spawn),
		str(MapVisualStyle.CHARACTER_FOOTPRINT_PX),
		str(MapVisualStyle.CHARACTER_PIVOT_PX),
		str(actors.y_sort_enabled),
	]
