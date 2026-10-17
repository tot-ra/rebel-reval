extends RefCounted

## Sword belt and scabbard on the left hip (docs/SYSTEMS/EQUIPMENT_VARIANTS.md, R-2007).
## 1340s fashion: a leather belt slung round the hips, its ends laced round the scabbard
## (no frog or baldric of later centuries), the scabbard hanging at the left front with the
## chape swung back. The scabbard is a variant GLB (`scabbard_<cell>`, origin at the mouth);
## the belt is built here to the girth of the body and the armour it is buckled over, since
## one rigid ring cannot fit a thin man in a tunic and a heavy knight in a coat of plates.
## A sheathed sword is the same cell's arming sword set into the scabbard by its cross.
## Preloaded, not a global class: `const SwordBelt := preload(...)`.

const EquipmentVariant := preload("res://scripts/city/equipment_variant.gd")

const SWORD_DIR := "res://assets/props/weapons/arming_sword/variants"
const SCABBARD_DIR := "res://assets/props/weapons/scabbard/variants"
const SWORD_BASE := "res://assets/props/weapons/arming_sword/variants/arming_sword_p1_w1.glb"
const SCABBARD_BASE := "res://assets/props/weapons/scabbard/variants/scabbard_p1_w1.glb"
const SLOT := &"hip_l"

## Belt height above the hips bone and the half-height of the slice measured for the
## girth, in skeleton units (the rig scales its skeleton; items are authored to it).
const BELT_RAISE := 0.01
const BAND := 0.03
## Leather strap and the gap kept over the outermost layer.
const BELT_WIDTH := 0.035
const BELT_THICK := 0.006
const EASE := 0.008
const SEGMENTS := 36
## Scabbard hang: the lacing (`LACE_BELOW_MOUTH` under the mouth) sits on the belt at
## `HANG_ANGLE` from the front toward the left; the chape swings back by `TILT_BACK` and
## out from the leg by at least `SPLAY` (radians), more when a flared skirt (aketon, coat of
## plates) measured `SKIRT_PROBE` below the belt stands further out than the belt itself.
const HANG_ANGLE := 1.1
const LACE_BELOW_MOUTH := 0.06
const TILT_BACK := 0.5
const SPLAY := 0.1
const SPLAY_MAX := 0.7
const SKIRT_PROBE := 0.3
## Belt leather and buckle metal by prestige: plain brown leather and an iron buckle,
## dark brown with latten, black (the knight's scabbard lacing) with gilt latten.
const LEATHER := {1: Color(0.3, 0.19, 0.1), 2: Color(0.19, 0.11, 0.06), 3: Color(0.05, 0.045, 0.04)}
const BUCKLE := {1: Color(0.22, 0.22, 0.23), 2: Color(0.55, 0.42, 0.2), 3: Color(0.72, 0.55, 0.25)}
## The free end of the belt hangs from the buckle; long tails were the fashion of the rich.
const TAIL := {1: 0.1, 2: 0.2, 3: 0.26}

## Mesh instance id + rig-relative transform -> [lo, hi] skeleton-space extents in the band.
static var _extents: Dictionary = {}
static var _materials: Dictionary = {}


## Buckles a sword belt with the scabbard of `cell` (a resident's `gear_variant`) on the
## rig's hips; `sheathed` puts the sword of the same cell in it, else it hangs empty (the
## sword is in the hand). Returns the scabbard node, or null when the rig has no hips.
static func gird(rig: SharedCharacterRig, cell: String, sheathed: bool) -> Node3D:
	var skeleton := rig.skeleton()
	var hips := skeleton.find_bone("hips") if skeleton != null else -1
	if hips < 0:
		return null
	var rest := skeleton.get_bone_global_rest(hips)
	var level := EquipmentVariant.prestige(cell)
	var belt_y := rest.origin.y + BELT_RAISE
	var ring := _girth(rig, skeleton, belt_y)
	# The slot follows the hips bone; undo its rest so children are placed in skeleton space.
	var root := Node3D.new()
	root.name = "SwordBelt"
	root.transform = rest.affine_inverse()
	var centre := Vector3(ring.position.x, belt_y, ring.position.y)
	var radii := Vector2(ring.size.x, ring.size.y)
	root.add_child(_belt(centre, radii, level))
	var skirt := _girth(rig, skeleton, belt_y - SKIRT_PROBE)
	var scabbard := _variant(SCABBARD_DIR, "scabbard", cell, SCABBARD_BASE)
	scabbard.name = "Scabbard"
	scabbard.transform = _hang(centre, radii, _splay(ring, skirt))
	root.add_child(scabbard)
	if sheathed:
		var sword := _variant(SWORD_DIR, "arming_sword", cell, SWORD_BASE)
		sword.name = "Sword"
		var cross := sword.get_node_or_null(^"socket_cross") as Node3D
		# Point down, the cross resting on the mouth: the sword's +Y turned onto -Y.
		var lift := cross.position.y if cross != null else 0.07
		sword.transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0.0, lift, 0.0))
		scabbard.add_child(sword)
	rig.equip_node(SLOT, root)
	return scabbard


