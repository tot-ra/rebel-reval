extends SceneTree

const LowerTownSliceDefinition := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapParitySnapshot := preload("res://scripts/map/map_parity_snapshot.gd")

const OUTPUT_PATH := "res://tests/fixtures/maps/lower_town_slice.parity.json"
const REQUIRED_FLAG := "--write-lower-town-slice-parity-fixture"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if REQUIRED_FLAG not in args:
		for argument in OS.get_cmdline_args():
			if argument == REQUIRED_FLAG:
				args.append(argument)
				break
	if not REQUIRED_FLAG in args:
		push_error(
			"Refusing to regenerate parity fixture without explicit %s flag." % REQUIRED_FLAG
		)
		quit(2)
		return

	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var errors: Array[String] = MapBuilder.validate(definition)
	if not errors.is_empty():
		push_error("Cannot snapshot invalid lower_town_slice: %s" % str(errors))
		quit(1)
		return

	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK:
		push_error("Could not create fixture directory: error %d" % directory_error)
		quit(1)
		return
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open parity fixture for writing: %s" % FileAccess.get_open_error())
		quit(1)
		return
	file.store_string(MapParitySnapshot.serialize(definition, grid))
	file.close()
	print("Wrote %s" % OUTPUT_PATH)
	quit(0)
