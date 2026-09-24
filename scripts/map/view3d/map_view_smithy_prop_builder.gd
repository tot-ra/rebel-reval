class_name MapViewSmithyPropBuilder
extends RefCounted

const AnvilMeshes := preload("res://scripts/map/view3d/map_view_anvil_meshes.gd")
const Primitives := preload("res://scripts/map/view3d/map_view_mesh_builder_primitives.gd")

# Runtime loading avoids a clean-clone bootstrap cycle where GDScript parses
# before Godot has registered the first GLB import.
const _ANVIL_SCENE_PATH := "res://assets/props/forge/smithy_anvil/smithy_anvil.glb"
const ANVIL_PROP_ID := &"forge_anvil"
const _FURNACE_SCENE_PATH := "res://assets/props/forge/smithy_furnace/smithy_furnace.glb"
const FURNACE_PROP_ID := &"forge_furnace"
const _BELLOWS_SCENE_PATH := "res://assets/props/forge/smithy_bellows/smithy_bellows.glb"
const BELLOWS_PROP_ID := &"forge_bellows"
const _CHAIR_SCENE_PATH := "res://assets/props/furniture/smithy_chair/smithy_chair.glb"
const CHAIR_PROP_ID := &"work_chair"
## Seating in Kalev's dwelling shares the one authored chair GLB. Town Hall and
## other civic chairs stay on the neutral fallback until they get their own art.
const CHAIR_PROP_IDS: Array[StringName] = [
	CHAIR_PROP_ID,
	&"kitchen_stool",
	&"table_stool_west",
	&"table_stool_east",
]
const _QUENCH_SCENE_PATH := "res://assets/props/forge/smithy_quench_bucket/smithy_quench_bucket.glb"
const QUENCH_PROP_ID := &"quench"
const _BED_SCENE_PATH := "res://assets/props/furniture/smithy_bed/smithy_bed.glb"
const BED_PROP_ID := &"bed"

## Authored Kalev smithy workstation props and procedural fallbacks for other maps.


static func add_smithy_bed(root: Node3D) -> void:
	# WHY: this close interior rest landmark needs period joinery and soft bedding,
	# while gameplay collision, navigation, and interaction remain owned by rrmap.
	var bed_scene := load(_BED_SCENE_PATH) as PackedScene
	assert(bed_scene != null, "Smithy bed GLB must be imported before the map view is assembled")
	var bed := bed_scene.instantiate() as Node3D
	bed.name = "SmithyBedModel"
	root.add_child(bed)


static func add_bed_fallback(root: Node3D) -> void:
	# Other maps can continue using the lightweight neutral bed until they receive
	# authored furniture matched to their location and status.
	Primitives.box(
		root, "Frame", Vector3(2.4, 0.38, 1.35), Vector3(0.0, 0.19, 0.0), &"wood"
	)
	Primitives.box(
		root, "Mattress", Vector3(2.2, 0.16, 1.2), Vector3(0.0, 0.46, 0.0), &"plaster"
	)
	Primitives.box(
		root, "Pillow", Vector3(0.42, 0.14, 0.72), Vector3(-0.82, 0.58, 0.0), &"hay"
	)


static func add_smithy_chair(root: Node3D) -> void:
	# WHY: the smithy's authored chair is a close, recurring interior prop. A
	# dedicated GLB gives it readable joinery while collision/navigation remain on
	# the immutable 2D map definition, just like every other view-only prop.
	var chair_scene := load(_CHAIR_SCENE_PATH) as PackedScene
	assert(
		chair_scene != null, "Smithy chair GLB must be imported before the map view is assembled"
	)
	var chair := chair_scene.instantiate() as Node3D
	chair.name = "SmithyChairModel"
	root.add_child(chair)


static func add_chair_fallback(root: Node3D) -> void:
	# Town Hall chairs share the generic map kind but need a separate high-status
	# model later, so they deliberately keep the neutral procedural fallback.
	Primitives.box(
		root, "Seat", Vector3(0.5, 0.08, 0.45), Vector3(0.0, 0.42, 0.0), &"wood"
	)
	Primitives.box(
		root, "Back", Vector3(0.48, 0.5, 0.06), Vector3(0.0, 0.72, -0.18), &"timber"
	)
	Primitives.box(
		root, "LegFL", Vector3(0.06, 0.4, 0.06), Vector3(-0.18, 0.2, 0.14), &"timber"
	)
	Primitives.box(
		root, "LegFR", Vector3(0.06, 0.4, 0.06), Vector3(0.18, 0.2, 0.14), &"timber"
	)


