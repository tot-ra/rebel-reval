extends RefCounted

## Cached wind-driven vegetation and cloth materials for the 3D map view.
##
## Grass blades, tree canopies, sails, pennants, wall banners, and fishing-net
## parts share one deformation vocabulary. MapViewMaterials keeps the public
## facade so existing builders and tests do not change call sites.

const FISHING_NET_HEMP_TEXTURE := preload(
	"res://assets/props/crafts/fishing_nets/fishing_nets_TarredHempNet_albedo.png"
)
const FISHING_NET_FLOAT_TEXTURE := preload(
	"res://assets/props/crafts/fishing_nets/fishing_nets_BarkCorkFloats_albedo.png"
)
const FISHING_NET_SINKER_TEXTURE := preload(
	"res://assets/props/crafts/fishing_nets/fishing_nets_PiercedStoneSinkers_albedo.png"
)
## R-1103 blade-cluster atlas for the cross-card grass tuft (tools/build_grass_blade_atlas.py).
# Fade ends sit inside the layers' range cull (45 m and 14 m, each with margin).
const GRASS_FADE_START := 30.0
const GRASS_FADE_END := 43.0
const GRASS_NEAR_FADE_START := 7.0
const GRASS_NEAR_FADE_END := 11.0
## VEGR-4 blade tiers: near blades shrink out as mid-tier clumps grow in over the
## overlap, so the hand-off is a scale cross-fade (no alpha self-fade).
const BLADE_NEAR_FADE_START := 12.0
const BLADE_NEAR_FADE_END := 17.0
const BLADE_MID_FADE_IN_START := 9.0
const BLADE_MID_FADE_IN_END := 15.0
const BLADE_MID_FADE_START := 38.0
const BLADE_MID_FADE_END := 46.0
# Far tier: grows in as the mid tier shrinks out (38-46 m), gone by ~118 m.
const BLADE_FAR_FADE_IN_START := 36.0
const BLADE_FAR_FADE_IN_END := 48.0
const BLADE_FAR_FADE_START := 100.0
const BLADE_FAR_FADE_END := 118.0
const GRASS_BLADE_ATLAS := preload("res://assets/materials/pbr/grass_blades/grass_blades_atlas.png")
const BLACK_CLOAKS_BANNER_TEXTURE := preload("res://assets/heraldry/black_cloaks_banner.png")
## R-1194 leaf-cluster card atlas, drawn procedurally since R-1329
## (tools/assets/generate_vegetation_atlases.py; no image-generator source).
const LEAF_CARD_ATLAS := preload("res://assets/materials/pbr/foliage_cards/leaf_card_atlas.png")
const PropMaterials := preload("res://scripts/map/view3d/map_view_prop_materials.gd")
const LeafGeometry := preload("res://scripts/map/view3d/map_view_leaf_geometry.gd")

## Whole-tree flexibility (tree_wind.gdshaderinc `slender`): how far the crown top
## swings under the same load. Tall thin boles (pine, birch) reach 20-30 degrees in
## a storm gust; stout broadleaves bend less. Unlisted species use 1.0.
const TREE_SLENDER := {
	&"pine": 1.5, &"spruce": 1.15, &"birch": 1.3, &"alder": 1.1, &"willow": 1.2,
	&"linden": 0.95, &"maple": 0.95, &"ash": 1.0, &"elm": 0.95, &"oak": 0.85,
	&"juniper": 0.7, &"apple": 0.8,
}

static var _cache: Dictionary = {}
## Recent footfalls pressing the grass down (R-1327).
static var _trail := VegetationInteractionBuffer.new()
## R-1187: last calendar date and wetness pushed into vegetation. Kept here so a
## species canopy material created later (streamed chunk, reset cache) starts
## in the current season instead of the summer defaults.
static var _season_date: Dictionary = GameCalendar.DEFAULT_DATE.duplicate()
static var _vegetation_wetness := 0.0


static func reset() -> void:
	_cache.clear()
	_vegetation_wetness = 0.0


## The single writer of the shared wind field (R-1321). Grass, crowns, sails,
## flags, banners, ropes and nets read the `wind_*_g` shader globals through
## wind_field.gdshaderinc, so one call reaches every material at once,
## including ones a streamed chunk creates later. Call alongside sea-weather
## updates so vegetation and cloth match harbor boats.
static func apply_world_wind(direction: Vector2, strength: float) -> void:
	WindField.publish(WindField.params_for(direction, strength))


