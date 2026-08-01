extends "res://tests/godot/test_case.gd"
const EnvironmentKit := preload("res://scripts/map/view3d/map_view_environment_kit.gd")

## P0-102f: deterministic integration contract for the four shared environment-kit
## target spaces. The fixture deliberately consumes authored MapDefinitions rather
## than creating a parallel scene/map representation.

const KalevSmithyDefinition := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const LowerTownSliceDefinition := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapParitySnapshot := preload("res://scripts/map/map_parity_snapshot.gd")
const MapTypes := preload("res://scripts/map/map_types.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")
const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const MapViewMeshBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder.gd")


func test_four_target_spaces_share_one_deterministic_view_contract() -> void:
	var spaces := _space_specs()
	assert_eq(spaces.size(), 4, "P0-102 must cover forge, street/well, brewery, and checkpoint")

	for space in spaces:
		var definition: MapDefinition = space["definition"]
		var label := String(space["id"])
		assert_eq(definition.cell_size, MapTypes.DEFAULT_CELL_SIZE, "%s must keep the shared cell scale" % label)
		assert_true(MapBuilder.validate(definition).is_empty(), "%s authored map must validate" % label)

		var grid := MapBuilder.build(definition)
		var grid_fingerprint := grid.fingerprint()
		var definition_fingerprint := definition.fingerprint
		var transition_snapshot := MapParitySnapshot.serialize_value(definition.transitions)
		var patrol_snapshot := MapParitySnapshot.serialize_value(definition.patrols)

		for building_id in space["building_ids"]:
			_assert_building_uses_shared_builder(definition, StringName(building_id), label)
		for prop_id in space["prop_ids"]:
			_assert_prop_uses_shared_builder(definition, StringName(prop_id), label)
		for anchor_id in space["anchor_ids"]:
			assert_true(
				MapVerification.has_anchor(definition, StringName(anchor_id)),
				"%s must preserve interaction anchor %s" % [label, anchor_id]
			)
		for route in space["routes"]:
			var from_anchor := MapVerification.anchor_position(definition, StringName(route[0]))
			var to_anchor := MapVerification.anchor_position(definition, StringName(route[1]))
			assert_true(
				MapVerification.route_exists(definition, grid, from_anchor, to_anchor),
				"%s route %s -> %s must remain reachable" % [label, route[0], route[1]]
			)

		for transition_id in space["transition_ids"]:
			var transition := _record_by_id(definition.transitions, StringName(transition_id))
			if transition.is_empty():
				fail("%s must preserve transition %s" % [label, transition_id])
				continue
			assert_true(
				MapVerification.spawn_clears_transition_trigger(transition),
				"%s transition %s must keep arrival clearance" % [label, transition_id]
			)

		for patrol_id in space["patrol_ids"]:
			var patrol := _record_by_id(definition.patrols, StringName(patrol_id))
			if patrol.is_empty():
				fail("%s must preserve patrol %s" % [label, patrol_id])
				continue
			for point in patrol.get("points", []):
				assert_true(
					point is Vector2 and _point_inside_map(definition, point),
					"%s patrol %s must stay inside authored map bounds" % [label, patrol_id]
				)

		# View construction is presentation-only. Building the same modules must not
		# rewrite logic data, route records, patrols, or the canonical terrain grid.
		assert_eq(grid.fingerprint(), grid_fingerprint, "%s view build changed terrain fingerprint" % label)
		assert_eq(definition.fingerprint, definition_fingerprint, "%s view build changed map fingerprint" % label)
		assert_eq(
			MapParitySnapshot.serialize_value(definition.transitions),
			transition_snapshot,
			"%s view build changed transition records" % label
		)
		assert_eq(
			MapParitySnapshot.serialize_value(definition.patrols),
			patrol_snapshot,
			"%s view build changed patrol records" % label
		)


