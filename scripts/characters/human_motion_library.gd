extends RefCounted
## Shared clip libraries for realistic humans (R-2211).
##
## Realistic body GLBs ship without animations. Their 76 clips live once per body
## shape in `shared/motion/<shape>.glb` (tools/assets/realistic_humans/
## shared_motion.py), and `shapes.json` maps each body to its shape, so the three
## outfit variants of a citizen build load one set. `attach` gives a rig's body an
## AnimationPlayer holding that set; all rigs of a shape share the Animation
## resources, exactly as rigs sharing one body GLB did before.
## docs/SYSTEMS/HUMAN_MOTION_LIBRARY.md

const MOTION_DIR := "res://assets/characters/realistic/shared/motion/"
const MANIFEST := MOTION_DIR + "shapes.json"
const HIPS := &"hips"

static var _bodies: Dictionary = {}
## "<shape>|<track prefix>" -> AnimationLibrary
static var _libraries: Dictionary = {}
## shape -> {library, prefix}
static var _shapes: Dictionary = {}


## Adds an AnimationPlayer with the body's shape library as a child of the body's scene
## root (the child of `model` containing `skeleton`) and returns it. Null when the body
## has no registered shape or is not a human motion rig.
static func attach(model: Node, skeleton: Skeleton3D) -> AnimationPlayer:
	var body_root: Node = skeleton
	while body_root.get_parent() != null and body_root.get_parent() != model:
		body_root = body_root.get_parent()
	if body_root == skeleton or skeleton.find_bone(HIPS) < 0:
		return null
	var library := library_for(body_basename(body_root), String(body_root.get_path_to(skeleton)))
	if library == null:
		return null
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	body_root.add_child(player)
	player.add_animation_library(&"", library)
	return player


## Library for body GLB `basename` whose Skeleton3D sits at `track_prefix` below the scene
## root. Null for a body without a registered shape.
static func library_for(basename: String, track_prefix: String) -> AnimationLibrary:
	var shape := shape_of(basename)
	if shape.is_empty():
		return null
	var key := "%s|%s" % [shape, track_prefix]
	if not _libraries.has(key):
		var source := _load_shape(shape)
		if source.is_empty():
			return null
		_libraries[key] = _with_prefix(source["library"], source["prefix"], track_prefix)
	return _libraries[key]


## Shape name for a body GLB basename, empty when unregistered.
static func shape_of(basename: String) -> String:
	if _bodies.is_empty():
		var file := FileAccess.open(MANIFEST, FileAccess.READ)
		if file != null:
			_bodies = (JSON.parse_string(file.get_as_text()) as Dictionary).get("bodies", {})
	return String(_bodies.get(basename, ""))


static func body_basename(body_root: Node) -> String:
	return body_root.scene_file_path.get_file().get_basename()


## Bodies built from different Blender sessions can carry a different rig node name
## (HumanMotionRig vs HumanMotionRig_001); retarget the paths on a copy in that case.
static func _with_prefix(
	library: AnimationLibrary, from_prefix: String, to_prefix: String
) -> AnimationLibrary:
	if from_prefix == to_prefix:
		return library
	var copy := AnimationLibrary.new()
	for clip_name: StringName in library.get_animation_list():
		var clip := library.get_animation(clip_name).duplicate(true) as Animation
		for track in clip.get_track_count():
			var path := String(clip.track_get_path(track))
			if path.begins_with(from_prefix):
				clip.track_set_path(track, NodePath(to_prefix + path.substr(from_prefix.length())))
		copy.add_animation(clip_name, clip)
	return copy


static func _load_shape(shape: String) -> Dictionary:
	if _shapes.has(shape):
		return _shapes[shape]
	var scene := (load("%s%s.glb" % [MOTION_DIR, shape]) as PackedScene).instantiate()
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	var result := {}
	if not players.is_empty() and not skeletons.is_empty():
		result = {
			"library": (players[0] as AnimationPlayer).get_animation_library(&""),
			"prefix": String(scene.get_path_to(skeletons[0])),
		}
	scene.free()
	_shapes[shape] = result
	return result