static func world_wind_direction() -> Vector2:
	return WindField.current().direction


static func world_wind_strength() -> float:
	return WindField.current().strength


## Materials whose shaders read the shared wind field (for tests and tools).
static func wind_materials() -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = _species_canopies()
	materials.append_array(_shared_wind_materials())
	return materials


static func _shared_wind_materials() -> Array[ShaderMaterial]:
	return [
		grass_blades(),
		grass_blades_near(),
		grass_blade_tier(true),
		grass_blade_tier(false),
		grass_blade_far(),
		canopy(&"spruce"),
		canopy(&"pine"),
		canopy(&"leaf"),
		canopy(&"column"),
		canopy(&"orchard"),
		sail_cloth(),
		flag_cloth(),
		flag_cloth(true),
		hanging_banner_cloth(),
		hanging_banner_cloth(BLACK_CLOAKS_BANNER_TEXTURE),
		hanging_banner_cloth(null, true),
		fishing_net_hemp(),
		fishing_net_float(),
		fishing_net_sinker(),
		hoist_rope_hemp(),
		hoist_rope_iron(),
	]


## Wind-swaying grass blade material; instance colors modulate the tint.
static func grass_blades() -> ShaderMaterial:
	return _grass_material("grass_blades", GRASS_FADE_START, GRASS_FADE_END)


## Eye-level ground cover (terrain details, 14 m cull): fades well inside it.
static func grass_blades_near() -> ShaderMaterial:
	return _grass_material("grass_blades_near", GRASS_NEAR_FADE_START, GRASS_NEAR_FADE_END)


## Real-geometry blade clumps (grass_blade_clump_mesh), no atlas: near tier within
## ~12 m of the player, mid tier beyond. Same shader as the tufts.
static func grass_blade_tier(near: bool) -> ShaderMaterial:
	if near:
		return _grass_material("grass_blade_near", BLADE_NEAR_FADE_START, BLADE_NEAR_FADE_END)
	return _grass_material(
		"grass_blade_mid", BLADE_MID_FADE_START, BLADE_MID_FADE_END,
		BLADE_MID_FADE_IN_START, BLADE_MID_FADE_IN_END
	)


## Sparse wide clumps beyond the mid tier (CityGrass far tier).
static func grass_blade_far() -> ShaderMaterial:
	return _grass_material(
		"grass_blade_far", BLADE_FAR_FADE_START, BLADE_FAR_FADE_END,
		BLADE_FAR_FADE_IN_START, BLADE_FAR_FADE_IN_END
	)


static func _grass_material(
	key: String, fade_start: float, fade_end: float, fade_in_start: float = 0.0,
	fade_in_end: float = 0.0
) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader_resource(
		"grass_character", MapViewMaterialShaders.GRASS_SHADER
	)
	material.set_shader_parameter("base_color", Color8(104, 130, 62))
	material.set_shader_parameter("blade_atlas", GRASS_BLADE_ATLAS)
	# Interaction starts off so maps without a player keep pure wind sway.
	material.set_shader_parameter("interact_strength", 0.0)
	material.set_shader_parameter("interact_radius", 0.65)
	material.set_shader_parameter("interact_center", Vector2.ZERO)
	material.set_shader_parameter("interact_push", Vector2.ZERO)
	material.set_shader_parameter("trail", empty_trail())
	material.set_shader_parameter("fade_start", fade_start)
	material.set_shader_parameter("fade_end", fade_end)
	material.set_shader_parameter("fade_in_start", fade_in_start)
	material.set_shader_parameter("fade_in_end", fade_in_end)
	_cache[key] = material
	return material


## Soft character parting for all grass MultiMeshes sharing grass_blades().
## center_xz / velocity_xz are world-space ground coordinates; tip displacement
## grows with speed so a walk opens a pocket and a run leaves a readable wake.
static func apply_grass_interaction(
	center_xz: Vector2, velocity_xz: Vector2, now: float = -1.0
) -> void:
	var speed := velocity_xz.length()
	var push := Vector2.ZERO
	if speed > 0.02:
		push = velocity_xz / speed
	# Standing still still parts blades around the feet; motion adds wake amplitude.
	var tip_displace := clampf(0.10 + speed * 0.015, 0.10, 0.22)
	for material in _grass_interaction_materials():
		material.set_shader_parameter("interact_center", center_xz)
		material.set_shader_parameter("interact_push", push)
		material.set_shader_parameter("interact_strength", tip_displace)
		material.set_shader_parameter("interact_radius", 0.65)
	# Footfalls stay pressed for a few seconds behind the walker (R-1327).
	var t := Time.get_ticks_msec() / 1000.0 if now < 0.0 else now
	if speed > 0.02:
		_trail.push(center_xz, velocity_xz, t)
	var trail := _trail.to_shader_array(t)
	for material in _grass_interaction_materials():
		material.set_shader_parameter("trail", trail)


