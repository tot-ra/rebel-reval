class_name CityTerrainBuilder
extends RefCounted

## Builds the continuous city ground as square chunks of the plan heightfield.
## Near chunks are full resolution; one coarse mesh covers the whole plan for
## distance, switched by GeometryInstance3D visibility ranges (no seams: the
## coarse mesh samples the same grid and sits a hair lower).

const SHADER := preload("res://scripts/city/city_ground.gdshader")
const CHUNK_CELLS := 48
const NEAR_RANGE := 520.0
const FAR_STEP := 6
const FAR_DROP := 0.06

const TEXTURES := {
	# Texture2DArray plates (4x3 slices) for city_grass_ground.gdshaderinc.
	"grass_ground_albedo": "res://assets/materials/pbr/grass_ground/grass_ground_albedo_array.jpg",
	"grass_ground_normal": "res://assets/materials/pbr/grass_ground/grass_ground_normal_array.jpg",
	"earth_albedo": "res://assets/materials/pbr/mud/mud_albedo.png",
	"earth_normal": "res://assets/materials/pbr/mud/mud_normal.png",
	"sand_albedo": "res://assets/materials/pbr/coast_sand/coast_sand_albedo.png",
	"sand_normal": "res://assets/materials/pbr/coast_sand/coast_sand_normal.png",
	# Natural beach pebbles for the shingle band (not the masonry stone plate).
	"shingle_albedo": "res://assets/materials/pbr/shore_shingle/shore_shingle_albedo.png",
	# R-1516 drought crust in dried puddle basins.
	"cracked_albedo": "res://assets/materials/pbr/cracked_earth/cracked_earth_albedo.png",
}


static var _shared: ShaderMaterial


static func shared_material() -> ShaderMaterial:
	return _shared


static func material(plan: CityPlan) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	_shared = mat
	mat.shader = SHADER
	for key: String in TEXTURES:
		mat.set_shader_parameter(key, load(TEXTURES[key]))
	mat.set_shader_parameter("splat", load(plan.splat_path()))
	mat.set_shader_parameter("roads", load(plan.roads_path()))
	mat.set_shader_parameter("ground_height", plan.height_texture())
	mat.set_shader_parameter("ground_rect", plan.height_texture_rect())
	mat.set_shader_parameter("trail", _neutral_trail())
	mat.set_shader_parameter("trail_rect", Vector4(0.0, 0.0, 1.0, 1.0))
	mat.set_shader_parameter(
		"splat_rect",
		Vector4(
			plan.bounds.position.x, plan.bounds.position.y, plan.bounds.size.x, plan.bounds.size.y
		)
	)
	return mat


## Untouched footprint relief (0.5) until CityGroundTrail installs its window.
static func _neutral_trail() -> ImageTexture:
	var image := Image.create_empty(2, 2, false, Image.FORMAT_R8)
	image.fill(Color(0.5, 0.0, 0.0))
	return ImageTexture.create_from_image(image)


