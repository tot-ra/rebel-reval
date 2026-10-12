extends Node
## Cinematic framing for a scripted conversation held in the live world (R-1877): no separate
## scene, the speakers stand where they are and a second camera in the same World3D frames
## them at eye level. Gameplay HUD layers and overhead bars are hidden for the shot (all but the
## `keep` subtree, which holds the dialogue box). While it is current the shot adds a harder,
## less saturated grade, a far-plane depth blur and a vignette with thin letterbox bars;
## `release()` hands the view back to the gameplay camera unchanged. Used by SmithyOpening
## for Kalev's arrival after the porter duel.

const LENS_FOV := 36.0
## Camera eye and aim heights above the subjects' floor (metres).
const EYE_HEIGHT := 1.5
const LOOK_HEIGHT := 1.4
## Room around the outermost subject inside the frame (metres, each side).
const FRAME_MARGIN := 1.0
## Widest lens the shot may open to when the room keeps the camera closer than the fit.
const MAX_FOV := 60.0
const MIN_DISTANCE := 2.4
const MAX_DISTANCE := 4.5
## The camera turns this far (radians) off the square-on side view: a three-quarter angle
## reads deeper and less like a stage set.
const ANGLE := 0.2
## Slow push-in while the conversation runs (fraction of the distance, over DRIFT_SEC).
const DRIFT := 0.08
const DRIFT_SEC := 30.0
## Opens on black and fades up: the cut into the shot reads as an edit, not a camera snap.
const FADE_IN_SEC := 0.7
const CONTRAST := 1.12
const SATURATION := 0.88
const DOF_AMOUNT := 0.08
## Far blur starts this far behind the deepest subject.
const DOF_BEHIND := 0.8
const DOF_TRANSITION := 2.5
## Drawn under the dialogue box (DialogueUI is layer 45).
const OVERLAY_LAYER := 40
const OVERLAY_SHADER := """
shader_type canvas_item;
uniform float bars : hint_range(0.0, 0.2) = 0.07;
uniform float vignette : hint_range(0.0, 1.0) = 0.6;
uniform float black : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	float bar = step(UV.y, bars) + step(1.0 - bars, UV.y);
	vec2 d = (UV - 0.5) * vec2(1.25, 1.0);
	float vig = smoothstep(0.32, 0.8, length(d)) * vignette;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(max(max(bar, vig), black), 0.0, 1.0));
}
"""

var camera: Camera3D

var _previous: Camera3D
var _overlay: CanvasLayer
var _material: ShaderMaterial
var _tween: Tween
var _hidden: Array[Node] = []


## Frames `points` (subjects' feet, world space) from the side nearest `from_hint`, keeping the
## camera within `bounds_radius` of `bounds_center` (the room). Returns `transform` and the
## vertical `fov`: when the room holds the camera closer than the fit, the lens widens instead.
static func compute_shot(
	points: Array[Vector3], from_hint: Vector3, aspect: float,
	bounds_center: Vector3 = Vector3.ZERO, bounds_radius: float = 0.0
) -> Dictionary:
	var center := Vector3.ZERO
	for point in points:
		center += point
	center /= maxf(1.0, points.size())
	var axis := Vector3.RIGHT
	var widest := -1.0
	for i in points.size():
		for j in range(i + 1, points.size()):
			var span := Vector3(points[j].x - points[i].x, 0.0, points[j].z - points[i].z)
			if span.length() > widest:
				widest = span.length()
				axis = span
	axis = axis.normalized() if not axis.is_zero_approx() else Vector3.RIGHT
	var normal := Vector3(-axis.z, 0.0, axis.x)
	var hint := Vector3(from_hint.x - center.x, 0.0, from_hint.z - center.z)
	if normal.dot(hint) < 0.0:
		normal = -normal
	normal = normal.rotated(Vector3.UP, ANGLE)
	var half_width := FRAME_MARGIN
	for point in points:
		half_width = maxf(half_width, absf((point - center).dot(axis)) + FRAME_MARGIN)
	aspect = maxf(aspect, 0.1)
	var half_h := atan(tan(deg_to_rad(LENS_FOV) * 0.5) * aspect)
	var distance := clampf(half_width / tan(half_h), MIN_DISTANCE, MAX_DISTANCE)
	var eye := center + normal * distance
	if bounds_radius > 0.0:
		var flat := Vector3(eye.x - bounds_center.x, 0.0, eye.z - bounds_center.z)
		if flat.length() > bounds_radius:
			flat = flat.normalized() * bounds_radius
			eye = Vector3(bounds_center.x + flat.x, eye.y, bounds_center.z + flat.z)
	eye.y = center.y + EYE_HEIGHT
	var fov := LENS_FOV
	var held := Vector2(eye.x - center.x, eye.z - center.z).length()
	if held < distance - 0.01:
		var needed_h := atan(half_width / maxf(held, 0.1))
		fov = minf(MAX_FOV, rad_to_deg(2.0 * atan(tan(needed_h) / aspect)))
	var aim := Vector3(center.x, center.y + LOOK_HEIGHT, center.z)
	return {
		"transform": Transform3D(Basis.looking_at(aim - eye, Vector3.UP), eye),
		"fov": maxf(fov, LENS_FOV),
	}


