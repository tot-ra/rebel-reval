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
	# Mature Scots pine of the sandy coastal heath (R-1617): a pine bor stands
	# far above people; MapViewTreeMeshes.CITY_FORMS gives it a clear bole.
	&"pine_tall": 23.0,
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
	&"pine_tall": 0.52,
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
## Metres past the near-crown radius where far crowns turn coarse (the LOD hides the coarse
## crown of every tree it swaps to a near crown, so a margin is enough).
const COARSE_MARGIN := 14.0
const GraphicsPresetsScript := preload("res://scripts/settings/graphics_presets.gd")
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


const LITTER_SHARE := 0.65
## Litter disc radius in metres per species; conifers drop a wider needle mat.
const LITTER_RADIUS_M := {
	&"spruce": 2.6, &"pine": 2.2, &"juniper": 1.4, &"oak": 3.0, &"linden": 2.8,
	&"elm": 2.8, &"ash": 2.6, &"willow": 2.8,
}
const CONIFERS := [&"spruce", &"pine", &"juniper"]
const LeafAtlas := preload("res://scripts/map/view3d/leaf_atlas.gd")
const LITTER_SHADER := preload("res://scripts/city/city_leaf_litter.gdshader")
## Weathered fallen-leaf browns (linear albedo, the atlas carries the detail).
const LITTER_BROWNS := [
	Color(0.12, 0.065, 0.025), Color(0.08, 0.045, 0.018), Color(0.11, 0.075, 0.04)
]
## Shed needles: rust for pine, darker for spruce and juniper.
const NEEDLE_BROWNS := {
	&"pine": [Color(0.30, 0.13, 0.04), Color(0.22, 0.10, 0.035)],
	&"spruce": [Color(0.17, 0.09, 0.035), Color(0.13, 0.075, 0.03)],
	&"juniper": [Color(0.17, 0.10, 0.04), Color(0.14, 0.08, 0.035)],
}
## Litter leaves are drawn a third larger than life (WHY: at the gameplay camera
## a true 6 cm birch leaf is a few pixels and the carpet dissolves into noise).
const LITTER_LEAF_BOOST := 1.35
static var _litter_meshes: Dictionary = {}
static var _litter_mats: Dictionary = {}


