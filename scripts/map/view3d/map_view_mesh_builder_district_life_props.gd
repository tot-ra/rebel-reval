class_name MapViewMeshBuilderDistrictLifeProps
extends RefCounted

## P2-025: trade-specific district-life dressing props. Each kind is a compact
## procedural silhouette readable from the frozen dimetric camera without blocking
## required routes when authored inside the documented footprint bands.

const _Primitives := preload("res://scripts/map/view3d/map_view_mesh_builder_primitives.gd")


static func add_to(root: Node3D, kind: StringName) -> void:
	match kind:
		MapTypes.PROP_KIND_FISHING_NETS:
			_add_fishing_nets(root)
		MapTypes.PROP_KIND_FISH_DRYING_RACK:
			_add_fish_drying_rack(root)
		MapTypes.PROP_KIND_SMOKE_RACK:
			_add_smoke_rack(root)
		MapTypes.PROP_KIND_FISH_SPLITTING_TABLE:
			_add_fish_splitting_table(root)
		MapTypes.PROP_KIND_BOAT_TIMBER_STACK:
			_add_boat_timber_stack(root)
		MapTypes.PROP_KIND_ROPE_COIL:
			_add_rope_coil(root)
		MapTypes.PROP_KIND_SAIL_CLOTH_BALE:
			_add_sail_cloth_bale(root)
		MapTypes.PROP_KIND_COOPER_STAVES:
			_add_cooper_staves(root)
		MapTypes.PROP_KIND_MALT_SACK_PILE:
			_add_malt_sack_pile(root)
		MapTypes.PROP_KIND_BREWERY_KEG_STACK:
			_add_brewery_keg_stack(root)
		MapTypes.PROP_KIND_CHARCOAL_PILE:
			_add_charcoal_pile(root)
		MapTypes.PROP_KIND_IRON_SCRAP_PILE:
			_add_iron_scrap_pile(root)
		MapTypes.PROP_KIND_WEAPON_RACK:
			_add_weapon_rack(root)
		MapTypes.PROP_KIND_HERB_DRYING_RACK:
			_add_herb_drying_rack(root)
		MapTypes.PROP_KIND_MARKET_GOODS_PALLET:
			_add_market_goods_pallet(root)
		MapTypes.PROP_KIND_SALT_PILE:
			_add_salt_pile(root)
		MapTypes.PROP_KIND_TANNING_FRAME:
			_add_tanning_frame(root)
		MapTypes.PROP_KIND_WASH_TUB:
			_add_wash_tub(root)
		_:
			_Primitives.box(root, "Marker", Vector3(0.5, 0.5, 0.5), Vector3(0.0, 0.25, 0.0), &"ink")


static func _add_fishing_nets(root: Node3D) -> void:
	for post_z in [-0.55, 0.55]:
		_Primitives.box(root, "Post%d" % int((post_z + 0.55) * 10.0), Vector3(0.08, 1.35, 0.08), Vector3(post_z, 0.68, 0.0), &"timber")
	_Primitives.box(root, "TopRail", Vector3(1.35, 0.07, 0.07), Vector3(0.0, 1.32, 0.0), &"wood")
	for index in 4:
		var along := lerpf(-0.55, 0.55, float(index) / 3.0)
		_Primitives.box(root, "Mesh%d" % index, Vector3(0.04, 0.9, 0.04), Vector3(along, 0.72, 0.0), &"plaster")


static func _add_fish_drying_rack(root: Node3D) -> void:
	for post_x in [-0.62, 0.62]:
		_Primitives.box(root, "Leg%d" % int((post_x + 0.62) * 10.0), Vector3(0.1, 0.72, 0.1), Vector3(post_x, 0.36, -0.42), &"timber")
		_Primitives.box(root, "LegBack%d" % int((post_x + 0.62) * 10.0), Vector3(0.1, 0.72, 0.1), Vector3(post_x, 0.36, 0.42), &"timber")
	for rail_z in [-0.35, 0.0, 0.35]:
		_Primitives.box(root, "Rail%d" % int((rail_z + 0.35) * 10.0), Vector3(1.45, 0.06, 0.06), Vector3(0.0, 0.78, rail_z), &"wood")
	for fish_index in 3:
		var fish_x := lerpf(-0.45, 0.45, float(fish_index) / 2.0)
		_Primitives.box(root, "Fish%d" % fish_index, Vector3(0.34, 0.06, 0.12), Vector3(fish_x, 0.84, 0.0), &"hay")


static func _add_smoke_rack(root: Node3D) -> void:
	_add_fish_drying_rack(root)
	_Primitives.box(root, "SmokeHood", Vector3(1.1, 0.08, 1.1), Vector3(0.0, 1.45, 0.0), &"stone")
	var smoke := MeshInstance3D.new()
	smoke.name = "Smoke"
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.22
	smoke_mesh.height = 0.44
	smoke_mesh.radial_segments = 8
	smoke_mesh.rings = 4
	smoke.mesh = smoke_mesh
	smoke.position = Vector3(0.0, 1.72, 0.0)
	smoke.material_override = _Primitives.role_material(&"plaster")
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(smoke)


