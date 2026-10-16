extends RefCounted

## Belt gear of the census residents (task R-2033, docs/SYSTEMS/EQUIPMENT_VARIANTS.md
## "Belt gear"): buckle, strap-end and mounts by prestige, a purse, the key bunch and the
## paternoster, as rigid scanned parts (assets/props/clothing/belt_gear/) hung on the
## belt baked into the body's base outfit.
##
## The belt itself stays the body's baked leather band (garments.py `belt`). Its ring is
## measured here from the body mesh's `*_belt_leather` surface, so every part sits on
## that very band whatever the body, and the parts follow the hips bone. Hanging parts
## (purse, keys, beads, the strap-end's tail) swing out over a skirt or belly measured
## below the belt instead of sinking into it.
##
## Tiers (the resident's own prestige, as tools/city/citizen_wardrobe.py prestige_of):
## p1 plain iron buckle, short tucked tail, undyed leather drawstring purse;
## p2 latten buckle with plate, latten strap-end, flap pouch;
## p3 silver-gilt buckle and strap-end, gilt quatrefoil mounts round the front, silk purse.
## Wear: the resident's own cell wear through the variant stand-in finish (EquipmentVariant).
## Keys are iron; the paternoster's beads are bone, boxwood, amber or coral by the census dye.
##
## Not hung: under a torso layer that covers the belt (aketon, mail, surcoat, plates,
## mantle), and the front pieces behind an apron. A body without a baked belt keeps the
## fitted `keys` and `paternoster` layers (CitizenWardrobe).
## Preloaded by CitizenWardrobe, no class_name.

const EquipmentVariant := preload("res://scripts/city/equipment_variant.gd")

const DIR := "res://assets/props/clothing/belt_gear"
## Wear layers this replaces with rigid parts when the body has a belt.
const LAYERS := ["keys", "paternoster"]
const BELT_SUFFIX := "_belt_leather"
const NODE_NAME := &"BeltGear"
const COVERS := ["gambeson", "mail_haubergeon", "surcoat", "coat_of_plates", "order_mantle"]
const APRONS := ["smith_apron", "waist_apron"]
## Base-outfit surfaces worn over the baked belt (the sideless surcoat of the `_c` gowns):
## the belt only shows through the side openings, so nothing is hung on it.
const BODY_COVERS := ["_sideless_surcoat"]
## Statuses the census does not count poor (citizen_wardrobe.py WEALTH keys); any other is p1.
const NOT_POOR := [
	"patrician", "noble", "guest_merchant", "burgher_merchant", "master_craftsman", "clerk",
	"cleric", "free_commoner", "journeyman", "soldier", "burgher",
]
## Duty-kit layers carry the unit's issue cell, not the resident's own
## (citizen_wardrobe.py DUTY_KITS).
const KIT_LAYERS := ["gambeson", "kettle_hat", "mail_haubergeon", "surcoat", "mail_coif", "keys"]

## Band of the baked belt: garments.py `band` width 0.036 m; the ring is measured from
## its top `RING_BAND` so the old purse box below it does not widen the ellipse.
const BAND_WIDTH := 0.036
const RING_BAND := 0.012
## Angles round the belt from the front toward the wearer's left (+X), as garments.horizontal.
const PURSE_ANGLE := -PI * 0.5
const KEYS_ANGLE := 0.95
const BEADS_ANGLE := -0.9
## p3 mounts: every MOUNT_STEP from the buckle to MOUNT_LAST each way, clear of hanging parts.
const MOUNT_FIRST := 0.42
const MOUNT_STEP := 0.26
const MOUNT_LAST := 1.35
const MOUNT_CLEAR := 0.16
## Free end of the belt below the buckle: long tails were the fashion of the rich.
const TAIL := {1: 0.07, 2: 0.16, 3: 0.24}
const TAIL_WIDTH := 0.03
const TAIL_THICK := 0.005
## Where the tail comes out of the buckle frame, as a share of the buckle's half length.
const TAIL_AT := 0.55
## Hanging parts swing out by the skirt or belly measured `PROBE_DROP` below the belt
## plus `SPLAY_PAD`, between 0 and SPLAY_MAX radians.
const PROBE_DROP := 0.16
const SPLAY_PAD := 0.012
const SPLAY_MAX := 0.6
## Small parts vanish where the body itself drops to LOD1 (SharedCharacterRig.LOD0_VISIBILITY_END).
const DRAW_RANGE := 16.0
## Bead colours (sRGB) for the census paternoster dyes (citizen_wardrobe.py BOXWOOD, AMBER, CORAL).
const BEAD_DYES := {
	"boxwood": Vector3(0.55, 0.40, 0.22),
	"amber": Vector3(0.70, 0.42, 0.12),
	"coral": Vector3(0.62, 0.16, 0.12),
}
const BEADS := {
	"boxwood": [Color(0.56, 0.38, 0.2), 0.6],
	"amber": [Color(0.86, 0.47, 0.1), 0.22],
	"coral": [Color(0.78, 0.24, 0.17), 0.38],
}
const BEAD_SURFACE := "belt_gear_paternoster_beads"

