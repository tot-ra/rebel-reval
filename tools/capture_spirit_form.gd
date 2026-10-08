extends SceneTree

## Review plates for the porter's spirit form and the duel's consequences (R-1335). GPU run:
##   tools/godot_render.sh --resolution 1280x720 --script tools/capture_spirit_form.gd -- \
##     --out=res://build/spirit_form
## Plates: form_key.png (rusted key swelling on the first telegraphed blow), form_cracked.png
## (the rod after two fireballs: smaller, cracked), form_shattered.png (broken porter),
## form_silhouette.png (an arena without a staged actor draws the body itself),
## kalev_struck.png (Kalev's reaction after the shove).
##
## WHY every game class is reached through `load()` instead of its `class_name`: a `--script`
## SceneTree tool is compiled before the autoloads are registered, so naming a class that
## reads the `SessionState` singleton (`AlmshouseOpening`, and `SpiritArenaHost` through
## `DialogueRunner` -> `StateRuleEvaluator` -> `CommissionDeadlineModel`) fails to compile
## with "Identifier not found: SessionState" and the tool loads as null. Loading the same
## scripts after the first frame compiles them with the singletons in place.

const OPENING_SCENE := "res://scenes/prologue/almshouse_opening.tscn"
const OPENING_SCRIPT := "res://scripts/prologue/almshouse_opening.gd"
const DUEL_SCRIPT := "res://scripts/combat/spirit_duel.gd"
const ARENA_HOST_SCRIPT := "res://scripts/combat/spirit_arena_host.gd"
const GAME_STATE_SCRIPT := "res://scripts/state/game_state.gd"
const MAGIC_RESOLVER_SCRIPT := "res://scripts/magic/magic_resolver.gd"
## Evidence-plate size (`docs/ASSET_STORAGE_POLICY.md`).
const PLATE_WIDTH := 1280
const PLATE_HEIGHT := 720
const ENDING_FLAGS: Array[StringName] = [
	&"flag.prologue.apprenticed",
	&"flag.prologue.struck_porter",
	&"flag.prologue.broke_porter",
	&"flag.prologue.punished_by_porter",
	&"flag.prologue.spared_porter",
]

var _opening_scene: PackedScene
var _opening_script: GDScript
var _duel_script: GDScript
var _host_script: GDScript
var _telegraph_sec := 1.2


func _init() -> void:
	var out := "res://build/spirit_form"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	# Autoloads (SessionState, DoorNavigator) are registered only after the first frame; the
	# game scripts are loaded after it so they compile with the singletons available.
	await process_frame
	_opening_scene = load(OPENING_SCENE) as PackedScene
	_opening_script = load(OPENING_SCRIPT) as GDScript
	_duel_script = load(DUEL_SCRIPT) as GDScript
	_host_script = load(ARENA_HOST_SCRIPT) as GDScript
	_telegraph_sec = float(_duel_script.TELEGRAPH_SEC)

	var opening := _opening()
	opening.begin_duel()
	var host: Node = opening.host()
	host.duel.tick(_telegraph_sec * 0.8)
	await _settle(host)
	await _save(out + "/form_key.png")
	host.duel.tick(_telegraph_sec)
	host.duel.answer("fire_hands")
	host.duel.tick(_telegraph_sec + 0.01)
	host.duel.answer("fire_lock")
	host.duel.tick(_telegraph_sec * 0.3)
	await _settle(host)
	await _save(out + "/form_cracked.png")
	host.duel.tick(_telegraph_sec)
	host.duel.answer("fire_secret")
	await _settle(host)
	await _save(out + "/form_shattered.png")
	opening.queue_free()
	await _frames(2)

	# An arena with no staged actor (world duels) draws the porter's body itself.
	var state_script := load(GAME_STATE_SCRIPT) as GDScript
	var state: Object = state_script.new()
	var magic := load(MAGIC_RESOLVER_SCRIPT) as GDScript
	for grant_id: StringName in _opening_script.STARTER_GRANTS:
		magic.apply_grant_operation(state, _session_db(), grant_id)
	# A constant is read off the script, not the instance (GDScript forbids the latter).
	state.set_magic_resource(state_script.MAGIC_RESOURCE_WILLPOWER, 8)
	var backdrop := CanvasLayer.new()
	var dark := ColorRect.new()
	dark.color = Color(0.08, 0.07, 0.1)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(dark)
	root.add_child(backdrop)
	var bare: Node = _host_script.new()
	bare.freeze_world = false
	root.add_child(bare)
	bare.open(_session_db(), state, _opening_script.CONFRONTATION)
	bare.duel.tick(_telegraph_sec + 0.01)
	bare.duel.answer("still_hunger")
	bare.duel.tick(_telegraph_sec * 0.5)
	await _settle(bare)
	await _save(out + "/form_silhouette.png")
	bare.close()
	bare.queue_free()
	backdrop.queue_free()
	await _frames(2)

	var struck := _opening()
	struck.begin_duel()
	struck.host().duel.tick(_telegraph_sec + 0.01)
	struck.host().duel.answer("shove")
	struck.host().close()
	await _frames(6)
	await _save(out + "/kalev_struck.png")
	print("GUILT ", _session_state().guilt.levels())
	quit()


func _opening() -> Node:
	for flag: StringName in ENDING_FLAGS:
		_session_state().set_flag(flag, false)
	_session_state().guilt.reset()
	var opening: Node = _opening_scene.instantiate()
	opening.auto_continue = false
	root.add_child(opening)
	return opening


## Let the form's eased presence catch up with the duel before the plate is taken.
func _settle(host: Node) -> void:
	await _frames(2)
	host.form_view().advance(10.0)
	await _frames(2)


## Autoloads are not compile-time identifiers in a SceneTree script; look them up.
func _session_state() -> Object:
	return root.get_node(^"SessionState").get("state")


func _session_db() -> Object:
	return root.get_node(^"SessionState").get("content_db")


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	# The viewport is the project's 1920x1080 whatever `--resolution` asks for, so the plate
	# is scaled down to the evidence-image standard (ASSET_STORAGE_POLICY.md: 1280x720 PNG).
	if image.get_width() > PLATE_WIDTH:
		image.resize(PLATE_WIDTH, PLATE_HEIGHT, Image.INTERPOLATE_LANCZOS)
	image.save_png(path)
	print("CAPTURED ", path)
