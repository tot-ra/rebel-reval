extends Node
## Cinematic framing for a conversation held in the live world (R-1877, made universal by
## R-1888): no separate scene, the speakers stand where they are and a second camera in the
## same World3D frames them at eye level. It opens on a two-shot, then `focus()` cuts to an
## over-the-shoulder close shot on whoever speaks (from behind the listener, never crossing the
## line between them). Every shot is tested for line of sight against the drawn geometry
## (ShotOcclusion): of several candidate angles the one that sees the faces wins, so a beam or a
## wall never fills the frame. Gameplay HUD layers and overhead bars are hidden for the shot (all
## but the `keep` subtree, which holds the dialogue box). While it is current the shot adds a
## harder, less saturated grade, a far-plane depth blur and a vignette with thin letterbox bars;
## `release(blend)` hands the view back to the gameplay camera, cutting or craning up to it
## (a conversation that turns into a duel rises to the play view). Used by SmithyOpening for
## Kalev's arrival and by CharacterConversation for talk with anyone.

signal released

const ShotOcclusion := preload("res://scripts/prologue/shot_occlusion.gd")

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
## Two-shot search: turns (radians, off the preferred angle) and distance scales tried in this
## order until every face is seen. The first entries keep the composition; later ones trade it
## for a clear view.
const TWO_SHOT_TURNS: Array[float] = [0.0, 0.3, -0.3, 0.6, -0.6, 1.0, -1.0, 2.6, -2.6, PI]
const TWO_SHOT_SCALES: Array[float] = [1.0, 0.75]
## Over-the-shoulder close shot: behind the listener's head, off to one shoulder, at his eye
## height, on a longer lens that holds the speaker's head and chest.
## The last entry is a point-of-view shot from just in front of the listener's face: in a
## crowd nobody can stand between two people talking at arm's length.
const SHOULDER_BACK: Array[float] = [0.9, 0.65, 0.45, -0.2]
const SHOULDER_SIDE := 0.42
const SHOULDER_FOV := 30.0
## Meshes this far around the subjects can stand between them and the lens.
const OCCLUSION_RADIUS := MAX_DISTANCE + 2.5
## Assumed height of a subject given only as a point.
const DEFAULT_HEIGHT := 1.75
## Slow push-in while the conversation runs (fraction of the distance, over DRIFT_SEC).
const DRIFT := 0.08
const DRIFT_SEC := 30.0
## Opens on black and fades up: the cut into the shot reads as an edit, not a camera snap.
const FADE_IN_SEC := 0.7
## Default rise back to the gameplay camera when a conversation turns into a duel.
const CRANE_SEC := 1.2
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
## Name of the current framing: "two_shot", "shoulder" or "single".
var shot_kind := ""
## The subject the current close shot looks at (null on the two-shot).
var focused: Node3D
## Subjects kept in the two-shot that never speak or listen (a patient lying on a bed): a close
## shot never takes their shoulder. Set before frame_subjects.
var framed_only: Array[Node3D] = []

var _previous: Camera3D
var _world: Node3D
var _subjects: Array[Node3D] = []
var _bounds_center := Vector3.ZERO
var _bounds_radius := 0.0
## Which side of the line between the first two subjects the two-shot took (+1 / -1). Close
## shots stay on it, so screen direction holds across cuts (the 180-degree rule).
var _line_side := 1.0
var _overlay: CanvasLayer
var _material: ShaderMaterial
var _tween: Tween
var _hidden: Array[Node] = []
var _releasing := false
var _lines_cued := 0
## Passers-by hidden because they stood in the current shot.
var _hidden_people: Array[Node3D] = []
var _occlusion := ShotOcclusion.new()


