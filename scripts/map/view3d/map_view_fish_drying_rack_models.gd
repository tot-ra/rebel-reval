class_name MapViewFishDryingRackModels
extends RefCounted

## Reusable timber frame for harbor drying yards. Catch geometry is deliberately
## excluded so maps can author empty, lightly loaded, or mixed-species racks.

const DRYING_POLE_HEIGHT := 1.16
const FRONT_POLE_Z := -0.24
const BACK_POLE_Z := 0.24

const _Primitives := preload("res://scripts/map/view3d/map_view_mesh_builder_primitives.gd")
const _DriedFishMeshes := preload("res://scripts/map/view3d/map_view_dried_fish_meshes.gd")
const _PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")

## R-1640 shore rack: the full-size two-tier rack the Kalarand fishers stood
## beside their huts (kalamaja-fishing-shore-1343.md: drying preferred for lean
## spring herring). A-frame trestles carry a ridge and cross-bars; four drying
## poles (two tiers, front and back) hold the catch.
const SHORE_TIER_HEIGHTS: Array[float] = [1.22, 1.78]
## Half-depth of the drying poles per tier (the upper bar is shorter).
const SHORE_TIER_HALF_DEPTH: Array[float] = [0.4, 0.32]
const SHORE_RIDGE_HEIGHT := 2.05
const SHORE_LEG_SPLAY := 0.62
## Spacing of fish along a drying pole and the share of slots actually hung.
const SHORE_FISH_SPACING := 0.2
const SHORE_FILL := {&"fish_rack.herring": 0.85, &"fish_rack.mixed": 0.7}

static var _lashing: StandardMaterial3D
static var _dried: Dictionary = {}


static func add_frame(parent: Node3D) -> Node3D:
	var frame := Node3D.new()
	frame.name = "FishDryingRackFrame"
	frame.set_meta(&"empty_drying_frame", true)
	parent.add_child(frame)

	for end_index in 2:
		var end_x := -0.66 if end_index == 0 else 0.66
		_add_spar(
			frame,
			"EndFrame%dFrontLeg" % end_index,
			Vector3(end_x, 0.015, -0.43),
			Vector3(end_x, 1.34, 0.0),
			0.045,
			&"timber"
		)
		_add_spar(
			frame,
			"EndFrame%dBackLeg" % end_index,
			Vector3(end_x, 0.015, 0.43),
			Vector3(end_x, 1.34, 0.0),
			0.045,
			&"timber"
		)
		_add_spar(
			frame,
			"EndFrame%dTie" % end_index,
			Vector3(end_x, 0.45, -0.32),
			Vector3(end_x, 0.45, 0.32),
			0.035,
			&"wood"
		)

	_add_spar(
		frame, "RidgePole", Vector3(-0.74, 1.34, 0.0), Vector3(0.74, 1.34, 0.0), 0.05, &"wood"
	)
	# Rope lashings where the ridge sits in the crossed legs.
	for end_index in 2:
		var end_x := -0.66 if end_index == 0 else 0.66
		_add_lashing(frame, "EndFrame%dLashing" % end_index, Vector3(end_x, 1.3, 0.0), 0.07)
	_add_spar(
		frame,
		"FrontDryingPole",
		Vector3(-0.7, DRYING_POLE_HEIGHT, FRONT_POLE_Z),
		Vector3(0.7, DRYING_POLE_HEIGHT, FRONT_POLE_Z),
		0.035,
		&"wood"
	)
	_add_spar(
		frame,
		"BackDryingPole",
		Vector3(-0.7, DRYING_POLE_HEIGHT, BACK_POLE_Z),
		Vector3(0.7, DRYING_POLE_HEIGHT, BACK_POLE_Z),
		0.035,
		&"wood"
	)
	_add_spar(
		frame, "FrontBrace", Vector3(-0.6, 0.18, -0.39), Vector3(0.6, 0.72, -0.3), 0.025, &"timber"
	)
	_add_spar(
		frame, "BackBrace", Vector3(0.6, 0.18, 0.39), Vector3(-0.6, 0.72, 0.3), 0.025, &"timber"
	)
	return frame


static func attachment_point(x: float, back_row: bool = false) -> Vector3:
	return Vector3(x, DRYING_POLE_HEIGHT, BACK_POLE_Z if back_row else FRONT_POLE_Z)


static func add_hanging_cord(
	parent: Node3D, node_name: String, start: Vector3, length: float
) -> void:
	_add_spar(parent, node_name, start, start + Vector3(0.0, -length, 0.0), 0.008, &"timber")


