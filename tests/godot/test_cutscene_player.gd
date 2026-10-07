extends "res://tests/godot/test_case.gd"

## ADR 0034 / R-1317: the cutscene records parse, and the player walks shots and lines
## deterministically, skips, and resolves its chain target without changing scene.

const CONTENT_DIRS: Array[String] = [
	"res://content/cutscenes",
	"res://content/prologue",
	"res://content/examples/valid",
	"res://content/examples/support",
]
const CONQUEST := &"cutscene.prologue.conquest"
const ALMSHOUSE := &"cutscene.prologue.almshouse_dawn"
const TAKEN_IN := &"cutscene.prologue.taken_in"

var _db: ContentDB
var _root: Node


func before_each() -> void:
	super.before_each()
	_db = ContentDB.new()
	assert_true(_db.load_from_directories(CONTENT_DIRS))
	_root = Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_root)


func after_each() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	super.after_each()


func _player(cutscene_id: StringName) -> CutscenePlayer:
	var player := CutscenePlayer.new()
	player.auto_continue = false
	_root.add_child(player)
	assert_true(player.play_id(_db, cutscene_id), String(cutscene_id))
	return player


func test_prologue_records_load_as_cutscenes() -> void:
	for cutscene_id: StringName in [CONQUEST, ALMSHOUSE, TAKEN_IN]:
		var record := _db.get_cutscene(cutscene_id)
		assert_false(record.is_empty(), String(cutscene_id))
		assert_eq(_db.get_record_type(cutscene_id), ContentDB.TYPE_CUTSCENE)


func test_sequence_parses_shots_lines_and_chain() -> void:
	var sequence := CutsceneSequence.from_record(_db.get_cutscene(CONQUEST))
	assert_true(sequence != null, "sequence parses")
	assert_eq(sequence.shot_count(), 6)
	assert_eq(String(sequence.grade), "memory_cold")
	assert_eq(String(sequence.shots[0].id), "s01_fleet")
	assert_true(sequence.shots[0].lines.size() >= 2)
	assert_true(sequence.shots[0].duration() > 0.0)
	assert_eq(String(sequence.next_target.get("kind", "")), "scene_file")
	# Captions carry the facts a skipping player must still receive.
	assert_eq(sequence.captions().size(), 6)


func test_a_missing_record_is_refused_instead_of_half_playing() -> void:
	assert_true(CutsceneSequence.from_record({}) == null, "empty record")
	assert_true(
		CutsceneSequence.from_record({"type": "dialogue", "shots": []}) == null, "wrong type"
	)
	var player := CutscenePlayer.new()
	player.auto_continue = false
	_root.add_child(player)
	assert_false(player.play_id(_db, &"cutscene.prologue.does_not_exist"))
	assert_false(player.is_playing)


func test_advance_walks_every_line_then_every_shot() -> void:
	var player := _player(ALMSHOUSE)
	assert_eq(player.shot_index, 0)
	assert_eq(player.line_index, 0)
	var sequence := player.sequence
	var total_lines := 0
	for shot: CutsceneSequence.Shot in sequence.shots:
		total_lines += shot.lines.size()
	# One advance per line; the last one ends the sequence.
	for i in total_lines:
		player.advance()
	assert_false(player.is_playing)
	assert_eq(player.shot_index, sequence.shot_count())


func test_finished_reports_whether_the_player_skipped() -> void:
	var player := _player(CONQUEST)
	var seen: Array = []
	player.finished.connect(func(id: StringName, skipped: bool) -> void: seen.append([id, skipped]))
	player.skip()
	assert_eq(seen.size(), 1)
	assert_eq(String(seen[0][0]), String(CONQUEST))
	assert_true(bool(seen[0][1]))
	assert_false(player.is_playing)
	# A second skip must not emit again.
	player.skip()
	assert_eq(seen.size(), 1)


func test_shot_and_line_signals_fire_in_order() -> void:
	var player := _player(TAKEN_IN)
	var shots: Array[int] = []
	player.shot_changed.connect(func(_id: StringName, index: int) -> void: shots.append(index))
	while player.is_playing:
		player.advance()
	assert_eq(shots, [1, 2] as Array[int])


func test_auto_advance_uses_the_authored_line_timing() -> void:
	var player := _player(ALMSHOUSE)
	var first_line := player.current_shot().lines[0]
	player._process(first_line.seconds * 0.5)
	assert_eq(player.line_index, 0)
	player._process(first_line.seconds * 0.6)
	assert_eq(player.line_index, 1)


func test_every_shot_points_at_a_frame_that_exists() -> void:
	for cutscene_id: StringName in [CONQUEST, ALMSHOUSE, TAKEN_IN]:
		var sequence := CutsceneSequence.from_record(_db.get_cutscene(cutscene_id))
		for shot: CutsceneSequence.Shot in sequence.shots:
			var path := shot.media_path()
			assert_false(path.is_empty(), String(shot.id))
			assert_true(ResourceLoader.exists(path), path)