static func _add_fish_splitting_table(root: Node3D) -> void:
	_Primitives.box(root, "Top", Vector3(1.35, 0.1, 0.72), Vector3(0.0, 0.78, 0.0), &"wood")
	for leg_spec in [["LegFL", -0.52, 0.24], ["LegFR", 0.52, 0.24], ["LegBL", -0.52, -0.24], ["LegBR", 0.52, -0.24]]:
		_Primitives.box(root, leg_spec[0], Vector3(0.1, 0.76, 0.1), Vector3(leg_spec[1], 0.38, leg_spec[2]), &"timber")
	_Primitives.box(root, "Slab", Vector3(0.42, 0.04, 0.28), Vector3(0.18, 0.86, 0.0), &"stone")


static func _add_boat_timber_stack(root: Node3D) -> void:
	for index in 5:
		var offset := float(index) * 0.18
		_Primitives.cylinder(
			root,
			"Log%d" % index,
			0.11,
			2.1,
			Vector3(-0.42 + offset, 0.12 + offset * 0.08, 0.0),
			&"wood",
			true
		)


static func _add_rope_coil(root: Node3D) -> void:
	_Primitives.cylinder(root, "CoilOuter", 0.42, 0.18, Vector3(0.0, 0.09, 0.0), &"hay")
	_Primitives.cylinder(root, "CoilInner", 0.18, 0.2, Vector3(0.0, 0.1, 0.0), &"timber")
	_Primitives.box(root, "Tail", Vector3(0.55, 0.05, 0.05), Vector3(0.42, 0.08, 0.12), &"hay")


static func _add_sail_cloth_bale(root: Node3D) -> void:
	_Primitives.box(root, "Bale", Vector3(0.92, 0.42, 0.62), Vector3(0.0, 0.21, 0.0), &"plaster")
	_Primitives.box(root, "CordA", Vector3(0.06, 0.44, 0.64), Vector3(-0.24, 0.21, 0.0), &"timber")
	_Primitives.box(root, "CordB", Vector3(0.06, 0.44, 0.64), Vector3(0.24, 0.21, 0.0), &"timber")


static func _add_cooper_staves(root: Node3D) -> void:
	for index in 6:
		var yaw := lerpf(-0.35, 0.35, float(index) / 5.0)
		var stave := Node3D.new()
		stave.name = "Stave%d" % index
		stave.rotation.y = yaw
		root.add_child(stave)
		_Primitives.box(stave, "Board", Vector3(0.08, 1.45, 0.18), Vector3(0.0, 0.72, 0.0), &"wood")


static func _add_malt_sack_pile(root: Node3D) -> void:
	_Primitives.sphere(root, "SackA", 0.34, Vector3(-0.22, 0.34, 0.06), &"plaster", Vector3(0.78, 1.1, 0.82))
	_Primitives.sphere(root, "SackB", 0.31, Vector3(0.18, 0.31, -0.12), &"plaster", Vector3(0.82, 1.08, 0.76))
	_Primitives.sphere(root, "SackC", 0.28, Vector3(0.02, 0.52, 0.14), &"hay", Vector3(0.74, 1.05, 0.8))


static func _add_brewery_keg_stack(root: Node3D) -> void:
	for spec in [
		{"name": "KegLow", "pos": Vector3(-0.28, 0.0, 0.1), "yaw": -0.08},
		{"name": "KegMid", "pos": Vector3(0.3, 0.0, -0.14), "yaw": 0.14},
		{"name": "KegTop", "pos": Vector3(0.02, 0.72, 0.0), "yaw": 0.04},
	]:
		var keg := Node3D.new()
		keg.name = spec["name"]
		keg.position = spec["pos"]
		keg.rotation.y = spec["yaw"]
		root.add_child(keg)
		_Primitives.cylinder(keg, "Body", 0.28, 0.68, Vector3(0.0, 0.34, 0.0), &"wood")
		_Primitives.cylinder(keg, "Band", 0.3, 0.05, Vector3(0.0, 0.42, 0.0), &"metal")


static func _add_charcoal_pile(root: Node3D) -> void:
	_Primitives.sphere(root, "MoundA", 0.62, Vector3(-0.12, 0.28, 0.08), &"stone", Vector3(1.2, 0.55, 1.0))
	_Primitives.sphere(root, "MoundB", 0.48, Vector3(0.24, 0.22, -0.1), &"stone", Vector3(1.05, 0.5, 0.95))
	_Primitives.box(root, "Scoop", Vector3(0.42, 0.06, 0.24), Vector3(0.46, 0.08, 0.28), &"metal")