static func empty_trail() -> PackedVector4Array:
	var out := PackedVector4Array()
	out.resize(VegetationInteractionBuffer.CAPACITY)
	return out


static func _grass_interaction_materials() -> Array[ShaderMaterial]:
	return [
		grass_blades(), grass_blades_near(), grass_blade_tier(true), grass_blade_tier(false),
		grass_blade_far(),
	]


## Clears character parting when no player rig is driving the view.
static func clear_grass_interaction() -> void:
	_trail.clear()
	for material in _grass_interaction_materials():
		material.set_shader_parameter("interact_strength", 0.0)
		material.set_shader_parameter("interact_push", Vector2.ZERO)
		material.set_shader_parameter("trail", empty_trail())


static func canopy(kind: StringName) -> ShaderMaterial:
	var key := "canopy:%s" % String(kind)
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader_resource(
		"canopy", MapViewMaterialShaders.CANOPY_SHADER
	)
	match kind:
		&"spruce":
			material.set_shader_parameter("base_color", Color8(58, 84, 56))
			material.set_shader_parameter("sway_strength", 0.035)
		&"pine":
			material.set_shader_parameter("base_color", Color8(72, 96, 52))
			material.set_shader_parameter("sway_strength", 0.03)
		&"column":
			material.set_shader_parameter("base_color", Color8(108, 132, 62))
			material.set_shader_parameter("sway_strength", 0.07)
		&"orchard":
			material.set_shader_parameter("base_color", Color8(92, 128, 60))
			material.set_shader_parameter("sway_strength", 0.075)
		_:
			material.set_shader_parameter("base_color", Color8(96, 118, 60))
			material.set_shader_parameter("sway_strength", 0.06)
	# Bound on the shared template so every species duplicate inherits it; bushes
	# have no card-tagged vertices and ignore its sampled value.
	material.set_shader_parameter("leaf_atlas", LEAF_CARD_ATLAS)
	material.set_shader_parameter("atlas_grid", LeafGeometry.CARD_ATLAS_GRID)
	_cache[key] = material
	return material


## Per-species tree crown material (R-1187). Same shader and kind tuning as
## canopy(kind), but one material per species so seasonal leaf density, size
## and autumn palette can differ between early birches and late oaks. Trees are
## already batched one MultiMesh per species, so this adds no draw calls.
static func canopy_for_species(species: StringName) -> ShaderMaterial:
	var key := "canopy_species:%s" % String(species)
	if _cache.has(key):
		return _cache[key]
	var template := canopy(MapViewTreeSpecies.canopy_material_kind(species))
	var material := template.duplicate() as ShaderMaterial
	material.set_meta(&"tree_species", species)
	_apply_tree_flexibility(material, species)
	material.set_shader_parameter("atlas_tile", LeafGeometry.card_tile(species))
	# Dense needle cards stack more translucent layers than broadleaf cards and
	# overexposed under the sun; a lower gain keeps conifers dark green.
	if species in [&"spruce", &"pine", &"juniper"]:
		material.set_shader_parameter("card_gain", 0.84)
	var palette := VegetationPhenology.autumn_colors(species)
	material.set_shader_parameter("autumn_color_a", palette[0])
	material.set_shader_parameter("autumn_color_b", palette[1])
	material.set_shader_parameter("wetness", _vegetation_wetness)
	_apply_season_to(material, species, _season_date)
	_cache[key] = material
	return material


