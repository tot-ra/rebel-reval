class_name MapViewKalevSmithyInterior
extends RefCounted

## Authored room shell, loft ceiling, and forge kit for Kalev's smithy.
##
## WHY: the generic interior-wall path dressed every wall with one plinth,
## rail and post grid under a flat plank lid, so the smithy read as a modern
## panelled box. The kit from tools/assets/generate_kalev_smithy_interior.py
## models the room from the smithy dossier instead (limestone fire wall, sooted
## rubble forge bay, limewashed living bay, splayed shuttered windows, oak loft
## on girders, raised hearth under a clay hood). It is presentation only: the
## rrmap walls, props and transitions stay the collision, navigation and
## interaction authority, so this class never adds or moves gameplay nodes.
##
## GLB surfaces arrive as untextured `ksi_<surface>` materials with soot and
## wear in COLOR_0; apply_materials() swaps them for the shared photoreal PBR
## plates with world triplanar mapping so masonry courses stay continuous
## across separately exported pieces.

const MAP_ID := &"kalev_smithy"
const INTERIOR_DIR := "res://assets/props/architecture/interiors"
const FORGE_DIR := "res://assets/props/forge"
const SHELL_PATH := INTERIOR_DIR + "/kalev_smithy_shell/kalev_smithy_shell.glb"
const CEILING_PATH := INTERIOR_DIR + "/kalev_smithy_ceiling/kalev_smithy_ceiling.glb"
const HEARTH_PATH := FORGE_DIR + "/kalev_smithy_hearth/kalev_smithy_hearth.glb"
const ANVIL_PATH := FORGE_DIR + "/kalev_smithy_anvil/kalev_smithy_anvil.glb"
const BELLOWS_PATH := FORGE_DIR + "/kalev_smithy_bellows/kalev_smithy_bellows.glb"
const SLACK_TUB_PATH := FORGE_DIR + "/kalev_smithy_slack_tub/kalev_smithy_slack_tub.glb"
const STOCK_RACK_PATH := FORGE_DIR + "/kalev_smithy_stock_rack/kalev_smithy_stock_rack.glb"
const SCRAP_HEAP_PATH := FORGE_DIR + "/kalev_smithy_scrap_heap/kalev_smithy_scrap_heap.glb"
const FINISHING_BENCH_PATH := (
	FORGE_DIR + "/kalev_smithy_finishing_bench/kalev_smithy_finishing_bench.glb"
)
const TEXTURE_DIR := INTERIOR_DIR + "/kalev_smithy_shell/textures"
const SHELL_NODE := &"AuthoredInterior"
const WINDOW_PANE_PREFIX := "WindowPane_"
## Children of a streamed interior-wall node that must survive: the hidden box
## still feeds MapView3D occlusion bounds for the actor silhouette probe.
const WALL_PROXY_NODE := &"Walls"
## Generic transition infill the shell's stone reveal replaces.
const DOOR_INFILL_NODES: Array[StringName] = [&"OpeningJambL", &"OpeningJambR", &"OpeningHead"]
const HAND_TOOL_KINDS: Array[StringName] = [
	MapTypes.PROP_KIND_BLACKSMITH_TONGS,
	MapTypes.PROP_KIND_BLACKSMITH_HAMMER,
	MapTypes.PROP_KIND_BLACKSMITH_PUNCH,
]
const HAND_TOOL_MATERIALS := {
	"HammeredToolIron": "ksi_iron",
	"PolishedToolEdge": "ksi_iron_bright",
	"ToolAshWood": "ksi_oak",
}
## Fire pot centre in hearth-prop space (FIRE_POT_LOCAL in the generator).
const FIRE_POT := Vector3(-0.2, 0.72, -0.2)

const PBR := "res://assets/materials/pbr"
const LIMESTONE_ALBEDO := PBR + "/limestone_rubble/limestone_rubble_albedo.png"
const LIMESTONE_NORMAL := TEXTURE_DIR + "/limestone_rubble_normal.png"
const PLASTER_ALBEDO := PBR + "/plaster/plaster_albedo.png"
const PLASTER_NORMAL := PBR + "/plaster/plaster_normal.png"
const PLASTER_ROUGHNESS := PBR + "/plaster/plaster_roughness.png"
const TIMBER_ALBEDO := PBR + "/timber/timber_albedo.png"
const TIMBER_NORMAL := PBR + "/timber/timber_normal.png"
const TIMBER_ROUGHNESS := PBR + "/timber/timber_roughness.png"
const BOARDS_ALBEDO := PBR + "/timber_floor/timber_floor_albedo.png"
const BOARDS_NORMAL := TEXTURE_DIR + "/timber_floor_normal.png"
const EARTH_ALBEDO := TEXTURE_DIR + "/beaten_earth_albedo.png"
const EARTH_NORMAL := TEXTURE_DIR + "/beaten_earth_normal.png"
const SLAB_ALBEDO := PBR + "/smithy_floor/smithy_floor_albedo.png"
const SLAB_NORMAL := TEXTURE_DIR + "/smithy_floor_normal.png"
const HAY_ALBEDO := PBR + "/hay/hay_albedo.png"
const HAY_NORMAL := PBR + "/hay/hay_normal.png"
const METERS_PER_WORLD_UNIT := 0.87

