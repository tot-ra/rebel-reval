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
const BLACK_CLOAKS_BANNER_TEXTURE := preload("res://assets/heraldry/black_cloaks_banner.png")

static var _cache: Dictionary = {}
## R-1187: last calendar date and wetness pushed into vegetation. Kept here so a
## species canopy material created later (streamed chunk, reset cache) starts
## in the current season instead of the summer defaults.
static var _season_date: Dictionary = GameCalendar.DEFAULT_DATE.duplicate()
static var _vegetation_wetness := 0.0
static var _world_wind_direction := Vector2(0.9285, 0.3714)
static var _world_wind_strength := 0.22


static func reset() -> void:
	_cache.clear()
	_vegetation_wetness = 0.0


## Pushes the shared world wind field into grass, canopy, sail, and flag cloth.
## Call alongside sea-weather updates so vegetation and cloth match harbor boats.
static func apply_world_wind(direction: Vector2, strength: float) -> void:
	var dir := direction
	if dir.length_squared() < 0.0001:
		dir = Vector2(0.9285, 0.3714)
	else:
		dir = dir.normalized()
	var wind := clampf(strength, 0.0, 1.0)
	_world_wind_direction = dir
	_world_wind_strength = wind
	for material in wind_materials():
		material.set_shader_parameter("wind_direction", dir)
		material.set_shader_parameter("wind_strength", wind)


static func world_wind_direction() -> Vector2:
	return _world_wind_direction


static func world_wind_strength() -> float:
	return _world_wind_strength


static func wind_materials() -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = _species_canopies()
	materials.append_array(_shared_wind_materials())
	return materials


static func _shared_wind_materials() -> Array[ShaderMaterial]:
	return [
		grass_blades(),
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
	]


## Wind-swaying grass blade material; instance colors modulate the tint.
static func grass_blades() -> ShaderMaterial:
	var key := "grass_blades"
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader_resource(
		"grass_character", MapViewMaterialShaders.GRASS_SHADER
	)
	material.set_shader_parameter("base_color", Color8(104, 130, 62))
	# Interaction starts off so maps without a player keep pure wind sway.
	material.set_shader_parameter("interact_strength", 0.0)
	material.set_shader_parameter("interact_radius", 0.65)
	material.set_shader_parameter("interact_center", Vector2.ZERO)
	material.set_shader_parameter("interact_push", Vector2.ZERO)
	_cache[key] = material
	return material


## Soft character parting for all grass MultiMeshes sharing grass_blades().
## center_xz / velocity_xz are world-space ground coordinates; tip displacement
## grows with speed so a walk opens a pocket and a run leaves a readable wake.
static func apply_grass_interaction(center_xz: Vector2, velocity_xz: Vector2) -> void:
	var material := grass_blades()
	var speed := velocity_xz.length()
	var push := Vector2.ZERO
	if speed > 0.02:
		push = velocity_xz / speed
	# Standing still still parts blades around the feet; motion adds wake amplitude.
	var tip_displace := clampf(0.10 + speed * 0.015, 0.10, 0.22)
	material.set_shader_parameter("interact_center", center_xz)
	material.set_shader_parameter("interact_push", push)
	material.set_shader_parameter("interact_strength", tip_displace)
	material.set_shader_parameter("interact_radius", 0.65)


## Clears character parting when no player rig is driving the view.
static func clear_grass_interaction() -> void:
	var material := grass_blades()
	material.set_shader_parameter("interact_strength", 0.0)
	material.set_shader_parameter("interact_push", Vector2.ZERO)


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
	var palette := VegetationPhenology.autumn_colors(species)
	material.set_shader_parameter("autumn_color_a", palette[0])
	material.set_shader_parameter("autumn_color_b", palette[1])
	material.set_shader_parameter("wind_direction", _world_wind_direction)
	material.set_shader_parameter("wind_strength", _world_wind_strength)
	material.set_shader_parameter("wetness", _vegetation_wetness)
	_apply_season_to(material, species, _season_date)
	_cache[key] = material
	return material


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
	material.set_shader_parameter("wind_strength", 0.08)
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
