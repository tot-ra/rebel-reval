extends SceneTree

## WB-07d (R-1010) texture parity. Builds each map through the staged assembly
## path (worker bakes where the checkout has them), then prints one line per
## texture slot under Terrain and Surroundings: node path, slot and the SHA-256
## of the texture bytes. Run it in two checkouts and diff the output to prove a
## change left every generated texture byte-identical.
##
## Usage:
##   godot --headless --path . --script tools/benchmarks/material_texture_hashes.gd \
##     -- --output=build/benchmarks/material_texture_hashes.txt
## Headless (dummy renderer) cannot read Texture2DArray layers back; those slots
## print "layers=<count>" instead. Run through tools/godot_render.sh to hash them.

const DEFAULT_OUTPUT := "res://build/benchmarks/material_texture_hashes.txt"
const MAP_SCRIPTS: Array[String] = [
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd",
	"res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd",
]
const ROOTS: Array[String] = ["Terrain", "Surroundings"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var lines: Array[String] = []
	for path in MAP_SCRIPTS:
		var definition: MapDefinition = load(path).create()
		var grid := MapBuilder.build(definition)
		var view := MapView3D.create_staged(definition, grid)
		await view.assemble_async(4.0)
		for root_name in ROOTS:
			var root := view.get_node_or_null(root_name)
			if root != null:
				_collect(String(definition.map_id), root, root, lines)
		view.free()
	var output_path := DEFAULT_OUTPUT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path).get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("TEXTURE_HASHES %d slots -> %s" % [lines.size(), output_path])
	quit(0)


static func _collect(map_id: String, base: Node, node: Node, lines: Array[String]) -> void:
	var where := "%s/%s" % [map_id, base.get_path_to(node)]
	if node is GeometryInstance3D:
		_material_lines(where, "override", (node as GeometryInstance3D).material_override, lines)
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			_material_lines(where, "surface%d" % surface, mesh.surface_get_material(surface), lines)
	if node is MultiMeshInstance3D:
		var multi := (node as MultiMeshInstance3D).multimesh
		if multi != null and multi.mesh != null:
			for surface in multi.mesh.get_surface_count():
				_material_lines(
					where, "multi%d" % surface, multi.mesh.surface_get_material(surface), lines
				)
	for child in node.get_children():
		_collect(map_id, base, child, lines)


static func _material_lines(
	where: String, slot: String, material: Material, lines: Array[String]
) -> void:
	if material == null:
		return
	if material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		for texture_slot: String in ["albedo_texture", "normal_texture"]:
			var texture: Texture = base.get(texture_slot)
			if texture != null:
				lines.append("%s %s.%s %s" % [where, slot, texture_slot, _hash(texture)])
	elif material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		if shader_material.shader == null:
			return
		for uniform: Dictionary in shader_material.shader.get_shader_uniform_list():
			var value: Variant = shader_material.get_shader_parameter(uniform["name"])
			if value is Texture:
				lines.append("%s %s.%s %s" % [where, slot, uniform["name"], _hash(value)])


static func _hash(texture: Texture) -> String:
	if texture is Texture2D:
		var image := (texture as Texture2D).get_image()
		return _image_hash(image)
	if texture is TextureLayered:
		var layered := texture as TextureLayered
		var parts: Array[String] = []
		for layer in layered.get_layers():
			parts.append(_image_hash(layered.get_layer_data(layer)))
		if parts.has("none"):
			return "layers=%d" % layered.get_layers()
		return "layers:" + ",".join(parts)
	return "unhashed:%s" % texture.get_class()


static func _image_hash(image: Image) -> String:
	if image == null or image.is_empty():
		return "none"
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(("%dx%d:%d:%s" % [
		image.get_width(), image.get_height(), image.get_format(), image.has_mipmaps()
	]).to_utf8_buffer())
	context.update(image.get_data())
	return context.finish().hex_encode().substr(0, 16)