static var _materials: Dictionary = {}


static func applies_to(definition: MapDefinition) -> bool:
	return definition != null and definition.map_id == MAP_ID


## Adds the room shell to the view and swaps the generic ceiling slab and beams
## inside InteriorShell for the authored loft. The new "Ceiling" keeps the
## generic node name so camera-mode visibility and close-camera checks still
## find it; DaylightOccluder stays untouched as the roof shadow caster.
static func install(view: Node3D, interior_shell: Node3D) -> void:
	var shell := _instantiate(SHELL_PATH, SHELL_NODE)
	view.add_child(shell)
	if interior_shell == null:
		return
	var ceiling_visible := true
	var generic_ceiling := interior_shell.get_node_or_null("Ceiling") as Node3D
	if generic_ceiling != null:
		ceiling_visible = generic_ceiling.visible
	for child in interior_shell.get_children():
		if child.name != &"DaylightOccluder":
			interior_shell.remove_child(child)
			child.free()
	var ceiling := _instantiate(CEILING_PATH, &"Ceiling")
	# The loft never casts sun shadow; the DaylightOccluder twin owns that.
	for mesh in ceiling.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ceiling.visible = ceiling_visible
	interior_shell.add_child(ceiling)


## Interior-wall buildings keep only an invisible proxy box: the authored shell
## draws the masonry, and the proxy still reports the wall AABB to occlusion.
static func adapt_building(source: Dictionary, node: Node3D) -> void:
	if StringName(source.get("kind", &"")) != MapTypes.BUILDING_KIND_INTERIOR_WALL:
		return
	for child in node.get_children():
		if child.name == WALL_PROXY_NODE and child is GeometryInstance3D:
			var proxy := child as GeometryInstance3D
			proxy.visible = false
			proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		node.remove_child(child)
		child.free()


## Window landmarks lose the generic sill/frame/infill and get their glowing pane
## refitted into the authored embrasure; InteriorWindowLights is rebuilt so the
## daylight spot and dust shaft start from the new pane.
static func adapt_landmark(view: Node3D, source: Dictionary, node: Node3D) -> void:
	if StringName(source.get("kind", &"")) != &"interior_window":
		return
	var marker := view.get_node_or_null(
		"%s/%s%s" % [SHELL_NODE, WINDOW_PANE_PREFIX, String(source.get("id", "")).replace(".", "_")]
	) as Node3D
	if marker == null:
		return
	var old_glass := node.get_node_or_null("Window0") as MeshInstance3D
	var glass_material: Material = null
	if old_glass != null:
		glass_material = old_glass.material_override
	for child in node.get_children():
		node.remove_child(child)
		child.free()
	var pane := MeshInstance3D.new()
	pane.name = "Window0"
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	pane.mesh = mesh
	# Marker scale encodes the pane size; both live in map world space.
	pane.transform = node.transform.affine_inverse() * marker.transform
	pane.material_override = (
		glass_material if glass_material != null else MapViewMaterials.role(&"window")
	)
	node.add_child(pane)
	var lights = MapViewMeshBuilderConfig.INTERIOR_WINDOW_LIGHTS_SCRIPT.new()
	lights.configure_from(node)
	node.add_child(lights)


## The shared hand-tool GLBs carry their own polished-steel look, which reads
## as bright blue plastic under the forge's warm light. In this room they take
## the kit's wrought iron and ash so tools, rack and anvil match.
static func adapt_prop(source: Dictionary, node: Node3D) -> void:
	if not StringName(source.get("kind", &"")) in HAND_TOOL_KINDS:
		return
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source_material := mesh_instance.mesh.surface_get_material(surface)
			if source_material == null:
				continue
			var key := String(HAND_TOOL_MATERIALS.get(source_material.resource_name, ""))
			if not key.is_empty():
				mesh_instance.set_surface_override_material(surface, material_for(key))


static func adapt_door(door: Node3D) -> void:
	for node_name in DOOR_INFILL_NODES:
		var infill := door.get_node_or_null(NodePath(String(node_name)))
		if infill != null:
			door.remove_child(infill)
			infill.free()


## Instantiates one kit GLB with the smithy materials applied.
static func instantiate_prop(path: String, node_name: StringName) -> Node3D:
	return _instantiate(path, node_name)


static func _instantiate(path: String, node_name: StringName) -> Node3D:
	var scene := MapViewPackedScenes.load_scene(path)
	assert(scene != null, "Kalev smithy kit %s must be imported before assembly" % path)
	var node := scene.instantiate() as Node3D
	node.name = node_name
	apply_materials(node)
	return node


static func apply_materials(root: Node) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface)
			if source == null:
				continue
			var key := source.resource_name
			if not key.begins_with("ksi_"):
				continue
			mesh_instance.set_surface_override_material(surface, material_for(key))


