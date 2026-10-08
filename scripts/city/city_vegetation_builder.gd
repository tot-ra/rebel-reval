class_name CityVegetationBuilder
extends RefCounted

## Trees from the city plan (orchards in yards, lindens on the klint, alders on
## the Hareapea, open-country oak and birch), one MultiMesh pair (wood, crown)
## per species, using the project's tree meshes and wind-aware canopy materials.

## Typical heights in metres for town and pasture trees (yard orchards are
## pruned low, open-grown oaks stay broad rather than tall); the shared tree
## meshes are ~2.5 units tall, so they are scaled to these. VEG pass (R-712):
## lowered to young-to-middle-aged trees, because full-grown 13-17 m spruces
## dwarfed Kalev (1.83 m) and towered over the two-storey town.
const HEIGHT_M := {
	&"oak": 10.0,
	&"linden": 9.5,
	&"ash": 9.5,
	&"elm": 9.5,
	&"maple": 8.0,
	&"birch": 9.0,
	&"alder": 7.0,
	&"willow": 6.5,
	&"spruce": 9.5,
	&"pine": 10.0,
	&"juniper": 2.5,
	&"apple": 4.0,
	&"cherry": 4.0,
	&"plum": 3.5,
	&"pear": 5.0,
	&"rowan": 5.0,
	&"hazel": 3.4,
	&"hawthorn": 3.6,
	&"blackthorn": 2.6,
}
## Trunk diameter at the base in metres for a tree of HEIGHT_M. The shared
## skeletons have stylised fat boles (a 13 m spruce had a 1.1 m trunk); city
## wood is thinned to these real proportions (MapViewTreeMeshes.city_wood_mesh).
const TRUNK_DIAMETER_M := {
	&"oak": 0.7,
	&"linden": 0.55,
	&"ash": 0.5,
	&"elm": 0.55,
	&"maple": 0.45,
	&"birch": 0.3,
	&"alder": 0.32,
	&"willow": 0.5,
	&"spruce": 0.36,
	&"pine": 0.4,
	&"juniper": 0.12,
	&"apple": 0.28,
	&"cherry": 0.22,
	&"plum": 0.18,
	&"pear": 0.3,
	&"rowan": 0.2,
	&"hazel": 0.08,
	&"hawthorn": 0.14,
	&"blackthorn": 0.08,
}
## The plan's per-tree size factor (0.85-1.35) is compressed toward 1 by this
## much, so neighbours vary without the odd giant.
const SIZE_VARIATION := 0.6
## Large shrubs read best as low multi-stem crowns: drawn with the tree meshes.
const SHRUB_AS_TREE := {
	&"elder": &"hazel",
	&"hazel_shrub": &"hazel",
	&"guelder_rose": &"hazel",
	&"willow_shrub": &"hazel",
	&"alder_shrub": &"hazel",
	&"hawthorn": &"hawthorn",
	&"blackthorn": &"blackthorn",
	&"spindle": &"hawthorn",
	# The shared block-shaped shrub meshes read as giant flat-shaded stalks beside
	# a 1.83 m figure; these draw with the real-size leaf-card shrub trees.
	&"juniper_shrub": &"juniper",
	&"sea_buckthorn": &"blackthorn",
}

## Crowns are expensive (layered leaf cards): chunk them spatially and only
## draw nearby ones; trunks carry a little further so woods do not pop bare.
const CHUNK := 96.0
const CROWN_RANGE := 260.0
const WOOD_RANGE := 200.0
const BUSH_RANGE := 120.0
## Shrub size in metres (height, spread); the shared bush meshes are ~1 x 0.4.
const BUSH_SIZE_M := {
	&"elder": Vector2(3.0, 2.8),
	&"hazel_shrub": Vector2(3.2, 3.0),
	&"dog_rose": Vector2(1.8, 2.0),
	&"guelder_rose": Vector2(2.6, 2.4),
	&"raspberry": Vector2(1.3, 1.4),
	&"hawthorn": Vector2(3.0, 2.6),
	&"blackthorn": Vector2(2.2, 2.4),
	&"willow_shrub": Vector2(3.0, 3.0),
	&"alder_shrub": Vector2(3.0, 2.6),
	&"juniper_shrub": Vector2(1.6, 1.2),
	&"sea_buckthorn": Vector2(2.0, 2.2),
	&"heather": Vector2(0.5, 0.8),
	&"spindle": Vector2(2.5, 2.0),
}
const BushMeshes := preload("res://scripts/map/view3d/map_view_bush_meshes.gd")
const BushSpecies := preload("res://scripts/map/view3d/map_view_bush_species.gd")


