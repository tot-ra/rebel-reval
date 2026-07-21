class_name InteractableWorldIndicator
extends Node3D

## View-only talk marker for interactables in the 3D map presentation layer.
## Shows a bobbing prompt glyph above the logic actor and a floor ring when focused.

const IDLE_GLYPH_COLOR := Color(0.95, 0.82, 0.35, 0.78)
const FOCUSED_GLYPH_COLOR := Color(1.0, 0.93, 0.5, 1.0)
const RING_COLOR := Color(0.396, 0.694, 0.769, 0.62)

const GLYPH_BY_KIND: Dictionary = {
	InteractionKinds.TALK: "?",
	InteractionKinds.PICKUP: "+",
	InteractionKinds.USE: "!",
}

## Fallback when the host has no height hook and no mirrored 3D rig is available.
## Padding matches SharedCharacterRig so the bottom-aligned glyph clears a 2.0 body.
const DEFAULT_GLYPH_HEIGHT := (
	CharacterScale.VISIBLE_HEIGHT_WORLD + SharedCharacterRig.PROMPT_GLYPH_PADDING
)
const GLYPH_BOB_AMPLITUDE := 0.05
## Ground pickups stay near the item instead of floating at adult head height.
const PICKUP_GLYPH_HEIGHT := 0.55

var _interactable: Interactable
var _cell_size := MapTypes.DEFAULT_CELL_SIZE
var _glyph: Label3D
var _ring: MeshInstance3D
var _bob_phase := 0.0
var _focused := false
var _enabled := true
var _view_runtime: Node


func attach(interactable: Interactable, cell_size: int, view_runtime: Node = null) -> void:
	_interactable = interactable
	_cell_size = cell_size
	_view_runtime = view_runtime
	_build_nodes()
	_apply_glyph_for_kind(interactable.get_interaction_kind())
	set_enabled(interactable.is_enabled())
	set_focused(interactable.is_focused())
	interactable.focused.connect(_on_focused)
	interactable.unfocused.connect(_on_unfocused)


func set_enabled(value: bool) -> void:
	_enabled = value
	visible = value


func set_focused(value: bool) -> void:
	_focused = value
	_apply_visual_state()


func _process(delta: float) -> void:
	if _interactable == null or not is_instance_valid(_interactable):
		return
	MapViewBridge.sync_actor(self, _interactable.global_position, _cell_size)
	if _glyph == null:
		return
	_bob_phase += delta * 3.2
	var bob := sin(_bob_phase) * GLYPH_BOB_AMPLITUDE
	_glyph.position.y = _resolve_glyph_height() + bob


func _build_nodes() -> void:
	_glyph = Label3D.new()
	_glyph.name = "PromptGlyph"
	_glyph.text = "?"
	_glyph.font_size = 56
	_glyph.pixel_size = 0.009
	# WHY: center alignment buried half the tall "?" inside the head; bottom
	# alignment keeps the whole glyph above the resolved crown height.
	_glyph.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph.position = Vector3(0.0, DEFAULT_GLYPH_HEIGHT, 0.0)
	_glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_glyph.no_depth_test = true
	_glyph.outline_size = 8
	_glyph.outline_modulate = Color(0.05, 0.06, 0.08, 0.85)
	_glyph.modulate = IDLE_GLYPH_COLOR
	add_child(_glyph)

	_ring = MeshInstance3D.new()
	_ring.name = "FocusRing"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.34
	mesh.bottom_radius = 0.34
	mesh.height = 0.04
	mesh.radial_segments = 24
	_ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = RING_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = material
	_ring.position = Vector3(0.0, 0.05, 0.0)
	_ring.visible = false
	add_child(_ring)


func _resolve_glyph_height() -> float:
	if _interactable == null or not is_instance_valid(_interactable):
		return DEFAULT_GLYPH_HEIGHT
	if _interactable.get_interaction_kind() == InteractionKinds.PICKUP:
		return PICKUP_GLYPH_HEIGHT
	var host := _interactable.get_parent()
	if host != null and host.has_method("view_glyph_height"):
		return host.call("view_glyph_height") as float
	var rig := _resolve_actor_rig(host)
	if rig != null and rig.has_method("view_glyph_height"):
		return rig.call("view_glyph_height") as float
	return DEFAULT_GLYPH_HEIGHT


func _resolve_actor_rig(host: Node) -> Node:
	if host == null or not (host is Node2D):
		return null
	var runtime := _view_runtime
	if runtime == null:
		runtime = get_parent()
	if runtime != null and runtime.has_method("get_actor_rig"):
		return runtime.call("get_actor_rig", host) as Node
	return null


func _apply_glyph_for_kind(kind: StringName) -> void:
	if _glyph == null:
		return
	_glyph.text = String(GLYPH_BY_KIND.get(kind, "?"))


func _apply_visual_state() -> void:
	if _glyph == null or _ring == null:
		return
	_glyph.modulate = FOCUSED_GLYPH_COLOR if _focused else IDLE_GLYPH_COLOR
	_glyph.font_size = 64 if _focused else 56
	_ring.visible = _focused and _enabled


func _on_focused() -> void:
	set_focused(true)


func _on_unfocused() -> void:
	set_focused(false)