## Frames `points` (subjects' feet, world space) from the side nearest `from_hint`, keeping the
## camera within `bounds_radius` of `bounds_center` (the room). Returns `transform` and the
## vertical `fov`: when the room holds the camera closer than the fit, the lens widens instead.
## `turn` swings the camera round the subjects and `scale` pulls it in (the occlusion search).
static func compute_shot(
	points: Array[Vector3], from_hint: Vector3, aspect: float,
	bounds_center: Vector3 = Vector3.ZERO, bounds_radius: float = 0.0,
	turn: float = 0.0, scale: float = 1.0
) -> Dictionary:
	var center := _points_center(points)
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
	normal = normal.rotated(Vector3.UP, ANGLE + turn)
	var half_width := FRAME_MARGIN
	for point in points:
		half_width = maxf(half_width, absf((point - center).dot(axis)) + FRAME_MARGIN)
	aspect = maxf(aspect, 0.1)
	var half_h := atan(tan(deg_to_rad(LENS_FOV) * 0.5) * aspect)
	var distance := clampf(half_width / tan(half_h), MIN_DISTANCE, MAX_DISTANCE) * scale
	var eye := center + normal * distance
	if bounds_radius > 0.0:
		var flat := Vector3(eye.x - bounds_center.x, 0.0, eye.z - bounds_center.z)
		if flat.length() > bounds_radius:
			flat = flat.normalized() * bounds_radius
			eye = Vector3(bounds_center.x + flat.x, eye.y, bounds_center.z + flat.z)
	eye.y = center.y + EYE_HEIGHT
	var fov := LENS_FOV
	var held := Vector2(eye.x - center.x, eye.z - center.z).length()
	if held < distance / scale - 0.01:
		var needed_h := atan(half_width / maxf(held, 0.1))
		fov = minf(MAX_FOV, rad_to_deg(2.0 * atan(tan(needed_h) / aspect)))
	var aim := Vector3(center.x, center.y + LOOK_HEIGHT, center.z)
	return {
		"transform": Transform3D(Basis.looking_at(aim - eye, Vector3.UP), eye),
		"fov": maxf(fov, LENS_FOV),
	}


## Over-the-shoulder shot on `speaker` (feet, height) from behind `listener`, on `side` (+1 or
## -1 of the listener -> speaker line). `back` is how far behind the listener's head the lens is.
static func compute_shoulder_shot(
	speaker: Vector3, speaker_height: float, listener: Vector3, listener_height: float,
	side: float, back: float
) -> Dictionary:
	var toward := Vector3(speaker.x - listener.x, 0.0, speaker.z - listener.z)
	toward = toward.normalized() if not toward.is_zero_approx() else Vector3.FORWARD
	var right := Vector3(-toward.z, 0.0, toward.x)
	var eye := listener - toward * back + right * side * (SHOULDER_SIDE if back > 0.0 else 0.0)
	# At the listener's eyes: a short boy looks up at a tall smith, as he would.
	eye.y = listener.y + listener_height * 0.9
	# Aimed at the chest so the face sits in the upper third, clear of the dialogue box.
	var aim := speaker + Vector3.UP * speaker_height * 0.7
	return {
		"transform": Transform3D(Basis.looking_at(aim - eye, Vector3.UP), eye),
		"fov": SHOULDER_FOV,
	}


## Cuts to a two-shot of `points` (subjects' feet). `world` hosts the camera; the overlay fades
## up from black. Kept for callers that only know positions; `frame_subjects` also checks the
## faces against the room and enables close shots.
func frame(
	world: Node3D, points: Array[Vector3], bounds_center: Vector3, bounds_radius: float,
	keep: Variant = null
) -> void:
	_open(world, bounds_center, bounds_radius, keep)
	var heights: Array[float] = []
	for _point in points:
		heights.append(DEFAULT_HEIGHT)
	_occlusion.collect(world, _points_center(points), OCCLUSION_RADIUS)
	var framed := _best_two_shot(points, heights)
	_cut_to(framed, "two_shot", null, points, framed.get("targets", []))


## Cuts to a two-shot of `subjects` (their rigs, feet at the origin), choosing the clearest
## angle, and remembers them for `focus()`.
func frame_subjects(
	world: Node3D, subjects: Array[Node3D], bounds_center: Vector3, bounds_radius: float,
	keep: Variant = null
) -> void:
	_open(world, bounds_center, bounds_radius, keep)
	_subjects = subjects.filter(func(n: Node3D) -> bool: return is_instance_valid(n))
	var points := _subject_points()
	var heights := _subject_heights()
	_occlusion.collect(
		_common_root(world, _subjects), _points_center(points), OCCLUSION_RADIUS, _subjects
	)
	var framed := _best_two_shot(points, heights)
	if not framed.is_empty():
		_line_side = _side_of((framed["transform"] as Transform3D).origin)
	_cut_to(framed, "two_shot", null, points, framed.get("targets", []))