## Fallen leaves (or needle clusters) of this species around the trunk, thickest
## at the foot and thinning out to nothing. Each leaf is a small square card
## showing the species' leaf from the leaf atlas at real size, so the floor under
## a birch is birch leaves and under a pine is rust needles (WHY: the former
## flat-colour flecks read as brown rectangles). `radius` is in tree units; leaf
## size follows it so a metre of litter stays a metre. COLOR.a is a per-leaf
## hash the shader uses for the seasonal fresh share and snow.
static func litter_mesh(species: StringName, radius: float) -> ArrayMesh:
	var key := "%s:%.3f" % [species, radius]
	if _litter_meshes.has(key):
		return _litter_meshes[key]
	var conifer := species in CONIFERS
	var metre := radius / float(LITTER_RADIUS_M.get(species, 2.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(String(species).hash()) + 811
	var uv := LeafAtlas.uv_rect(LeafAtlas.cell_for(species))
	var side := LeafAtlas.quad_side_m(species) * metre * LITTER_LEAF_BOOST
	var browns: Array = NEEDLE_BROWNS.get(species, LITTER_BROWNS)
	var autumn: Color = VegetationPhenology.autumn_colors(species)[0]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3.UP)
	var count := 240 if conifer else 300
	for i in count:
		# Squared radius sampling packs leaves near the trunk.
		var dist := radius * pow(rng.randf(), 1.7)
		var ang := rng.randf() * TAU
		var centre := Vector3(cos(ang) * dist, rng.randf() * 0.012 * metre, sin(ang) * dist)
		var yaw := rng.randf() * TAU
		var half := side * 0.5 * rng.randf_range(0.8, 1.25)
		var along := Vector3(cos(yaw), 0.0, sin(yaw)) * half
		var across := Vector3(-sin(yaw), 0.0, cos(yaw)) * half
		var tint: Color = browns[rng.randi() % browns.size()]
		if not conifer:
			# A hint of the species' autumn hue survives in the weathered leaf.
			tint = tint.lerp(autumn * 0.3, rng.randf() * 0.35)
		tint *= rng.randf_range(0.8, 1.15)
		tint.a = rng.randf()
		surface.set_color(tint)
		# Curled leaves: corners sit at slightly different heights.
		var lift := [0.0, rng.randf(), rng.randf(), rng.randf() * 0.5]
		var quad := [-along - across, along - across, along + across, -along + across]
		var uvs := [
			uv.position + Vector2(0.0, uv.size.y), uv.position + uv.size,
			uv.position + Vector2(uv.size.x, 0.0), uv.position,
		]
		for corner_index: int in [0, 1, 2, 0, 2, 3]:
			surface.set_uv(uvs[corner_index])
			surface.add_vertex(
				centre + quad[corner_index] + Vector3.UP * float(lift[corner_index]) * 0.01 * metre
			)
	var mesh := surface.commit()
	_litter_meshes[key] = mesh
	return mesh


## One material per species: its autumn palette and the seasonal fresh share.
static func litter_material(species: StringName = &"") -> ShaderMaterial:
	if not _litter_mats.has(species):
		var material := ShaderMaterial.new()
		material.shader = LITTER_SHADER
		material.set_shader_parameter("leaf_atlas", LeafAtlas.ATLAS)
		var palette: Array = VegetationPhenology.autumn_colors(species)
		material.set_shader_parameter("autumn_a", palette[0])
		material.set_shader_parameter("autumn_b", palette[palette.size() - 1])
		_litter_mats[species] = material
	return _litter_mats[species]


## Season for every litter material: this autumn's coloured share and lying snow.
static func apply_litter_season(date: Dictionary, snow_cover: float) -> void:
	for species: StringName in _litter_mats:
		var material: ShaderMaterial = _litter_mats[species]
		material.set_shader_parameter(
			"fresh", VegetationPhenology.fresh_litter_share(species, date)
		)
		material.set_shader_parameter("snow_cover", snow_cover)


static func species_scale(species: StringName, metres_per_unit: float) -> float:
	var crown := MapViewTreeMeshes.city_canopy_far_mesh(species).get_aabb()
	var height := maxf(crown.end.y, 0.5)
	return float(HEIGHT_M.get(species, 8.0)) / metres_per_unit / height


static func size_factor(plan_scale: float) -> float:
	return lerpf(1.0, plan_scale, SIZE_VARIATION)


## Trunk radius multiplier that gives the species its TRUNK_DIAMETER_M.
static func trunk_factor(species: StringName, world_scale: float) -> float:
	# A growth form keeps its base species' trunk radius (CITY_FORMS).
	var radii: Array = MapViewMeshBuilderPrimitives.tree_geometry_stats(
		MapViewTreeMeshes.base_species(species)
	)["trunk_radii"]
	var base := float(radii[0]) * 2.0 * world_scale if not radii.is_empty() else 1.0
	return clampf(float(TRUNK_DIAMETER_M.get(species, 0.4)) / maxf(base, 0.01), 0.2, 1.0)


## Distance (to a 96 m chunk's centre) where far crowns switch to the coarse mesh. The
## graphics quality shrinks the near-crown radius, so low switches earlier.
static func coarse_crown_begin() -> float:
	var near_scale := 1.0
	var tree := Engine.get_main_loop() as SceneTree
	var settings := tree.root.get_node_or_null("UserSettings") if tree != null else null
	if settings != null and settings.get("graphics") != null:
		near_scale = float(
			GraphicsPresetsScript.row(String(settings.graphics.quality))["tree_near_scale"]
		)
	return CityTreeLod.NEAR_EXIT * near_scale + COARSE_MARGIN


static func build(plan: CityPlan, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Vegetation"
	parent.add_child(root)
	var lod := CityTreeLod.new()
	lod.name = "TreeLod"
	root.add_child(lod)
	var coarse_begin := coarse_crown_begin()
	var wood_coarse_begin := coarse_begin - COARSE_MARGIN + CHUNK * 0.71
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
				"transforms": [] as Array[Transform3D],
				"colors": [] as Array[Color],
				"litter": [] as Array[Transform3D],
			}
		var scale := size_factor(float(t[3])) * float(species_scales[species])
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(int(p.x * 10.0), int(p.y * 10.0)))
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale)
		var xf := Transform3D(basis, Vector3(p.x, plan.ground_height(p) - 0.15, p.y))
		(by_species[bucket]["transforms"] as Array[Transform3D]).append(xf)
		var tone := rng.randf_range(0.85, 1.1)
		(by_species[bucket]["colors"] as Array[Color]).append(Color(tone, tone, tone, 1.0))
		# Fallen leaves or needles under about two thirds of the trees; the
		# rest keep bare earth so the carpet reads as natural, not as a decal.
		if rng.randf() < LITTER_SHARE and not SHRUB_AS_TREE.values().has(String(species)):
			var litter_basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale)
			(by_species[bucket]["litter"] as Array[Transform3D]).append(
				Transform3D(litter_basis, xf.origin + Vector3(0.0, 0.25, 0.0))
			)
	var buckets := by_species.keys()
	buckets.sort_custom(func(a: Array, b: Array) -> bool: return str(a) < str(b))
	for bucket: Array in buckets:
		var species: StringName = bucket[0]
		var batch: Dictionary = by_species[bucket]
		var transforms: Array[Transform3D] = batch["transforms"]
		var colors: Array[Color] = batch["colors"]
		var world_scale: float = species_scales[species]
		var base := MapViewTreeMeshes.base_species(species)
		var wood := MapViewMeshBuilderPrimitives.multi_mesh(
			"Wood_%s" % species,
			MapViewTreeMeshes.city_wood_mesh(
				species, world_scale, trunk_factor(species, world_scale)
			),
			transforms,
			colors,
			MapViewMaterials.bark_plate_wind(MapViewTreeSpecies.bark_plate_for(base), base),
			Vector3.ZERO
		)
		var shrub := base in MapViewTreeMeshes.CITY_SHRUBS
		# Shader-bent crowns can reach beyond the undeformed batch AABB.
		wood.extra_cull_margin = 12.0
		wood.visibility_range_end = BUSH_RANGE if shrub else wood_coarse_begin
		if shrub:
			wood.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(wood)
		if not shrub:
			# Past a chunk-safe distance only the trunk is drawn, and no shadow is cast.
			var trunk := MapViewMeshBuilderPrimitives.multi_mesh(
				"WoodCoarse_%s" % species,
				MapViewTreeMeshes.city_wood_trunk_mesh(
					species, world_scale, trunk_factor(species, world_scale)
				),
				transforms,
				colors,
				MapViewMaterials.bark_plate_wind(MapViewTreeSpecies.bark_plate_for(base), base),
				Vector3.ZERO
			)
			trunk.extra_cull_margin = 12.0
			trunk.visibility_range_begin = wood_coarse_begin
			trunk.visibility_range_end = WOOD_RANGE
			trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(trunk)
			# The branchy wood never enters the shadow pass: the trunk casts for it.
			wood.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var trunk_shadow := MapViewMeshBuilderPrimitives.multi_mesh(
				"WoodShadow_%s" % species,
				MapViewTreeMeshes.city_wood_trunk_mesh(
					species, world_scale, trunk_factor(species, world_scale)
				),
				transforms,
				colors,
				MapViewMaterials.bark_plate_wind(MapViewTreeSpecies.bark_plate_for(base), base),
				Vector3.ZERO
			)
			trunk_shadow.extra_cull_margin = 12.0
			trunk_shadow.visibility_range_end = WOOD_RANGE
			trunk_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			root.add_child(trunk_shadow)
		var litter: Array[Transform3D] = batch["litter"]
		if not shrub and not litter.is_empty():
			var litter_colors: Array[Color] = []
			litter_colors.resize(litter.size())
			litter_colors.fill(Color.WHITE)
			# Litter follows the real species (a pollard form drops oak leaves).
			var litter_m := LITTER_RADIUS_M.get(base, 2.2) as float
			var litter_node := MapViewMeshBuilderPrimitives.multi_mesh(
				"Litter_%s" % species,
				litter_mesh(base, litter_m / plan.metres_per_unit / world_scale),
				litter,
				litter_colors,
				litter_material(base),
				Vector3.ZERO
			)
			litter_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			litter_node.visibility_range_end = BUSH_RANGE
			root.add_child(litter_node)
		var crown := MapViewMeshBuilderPrimitives.multi_mesh(
			"Crown_%s" % species,
			MapViewTreeMeshes.city_canopy_far_mesh(species),
			transforms,
			colors,
			MapViewMaterials.canopy_for_species(base),
			Vector3.ZERO,
			true
		)
		crown.extra_cull_margin = 12.0
		crown.visibility_range_end = BUSH_RANGE if shrub else coarse_begin
		if shrub:
			crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(crown)
		var hidden_with_near: Array[MultiMesh] = []
		if not shrub:
			# The full far crown draws in the colour pass only; a shadows-only coarse copy casts
			# for it (a quarter of the triangles in every sun cascade).
			crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var shade := MapViewMeshBuilderPrimitives.multi_mesh(
				"CrownShadow_%s" % species,
				MapViewTreeMeshes.city_canopy_coarse_mesh(species),
				transforms,
				colors,
				MapViewMaterials.canopy_for_species(base),
				Vector3.ZERO,
				true
			)
			shade.extra_cull_margin = 12.0
			shade.visibility_range_end = CROWN_RANGE
			shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			shade.set_instance_shader_parameter(&"coarse_lod", 1.0)
			root.add_child(shade)
			hidden_with_near.append(shade.multimesh)
			# Beyond coarse_begin (chunk-centre distance) the same trees draw a quarter of the
			# triangles and cast no shadow. A forest paid ~85 ms for full far crowns.
			var coarse := MapViewMeshBuilderPrimitives.multi_mesh(
				"CrownCoarse_%s" % species,
				MapViewTreeMeshes.city_canopy_coarse_mesh(species),
				transforms,
				colors,
				MapViewMaterials.canopy_for_species(base),
				Vector3.ZERO,
				true
			)
			coarse.extra_cull_margin = 12.0
			coarse.visibility_range_begin = coarse_begin
			coarse.visibility_range_end = CROWN_RANGE
			coarse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			coarse.set_instance_shader_parameter(&"coarse_lod", 1.0)
			root.add_child(coarse)
			hidden_with_near.append(coarse.multimesh)
		# This big-card crown is the far LOD; CityTreeLod swaps trees near the
		# camera to the real-size near crown. Shrubs swap too: their near cards
		# are NEAR_SHRUB_CARD_METRES (hand-sized leaves beside Kalev).
		lod.register(
			species, world_scale, crown.multimesh, transforms, colors, shrub, hidden_with_near
		)
	build_bushes(plan, root)
	return root


