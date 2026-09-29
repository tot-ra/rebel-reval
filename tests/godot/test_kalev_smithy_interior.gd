extends "res://tests/godot/map_view_3d_test_base.gd"

## Authored Kalev smithy interior: the kit replaces generic presentation only,
## while rrmap walls, windows and doors keep gameplay authority.


func test_view_installs_authored_shell_and_keeps_wall_proxies() -> void:
	var view := _smithy_view()
	assert_true(view.has_node("AuthoredInterior"), "smithy view needs the authored room shell")
	var shell := view.get_node("AuthoredInterior") as Node3D
	var materials := {}
	for child in shell.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_surface_override_material(surface)
			assert_true(
				material != null,
				"%s surface %d needs a kit material" % [mesh_instance.name, surface]
			)
			materials[String(material.resource_name)] = true
	for key in ["ksi_limestone", "ksi_limewash", "ksi_oak", "ksi_boards", "ksi_earth"]:
		assert_true(materials.has(key), "room shell needs %s" % key)
	var wall_nodes := 0
	for building in view.get_node("Buildings").get_children():
		var walls := building.get_node_or_null("Walls") as MeshInstance3D
		if walls == null:
			continue
		wall_nodes += 1
		# The generic plinth/rail/post grid is gone; the hidden box still reports
		# the wall AABB to the occluded-actor probe.
		assert_eq(building.get_child_count(), 1, "%s keeps only its proxy box" % building.name)
		assert_false(walls.visible, "%s proxy must not render" % building.name)
	assert_true(wall_nodes >= 10, "every rrmap interior wall segment still streams in")
	view.free()


func test_window_panes_sit_inside_the_embrasures() -> void:
	var view := _smithy_view()
	var windows := 0
	for landmark in view.get_node("Landmarks").get_children():
		if not landmark.has_node("Window0"):
			continue
		windows += 1
		assert_false(
			landmark.has_node("WallAbove0"), "generic infill is replaced by the authored embrasure"
		)
		assert_true(
			landmark.has_node("InteriorWindowLights/WindowDaylight0"),
			"daylight projector survives the refit"
		)
		var pane := landmark.get_node("Window0") as MeshInstance3D
		var world := (landmark as Node3D).transform * pane.transform
		var p := world.origin
		# Panes stand in the outer third of the 1 m perimeter wall, never in the room.
		var in_wall := p.z < 1.0 or p.z > 13.0 or p.x < 1.0 or p.x > 25.0
		assert_true(in_wall, "%s pane must sit inside the wall thickness" % landmark.name)
		assert_true(p.y > 1.0 and p.y < 3.2, "%s pane must sit at window height" % landmark.name)
		var light := landmark.get_node("InteriorWindowLights/WindowDaylight0") as SpotLight3D
		var inward := Vector3(-pane.position.x, 0.0, -pane.position.z).normalized()
		assert_true((-light.basis.z).dot(inward) > 0.99, "daylight still points into the room")
	assert_eq(windows, 4, "all four rrmap windows keep a glowing pane")
	view.free()


func test_courtyard_door_and_ceiling_use_authored_surrounds() -> void:
	var view := _smithy_view()
	var door := view.get_node("Doors/Door_door_courtyard") as Node3D
	assert_true(door.has_node("Panel"), "interactive door leaf stays procedural")
	for infill in ["OpeningJambL", "OpeningJambR", "OpeningHead"]:
		assert_false(door.has_node(infill), "stone reveal replaces generic %s" % infill)
	var shell := view.get_node("InteriorShell") as Node3D
	assert_eq(shell.get_child_count(), 2, "loft ceiling replaces the generic slab and beams")
	assert_true(shell.has_node("DaylightOccluder"), "roof shadow twin stays")
	var ceiling := shell.get_node("Ceiling") as Node3D
	assert_false(ceiling.visible, "top-down gameplay hides the loft")
	view.set_close_camera_mode(true)
	assert_true(ceiling.visible, "close cameras show the loft")
	view.free()


