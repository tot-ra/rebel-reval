class_name InteractableViewBinder
extends Node

## Mirrors interactable focus state onto 3D prompt markers in MapViewRuntime.

var _view_runtime: MapViewRuntime
var _cell_size := MapTypes.DEFAULT_CELL_SIZE
var _indicators: Dictionary = {}


func setup(view_runtime: MapViewRuntime, definition: MapDefinition) -> void:
	_view_runtime = view_runtime
	if definition != null:
		_cell_size = definition.cell_size


func bind(interactable: Interactable) -> InteractableWorldIndicator:
	if interactable == null or _view_runtime == null:
		return null
	if _indicators.has(interactable):
		return _indicators[interactable]

	var indicator := InteractableWorldIndicator.new()
	indicator.name = "Indicator_%s" % interactable.name
	_view_runtime.add_child(indicator)
	indicator.attach(interactable, _cell_size)
	_indicators[interactable] = indicator
	_hide_flat_marker(interactable)
	return indicator


func unbind(interactable: Interactable) -> void:
	if interactable == null:
		return
	var indicator: InteractableWorldIndicator = _indicators.get(interactable)
	if indicator != null and is_instance_valid(indicator):
		indicator.queue_free()
	_indicators.erase(interactable)


func _hide_flat_marker(interactable: Interactable) -> void:
	interactable.suppress_flat_markers(true)
