class_name MapViewDecals
extends RefCounted

## P0-157: Wear/grime/blood decal system for environmental storytelling.
## Flat transparent MeshInstance3D overlays placed from MapDefinition.decals.
## GL-Compatibility compatible: no Decal3D node, just projected quads with
## a soft-edge shader that multiplies authored alpha masks by DECAL_TINTS.

const MaterialShaders := preload("res://scripts/map/view3d/map_view_material_shaders.gd")
const MeshBuilderPrimitives := preload(
	"res://scripts/map/view3d/map_view_mesh_builder_primitives.gd"
)
const MeshBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder.gd")
const Bridge := preload("res://scripts/map/view3d/map_view_bridge.gd")

## Slight lift above sampled ground to avoid z-fighting while staying imperceptible.
const GROUND_LIFT := 0.015
const MASK_DIR := "res://assets/materials/decals"

static var _mask_cache: Dictionary = {}


static func _decal_quad_mesh(radius: float) -> ArrayMesh:
	var key := "decal_quad:%.2f" % radius
	if MeshBuilderPrimitives._mesh_cache.has(key):
		return MeshBuilderPrimitives._mesh_cache[key]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array(
		[
			Vector3(-radius, 0.0, -radius),
			Vector3(radius, 0.0, -radius),
			Vector3(radius, 0.0, radius),
			Vector3(-radius, 0.0, radius),
		]
	)
	var uvs := PackedVector2Array(
		[
			Vector2(0.0, 0.0),
			Vector2(1.0, 0.0),
			Vector2(1.0, 1.0),
			Vector2(0.0, 1.0),
		]
	)
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	MeshBuilderPrimitives._mesh_cache[key] = mesh
	return mesh


static func _mask_texture(kind: StringName) -> Texture2D:
	if _mask_cache.has(kind):
		return _mask_cache[kind]
	var path := "%s/%s.png" % [MASK_DIR, String(kind)]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_mask_cache[kind] = texture
	return texture


static func _decal_material(kind: StringName, tint: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = MaterialShaders.shader("wear_decal", MaterialShaders.WEAR_DECAL_SHADER_CODE)
	material.render_priority = -1
	material.set_shader_parameter("tint_color", tint)
	material.set_shader_parameter("soft_edge", 0.35)
	var mask := _mask_texture(kind)
	if mask != null:
		material.set_shader_parameter("mask_texture", mask)
	return material


static func build_decals(definition: MapDefinition, cell_size: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Decals"
	for decal in definition.decals:
		var node := _build_single(decal, definition, cell_size)
		if node != null:
			root.add_child(node)
	return root


static func _build_single(decal: Dictionary, definition: MapDefinition, cell_size: int) -> Node3D:
	var kind: StringName = decal.get("kind", &"")
	if kind not in MapTypes.ALL_DECAL_KINDS:
		return null
	var tint: Color = MapTypes.DECAL_TINTS.get(kind, Color(0.2, 0.2, 0.2, 0.3))
	# Override tint from authored data.
	if decal.has("tint"):
		tint = decal["tint"]
	var radius: float = decal.get("radius", MapTypes.DECAL_DEFAULT_RADIUS)
	var position_2d: Vector2 = decal["position"]
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Decal_%s" % String(decal.get("id", kind))
	mesh_instance.mesh = _decal_quad_mesh(radius)
	var world_pos := Bridge.logic_to_world(position_2d, cell_size)
	# WHY: cobble/dirt relief sits above y=0; a fixed micro-lift buries stains
	# under the terrain mesh. Snap to sampled ground like props do.
	var ground_y := MeshBuilder.ground_height(definition, Vector2(world_pos.x, world_pos.z))
	mesh_instance.position = Vector3(world_pos.x, ground_y + GROUND_LIFT, world_pos.z)
	if decal.has("rotation"):
		mesh_instance.rotation.y = decal["rotation"]
	# Shadow and GI off: decals are purely cosmetic overlays.
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mesh_instance.material_override = _decal_material(kind, tint)
	return mesh_instance


## Clear all decal children from a parent node.
static func clear(parent: Node3D) -> void:
	var decals := parent.get_node_or_null("Decals")
	if decals != null:
		parent.remove_child(decals)
		decals.free()
