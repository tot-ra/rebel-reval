class_name MapViewBurgherHouseModels
extends RefCounted

## Production exterior models for the R-003 ordinary-house tiers.
## Gameplay collision/navigation remain authored on the 2D map plane; this module
## only swaps view geometry after the contract nodes have been created.
##
## Every kit GLB (burgher_house_kit_v2) has its wall body centred on the origin
## with the street gable facing +Z. The loader picks the variant whose frontage
## is closest to the authored footprint and fits the body to it: frontage and
## plot depth stretch to the footprint, while height follows the frontage scale
## within a narrow band. WHY: the v1 loader squeezed the whole model (roof
## included) into the gameplay wall height, which left 0.5 m doors and flat
## roofs; storeys, doors and roof pitch must stay true to people on the street.

const SurfaceVariety := preload(
	"res://scripts/map/view3d/map_view_burgher_house_surface_variety.gd"
)

## Vertical scale band around the frontage fit. Narrow plots still keep doors
## above head height; wide plots do not grow extra-tall storeys.
const MIN_VERTICAL_SCALE := 0.85
const MAX_VERTICAL_SCALE := 1.1

## Plot depth matters less than frontage for choosing a variant: depth only
## stretches the ridge run, frontage stretches doors, openings and roof pitch.
const DEPTH_FIT_WEIGHT := 0.5

## body = wall body in metres: (frontage width, eave height, plot depth);
## smoke = flue or smoke-vent outlet in model space. Both must match body_m /
## smoke_outlet_m in
## generated/blender/burgher_house_merchant_timber_v1/report.json.
const MERCHANT_TIMBER_VARIANTS: Array[Dictionary] = [
	{
		"id": &"timber_frame",
		"path": "res://assets/props/architecture/houses/merchant_timber/merchant_timber.glb",
		"body": Vector3(8.4, 6.1, 8.4),
		"smoke": Vector3(-0.58, 12.0939, -1.512),
	},
	{
		"id": &"horizontal_log",
		"path": "res://assets/props/architecture/houses/merchant_timber/merchant_timber_log.glb",
		"body": Vector3(10.0, 5.65, 8.4),
		"smoke": Vector3(0.67, 12.4824, -1.68),
	},
]


static func is_production_tier(building: Dictionary) -> bool:
	return StringName(building.get("house_tier", &"")) == &"merchant_timber"


static func add_model(
	root: Node3D, building: Dictionary, size: Vector2, _height: float
) -> Node3D:
	return add_variant_model(
		root, building, size, &"merchant_timber", "ProductionMerchantTimber", MERCHANT_TIMBER_VARIANTS
	)


## Instantiate the best-fitting variant of a tier under ``root`` and hide the
## placeholder geometry it replaces.
static func add_variant_model(
	root: Node3D,
	building: Dictionary,
	size: Vector2,
	tier: StringName,
	node_name: String,
	variants: Array[Dictionary]
) -> Node3D:
	var fit := variant_fit(building, size, variants)
	var variant: Dictionary = fit["variant"]
	var path := String(variant["path"])
	var scene := load(path) as PackedScene
	assert(scene != null, "%s GLB must be imported before map assembly" % tier)
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	assert(model != null, "%s GLB root must be Node3D" % tier)
	if model == null:
		return null
	model.name = node_name
	model.set_meta(&"production_house_model", true)
	model.set_meta(&"house_tier", tier)
	model.set_meta(&"house_variant", variant["id"])
	model.set_meta(&"source_scene", path)
	model.scale = fit["scale"]
	model.rotation.y = _frontage_rotation(building.get("door_side", &"south"))
	enable_baked_wear(model)
	# Shared kit albedos would otherwise clone across a same-footprint street.
	SurfaceVariety.apply(model, StringName(String(building.get("id", ""))))
	root.add_child(model)
	prune_placeholder_geometry(root, model)
	_attach_smoke(root, model, variant)
	return model


## The procedural roof pass placed ChimneySmoke3D over its own (now hidden)
## stack. Move the plume to the kit's flue or gable smoke vent and keep it
## visible; the smoke culler re-shows it every frame anyway, so leaving it at
## the placeholder height made plumes hang in mid-air above the new roofs.
static func _attach_smoke(root: Node3D, model: Node3D, variant: Dictionary) -> void:
	var smoke := root.get_node_or_null("ChimneySmoke") as Node3D
	if smoke == null:
		return
	if not variant.has("smoke"):
		root.remove_child(smoke)
		smoke.free()
		return
	smoke.position = model.transform * Vector3(variant["smoke"])
	smoke.visible = true


## The kit bakes rising damp, runoff, roof moss and soot into COLOR_0. Godot's
## glTF importer keeps the colours but leaves them off the albedo, so switch
## them on for the imported (shared, cached) materials. Colours are linear
## multipliers, matching the Blender evidence plates.
static func enable_baked_wear(model: Node) -> void:
	var mesh_instance := model as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		var mesh := mesh_instance.mesh
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null and not material.vertex_color_use_as_albedo:
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
	for child in model.get_children():
		enable_baked_wear(child)


## Deterministic variant choice and model-local scale for a footprint.
## Returns {"variant": Dictionary, "scale": Vector3}. Scale is in model space
## (x = frontage, z = plot depth), so it stays correct after the frontage
## rotation for east/west doors.
static func variant_fit(
	building: Dictionary, size: Vector2, variants: Array[Dictionary]
) -> Dictionary:
	var door_side := StringName(building.get("door_side", &"south"))
	var side_facing := door_side == &"east" or door_side == &"west"
	var frontage := size.y if side_facing else size.x
	var plot_depth := size.x if side_facing else size.y
	var tie_break := absi(String(building.get("id", "")).hash())
	var best: Dictionary = variants[0]
	var best_score := INF
	for index in variants.size():
		var candidate: Dictionary = variants[index]
		var body: Vector3 = candidate["body"]
		var score := (
			absf(log(frontage / body.x)) + DEPTH_FIT_WEIGHT * absf(log(plot_depth / body.z))
		)
		# Near-equal fits alternate by building id so a uniform row still varies.
		var nudged := score + 0.0001 * float((tie_break + index) % variants.size())
		if nudged < best_score:
			best_score = nudged
			best = candidate
	var fitted: Vector3 = best["body"]
	var across := frontage / fitted.x
	return {
		"variant": best,
		"scale": Vector3(
			across,
			clampf(across, MIN_VERTICAL_SCALE, MAX_VERTICAL_SCALE),
			plot_depth / fitted.z
		),
	}


## Keep ordinary-renderer contract nodes for diagnostics and tests, but hide
## their placeholder geometry once an authored exterior GLB is active.
static func prune_placeholder_geometry(root: Node3D, keep: Node3D) -> void:
	if root == null or keep == null:
		return
	for child in root.get_children():
		if child != keep:
			child.visible = false


static func _frontage_rotation(door_side: StringName) -> float:
	match door_side:
		&"north":
			return PI
		&"east":
			return PI * 0.5
		&"west":
			return -PI * 0.5
	return 0.0
