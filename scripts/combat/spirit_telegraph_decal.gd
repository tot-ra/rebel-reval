class_name SpiritTelegraphDecal
extends MeshInstance3D
## In-world telegraph of an incoming spirit blow (ADR 0038, SA3D-2): a flat arc or circle on
## the arena floor where the blow will land, replacing the 2D telegraph arc as the cue to move.
## A mesh, not a Decal node: the GL Compatibility renderer does not draw Decals. It fills in
## as the telegraph runs. Presentation only; the zone itself lives in SpiritArenaMotion.

const LIFT := 0.03
const SEGMENTS := 40
const COLOR := Color(0.95, 0.30, 0.22)
const ALPHA_START := 0.18
const ALPHA_END := 0.6

var _material := StandardMaterial3D.new()


func _init() -> void:
	name = "SpiritTelegraphDecal"
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(COLOR, ALPHA_START)


## Draw `zone` (SpiritArenaMotion.lock_zone) in the parent arena's local space.
func show_zone(zone: Dictionary, arena_origin: Vector3) -> void:
	if zone.is_empty():
		hide_zone()
		return
	var origin := (zone["origin"] as Vector3) - arena_origin
	var points := PackedVector3Array()
	if zone["shape"] == SpiritArenaMotion.SHAPE_ARC:
		var direction := zone["direction"] as Vector3
		var half := float(zone["half_angle"])
		var reach := float(zone["reach"])
		points.append(Vector3.ZERO)
		for i in SEGMENTS + 1:
			var angle := lerpf(-half, half, float(i) / SEGMENTS)
			points.append(direction.rotated(Vector3.UP, angle) * reach)
	else:
		var radius := float(zone["radius"])
		points.append(Vector3.ZERO)
		for i in SEGMENTS + 1:
			points.append(Vector3.FORWARD.rotated(Vector3.UP, TAU * float(i) / SEGMENTS) * radius)
	var fan := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var indices := PackedInt32Array()
	for i in range(1, points.size() - 1):
		indices.append_array([0, i, i + 1])
	arrays[Mesh.ARRAY_INDEX] = indices
	fan.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	fan.surface_set_material(0, _material)
	mesh = fan
	position = Vector3(origin.x, LIFT, origin.z)
	set_progress(0.0)
	visible = true


## 0 at the start of the telegraph, 1 at impact.
func set_progress(progress: float) -> void:
	_material.albedo_color = Color(COLOR, lerpf(ALPHA_START, ALPHA_END, clampf(progress, 0.0, 1.0)))


func hide_zone() -> void:
	visible = false
	mesh = null
