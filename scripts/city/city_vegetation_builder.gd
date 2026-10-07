class_name CityVegetationBuilder
extends RefCounted

## Trees from the city plan (orchards in yards, lindens on the klint, alders on
## the Hareapea, open-country oak and birch), one MultiMesh pair (wood, crown)
## per species, using the project's tree meshes and wind-aware canopy materials.

## Mature heights in metres; the shared tree meshes are ~2.5 units tall, made
## for the compressed district maps, so the true-scale city scales them up.
const HEIGHT_M := {
	&"oak": 16.0,
	&"linden": 15.0,
	&"ash": 15.0,
	&"elm": 15.0,
	&"maple": 12.0,
	&"birch": 14.0,
	&"alder": 10.0,
	&"willow": 9.0,
	&"spruce": 18.0,
	&"pine": 16.0,
	&"juniper": 3.0,
	&"apple": 5.0,
	&"cherry": 5.0,
	&"plum": 4.5,
	&"pear": 6.0,
	&"rowan": 6.0,
}

## Crowns are expensive (layered leaf cards): chunk them spatially and only
## draw nearby ones; trunks carry a little further so woods do not pop bare.
const CHUNK := 96.0
const CROWN_RANGE := 260.0
const WOOD_RANGE := 200.0


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
	for t: Array in plan.data.get("trees", []):
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
		wood.visibility_range_end = WOOD_RANGE
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
		crown.visibility_range_end = CROWN_RANGE
		root.add_child(crown)
	return root