static func material_for(key: String) -> Material:
	if _materials.has(key):
		return _materials[key]
	var material: StandardMaterial3D
	match key:
		"ksi_limestone":
			# ~1.4 m per plate keeps rubble courses near 0.2 m, like Reval's
			# thin-bedded Ordovician limestone rather than big dressed blocks.
			material = _plate(LIMESTONE_ALBEDO, LIMESTONE_NORMAL, "", 1.4, 0.94)
			material.normal_scale = 0.9
		"ksi_limewash":
			material = _plate(PLASTER_ALBEDO, PLASTER_NORMAL, PLASTER_ROUGHNESS, 1.8, 0.95)
			material.normal_scale = 1.2
		"ksi_oak":
			material = _grain(TIMBER_ALBEDO, TIMBER_NORMAL, TIMBER_ROUGHNESS, 1.4, 0.82)
		"ksi_boards":
			# The board-seamless plate spans 4 whole boards; 1.2 m keeps the
			# ~0.3 m board width the old 6-board 1.8 m plate had.
			material = _grain(BOARDS_ALBEDO, BOARDS_NORMAL, "", 1.2, 0.78)
		"ksi_earth":
			# Beaten clay and charcoal dust from a Leonardo plate made seamless
			# offline; COLOR_0 adds the dust plume, scale ring and trodden path.
			material = _plate(EARTH_ALBEDO, EARTH_NORMAL, "", 2.4, 0.96)
			material.metallic_specular = 0.25
		"ksi_slab":
			material = _plate(SLAB_ALBEDO, SLAB_NORMAL, "", 3.4, 0.9)
		"ksi_straw":
			material = _plate(HAY_ALBEDO, HAY_NORMAL, "", 0.9, 0.95)
		"ksi_clay":
			# Hood daub and hearth lining are lime-washed clay; the photoreal
			# plaster plate keeps them in the same register as the walls.
			material = _plate(PLASTER_ALBEDO, PLASTER_NORMAL, PLASTER_ROUGHNESS, 1.6, 0.96)
			material.albedo_color = Color(0.93, 0.86, 0.78)
		"ksi_iron":
			material = _flat(Color8(58, 58, 60), 0.62, 0.6)
		"ksi_iron_bright":
			material = _flat(Color8(128, 128, 132), 0.3, 0.88)
		"ksi_leather":
			# The bellows bag is the only large soft surface in the bay. The
			# shared prop leather is cut for daylight props at (0.36, 0.23, 0.13);
			# under the hearth's saturated orange key its green and blue channels
			# fall below one 8-bit step, so the bag rendered as a flat red-black
			# blob. Oiled ox-hide is far paler than that, and the lighter base
			# keeps hue separation in firelight.
			material = (MapViewMaterials.leather().duplicate() as StandardMaterial3D)
			material.albedo_color = Color8(104, 84, 68)
			material.roughness = 0.76
		"ksi_charcoal":
			material = (MapViewMaterials.charcoal().duplicate() as StandardMaterial3D)
		"ksi_ash":
			material = _flat(Color8(120, 116, 110), 1.0, 0.0)
		"ksi_water":
			material = _flat(Color8(10, 12, 12), 0.05, 0.0)
			material.metallic_specular = 0.75
		_:
			material = _flat(Color8(6, 5, 5), 1.0, 0.0)
	material.resource_name = key
	material.vertex_color_use_as_albedo = true
	_materials[key] = material
	return material


## Photoreal plate projected in world space; `plate_metres` is the real span one
## repeat of the plate covers, converted to repeats per world unit.
static func _plate(
	albedo: String, normal: String, roughness: String, plate_metres: float, rough: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(albedo)
	if not normal.is_empty():
		material.normal_enabled = true
		material.normal_texture = load(normal)
	material.roughness = rough
	if not roughness.is_empty():
		material.roughness_texture = load(roughness)
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
		# Godot multiplies the plate into `roughness`, so keeping the scalar here
		# double-darkened it: the timber plate averages 0.42 and dropped to 0.35
		# against 0.82, which lacquered every beam and shelf. MapViewMaterials
		# already treats the plate as the sole authority; match that.
		material.roughness = 1.0
	# Nothing in a working smithy is polished: soot and hearth dust kill the
	# specular lobe on limestone, plaster and oak alike.
	material.metallic_specular = 0.3
	var density := METERS_PER_WORLD_UNIT / plate_metres
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_triplanar_sharpness = 6.0
	material.uv1_scale = Vector3(density, density, density)
	return material


## Wood follows the GLB's grain-aligned UVs (metres) instead of triplanar, so
## the plate's grain runs along every beam, board and haft.
static func _grain(
	albedo: String, normal: String, roughness: String, plate_metres: float, rough: float
) -> StandardMaterial3D:
	var material := _plate(albedo, normal, roughness, plate_metres, rough)
	material.uv1_triplanar = false
	material.uv1_world_triplanar = false
	var density := 1.0 / plate_metres
	material.uv1_scale = Vector3(density, density, 1.0)
	return material


static func _flat(color: Color, rough: float, metal: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	material.metallic = metal
	return material
