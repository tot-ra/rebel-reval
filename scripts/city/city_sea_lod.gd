class_name CitySeaLod
extends Node3D

## WR-3 camera-centred city sea LOD (docs/SYSTEMS/CITY_SEA.md, LOD; task R-1508).
##
## WHY: the fixed 4 m sea grid was too coarse for the C1 cascade next to the
## camera and wasted vertices on the far sea. The open sea is now drawn by one
## MultiMesh of 16 x 16-quad ring nodes picked per frame by a CDLOD quadtree: node
## level L has vertex spacing base_spacing * 2^L and covers distances from
## ring_range * 2^(L - 1) out. The vertex shader morphs every vertex towards the
## next level by distance (map_view_water.gdshader, _sea_lod_vertex), so levels
## blend without popping and meet without cracks.
##
## The 0.5 m surf band (CityShoreField.build_band) and the 4 m "skirt" cells that
## stitch to it stay static meshes. Rings own every other wet 4 m cell; their
## pixels in cells owned by band, skirt or land are discarded. One RGBA float
## texel per 4 m lattice vertex (bound as sea_depth_map) carries what the shader
## needs: R depth, G signed bed height, B = 1 next to a static cell (forces the
## 4 m spacing on edges shared with the skirt), A = extra levels allowed above the
## 4 m level (no coarse triangle may span a cell the rings do not own) plus
## DRAWN when the cell whose minimum corner is this vertex belongs to the rings.

const WaterMaterials := preload("res://scripts/map/view3d/map_view_water_materials.gd")

## Mirrors SEA_LOD_NODE_QUADS / SEA_LOD_MORPH / SEA_LOD_WEIGHT_SPACING /
## SEA_LOD_DRAWN in map_view_water.gdshader.
const NODE_QUADS := 16
const MORPH := 0.4
const WEIGHT_SPACING := Vector4(1.0, 2.0, 4.0, 8.0)
const DRAWN := 1000.0
## Selection is redone when the camera moved this far (m); below that the
## previous node set and eye stay bound, so a still camera costs nothing.
const RESELECT_DISTANCE := 0.05
const AABB_HALF_HEIGHT := 40.0

var preset: Dictionary = {}
var lattice_origin := Vector2.ZERO
var cell_size := 4.0
## Cell counts; the lattice has one more vertex per axis.
var cells := Vector2i.ZERO
var base_spacing := 1.0
var ring_range := 64.0
## Level whose spacing equals the cell size, and the coarsest level.
var shore_level := 2
var last_level := 6
## 1 where the rings draw the cell, 0 where band, skirt or land own it.
var ring_cells := PackedByteArray()
## 1 where a static sea mesh (band or skirt) owns the cell.
var static_cells := PackedByteArray()
## Chebyshev distance (cells) from each lattice vertex to the nearest cell the
## rings do not own; outside the lattice counts as not owned.
var clearance := PackedInt32Array()
var field: Image
var field_texture: ImageTexture
var eye := Vector3(INF, INF, INF)
## Selected nodes of the last selection: Vector4(node x, node z, level, 2^level).
var nodes: Array[Vector4] = []

var _ring_sat := PackedInt32Array()
## Per level > shore_level: min clearance over each node's closed vertex rect.
var _node_clearance: Dictionary = {}
var _multimesh: MultiMesh
var _instance: MultiMeshInstance3D


## `ring_cells` / `static_cells` are row-major over `cells`; `bed` returns the
## signed ground height at a world xz point.
func configure(
	origin: Vector2, cell: float, size: Vector2i, rings: PackedByteArray,
	statics: PackedByteArray, bed: Callable, tier_preset: Dictionary,
	material: Material
) -> void:
	lattice_origin = origin
	cell_size = cell
	cells = size
	ring_cells = rings
	static_cells = statics
	preset = tier_preset
	base_spacing = float(preset["base_spacing"])
	ring_range = float(preset["ring_range"])
	shore_level = int(round(log(cell_size / base_spacing) / log(2.0)))
	last_level = int(preset["rings"]) - 1
	_build_clearance()
	_build_field(bed)
	_build_ring_sat()
	_build_node_clearance()
	_build_instance(material)
	_apply_uniforms()


func _enter_tree() -> void:
	# The water materials are shared with the district maps; rebind on entry.
	if field_texture != null:
		_apply_uniforms()


func _process(_delta: float) -> void:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera != null:
		update_eye(camera.global_position)