## Swaying bark plate for city trunks and branches. Replaces
## MapViewPropMaterials.bark_plate on the city wood mesh so the wood moves with
## the crown: thin limbs (vertex alpha) far more than the bole. Textures come
## from the plain plate material so both stay in sync.
static func bark_plate_wind(plate: StringName, species: StringName = &"") -> ShaderMaterial:
	var key := "bark_wind:%s:%s" % [String(plate), String(species)]
	if _cache.has(key):
		return _cache[key]
	var plain := PropMaterials.bark_plate(plate)
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader_resource(
		"bark_wind", MapViewMaterialShaders.BARK_WIND_SHADER
	)
	material.set_shader_parameter("albedo_tex", plain.albedo_texture)
	material.set_shader_parameter("normal_tex", plain.normal_texture)
	material.set_shader_parameter("roughness_value", plain.get_meta(&"dry_roughness", plain.roughness))
	if species != &"":
		_apply_tree_flexibility(material, species)
	material.set_shader_parameter("wetness", _vegetation_wetness)
	_cache[key] = material
	return material


## Crown-top height (model units, from the shared city crown) and species
## flexibility, so bark and leaves bend with the same cantilever.
static func _apply_tree_flexibility(material: ShaderMaterial, species: StringName) -> void:
	var top := MapViewTreeMeshes.city_canopy_far_mesh(species).get_aabb().end.y
	material.set_shader_parameter("tree_top", maxf(top, 0.5))
	material.set_shader_parameter("slender", float(TREE_SLENDER.get(species, 1.0)))


## Pushes the campaign date into every tree crown. Cheap: one uniform set per
## species material, no mesh rebuild, and streamed chunks inherit it.
static func apply_vegetation_season(date: Dictionary) -> void:
	_season_date = GameCalendar.normalize_date(date)
	for material in _species_canopies():
		_apply_season_to(material, material.get_meta(&"tree_species"), _season_date)


static func vegetation_season_date() -> Dictionary:
	return _season_date.duplicate()


## Rain wetness for leaves (bark is handled by MapViewPropMaterials). Values are
## quantised so the per-frame weather fan-out does not touch uniforms needlessly.
static func apply_vegetation_wetness(wetness: float) -> void:
	var value := snappedf(clampf(wetness, 0.0, 1.0), 0.02)
	if is_equal_approx(value, _vegetation_wetness):
		return
	_vegetation_wetness = value
	for material in _species_canopies():
		material.set_shader_parameter("wetness", value)
	for key: String in _cache.keys():
		if key.begins_with("bark_wind:"):
			(_cache[key] as ShaderMaterial).set_shader_parameter("wetness", value)


static func _apply_season_to(
	material: ShaderMaterial, species: StringName, date: Dictionary
) -> void:
	var state := VegetationPhenology.state_for(species, date)
	material.set_shader_parameter("leaf_density", float(state["leaf_density"]))
	material.set_shader_parameter("leaf_scale", float(state["leaf_scale"]))
	material.set_shader_parameter("freshness", float(state["freshness"]))
	material.set_shader_parameter("autumn", float(state["autumn"]))
	material.set_shader_parameter("winter_dull", float(state["winter_dull"]))


static func _species_canopies() -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = []
	for key: String in _cache.keys():
		if key.begins_with("canopy_species:"):
			materials.append(_cache[key])
	return materials


## Merchant square sail: hangs free along UV.y from the yard, billows with wind.
static func sail_cloth() -> ShaderMaterial:
	var key := "sail_cloth"
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader_resource(
		"cloth", MapViewMaterialShaders.CLOTH_SHADER
	)
	material.set_shader_parameter("base_color", Color8(214, 208, 190))
	material.set_shader_parameter("sway_strength", 0.28)
	material.set_shader_parameter("free_edge", Vector2(0.0, 1.0))
	_cache[key] = material
	return material


## Tower pennants, gable flags, and other hoist-fixed cloth. The flag shader
## turns the cloth downwind about the staff, sags it in light air, and runs a
## travelling wave toward the fly (mesh contract in map_view_flag_cloth.gdshader).
## Vertex COLOR carries heraldry; base stays near-white so charges read.
## `srgb_vertex_color` is for meshes whose colors are authored in sRGB.
static func flag_cloth(srgb_vertex_color: bool = false) -> ShaderMaterial:
	var key := "flag_cloth_srgb" if srgb_vertex_color else "flag_cloth"
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader_resource(
		"flag_cloth", MapViewMaterialShaders.FLAG_CLOTH_SHADER
	)
	material.set_shader_parameter("base_color", Color8(248, 246, 240))
	material.set_shader_parameter("sway_strength", 0.42)
	material.set_shader_parameter("free_edge", Vector2(1.0, 0.0))
	material.set_shader_parameter("vertex_color_srgb", 1.0 if srgb_vertex_color else 0.0)
	_cache[key] = material
	return material