static func species_scale(species: StringName, metres_per_unit: float) -> float:
	var crown := MapViewTreeMeshes.city_canopy_far_mesh(species).get_aabb()
	var height := maxf(crown.end.y, 0.5)
	return float(HEIGHT_M.get(species, 8.0)) / metres_per_unit / height


static func size_factor(plan_scale: float) -> float:
	return lerpf(1.0, plan_scale, SIZE_VARIATION)


## Trunk radius multiplier that gives the species its TRUNK_DIAMETER_M.
static func trunk_factor(species: StringName, world_scale: float) -> float:
	var radii: Array = MapViewMeshBuilderPrimitives.tree_geometry_stats(species)["trunk_radii"]
	var base := float(radii[0]) * 2.0 * world_scale if not radii.is_empty() else 1.0
	return clampf(float(TRUNK_DIAMETER_M.get(species, 0.4)) / maxf(base, 0.01), 0.2, 1.0)


static func build(plan: CityPlan, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Vegetation"
	parent.add_child(root)
	var lod := CityTreeLod.new()
	lod.name = "TreeLod"
	root.add_child(lod)
	var by_species: Dictionary = {}
	var species_scales: Dictionary = {}
	var entries: Array = plan.data.get("trees", []).duplicate()
	for t: Array in plan.data.get("bushes", []):
		if SHRUB_AS_TREE.has(StringName(t[2])):
			entries.append([t[0], t[1], String(SHRUB_AS_TREE[StringName(t[2])]), t[3]])
	for t: Array in entries:
		var species := StringName(t[2])
		var p := Vector2(t[0], t[1])
		if plan.in_moat(p, 1.0):
			continue  # nothing roots in the ditch water
		if not species_scales.has(species):
			species_scales[species] = species_scale(species, plan.metres_per_unit)
		var bucket := [species, Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))]
		if not by_species.has(bucket):
			by_species[bucket] = {
				"transforms": [] as Array[Transform3D], "colors": [] as Array[Color]
			}
		var scale := size_factor(float(t[3])) * float(species_scales[species])
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(int(p.x * 10.0), int(p.y * 10.0)))
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale)
		var xf := Transform3D(basis, Vector3(p.x, plan.ground_height(p) - 0.15, p.y))
		(by_species[bucket]["transforms"] as Array[Transform3D]).append(xf)
		var tone := rng.randf_range(0.85, 1.1)
		(by_species[bucket]["colors"] as Array[Color]).append(Color(tone, tone, tone, 1.0))
	var buckets := by_species.keys()
	buckets.sort_custom(func(a: Array, b: Array) -> bool: return str(a) < str(b))
	for bucket: Array in buckets:
		var species: StringName = bucket[0]
		var batch: Dictionary = by_species[bucket]
		var transforms: Array[Transform3D] = batch["transforms"]
		var colors: Array[Color] = batch["colors"]
		var world_scale: float = species_scales[species]
		var wood := MapViewMeshBuilderPrimitives.multi_mesh(
			"Wood_%s" % species,
			MapViewTreeMeshes.city_wood_mesh(
				species, world_scale, trunk_factor(species, world_scale)
			),
			transforms,
			colors,
			MapViewMaterials.bark_plate_wind(MapViewTreeSpecies.bark_plate_for(species), species),
			Vector3.ZERO
		)
		var shrub := species in MapViewTreeMeshes.CITY_SHRUBS
		# Shader-bent crowns can reach beyond the undeformed batch AABB.
		wood.extra_cull_margin = 12.0
		wood.visibility_range_end = BUSH_RANGE if shrub else WOOD_RANGE
		if shrub:
			wood.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(wood)
		var crown := MapViewMeshBuilderPrimitives.multi_mesh(
			"Crown_%s" % species,
			MapViewTreeMeshes.city_canopy_far_mesh(species),
			transforms,
			colors,
			MapViewMaterials.canopy_for_species(species),
			Vector3.ZERO,
			true
		)
		crown.extra_cull_margin = 12.0
		crown.visibility_range_end = BUSH_RANGE if shrub else CROWN_RANGE
		if shrub:
			crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(crown)
		# This big-card crown is the far LOD; CityTreeLod swaps trees near the
		# camera to the real-size near crown. Shrubs swap too: their near cards
		# are NEAR_SHRUB_CARD_METRES (hand-sized leaves beside Kalev).
		lod.register(species, world_scale, crown.multimesh, transforms, colors, shrub)
	build_bushes(plan, root)
	return root


