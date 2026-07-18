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

var _interactable: Interactable
var _cell_size := MapTypes.DEFAULT_CELL_SIZE
var _glyph: Label3D
var _ring: MeshInstance3D
var _bob_phase := 0.0
var _focused := false
var _enabled := true


func attach(interactable: Interactable, cell_size: int) -> void:
	_interactable = interactable
	_cell_size = cell_size
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
	var bob := sin(_bob_phase) * 0.05
	_glyph.position.y = 2.05 + bob


func _build_nodes() -> void:
	_glyph = Label3D.new()
	_glyph.name = "PromptGlyph"
	_glyph.text = "?"
	_glyph.font_size = 56
	_glyph.pixel_size = 0.009
	_glyph.position = Vector3(0.0, 2.05, 0.0)
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
