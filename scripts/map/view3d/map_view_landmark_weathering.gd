extends RefCounted

## Shared landmark wear kit (LM-01, R-1123): rising damp over the plinth, soot and
## runoff under eaves, rain streaks below sills, and age-toned library surfaces.
##
## WHY: every stone landmark in 1343 Reval is decades old, and each builder
## re-implementing stains drifts in look and cost. Stains are flat quads sharing
## one alpha-mask material per (strength, direction, soft sides); toned surfaces
## stay in the AR-03 library cache so the anti-tiling quality toggle reaches them.
## Output is deterministic per building id (callers seed the RNG from it).
##
## St Olaf (R-1120) is the first consumer. The Town Hall still carries its own copy
## of this recipe until R-1123 moves it here with identical output.

const _BuildingMaterials := preload("res://scripts/map/view3d/map_view_building_materials.gd")

const GRIME := Color(0.1, 0.09, 0.07)
## Keeps the overlay quads off the wall face without visible floating.
const DECAL_OFFSET := 0.015

static var _cache: Dictionary = {}


## Library stem surface with an explicit wear multiplier. Library tints carry hue
## only, so age (dulled stone, lichened tile) is applied once, in place, on the
## cached entry; the base-tint meta is scaled too so the quality toggle keeps it.
static func toned_surface(
	prefix: String, surface_id: StringName, stem: String, tint: Color, tone: Color
) -> StandardMaterial3D:
	var material := _BuildingMaterials.library_surface_for_building(prefix, surface_id, stem, tint)
	if material.has_meta(&"landmark_toned"):
		return material
	material.set_meta(&"landmark_toned", true)
	var base: Color = material.get_meta(&"ar03_base_tint", material.albedo_color)
	material.set_meta(&"ar03_base_tint", Color(base * tone, base.a))
	material.albedo_color = Color(material.albedo_color * tone, material.albedo_color.a)
	return material


## Object-space projection at the stem's real-world density, so small boxes and
## prisms keep the stone scale instead of one stretched plate.
static func triplanar(material: StandardMaterial3D, stem: String) -> StandardMaterial3D:
	var key := "triplanar:%d:%s" % [material.get_instance_id(), stem]
	if _cache.has(key):
		return _cache[key]
	var projected := material.duplicate() as StandardMaterial3D
	projected.uv1_triplanar = true
	projected.uv1_scale = _BuildingMaterials.library_world_uv_density(stem)
	_cache[key] = projected
	return projected


## Damp band above the plinth and seeded eave streaks for one wall face.
## `origin` is the face centre at ground level, `yaw` turns +Z onto the outward
## normal, `eave_y` is where runoff starts.
static func add_face_wear(
	root: Node3D,
	rng: RandomNumberGenerator,
	prefix: String,
	span: float,
	origin: Vector3,
	yaw: float,
	eave_y: float,
	plinth_height: float = 0.6
) -> void:
	var along := Vector3(cos(yaw), 0.0, -sin(yaw))
	var normal := Vector3(sin(yaw), 0.0, cos(yaw))
	var base := origin + normal * DECAL_OFFSET
	decal(
		root,
		"%sDamp" % prefix,
		Vector2(span, 1.5),
		base + Vector3(0.0, plinth_height + 0.75, 0.0),
		yaw,
		0.5,
		false,
		false
	)
	var streak_count := maxi(int(span / 0.9), 1)
	for index in streak_count:
		var width := rng.randf_range(0.25, 0.8)
		var length := rng.randf_range(0.6, minf(2.6, eave_y * 0.4))
		var t := (float(index) + rng.randf_range(0.2, 0.8)) / float(streak_count) - 0.5
		decal(
			root,
			"%sEaveStreak%02d" % [prefix, index],
			Vector2(width, length),
			base + along * (t * span) + Vector3(0.0, eave_y - length * 0.5, 0.0),
			yaw,
			rng.randf_range(0.2, 0.4),
			true
		)


## Three runoff streaks below a sill centred at `sill` (on the wall face).
static func add_sill_streaks(
	root: Node3D,
	rng: RandomNumberGenerator,
	prefix: String,
	sill: Vector3,
	width: float,
	yaw: float
) -> void:
	var along := Vector3(cos(yaw), 0.0, -sin(yaw))
	var normal := Vector3(sin(yaw), 0.0, cos(yaw))
	for index in 3:
		var length := rng.randf_range(0.5, 1.4)
		var offset := (float(index) - 1.0) * width * 0.34 + rng.randf_range(-0.06, 0.06)
		decal(
			root,
			"%sStreak%d" % [prefix, index],
			Vector2(rng.randf_range(0.14, 0.3), length),
			(
				sill
				+ along * offset
				+ normal * DECAL_OFFSET * 2.0
				+ Vector3(0.0, -0.12 - length * 0.5, 0.0)
			),
			yaw,
			rng.randf_range(0.35, 0.6),
			true
		)


## One faded staining quad. `from_top` darkens at the top edge and fades down
## (runoff); otherwise it darkens at the bottom and fades up (rising damp).
static func decal(
	root: Node3D,
	decal_name: String,
	quad_size: Vector2,
	center: Vector3,
	yaw: float,
	strength: float,
	from_top: bool,
	soft_sides: bool = true
) -> void:
	var quad := MeshInstance3D.new()
	quad.name = decal_name
	var mesh := QuadMesh.new()
	mesh.size = quad_size
	quad.mesh = mesh
	quad.position = center
	quad.rotation.y = yaw
	quad.material_override = grime_material(snappedf(strength, 0.05), from_top, soft_sides)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(quad)


## Alpha mask baked per (strength, direction, edge) so every stain of that kind
## shares one material. Soft sides fade the stain across its width as well, so
## runoff reads as a streak instead of a translucent rectangle.
static func grime_material(strength: float, from_top: bool, soft_sides: bool) -> StandardMaterial3D:
	var key := "grime:%.2f:%s:%s" % [strength, from_top, soft_sides]
	if _cache.has(key):
		return _cache[key]
	var image := Image.create(16, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		var v := float(y) / 63.0
		var fade := 1.0 - v if from_top else v
		fade = fade * fade
		for x in 16:
			var across := 1.0
			if soft_sides:
				across = pow(sin(PI * (float(x) + 0.5) / 16.0), 1.5)
			image.set_pixel(x, y, Color(GRIME, strength * fade * across))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	material.metallic_specular = 0.0
	material.cull_mode = BaseMaterial3D.CULL_BACK
	_cache[key] = material
	return material
