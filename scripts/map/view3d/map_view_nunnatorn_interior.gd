class_name MapViewNunnatornInterior
extends Node3D

## R-628: presentation kit for the reconstructed early-14th-century, open-backed
## Nunnatorn interior. It deliberately uses abstract light blocks rather than
## historical claims: the floor route stays legible in both day and night.

const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const NunnatornAudioController := preload("res://scripts/audio/nunnatorn_audio_controller.gd")
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")

const MAP_ID := &"nunnatorn_interior"
const DAY_FILL_COLOR := Color8(196, 210, 232)
const NIGHT_FILL_COLOR := Color8(96, 122, 184)
const DAY_FILL_ENERGY := 0.34
const NIGHT_FILL_ENERGY := 0.16
const FILL_RANGE := 8.0
const FLOOR_LIGHT_COLOR := Color8(255, 184, 92)
const FLOOR_LIGHT_ENERGY := 0.70
const FLOOR_LIGHT_RANGE := 3.0
const FLOOR_LIGHT_HEIGHT := 1.15
const OPEN_EDGE_COLOR := Color8(90, 164, 196)
const OPEN_EDGE_ALPHA := 0.22
const OPEN_EDGE_HEIGHT := 0.035

var _definition: MapDefinition
var _fill_light: OmniLight3D
var _floor_lights: Array[OmniLight3D] = []
var _audio: NunnatornAudioController
var _cycle_progress := 0.5
var _audio_enabled := true


static func install(parent: Node3D, definition: MapDefinition) -> MapViewNunnatornInterior:
	var kit := MapViewNunnatornInterior.new()
	kit.name = "NunnatornPresentation"
	kit.configure(definition)
	parent.add_child(kit)
	return kit


func configure(definition: MapDefinition) -> void:
	_definition = definition
	set_meta(&"presentation_id", &"nunnatorn_readability")
	set_meta(&"open_backed", true)
	set_meta(&"historical_form", &"early-14th-century")
	_build_lighting()
	_build_open_edge_marker()
	_audio = NunnatornAudioController.new()
	_audio.name = "NunnatornAudio"
	add_child(_audio)
	_apply_cycle_progress(_cycle_progress)


func apply_cycle_progress(progress: float, rain_intensity: float = 0.0) -> void:
	_cycle_progress = wrapf(progress, 0.0, 1.0)
	_apply_cycle_progress(_cycle_progress)
	if _audio != null:
		_audio.sync(rain_intensity, 0.0)


func sync_audio(rain_intensity: float, delta: float) -> void:
	if _audio != null:
		_audio.sync(rain_intensity, delta)


func set_audio_enabled(enabled: bool) -> void:
	_audio_enabled = enabled
	if _audio != null:
		_audio.set_audio_enabled(enabled)


func audio_active() -> bool:
	return _audio != null and _audio.audio_active()


func floor_light_count() -> int:
	return _floor_lights.size()


func open_backed_marker() -> MeshInstance3D:
	return get_node_or_null("OpenBackedMarker") as MeshInstance3D


func _build_lighting() -> void:
	_fill_light = OmniLight3D.new()
	_fill_light.name = "InteriorReadabilityFill"
	_fill_light.position = Vector3(0.5, 2.0, 0.5)
	_fill_light.omni_range = FILL_RANGE
	_fill_light.shadow_enabled = false
	add_child(_fill_light)
	for anchor_id in [&"nunnatorn_floor_ground", &"nunnatorn_floor_watch", &"nunnatorn_floor_roof"]:
		var light := OmniLight3D.new()
		light.name = "FloorLight_%s" % String(anchor_id)
		light.position = _anchor_world(anchor_id, FLOOR_LIGHT_HEIGHT)
		light.light_color = FLOOR_LIGHT_COLOR
		light.omni_range = FLOOR_LIGHT_RANGE
		light.shadow_enabled = false
		add_child(light)
		_floor_lights.append(light)


func _build_open_edge_marker() -> void:
	# WHY: a thin cyan edge is a readability aid for the reconstructed city-facing
	# gap; it is not a wall and cannot seal the open-backed route.
	var marker := MeshInstance3D.new()
	marker.name = "OpenBackedMarker"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(4.0, OPEN_EDGE_HEIGHT, 0.04)
	marker.mesh = mesh
	marker.position = _anchor_world(&"nunnatorn_interior_entry", 0.015)
	marker.position.z += 0.25
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(OPEN_EDGE_COLOR, OPEN_EDGE_ALPHA)
	material.emission_enabled = true
	material.emission = OPEN_EDGE_COLOR
	material.emission_energy_multiplier = 0.35
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = material
	add_child(marker)


func _apply_cycle_progress(progress: float) -> void:
	if _fill_light == null:
		return
	var day_blend := DayNightCycle.day_blend(progress)
	_fill_light.light_color = NIGHT_FILL_COLOR.lerp(DAY_FILL_COLOR, day_blend)
	_fill_light.light_energy = lerpf(NIGHT_FILL_ENERGY, DAY_FILL_ENERGY, day_blend)
	for light in _floor_lights:
		light.light_energy = FLOOR_LIGHT_ENERGY * lerpf(1.0, 0.55, day_blend)


func _anchor_world(anchor_id: StringName, height: float) -> Vector3:
	if _definition == null:
		return Vector3.ZERO
	var anchor := MapVerification.anchor_position(_definition, anchor_id)
	return MapViewBridge.logic_to_world(anchor, _definition.cell_size, height)