static func add_smithy_anvil(root: Node3D) -> void:
	# WHY: forge_anvil is the close, gameplay-critical smithy workstation. Its
	# authored GLB improves silhouette and materials while the immutable rrmap
	# footprint remains the sole collision/navigation authority.
	var anvil_scene := load(_ANVIL_SCENE_PATH) as PackedScene
	assert(
		anvil_scene != null, "Smithy anvil GLB must be imported before the map view is assembled"
	)
	var anvil := anvil_scene.instantiate() as Node3D
	anvil.name = "SmithyAnvilModel"
	root.add_child(anvil)


static func add_anvil_fallback(root: Node3D) -> void:
	# Outdoor and future anvils keep the lightweight procedural model until they
	# receive location-specific art; this prevents smithy wear from leaking out.
	Primitives.cylinder(
		root, "Stump", 0.28, 0.42, Vector3(0.0, 0.21, 0.0), &"wood"
	)
	Primitives.cylinder(
		root, "StumpBand", 0.295, 0.045, Vector3(0.0, 0.34, 0.0), &"metal"
	)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = AnvilMeshes.body_mesh()
	# Mesh local Y already includes the standing height above the stump crown.
	body.position = Vector3(0.0, 0.42, 0.0)
	body.material_override = Primitives.role_material(&"metal")
	root.add_child(body)


static func add_smithy_furnace(root: Node3D) -> void:
	# WHY: forge_furnace is a close hero prop, but its rrmap footprint must remain
	# the sole collision/navigation authority. The GLB replaces only the masonry;
	# live embers, particles, and day/night fire lighting remain engine-driven.
	var furnace_scene := load(_FURNACE_SCENE_PATH) as PackedScene
	assert(
		furnace_scene != null,
		"Smithy furnace GLB must be imported before the map view is assembled"
	)
	var furnace := furnace_scene.instantiate() as Node3D
	furnace.name = "SmithyFurnaceModel"
	root.add_child(furnace)
	_add_furnace_ember_bed(root)
	_add_furnace_coal_bed(root)
	var flames := _add_furnace_flames(root)
	var particles := _add_furnace_fire_particles(root)
	var smoke := _add_furnace_smoke_particles(root)
	var forge_light := OmniLight3D.new()
	forge_light.name = "Omni"
	forge_light.position = Vector3(0.0, 0.7, 0.85)
	root.add_child(forge_light)
	var controller = MapViewMeshBuilderConfig.FORGE_FIRE_LIGHT_SCRIPT.new()
	controller.configure(forge_light, flames, particles, smoke)
	root.add_child(controller)


static func add_furnace_fallback(root: Node3D) -> void:
	# Open-mouth masonry forge: rear bulk + cheeks + lintel leave a real cavity
	# so red coal and flame read from the working bay (not a solid black box).
	Primitives.box(
		root, "Mass", Vector3(2.4, 1.55, 1.35), Vector3(0.0, 0.78, -0.22), &"stone"
	)
	Primitives.box(
		root, "LeftCheek", Vector3(0.38, 1.05, 1.05), Vector3(-0.92, 0.62, 0.52), &"stone"
	)
	Primitives.box(
		root, "RightCheek", Vector3(0.38, 1.05, 1.05), Vector3(0.92, 0.62, 0.52), &"stone"
	)
	Primitives.box(
		root, "Lintel", Vector3(1.55, 0.32, 1.05), Vector3(0.0, 1.3, 0.52), &"stone"
	)
	Primitives.box(
		root, "HearthShelf", Vector3(1.55, 0.18, 1.0), Vector3(0.0, 0.16, 0.58), &"stone"
	)
	Primitives.box(
		root, "Breast", Vector3(2.1, 0.5, 0.7), Vector3(0.0, 1.7, 0.18), &"stone"
	)
	# Sooted cavity back sits deep inside the mouth, not as a front-facing plug.
	Primitives.box(
		root, "Firebox", Vector3(1.35, 0.85, 0.14), Vector3(0.0, 0.72, 0.05), &"ink"
	)
	# Bright ember bed fills the hearth floor so the mouth always shows heat.
	_add_furnace_ember_bed(root)
	_add_furnace_coal_bed(root)
	var flames := _add_furnace_flames(root)
	var particles := _add_furnace_fire_particles(root)
	var smoke := _add_furnace_smoke_particles(root)
	# Tuyere stub on the left cheek - bellows nozzle aims here (axis along X).
	_add_axis_cylinder(root, "Tuyere", 0.06, 0.42, Vector3(-1.15, 0.48, 0.55), &"metal")
	# Flue seats into the breast and clears the interior ceiling plane.
	Primitives.add_chimney_stack(
		root, "Chimney", 0.58, 2.35, Vector3(0.0, 1.85, -0.35)
	)

	var forge_light := OmniLight3D.new()
	forge_light.name = "Omni"
	forge_light.position = Vector3(0.0, 0.7, 0.85)
	root.add_child(forge_light)
	var controller = MapViewMeshBuilderConfig.FORGE_FIRE_LIGHT_SCRIPT.new()
	controller.configure(forge_light, flames, particles, smoke)
	root.add_child(controller)


