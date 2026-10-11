class_name CogModel
extends RefCounted

## A Hanseatic trading cog in true metres, built from CogHull (lofted clinker
## hull), CogInterior (deck, cabins, hold well, fittings) and CogRig (mast, sail,
## ropes, rudder). The node origin is the waterline amidships, +X is the bow; the
## cog sits at its own draft, no rescale. Docs: docs/SYSTEMS/SHIPS.md.
##
## Meshes are merged per material (hull, timber, iron, rope, sail, rudder), so one
## cog is about ten draw calls.

const DECK_Y := CogHull.DECK_Y
## Wind-filled sail on a ship under way; furled at anchor.
const SAIL_SET := true
const SAIL_FURLED := false

static var _wood: StandardMaterial3D
static var _iron: StandardMaterial3D
static var _canvas: StandardMaterial3D


static func wood_material() -> StandardMaterial3D:
	if _wood == null:
		_wood = MapViewMaterials.hewn_timber(true, 1).duplicate() as StandardMaterial3D
		_wood.albedo_color = Color(0.62, 0.52, 0.42)
		_wood.vertex_color_use_as_albedo = true
		_wood.cull_mode = BaseMaterial3D.CULL_BACK
		_wood.roughness = 0.88
	return _wood


static func iron_material() -> StandardMaterial3D:
	if _iron == null:
		_iron = StandardMaterial3D.new()
		_iron.vertex_color_use_as_albedo = true
		_iron.albedo_color = Color.WHITE
		_iron.metallic = 0.45
		_iron.roughness = 0.62
	return _iron


static func canvas_material() -> StandardMaterial3D:
	if _canvas == null:
		_canvas = StandardMaterial3D.new()
		_canvas.vertex_color_use_as_albedo = true
		_canvas.roughness = 0.95
		_canvas.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _canvas


## Standing height at hull-local (x, z), or NAN off the decks and rooms.
static func walk_height(x: float, z: float) -> float:
	return CogInterior.walk_height(x, z)


## A hull node. `sail_set` fills the sail from the wind (ship under way);
## otherwise the sail is furled on the yard. `anchored` runs a cable out of the hawse.
static func build(
	faction_id: StringName = FactionHeraldry.HANSEATIC, sail_set := false, anchored := true
) -> Node3D:
	var root := Node3D.new()
	root.name = "Cog"
	var hull := CogParts.new()
	CogHull.add_outer(hull)
	CogHull.add_inner(hull)
	_add_mesh(root, "Hull", hull, wood_material())

	var timber := CogParts.new()
	var iron := CogParts.new()
	var ropes := CogParts.new()
	CogInterior.add_all(timber, iron)
	CogRig.add_all(timber, iron, ropes, sail_set, anchored)
	_add_mesh(root, "Timber", timber, wood_material())
	_add_mesh(root, "Ironwork", iron, iron_material())
	var rope_mesh := _add_mesh(root, "Rigging", ropes, CogRig.rope_material())
	if rope_mesh != null:
		# The shader sags and bellies ropes beyond their rest bounds.
		rope_mesh.extra_cull_margin = 4.0

	if sail_set:
		var sail := MeshInstance3D.new()
		sail.name = "Sail"
		sail.mesh = CogRig.sail_mesh()
		sail.material_override = CogRig.sail_material()
		sail.extra_cull_margin = 4.0
		sail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(sail)
	else:
		var furled := CogParts.new()
		CogRig.furled_sail(furled)
		_add_mesh(root, "FurledSail", furled, canvas_material())

	_add_rudder(root)
	if FactionHeraldry.shows_flag(faction_id):
		_add_pennant(root, faction_id)
	return root


static func _add_mesh(
	root: Node3D, node_name: String, parts: CogParts, material: Material
) -> MeshInstance3D:
	var mesh := parts.commit()
	if mesh == null:
		return null
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	root.add_child(instance)
	return instance


## The rudder hangs on the raked sternpost: RudderPivot tilts to the post, its
## "Rudder" child yaws about the post axis (the helm), the Tiller follows it into the cabin.
static func _add_rudder(root: Node3D) -> void:
	var pivot := Node3D.new()
	pivot.name = "RudderPivot"
	pivot.position = CogRig.rudder_pivot_position()
	pivot.rotation.z = CogRig.rudder_rake()
	root.add_child(pivot)
	var rudder := Node3D.new()
	rudder.name = "Rudder"
	pivot.add_child(rudder)
	var blade := CogParts.new()
	var blade_iron := CogParts.new()
	var tiller := CogParts.new()
	CogRig.add_rudder(blade, blade_iron, tiller)
	_add_mesh(rudder, "Blade", blade, wood_material())
	_add_mesh(rudder, "BladeIron", blade_iron, iron_material())
	var tiller_node := Node3D.new()
	tiller_node.name = "Tiller"
	# Undo the post rake so the tiller lies level in the cabin, at the rudder head.
	tiller_node.position = Vector3(0.0, CogRig.pintle_heights()[3] + 0.5, 0.0)
	tiller_node.rotation.z = -CogRig.rudder_rake()
	rudder.add_child(tiller_node)
	_add_mesh(tiller_node, "TillerBar", tiller, wood_material())


static func _add_pennant(root: Node3D, faction_id: StringName) -> void:
	var staff := CogParts.new()
	staff.tube(
		Vector3(CogRig.MAST_X, CogRig.MAST_TOP_Y, 0),
		Vector3(CogRig.MAST_X, CogRig.MAST_TOP_Y + 1.0, 0),
		0.03,
		0.02,
		5,
		CogInterior.DARK
	)
	_add_mesh(root, "PennantStaff", staff, wood_material())
	var pennant := MeshInstance3D.new()
	pennant.name = "MastheadPennant"
	pennant.mesh = FactionHeraldry.pennant_mesh(faction_id)
	pennant.position = Vector3(CogRig.MAST_X, CogRig.MAST_TOP_Y + 1.3, 0)
	pennant.scale = Vector3.ONE * 1.8
	pennant.set_meta(&"faction", faction_id)
	pennant.material_override = MapViewMaterials.flag_cloth()
	pennant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pennant)


## The Rudder node of a built cog (for helm animation), or null.
static func rudder_of(cog: Node3D) -> Node3D:
	return cog.get_node_or_null("RudderPivot/Rudder") as Node3D