func test_checkpoint_keeps_exceptional_gate_context_outside_ordinary_house_kit() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var north_tower := _record_by_id(definition.buildings, &"viru_gate_north_tower")
	var south_tower := _record_by_id(definition.buildings, &"viru_gate_south_tower")
	if north_tower.is_empty() or south_tower.is_empty():
		fail("checkpoint must retain both Viru gate tower records")
		return
	for tower in [north_tower, south_tower]:
		assert_eq(tower.get("kind"), MapTypes.BUILDING_KIND_WALL, "gate towers stay fortification records")
		assert_true(bool(tower.get("round_tower", false)), "gate towers keep their authored round form")
		var node := MapViewMeshBuilder.build_building(tower, definition.cell_size)
		assert_true(node.has_node("Walls"), "gate tower needs a shared wall mass")
		assert_false(node.has_node("Roof"), "gate tower must not fall through the ordinary house roof path")
		_assert_view_only(node, "gate tower")
		node.free()

	var gate_arches := definition.view_landmarks.filter(
		func(landmark: Dictionary) -> bool: return landmark.get("kind") == &"gate_arch"
	)
	assert_true(gate_arches.size() >= 2, "checkpoint gate leaves remain separate view landmarks")


func _space_specs() -> Array[Dictionary]:
	var smithy := KalevSmithyDefinition.create()
	var lower_town := LowerTownSliceDefinition.create()
	return [
		{
			"id": &"forge",
			"definition": smithy,
			"building_ids": [&"wall.north_forge/segment.000", &"wall.south_forge", &"wall.divider/segment.000"],
			"prop_ids": [&"forge_anvil", &"forge_furnace", &"forge_bellows", &"forge_tongs"],
			"anchor_ids": [&"anvil", &"ledger", &"bed_alcove"],
			"routes": [[&"anvil", &"ledger"], [&"ledger", &"bed_alcove"]],
			"transition_ids": [&"door_courtyard"],
			"patrol_ids": [],
		},
		{
			"id": &"street_well",
			"definition": lower_town,
			"building_ids": [&"kalev_smithy"],
			"prop_ids": [&"cistern", &"cistern_wash_tub", &"monastery_well"],
			"anchor_ids": [&"street_start", &"checkpoint_east", &"monastery_gate"],
			"routes": [[&"street_start", &"checkpoint_east"], [&"street_start", &"monastery_gate"]],
			"transition_ids": [],
			"patrol_ids": [],
		},
		{
			"id": &"brewery",
			"definition": lower_town,
			"building_ids": [&"foaming_mug_brewery"],
			"prop_ids": [&"brewery_keg_stack", &"brewery_malt_sacks", &"evidence_barrels"],
			"anchor_ids": [&"street_start", &"brewery_door"],
			"routes": [[&"street_start", &"brewery_door"]],
			"transition_ids": [],
			"patrol_ids": [],
		},
		{
			"id": &"checkpoint",
			"definition": lower_town,
			"building_ids": [&"viru_gate_north_tower", &"viru_gate_south_tower"],
			"prop_ids": [&"market_stall_gate", &"gate_cart"],
			"anchor_ids": [&"checkpoint_west", &"checkpoint_east"],
			"routes": [[&"checkpoint_west", &"checkpoint_east"]],
			"transition_ids": [&"viru_road_boundary"],
			"patrol_ids": [&"viru_watch", &"iron_convoy"],
		},


	]


func test_forge_and_street_well_modules_are_deterministic_view_only_assemblies() -> void:
	var smithy := KalevSmithyDefinition.create()
	var lower_town := LowerTownSliceDefinition.create()
	var modules := [
		[EnvironmentKit.MODULE_FORGE_INTERIOR, EnvironmentKit.build_forge_interior(smithy)],
		[EnvironmentKit.MODULE_FORGE_YARD, EnvironmentKit.build_forge_yard(lower_town)],
		[EnvironmentKit.MODULE_STREET_WELL, EnvironmentKit.build_street_well(lower_town)],
	]
	for entry in modules:
		var module_id: StringName = entry[0]
		var first: Node3D = entry[1]
		var second: Node3D = _build_module(module_id, smithy, lower_town)
		assert_eq(first.get_meta(&"environment_module"), module_id, "%s must expose its stable module id" % module_id)
		assert_true(bool(first.get_meta(&"view_only", false)), "%s must be view-only" % module_id)
		assert_true(
			first.find_children("*", "MeshInstance3D", true, false).size() > 0,
			"%s must assemble renderable geometry" % module_id
		)
		assert_eq(
			_node_signature(first),
			_node_signature(second),
			"%s construction must be deterministic" % module_id
		)
		_assert_view_only(first, "%s environment module" % module_id)
		first.free()
		second.free()