static func add_smithy_bellows(root: Node3D) -> void:
	# The authored mechanism supplies readable leather folds, joinery, tacks, and
	# a tapered nozzle without changing the declarative smithy prop footprint.
	var bellows_scene := load(_BELLOWS_SCENE_PATH) as PackedScene
	assert(
		bellows_scene != null,
		"Smithy bellows GLB must be imported before the map view is assembled"
	)
	var bellows := bellows_scene.instantiate() as Node3D
	bellows.name = "SmithyBellowsModel"
	root.add_child(bellows)


static func add_bellows_fallback(root: Node3D) -> void:
	# Double-board leather bellows aimed +X toward the forge tuyere.
	Primitives.box(
		root, "Stand", Vector3(0.55, 0.12, 0.7), Vector3(0.0, 0.06, 0.0), &"timber"
	)
	Primitives.box(
		root, "BoardBottom", Vector3(0.85, 0.06, 0.48), Vector3(0.05, 0.28, 0.0), &"wood"
	)
	Primitives.box(
		root, "BoardTop", Vector3(0.78, 0.06, 0.42), Vector3(-0.02, 0.72, 0.0), &"wood"
	)
	# Accordion leather folds between the boards.
	for index in 4:
		var t := float(index) / 3.0
		var y := lerpf(0.36, 0.64, t)
		var width := lerpf(0.82, 0.7, t)
		var depth := lerpf(0.46, 0.38, absf(t - 0.5) * 2.0)
		var fold := MeshInstance3D.new()
		fold.name = "Leather%d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, 0.07, depth)
		fold.mesh = mesh
		fold.position = Vector3(0.02, y, 0.0)
		fold.material_override = MapViewMaterials.leather()
		root.add_child(fold)
	# Nozzle / pipe points into the furnace mouth from the west (axis along X).
	_add_axis_cylinder(root, "Nozzle", 0.055, 0.55, Vector3(0.55, 0.42, 0.0), &"metal")
	_add_axis_cylinder(root, "NozzleTip", 0.04, 0.18, Vector3(0.88, 0.42, 0.0), &"metal")
	# Pump lever on the top board.
	Primitives.box(
		root, "Lever", Vector3(0.08, 0.55, 0.08), Vector3(-0.28, 1.0, 0.0), &"timber"
	)
	Primitives.box(
		root, "Handle", Vector3(0.28, 0.06, 0.08), Vector3(-0.38, 1.28, 0.0), &"wood"
	)
	Primitives.cylinder(
		root, "Hinge", 0.04, 0.5, Vector3(-0.4, 0.5, 0.0), &"metal"
	)


static func add_quench_fallback(root: Node3D) -> void:
	Primitives.cylinder(
		root, "Bucket", 0.3, 0.46, Vector3(0.0, 0.23, 0.0), &"wood"
	)
	Primitives.cylinder(
		root, "Water", 0.24, 0.05, Vector3(0.0, 0.44, 0.0), &"water_highlight"
	)


static func add_smithy_quench_bucket(root: Node3D) -> void:
	# WHY: the smithy's close workstation needs a visibly hollow, metal quench
	# vessel, while generic map buckets retain the cheap procedural fallback.
	# The rrmap footprint remains the sole collision/navigation authority.
	var bucket_scene := load(_QUENCH_SCENE_PATH) as PackedScene
	assert(
		bucket_scene != null,
		"Smithy quench bucket GLB must be imported before the map view is assembled"
	)
	var bucket := bucket_scene.instantiate() as Node3D
	bucket.name = "SmithyQuenchBucketModel"
	root.add_child(bucket)


static func _add_axis_cylinder(
	root: Node3D,
	node_name: String,
	radius: float,
	length: float,
	position: Vector3,
	role: StringName
) -> void:
	# Primitive side_axis lies along Z; forge tuyere/nozzle need the X axis.
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	instance.mesh = mesh
	instance.position = position
	instance.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	instance.material_override = Primitives.role_material(role)
	root.add_child(instance)


