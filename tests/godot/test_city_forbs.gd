extends "res://tests/godot/test_case.gd"

## R-1519: realistic wild plants of the seamless city (CityForbMeshes) and their
## habitat placement (CityForbs). docs/SYSTEMS/VEGETATION_REALISM.md section 2.

const Meshes := preload("res://scripts/city/city_forb_meshes.gd")
## Per-model triangle cap: keeps a chunk of forbs inside the flower budget.
const MAX_TRIANGLES := 4500
## Flowering burdock is a metre-high branched plant with dozens of burrs, and
## rare (a share of the sparsest species), so it gets a larger cap.
const MAX_TRIANGLES_LARGE := 6500
## Verge spot near the pasture used by the capture tool (habitat score peak).
const VERGE := Vector2(75.5, 377.7)


func test_models_are_cached_bounded_and_rooted() -> void:
	for kind: StringName in Meshes.ALL_KINDS:
		var mesh := Meshes.mesh_for(kind)
		assert_true(mesh == Meshes.mesh_for(kind), "%s is cached" % kind)
		var tris := Meshes.triangle_count(kind)
		var cap := MAX_TRIANGLES_LARGE if kind == Meshes.KIND_BURDOCK_FLOWERING else MAX_TRIANGLES
		assert_true(tris > 200 and tris <= cap, "%s has %d triangles" % [kind, tris])
		assert_eq((mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2] as PackedVector2Array).size(),
			(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
			"%s carries leaf-detail UV2" % kind)
		var arrays := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var low := INF
		for i in verts.size():
			assert_true(verts[i].y >= 0.0, "%s never dips under the ground" % kind)
			low = minf(low, verts[i].y)
			if verts[i].y < 0.003 and Vector2(verts[i].x, verts[i].z).length() < 0.01:
				assert_true(uvs[i].x < 0.05, "%s is rigid at its root" % kind)
		assert_true(low < 0.01, "%s stands on the ground" % kind)


func test_heights_match_the_species() -> void:
	var heights := {}
	for kind: StringName in Meshes.ALL_KINDS:
		heights[kind] = Meshes.mesh_for(kind).get_aabb().end.y
	assert_true(heights[Meshes.KIND_DANDELION_LEAVES] < 0.12, "dandelion rosette lies low")
	assert_true(heights[Meshes.KIND_DANDELION_FLOWER] > 0.15, "dandelion scapes stand up")
	assert_true(heights[Meshes.KIND_WHITE_CLOVER] < 0.2, "white clover is a low mat")
	assert_true(
		heights[Meshes.KIND_RED_CLOVER] > heights[Meshes.KIND_WHITE_CLOVER], "red clover is taller"
	)
	assert_true(heights[Meshes.KIND_BURDOCK_FLOWERING] > 1.0, "flowering burdock is over a metre")


func test_leaves_face_up() -> void:
	# The front face is the upper side (the shader shows the pale underside on
	# back faces): a flat rosette's front normals point mostly up.
	var arrays := Meshes.mesh_for(Meshes.KIND_PLANTAIN).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var up := 0.0
	for i in range(0, indices.size(), 3):
		var a := verts[indices[i]]
		var n := (verts[indices[i + 2]] - a).cross(verts[indices[i + 1]] - a)
		up += n.y
	assert_true(up > 0.0, "front faces of the plantain rosette look up")


func test_habitats() -> void:
	var grass := CityGrass.create(CityPlan.load_default())
	var plan := grass.plan
	# Red clover needs uncut meadow; it never grows where the grass is scythed.
	var cut := 0
	var plantain_near := 0.0
	var plantain_wild := 0.0
	for y in range(-120, 121, 6):
		for x in range(-120, 121, 6):
			var p := VERGE + Vector2(x, y)
			if grass.wildness_at(p) < 0.3:
				assert_true(
					CityForbs.suitability(grass, Meshes.KIND_RED_CLOVER, p) < 0.2,
					"red clover stays out of short turf at %s" % p
				)
				cut += 1
			if grass.road_distance_at(p) <= 3.0:
				plantain_near += CityForbs.suitability(grass, Meshes.KIND_PLANTAIN, p)
			elif grass.wildness_at(p) > 0.9:
				plantain_wild += CityForbs.suitability(grass, Meshes.KIND_PLANTAIN, p)
	assert_true(cut > 0, "probe area includes cut turf")
	assert_true(plantain_near > plantain_wild * 0.2, "plantain favours worn verges")
	grass.free()


func test_chunk_is_deterministic_and_off_buildings() -> void:
	var grass := CityGrass.create(CityPlan.load_default())
	var key := Vector2i(floori(VERGE.x / CityForbs.CHUNK), floori(VERGE.y / CityForbs.CHUNK))
	var a := CityForbs.chunk_buffers(grass, key)
	var b := CityForbs.chunk_buffers(grass, key)
	assert_eq(a.keys(), b.keys(), "same models both times")
	var total := 0
	for kind: StringName in a:
		var buf: PackedFloat32Array = a[kind]
		assert_eq(buf, b[kind], "same placement for %s" % kind)
		assert_eq(buf.size() % CityForbs.STRIDE, 0, "whole instances")
		for k in range(0, buf.size(), CityForbs.STRIDE):
			var p := Vector2(buf[k + 3], buf[k + 11])
			assert_true(grass.plan.building_at(p) < 0, "no plant inside a building")
			total += 1
	assert_true(total > 5, "a verge chunk holds a real number of plants (%d)" % total)
	grass.free()


func test_buffer_layout_matches_multimesh() -> void:
	# The packed layout must follow Godot's MultiMesh TRANSFORM_3D + colour
	# buffer: three basis rows each ending in the origin component, then RGBA.
	# (The headless dummy renderer keeps no MultiMesh buffer, so decode by hand.)
	var t := Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3(1.2, 0.8, 1.2)), Vector3(3, 4, 5))
	var buf := CityForbs._pack(t, Color(0.9, 1.0, 0.8))
	assert_eq(buf.size(), CityForbs.STRIDE, "one instance is one stride")
	var basis := Basis(
		Vector3(buf[0], buf[4], buf[8]), Vector3(buf[1], buf[5], buf[9]), Vector3(buf[2], buf[6], buf[10])
	)
	var decoded := Transform3D(basis, Vector3(buf[3], buf[7], buf[11]))
	assert_true(decoded.is_equal_approx(t), "transform round-trips")
	var tint := Color(buf[12], buf[13], buf[14], buf[15])
	assert_true(tint.is_equal_approx(Color(0.9, 1.0, 0.8)), "tint round-trips")


func test_layers_split_near_and_far() -> void:
	var grass := CityGrass.create(CityPlan.load_default())
	var forbs := grass.forbs
	while forbs.update_for(VERGE, Time.get_ticks_usec() + 1000000, false):
		pass
	var near := 0
	var far := 0
	for kind: StringName in Meshes.ALL_KINDS:
		near += forbs.instance_count(kind, false)
		far += forbs.instance_count(kind, true)
		assert_true(
			Meshes.triangle_count(kind, true) * 4 <= Meshes.triangle_count(kind),
			"far %s is at most a quarter of the near model" % kind
		)
	assert_true(near > 0 and far > near, "near ring round the player, far variants beyond")
	grass.free()