static func _add_spar(
	parent: Node3D, node_name: String, start: Vector3, end: Vector3, radius: float, role: StringName
) -> void:
	var direction := end - start
	if direction.is_zero_approx():
		return
	var spar := MeshInstance3D.new()
	spar.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.08
	mesh.height = direction.length()
	mesh.radial_segments = 6
	mesh.rings = 1
	spar.mesh = mesh
	spar.position = (start + end) * 0.5
	spar.quaternion = Quaternion(Vector3.UP, direction.normalized())
	spar.material_override = _Primitives.role_material(role)
	parent.add_child(spar)


## Builds the R-1640 full-size shore rack with its catch. `length` is the
## drying-pole span in metres; `variant` is one of the fish_rack.* style variants.
## The same id always rebuilds the same rack.
static func add_shore_rack(
	parent: Node3D, id: String, length: float = 3.4, variant: StringName = &"fish_rack.mixed"
) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var rack := Node3D.new()
	rack.name = "ShoreFishRack"
	rack.set_meta(&"shore_fish_rack", true)
	rack.set_meta(&"fish_rack_variant", variant)
	parent.add_child(rack)
	var half := length * 0.5
	for end_index in 2:
		var end_x := -half if end_index == 0 else half
		# Hand-cut poles are never straight or equal: jitter each foot and tip.
		for side: float in [-1.0, 1.0]:
			# Legs cross just under the ridge and their tips stand proud of it,
			# the cradle a ridge pole is dropped into.
			var foot := Vector3(end_x, -0.12, side * SHORE_LEG_SPLAY) + _jitter(rng)
			var tip := Vector3(end_x, SHORE_RIDGE_HEIGHT + 0.22, -side * 0.12) + _jitter(rng)
			_add_spar(
				rack,
				"Trestle%dLeg%s" % [end_index, "Front" if side < 0.0 else "Back"],
				foot,
				tip,
				rng.randf_range(0.045, 0.055),
				&"timber"
			)
		_add_lashing(
			rack,
			"Trestle%dCrossLashing" % end_index,
			Vector3(end_x, SHORE_RIDGE_HEIGHT - 0.04, 0.0),
			0.075
		)
		for tier in SHORE_TIER_HEIGHTS.size():
			var y: float = SHORE_TIER_HEIGHTS[tier]
			var depth: float = SHORE_TIER_HALF_DEPTH[tier] + 0.06
			_add_spar(
				rack,
				"Trestle%dBar%d" % [end_index, tier],
				Vector3(end_x, y - 0.05, -depth),
				Vector3(end_x, y - 0.05, depth),
				0.03,
				&"wood"
			)
			for side: float in [-1.0, 1.0]:
				var leg_z := (
					side * SHORE_LEG_SPLAY * (1.0 - (y + 0.12) / (SHORE_RIDGE_HEIGHT + 0.12))
				)
				_add_lashing(
					rack,
					(
						"Trestle%dBar%dLashing%s"
						% [end_index, tier, "Front" if side < 0.0 else "Back"]
					),
					Vector3(end_x, y - 0.05, leg_z),
					0.05
				)
	_add_spar(
		rack,
		"RidgePole",
		Vector3(-half - 0.18, SHORE_RIDGE_HEIGHT, 0.0),
		Vector3(half + 0.18, SHORE_RIDGE_HEIGHT, 0.0),
		0.05,
		&"wood"
	)
	for tier in SHORE_TIER_HEIGHTS.size():
		for side: float in [-1.0, 1.0]:
			var start := shore_attachment_point(-half - 0.12, tier, side > 0.0)
			var end := shore_attachment_point(half + 0.12, tier, side > 0.0)
			# A drying pole sags a little under a full load of wet fish.
			_add_spar(
				rack,
				"DryingPole%d%s" % [tier, "Front" if side < 0.0 else "Back"],
				start + Vector3(0.0, rng.randf_range(-0.02, 0.02), 0.0),
				end + Vector3(0.0, rng.randf_range(-0.02, 0.02), 0.0),
				0.032,
				&"wood"
			)
	# A diagonal brace along the back stops the trestles folding over in a gale.
	_add_spar(
		rack,
		"BackBrace",
		Vector3(-half, 0.1, SHORE_LEG_SPLAY * 0.85),
		Vector3(half, SHORE_TIER_HEIGHTS[0], SHORE_TIER_HALF_DEPTH[0] * 0.6),
		0.03,
		&"timber"
	)
	# Shore racks are cut from the same grey weathered poles as the net racks.
	var weathered := MapViewDryingNet.pole_wood()
	for spar in rack.get_children():
		if spar is MeshInstance3D and not String(spar.name).contains("Lashing"):
			(spar as MeshInstance3D).material_override = weathered
	if variant != _PropStyleVariants.FISH_RACK_EMPTY:
		_add_shore_catch(rack, rng, length, variant)
	return rack