func test_forge_and_street_well_keep_clearance_and_local_wear_contract() -> void:
	var smithy := KalevSmithyDefinition.create()
	var smithy_grid: MapTerrainGrid = MapBuilder.build(smithy)
	var forge_module := EnvironmentKit.build_forge_interior(smithy)
	assert_true(forge_module.get_node("Buildings").get_child_count() >= 3, "forge shell must include shared wall segments")
	assert_true(forge_module.get_node("Props").get_child_count() >= 9, "forge module must include the work/fuel grouping")
	assert_true(
		MapVerification.route_exists(smithy, smithy_grid, smithy.player_spawn, MapVerification.anchor_position(smithy, &"anvil")),
		"forge assembly must preserve the player-to-anvil approach"
	)
	assert_true(
		_has_decal(smithy, &"decal.soot_furnace_pad", MapTypes.DECAL_KIND_SOOT)
		and _has_decal(smithy, &"decal.soot_anvil_apron", MapTypes.DECAL_KIND_SOOT)
		and _has_decal(smithy, &"decal.grime_quench", MapTypes.DECAL_KIND_GRIME),
		"forge assembly must retain local soot and quench wear cues"
	)
	forge_module.free()

	var lower_town := LowerTownSliceDefinition.create()
	var lower_town_grid: MapTerrainGrid = MapBuilder.build(lower_town)
	var yard_module := EnvironmentKit.build_forge_yard(lower_town)
	var well_module := EnvironmentKit.build_street_well(lower_town)
	var smithy_door := MapVerification.anchor_position(lower_town, &"smithy_door")
	var firewood := MapVerification.prop_position(lower_town, &"courtyard_firewood")
	assert_true(
		MapVerification.route_exists(lower_town, lower_town_grid, MapVerification.anchor_position(lower_town, &"street_start"), smithy_door),
		"forge yard must keep the street-to-smithy route open"
	)
	assert_true(firewood.distance_to(smithy_door) > float(lower_town.cell_size * 2), "yard fuel must keep the door apron clear")
	assert_true(yard_module.get_node("Buildings").get_child_count() >= 3, "forge yard must include shell and fence families")
	assert_true(well_module.get_node("Props").get_child_count() == 3, "street/well must include both wells and the wash vessel")

	var cistern := _prop_by_id(lower_town, &"cistern")
	var wash_tub := _prop_by_id(lower_town, &"cistern_wash_tub")
	assert_true(cistern["position"].distance_to(wash_tub["position"]) <= float(lower_town.cell_size * 3), "wash vessel must stay within the well apron")
	assert_true(MapVerification.is_walkable_point(lower_town, lower_town_grid, cistern["position"]), "well center must not become a gameplay blocker")
	assert_true(
		MapVerification.route_exists(lower_town, lower_town_grid, MapVerification.anchor_position(lower_town, &"street_start"), MapVerification.anchor_position(lower_town, &"checkpoint_east")),
		"street/well dressing must preserve the through-route"
	)
	assert_true(_has_decal(lower_town, &"decal.wet_cistern", MapTypes.DECAL_KIND_WET_THRESHOLD), "well apron needs a wet threshold cue")
	assert_true(_has_decal(lower_town, &"decal.grime_courtyard_firewood", MapTypes.DECAL_KIND_GRIME), "forge yard needs local grime wear")
	_assert_view_only(yard_module, "forge yard environment module")
	_assert_view_only(well_module, "street/well environment module")
	yard_module.free()
	well_module.free()


func _build_module(module_id: StringName, smithy: MapDefinition, lower_town: MapDefinition) -> Node3D:
	match module_id:
		EnvironmentKit.MODULE_FORGE_INTERIOR:
			return EnvironmentKit.build_forge_interior(smithy)
		EnvironmentKit.MODULE_FORGE_YARD:
			return EnvironmentKit.build_forge_yard(lower_town)
		EnvironmentKit.MODULE_STREET_WELL:
			return EnvironmentKit.build_street_well(lower_town)
	return Node3D.new()


