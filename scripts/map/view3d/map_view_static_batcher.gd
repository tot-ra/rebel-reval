class_name MapViewStaticBatcher
extends RefCounted

## Draw-call batching for procedurally built, never-animated view geometry.
##
## WHY: building and prop builders emit one MeshInstance3D per architectural
## detail (bargeboards, slits, chimney courses, gallery ribs). A district like
## the workers quarter reaches ~18k mesh instances, which the renderer submits
## as ~16k draw calls per frame plus a second pass for shadows. That is a pure
## CPU submission cost with no visual benefit, because the details never move.
##
## WHAT: collects static leaf MeshInstance3D nodes under a subtree, bakes their
## transforms into one merged mesh per material, and replaces them with a single
## instance. Nodes that carry a script, have children, are hidden, or are named
## in the preserve set are left untouched, so animated dressing, interactables,
## and structure lookups by node name keep working.

## Names that other systems and tests resolve directly on a building node.
const PRESERVED_NAMES := {
	"Walls": true,
	"Roof": true,
	"Door": true,
	"ChimneySmoke": true,
	"WindowLights": true,
}

## Opt-out contract for meshes a sibling controller mutates at runtime (window
## glow panes, forge embers). Such a mesh must survive as its own node because
## its owner keeps a direct reference to it.
const DYNAMIC_GEOMETRY_GROUP := &"view_dynamic_geometry"

## A group of one saves nothing and would only cost the scene a node lookup that
## other systems or tests may rely on.
const MIN_GROUP_SIZE := 2


## Merges the static leaf meshes below `root`. Returns the number of removed
## mesh instances so callers can report the saving.
static func merge(root: Node3D, preserved_names: Dictionary = PRESERVED_NAMES) -> int:
	var groups: Dictionary = {}
	_collect(root, Transform3D.IDENTITY, preserved_names, groups)
	var removed := 0
	var index := 0
	var surfaces_merged: Dictionary = {}
	for key in groups:
		var group: Dictionary = groups[key]
		var entries: Array = group["entries"]
		if entries.size() < MIN_GROUP_SIZE:
			continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for entry in entries:
			surface.append_from(entry["mesh"], int(entry["surface"]), entry["transform"])
			var node: MeshInstance3D = entry["node"]
			var node_id: int = node.get_instance_id()
			if not surfaces_merged.has(node_id):
				surfaces_merged[node_id] = {
					"node": node,
					"surfaces": {},
				}
			surfaces_merged[node_id]["surfaces"][int(entry["surface"])] = true
		var merged := MeshInstance3D.new()
		merged.name = "Batched%02d" % index
		index += 1
		merged.mesh = surface.commit()
		merged.material_override = group["material"]
		merged.cast_shadow = group["cast_shadow"]
		root.add_child(merged)
	for node_id in surfaces_merged:
		var record: Dictionary = surfaces_merged[node_id]
		var source := record["node"] as MeshInstance3D
		if not _node_fully_merged(source, record["surfaces"]):
			# Baking only some surfaces duplicates geometry on the source node.
			continue
		source.get_parent().remove_child(source)
		source.queue_free()
		removed += 1
	return removed


static func _node_fully_merged(node: MeshInstance3D, merged_surfaces: Dictionary) -> bool:
	var mesh: Mesh = node.mesh
	for surface_index in mesh.get_surface_count():
		if not merged_surfaces.has(surface_index):
			return false
	return true


## Backdrop districts are pure silhouette: they never need animated dressing,
## point lights, or shadow casting, all of which cost per-frame work far from
## the camera.
static func strip_backdrop_dressing(root: Node3D) -> void:
	for child in root.get_children():
		if child is GPUParticles3D or child is CPUParticles3D or child is Light3D:
			root.remove_child(child)
			child.queue_free()
			continue
		if child is GeometryInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if child is Node3D:
			strip_backdrop_dressing(child)