## Body mesh + transform key -> girdle Dictionary ({} when the mesh has no belt).
static var _rings: Dictionary = {}
## Mesh + transform + height key -> [lo, hi] (x, z) extents.
static var _bands: Dictionary = {}
static var _beads: Dictionary = {}


## Prestige 1..3 of the resident's own things (citizen_wardrobe.py prestige_of).
static func prestige_of(record: Dictionary) -> int:
	var kit := String((record.get("duty", {}) as Dictionary).get("kit", ""))
	var faction := String(record.get("faction", "none"))
	var trade := String(record.get("trade", ""))
	var status := String(record.get("status", ""))
	if kit == "sergeant":
		return 2 if faction == "danish_crown" else 1
	if kit in ["watch", "keeper"]:
		return 1
	if kit == "crown":
		return 2
	if trade == "knight" and status == "noble":
		return 3
	if trade in ["man_at_arms", "squire"]:
		return 2 if faction in ["danish_crown", "livonian_order"] else 1
	if status in ["noble", "patrician"]:
		return 3
	return 2 if status in NOT_POOR else 1


## The resident's own cell: prestige_of with the wear of an own-cell layer, else w1.
static func cell_of(record: Dictionary) -> String:
	var level := 1
	for entry: String in record.get("wear", []):
		var parts := EquipmentVariant.split(entry)
		if parts[0] not in KIT_LAYERS and EquipmentVariant.is_cell(parts[1]):
			level = EquipmentVariant.wear(parts[1])
			break
	return "p%d_w%d" % [prestige_of(record), level]


