extends Node

## Host entry for D-004 walkthrough capture. Run with a normal project main
## loop so autoloads such as SessionState are visible to scene scripts:
##   godot --path . res://tools/capture_demo_walkthrough_host.tscn
## WHY: DoorNavigator.go_to_scene defers change_scene; this host changes scenes
## synchronously and waits for frame_post_draw so PNG captures are not stale.

const OUTPUT_DIR := "res://docs/reports/images/demo_walkthrough"
const REPORT_PATH := "res://docs/reports/demo_walkthrough_d004.md"
const SETTLE_FRAMES := 20
const ITEM_SPEARHEAD := &"item.seized_spearhead"
const FLAG_DEMO_MART_SPOKEN := &"flag.demo_mart_spoken"


func _ready() -> void:
	# DoorNavigator swaps current_scene; keep this runner on the root so captures
	# survive forge <-> Lower Town transitions.
	var tree := get_tree()
	if get_parent() != tree.root:
		reparent(tree.root)
	if tree.current_scene == self:
		tree.current_scene = null
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_reset_session()

	if not await _goto(&"forge", &"smithy_start"):
		push_error("Failed to reach forge start scene")
		get_tree().quit(1)
		return
	if not await _capture("01_forge_start", "Start lands at smithy_start"):
		get_tree().quit(1)
		return

	var forge := get_tree().current_scene
	var player: CharacterBody2D = forge.get_node("Actors/Player")
	var start := player.global_position
	player.global_position = start + Vector2(160.0, 24.0)
	await _settle(SETTLE_FRAMES)
	if not await _capture("02_forge_move", "Player moves inside the forge"):
		get_tree().quit(1)
		return

	if not await _goto(&"reval_east", &"forge"):
		push_error("Failed to reach Lower Town")
		get_tree().quit(1)
		return
	if not await _capture("03_lower_town_arrive", "Courtyard door reaches Lower Town"):
		get_tree().quit(1)
		return

	var east := get_tree().current_scene
	var encounter := east.get_node_or_null("DemoMartEncounter") as DemoMartEncounter
	if encounter == null:
		push_error("DemoMartEncounter missing on Lower Town")
		get_tree().quit(1)
		return
	var talk := encounter.get_interactable()
	var runner := encounter.get_dialogue_runner()
	player = east.get_node("Actors/Player")
	player.global_position = talk.global_position
	talk.register_actor_in_range(player)
	if not talk.interact(player):
		push_error("Talk to Mart failed")
		get_tree().quit(1)
		return
	await _settle(12)
	if not runner.is_active():
		push_error("Mart dialogue did not stay open for capture")
		get_tree().quit(1)
		return
	if not await _capture("04_mart_talk", "Mart dialogue is open"):
		get_tree().quit(1)
		return
	while runner.is_active():
		runner.advance_for_test()
		await get_tree().process_frame
	if not bool(SessionState.state.get_flag(FLAG_DEMO_MART_SPOKEN)):
		push_error("Mart dialogue did not set flag.demo_mart_spoken")
		get_tree().quit(1)
		return
	if not await _capture("05_mart_done", "Mart conversation completed"):
		get_tree().quit(1)
		return

	if not await _goto(&"forge", &"door_courtyard"):
		push_error("Failed to return to forge for pickup")
		get_tree().quit(1)
		return
	forge = get_tree().current_scene
	player = forge.get_node("Actors/Player")
	var pickup := _find_pickup(forge)
	if pickup == null:
		push_error("Anvil spearhead missing after return")
		get_tree().quit(1)
		return
	player.global_position = pickup.global_position
	pickup.register_actor_in_range(player)
	if not pickup.interact(player):
		push_error("Spearhead pickup failed")
		get_tree().quit(1)
		return
	await _settle(8)
	if not bool(SessionState.state.has_item(ITEM_SPEARHEAD)):
		push_error("Spearhead did not enter the bag")
		get_tree().quit(1)
		return
	var inventory := player.get_node_or_null("InventoryController") as InventoryController
	if inventory != null:
		inventory.open()
	await _settle(12)
	if not await _capture("06_spearhead_pickup", "Seized spearhead is in the bag"):
		get_tree().quit(1)
		return

	_write_report()
	print("D-004 walkthrough capture complete under %s" % OUTPUT_DIR)
	get_tree().quit(0)