static func _add_furnace_ember_bed(root: Node3D) -> void:
	var bed := MeshInstance3D.new()
	bed.name = "EmberBed"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.05, 0.1, 0.7)
	bed.mesh = mesh
	bed.position = Vector3(0.0, 0.3, 0.58)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color8(180, 48, 18)
	material.emission_enabled = true
	material.emission = Color8(255, 90, 28)
	material.emission_energy_multiplier = 3.4
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bed.material_override = material
	bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bed)


static func _add_furnace_coal_bed(root: Node3D) -> void:
	var cold := MapViewMaterials.charcoal()
	var hot := MapViewMaterials.hot_coal()
	for spec in [
		{
			"name": "CoalA",
			"radius": 0.17,
			"pos": Vector3(-0.28, 0.36, 0.68),
			"scale": Vector3(1.35, 0.55, 1.15),
			"hot": true
		},
		{
			"name": "CoalB",
			"radius": 0.15,
			"pos": Vector3(0.24, 0.34, 0.72),
			"scale": Vector3(1.25, 0.52, 1.1),
			"hot": true
		},
		{
			"name": "CoalC",
			"radius": 0.14,
			"pos": Vector3(-0.02, 0.38, 0.55),
			"scale": Vector3(1.4, 0.5, 1.2),
			"hot": true
		},
		{
			"name": "CoalD",
			"radius": 0.12,
			"pos": Vector3(0.36, 0.32, 0.52),
			"scale": Vector3(1.15, 0.45, 1.0),
			"hot": false
		},
		{
			"name": "CoalE",
			"radius": 0.11,
			"pos": Vector3(-0.4, 0.32, 0.5),
			"scale": Vector3(1.1, 0.42, 0.95),
			"hot": false
		},
		{
			"name": "CoalF",
			"radius": 0.10,
			"pos": Vector3(0.08, 0.42, 0.7),
			"scale": Vector3(1.1, 0.42, 1.05),
			"hot": true
		},
		{
			"name": "CoalG",
			"radius": 0.09,
			"pos": Vector3(-0.14, 0.4, 0.74),
			"scale": Vector3(1.05, 0.38, 1.0),
			"hot": true
		},
		{
			"name": "CoalH",
			"radius": 0.08,
			"pos": Vector3(0.18, 0.4, 0.48),
			"scale": Vector3(1.0, 0.36, 0.95),
			"hot": true
		},
	]:
		var lump := MeshInstance3D.new()
		lump.name = spec["name"]
		var mesh := SphereMesh.new()
		mesh.radius = spec["radius"]
		mesh.height = spec["radius"] * 2.0
		mesh.radial_segments = 7
		mesh.rings = 3
		lump.mesh = mesh
		lump.position = spec["pos"]
		lump.scale = spec["scale"]
		lump.material_override = hot if spec["hot"] else cold
		lump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lump)


static func _add_furnace_flames(root: Node3D) -> Node3D:
	# WHY: solid pulsing spheres read as plastic blobs, not fire. Overlapping
	# billboard flame tongues (the CandleFlame3D vocabulary, hearth scale) give
	# turbulent licks, a cooling color ramp, and additive glow instead.
	var flames = MapViewMeshBuilderConfig.FORGE_FLAME_SCRIPT.new()
	flames.position = Vector3(0.0, 0.36, 0.6)
	flames.configure()
	root.add_child(flames)
	return flames


