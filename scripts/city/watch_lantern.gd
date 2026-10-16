class_name WatchLantern
extends Node3D

## Horn lantern carried by the night watch (docs/SYSTEMS/NIGHT_LIGHTING.md). In 1343
## Reval nobody lit the streets: after the night bell the watch walked with a closed
## lantern, horn panes round a tallow candle, and anyone else abroad was expected to
## carry one too. Built from primitives until an authored model replaces it
## (obj.hanging_lantern_iron in docs/SYSTEMS/OBJECT_CATALOG.md). The origin is the
## top of the bail; the body hangs below along -Y. Lit only while it is dark; the
## city calls apply_cycle_progress on the `city_cycle_lights` group every frame.

const LIGHT_COLOR := Color8(255, 168, 86)
const LIGHT_ENERGY := 1.6
const LIGHT_RANGE := 7.5
## Same threshold as the household lights (CityInteriors.DARK_BELOW).
const DARK_BELOW := 0.35

var lit := false
var _light: OmniLight3D
var _horn: StandardMaterial3D
var _phase := 0.0


func _init() -> void:
	name = "WatchLantern"
	add_to_group(&"city_cycle_lights")
	_build()
	_set_lit(false)


func _build() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.1, 0.095, 0.085)
	iron.metallic = 0.6
	iron.roughness = 0.75
	_horn = StandardMaterial3D.new()
	# Scraped cow horn: amber, cloudy, lets light through but no view.
	_horn.albedo_color = Color(0.62, 0.44, 0.22, 0.82)
	_horn.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_horn.roughness = 0.55
	_horn.emission_enabled = true
	_horn.emission = Color(1.0, 0.6, 0.26)
	_part(_torus(0.022, 0.006), iron, Vector3(0, -0.018, 0), Vector3(PI * 0.5, 0, 0))
	_part(_cone(0.012, 0.07, 0.05), iron, Vector3(0, -0.065, 0))
	_part(_box(Vector3(0.11, 0.15, 0.11)), _horn, Vector3(0, -0.165, 0))
	for x: float in [-0.055, 0.055]:
		for z: float in [-0.055, 0.055]:
			_part(_box(Vector3(0.012, 0.16, 0.012)), iron, Vector3(x, -0.165, z))
	_part(_box(Vector3(0.13, 0.014, 0.13)), iron, Vector3(0, -0.247, 0))
	_light = OmniLight3D.new()
	_light.name = "Omni"
	_light.position = Vector3(0, -0.165, 0)
	_light.light_color = LIGHT_COLOR
	_light.omni_range = LIGHT_RANGE
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = false
	add_child(_light)


func _part(mesh: Mesh, material: Material, at: Vector3, rot := Vector3.ZERO) -> void:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material
	inst.position = at
	inst.rotation = rot
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _cone(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return mesh


static func _torus(outer: float, thickness: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.outer_radius = outer
	mesh.inner_radius = outer - thickness
	mesh.rings = 12
	mesh.ring_segments = 6
	return mesh


func apply_cycle_progress(progress: float) -> void:
	_set_lit(DayNightCycle.day_blend(progress) < DARK_BELOW)


func _set_lit(value: bool) -> void:
	lit = value
	_light.visible = value
	_horn.emission_energy_multiplier = 2.2 if value else 0.0
	set_process(value)


func _process(delta: float) -> void:
	# A candle behind horn: a slow tremble, not a torch's leap.
	_phase += delta
	var tremble := 0.93 + 0.05 * sin(_phase * 5.3) + 0.02 * sin(_phase * 11.9)
	_light.light_energy = LIGHT_ENERGY * tremble