## Variant instance `<family>_<cell>`, the nearest shipped cell or the base with the
## stand-in wear finish (EquipmentVariant), tagged with the requested variant id.
static func _variant(dir: String, family: String, cell: String, base: String) -> Node3D:
	var shipped := EquipmentVariant.nearest_cell(dir, family, cell)
	var scene := (
		(
			EquipmentVariant.variant_scene(dir, family, shipped)
			if not shipped.is_empty()
			else load(base)
		)
		as PackedScene
	)
	var node := scene.instantiate() as Node3D
	var wanted := cell if EquipmentVariant.is_cell(cell) else EquipmentVariant.BASE_CELL
	node.set_meta(&"variant", "%s_%s" % [family, wanted])
	if shipped != wanted:
		EquipmentVariant.finish(node, wanted)
	return node


## Ellipse of the belt in skeleton space: position = centre (x, z), size = radii (x, z),
## from the widest visible body or garment mesh in a band round `belt_y`, plus the ease.
static func _girth(rig: SharedCharacterRig, skeleton: Skeleton3D, belt_y: float) -> Rect2:
	var lo := Vector2(-0.16, -0.12)
	var hi := Vector2(0.16, 0.14)
	var to_skeleton := _to_rig(skeleton, rig).affine_inverse()
	for node: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.visible or _is_prop(mesh_instance, rig):
			continue
		var xf := to_skeleton * _to_rig(mesh_instance, rig)
		var key := "%d:%s:%.3f" % [mesh_instance.mesh.get_instance_id(), xf, belt_y]
		if not _extents.has(key):
			_extents[key] = _band_extents(mesh_instance.mesh, xf, belt_y)
		var band: Array = _extents[key]
		if band.is_empty():
			continue
		lo = Vector2(minf(lo.x, band[0].x), minf(lo.y, band[0].y))
		hi = Vector2(maxf(hi.x, band[1].x), maxf(hi.y, band[1].y))
	var radii := (hi - lo) * 0.5 + Vector2(EASE, EASE)
	return Rect2((hi + lo) * 0.5, radii)


## [lo, hi] (x, z) of the mesh's bind-pose vertices within BAND of `belt_y`, [] when none.
## The bind pose holds the arms out at shoulder height, so only a stray hand is guarded
## against (|x| > 0.5); a flared skirt is wide and must count.
static func _band_extents(mesh: Mesh, xf: Transform3D, belt_y: float) -> Array:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for surface in mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for v: Vector3 in vertices:
			var p := xf * v
			if absf(p.y - belt_y) > BAND or absf(p.x) > 0.5:
				continue
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	return [] if lo.x == INF else [lo, hi]


## True for meshes of mounted props (weapons, lantern, a previous belt): they hang off
## bone attachments and are not part of the body the belt goes round.
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


## Outward swing of the chape that clears the skirt: how far the skirt's ellipse stands
## out beyond the belt's at HANG_ANGLE, over SKIRT_PROBE of drop, plus 2 cm.
static func _splay(belt: Rect2, skirt: Rect2) -> float:
	var side := Vector2(sin(HANG_ANGLE), cos(HANG_ANGLE))
	var at_belt := belt.position + belt.size * side
	var at_skirt := skirt.position + skirt.size * side
	var out := (at_skirt - at_belt).dot(side) + 0.02
	return clampf(atan2(out, SKIRT_PROBE), SPLAY, SPLAY_MAX)