## Close shot on `speaker` over the shoulder of the nearest other subject. Does nothing while
## releasing or when `speaker` is not one of the subjects.
func focus(speaker: Node3D) -> void:
	if _releasing or camera == null or not is_instance_valid(speaker):
		return
	if not _subjects.has(speaker) or speaker == focused:
		return
	var listener: Node3D = null
	var nearest := INF
	for subject in _subjects:
		if subject == speaker or not is_instance_valid(subject) or framed_only.has(subject):
			continue
		var d := subject.global_position.distance_to(speaker.global_position)
		if d < nearest:
			nearest = d
			listener = subject
	if listener == null:
		return
	var targets := _face_targets(speaker)
	var best: Dictionary = {}
	var best_seen := -1
	# Keep the lens on the two-shot's side of the line between the subjects (the reverse shot
	# flips the listener -> speaker direction, not the screen side).
	var probe := compute_shoulder_shot(
		speaker.global_position, 1.0, listener.global_position, 1.0, 1.0, SHOULDER_BACK[0]
	)
	var side := 1.0 if _side_of((probe["transform"] as Transform3D).origin) == _line_side else -1.0
	for side_sign: float in [side, -side]:
		for back: float in SHOULDER_BACK:
			var framed := compute_shoulder_shot(
				speaker.global_position, _height_of(speaker),
				listener.global_position, _height_of(listener), side_sign, back
			)
			framed = _held_in_bounds(framed)
			var eye: Vector3 = (framed["transform"] as Transform3D).origin
			# Scenery decides; a passer-by in the way only costs a little (the cut hides them).
			var seen := (
				_occlusion.visible_count(eye, targets, true) * 10
				+ _occlusion.visible_count(eye, targets)
			)
			if seen > best_seen:
				best_seen = seen
				best = framed
			if seen == targets.size() * 11:
				break
		if best_seen == targets.size() * 11:
			break
	if best_seen < 10:
		return
	focused = speaker
	var points: Array[Vector3] = [speaker.global_position]
	_cut_to(best, "shoulder", speaker, points, targets)


## A line by `speaker` is on screen. The first line plays on the opening two-shot so the
## player sees where everyone stands; later lines cut to the speaker.
func cue_line(speaker: Node3D) -> void:
	_lines_cued += 1
	if _lines_cued > 1:
		focus(speaker)


## Back to the two-shot (e.g. while the hero picks a reply).
func widen() -> void:
	if _releasing or camera == null or focused == null:
		return
	focused = null
	var points := _subject_points()
	var framed := _best_two_shot(points, _subject_heights())
	_cut_to(framed, "two_shot", null, points, framed.get("targets", []))


