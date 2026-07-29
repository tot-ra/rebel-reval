class_name CatCoatVariants
extends RefCounted

## Coat and size variation for the shared forge-cat model.
##
## Every cat in Reval is the same production GLB. Rather than ship six meshes,
## the build bakes one albedo per coat over the same UVs, and this adapter swaps
## the base colour map (keeping the shared normal and roughness maps) plus a
## small deterministic size jitter. Kalev's smithy cat keeps the embedded forge
## coat; the town cats draw from the rest.

const TEX_DIR := "res://generated/comfyui/forge_cat_hunyuan3d_v1/production/tex"
const NORMAL_TEXTURE := TEX_DIR + "/forge_cat_normal.png"
const ROUGHNESS_TEXTURE := TEX_DIR + "/forge_cat_roughness.png"

const COAT_FORGE := &"forge"
const FACE_MESH_PREFIX := "ForgeCatFace"

## Historically plausible unimproved medieval European coats: mackerel tabby is
## the common wild type, with self-black, red and bicolour beside it.
const TOWN_COATS: Array[StringName] = [
	&"tabby_brown",
	&"tabby_grey",
	&"black",
	&"ginger",
	&"white_black",
]

const SCALE_RANGE := Vector2(0.90, 1.10)


static func coat_texture_path(coat: StringName) -> String:
	if coat == COAT_FORGE:
		return ""
	return "%s/coats/forge_cat_albedo_%s.png" % [TEX_DIR, coat]


static func coat_for_seed(variant_seed: int) -> StringName:
	return TOWN_COATS[absi(variant_seed) % TOWN_COATS.size()]


static func scale_for_seed(variant_seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant_seed
	return rng.randf_range(SCALE_RANGE.x, SCALE_RANGE.y)


## Dresses an instantiated cat model in one coat and body size. Returns the coat
## that was applied, or an empty name when the model carried no mesh.
static func apply(model: Node3D, variant_seed: int) -> StringName:
	if model == null:
		return &""
	var meshes := body_meshes(model)
	if meshes.is_empty():
		return &""
	var coat := coat_for_seed(variant_seed)
	var material := build_material(coat)
	if material != null:
		for mesh in meshes:
			mesh.material_override = material
	var body_scale := scale_for_seed(variant_seed)
	model.scale = Vector3.ONE * body_scale
	model.set_meta(&"cat_coat", coat)
	model.set_meta(&"cat_scale", body_scale)
	return coat


## Fur meshes only. The GLB also carries a face mesh (eyes, slit pupils, nose
## leather, whiskers) whose own materials must survive a coat swap.
static func body_meshes(model: Node3D) -> Array[MeshInstance3D]:
	var bodies: Array[MeshInstance3D] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if String(node.name).begins_with(FACE_MESH_PREFIX):
			continue
		bodies.append(node as MeshInstance3D)
	return bodies


static func build_material(coat: StringName) -> StandardMaterial3D:
	var albedo_path := coat_texture_path(coat)
	if albedo_path.is_empty() or not ResourceLoader.exists(albedo_path):
		return null
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(albedo_path)
	material.metallic = 0.0
	if ResourceLoader.exists(NORMAL_TEXTURE):
		material.normal_enabled = true
		material.normal_texture = load(NORMAL_TEXTURE)
		material.normal_scale = 0.8
	if ResourceLoader.exists(ROUGHNESS_TEXTURE):
		material.roughness_texture = load(ROUGHNESS_TEXTURE)
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	else:
		material.roughness = 0.82
	return material
