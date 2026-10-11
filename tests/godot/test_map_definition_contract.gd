class_name TestMapDefinitionContract
extends RefCounted

var _failures: Array[String] = []

func _get_failures() -> Array[String]:
	return _failures.duplicate()

func test_all() -> void:
	
	test_valid_definition()
	test_out_of_bounds_rejection()
	test_duplicate_id_rejection()
	test_active_scope_rejection()
	test_fingerprint_preservation()
	

func test_valid_definition() -> void:
	
	var def := _create_base_def()
	var validation := def.validate()
	if not validation.is_empty():
		_failures.append("Valid definition should have no errors, got: " + str(validation))
	

func test_out_of_bounds_rejection() -> void:
	
	var def := _create_base_def()
	
	# Out of bounds interaction anchor
	def.interaction_anchors = [{"id": &"anchor_1", "position": Vector2(9999, 9999)}]
	var val1 := def.validate()
	if not _has_error(val1, "outside world bounds"):
		_failures.append("Failed to reject out-of-bounds interaction anchor")
		
	# Out of bounds transition
	def.interaction_anchors = []
	def.transitions = [{"id": &"trans_1", "rect": Rect2(9999, 9999, 10, 10)}]
	var val2 := def.validate()
	if not _has_error(val2, "outside world bounds"):
		_failures.append("Failed to reject out-of-bounds transition")
		
	

func test_duplicate_id_rejection() -> void:
	
	var def := _create_base_def()
	
	def.buildings = [{"id": &"dupe_id", "kind": &"house", "footprint": Rect2(0, 0, 10, 10)}]
	def.props = [{"id": &"dupe_id", "kind": &"anvil", "position": Vector2(5, 5)}]
	
	var val := def.validate()
	if not _has_error(val, "duplicate stable id"):
		_failures.append("Failed to reject duplicate stable id between building and prop")
		
	

func test_active_scope_rejection() -> void:
	
	
	var def1 := _create_base_def()
	def1.scope = &"prototype"
	def1.active = true
	if not _has_error(def1.validate(), "active=true is rejected for prototype or archive"):
		_failures.append("Failed to reject active=true for prototype")
		
	var def2 := _create_base_def()
	def2.scope = &"archive"
	def2.active = true
	if not _has_error(def2.validate(), "active=true is rejected for prototype or archive"):
		_failures.append("Failed to reject active=true for archive")
		
	

func test_fingerprint_preservation() -> void:
	
	var def1 := SmithyCourtyardDefinition.create()
	var def2 := SmithyCourtyardDefinition.create()
	if def1.fingerprint != def2.fingerprint:
		_failures.append("Fingerprint not preserved across builds")
	

func _create_base_def() -> MapDefinition:
	var def := MapDefinition.new()
	def.map_id = &"test_map"
	def.cell_size = 32
	def.size_cells = Vector2i(10, 10)
	def.base_terrain = &"grass"
	def.player_spawn = Vector2(160, 160)
	def.location = &"test_location"
	def.scope = &"production"
	def.active = true
	def.palette = &"clean_painted"
	def.fingerprint = "test_fingerprint_123"
	def.camera_bounds = Rect2(0, 0, 320, 320)
	return def

func _has_error(errors: Array[String], substring: String) -> bool:
	for e in errors:
		if e.find(substring) != -1:
			return true
	return false
