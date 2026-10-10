class_name CityTreeLod
extends Node3D

## Per-tree crown LOD for the seamless city (R-712 VEG pass).
##
## Far: the shared big-card crowns (cheap, the right mass from a distance) in
## the chunked MultiMeshes built by CityVegetationBuilder.
## Near: MapViewTreeMeshes.city_canopy_near_mesh, real-size leaf clusters and
## needle sprays, for the trees within NEAR_ENTER metres of the camera.
##
## Why per tree and not per chunk: the vegetation chunks are 96 m, so a chunk
## visibility range would switch dozens of trees at once, and a camera standing
## at a chunk edge would see the far crown on a tree two metres away. Here a
## tree entering the radius has its far instance collapsed to zero scale and is
## added to a small per-species near MultiMesh; leaving restores it. Hysteresis
## (NEAR_ENTER / NEAR_EXIT) stops trees at the edge from flickering.
##
## Macro: conifers within MACRO_ENTER metres swap the near crown for
## MapViewTreeMeshes.city_canopy_macro_mesh, whose outer needle cards are real
## 3D needle fronds. Those crowns cost ~10x the triangles, so only the few trees
## right beside the camera get them; card size and density match the near crown,
## so the swap changes needle detail, not crown mass.

const NEAR_ENTER := 34.0
const NEAR_EXIT := 42.0
const MACRO_ENTER := 10.0
const MACRO_EXIT := 13.0
const GRID := 32.0
const UPDATE_INTERVAL := 0.15

## Optional fixed viewpoint (captures and tests); otherwise the active camera.
var focus_override := Vector3.INF
## species -> {"world_scale", "shrub"}
var _species: Dictionary = {}
## tree id -> [species, Transform3D, Color, MultiMesh far, int far index]
var _trees: Array = []
## Vector2i grid cell -> Array[int] tree ids
var _grid: Dictionary = {}
var _near: Dictionary = {}
## species -> MultiMeshInstance3D
var _near_nodes: Dictionary = {}
## tree id -> true for trees drawn with the macro crown (a subset of _near)
var _macro: Dictionary = {}
## species -> MultiMeshInstance3D
var _macro_nodes: Dictionary = {}
var _timer := 0.0


func register(
	species: StringName,
	world_scale: float,
	far: MultiMesh,
	transforms: Array[Transform3D],
	colors: Array[Color],
	shrub: bool
) -> void:
	if not _species.has(species):
		_species[species] = {"world_scale": world_scale, "shrub": shrub}
		if MapViewTreeMeshes.has_macro_crown(species):
			# Build the macro (and with it the near) crown now, about a second
			# for spruce, so the first walk up to a conifer does not hitch.
			MapViewTreeMeshes.city_canopy_macro_mesh(species, world_scale)
	for index in transforms.size():
		var id := _trees.size()
		var origin := transforms[index].origin
		_trees.append([species, transforms[index], colors[index], far, index])
		var cell := Vector2i(floori(origin.x / GRID), floori(origin.z / GRID))
		if not _grid.has(cell):
			_grid[cell] = []
		(_grid[cell] as Array).append(id)


func near_count() -> int:
	return _near.size()


func is_near(id: int) -> bool:
	return _near.has(id)


func is_macro(id: int) -> bool:
	return _macro.has(id)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = UPDATE_INTERVAL
	var focus := focus_override
	if focus == Vector3.INF:
		var camera := get_viewport().get_camera_3d() if get_viewport() != null else null
		if camera == null:
			return
		focus = camera.global_position
	update_for(focus)


## Recomputes the near set around `focus` and swaps changed trees. Returns true
## when the set changed.
func update_for(focus: Vector3) -> bool:
	var wanted := {}
	var wanted_macro := {}
	var reach := ceili(NEAR_EXIT / GRID)
	var centre := Vector2i(floori(focus.x / GRID), floori(focus.z / GRID))
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			for id: int in _grid.get(centre + Vector2i(dx, dy), []):
				var origin: Vector3 = (_trees[id][1] as Transform3D).origin
				var d := Vector2(origin.x - focus.x, origin.z - focus.z).length()
				if d < NEAR_ENTER or (_near.has(id) and d < NEAR_EXIT):
					wanted[id] = true
				if (
					MapViewTreeMeshes.has_macro_crown(_trees[id][0])
					and (d < MACRO_ENTER or (_macro.has(id) and d < MACRO_EXIT))
				):
					wanted[id] = true
					wanted_macro[id] = true
	var changed: Dictionary = {}
	for id: int in _macro.keys():
		if not wanted_macro.has(id):
			_macro.erase(id)
			changed[_trees[id][0]] = true
	for id: int in wanted_macro:
		if not _macro.has(id):
			_macro[id] = true
			changed[_trees[id][0]] = true
	for id: int in _near.keys():
		if not wanted.has(id):
			_near.erase(id)
			var tree: Array = _trees[id]
			(tree[3] as MultiMesh).set_instance_transform(tree[4], tree[1])
			changed[tree[0]] = true
	for id: int in wanted:
		if not _near.has(id):
			_near[id] = true
			var tree: Array = _trees[id]
			var hidden := Transform3D(
				Basis.from_scale(Vector3.ZERO), (tree[1] as Transform3D).origin
			)
			(tree[3] as MultiMesh).set_instance_transform(tree[4], hidden)
			changed[tree[0]] = true
	for species: StringName in changed:
		_rebuild_near(species, false)
		_rebuild_near(species, true)
	return not changed.is_empty()


## Rebuilds the species' near (`macro` false: near trees that are not macro) or
## macro MultiMesh.
func _rebuild_near(species: StringName, macro: bool) -> void:
	var nodes := _macro_nodes if macro else _near_nodes
	if nodes.has(species):
		(nodes[species] as Node).queue_free()
		nodes.erase(species)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var ids := _near.keys()
	ids.sort()
	for id: int in ids:
		var tree: Array = _trees[id]
		if tree[0] == species and _macro.has(id) == macro:
			transforms.append(tree[1])
			colors.append(tree[2])
	if transforms.is_empty():
		return
	var info: Dictionary = _species[species]
	var world_scale := float(info["world_scale"])
	var node := MapViewMeshBuilderPrimitives.multi_mesh(
		"Crown%s_%s" % ["Macro" if macro else "Near", species],
		(
			MapViewTreeMeshes.city_canopy_macro_mesh(species, world_scale)
			if macro
			else MapViewTreeMeshes.city_canopy_near_mesh(species, world_scale)
		),
		transforms,
		colors,
		MapViewMaterials.canopy_for_species(MapViewTreeMeshes.base_species(species)),
		Vector3.ZERO,
		true
	)
	# Match far crowns: shader bend exceeds static bounds.
	node.extra_cull_margin = 12.0
	if bool(info["shrub"]):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	nodes[species] = node
