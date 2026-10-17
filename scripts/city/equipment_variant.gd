extends RefCounted

## Prestige and wear variant cells of equipment (docs/SYSTEMS/EQUIPMENT_VARIANTS.md, R-2004).
## A cell is "p<prestige>_w<wear>" (p1 munition, p2 burgher or lord's issue, p3 noble;
## w0 new, w1 used, w2 battered), chosen by the census rules in tools/city/citizen_wardrobe.py.
## A variant id is "<family>_<cell>", the file stem of its GLB. When a cell has no file yet,
## code falls back to the family's base item and, for wear other than w1, gives it a stand-in
## finish (cleaner or grimier materials) so a row of guards still differs.
## Preloaded, not a global class: `const EquipmentVariant := preload(...)`.

const BASE_CELL := "p1_w1"
const _CELL_PREFIXES := ["p1", "p2", "p3"]

## Variant path or the fallback -> PackedScene (null when the file is missing).
static var _scenes: Dictionary = {}
## Source material -> {wear: finished duplicate}, shared by every item.
static var _finished: Dictionary = {}


## [layer, cell] of a wear entry ("kettle_hat@p1_w2"); cell "" when the entry has none.
static func split(entry: String) -> PackedStringArray:
	var at := entry.find("@")
	if at < 0:
		return PackedStringArray([entry, ""])
	return PackedStringArray([entry.substr(0, at), entry.substr(at + 1)])


static func is_cell(cell: String) -> bool:
	return (
		cell.length() == 5
		and String(cell.substr(0, 2)) in _CELL_PREFIXES
		and cell.substr(2, 2) == "_w"
		and cell[4] in ["0", "1", "2"]
	)


## Wear 0..2 of a cell; 1 (used) for an empty or malformed cell.
static func wear(cell: String) -> int:
	return int(cell[4]) if is_cell(cell) else 1


static func prestige(cell: String) -> int:
	return int(cell[1]) if is_cell(cell) else 1


## The variant's own scene `<dir>/<family>_<cell>.glb`, or null when it is not shipped.
static func variant_scene(dir: String, family: String, cell: String) -> PackedScene:
	if not is_cell(cell):
		return null
	return _load("%s/%s_%s.glb" % [dir, family, cell])


## The shipped cell nearest to `cell` within its prestige: the cell itself, else the
## nearest wear (newer first on a tie), else "" (use the family's base item). A burgher's
## used sword is then his new one with the stand-in finish, not the sergeant's munition.
static func nearest_cell(dir: String, family: String, cell: String) -> String:
	if not is_cell(cell):
		return ""
	if variant_scene(dir, family, cell) != null:
		return cell
	var level := wear(cell)
	for step in [1, 2]:
		for other in [level - step, level + step]:
			var near := "%s_w%d" % [cell.substr(0, 2), other]
			if other >= 0 and other <= 2 and variant_scene(dir, family, near) != null:
				return near
	return ""


static func _load(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[path]


## Stand-in wear finish for an item mounted from its fallback: every StandardMaterial
## surface under `root` gets a shared duplicate, brighter and smoother for w0, darker,
## rougher and (on metal) rust-browned for w2. w1 is the base look and changes nothing.
static func finish(root: Node, cell: String) -> void:
	var level := wear(cell)
	if root == null or level == 1:
		return
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node: Node in meshes:
		finish_mesh(node as MeshInstance3D, level)


## Finishes the surfaces of one mesh. A ShaderMaterial override (woven cloth, rig shaders)
## is left alone. A StandardMaterial override is the per-mount duplicate that
## SharedCharacterRig.equip_garment made for this very garment, so it is worn in place
## (once: a meta mark makes a second weave a no-op); bare surfaces of a rigid prop get a
## duplicate shared by every item of that material and wear.
static func finish_mesh(mesh_instance: MeshInstance3D, level: int) -> void:
	if mesh_instance == null or mesh_instance.mesh == null or level == 1:
		return
	for surface in mesh_instance.mesh.get_surface_count():
		var current := mesh_instance.get_surface_override_material(surface)
		if current is ShaderMaterial:
			continue
		if current is BaseMaterial3D:
			if not current.has_meta(&"variant_wear"):
				_wear(current as BaseMaterial3D, level)
			continue
		var source := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
		if source == null:
			continue
		mesh_instance.set_surface_override_material(surface, finished_material(source, level))


static func finished_material(source: BaseMaterial3D, level: int) -> BaseMaterial3D:
	var by_wear: Dictionary = _finished.get_or_add(source, {})
	if by_wear.has(level):
		return by_wear[level]
	var material := source.duplicate() as BaseMaterial3D
	# Keep the name: dye rules and tests match materials by it.
	material.resource_name = source.resource_name
	_wear(material, level)
	by_wear[level] = material
	return material


## Wears `material` in place: brighter and smoother for w0; darker, rougher and (on
## metal) rust-browned for w2. `roughness` multiplies the ORM texture when there is one,
## so it is scaled, not offset.
static func _wear(material: BaseMaterial3D, level: int) -> void:
	material.set_meta(&"variant_wear", level)
	var colour := material.albedo_color
	if level == 0:
		material.albedo_color = Color(colour.r * 1.1, colour.g * 1.1, colour.b * 1.1, colour.a)
		material.roughness *= 0.8
		return
	var grimed := Color(colour.r * 0.68, colour.g * 0.66, colour.b * 0.62, colour.a)
	if material.metallic > 0.3:
		# Battered iron: brown rust bloom and far less bare metal (a dull, scaly surface).
		grimed = grimed.lerp(Color(0.34, 0.2, 0.11, colour.a), 0.5)
		material.metallic *= 0.5
	material.albedo_color = grimed
	material.roughness = minf(1.0, material.roughness * 1.25 + 0.1)
