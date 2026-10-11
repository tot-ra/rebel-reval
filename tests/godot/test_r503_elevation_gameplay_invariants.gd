extends "res://tests/godot/test_case.gd"

const URBAN_EXTERIOR_PATHS := [
	"res://content/maps/lower_town_slice.rrmap",
	"res://content/maps/market_civic_quarter.rrmap",
	"res://content/maps/monastery_quarter.rrmap",
	"res://content/maps/north_quarter.rrmap",
	"res://content/maps/south_quarter.rrmap",
	"res://content/maps/toompea_quarter.rrmap",
	"res://content/maps/archbishops_garden.rrmap",
	"res://content/maps/reval_harbor_north.rrmap",
	"res://content/maps/reval_harbor_east.rrmap",
]

const ELEVATION_LIMIT := 8.0


func _urban_definitions() -> Array[MapDefinition]:
	var definitions: Array[MapDefinition] = []
	for path in URBAN_EXTERIOR_PATHS:
		var parsed := MapRrmapParser.parse_file(path)
		assert_true(parsed.is_ok(), "%s must compile: %s" % [path, parsed.formatted_diagnostics()])
		if parsed.is_ok():
			definitions.append(parsed.definition)
	return definitions


func test_r503_elevation_values_are_finite_valid_and_scoped() -> void:
	var definitions := _urban_definitions()
	if definitions.size() != URBAN_EXTERIOR_PATHS.size():
		return

	for definition in definitions:
		var validation_errors := definition.validate()
		assert_true(
			validation_errors.is_empty(),
			"%s elevation/map validation: %s" % [definition.map_id, validation_errors]
		)
		assert_true(
			is_finite(definition.ground_elevation),
			"%s ground elevation must be finite" % definition.map_id
		)
		assert_true(
			definition.ground_elevation >= 0.0 and definition.ground_elevation <= ELEVATION_LIMIT,
			"%s ground elevation must stay within 0..8 view scope" % definition.map_id
		)
		for profile in definition.elevation_profiles:
			for key in [&"delta", &"height", &"start_height", &"end_height"]:
				if not profile.has(key):
					continue
				var value: Variant = profile[key]
				assert_true(
					value is int or value is float,
					"%s profile %s.%s must be numeric" % [definition.map_id, profile.get("id", ""), key]
				)
				if value is int or value is float:
					assert_true(
						is_finite(float(value)) and absf(float(value)) <= ELEVATION_LIMIT,
						"%s profile %s.%s must stay within -8..8" % [
							definition.map_id,
							profile.get("id", ""),
							key,
						]
					)


func test_r503_elevation_does_not_change_gameplay_geometry_or_navigation() -> void:
	var definitions := _urban_definitions()
	if definitions.size() != URBAN_EXTERIOR_PATHS.size():
		return

	for definition in definitions:
		var before_grid := MapBuilder.build(definition)
		var before_snapshot := _gameplay_snapshot(definition, before_grid)
		var original_elevation := definition.ground_elevation
		definition.ground_elevation = original_elevation + 0.25 if original_elevation < 7.75 else 7.5
		var profiles := definition.elevation_profiles.duplicate(true)
		profiles.append({
			"id": "r503.view_only_probe",
			"kind": &"grade",
			"direction": Vector2i.RIGHT,
			"delta": 0.25,
		})
		definition.elevation_profiles = profiles

		var after_grid := MapBuilder.build(definition)
		assert_eq(
			MapParitySnapshot.terrain_grid_fingerprint(after_grid),
			before_snapshot["terrain_grid"],
			"%s elevation must not alter terrain IDs" % definition.map_id
		)
		assert_eq(
			_gameplay_snapshot(definition, after_grid),
			before_snapshot,
			"%s elevation must remain outside gameplay geometry/navigation" % definition.map_id
		)


func test_r503_reciprocal_transitions_keep_identity_and_physical_seam_alignment() -> void:
	var definitions := _urban_definitions()
	if definitions.size() != URBAN_EXTERIOR_PATHS.size():
		return

	var pair_count := 0
	var physical_seam_count := 0
	for base_index in definitions.size():
		var base: MapDefinition = definitions[base_index]
		for neighbor_index in range(base_index + 1, definitions.size()):
			var neighbor: MapDefinition = definitions[neighbor_index]
			for pair in MapAlignmentMath.find_transition_pairs(base, neighbor):
				pair_count += 1
				var base_transition: Dictionary = pair["base"]
				var neighbor_transition: Dictionary = pair["neighbor"]
				var base_side := StringName(pair["base_side"])
				var neighbor_side := StringName(pair["neighbor_side"])
				assert_true(
					_opposite_sides(base_side, neighbor_side),
					"%s/%s seam must use opposite boundary sides" % [
						base_transition.get("id", ""),
						neighbor_transition.get("id", ""),
					]
				)
				assert_eq(
					StringName(base_transition.get("destination_spawn_id", "")),
					StringName(neighbor_transition.get("spawn_id", "")),
					"%s reciprocal destination identity" % base_transition.get("id", ""),
				)
				assert_eq(
					StringName(neighbor_transition.get("destination_spawn_id", "")),
					StringName(base_transition.get("spawn_id", "")),
					"%s reciprocal destination identity" % neighbor_transition.get("id", ""),
				)
				# Only the authored harbor pair is a physical seam with a shared
				# boundary span. Other reciprocal city transitions are travel gates
				# whose trigger widths intentionally differ between districts.
				if base.map_id == &"reval_harbor_north" and neighbor.map_id == &"reval_harbor_east":
					physical_seam_count += 1
					var base_span := MapAlignmentMath.seam_span_cells(base, base_transition, base_side)
					var neighbor_span := MapAlignmentMath.seam_span_cells(
						neighbor, neighbor_transition, neighbor_side
					)
					assert_true(
						is_equal_approx(base_span, neighbor_span),
						"%s/%s physical seam spans must match: %.3f != %.3f" % [
							base_transition.get("id", ""),
							neighbor_transition.get("id", ""),
							base_span,
							neighbor_span,
						]
					)
	assert_true(pair_count > 0, "urban exterior matrix must expose reciprocal transitions")
	assert_true(physical_seam_count > 0, "harbor maps must expose a physical reciprocal seam")


func _gameplay_snapshot(definition: MapDefinition, grid: MapTerrainGrid) -> Dictionary:
	return {
		"terrain_grid": MapParitySnapshot.terrain_grid_fingerprint(grid),
		"blocked_cells": MapVerification.blocked_cells(definition),
		"player_spawn": definition.player_spawn,
		"buildings": definition.buildings.duplicate(true),
		"props": definition.props.duplicate(true),
		"transitions": definition.transitions.duplicate(true),
		"anchors": definition.interaction_anchors.duplicate(true),
		"patrols": definition.patrols.duplicate(true),
		"excluded_areas": definition.excluded_areas.duplicate(true),
	}


func _opposite_sides(first: StringName, second: StringName) -> bool:
	return (
		(first == &"north" and second == &"south")
		or (first == &"south" and second == &"north")
		or (first == &"east" and second == &"west")
		or (first == &"west" and second == &"east")
	)