## Hand-cut poles are never straight or equal: jitter each foot and tip.
static func _jitter(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.03, 0.03))


static func shore_attachment_point(x: float, tier: int, back_row: bool) -> Vector3:
	var z: float = SHORE_TIER_HALF_DEPTH[tier]
	return Vector3(x, SHORE_TIER_HEIGHTS[tier], z if back_row else -z)


static func _add_shore_catch(
	rack: Node3D, rng: RandomNumberGenerator, length: float, variant: StringName
) -> void:
	# WHY merged: a rack holds 40-60 fish; one node per fish would cost a draw call
	# each across a dozen racks. Fish are baked per species into one mesh, cords
	# into another, so a loaded rack is three draw calls.
	var tools := {}
	var cords := SurfaceTool.new()
	var cord_mesh := CylinderMesh.new()
	cord_mesh.top_radius = 0.006
	cord_mesh.bottom_radius = 0.006
	cord_mesh.height = 1.0
	cord_mesh.radial_segments = 3
	cord_mesh.rings = 1
	var fill: float = SHORE_FILL.get(variant, 0.7)
	var slots := maxi(1, floori((length - 0.2) / SHORE_FISH_SPACING))
	var count := 0
	for tier in SHORE_TIER_HEIGHTS.size():
		for side: float in [-1.0, 1.0]:
			for slot in slots:
				if rng.randf() > fill:
					continue
				var x := -length * 0.5 + 0.1 + (float(slot) + 0.5) * (length - 0.2) / float(slots)
				x += rng.randf_range(-0.03, 0.03)
				var species := _DriedFishMeshes.SPECIES_HERRING
				if variant == _PropStyleVariants.FISH_RACK_MIXED and rng.randf() < 0.35:
					species = _DriedFishMeshes.SPECIES_COD
				var scale := (
					rng.randf_range(0.82, 0.96)
					if species == _DriedFishMeshes.SPECIES_HERRING
					else rng.randf_range(0.74, 0.86)
				)
				var cord := rng.randf_range(0.05, 0.13)
				var top := shore_attachment_point(x, tier, side > 0.0)
				var fish_at := top + Vector3(0.0, -cord, 0.0)
				var fish_basis := Basis(Vector3.UP, rng.randf_range(-0.35, 0.35)).scaled(
					Vector3.ONE * scale
				)
				if not tools.has(species):
					var st := SurfaceTool.new()
					tools[species] = st
				(tools[species] as SurfaceTool).append_from(
					_DriedFishMeshes.mesh_for(species), 0, Transform3D(fish_basis, fish_at)
				)
				cords.append_from(
					cord_mesh,
					0,
					Transform3D(
						Basis.IDENTITY.scaled(Vector3(1.0, cord, 1.0)),
						top + Vector3(0.0, -cord * 0.5, 0.0)
					)
				)
				count += 1
	var catch_root := Node3D.new()
	catch_root.name = "DryingCatch"
	catch_root.set_meta(&"fish_rack_variant", variant)
	catch_root.set_meta(&"fish_count", count)
	rack.add_child(catch_root)
	for species: StringName in tools:
		var inst := MeshInstance3D.new()
		inst.name = "Catch_%s" % species
		inst.mesh = (tools[species] as SurfaceTool).commit()
		inst.material_override = _dried_material(species)
		inst.set_meta(&"dried_fish_species", species)
		catch_root.add_child(inst)
	if count > 0:
		var cord_inst := MeshInstance3D.new()
		cord_inst.name = "Cords"
		cord_inst.mesh = cords.commit()
		cord_inst.material_override = _lashing_material()
		catch_root.add_child(cord_inst)


## Fish left for days on a shore rack lose their silver: the skin dulls to a
## smoked grey-gold. Tints the shared species material instead of new meshes.
static func _dried_material(species: StringName) -> StandardMaterial3D:
	var key := "dried_%s" % species
	if _dried.has(key):
		return _dried[key]
	var material := _DriedFishMeshes.material_for(species).duplicate() as StandardMaterial3D
	material.albedo_color = Color(0.68, 0.62, 0.5)
	_dried[key] = material
	return material


static func _add_lashing(parent: Node3D, node_name: String, at: Vector3, radius: float) -> void:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = radius * 1.3
	mesh.radial_segments = 8
	mesh.rings = 1
	inst.mesh = mesh
	inst.position = at
	inst.rotation.z = PI * 0.5
	inst.material_override = _lashing_material()
	parent.add_child(inst)


static func _lashing_material() -> StandardMaterial3D:
	if _lashing == null:
		_lashing = StandardMaterial3D.new()
		_lashing.albedo_color = Color(0.34, 0.32, 0.27)
		_lashing.roughness = 1.0
	return _lashing
