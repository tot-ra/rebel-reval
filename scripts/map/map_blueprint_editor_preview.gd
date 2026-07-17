@tool
class_name MapBlueprintEditorPreview
extends Node2D

## Disposable editor visualization for a MapBlueprint factory. The blueprint and
## compiler output remain authoritative; generated children deliberately have no
## scene owner so saving the host scene cannot serialize them.

const GENERATED_ROOT_NAME := "_MapBlueprintPreviewGenerated"
const PREVIEW_GROUP := &"map_blueprint_editor_preview"

@export_category("Map Blueprint Preview")
@export var blueprint_factory: Script:
	set(value):
		blueprint_factory = value
		_request_rebuild()

@export_tool_button("Rebuild Preview", "Reload") var rebuild_preview_action: Callable = rebuild_preview
@export_tool_button("Validate", "StatusSuccess") var validate_action: Callable = validate

@export_group("Overlays")
@export var show_stable_ids := false:
	set(value):
		show_stable_ids = value
		_update_overlay()
@export var show_anchors := true:
	set(value):
		show_anchors = value
		_update_overlay()
@export var show_navigation := false:
	set(value):
		show_navigation = value
		_update_overlay()
@export var show_chunk_bounds := false:
	set(value):
		show_chunk_bounds = value
		_update_overlay()

@export_group("Diagnostics")
@export_multiline var preview_status := "Preview has not been validated."

var _generated_root: Node2D
var _overlay: MapBlueprintPreviewOverlay
var _last_definition: MapDefinition
var _diagnostic_errors: Array[String] = []
var _diagnostic_warnings: Array[String] = []
var _rebuild_queued := false


func _ready() -> void:
	if Engine.is_editor_hint():
		_request_rebuild()
	else:
		# A preview component may intentionally remain in a runtime shell, but its
		# derived editor children and processing must never become gameplay state.
		clear_preview()
		process_mode = Node.PROCESS_MODE_DISABLED


func _exit_tree() -> void:
	_rebuild_queued = false


func _validate_property(property: Dictionary) -> void:
	var property_name := StringName(property.get("name", ""))
	if property_name in [
		&"rebuild_preview_action",
		&"validate_action",
		&"show_stable_ids",
		&"show_anchors",
		&"show_navigation",
		&"show_chunk_bounds",
	]:
		# Controls are editor session state, not authored map data. Removing
		# STORAGE prevents toggling an overlay from changing the host .tscn.
		property["usage"] = PROPERTY_USAGE_EDITOR
	elif property_name == &"preview_status":
		property["usage"] = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if blueprint_factory == null:
		warnings.append("Assign a MapBlueprint factory script with static create().")
	for compiler_error in _diagnostic_errors:
		warnings.append("MapBlueprint compiler: %s" % compiler_error)
	for compiler_warning in _diagnostic_warnings:
		warnings.append("MapBlueprint warning: %s" % compiler_warning)
	return warnings


## Recompiles and replaces the disposable visual tree. Runtime callers are
## rejected unless they explicitly opt in, which is useful for contract tests or
## a deliberate in-game authoring tool while keeping normal exported scenes clean.
func rebuild_preview(allow_outside_editor: bool = false) -> bool:
	_rebuild_queued = false
	if not Engine.is_editor_hint() and not allow_outside_editor:
		clear_preview()
		return false

	clear_preview()
	var result := compile_blueprint()
	_apply_diagnostics(result, "Rebuild Preview")
	if not result.is_ok():
		return false

	_last_definition = result.definition
	_generated_root = Node2D.new()
	_generated_root.name = GENERATED_ROOT_NAME
	_generated_root.add_to_group(PREVIEW_GROUP)
	_generated_root.set_meta("preview_only", true)
	_generated_root.set_meta("map_id", _last_definition.map_id)
	_generated_root.set_meta("fingerprint", _last_definition.fingerprint)
	add_child(_generated_root, false, Node.INTERNAL_MODE_FRONT)

	var visuals := Node2D.new()
	visuals.name = "Visuals"
	visuals.y_sort_enabled = true
	_generated_root.add_child(visuals)
	var grid := MapBuilder.build(_last_definition)
	MapAssembler.assemble(visuals, _last_definition, grid, visuals)
	_disable_preview_physics(_generated_root)

	_overlay = MapBlueprintPreviewOverlay.new()
	_overlay.name = "Overlays"
	_generated_root.add_child(_overlay)
	_overlay.configure(_last_definition, grid)
	_update_overlay()
	preview_status = _success_status("Preview rebuilt", _last_definition)
	return true