## Reselects the ring nodes for `at` and binds it as the shader's morph eye. The
## selection and the morph use the same eye, so their level choice agrees.
func update_eye(at: Vector3, force := false) -> void:
	if not force and at.distance_to(eye) < RESELECT_DISTANCE:
		return
	eye = at
	nodes = select(at)
	if _multimesh != null:
		if nodes.size() > _multimesh.instance_count:
			_multimesh.instance_count = nodes.size() * 2
		for i in nodes.size():
			var n := nodes[i]
			_multimesh.set_instance_transform(i, Transform3D.IDENTITY)
			_multimesh.set_instance_custom_data(i, Color(n.x, n.y, n.z, n.w))
		_multimesh.visible_instance_count = nodes.size()
	WaterMaterials.set_sea_lod_eye(at)


## CDLOD quadtree selection from the coarsest level down. A node is split when
## part of it is nearer than its level's range (it would need finer vertices),
## or, above the 4 m level, when its triangles could span a cell the rings do not
## own. Nodes without any ring cell are dropped.
func select(at: Vector3) -> Array[Vector4]:
	var out: Array[Vector4] = []
	var root_span := NODE_QUADS * (1 << last_level)
	var lattice_units := Vector2(cells) * _cell_span()
	var roots := Vector2i(
		int(ceil(lattice_units.x / root_span)), int(ceil(lattice_units.y / root_span))
	)
	for z in roots.y:
		for x in roots.x:
			_select_node(Vector2i(x, z), last_level, at, out)
	return out


func _select_node(node: Vector2i, level: int, at: Vector3, out: Array[Vector4]) -> void:
	var span := NODE_QUADS * (1 << level)
	var g0 := Vector2(node) * span
	var c0 := Vector2i((g0 / _cell_span()).floor())
	var c1 := Vector2i(((g0 + Vector2.ONE * span) / _cell_span()).ceil())
	if not _any_ring_cell(c0, c1):
		return
	var split := false
	if level > 0:
		var lo := lattice_origin + g0 * base_spacing
		var hi := lo + Vector2.ONE * span * base_spacing
		var near := Vector2(clampf(at.x, lo.x, hi.x), clampf(at.z, lo.y, hi.y))
		var d := Vector3(near.x, 0.0, near.y).distance_to(at)
		split = d < ring_range * pow(2.0, level - 1)
		if not split and level > shore_level:
			var mins: Dictionary = _node_clearance[level]
			split = int(mins.get(node, 0)) < (1 << (level - shore_level))
	if not split:
		out.append(Vector4(node.x, node.y, level, 1 << level))
		return
	for k in 4:
		_select_node(node * 2 + Vector2i(k & 1, k >> 1), level - 1, at, out)


## Continuous ring level at distance d; mirrors _sea_lod_ring.
static func ring_level(d: float, range_m: float, last: int) -> float:
	var t := d / range_m
	var level := 0.0 if t < 1.0 else floorf(log(t) / log(2.0)) + 1.0
	var outer := range_m * pow(2.0, level)
	var inner := 0.0 if level < 0.5 else outer * 0.5
	var w := MORPH * (outer - inner)
	return minf(level + clampf((d - outer + w) / w, 0.0, 1.0), float(last))


## Vertex spacing (m) of the sea surface at xz around the current eye: 4 m in
## static cells, else the ring morph level (no node snapping; CPU estimate).
func mesh_spacing_at(xz: Vector2) -> float:
	var c := _cell_of(xz)
	if not _ring_cell(c):
		return cell_size
	var level := ring_level(_eye_distance(xz), ring_range, last_level)
	var f := field_at(xz)
	level = maxf(level, float(shore_level) * f.z)
	var v := Vector2i(((xz - lattice_origin) / cell_size).round())
	var cap := float(shore_level + _cap(_clearance_at(v)))
	return base_spacing * pow(2.0, minf(level, minf(cap, float(last_level))))


## (C0, C1) geometry weights at xz; mirrors _sea_lod_weights. CityWaterSurface
## multiplies its CPU height by these so swimmers and the camera ride the mesh.
func displacement_weights(xz: Vector2, mesh_spacing := -1.0) -> Vector2:
	if mesh_spacing < 0.0:
		mesh_spacing = mesh_spacing_at(xz)
	var e := maxf(
		mesh_spacing,
		base_spacing * pow(2.0, ring_level(_eye_distance(xz), ring_range, last_level))
	)
	var c1 := 1.0 if int(preset["displacement_cascades"]) >= 2 else 0.0
	var s := WEIGHT_SPACING
	return Vector2(1.0 - smoothstep(s.z, s.w, e), c1 * (1.0 - smoothstep(s.x, s.y, e)))


