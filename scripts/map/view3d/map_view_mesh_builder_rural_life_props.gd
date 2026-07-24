class_name MapViewMeshBuilderRuralLifeProps
extends RefCounted

## P0-107: peri-urban and foreland agricultural dressing props. Each kind is a
## compact procedural silhouette readable from the frozen dimetric camera without
## blocking required routes when authored inside the documented footprint bands.

const _Primitives := preload("res://scripts/map/view3d/map_view_mesh_builder_primitives.gd")


static func add_to(root: Node3D, kind: StringName) -> void:
	match kind:
		MapTypes.PROP_KIND_KITCHEN_GARDEN:
			_add_kitchen_garden(root)
		MapTypes.PROP_KIND_FIELD_STRIP:
			_add_field_strip(root)
		MapTypes.PROP_KIND_HAY_WAGON:
			_add_hay_wagon(root)
		MapTypes.PROP_KIND_PASTURE_FENCE:
			_add_pasture_fence(root)
		MapTypes.PROP_KIND_PIGSTY:
			_add_pigsty(root)
		MapTypes.PROP_KIND_CHICKEN_RUN:
			_add_chicken_run(root)
		MapTypes.PROP_KIND_FLAX_DRYING_FRAME:
			_add_flax_drying_frame(root)
		MapTypes.PROP_KIND_ROOT_CELLAR_MOUND:
			_add_root_cellar_mound(root)
		MapTypes.PROP_KIND_ORCHARD_ROW:
			_add_orchard_row(root)
		MapTypes.PROP_KIND_FARM_CART:
			_add_farm_cart(root)
		_:
			_Primitives.box(root, "Marker", Vector3(0.5, 0.5, 0.5), Vector3(0.0, 0.25, 0.0), &"ink")


static func _add_kitchen_garden(root: Node3D) -> void:
	_Primitives.box(root, "BedNorth", Vector3(1.35, 0.08, 0.42), Vector3(0.0, 0.04, -0.28), &"stone")
	_Primitives.box(root, "BedSouth", Vector3(1.35, 0.08, 0.42), Vector3(0.0, 0.04, 0.28), &"stone")
	for index in 4:
		var along := lerpf(-0.48, 0.48, float(index) / 3.0)
		_Primitives.sphere(root, "Leaf%d" % index, 0.12, Vector3(along, 0.16, -0.28), &"vegetation", Vector3(0.9, 1.2, 0.9))
		_Primitives.sphere(root, "LeafB%d" % index, 0.1, Vector3(along + 0.08, 0.14, 0.3), &"vegetation", Vector3(0.85, 1.1, 0.85))


static func _add_field_strip(root: Node3D) -> void:
	_Primitives.box(root, "FurrowA", Vector3(1.45, 0.06, 0.14), Vector3(0.0, 0.03, -0.22), &"stone")
	_Primitives.box(root, "FurrowB", Vector3(1.45, 0.06, 0.14), Vector3(0.0, 0.03, 0.0), &"stone")
	_Primitives.box(root, "FurrowC", Vector3(1.45, 0.06, 0.14), Vector3(0.0, 0.03, 0.22), &"stone")
	for index in 5:
		var along := lerpf(-0.58, 0.58, float(index) / 4.0)
		_Primitives.box(root, "Stubble%d" % index, Vector3(0.04, 0.12, 0.04), Vector3(along, 0.1, 0.0), &"hay")


static func _add_hay_wagon(root: Node3D) -> void:
	_Primitives.box(root, "Axle", Vector3(1.05, 0.08, 0.12), Vector3(0.0, 0.18, 0.0), &"timber")
	for wheel_x in [-0.42, 0.42]:
		_Primitives.cylinder(root, "Wheel%d" % int((wheel_x + 0.42) * 10.0), 0.22, 0.08, Vector3(wheel_x, 0.22, 0.28), &"wood")
		_Primitives.cylinder(root, "WheelBack%d" % int((wheel_x + 0.42) * 10.0), 0.22, 0.08, Vector3(wheel_x, 0.22, -0.28), &"wood")
	_Primitives.box(root, "Bed", Vector3(0.92, 0.1, 0.72), Vector3(0.0, 0.34, 0.0), &"wood")
	_Primitives.sphere(root, "LoadA", 0.42, Vector3(-0.18, 0.62, 0.08), &"hay", Vector3(1.1, 0.72, 1.0))
	_Primitives.sphere(root, "LoadB", 0.38, Vector3(0.2, 0.58, -0.1), &"hay", Vector3(1.05, 0.68, 0.95))


static func _add_pasture_fence(root: Node3D) -> void:
	for post_x in [-0.62, -0.2, 0.2, 0.62]:
		_Primitives.box(root, "Post%d" % int((post_x + 0.62) * 10.0), Vector3(0.06, 0.72, 0.06), Vector3(post_x, 0.36, 0.0), &"timber")
	for rail_y in [0.28, 0.58]:
		_Primitives.box(root, "Rail%d" % int(rail_y * 10.0), Vector3(1.45, 0.05, 0.05), Vector3(0.0, rail_y, 0.0), &"wood")