func validate() -> bool:
	var result := compile_blueprint()
	_apply_diagnostics(result, "Validate")
	if result.is_ok():
		preview_status = _success_status("Validation passed", result.definition)
	return result.is_ok()


## Kept public so editor/runtime-separation tests and future editor plugins can
## verify that this component uses the production compiler rather than a preview
## approximation.
func compile_blueprint() -> MapBlueprintCompileResult:
	if blueprint_factory == null:
		return _failed_result("blueprint_factory is required")
	if not blueprint_factory.has_method("create"):
		return _failed_result("%s must define static func create() -> MapBlueprint" % blueprint_factory.resource_path)

	var value: Variant = blueprint_factory.call("create")
	if not value is MapBlueprint:
		return _failed_result("%s.create() must return MapBlueprint" % blueprint_factory.resource_path)
	return MapBlueprintCompiler.compile_with_diagnostics(value as MapBlueprint)


func clear_preview() -> void:
	_last_definition = null
	_overlay = null
	var existing := get_node_or_null(GENERATED_ROOT_NAME)
	if existing != null:
		remove_child(existing)
		existing.free()
	_generated_root = null


func preview_root() -> Node2D:
	return _generated_root


func _request_rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("rebuild_preview")


func _update_overlay() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	_overlay.show_stable_ids = show_stable_ids
	_overlay.show_anchors = show_anchors
	_overlay.show_navigation = show_navigation
	_overlay.show_chunk_bounds = show_chunk_bounds
	_overlay.queue_redraw()


func _apply_diagnostics(result: MapBlueprintCompileResult, action: String) -> void:
	_diagnostic_errors.clear()
	_diagnostic_warnings.clear()
	for diagnostic in result.diagnostics:
		if diagnostic.is_error():
			_diagnostic_errors.append(diagnostic.format())
		else:
			_diagnostic_warnings.append(diagnostic.format())
	update_configuration_warnings()
	if result.diagnostics.is_empty():
		return

	var source := blueprint_factory.resource_path if blueprint_factory != null else "<unassigned>"
	var lines: PackedStringArray = ["%s diagnostics for %s:" % [action, source]]
	for diagnostic in result.diagnostics:
		lines.append("- %s" % diagnostic.format())
		if diagnostic.is_error():
			push_error("MapBlueprint preview [%s]: %s" % [source, diagnostic.format()])
		else:
			push_warning("MapBlueprint preview [%s]: %s" % [source, diagnostic.format()])
	if result.has_errors():
		lines.append("Fix blueprint errors, then use Validate or Rebuild Preview.")
	preview_status = "\n".join(lines)


func _failed_result(message: String) -> MapBlueprintCompileResult:
	var result := MapBlueprintCompileResult.new()
	result.errors.append(message)
	result.import_legacy_errors()
	return result


func _success_status(prefix: String, definition: MapDefinition) -> String:
	var warning_suffix := "\nWarnings: %d (see configuration warnings)" % _diagnostic_warnings.size() if not _diagnostic_warnings.is_empty() else ""
	return "%s: %s\nFingerprint: %s\nTerrain zones: %d | Buildings: %d | Props: %d | Landmarks: %d | Anchors: %d%s" % [
		prefix,
		definition.map_id,
		definition.fingerprint,
		definition.zones.size(),
		definition.buildings.size(),
		definition.props.size(),
		definition.view_landmarks.size(),
		definition.interaction_anchors.size(),
		warning_suffix,
	]


func _disable_preview_physics(node: Node) -> void:
	if node is CollisionObject2D:
		(node as CollisionObject2D).collision_layer = 0
		(node as CollisionObject2D).collision_mask = 0
	if node is CollisionShape2D:
		(node as CollisionShape2D).disabled = true
	for child in node.get_children(true):
		_disable_preview_physics(child)
