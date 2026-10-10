extends "res://tests/godot/test_case.gd"

## R-1519: realistic wild plants of the seamless city (CityForbMeshes) and their
## habitat placement (CityForbs); R-1557: the model mix follows the season.
## docs/SYSTEMS/VEGETATION_REALISM.md section 2.

const Meshes := preload("res://scripts/city/city_forb_meshes.gd")
## Per-model triangle cap: keeps a chunk of forbs inside the flower budget.
const MAX_TRIANGLES := 4500
## Flowering burdock is a metre-high branched plant with dozens of burrs, and
## rare (a share of the sparsest species), so it gets a larger cap.
const MAX_TRIANGLES_LARGE := 6500
## Verge spot near the pasture used by the capture tool (habitat score peak).
const VERGE := Vector2(75.5, 377.7)
## A mid-June day: every species above ground, dandelions flowering and seeding.
const JUNE := {"day": 15, "month": 6, "year": 1343}


func test_models_are_cached_bounded_and_rooted() -> void:
	for kind: StringName in Meshes.ALL_KINDS:
		var mesh := Meshes.mesh_for(kind)
		assert_true(mesh == Meshes.mesh_for(kind), "%s is cached" % kind)
		var tris := Meshes.triangle_count(kind)
		var tall := kind in [Meshes.KIND_BURDOCK_FLOWERING, Meshes.KIND_BURDOCK_DRY]
		var cap := MAX_TRIANGLES_LARGE if tall else MAX_TRIANGLES
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
	var day := GameCalendar.day_of_year(JUNE)
	var a := CityForbs.chunk_buffers(grass, key, day)
	var b := CityForbs.chunk_buffers(grass, key, day)
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


## Every model CityForbs can pick on `date`, over all species, picks and wildness.
func _mix(date: Dictionary) -> Array:
	var day := GameCalendar.day_of_year(date)
	var kinds := {}
	for species: StringName in CityForbs.MAX_DENSITY:
		var phase := VegetationPhenology.forb_phase(species, day)
		if phase == VegetationPhenology.FORB_NONE:
			continue
		for i in 21:
			for wild: float in [0.0, 0.5, 1.0]:
				# Picks are 0..1 exclusive (randf), so sweep 0..0.999.
				kinds[CityForbs._kind_for(species, float(i) / 20.0 * 0.999, wild, phase)] = true
	var out := kinds.keys()
	out.sort()
	return out


func _sorted(kinds: Array) -> Array:
	var out := kinds.duplicate()
	out.sort()
	return out


func test_season_mix() -> void:
	var leaves := [
		Meshes.KIND_DANDELION_LEAVES, Meshes.KIND_PLANTAIN_LEAVES,
		Meshes.KIND_WHITE_CLOVER_LEAVES, Meshes.KIND_RED_CLOVER_LEAVES, Meshes.KIND_BURDOCK,
	]
	# [date, models that grow then]
	var seasons := [
		# Slice opening, 21 April: young rosettes only.
		[GameCalendar.DEFAULT_DATE, leaves],
		# May: dandelions in flower, no clocks yet.
		[{"day": 20, "month": 5, "year": 1343}, leaves + [Meshes.KIND_DANDELION_FLOWER]],
		# June: dandelion flowers and clocks, clover and plantain in flower,
		# burdock still a rosette.
		[JUNE, [
			Meshes.KIND_DANDELION_FLOWER, Meshes.KIND_DANDELION_CLOCK, Meshes.KIND_DANDELION_LEAVES,
			Meshes.KIND_PLANTAIN, Meshes.KIND_PLANTAIN_LEAVES,
			Meshes.KIND_WHITE_CLOVER, Meshes.KIND_RED_CLOVER, Meshes.KIND_BURDOCK,
		]],
		# July: dandelion leaves only, burdock in burr.
		[{"day": 20, "month": 7, "year": 1343}, [
			Meshes.KIND_DANDELION_LEAVES, Meshes.KIND_PLANTAIN, Meshes.KIND_PLANTAIN_LEAVES,
			Meshes.KIND_WHITE_CLOVER, Meshes.KIND_RED_CLOVER,
			Meshes.KIND_BURDOCK, Meshes.KIND_BURDOCK_FLOWERING,
		]],
		# September: clover over, plantain still spiked, burrs dry brown.
		[{"day": 20, "month": 9, "year": 1343}, leaves + [
			Meshes.KIND_PLANTAIN, Meshes.KIND_BURDOCK_DRY,
		]],
		# October: leaves and dry burdock.
		[{"day": 20, "month": 10, "year": 1343}, leaves + [Meshes.KIND_BURDOCK_DRY]],
		# Early November: the last rosettes before the frost.
		[{"day": 10, "month": 11, "year": 1343}, leaves],
		# Winter: nothing above ground.
		[{"day": 1, "month": 12, "year": 1343}, []],
		[{"day": 15, "month": 1, "year": 1344}, []],
		[{"day": 1, "month": 4, "year": 1343}, []],
	]
	for season: Array in seasons:
		assert_eq(_mix(season[0]), _sorted(season[1]), "forb mix on %s" % [season[0]])