## Bilinear field (R depth, G bed, B floor, A cap code) like _sea_lod_field.
func field_at(xz: Vector2) -> Vector4:
	var u := (xz - lattice_origin) / cell_size
	var i0 := Vector2i(u.floor())
	var f := u - u.floor()
	var a := _texel(i0).lerp(_texel(i0 + Vector2i(1, 0)), f.x)
	var b := _texel(i0 + Vector2i(0, 1)).lerp(_texel(i0 + Vector2i(1, 1)), f.x)
	return a.lerp(b, f.y)


func vertex_count() -> int:
	return nodes.size() * (NODE_QUADS + 1) * (NODE_QUADS + 1)


func _apply_uniforms() -> void:
	var lattice := Vector4(lattice_origin.x, lattice_origin.y, cell_size, 1.0)
	var rings := Vector4(base_spacing, ring_range, float(shore_level), float(last_level))
	WaterMaterials.apply_sea_lod(lattice, rings, preset)
	# Texel centres sit on lattice vertices: the rect starts half a cell early.
	var verts := Vector2(cells + Vector2i.ONE)
	WaterMaterials.apply_sea_depth_map(
		field_texture,
		Vector4(
			lattice_origin.x - cell_size * 0.5, lattice_origin.y - cell_size * 0.5,
			verts.x * cell_size, verts.y * cell_size
		)
	)
	if eye.is_finite():
		WaterMaterials.set_sea_lod_eye(eye)


func _cell_span() -> float:
	return cell_size / base_spacing


func _eye_distance(xz: Vector2) -> float:
	return Vector3(xz.x, 0.0, xz.y).distance_to(eye) if eye.is_finite() else 0.0


func _cell_of(xz: Vector2) -> Vector2i:
	return Vector2i(((xz - lattice_origin) / cell_size).floor())