static func _add_furnace_fire_particles(root: Node3D) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "FireSparks"
	particles.position = Vector3(0.0, 0.48, 0.62)
	particles.amount = 28
	particles.lifetime = 1.05
	particles.preprocess = 0.55
	particles.explosiveness = 0.08
	particles.randomness = 0.4
	particles.visibility_aabb = AABB(Vector3(-0.9, -0.2, -0.7), Vector3(1.8, 2.0, 1.4))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.4, 0.06, 0.22)
	process.direction = Vector3.UP
	process.spread = 28.0
	process.initial_velocity_min = 0.55
	process.initial_velocity_max = 1.45
	process.gravity = Vector3(0.0, 0.45, 0.0)
	process.damping_min = 0.35
	process.damping_max = 1.0
	process.angular_velocity_min = -60.0
	process.angular_velocity_max = 60.0
	process.scale_min = 0.025
	process.scale_max = 0.06
	# WHY: sparks cool as they rise. A white-hot birth fading through orange to
	# dead red plus shrink-over-life sells ember trajectories, not orange dots.
	var spark_scale := Curve.new()
	spark_scale.add_point(Vector2(0.0, 1.0))
	spark_scale.add_point(Vector2(0.55, 0.7))
	spark_scale.add_point(Vector2(1.0, 0.15))
	var spark_scale_texture := CurveTexture.new()
	spark_scale_texture.curve = spark_scale
	process.scale_curve = spark_scale_texture
	var spark_ramp := Gradient.new()
	spark_ramp.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	spark_ramp.set_color(1, Color(0.6, 0.08, 0.0, 0.0))
	spark_ramp.add_point(0.4, Color(1.0, 0.6, 0.15, 0.9))
	spark_ramp.add_point(0.75, Color(0.9, 0.25, 0.02, 0.5))
	var spark_ramp_texture := GradientTexture1D.new()
	spark_ramp_texture.gradient = spark_ramp
	process.color_ramp = spark_ramp_texture
	particles.process_material = process
	var draw := SphereMesh.new()
	draw.radius = 0.5
	draw.height = 1.0
	draw.radial_segments = 6
	draw.rings = 3
	particles.draw_pass_1 = draw
	var spark_mat := StandardMaterial3D.new()
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.albedo_color = Color.WHITE
	spark_mat.emission_enabled = true
	spark_mat.emission = Color8(255, 140, 40)
	spark_mat.emission_energy_multiplier = 2.4
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particles.material_override = spark_mat
	root.add_child(particles)
	return particles


static func _add_furnace_smoke_particles(root: Node3D) -> GPUParticles3D:
	# Thin soot stream above the mouth: without it the fire looks weightless.
	# Soft radial puffs grow, gray out, and dissolve as they clear the lintel.
	var particles := GPUParticles3D.new()
	particles.name = "FireSmoke"
	particles.position = Vector3(0.0, 0.95, 0.55)
	particles.amount = 12
	particles.lifetime = 2.4
	particles.preprocess = 1.6
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	particles.local_coords = true
	particles.visibility_aabb = AABB(Vector3(-1.0, -0.4, -0.8), Vector3(2.0, 3.2, 1.6))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.28, 0.05, 0.14)
	process.direction = Vector3.UP
	process.spread = 10.0
	process.initial_velocity_min = 0.35
	process.initial_velocity_max = 0.6
	process.gravity = Vector3(0.0, 0.12, 0.0)
	process.damping_min = 0.05
	process.damping_max = 0.2
	process.angular_velocity_min = -18.0
	process.angular_velocity_max = 18.0
	process.scale_min = 0.55
	process.scale_max = 0.85
	var smoke_scale := Curve.new()
	smoke_scale.add_point(Vector2(0.0, 0.3))
	smoke_scale.add_point(Vector2(0.4, 0.9))
	smoke_scale.add_point(Vector2(1.0, 1.7))
	var smoke_scale_texture := CurveTexture.new()
	smoke_scale_texture.curve = smoke_scale
	process.scale_curve = smoke_scale_texture
	# Puffs darken and thin over life so the column dissolves instead of popping.
	var smoke_ramp := Gradient.new()
	smoke_ramp.set_color(0, Color(0.32, 0.28, 0.25, 0.0))
	smoke_ramp.set_color(1, Color(0.16, 0.15, 0.14, 0.0))
	smoke_ramp.add_point(0.25, Color(0.3, 0.27, 0.24, 0.3))
	smoke_ramp.add_point(0.65, Color(0.22, 0.2, 0.19, 0.22))
	var smoke_ramp_texture := GradientTexture1D.new()
	smoke_ramp_texture.gradient = smoke_ramp
	process.color_ramp = smoke_ramp_texture
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	particles.draw_pass_1 = quad
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.vertex_color_use_as_albedo = true
	# Procedural radial falloff keeps the puff soft without a texture asset.
	var falloff := Gradient.new()
	falloff.set_color(0, Color.WHITE)
	falloff.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	falloff.add_point(0.55, Color(1.0, 1.0, 1.0, 0.55))
	var falloff_texture := GradientTexture2D.new()
	falloff_texture.gradient = falloff
	falloff_texture.fill = GradientTexture2D.FILL_RADIAL
	falloff_texture.fill_from = Vector2(0.5, 0.5)
	falloff_texture.fill_to = Vector2(1.0, 0.5)
	smoke_mat.albedo_texture = falloff_texture
	smoke_mat.albedo_color = Color.WHITE
	smoke_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke_mat.billboard_keep_scale = true
	particles.material_override = smoke_mat
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(particles)
	return particles
