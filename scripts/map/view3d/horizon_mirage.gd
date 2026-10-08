class_name HorizonMirage
extends Node3D

## Heat shimmer on the far horizon in hot, calm, clear weather: a short open cylinder
## around the camera drawn by horizon_mirage.gdshader. Perspective cameras only; the
## orthographic overview has no horizon. Distance haze for the same cameras lives in
## MapViewLighting.apply_ground_mist (horizon_haze); this adds the visible element.
## Presentation only: nothing is persisted.

const MIRAGE_SHADER := preload("res://scripts/map/view3d/horizon_mirage.gdshader")
const Lighting := preload("res://scripts/map/view3d/map_view_lighting.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const SEGMENTS := 72
## Ring distance: well inside the camera far plane, beyond any street-level geometry.
const MAX_RADIUS := 420.0
const RADIUS_OF_FAR := 0.6
const BAND_HEIGHT := 30.0
const STRENGTH_SKIP := 0.02
const GROUP := &"horizon_mirage"

var strength := 0.0
var _camera: Camera3D
var _material: ShaderMaterial
var _ring: MeshInstance3D
var _radius := MAX_RADIUS


static func should_create(indoor: bool) -> bool:
	return not indoor


## Shimmer strength 0..1 for a presentation; the band is pale sky-hued light.
static func strength_for(presentation: SkyWeather.WeatherPresentation) -> float:
	return Lighting.heat_amount(presentation) * clampf(presentation.fog_quality, 0.0, 1.0)


func configure(camera: Camera3D) -> void:
	name = "HorizonMirage"
	_camera = camera
	add_to_group(GROUP)
	_radius = minf(camera.far * RADIUS_OF_FAR, MAX_RADIUS)
	_material = ShaderMaterial.new()
	_material.shader = MIRAGE_SHADER
	_material.set_shader_parameter(&"band_height", BAND_HEIGHT)
	_ring = MeshInstance3D.new()
	_ring.name = "MirageRing"
	_ring.mesh = _build_ring(_radius, BAND_HEIGHT)
	_ring.material_override = _material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.ignore_occlusion_culling = true
	_ring.extra_cull_margin = 16384.0
	_ring.top_level = true
	_ring.visible = false
	add_child(_ring)


func _exit_tree() -> void:
	remove_from_group(GROUP)


## Open cylinder, UV.y 0 at the foot of the band and 1 at the top (the shader's profile).
static func _build_ring(radius: float, height: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in SEGMENTS + 1:
		var angle := TAU * float(i) / float(SEGMENTS)
		var x := sin(angle) * radius
		var z := cos(angle) * radius
		vertices.append(Vector3(x, 0.0, z))
		uvs.append(Vector2(float(i) / float(SEGMENTS), 0.0))
		vertices.append(Vector3(x, height, z))
		uvs.append(Vector2(float(i) / float(SEGMENTS), 1.0))
	for i in SEGMENTS:
		var a := i * 2
		indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func update(presentation: SkyWeather.WeatherPresentation, enabled: bool = true) -> void:
	if _material == null or _camera == null or presentation == null:
		return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		camera = _camera
	# Hosted neighbours share one camera; only the first ring draws.
	var first: Node = null
	for layer in get_tree().get_nodes_in_group(GROUP):
		if layer.get_viewport() == get_viewport():
			first = layer
			break
	var perspective := camera.projection != Camera3D.PROJECTION_ORTHOGONAL
	strength = strength_for(presentation) if enabled and perspective and first == self else 0.0
	_ring.visible = strength > STRENGTH_SKIP
	if not _ring.visible:
		return
	# The ring follows the camera in XZ and sits on sea level, where the horizon line is.
	_ring.global_position = Vector3(camera.global_position.x, 0.0, camera.global_position.z)
	var tint := Lighting.FOG_MORNING_COLOR
	if presentation.atmosphere_available:
		tint = Lighting.physical_hue(presentation.horizon_display_color, tint)
	_material.set_shader_parameter(&"band_color", tint.lerp(Color.WHITE, 0.35))
	_material.set_shader_parameter(&"strength", strength)