## Back to the gameplay camera. `blend_sec` 0 cuts; above 0 the camera rises along a smooth
## path to the live gameplay view first (the conversation turning into a duel). `released`
## fires when the gameplay camera is current again.
func release(blend_sec: float = 0.0) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if (
		blend_sec > 0.0 and is_instance_valid(camera) and camera.is_inside_tree()
		and is_instance_valid(_previous) and _previous.is_inside_tree() and not _releasing
	):
		_releasing = true
		_show_people()
		var start := camera.global_transform
		var start_fov := camera.fov
		# Unset uniforms read back as null: fall back to the shader defaults.
		var bars := _shader_param(&"bars", 0.07)
		var vignette := _shader_param(&"vignette", 0.6)
		_tween = create_tween()
		_tween.tween_method(
			func(t: float) -> void:
				if not is_instance_valid(camera) or not is_instance_valid(_previous):
					return
				# Follows the live gameplay camera, which keeps tracking the hero.
				camera.global_transform = start.interpolate_with(_previous.global_transform, t)
				camera.fov = lerpf(start_fov, _previous.fov, t)
				if camera.attributes is CameraAttributesPractical:
					(camera.attributes as CameraAttributesPractical).dof_blur_amount = (
						DOF_AMOUNT * (1.0 - t)
					)
				if _material != null:
					_material.set_shader_parameter(&"bars", bars * (1.0 - t))
					_material.set_shader_parameter(&"vignette", vignette * (1.0 - t)),
			0.0, 1.0, blend_sec
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_callback(_finish_release)
		return
	_finish_release()


func _shader_param(param: StringName, fallback: float) -> float:
	var value: Variant = _material.get_shader_parameter(param) if _material != null else null
	return float(value) if value != null else fallback


func is_releasing() -> bool:
	return _releasing


func _show_people() -> void:
	for person in _hidden_people:
		if is_instance_valid(person):
			person.visible = true
	_hidden_people.clear()


func _finish_release() -> void:
	_show_people()
	_releasing = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if is_instance_valid(_previous) and _previous.is_inside_tree():
		_previous.current = true
	if is_instance_valid(camera):
		camera.queue_free()
	camera = null
	focused = null
	shot_kind = ""
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_material = null
	for node in _hidden:
		if is_instance_valid(node):
			node.set(&"visible", true)
	_hidden.clear()
	_subjects.clear()
	_lines_cued = 0
	released.emit()


func _exit_tree() -> void:
	if camera != null or not _hidden.is_empty():
		_finish_release()


func _open(world: Node3D, bounds_center: Vector3, bounds_radius: float, keep: Variant) -> void:
	_world = world
	_bounds_center = bounds_center
	_bounds_radius = bounds_radius
	if camera != null:
		return
	var viewport := world.get_viewport() if world.is_inside_tree() else null
	_previous = viewport.get_camera_3d() if viewport != null else null
	camera = Camera3D.new()
	camera.name = "ConversationCamera"
	world.add_child(camera)
	camera.environment = _environment(world)
	camera.attributes = _attributes(MAX_DISTANCE)
	camera.current = true
	_hide_hud(world, keep)
	_mount_overlay()
	var fade := create_tween()
	fade.tween_property(_material, ^"shader_parameter/black", 0.0, FADE_IN_SEC).from(1.0)


## Places the camera, sets the far blur behind the deepest subject and starts the slow push-in.
## Passers-by standing between the lens and `targets` (faces) are hidden until the next cut.
func _cut_to(
	framed: Dictionary, kind: String, target: Node3D, points: Array[Vector3], targets: Array = []
) -> void:
	if camera == null or framed.is_empty():
		return
	shot_kind = kind
	focused = target
	var shot: Transform3D = framed["transform"]
	camera.global_transform = shot
	camera.fov = framed["fov"]
	_show_people()
	for face: Vector3 in targets:
		for person in _occlusion.people_between(shot.origin, face):
			if person.visible:
				person.visible = false
				_hidden_people.append(person)
	var deepest := 0.0
	for point in points:
		deepest = maxf(deepest, shot.origin.distance_to(point))
	if camera.attributes is CameraAttributesPractical:
		(camera.attributes as CameraAttributesPractical).dof_blur_far_distance = deepest + DOF_BEHIND
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var aim := shot.origin + -shot.basis.z * shot.origin.distance_to(_points_center(points))
	_tween = create_tween()
	_tween.tween_property(camera, ^"global_position", shot.origin.lerp(aim, DRIFT), DRIFT_SEC)


## Tries the preferred two-shot, then turns and closer distances, until all faces are seen.
func _best_two_shot(points: Array[Vector3], heights: Array[float]) -> Dictionary:
	var size := (
		_world.get_viewport().get_visible_rect().size if _world.is_inside_tree()
		else Vector2(16, 9)
	)
	var aspect := size.x / maxf(size.y, 1.0)
	var hint := (
		_previous.global_position if is_instance_valid(_previous)
		else _bounds_center + Vector3.BACK * MAX_DISTANCE
	)
	var targets: Array = []
	for i in points.size():
		var h: float = heights[i] if i < heights.size() else DEFAULT_HEIGHT
		targets.append(points[i] + Vector3.UP * h * 0.92)
		targets.append(points[i] + Vector3.UP * h * 0.65)
	# The space between the speakers is the middle of the frame: a passer-by standing there
	# fills it without crossing any face ray.
	if points.size() >= 2:
		for t: float in [0.3, 0.5, 0.7]:
			targets.append(points[0].lerp(points[1], t) + Vector3.UP * LOOK_HEIGHT)
	var best: Dictionary = {}
	var best_score := -INF
	for scale: float in TWO_SHOT_SCALES:
		for turn: float in TWO_SHOT_TURNS:
			var framed := compute_shot(
				points, hint, aspect, _bounds_center, _bounds_radius, turn, scale
			)
			var eye: Vector3 = (framed["transform"] as Transform3D).origin
			var clear := _occlusion.visible_count(eye, targets)
			# A face behind scenery is lost; one behind a passer-by is not (the cut hides them),
			# and either outweighs any composition preference.
			var score := (
				_occlusion.visible_count(eye, targets, true) * 10.0 + clear * 2.0
				- absf(turn) - (1.0 - scale) * 2.0
			)
			if score > best_score:
				best_score = score
				best = framed
			if clear == targets.size():
				break
		if not best.is_empty() and _occlusion.visible_count(
			(best["transform"] as Transform3D).origin, targets
		) == targets.size():
			break
	best["targets"] = targets
	return best


func _held_in_bounds(framed: Dictionary) -> Dictionary:
	if _bounds_radius <= 0.0:
		return framed
	var shot: Transform3D = framed["transform"]
	var flat := Vector3(shot.origin.x - _bounds_center.x, 0.0, shot.origin.z - _bounds_center.z)
	if flat.length() <= _bounds_radius:
		return framed
	flat = flat.normalized() * _bounds_radius
	var eye := Vector3(_bounds_center.x + flat.x, shot.origin.y, _bounds_center.z + flat.z)
	var aim := shot.origin + -shot.basis.z * 4.0
	return {
		"transform": Transform3D(Basis.looking_at(aim - eye, Vector3.UP), eye),
		"fov": framed["fov"],
	}


## The lowest Node3D holding the world and every subject: the city mirrors people under
## MapViewRuntime, beside the CityWorld3D that holds the buildings, and both block a lens.
static func _common_root(world: Node3D, subjects: Array[Node3D]) -> Node3D:
	var root: Node = world
	for subject in subjects:
		while root != null and not (root == subject or root.is_ancestor_of(subject)):
			root = root.get_parent()
	var spatial := root as Node3D
	while root != null and spatial == null:
		root = root.get_parent()
		spatial = root as Node3D
	return spatial if spatial != null else world


## +1 or -1: which side of the line from the first to the second subject `point` is on.
func _side_of(point: Vector3) -> float:
	if (
		_subjects.size() < 2
		or not is_instance_valid(_subjects[0]) or not is_instance_valid(_subjects[1])
	):
		return 1.0
	var line := _subjects[1].global_position - _subjects[0].global_position
	var v := point - _subjects[0].global_position
	return 1.0 if line.x * v.z - line.z * v.x >= 0.0 else -1.0


func _subject_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for subject in _subjects:
		if is_instance_valid(subject):
			points.append(subject.global_position)
	return points


func _subject_heights() -> Array[float]:
	var heights: Array[float] = []
	for subject in _subjects:
		if is_instance_valid(subject):
			heights.append(_height_of(subject))
	return heights


func _face_targets(subject: Node3D) -> Array:
	var h := _height_of(subject)
	return [
		subject.global_position + Vector3.UP * h * 0.92,
		subject.global_position + Vector3.UP * h * 0.65,
	]


## Standing height of a rig from its drawn meshes (a boy is shorter than a smith), clamped to a
## human range; points without meshes use DEFAULT_HEIGHT.
static func _height_of(subject: Node3D) -> float:
	var top := -INF
	for node in subject.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		if not visual.is_visible_in_tree() or visual is Label3D or visual is Sprite3D:
			continue
		var box := visual.global_transform * visual.get_aabb()
		top = maxf(top, box.end.y)
	if top == -INF:
		return DEFAULT_HEIGHT
	return clampf(top - subject.global_position.y, 0.9, 2.1)


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
## `keep` is a node or an array of nodes whose layers stay up (dialogue box, speaker card).
func _hide_hud(world: Node3D, keep: Variant) -> void:
	if not is_inside_tree():
		return
	var kept: Array = keep if keep is Array else ([keep] if keep is Node else [])
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if (layer as CanvasLayer).visible and not ShotOcclusion._under_any(layer, kept):
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