## City mesh for a build_bushes shrub: leafy shrubs with a city variant are
## built in metres with real-size leaf cards; the rest reuse the shared mesh.
static func bush_mesh(species: StringName) -> ArrayMesh:
	if BushMeshes.has_city_variant(species):
		return BushMeshes.city_mesh_for(species, BUSH_SIZE_M[species])
	return BushMeshes.mesh_for(species)


## Uniform instance scale (the cards only read as a shrub in their authored
## proportions). City variants are already in metres: only the plan factor.
static func bush_scale(species: StringName, plan_scale: float, metres_per_unit: float) -> float:
	if BushMeshes.has_city_variant(species):
		return plan_scale / metres_per_unit
	var size_m: Vector2 = BUSH_SIZE_M.get(species, Vector2(2.0, 2.0))
	var height := maxf(BushMeshes.mesh_for(species).get_aabb().size.y, 0.1)
	return size_m.x / metres_per_unit / height * plan_scale


## Shrubs from the plan (yard elder and roses, wall-foot thorn scrub, stream
## willow, juniper on the shore), chunked MultiMeshes with a short range.
static func build_bushes(plan: CityPlan, root: Node3D) -> void:
	var buckets: Dictionary = {}
	for t: Array in plan.data.get("bushes", []):
		var species := StringName(t[2])
		if SHRUB_AS_TREE.has(species):
			continue
		var p := Vector2(t[0], t[1])
		if plan.in_moat(p, 1.0):
			continue
		var key := [species, Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))]
		if not buckets.has(key):
			buckets[key] = {"transforms": [] as Array[Transform3D], "colors": [] as Array[Color]}
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(int(p.x * 10.0), int(p.y * 10.0)))
		var sy := bush_scale(species, float(t[3]), plan.metres_per_unit)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sy)
		(buckets[key]["transforms"] as Array[Transform3D]).append(
			Transform3D(basis, Vector3(p.x, plan.ground_height(p) - 0.05, p.y))
		)
		var tone := rng.randf_range(0.85, 1.1)
		(buckets[key]["colors"] as Array[Color]).append(Color(tone, tone, tone, 1.0))
	var keys := buckets.keys()
	keys.sort_custom(func(a: Array, b: Array) -> bool: return str(a) < str(b))
	for key: Array in keys:
		var species: StringName = key[0]
		var kind: StringName = BushSpecies.material_kind(species)
		var material: Material = (
			MapViewMaterials.canopy(kind) if kind == &"leaf" else MapViewMaterials.foliage_tuft()
		)
		if BushMeshes.has_city_variant(species):
			material = MapViewMaterials.canopy_for_species(BushMeshes.city_leaf_proxy(species))
		var inst := MapViewMeshBuilderPrimitives.multi_mesh(
			"Bush_%s" % species,
			bush_mesh(species),
			buckets[key]["transforms"],
			buckets[key]["colors"],
			material,
			Vector3.ZERO
		)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.visibility_range_end = BUSH_RANGE
		root.add_child(inst)