## Architectural trim (bargeboards, slits, gallery ribs, roof battens) is drawn
## again for every shadow cascade, yet its shadow is a sliver nobody reads. The
## shadow pass was ~8k of the district's ~11.6k draw calls; dropping slim and
## small casters removes most of it without touching the structural silhouette.
const SHADOW_MIN_MEDIAN_EXTENT := 0.35
const SHADOW_MIN_LONGEST_EXTENT := 0.6


static func trim_small_shadow_casters(root: Node3D) -> int:
	return _trim(root, root.transform.basis.get_scale())


static func _trim(node: Node3D, accumulated_scale: Vector3) -> int:
	var trimmed := 0
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null \
			and mesh_instance.mesh != null \
			and mesh_instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		var size: Vector3 = mesh_instance.get_aabb().size * accumulated_scale
		var extents := [absf(size.x), absf(size.y), absf(size.z)]
		extents.sort()
		if extents[1] < SHADOW_MIN_MEDIAN_EXTENT or extents[2] < SHADOW_MIN_LONGEST_EXTENT:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			trimmed += 1
	for child in node.get_children():
		var child_3d := child as Node3D
		if child_3d != null:
			trimmed += _trim(child_3d, accumulated_scale * child_3d.transform.basis.get_scale())
	return trimmed


static func _collect(
	node: Node3D,
	accumulated: Transform3D,
	preserved_names: Dictionary,
	groups: Dictionary
) -> void:
	for child in node.get_children():
		var child_3d := child as Node3D
		if child_3d == null:
			continue
		# A scripted node owns its own subtree and may rebuild or animate it.
		if child_3d.get_script() != null or preserved_names.has(child_3d.name):
			continue
		var child_transform := accumulated * child_3d.transform
		if child_3d.get_child_count() > 0:
			_collect(child_3d, child_transform, preserved_names, groups)
			continue
		if not _is_mergeable(child_3d, preserved_names):
			continue
		var mesh_instance := child_3d as MeshInstance3D
		var mesh: Mesh = mesh_instance.mesh
		for surface_index in mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface_index)
			var key := "%s|%d" % [
				material.get_rid() if material != null else RID(),
				int(mesh_instance.cast_shadow),
			]
			if not groups.has(key):
				groups[key] = {
					"material": material,
					"cast_shadow": mesh_instance.cast_shadow,
					"entries": [],
				}
			groups[key]["entries"].append({
				"node": mesh_instance,
				"mesh": mesh,
				"surface": surface_index,
				"transform": child_transform,
			})


static func _is_mergeable(node: Node3D, preserved_names: Dictionary) -> bool:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null:
		return false
	if mesh_instance.mesh == null or not mesh_instance.visible:
		return false
	# Scripted instances animate themselves; named nodes are resolved elsewhere.
	if mesh_instance.get_script() != null or preserved_names.has(mesh_instance.name):
		return false
	if mesh_instance.is_in_group(DYNAMIC_GEOMETRY_GROUP):
		return false
	if mesh_instance.skeleton != NodePath("") and mesh_instance.get_skin_reference() != null:
		return false
	# Range-culled instances already avoid submission when far away.
	if mesh_instance.visibility_range_end > 0.0:
		return false
	if mesh_instance.mesh.get_surface_count() > 1:
		return false
	return _all_surfaces_mergeable(mesh_instance)


## Object-space triplanar samples mesh-local vertex position. Baking instance
## transforms into one merged mesh retiles every piece from the parent origin,
## which reads as stretched or swimming masonry on walls and gate jambs.
static func _material_breaks_when_merged(material: Material) -> bool:
	var standard := material as StandardMaterial3D
	if standard == null:
		return false
	return standard.uv1_triplanar and not standard.uv1_world_triplanar


static func _all_surfaces_mergeable(mesh_instance: MeshInstance3D) -> bool:
	var mesh: Mesh = mesh_instance.mesh
	for surface_index in mesh.get_surface_count():
		if _material_breaks_when_merged(mesh_instance.get_active_material(surface_index)):
			return false
	return true