func test_forge_hand_tools_use_kit_iron_and_rest_on_the_anvil() -> void:
	var view := _smithy_view()
	var hammer := view.get_node("Props/Prop_forge_hammer") as Node3D
	var anvil := view.get_node("Props/Prop_forge_anvil") as Node3D
	var found_iron := false
	# The view's static batcher may merge the tool into Batched* nodes that carry
	# the material as material_override; the active material covers both cases.
	for child in hammer.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface)
			if material != null and String(material.resource_name) == "ksi_iron":
				found_iron = true
	assert_true(found_iron, "forge hammer takes the kit's wrought iron")
	assert_true(absf(hammer.position.y - 0.8) < 0.02, "hammer rests on the block anvil face")
	var face_offset := Vector2(
		hammer.position.x - anvil.position.x, hammer.position.z - (anvil.position.z + 0.5)
	)
	assert_true(face_offset.length() < 0.2, "hammer stands on the anvil face, not beside the stump")
	view.free()


func test_enclosed_interior_light_is_bounced_not_sky_blue() -> void:
	var view := _smithy_view()
	view.apply_cycle_progress(0.5)
	var environment := (view.get_node("ViewEnvironment") as WorldEnvironment).environment
	assert_eq(
		environment.reflected_light_source,
		Environment.REFLECTION_SOURCE_DISABLED,
		"indoor iron and water must not mirror the sky dome"
	)
	var ambient := environment.ambient_light_color
	assert_true(ambient.r >= ambient.b, "daytime indoor fill is warm limewash bounce, not sky blue")
	view.free()


func test_finishing_bench_fills_the_south_forge_floor_with_kit_materials() -> void:
	var view := _smithy_view()
	var bench := view.get_node("Props/Prop_finishing_bench") as Node3D
	assert_true(
		bench.has_node("SmithyFinishingBenchModel"),
		"the finishing bench must take the authored GLB, not the household table"
	)
	# Dossier placement: on the customer route between the anvil (z 6) and the
	# courtyard door. It must stay off the last floor row, which the gameplay
	# isometric camera hides behind the south wall head.
	assert_true(bench.position.z > 8.0, "bench must stand south of the anvil")
	assert_true(bench.position.z < 11.6, "bench must stay inside the camera-visible floor")
	assert_true(
		bench.position.x > 15.0 and bench.position.x < 25.0, "bench belongs to the forge bay"
	)
	var bounds := AABB()
	var first := true
	var materials := {}
	for child in bench.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var child_bounds := mesh_instance.transform * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface)
			if material != null:
				materials[String(material.resource_name)] = true
	assert_false(first, "bench GLB must expose renderable geometry")
	assert_true(bounds.position.y >= -0.001, "bench feet rest on the bay floor")
	assert_true(bounds.size.y > 0.9 and bounds.size.y < 1.3, "top and stake reach working height")
	assert_true(
		bounds.size.x > 2.2 and bounds.size.x < 3.0, "bench stays inside its 3-cell footprint"
	)
	for key in ["ksi_oak", "ksi_iron", "ksi_iron_bright"]:
		assert_true(materials.has(key), "bench needs %s from the kit" % key)
	view.free()


func test_bellows_leather_keeps_hue_separation_under_the_forge_key() -> void:
	# Regression: the shared prop leather plus a saturated hearth key crushed the
	# bag's green and blue channels to zero, so it rendered as a red-black blob.
	var leather := MapViewKalevSmithyInterior.material_for("ksi_leather") as StandardMaterial3D
	var albedo := leather.albedo_color
	assert_true(albedo.g > 0.26, "leather must stay bright enough to survive the firelight")
	assert_true(albedo.b > 0.17, "leather blue channel must not quantise away")
	var fire := ForgeFireLight3D.FIRE_COLOR
	assert_true(fire.b > 0.3, "the charcoal key must keep a blue component")
	assert_true(albedo.b * fire.b * 3.0 > 0.02, "lit leather keeps a measurable blue response")


func test_kit_plates_let_the_roughness_texture_govern() -> void:
	# Godot multiplies roughness_texture into `roughness`; keeping a scalar below
	# 1.0 alongside a plate lacquered every beam and shelf in the bay.
	for key in ["ksi_oak", "ksi_limewash", "ksi_clay"]:
		var material := MapViewKalevSmithyInterior.material_for(key) as StandardMaterial3D
		assert_true(material.roughness_texture != null, "%s is plate-driven" % key)
		assert_eq(material.roughness, 1.0, "%s must let its plate govern roughness" % key)
		assert_true(
			material.metallic_specular < 0.4, "%s must not throw a polished highlight" % key
		)


func _smithy_view() -> MapView3D:
	var definition := KalevSmithyDefinition.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	view.activate_all_chunks()
	return view
