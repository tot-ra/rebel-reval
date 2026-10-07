class_name CityVegetationBuilder
extends RefCounted

## Trees from the city plan (orchards in yards, lindens on the klint, alders on
## the Hareapea, open-country oak and birch), one MultiMesh pair (wood, crown)
## per species, using the project's tree meshes and wind-aware canopy materials.

## Typical heights in metres for town and pasture trees (yard orchards are
## pruned low, open-grown oaks stay broad rather than tall); the shared tree
## meshes are ~2.5 units tall, so they are scaled to these.
const HEIGHT_M := {
	&"oak": 12.0,
	&"linden": 11.0,
	&"ash": 11.0,
	&"elm": 11.0,
	&"maple": 9.0,
	&"birch": 10.0,
	&"alder": 8.0,
	&"willow": 7.0,
	&"spruce": 13.0,
	&"pine": 12.0,
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
	var crown := MapViewMeshBuilderPrimitives.tree_canopy_mesh(species).get_aabb()
	var height := maxf(crown.end.y, 0.5)
	return float(HEIGHT_M.get(species, 8.0)) / metres_per_unit / height


static func build(plan: CityPlan, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Vegetation"
	parent.add_child(root)
	var by_species: Dictionary = {}
	var species_scales: Dictionary = {}
	var entries: Array = plan.data.get("trees", []).duplicate()
	for t: Array in plan.data.get("bushes", []):
		if SHRUB_AS_TREE.has(StringName(t[2])):
			entries.append([t[0], t[1], String(SHRUB_AS_TREE[StringName(t[2])]), t[3]])
	for t: Array in entries:
		var species := StringName(t[2])
		var p := Vector2(t[0], t[1])
		if not species_scales.has(species):
			species_scales[species] = species_scale(species, plan.metres_per_unit)
		var bucket := [species, Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))]
		if not by_species.has(bucket):
			by_species[bucket] = {
				"transforms": [] as Array[Transform3D], "colors": [] as Array[Color]
			}
		var scale := float(t[3]) * float(species_scales[species])
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
		var wood := MapViewMeshBuilderPrimitives.multi_mesh(
			"Wood_%s" % species,
			MapViewMeshBuilderPrimitives.tree_wood_mesh(species),
			transforms,
			colors,
			MapViewMaterials.bark(MapViewTreeSpecies.bark_kind_for(species)),
			Vector3.ZERO
		)
		var shrub := species in [&"hazel", &"hawthorn", &"blackthorn"]
		wood.visibility_range_end = BUSH_RANGE if shrub else WOOD_RANGE
		if shrub:
			wood.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(wood)
		var crown := MapViewMeshBuilderPrimitives.multi_mesh(
			"Crown_%s" % species,
			MapViewMeshBuilderPrimitives.tree_canopy_mesh(species),
			transforms,
			colors,
			MapViewMaterials.canopy_for_species(species),
			Vector3.ZERO,
			true
		)
		crown.visibility_range_end = BUSH_RANGE if shrub else CROWN_RANGE
		if shrub:
			crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(crown)
	build_bushes(plan, root)
	return root


## Shrubs from the plan (yard elder and roses, wall-foot thorn scrub, stream
## willow, juniper on the shore), chunked MultiMeshes with a short range.
static func build_bushes(plan: CityPlan, root: Node3D) -> void:
	var buckets: Dictionary = {}
	for t: Array in plan.data.get("bushes", []):
		var species := StringName(t[2])
		if SHRUB_AS_TREE.has(species):
			continue
		var p := Vector2(t[0], t[1])
		var key := [species, Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))]
		if not buckets.has(key):
			buckets[key] = {"transforms": [] as Array[Transform3D], "colors": [] as Array[Color]}
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(int(p.x * 10.0), int(p.y * 10.0)))
		var scale := float(t[3])
		var size_m: Vector2 = BUSH_SIZE_M.get(species, Vector2(2.0, 2.0))
		var aabb := BushMeshes.mesh_for(species).get_aabb().size
		var sy := size_m.x / plan.metres_per_unit / maxf(aabb.y, 0.1) * scale
		# Uniform: the cards only read as a shrub in their authored proportions.
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
		var inst := MapViewMeshBuilderPrimitives.multi_mesh(
			"Bush_%s" % species,
			BushMeshes.mesh_for(species),
			buckets[key]["transforms"],
			buckets[key]["colors"],
			material,
			Vector3.ZERO
		)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.visibility_range_end = BUSH_RANGE
		root.add_child(inst)