## Hoist rope and hook (R-1200): both surfaces of MapViewHoistRope share the
## pendulum shader so the hook stays on the rope end; only the look differs.
static func hoist_rope_hemp() -> ShaderMaterial:
	return _hoist_rope_material("hoist_rope_hemp", Color8(136, 116, 84), 0.95, 0.0, 1.0)


static func hoist_rope_iron() -> ShaderMaterial:
	return _hoist_rope_material("hoist_rope_iron", Color8(52, 48, 45), 0.62, 0.55, 0.0)


static func _hoist_rope_material(
	key: String, color: Color, roughness: float, metallic: float, lay: float
) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader_resource(
		"hoist_rope", MapViewMaterialShaders.HOIST_ROPE_SHADER
	)
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("roughness_value", roughness)
	material.set_shader_parameter("metallic_value", metallic)
	material.set_shader_parameter("specular_value", 0.5 if metallic > 0.0 else 0.3)
	material.set_shader_parameter("lay_pattern", lay)
	_cache[key] = material
	return material


## Vertical wall banners: pinned at the top rod, soft hem sway only.
## Pass an embroidered albedo for factions that ship a heraldry plate; otherwise
## vertex COLOR from FactionHeraldry.banner_mesh remains the charge source.
static func hanging_banner_cloth(
	albedo: Texture2D = null, srgb_vertex_color: bool = false
) -> ShaderMaterial:
	var keyed := "hanging_banner_cloth_textured" if albedo != null else "hanging_banner_cloth"
	if srgb_vertex_color:
		keyed += "_srgb"
	if _cache.has(keyed):
		return _cache[keyed]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader_resource(
		"hanging_banner_cloth", MapViewMaterialShaders.HANGING_BANNER_CLOTH_SHADER
	)
	material.set_shader_parameter("base_color", Color8(248, 246, 240))
	material.set_shader_parameter("sway_strength", 0.035)
	material.set_shader_parameter("free_edge", Vector2(0.0, 1.0))
	material.set_shader_parameter("vertex_color_srgb", 1.0 if srgb_vertex_color else 0.0)
	if albedo != null:
		material.set_shader_parameter("albedo_texture", albedo)
		material.set_shader_parameter("use_albedo_texture", 1.0)
	else:
		# Unbound sampler2D is undefined on GLES; bind a 1x1 white plate.
		material.set_shader_parameter("albedo_texture", _white_albedo())
		material.set_shader_parameter("use_albedo_texture", 0.0)
	_cache[keyed] = material
	return material


static func faction_banner_albedo(faction_id: StringName) -> Texture2D:
	if faction_id == &"black_cloaks":
		return BLACK_CLOAKS_BANNER_TEXTURE
	return null


static func _white_albedo() -> Texture2D:
	var key := "white_albedo_1x1"
	if _cache.has(key):
		return _cache[key]
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## The rack stays rigid while all net-borne parts share one height-pinned wind
## shader. Separate textured materials preserve their maritime identities while
## the common deformation keeps outline rope, floats, and sinkers attached.
static func fishing_net_hemp() -> ShaderMaterial:
	return _fishing_net_wind_material(
		&"fishing_net_hemp", FISHING_NET_HEMP_TEXTURE, 0.098, 1.36, 0.17, 0.96
	)


static func fishing_net_float() -> ShaderMaterial:
	return _fishing_net_wind_material(
		&"fishing_net_float", FISHING_NET_FLOAT_TEXTURE, 0.098, 1.36, 0.17, 0.94
	)


static func fishing_net_sinker() -> ShaderMaterial:
	return _fishing_net_wind_material(
		&"fishing_net_sinker", FISHING_NET_SINKER_TEXTURE, 0.098, 1.36, 0.17, 0.98
	)


static func _fishing_net_wind_material(
	key_name: StringName,
	albedo: Texture2D,
	sway_strength: float,
	pin_height: float,
	pin_fade: float,
	roughness: float
) -> ShaderMaterial:
	var key := String(key_name)
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader_resource(
		"fishing_net_wind", MapViewMaterialShaders.FISHING_NET_WIND_SHADER
	)
	material.set_shader_parameter("albedo_texture", albedo)
	material.set_shader_parameter("sway_strength", sway_strength)
	material.set_shader_parameter("pin_height", pin_height)
	material.set_shader_parameter("pin_fade", pin_fade)
	material.set_shader_parameter("surface_roughness", roughness)
	_cache[key] = material
	return material