## Scabbard transform in skeleton space: its lacing on the belt at HANG_ANGLE, flat face
## out from the hip, the mouth forward and up, the chape back and `splay` out.
static func _hang(centre: Vector3, radii: Vector2, splay: float) -> Transform3D:
	var side := Vector3(sin(HANG_ANGLE), 0.0, cos(HANG_ANGLE))
	var on_belt := centre + Vector3(radii.x * side.x, 0.0, radii.y * side.z)
	# Outward normal of the ellipse at that point.
	var out := Vector3(side.x / radii.x, 0.0, side.z / radii.y).normalized()
	# The rig faces +Z, so its back is Godot FORWARD (-Z).
	var down := (
		(Vector3.DOWN * cos(TILT_BACK) + Vector3.FORWARD * sin(TILT_BACK) + out * sin(splay))
		. normalized()
	)
	var y := -down
	var z := (out - y * out.dot(y)).normalized()
	var basis := Basis(y.cross(z), y, z)
	# Scabbard origin is its mouth; the lacing below it rests on the belt's outer face.
	var origin := (
		on_belt + out * (BELT_THICK + 0.016) - basis * Vector3(0.0, -LACE_BELOW_MOUTH, 0.0)
	)
	return Transform3D(basis, origin)


## Belt: an elliptic leather band at `centre` with `radii`, a buckle at the front and the
## free end hanging from it.
static func _belt(centre: Vector3, radii: Vector2, level: int) -> Node3D:
	var belt := Node3D.new()
	belt.name = "Belt"
	var band := MeshInstance3D.new()
	band.name = "Band"
	band.mesh = _band_mesh(radii)
	band.material_override = _material("leather_%d" % level, LEATHER[level], 0.0, 0.8)
	band.position = centre
	belt.add_child(band)
	var front := centre + Vector3(0.0, 0.0, radii.y + BELT_THICK)
	var buckle := MeshInstance3D.new()
	buckle.name = "Buckle"
	var frame := BoxMesh.new()
	frame.size = Vector3(0.04, BELT_WIDTH + 0.012, 0.008)
	buckle.mesh = frame
	buckle.material_override = _material("buckle_%d" % level, BUCKLE[level], 0.8, 0.45)
	buckle.position = front + Vector3(0.0, 0.0, 0.003)
	belt.add_child(buckle)
	var tail := MeshInstance3D.new()
	tail.name = "Tail"
	var strap := BoxMesh.new()
	strap.size = Vector3(BELT_WIDTH * 0.85, TAIL[level], BELT_THICK)
	tail.mesh = strap
	tail.material_override = band.material_override
	# Tucked under the belt beside the buckle and hanging down the front.
	tail.position = front + Vector3(-0.035, -TAIL[level] * 0.5 + BELT_WIDTH * 0.3, 0.006)
	belt.add_child(tail)
	return belt


static func _band_mesh(radii: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := BELT_WIDTH * 0.5
	for i in SEGMENTS:
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		for face in [[radii, 1.0], [radii - Vector2(BELT_THICK, BELT_THICK), -1.0]]:
			var r: Vector2 = face[0]
			var sgn: float = face[1]
			var p0 := Vector3(r.x * sin(a0), 0.0, r.y * cos(a0))
			var p1 := Vector3(r.x * sin(a1), 0.0, r.y * cos(a1))
			var n0 := Vector3(sin(a0) / r.x, 0.0, cos(a0) / r.y).normalized() * sgn
			var n1 := Vector3(sin(a1) / r.x, 0.0, cos(a1) / r.y).normalized() * sgn
			var quad := [
				[p0 + Vector3.UP * half, n0],
				[p0 - Vector3.UP * half, n0],
				[p1 - Vector3.UP * half, n1],
				[p1 + Vector3.UP * half, n1],
			]
			var order := [0, 1, 2, 0, 2, 3] if sgn > 0.0 else [0, 2, 1, 0, 3, 2]
			for k: int in order:
				st.set_normal(quad[k][1])
				st.set_uv(Vector2(float(i) / SEGMENTS, 0.0 if k < 2 else 1.0))
				st.add_vertex(quad[k][0])
	return st.commit()


static func _material(
	key: String, colour: Color, metallic: float, roughness: float
) -> StandardMaterial3D:
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.resource_name = "sword_belt_" + key
		material.albedo_color = colour
		material.metallic = metallic
		material.roughness = roughness
		# The band is a thin shell seen from both sides as the hips turn.
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = material
	return _materials[key]