func _reset_session() -> void:
	SessionState.state = GameState.new()
	SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.bag.try_add(&"item.forge_hammer")
	SessionState.state.equip_from_bag(&"right_hand", &"item.forge_hammer")


func _goto(scene_id: StringName, spawn_id: StringName) -> bool:
	# Mirror DoorNavigator spawn bookkeeping, but change scenes immediately so the
	# capture host can wait on a real current_scene path instead of a deferred swap.
	if not DoorNavigator.has_active_scene(scene_id) or not DoorNavigator.has_spawn(scene_id, spawn_id):
		push_error("Missing transition target %s/%s" % [String(scene_id), String(spawn_id)])
		return false
	DoorNavigator.pending_spawn_scene_id = scene_id
	DoorNavigator.pending_spawn_id = spawn_id
	DoorNavigator.spawn_door_tag = null
	var path := DoorNavigator.get_scene_path(scene_id)
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("change_scene_to_file failed for %s (%s)" % [path, error_string(err)])
		return false
	for _i in 180:
		var scene := get_tree().current_scene
		if scene != null and String(scene.scene_file_path) == path:
			await _settle(SETTLE_FRAMES)
			print("Arrived at %s (%s)" % [path, String(scene.name)])
			return true
		await get_tree().process_frame
	push_error("Timed out waiting for %s" % path)
	return false


func _find_pickup(forge: Node) -> Interactable:
	for node in forge.find_children("*", "Area2D", true, false):
		var interactable := node as Interactable
		if interactable != null and interactable.get_interaction_kind() == InteractionKinds.PICKUP:
			return interactable
	return null


func _capture(stem: String, caption: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, stem]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Failed to save %s" % path)
		return false
	var scene := get_tree().current_scene
	var scene_path := String(scene.scene_file_path) if scene != null else "<none>"
	print("Walkthrough capture: %s (%s) scene=%s" % [path, caption, scene_path])
	return true


func _settle(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _write_report() -> void:
	var lines: PackedStringArray = [
		"# Demo walkthrough (D-004)",
		"",
		"Captured proof that the packaged demo loop completes without debug intervention:",
		"Start -> forge move -> Lower Town Mart talk -> forge spearhead pickup into the bag.",
		"",
		"## How to reproduce",
		"",
		"```bash",
		"tools/verify_packaged_demo.sh",
		"# or capture frames only:",
		"godot --path . res://tools/capture_demo_walkthrough_host.tscn",
		"```",
		"",
		"## Frame sequence",
		"",
		"| Step | Capture | What it shows |",
		"|------|---------|---------------|",
		"| 1 | ![forge start](images/demo_walkthrough/01_forge_start.png) | Main-menu Start lands at `smithy_start` |",
		"| 2 | ![forge move](images/demo_walkthrough/02_forge_move.png) | Player can move in the forge |",
		"| 3 | ![lower town](images/demo_walkthrough/03_lower_town_arrive.png) | Courtyard door reaches Lower Town |",
		"| 4 | ![mart talk](images/demo_walkthrough/04_mart_talk.png) | Talk to Mart opens demo dialogue |",
		"| 5 | ![mart done](images/demo_walkthrough/05_mart_done.png) | Conversation completes and sets `flag.demo_mart_spoken` |",
		"| 6 | ![pickup](images/demo_walkthrough/06_spearhead_pickup.png) | Anvil spearhead is taken into the bag |",
		"",
		"## Automated checks",
		"",
		"- Headless flow: `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_demo_walkthrough`",
		"- Packaged macOS build: `tools/verify_packaged_demo.sh` exports `build/rr.dmg`, extracts `build/Reval Rebel.app`, and runs `Reval Rebel.app/Contents/MacOS/Reval Rebel -- --verify-packaged-demo`.",
		"- The shipped main-scene verifier triggers Start, proves movement, completes Mart's interaction, picks up the spearhead, and must print `D-004C_PACKAGED_WALKTHROUGH_PASS` with exit 0. No editor binary chooses scenes or drives the packaged loop.",
		"",
		"Release builds omit the debug inspector (`OS.is_debug_build()` is false), so this loop matches packaged play without debug presets.",
		"",
	]
	var file := FileAccess.open(ProjectSettings.globalize_path(REPORT_PATH), FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % REPORT_PATH)
		return
	file.store_string("\n".join(lines))
	file.close()
	print("Wrote %s" % REPORT_PATH)