func _ring_cell(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= cells.x or c.y >= cells.y:
		return false
	return ring_cells[c.y * cells.x + c.x] == 1


func _static_cell(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= cells.x or c.y >= cells.y:
		return false
	return static_cells[c.y * cells.x + c.x] == 1


func _clearance_at(v: Vector2i) -> int:
	if v.x < 0 or v.y < 0 or v.x > cells.x or v.y > cells.y:
		return 0
	return clearance[v.y * (cells.x + 1) + v.x]


## Extra levels above the 4 m level at a vertex with clearance d: a level
## shore + a triangle spans 2^a cells, so it needs d >= 2^a.
static func _cap(d: int) -> int:
	if d < 1:
		return 0
	return int(floor(log(float(d)) / log(2.0) + 0.000001))


func _texel(i: Vector2i) -> Vector4:
	if i.x < 0 or i.y < 0 or i.x > cells.x or i.y > cells.y:
		return Vector4(0.0, 0.0, 1.0, 0.0)
	var c := field.get_pixel(i.x, i.y)
	return Vector4(c.r, c.g, c.b, c.a)


## Chebyshev distance transform (8-connected BFS) from vertices that touch a
## cell the rings do not own.
func _build_clearance() -> void:
	var w := cells.x + 1
	var h := cells.y + 1
	clearance = PackedInt32Array()
	clearance.resize(w * h)
	clearance.fill(-1)
	var queue := PackedInt32Array()
	for j in h:
		for i in w:
			var touches := false
			for k in 4:
				if not _ring_cell(Vector2i(i - 1 + (k & 1), j - 1 + (k >> 1))):
					touches = true
					break
			if touches:
				clearance[j * w + i] = 0
				queue.append(j * w + i)
	var head := 0
	while head < queue.size():
		var idx := queue[head]
		head += 1
		var i := idx % w
		var j := idx / w
		for dj in range(-1, 2):
			for di in range(-1, 2):
				var ni := i + di
				var nj := j + dj
				if ni < 0 or nj < 0 or ni >= w or nj >= h:
					continue
				var n := nj * w + ni
				if clearance[n] < 0:
					clearance[n] = clearance[idx] + 1
					queue.append(n)


func _build_field(bed: Callable) -> void:
	var w := cells.x + 1
	var h := cells.y + 1
	field = Image.create_empty(w, h, false, Image.FORMAT_RGBAF)
	for j in h:
		for i in w:
			var p := lattice_origin + Vector2(i, j) * cell_size
			var ground: float = bed.call(p)
			var floor_weight := 0.0
			for k in 4:
				if _static_cell(Vector2i(i - 1 + (k & 1), j - 1 + (k >> 1))):
					floor_weight = 1.0
					break
			var code := float(_cap(clearance[j * w + i]))
			if _ring_cell(Vector2i(i, j)):
				code += DRAWN
			field.set_pixel(i, j, Color(maxf(-ground, 0.0), ground, floor_weight, code))
	field_texture = ImageTexture.create_from_image(field)


## Summed-area table of ring cells for O(1) "any ring cell in this rect".
func _build_ring_sat() -> void:
	var w := cells.x + 1
	_ring_sat = PackedInt32Array()
	_ring_sat.resize(w * (cells.y + 1))
	for j in cells.y:
		var row := 0
		for i in cells.x:
			row += ring_cells[j * cells.x + i]
			_ring_sat[(j + 1) * w + i + 1] = _ring_sat[j * w + i + 1] + row


func _any_ring_cell(c0: Vector2i, c1: Vector2i) -> bool:
	var a := Vector2i(clampi(c0.x, 0, cells.x), clampi(c0.y, 0, cells.y))
	var b := Vector2i(clampi(c1.x, 0, cells.x), clampi(c1.y, 0, cells.y))
	if a.x >= b.x or a.y >= b.y:
		return false
	var w := cells.x + 1
	return (
		_ring_sat[b.y * w + b.x] - _ring_sat[a.y * w + b.x]
		- _ring_sat[b.y * w + a.x] + _ring_sat[a.y * w + a.x]
	) > 0


## Min clearance over each node's closed vertex rect for levels above the 4 m
## level. Children's closed rects tile the parent's closed rect, so each level is
## the min of its four children.
func _build_node_clearance() -> void:
	_node_clearance.clear()
	if last_level <= shore_level:
		return
	var level := shore_level + 1
	var node_cells := NODE_QUADS << (level - shore_level)
	var mins := {}
	var count := Vector2i(
		int(ceil(float(cells.x) / node_cells)), int(ceil(float(cells.y) / node_cells))
	)
	for nz in count.y:
		for nx in count.x:
			var best := 1 << 30
			for j in range(nz * node_cells, nz * node_cells + node_cells + 1):
				for i in range(nx * node_cells, nx * node_cells + node_cells + 1):
					best = mini(best, _clearance_at(Vector2i(i, j)))
			mins[Vector2i(nx, nz)] = best
	_node_clearance[level] = mins
	for upper in range(level + 1, last_level + 1):
		var parent := {}
		for child: Vector2i in _node_clearance[upper - 1]:
			var key := Vector2i(child.x >> 1, child.y >> 1)
			parent[key] = mini(int(parent.get(key, 1 << 30)), int(_node_clearance[upper - 1][child]))
		_node_clearance[upper] = parent


func _build_instance(material: Material) -> void:
	var mesh := _node_mesh()
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_custom_data = true
	_multimesh.mesh = mesh
	_multimesh.instance_count = 256
	_multimesh.visible_instance_count = 0
	_instance = MultiMeshInstance3D.new()
	_instance.name = "SeaRings"
	_instance.multimesh = _multimesh
	_instance.material_override = material
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instance.set_instance_shader_parameter("sea_physical_depth", true)
	_instance.set_instance_shader_parameter("sea_lod", true)
	# Vertices are placed in world space by the shader; cull against the lattice.
	var extent := Vector2(cells) * cell_size
	_instance.custom_aabb = AABB(
		Vector3(lattice_origin.x, -AABB_HALF_HEIGHT, lattice_origin.y),
		Vector3(extent.x, AABB_HALF_HEIGHT * 2.0, extent.y)
	)
	add_child(_instance)


## One node: (NODE_QUADS + 1)^2 vertices whose x/z hold the grid index. The
## diagonal and clockwise top faces match the static sea grid.
static func _node_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var n := NODE_QUADS + 1
	for j in n:
		for i in n:
			verts.append(Vector3(i, 0.0, j))
			normals.append(Vector3.UP)
	for j in NODE_QUADS:
		for i in NODE_QUADS:
			var a := j * n + i
			var quad := [a, a + 1, a + n + 1, a + n]
			for k: int in [0, 1, 2, 0, 2, 3]:
				indices.append(quad[k])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