## City mesh for a build_bushes shrub, built in metres with real-size leaf
## cards. Only species with a city variant reach build_bushes.
static func bush_mesh(species: StringName) -> ArrayMesh:
	return BushMeshes.city_mesh_for(species, BUSH_SIZE_M[species])


## Uniform instance scale: city variants are already in metres, so only the
## plan factor applies.
static func bush_scale(plan_scale: float, metres_per_unit: float) -> float:
	return plan_scale / metres_per_unit


## Shrubs from the plan (yard elder and roses, wall-foot thorn scrub, stream
## willow, juniper on the shore), chunked MultiMeshes with a short range.
static func build_bushes(plan: CityPlan, root: Node3D) -> void:
	var buckets: Dictionary = {}
	for t: Array in plan.data.get("bushes", []):
		var species := StringName(t[2])
		if SHRUB_AS_TREE.has(species):
			continue
		# The legacy procedural shrub mesh was removed: a species with neither a
		# tree form nor a city variant is not drawn.
		if not BushMeshes.has_city_variant(species):
			continue
		var p := Vector2(t[0], t[1])
		if plan.in_moat(p, 1.0):
			continue
		var key := [species, Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))]
		if not buckets.has(key):
			buckets[key] = {"transforms": [] as Array[Transform3D], "colors": [] as Array[Color]}
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(int(p.x * 10.0), int(p.y * 10.0)))
		var sy := bush_scale(float(t[3]), plan.metres_per_unit)
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
		var material := MapViewMaterials.canopy_for_species(BushMeshes.city_leaf_proxy(species))
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
