class_name NamedNpcMarker
extends Node3D

## Overhead "!" over a named NPC (docs/SYSTEMS/NAMED_NPCS.md, task R-1564).
## View only: a billboard font glyph child of the NPC's mirrored rig, driven by
## CityNamedNpcs. The glyph SHAPE carries the meaning ("!" available, "?" quest
## ready); the faction tint is decoration, so it stays readable without colour.

enum State { NONE, AVAILABLE, QUEST_READY, SPOKEN }

## Fully opaque up to FADE_START metres from the camera, gone at FADE_END.
const FADE_START := 32.0
const FADE_END := 40.0
## Far markers are scaled up so they keep a similar on-screen size in the
## isometric view; capped so a distant one never becomes a banner.
const REFERENCE_DISTANCE := 12.0
const MAX_SCALE := 2.0
const BOB_AMPLITUDE := 0.05
const BOB_SPEED := 2.2
const HEAD_PADDING := 0.45
const SPOKEN_ALPHA := 0.45
## Chip: 64 px at 0.0035 m = 0.22 m, hanging just below the glyph.
const CHIP_PIXEL_SIZE := 0.0035
const CHIP_OFFSET := -0.27
const DEFAULT_TINT := Color(1.0, 0.86, 0.35)
## Groups that mean "the player is talking or watching a scene": no markers then.
const SpiritSightScript := preload("res://scripts/combat/spirit_sight.gd")
const SUPPRESS_GROUPS: Array[StringName] = [
	&"demo_dialogue_active", &"dialogue_active", &"cutscene_active",
	SpiritSightScript.DUEL_OPEN_GROUP,
]

var state: State = State.NONE
var faction := ""
var _glyph: Label3D
var _chip: Sprite3D
var _phase := 0.0
var _base_height := 2.0


## Registry `marker` value -> state. Unknown strings are NONE.
static func state_from_registry(value: Variant) -> State:
	return State.AVAILABLE if value is String and value == "available" else State.NONE


static func glyph_for(marker_state: State) -> String:
	match marker_state:
		State.AVAILABLE, State.SPOKEN:
			return "!"
		State.QUEST_READY:
			return "?"
	return ""


static func tint_for(npc_faction: Variant) -> Color:
	return FactionIdentity.marker_tint(npc_faction, DEFAULT_TINT)


## 1 up to FADE_START, 0 from FADE_END, linear between.
static func distance_alpha(distance: float) -> float:
	return clampf((FADE_END - distance) / (FADE_END - FADE_START), 0.0, 1.0)


static func distance_scale(distance: float) -> float:
	return clampf(distance / REFERENCE_DISTANCE, 1.0, MAX_SCALE)


## Pure visibility rule: setting on, a marker state with a glyph, not suppressed.
static func wants_visible(
	marker_state: State, setting_on: bool, suppressed: bool, distance: float
) -> bool:
	return (
		setting_on and not suppressed and glyph_for(marker_state) != ""
		and distance_alpha(distance) > 0.0
	)


static func setting_enabled() -> bool:
	var settings: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("UserSettings")
	return settings == null or settings.gameplay.show_npc_markers


static func suppressed_in(tree: SceneTree) -> bool:
	for group in SUPPRESS_GROUPS:
		if not tree.get_nodes_in_group(group).is_empty():
			return true
	# Spirit sight swaps the world for the soul-light layer (ADR 0041).
	var session: Node = tree.root.get_node_or_null("SessionState")
	return session != null and session.state.spirit_sight


func setup(npc: Dictionary, height_scale: float) -> void:
	state = state_from_registry(npc.get("marker", "none"))
	var row_faction: Variant = npc.get("faction")
	faction = String(row_faction) if row_faction != null else ""
	_base_height = (
		CharacterScale.VISIBLE_HEIGHT_WORLD + HEAD_PADDING
	) * height_scale
	position = Vector3(0.0, _base_height, 0.0)
	_phase = float(absi(hash(String(npc["id"]))) % 628) / 100.0
	_glyph = Label3D.new()
	_glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_glyph.no_depth_test = true  # occlusion-safe: houses never swallow the cue
	_glyph.fixed_size = false
	_glyph.pixel_size = 0.0032
	_glyph.font_size = 80
	_glyph.outline_size = 16
	_glyph.outline_modulate = Color(0.08, 0.05, 0.03, 0.95)
	_glyph.render_priority = 5
	add_child(_glyph)
	_add_chip()
	apply_state(state)


## Faction chip (emblem on a plate, R-1565) under the glyph: the shape that tells
## factions apart without colour. Absent for clergy, no-seat NPCs and the Black
## Cloaks (hidden emblem).
func _add_chip() -> void:
	if not FactionIdentity.is_public(faction):
		return
	_chip = Sprite3D.new()
	_chip.name = "FactionChip"
	_chip.texture = FactionIdentity.chip_texture(faction)
	_chip.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_chip.no_depth_test = true
	_chip.shaded = false
	_chip.pixel_size = CHIP_PIXEL_SIZE
	_chip.position = Vector3(0.0, CHIP_OFFSET, 0.0)
	_chip.render_priority = 5
	add_child(_chip)


func apply_state(new_state: State) -> void:
	state = new_state
	if _glyph == null:
		return
	_glyph.text = glyph_for(state)
	var tint := tint_for(faction)
	tint.a = SPOKEN_ALPHA if state == State.SPOKEN else 1.0
	_glyph.modulate = tint


## Called every frame by CityNamedNpcs with the camera distance.
func update_presence(distance: float, suppressed: bool, delta: float) -> void:
	var show := wants_visible(state, setting_enabled(), suppressed, distance)
	visible = show
	if not show or _glyph == null:
		return
	_phase += delta * BOB_SPEED
	position.y = _base_height + sin(_phase) * BOB_AMPLITUDE
	scale = Vector3.ONE * distance_scale(distance)
	var shade := _glyph.modulate
	shade.a = distance_alpha(distance) * (SPOKEN_ALPHA if state == State.SPOKEN else 1.0)
	_glyph.modulate = shade
	if _chip != null:
		_chip.modulate.a = shade.a
