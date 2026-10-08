class_name SpiritWordBolt
extends Node3D
## A spoken word thrown across the 3D arena (ADR 0038, SA3D-3): a glowing core and a short trail
## in the element colour (SpiritSpellCard.ELEMENT_COLORS), built from the soft sprite and particle
## helpers of MapViewMagicVfxParts (no texture assets, P0-040). Presentation only: the host moves
## it each frame from the rules (SpiritWordSpells bolts, or the opponent's telegraph progress).

const VfxParts := preload("res://scripts/map/view3d/map_view_magic_vfx_parts.gd")
const CORE_SIZE := 0.55
const HEIGHT := 1.2

var element: StringName = &""
var color := SpiritSpellCard.NEUTRAL_COLOR
var from := Vector3.ZERO
var to := Vector3.ZERO


func setup(word_element: StringName, start: Vector3, target: Vector3) -> SpiritWordBolt:
	element = word_element
	color = SpiritSpellCard.ELEMENT_COLORS.get(String(word_element), SpiritSpellCard.NEUTRAL_COLOR)
	from = start + Vector3.UP * HEIGHT
	to = target + Vector3.UP * HEIGHT
	name = "WordBolt_%s" % String(word_element)
	var core := MeshInstance3D.new()
	core.name = "Core"
	var quad := QuadMesh.new()
	quad.size = Vector2(CORE_SIZE, CORE_SIZE)
	core.mesh = quad
	# The shared glow material billboards as particles; a lone mesh needs plain billboarding.
	var material := VfxParts.glow_material().duplicate() as StandardMaterial3D
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.proximity_fade_enabled = false
	material.albedo_color = color.lightened(0.2)
	core.material_override = material
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var ramp := VfxParts.ramp([0.0, 1.0], [color, Color(color, 0.0)])
	var trail := VfxParts.particles(
		"Trail",
		24,
		0.35,
		VfxParts.burst_process(Vector2(0.05, 0.3), 0.0, Vector2(0.5, 1.0), ramp),
		0.32,
		VfxParts.glow_material(),
		true
	)
	add_child(trail)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.4
	light.omni_range = 2.5
	add_child(light)
	return self


## Place the bolt `progress` (0..1) of the way along its path.
func set_progress(progress: float) -> void:
	var at := from.lerp(to, clampf(progress, 0.0, 1.0))
	if is_inside_tree():
		global_position = at
	else:
		position = at