## Cuts to the shot. `world` hosts the camera; the overlay fades up from black.
func frame(
	world: Node3D, points: Array[Vector3], bounds_center: Vector3, bounds_radius: float,
	keep: Node = null
) -> void:
	var viewport := world.get_viewport() if world.is_inside_tree() else null
	_previous = viewport.get_camera_3d() if viewport != null else null
	var size := viewport.get_visible_rect().size if viewport != null else Vector2(16, 9)
	var hint := (
		_previous.global_position if _previous != null
		else bounds_center + Vector3.BACK * MAX_DISTANCE
	)
	var framed := compute_shot(
		points, hint, size.x / maxf(size.y, 1.0), bounds_center, bounds_radius
	)
	var shot: Transform3D = framed["transform"]
	camera = Camera3D.new()
	camera.name = "ConversationCamera"
	camera.fov = framed["fov"]
	world.add_child(camera)
	camera.global_transform = shot
	var deepest := 0.0
	for point in points:
		deepest = maxf(deepest, shot.origin.distance_to(point))
	camera.attributes = _attributes(deepest + DOF_BEHIND)
	camera.environment = _environment(world)
	camera.current = true
	_hide_hud(world, keep)
	_mount_overlay()
	_tween = create_tween()
	_tween.tween_property(_material, ^"shader_parameter/black", 0.0, FADE_IN_SEC).from(1.0)
	var aim := shot.origin + -shot.basis.z * shot.origin.distance_to(_points_center(points))
	var pushed := shot.origin.lerp(aim, DRIFT)
	_tween.parallel().tween_property(camera, ^"global_position", pushed, DRIFT_SEC)


## Back to the gameplay camera, as it was.
func release() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if is_instance_valid(_previous) and _previous.is_inside_tree():
		_previous.current = true
	if is_instance_valid(camera):
		camera.queue_free()
	camera = null
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	for node in _hidden:
		if is_instance_valid(node):
			node.set(&"visible", true)
	_hidden.clear()


func _exit_tree() -> void:
	release()


## Keeps the gameplay camera's exposure; adds the far blur behind the speakers.
func _attributes(blur_from: float) -> CameraAttributesPractical:
	var source := _previous.attributes if _previous != null else null
	var attributes := (
		source.duplicate() as CameraAttributesPractical if source is CameraAttributesPractical
		else CameraAttributesPractical.new()
	)
	# Compatibility has no DOF and warns when blur is on; the city runs Mobile.
	var blur := (
		str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
		!= "gl_compatibility"
	)
	attributes.dof_blur_far_enabled = blur
	attributes.dof_blur_near_enabled = false
	attributes.dof_blur_amount = DOF_AMOUNT
	attributes.dof_blur_far_distance = blur_from
	attributes.dof_blur_far_transition = DOF_TRANSITION
	return attributes


## A snapshot of the live grade, a little harder and less saturated. The city's lighting keeps
## writing to the world environment; a conversation is short enough to hold the snapshot.
func _environment(world: Node3D) -> Environment:
	var source: Environment = null
	if _previous != null and _previous.environment != null:
		source = _previous.environment
	elif world.get_world_3d() != null:
		source = world.get_world_3d().environment
	if source == null:
		return null
	var graded := source.duplicate() as Environment
	if not graded.adjustment_enabled:
		graded.adjustment_enabled = true
		graded.adjustment_brightness = 1.0
		graded.adjustment_contrast = 1.0
		graded.adjustment_saturation = 1.0
	graded.adjustment_contrast *= CONTRAST
	graded.adjustment_saturation *= SATURATION
	return graded


## HUD layers (minimap, tools, vitals, location) and overhead bars would break the frame.
## Only what is visible now is hidden, and exactly that comes back on release.
func _hide_hud(world: Node3D, keep: Node) -> void:
	if not is_inside_tree():
		return
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if (layer as CanvasLayer).visible and (keep == null or not keep.is_ancestor_of(layer)):
			_hidden.append(layer)
	for node in world.find_children("*", "Node3D", true, false):
		if node is CharacterHealthRing3D and (node as Node3D).visible:
			_hidden.append(node)
	for node in _hidden:
		node.set(&"visible", false)


func _mount_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "ConversationOverlay"
	_overlay.layer = OVERLAY_LAYER
	add_child(_overlay)
	var shader := Shader.new()
	shader.code = OVERLAY_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter(&"black", 1.0)
	var rect := ColorRect.new()
	rect.material = _material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(rect)


static func _points_center(points: Array[Vector3]) -> Vector3:
	var center := Vector3.ZERO
	for point in points:
		center += point
	return center / maxf(1.0, points.size())