func _node_signature(root: Node) -> Array[String]:
	var signature: Array[String] = []
	_signature_walk(root, signature)
	return signature


func _signature_walk(node: Node, signature: Array[String]) -> void:
	signature.append("%s:%s:%d" % [node.name, node.get_class(), node.get_child_count()])
	for child in node.get_children():
		_signature_walk(child, signature)


func _has_decal(definition: MapDefinition, decal_id: StringName, kind: StringName) -> bool:
	for decal in definition.decals:
		if decal.get("id", &"") == decal_id and decal.get("kind", &"") == kind:
			return true
	return false


func _prop_by_id(definition: MapDefinition, prop_id: StringName) -> Dictionary:
	for prop in definition.props:
		if prop.get("id", &"") == prop_id:
			return prop
	return {}


func _assert_building_uses_shared_builder(
	definition: MapDefinition,
	building_id: StringName,
	label: String,
) -> void:
	var building := _record_by_id(definition.buildings, building_id)
	if building.is_empty():
		fail("%s must contain building %s" % [label, building_id])
		return
	var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
	var expected_position := MapViewBridge.logic_to_world(
		(building["footprint"] as Rect2).get_center(),
		definition.cell_size
	)
	assert_true(
		node.position.is_equal_approx(expected_position),
		"%s building %s must use the shared cell-to-metre pivot" % [label, building_id]
	)
	var walls := node.get_node_or_null("Walls") as MeshInstance3D
	assert_true(walls != null, "%s building %s must expose a shared wall surface" % [label, building_id])
	var material := walls.material_override as StandardMaterial3D
	assert_true(material != null, "%s building %s must use a shared PBR material interface" % [label, building_id])
	assert_true(material.albedo_texture != null, "%s building %s must carry a material pattern" % [label, building_id])
	_assert_view_only(node, "%s building %s" % [label, building_id])
	node.free()


func _assert_prop_uses_shared_builder(
	definition: MapDefinition,
	prop_id: StringName,
	label: String,
) -> void:
	var prop := _record_by_id(definition.props, prop_id)
	if prop.is_empty():
		fail("%s must contain prop %s" % [label, prop_id])
		return
	var node := MapViewMeshBuilder.build_prop(prop, definition.cell_size, definition)
	var expected_position := MapViewBridge.logic_to_world(prop["position"], definition.cell_size)
	if prop.has("visual_offset_px"):
		var offset: Vector2 = prop["visual_offset_px"]
		expected_position.x += offset.x * MapViewBridge.world_scale(definition.cell_size)
		expected_position.y -= offset.y * MapViewBridge.world_scale(definition.cell_size)
	assert_true(
		node.position.is_equal_approx(expected_position),
		"%s prop %s must use the shared cell-to-metre pivot" % [label, prop_id]
	)
	assert_true(node.find_children("*", "MeshInstance3D", true, false).size() > 0, "%s prop %s needs view geometry" % [label, prop_id])
	_assert_view_only(node, "%s prop %s" % [label, prop_id])
	node.free()


func _assert_view_only(node: Node, label: String) -> void:
	assert_eq(node.find_children("*", "CollisionShape2D", true, false).size(), 0, "%s must not author 2D collision" % label)
	assert_eq(node.find_children("*", "CollisionShape3D", true, false).size(), 0, "%s must not author 3D collision" % label)
	assert_eq(node.find_children("*", "NavigationRegion2D", true, false).size(), 0, "%s must not author 2D navigation" % label)
	assert_eq(node.find_children("*", "NavigationRegion3D", true, false).size(), 0, "%s must not author 3D navigation" % label)


func _record_by_id(records: Array, record_id: StringName) -> Dictionary:
	for record in records:
		if record.get("id", &"") == record_id:
			return record
	return {}


func _point_inside_map(definition: MapDefinition, point: Vector2) -> bool:
	return point.x >= 0.0 and point.y >= 0.0 and point.x <= definition.world_size().x and point.y <= definition.world_size().y