static func _add_iron_scrap_pile(root: Node3D) -> void:
	_Primitives.box(root, "PlateA", Vector3(0.42, 0.08, 0.34), Vector3(-0.18, 0.12, 0.06), &"metal")
	_Primitives.box(root, "PlateB", Vector3(0.36, 0.1, 0.28), Vector3(0.16, 0.18, -0.08), &"metal")
	_Primitives.box(root, "Rod", Vector3(0.08, 0.62, 0.08), Vector3(0.02, 0.31, 0.18), &"metal")
	_Primitives.sphere(root, "Chunk", 0.16, Vector3(0.28, 0.14, 0.12), &"metal", Vector3(1.0, 0.7, 0.9))


static func _add_weapon_rack(root: Node3D) -> void:
	_Primitives.box(root, "Back", Vector3(0.12, 1.2, 0.92), Vector3(0.0, 0.6, 0.0), &"wood")
	for index in 3:
		var along := lerpf(-0.3, 0.3, float(index) / 2.0)
		_Primitives.box(root, "Peg%d" % index, Vector3(0.08, 0.08, 0.08), Vector3(0.08, 0.45 + 0.28 * index, along), &"timber")
		_Primitives.box(root, "Haft%d" % index, Vector3(0.05, 0.72, 0.05), Vector3(0.12, 0.86, along), &"wood")
		_Primitives.box(root, "Blade%d" % index, Vector3(0.16, 0.05, 0.05), Vector3(0.12, 1.18, along), &"metal")


static func _add_herb_drying_rack(root: Node3D) -> void:
	for post_x in [-0.5, 0.5]:
		_Primitives.box(root, "Post%d" % int((post_x + 0.5) * 10.0), Vector3(0.08, 1.05, 0.08), Vector3(post_x, 0.52, 0.0), &"timber")
	_Primitives.box(root, "Crossbar", Vector3(1.15, 0.06, 0.06), Vector3(0.0, 0.98, 0.0), &"wood")
	for bundle in 4:
		var bundle_x := lerpf(-0.38, 0.38, float(bundle) / 3.0)
		_Primitives.sphere(root, "Bundle%d" % bundle, 0.12, Vector3(bundle_x, 0.82, 0.0), &"vegetation", Vector3(1.0, 1.4, 0.8))


static func _add_market_goods_pallet(root: Node3D) -> void:
	_Primitives.box(root, "Deck", Vector3(1.1, 0.08, 0.82), Vector3(0.0, 0.12, 0.0), &"wood")
	for leg_spec in [["LegFL", -0.42, 0.3], ["LegFR", 0.42, 0.3], ["LegBL", -0.42, -0.3], ["LegBR", 0.42, -0.3]]:
		_Primitives.box(root, leg_spec[0], Vector3(0.08, 0.12, 0.08), Vector3(leg_spec[1], 0.06, leg_spec[2]), &"timber")
	_Primitives.box(root, "CrateA", Vector3(0.42, 0.28, 0.34), Vector3(-0.18, 0.3, 0.0), &"wood")
	_Primitives.box(root, "CrateB", Vector3(0.36, 0.22, 0.3), Vector3(0.2, 0.27, -0.08), &"wood")
	_Primitives.sphere(root, "Sack", 0.22, Vector3(0.08, 0.34, 0.16), &"plaster", Vector3(0.8, 1.0, 0.78))


static func _add_salt_pile(root: Node3D) -> void:
	_Primitives.sphere(root, "SaltA", 0.48, Vector3(-0.1, 0.24, 0.06), &"plaster", Vector3(1.15, 0.62, 1.0))
	_Primitives.sphere(root, "SaltB", 0.36, Vector3(0.2, 0.18, -0.08), &"plaster", Vector3(1.05, 0.58, 0.95))
	_Primitives.box(root, "Shovel", Vector3(0.06, 0.42, 0.06), Vector3(0.42, 0.16, 0.2), &"wood")


static func _add_tanning_frame(root: Node3D) -> void:
	for post_x in [-0.42, 0.42]:
		_Primitives.box(root, "AFrame%d" % int((post_x + 0.42) * 10.0), Vector3(0.1, 1.15, 0.1), Vector3(post_x, 0.58, 0.0), &"timber")
	_Primitives.box(root, "Beam", Vector3(1.0, 0.08, 0.08), Vector3(0.0, 1.05, 0.0), &"wood")
	_Primitives.box(root, "Hide", Vector3(0.72, 0.9, 0.04), Vector3(0.0, 0.62, 0.0), &"plaster")


static func _add_wash_tub(root: Node3D) -> void:
	_Primitives.cylinder(root, "Tub", 0.42, 0.36, Vector3(0.0, 0.42, 0.0), &"wood")
	_Primitives.cylinder(root, "Water", 0.34, 0.05, Vector3(0.0, 0.58, 0.0), &"water_highlight")
	for leg_spec in [["LegFL", -0.28, 0.22], ["LegFR", 0.28, 0.22], ["LegBL", -0.28, -0.22], ["LegBR", 0.28, -0.22]]:
		_Primitives.box(root, leg_spec[0], Vector3(0.08, 0.42, 0.08), Vector3(leg_spec[1], 0.21, leg_spec[2]), &"timber")