static func _add_pigsty(root: Node3D) -> void:
	for post in [[-0.55, -0.35], [0.55, -0.35], [-0.55, 0.35], [0.55, 0.35]]:
		_Primitives.box(root, "Post%d_%d" % [int((post[0] + 0.55) * 10.0), int((post[1] + 0.35) * 10.0)], Vector3(0.08, 0.62, 0.08), Vector3(post[0], 0.31, post[1]), &"timber")
	_Primitives.box(root, "RailNorth", Vector3(1.2, 0.06, 0.06), Vector3(0.0, 0.48, -0.35), &"wood")
	_Primitives.box(root, "RailSouth", Vector3(1.2, 0.06, 0.06), Vector3(0.0, 0.48, 0.35), &"wood")
	_Primitives.box(root, "Roof", Vector3(1.05, 0.08, 0.82), Vector3(0.0, 0.66, 0.0), &"hay")
	_Primitives.sphere(root, "Mud", 0.34, Vector3(0.0, 0.12, 0.0), &"stone", Vector3(1.2, 0.35, 1.0))


static func _add_chicken_run(root: Node3D) -> void:
	for post_x in [-0.5, 0.5]:
		_Primitives.box(root, "Post%d" % int((post_x + 0.5) * 10.0), Vector3(0.07, 0.55, 0.07), Vector3(post_x, 0.28, -0.32), &"timber")
		_Primitives.box(root, "PostBack%d" % int((post_x + 0.5) * 10.0), Vector3(0.07, 0.55, 0.07), Vector3(post_x, 0.28, 0.32), &"timber")
	for rail_z in [-0.2, 0.2]:
		_Primitives.box(root, "Rail%d" % int((rail_z + 0.2) * 10.0), Vector3(1.15, 0.05, 0.05), Vector3(0.0, 0.42, rail_z), &"wood")
	_Primitives.box(root, "Mesh", Vector3(1.05, 0.42, 0.72), Vector3(0.0, 0.42, 0.0), &"plaster")
	for index in 3:
		var along := lerpf(-0.28, 0.28, float(index) / 2.0)
		_Primitives.sphere(root, "Hen%d" % index, 0.08, Vector3(along, 0.1, 0.12), &"plaster", Vector3(1.0, 0.8, 1.1))


static func _add_flax_drying_frame(root: Node3D) -> void:
	for post_x in [-0.58, 0.58]:
		_Primitives.box(root, "Post%d" % int((post_x + 0.58) * 10.0), Vector3(0.08, 1.15, 0.08), Vector3(post_x, 0.58, -0.28), &"timber")
		_Primitives.box(root, "PostBack%d" % int((post_x + 0.58) * 10.0), Vector3(0.08, 1.15, 0.08), Vector3(post_x, 0.58, 0.28), &"timber")
	for rail_z in [-0.12, 0.12]:
		_Primitives.box(root, "Rail%d" % int((rail_z + 0.12) * 10.0), Vector3(1.3, 0.05, 0.05), Vector3(0.0, 0.92, rail_z), &"wood")
	for bundle_index in 4:
		var along := lerpf(-0.42, 0.42, float(bundle_index) / 3.0)
		_Primitives.box(root, "Bundle%d" % bundle_index, Vector3(0.08, 0.72, 0.18), Vector3(along, 0.78, 0.0), &"hay")


static func _add_root_cellar_mound(root: Node3D) -> void:
	_Primitives.sphere(root, "Mound", 0.72, Vector3(0.0, 0.28, 0.0), &"stone", Vector3(1.35, 0.55, 1.1))
	_Primitives.box(root, "Door", Vector3(0.42, 0.38, 0.08), Vector3(0.0, 0.22, 0.62), &"timber")
	_Primitives.box(root, "Lint", Vector3(0.5, 0.06, 0.12), Vector3(0.0, 0.44, 0.62), &"wood")


static func _add_orchard_row(root: Node3D) -> void:
	for index in 3:
		var along := lerpf(-0.55, 0.55, float(index) / 2.0)
		_Primitives.cylinder(root, "Trunk%d" % index, 0.08, 0.62, Vector3(along, 0.31, 0.0), &"wood")
		_Primitives.sphere(root, "Crown%d" % index, 0.28, Vector3(along, 0.72, 0.0), &"vegetation", Vector3(0.95, 1.05, 0.95))


static func _add_farm_cart(root: Node3D) -> void:
	_Primitives.box(root, "Axle", Vector3(0.92, 0.07, 0.1), Vector3(0.0, 0.16, 0.0), &"timber")
	for wheel_x in [-0.34, 0.34]:
		_Primitives.cylinder(root, "Wheel%d" % int((wheel_x + 0.34) * 10.0), 0.2, 0.07, Vector3(wheel_x, 0.2, 0.24), &"wood")
		_Primitives.cylinder(root, "WheelBack%d" % int((wheel_x + 0.34) * 10.0), 0.2, 0.07, Vector3(wheel_x, 0.2, -0.24), &"wood")
	_Primitives.box(root, "Bed", Vector3(0.78, 0.08, 0.62), Vector3(0.0, 0.28, 0.0), &"wood")
	_Primitives.box(root, "ShaftL", Vector3(0.06, 0.06, 0.42), Vector3(-0.18, 0.24, 0.46), &"timber")
	_Primitives.box(root, "ShaftR", Vector3(0.06, 0.06, 0.42), Vector3(0.18, 0.24, 0.46), &"timber")
	_Primitives.box(root, "Crate", Vector3(0.28, 0.18, 0.22), Vector3(0.04, 0.36, -0.04), &"plaster")