static func build(plan: CityPlan, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Terrain"
	parent.add_child(root)
	var mat := material(plan)
	var size := plan.height_grid_size()
	for cy in range(0, size.y - 1, CHUNK_CELLS):
		for cx in range(0, size.x - 1, CHUNK_CELLS):
			var mesh := _chunk_mesh(
				plan,
				cx,
				cy,
				mini(cx + CHUNK_CELLS, size.x - 1),
				mini(cy + CHUNK_CELLS, size.y - 1),
				1,
				0.0
			)
			var inst := MeshInstance3D.new()
			inst.name = "Chunk_%d_%d" % [cx / CHUNK_CELLS, cy / CHUNK_CELLS]
			inst.mesh = mesh
			inst.material_override = mat
			inst.visibility_range_end = NEAR_RANGE
			inst.visibility_range_end_margin = 24.0
			inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			root.add_child(inst)
	var far := MeshInstance3D.new()
	far.name = "FarTerrain"
	far.mesh = _chunk_mesh(plan, 0, 0, size.x - 1, size.y - 1, FAR_STEP, FAR_DROP)
	far.material_override = mat
	far.visibility_range_begin = NEAR_RANGE - 40.0
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(far)
	var skirt := MeshInstance3D.new()
	skirt.name = "HorizonSkirt"
	skirt.mesh = _skirt_mesh(plan)
	skirt.material_override = mat
	skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(skirt)
	return root


## Flat extension of the plan's edge heights out to the horizon so vistas from
## Toompea and the towers never end at a cliff. Land past the shore dips under
## the open sea plane.
static func _skirt_mesh(plan: CityPlan) -> ArrayMesh:
	const STEP := 8
	const REACH := 2600.0
	var size := plan.height_grid_size()
	var cell := plan.height_cell()
	var origin := plan.height_origin()
	var edge: Array[Vector2i] = []
	for x in range(0, size.x, STEP):
		edge.append(Vector2i(x, 0))
	for y in range(0, size.y, STEP):
		edge.append(Vector2i(size.x - 1, y))
	for x in range(size.x - 1, -1, -STEP):
		edge.append(Vector2i(x, size.y - 1))
	for y in range(size.y - 1, -1, -STEP):
		edge.append(Vector2i(0, y))
	var center := plan.bounds.get_center()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in edge.size():
		var a := edge[i]
		var b := edge[(i + 1) % edge.size()]
		var pa := origin + Vector2(a) * cell
		var pb := origin + Vector2(b) * cell
		var ha := plan.grid_height(a.x, a.y) - 0.05
		var hb := plan.grid_height(b.x, b.y) - 0.05
		var oa := pa + (pa - center).normalized() * REACH
		var ob := pb + (pb - center).normalized() * REACH
		var quad := [
			Vector3(pa.x, ha, pa.y),
			Vector3(pb.x, hb, pb.y),
			Vector3(ob.x, hb, ob.y),
			Vector3(oa.x, ha, oa.y),
		]
		for idx: int in [0, 2, 1, 0, 3, 2]:
			var v: Vector3 = quad[idx]
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z))
			st.add_vertex(v)
	st.generate_tangents()
	return st.commit()


static func _chunk_mesh(
	plan: CityPlan, x0: int, y0: int, x1: int, y1: int, step: int, drop: float
) -> ArrayMesh:
	var cell := plan.height_cell()
	var origin := plan.height_origin()
	var xs: Array[int] = []
	var ys: Array[int] = []
	for x in range(x0, x1 + 1, step):
		xs.append(x)
	if xs[-1] != x1:
		xs.append(x1)
	for y in range(y0, y1 + 1, step):
		ys.append(y)
	if ys[-1] != y1:
		ys.append(y1)
	var w := xs.size()
	var h := ys.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tangents := PackedFloat32Array()
	verts.resize(w * h)
	normals.resize(w * h)
	uvs.resize(w * h)
	tangents.resize(w * h * 4)
	for j in h:
		for i in w:
			var gx := xs[i]
			var gy := ys[j]
			var px := origin.x + float(gx) * cell
			var pz := origin.y + float(gy) * cell
			var k := j * w + i
			verts[k] = Vector3(px, plan.grid_height(gx, gy) - drop, pz)
			var dx := plan.grid_height(gx + 1, gy) - plan.grid_height(gx - 1, gy)
			var dz := plan.grid_height(gx, gy + 1) - plan.grid_height(gx, gy - 1)
			var n := Vector3(-dx, 2.0 * cell, -dz).normalized()
			normals[k] = n
			uvs[k] = Vector2(px, pz)
			var t := Vector3(1, 0, 0)
			t = (t - n * n.dot(t)).normalized()
			tangents[k * 4] = t.x
			tangents[k * 4 + 1] = t.y
			tangents[k * 4 + 2] = t.z
			tangents[k * 4 + 3] = 1.0
	var indices := PackedInt32Array()
	indices.resize((w - 1) * (h - 1) * 6)
	var q := 0
	for j in h - 1:
		for i in w - 1:
			var a := j * w + i
			var b := a + 1
			var c := a + w
			var d := c + 1
			# Split each quad along the diagonal closer in height so ridges follow the data.
			if absf(verts[a].y - verts[d].y) < absf(verts[b].y - verts[c].y):
				indices[q] = a
				indices[q + 1] = b
				indices[q + 2] = d
				indices[q + 3] = a
				indices[q + 4] = d
				indices[q + 5] = c
			else:
				indices[q] = a
				indices[q + 1] = b
				indices[q + 2] = c
				indices[q + 3] = b
				indices[q + 4] = d
				indices[q + 5] = c
			q += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