## Layers of `record` that hang() shows as rigid parts on this rig (skip their fitted GLBs).
static func handles(rig: SharedCharacterRig, record: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var layers := _layers(record)
	var ring := girdle(rig)
	if _covered(layers) or ring.is_empty() or bool(ring["covered"]):
		return out
	for layer in LAYERS:
		if layer in layers:
			out.append(layer)
	return out


## Hangs the resident's belt gear on `rig`; returns the mounted root, or null when the
## body has no baked belt or the belt is covered. Safe to call twice.
static func hang(rig: SharedCharacterRig, record: Dictionary) -> Node3D:
	var skeleton := rig.skeleton()
	if skeleton == null or skeleton.has_node(NodePath(NODE_NAME)):
		return null
	var layers := _layers(record)
	var ring := girdle(rig)
	var hips := skeleton.find_bone("hips")
	if hips < 0 or ring.is_empty() or bool(ring["covered"]) or _covered(layers):
		return null
	var cell := cell_of(record)
	var level := EquipmentVariant.prestige(cell)
	var low := _girth(rig, skeleton, float(ring["y"]) - PROBE_DROP)
	var root := Node3D.new()
	root.name = "Parts"
	# The attachment follows the hips bone; undo its rest so children sit in skeleton space.
	root.transform = skeleton.get_bone_global_rest(hips).affine_inverse()
	var used: Array[float] = []
	if not _aproned(layers):
		_front(root, ring, low, level, cell)
		used.append(0.0)
	if int(record.get("age", 30)) >= 12:
		_add(root, _part("purse", level, cell), _frame(ring, low, PURSE_ANGLE, true))
		used.append(PURSE_ANGLE)
	if "keys" in layers:
		_add(root, _part("keys", 1, cell), _frame(ring, low, KEYS_ANGLE, true))
		used.append(KEYS_ANGLE)
	if "paternoster" in layers:
		var beads := _part("paternoster", 1, "p1_w1")
		_tint_beads(beads, record, level)
		_add(root, beads, _frame(ring, low, BEADS_ANGLE, true))
		used.append(BEADS_ANGLE)
	if level >= 3 and not _aproned(layers):
		_mounts(root, ring, low, cell, used)
	var attachment := BoneAttachment3D.new()
	attachment.name = NODE_NAME
	attachment.bone_name = "hips"
	attachment.add_child(root)
	skeleton.add_child(attachment)
	# Spirit sight and other rig render layers reach rigid props as they do equipped ones.
	rig._apply_visual_layers(attachment)
	return root


## Ring of the body's baked belt in skeleton space: {"y": band centre height,
## "centre": Vector2 (x, z), "radii": Vector2, "material": the belt's own material,
## "covered": a base-outfit layer hides it (BODY_COVERS)};
## {} when no mesh on the rig carries a belt surface.
static func girdle(rig: SharedCharacterRig) -> Dictionary:
	var skeleton := rig.skeleton()
	if skeleton == null:
		return {}
	var to_skeleton := _to_rig(skeleton, rig).affine_inverse()
	var best: Dictionary = {}
	for node: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or _is_prop(mesh_instance, rig):
			continue
		var xf := to_skeleton * _to_rig(mesh_instance, rig)
		var key := "%d:%s" % [mesh_instance.mesh.get_instance_id(), xf]
		if not _rings.has(key):
			_rings[key] = _ring(mesh_instance.mesh, xf)
		var ring: Dictionary = _rings[key]
		if not ring.is_empty() and int(ring["count"]) > int(best.get("count", 0)):
			best = ring
	return best


static func _ring(mesh: Mesh, xf: Transform3D) -> Dictionary:
	var points := PackedVector3Array()
	var material: Material = null
	var covered := false
	for surface in mesh.get_surface_count():
		var source := mesh.surface_get_material(surface)
		for suffix: String in BODY_COVERS:
			covered = covered or (source != null and source.resource_name.ends_with(suffix))
		if source == null or not source.resource_name.ends_with(BELT_SUFFIX):
			continue
		material = source
		for v: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			points.append(xf * v)
	if points.is_empty():
		return {}
	var top := -INF
	for p in points:
		top = maxf(top, p.y)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var count := 0
	for p in points:
		if p.y < top - RING_BAND:
			continue
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
		count += 1
	return {
		"y": top - BAND_WIDTH * 0.5,
		"centre": (lo + hi) * 0.5,
		"radii": (hi - lo) * 0.5,
		"material": material,
		"count": count,
		"covered": covered,
	}


## Buckle at the front, the tail from its frame down with the strap-end (p2, p3).
static func _front(root: Node3D, ring: Dictionary, low: Rect2, level: int, cell: String) -> void:
	var buckle := _part("buckle", level, cell)
	_add(root, buckle, _frame(ring, low, 0.0, false))
	var half := _half_length(buckle)
	var radii: Vector2 = ring["radii"]
	var angle := half * TAIL_AT / radii.y
	var hang := Node3D.new()
	hang.name = "Tail"
	var tail := MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(TAIL_WIDTH, TAIL[level], TAIL_THICK)
	tail.mesh = strip
	tail.material_override = ring["material"]
	tail.position = Vector3(0.0, -TAIL[level] * 0.5 + 0.006, TAIL_THICK * 0.5 + 0.004)
	hang.add_child(tail)
	if level >= 2:
		var end := _part("strap_end", level, cell)
		# The strap-end's own leather stub overlaps the tail's last 2 cm.
		end.position = Vector3(0.0, -TAIL[level] + 0.026, 0.006)
		hang.add_child(end)
	_add(root, hang, _frame(ring, low, angle, true))


static func _mounts(
	root: Node3D, ring: Dictionary, low: Rect2, cell: String, used: Array[float]
) -> void:
	var angle := MOUNT_FIRST
	while angle <= MOUNT_LAST:
		for side in [-1.0, 1.0]:
			var at: float = angle * side
			var clear := true
			for other in used:
				clear = clear and absf(other - at) > MOUNT_CLEAR + (0.25 if other == PURSE_ANGLE else 0.0)
			if clear:
				_add(root, _part("mount", 3, cell), _frame(ring, low, at, false))
		angle += MOUNT_STEP


## Part transform at `angle` round the ring: back on the band's outer face, +Z out,
## +Y up, swung out over the lower body when `hanging`.
static func _frame(ring: Dictionary, low: Rect2, angle: float, hanging: bool) -> Transform3D:
	var centre: Vector2 = ring["centre"]
	var radii: Vector2 = ring["radii"]
	var side := Vector2(sin(angle), cos(angle))
	var on_band := Vector3(
		centre.x + radii.x * side.x, float(ring["y"]), centre.y + radii.y * side.y
	)
	var out := Vector3(side.x / radii.x, 0.0, side.y / radii.y).normalized()
	var splay := 0.0
	if hanging:
		var at_belt := centre + radii * side
		var at_low := low.position + low.size * side
		var beyond := (at_low - at_belt).dot(Vector2(out.x, out.z)) + SPLAY_PAD
		splay = clampf(atan2(beyond, PROBE_DROP), 0.0, SPLAY_MAX)
	# The bottom swings out, so +Y (up the part) leans in toward the body's axis.
	var y := (Vector3.UP * cos(splay) - out * sin(splay)).normalized()
	var z := (out - y * out.dot(y)).normalized()
	return Transform3D(Basis(y.cross(z), y, z), on_band + out * 0.002)


## Ellipse (position = centre, size = radii in x, z) of every visible body and garment
## mesh in a slice round `y` (skeleton space), as SwordBelt measures its girth.
static func _girth(rig: SharedCharacterRig, skeleton: Skeleton3D, y: float) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var to_skeleton := _to_rig(skeleton, rig).affine_inverse()
	for node: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.visible or _is_prop(mesh_instance, rig):
			continue
		var xf := to_skeleton * _to_rig(mesh_instance, rig)
		var key := "%d:%s:%.3f" % [mesh_instance.mesh.get_instance_id(), xf, y]
		if not _bands.has(key):
			_bands[key] = _slice(mesh_instance.mesh, xf, y)
		var band: Array = _bands[key]
		if band.is_empty():
			continue
		lo = Vector2(minf(lo.x, band[0].x), minf(lo.y, band[0].y))
		hi = Vector2(maxf(hi.x, band[1].x), maxf(hi.y, band[1].y))
	if lo.x == INF:
		return Rect2()
	return Rect2((lo + hi) * 0.5, (hi - lo) * 0.5)


## [lo, hi] (x, z) of bind-pose vertices within 2 cm of `y`; [] when none. The bind pose
## holds the arms out, so a stray hand (|x| > 0.5) is ignored.
static func _slice(mesh: Mesh, xf: Transform3D, y: float) -> Array:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for surface in mesh.get_surface_count():
		for v: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var p := xf * v
			if absf(p.y - y) > 0.02 or absf(p.x) > 0.5:
				continue
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	return [] if lo.x == INF else [lo, hi]


## Instance of `<family>_p<level>_w1`, finished to the wear of `cell`; tagged with its variant id.
static func _part(family: String, level: int, cell: String) -> Node3D:
	var shipped := "p%d_w1" % level
	var scene := EquipmentVariant.variant_scene(DIR, family, shipped)
	var node := scene.instantiate() as Node3D if scene != null else Node3D.new()
	node.name = family.to_pascal_case()
	node.set_meta(&"variant", "%s_p%d_w%d" % [family, level, EquipmentVariant.wear(cell)])
	EquipmentVariant.finish(node, cell)
	return node


static func _add(root: Node3D, part: Node3D, at: Transform3D) -> void:
	part.transform = at * part.transform
	for node: Node in part.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visibility_range_end = DRAW_RANGE
	root.add_child(part)


static func _half_length(part: Node3D) -> float:
	var half := 0.03
	for node: Node in part.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			half = maxf(half, mesh.get_aabb().size.x * 0.5)
	return half


## Bead material by the census dye: boxwood (bone for p2 and above), amber or coral.
static func _tint_beads(beads: Node3D, record: Dictionary, level: int) -> void:
	var kind := bead_kind(record, level)
	if kind == "bone":
		return
	for node: Node in beads.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or source.resource_name != BEAD_SURFACE:
				continue
			var key := "%d:%s" % [source.get_instance_id(), kind]
			if not _beads.has(key):
				var material := source.duplicate() as BaseMaterial3D
				material.resource_name = source.resource_name
				material.albedo_color = BEADS[kind][0]
				material.roughness = BEADS[kind][1]
				_beads[key] = material
			mesh_instance.set_surface_override_material(surface, _beads[key])


## "bone", "boxwood", "amber" or "coral": the nearest census bead dye; boxwood worn by
## a resident of prestige 2 or more is turned bone (the census has no bone dye).
static func bead_kind(record: Dictionary, level: int) -> String:
	var dye: Array = (record.get("wear_dye", {}) as Dictionary).get("paternoster", [])
	var kind := "boxwood"
	if dye.size() >= 3:
		var colour := Vector3(float(dye[0]), float(dye[1]), float(dye[2]))
		var best := INF
		for name: String in BEAD_DYES:
			var d := colour.distance_to(BEAD_DYES[name])
			if d < best:
				best = d
				kind = name
	return "bone" if kind == "boxwood" and level >= 2 else kind


static func _layers(record: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for entry: String in record.get("wear", []):
		out.append(EquipmentVariant.split(entry)[0])
	return out


static func _covered(layers: PackedStringArray) -> bool:
	for layer in COVERS:
		if layer in layers:
			return true
	return false


static func _aproned(layers: PackedStringArray) -> bool:
	for layer in APRONS:
		if layer in layers:
			return true
	return false


## True for meshes of mounted props (weapons, lantern, belt gear): they hang off bone
## attachments and are not part of the body the belt goes round.
static func _is_prop(node: Node, rig: Node) -> bool:
	var at := node.get_parent()
	while at != null and at != rig:
		if at is BoneAttachment3D:
			return true
		at = at.get_parent()
	return false


static func _to_rig(node: Node, rig: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var at := node
	while at != null and at != rig:
		if at is Node3D:
			xf = (at as Node3D).transform * xf
		at = at.get_parent()
	return xf