func test_winter_chunks_are_empty() -> void:
	var grass := CityGrass.create(CityPlan.load_default())
	var key := Vector2i(floori(VERGE.x / CityForbs.CHUNK), floori(VERGE.y / CityForbs.CHUNK))
	var winter := GameCalendar.day_of_year({"day": 15, "month": 1, "year": 1343})
	assert_true(CityForbs.chunk_buffers(grass, key, winter).is_empty(), "nothing grows in January")
	assert_false(
		CityForbs.chunk_buffers(grass, key, GameCalendar.day_of_year(JUNE)).is_empty(),
		"the same chunk is green in June"
	)
	grass.free()


func test_plants_keep_their_spots_through_the_year() -> void:
	# The season only swaps models: every spot that grows a plant in spring grows
	# one in summer and autumn too.
	var grass := CityGrass.create(CityPlan.load_default())
	var key := Vector2i(floori(VERGE.x / CityForbs.CHUNK), floori(VERGE.y / CityForbs.CHUNK))
	var spots := []
	for date: Dictionary in [
		GameCalendar.DEFAULT_DATE, JUNE, {"day": 1, "month": 10, "year": 1343}
	]:
		var found := []
		var chunk := CityForbs.chunk_buffers(grass, key, GameCalendar.day_of_year(date))
		for kind: StringName in chunk:
			var buf: PackedFloat32Array = chunk[kind]
			for k in range(0, buf.size(), CityForbs.STRIDE):
				found.append(Vector3(buf[k + 3], buf[k + 7], buf[k + 11]))
		found.sort()
		spots.append(found)
	assert_true(spots[0].size() > 5, "the verge chunk holds plants")
	assert_eq(spots[1], spots[0], "June plants stand where April ones did")
	assert_eq(spots[2], spots[0], "October plants stand where April ones did")
	grass.free()


func test_calendar_rebuilds_only_when_the_mix_changes() -> void:
	var grass := CityGrass.create(CityPlan.load_default())
	var forbs := grass.forbs
	forbs.set_calendar_date({"day": 1, "month": 7, "year": 1343})
	while forbs.update_for(VERGE, Time.get_ticks_usec() + 1000000, false):
		pass
	var july := forbs.instance_count(Meshes.KIND_DANDELION_FLOWER, false) \
		+ forbs.instance_count(Meshes.KIND_DANDELION_FLOWER, true)
	assert_eq(july, 0, "no dandelion flowers in July")
	var cached := forbs._chunks.size()
	assert_true(cached > 0, "chunks streamed")
	forbs.set_calendar_date({"day": 2, "month": 7, "year": 1343})
	assert_eq(forbs._chunks.size(), cached, "a new day in the same phase keeps the chunks")
	forbs.set_calendar_date({"day": 20, "month": 5, "year": 1343})
	assert_eq(forbs._chunks.size(), 0, "a new phase drops the cached chunks")
	while forbs.update_for(VERGE, Time.get_ticks_usec() + 1000000, false):
		pass
	var may := forbs.instance_count(Meshes.KIND_DANDELION_FLOWER, false) \
		+ forbs.instance_count(Meshes.KIND_DANDELION_FLOWER, true)
	assert_true(may > 0, "May dandelions flower after the rebuild")
	grass.free()
