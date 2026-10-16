extends RefCounted

## ADR 0045 winter ice: binds the CC0 lake-ice scans to a material whose shader
## includes ice_surface.gdshaderinc with ICE_PHOTO defined (moat, stream, lakes and
## the sea). Packed by tools/assets/pack_lake_ice_textures.py; rows in
## assets/SOURCES.csv.

const CLEAR := preload("res://assets/materials/pbr/lake_ice/lake_ice_clear_albedo_rough.png")
const MILKY := preload("res://assets/materials/pbr/lake_ice/lake_ice_milky_albedo_rough.png")
const NORMALS := preload("res://assets/materials/pbr/lake_ice/lake_ice_normals.png")
const SNOW_NORMAL := preload("res://assets/materials/pbr/lake_ice/snow_crust_normal.png")


static func bind(material: ShaderMaterial) -> void:
	material.set_shader_parameter("ice_clear_tex", CLEAR)
	material.set_shader_parameter("ice_milky_tex", MILKY)
	material.set_shader_parameter("ice_normal_tex", NORMALS)
	material.set_shader_parameter("ice_snow_normal_tex", SNOW_NORMAL)
