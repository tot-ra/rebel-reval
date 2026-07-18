extends Node

## Applies authored slice phase profiles when GameState.phase changes.
## Owns phase-boundary autosave and global presentation hooks (music, lighting).

const PhaseProfileModelScript := preload("res://scripts/phase/phase_profile_model.gd")

signal profile_applied(profile: Dictionary, phase_id: StringName)

var _connected_state: GameState


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_connect_session")


func sync_current_phase() -> void:
	if SessionState.state == null:
		return
	apply_profile_for_phase(SessionState.state.get_phase())


func apply_profile_for_phase(phase_id: StringName) -> void:
	if phase_id.is_empty():
		return
	var profile := PhaseProfileModelScript.resolve_profile(phase_id, SessionState.content_db)
	_apply_presentation(profile)
	profile_applied.emit(profile, phase_id)


func advance_to_next_phase() -> bool:
	if SessionState.state == null:
		return false
	var next := PhaseProfileModelScript.next_phase_id(SessionState.state.get_phase(), SessionState.content_db)
	if next.is_empty():
		return false
	SessionState.state.set_phase(next)
	return true


func _connect_session() -> void:
	if SessionState.state == null:
		return
	_bind_state(SessionState.state)
	if not SessionState.debug_state_applied.is_connected(_on_debug_state_applied):
		SessionState.debug_state_applied.connect(_on_debug_state_applied)
	sync_current_phase()


func _bind_state(state: GameState) -> void:
	if _connected_state != null and _connected_state.phase_changed.is_connected(_on_phase_changed):
		_connected_state.phase_changed.disconnect(_on_phase_changed)
	_connected_state = state
	if not _connected_state.phase_changed.is_connected(_on_phase_changed):
		_connected_state.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(_previous: StringName, next: StringName) -> void:
	if not SessionState.save_game():
		push_warning("Phase-boundary autosave failed for phase %s" % String(next))
	apply_profile_for_phase(next)


func _on_debug_state_applied(_preset_id: StringName) -> void:
	_bind_state(SessionState.state)
	sync_current_phase()


func _apply_presentation(profile: Dictionary) -> void:
	var presentation := PhaseProfileModelScript.presentation(profile)
	if presentation.is_empty():
		return
	var progress := float(presentation.get("cycle_progress", 0.25))
	if bool(presentation.get("music_night_tracks", false)):
		progress = 0.0
	MusicDirector.set_cycle_progress(progress)
