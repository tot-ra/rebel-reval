class_name MapWorldLayout
extends RefCounted

## Runtime-neutral global layout contract for a contiguous group of maps.
## Authored map coordinates remain local; origins and seams are derived once from
## reciprocal physical transitions so load order cannot invent world placement.

const DEFAULT_WORLD_GROUP_ID := &"reval_outdoor"
const LOCATION_KIND_OUTDOOR := &"outdoor_streamed"
const LOCATION_KIND_TRAVEL := &"travel"
const EPSILON := 0.001
## Stable seam diagnostic codes (manifest, verifier and tests match on them).
const DIAG_SEAM_NO_SIDE := "MAP_WORLD_SEAM_NO_SIDE"
const DIAG_SEAM_SIDES_NOT_OPPOSITE := "MAP_WORLD_SEAM_SIDES_NOT_OPPOSITE"
const DIAG_SEAM_CELL_SIZE_MISMATCH := "MAP_WORLD_SEAM_CELL_SIZE_MISMATCH"
const DIAG_SEAM_SPAN_MISMATCH := "MAP_WORLD_SEAM_SPAN_MISMATCH"
const DIAG_SEAM_ORIGIN_CONFLICT := "MAP_WORLD_SEAM_ORIGIN_CONFLICT"
const DIAG_SEAM_OUTSIDE_GROUP := "MAP_WORLD_SEAM_OUTSIDE_GROUP"
const DIAG_NOT_A_MEMBER := "MAP_WORLD_NOT_A_MEMBER"
const DIAG_MEMBER_MISSING := "MAP_WORLD_MEMBER_MISSING"
const DIAG_TRAVEL_ALIGNMENT_MISSING := "MAP_WORLD_TRAVEL_ALIGNMENT_MISSING"
## UF-15d / R-1217 registry and gate-bridge diagnostics (ADR 0027 section 5).
## Stable API like the seam codes above: add new codes, never rename.
const DIAG_GROUP_UNKNOWN := "MAP_WORLD_GROUP_UNKNOWN"
const DIAG_MEMBER_DUPLICATE := "MAP_WORLD_MEMBER_DUPLICATE"
const DIAG_CROSS_GROUP_UNDECLARED := "MAP_WORLD_CROSS_GROUP_SEAM_UNDECLARED"
const DIAG_KIND_PHYSICAL_SEAM := "MAP_WORLD_KIND_PHYSICAL_SEAM"
const DIAG_BRIDGE_ENDPOINT_UNKNOWN := "MAP_WORLD_BRIDGE_ENDPOINT_UNKNOWN"
const DIAG_BRIDGE_NOT_RECIPROCAL := "MAP_WORLD_BRIDGE_NOT_RECIPROCAL"
const DIAG_BRIDGE_SIDES_NOT_OPPOSITE := "MAP_WORLD_BRIDGE_SIDES_NOT_OPPOSITE"
const DIAG_BRIDGE_WIDTH_MISMATCH := "MAP_WORLD_BRIDGE_WIDTH_MISMATCH"
const DIAG_BRIDGE_TRANSFORM_INVALID := "MAP_WORLD_BRIDGE_TRANSFORM_INVALID"
const MANIFEST_SCHEMA := "rr.world_layout.v1"
const REVAL_OUTDOOR_MANIFEST_PATH := "res://content/world/reval_outdoor_layout.json"
const SEAM_STATUS_STREAMABLE := "streamable"
const SEAM_STATUS_BLOCKED := "blocked"
const EXPLICIT_REASON_TRAVEL := "travel_alignment"
const EXPLICIT_REASON_OUTSIDE := "outside_group"
const EXPLICIT_REASON_UNPAIRED := "unpaired"
## The accepted `reval_outdoor` membership (docs/SEAMLESS_STREAMING_PLAN.md,
## R-977 / R-1016). Interiors and every world.* map stay explicit transitions.
## scene_id is the DoorNavigator destination id the transitions use (`to=`).
const REVAL_OUTDOOR_MEMBERS := [
	{"location_id": &"archbishops_garden", "scene_id": &"reval_archbishops_garden"},
	{"location_id": &"lower_town_slice", "scene_id": &"reval_east"},
	{"location_id": &"market_civic_quarter", "scene_id": &"reval_center"},
	{"location_id": &"monastery_quarter", "scene_id": &"reval_monastery"},
	{"location_id": &"north_quarter", "scene_id": &"reval_north"},
	{"location_id": &"reval_harbor_east", "scene_id": &"reval_harbor_east"},
	{"location_id": &"reval_harbor_north", "scene_id": &"reval_harbor_north"},
	{"location_id": &"south_quarter", "scene_id": &"reval_south"},
	{"location_id": &"toompea_quarter", "scene_id": &"reval_toompea"},
	{"location_id": &"viru_gate_foreland", "scene_id": &"viru_gate_foreland"},
]
## Named group registry. `reval_hinterland` is declared with no members until UF-15
## (R-1133) fills it, so the tool accepts it without writing an empty manifest.
const WORLD_GROUPS := [
	{
		"id": &"reval_outdoor",
		"members": REVAL_OUTDOOR_MEMBERS,
		"root_location_id": &"lower_town_slice",
		"manifest_path": REVAL_OUTDOOR_MANIFEST_PATH,
	},
	{
		"id": &"reval_hinterland",
		"members": [],
		"root_location_id": &"",
		"manifest_path": "res://content/world/reval_hinterland_layout.json",
	},
]
## Allowlisted inter-group gate bridges (ships empty; UF-15 adds the five ADR 0027
## rows). Row shape: {group_a, map_a, transition_a, group_b, map_b, transition_b,
## transform}. `transform` maps group_b canonical cells into group_a space:
## {"rotate_quarters": 0..3 (clockwise), "translate_cells": [x, y]}, applied as
## rotate then translate. Integers only, so there is no float drift.
const GATE_BRIDGES := []
## Clockwise quarter turn of a side, used to compare sides across group spaces.
const SIDE_CLOCKWISE := {
	&"north": &"east",
	&"east": &"south",
	&"south": &"west",
	&"west": &"north",
}
const OPPOSITE_SIDES := {
	&"north": &"south",
	&"south": &"north",
	&"east": &"west",
	&"west": &"east",
}


## Registry row for a group id, or {} when the id is not declared.
static func group_entry(group_id: StringName, groups: Array = WORLD_GROUPS) -> Dictionary:
	for group_value in groups:
		var group: Dictionary = group_value as Dictionary
		if StringName(group["id"]) == group_id:
			return group.duplicate(true)
	return {}


## Rotate (clockwise quarters) then translate a group-b cell into group-a space.
static func transform_cell(cell: Vector2i, transform: Dictionary) -> Vector2i:
	var rotated := cell
	for _turn in posmod(int(transform.get("rotate_quarters", 0)), 4):
		# Clockwise on a y-down grid: (x, y) -> (-y, x).
		rotated = Vector2i(-rotated.y, rotated.x)
	var shift: Array = transform.get("translate_cells", [0, 0])
	return rotated + Vector2i(int(shift[0]), int(shift[1]))


## Exact inverse: undo the translation, then rotate the remaining quarters.
static func invert_transform_cell(cell: Vector2i, transform: Dictionary) -> Vector2i:
	var shift: Array = transform.get("translate_cells", [0, 0])
	var unshifted := cell - Vector2i(int(shift[0]), int(shift[1]))
	for _turn in posmod(-int(transform.get("rotate_quarters", 0)), 4):
		unshifted = Vector2i(-unshifted.y, unshifted.x)
	return unshifted


static func rotate_side(side: StringName, quarters: int) -> StringName:
	var rotated := side
	for _turn in posmod(quarters, 4):
		rotated = SIDE_CLOCKWISE.get(rotated, &"")
	return rotated


## Registry-level rules that need no compiled maps: unknown group ids, a member
## declared twice (in one group or two), bridge rows that name an unknown group or
## a map that is not a member of it, and malformed transforms.
static func validate_registry(
	groups: Array = WORLD_GROUPS, bridges: Array = GATE_BRIDGES
) -> Array[String]:
	var errors: Array[String] = []
	var owner_of: Dictionary = {}
	for group_value in groups:
		var group: Dictionary = group_value as Dictionary
		for member_value in group["members"]:
			var location_id := String((member_value as Dictionary)["location_id"])
			if owner_of.has(location_id):
				errors.append(
					"%s %s is declared in %s and %s"
					% [DIAG_MEMBER_DUPLICATE, location_id, owner_of[location_id], group["id"]]
				)
			else:
				owner_of[location_id] = String(group["id"])
	for bridge_value in bridges:
		var bridge: Dictionary = bridge_value as Dictionary
		var label := _bridge_label(bridge)
		for side in ["a", "b"]:
			var group_id := StringName(bridge.get("group_" + side, ""))
			var map_id := String(bridge.get("map_" + side, ""))
			if group_entry(group_id, groups).is_empty():
				errors.append("%s bridge %s names group %s" % [DIAG_GROUP_UNKNOWN, label, group_id])
			elif owner_of.get(map_id, "") != String(group_id):
				errors.append(
					"%s bridge %s: %s is not a member of %s"
					% [DIAG_BRIDGE_ENDPOINT_UNKNOWN, label, map_id, group_id]
				)
		if StringName(bridge.get("group_a", "")) == StringName(bridge.get("group_b", "")):
			errors.append("%s bridge %s joins a group to itself" % [DIAG_BRIDGE_ENDPOINT_UNKNOWN, label])
		var transform: Dictionary = bridge.get("transform", {})
		var shift: Variant = transform.get("translate_cells", null)
		var quarters: Variant = transform.get("rotate_quarters", null)
		if not (shift is Array and (shift as Array).size() == 2 and quarters is int):
			errors.append("%s bridge %s needs integer rotate_quarters and translate_cells" % [DIAG_BRIDGE_TRANSFORM_INVALID, label])
		else:
			for component in shift:
				if not component is int:
					errors.append("%s bridge %s translate_cells must be integers" % [DIAG_BRIDGE_TRANSFORM_INVALID, label])
					break
			if int(quarters) < 0 or int(quarters) > 3:
				errors.append("%s bridge %s rotate_quarters must be 0..3" % [DIAG_BRIDGE_TRANSFORM_INVALID, label])
	errors.sort()
	return errors


## Compiled-map rules for the bridge allowlist. `definitions` is every compiled
## member across groups (Array[MapDefinition]); `scene_ids` maps map_id to the
## DoorNavigator scene id from the registry. Each bridge must be reciprocal (each
## transition leads to the other map), land on opposite sides once group b is
## rotated into group a's space, and be equally wide. Gate height and form
## continuity stay with the UF-08 seam-continuity gate.
static func validate_bridges(
	definitions: Array[MapDefinition],
	scene_ids: Dictionary,
	bridges: Array = GATE_BRIDGES
) -> Array[String]:
	var errors: Array[String] = []
	var by_id := _definitions_by_id(definitions)
	for bridge_value in bridges:
		var bridge: Dictionary = bridge_value as Dictionary
		var label := _bridge_label(bridge)
		var map_a: MapDefinition = by_id.get(StringName(bridge.get("map_a", "")))
		var map_b: MapDefinition = by_id.get(StringName(bridge.get("map_b", "")))
		var transition_a := _transition_by_id(map_a, StringName(bridge.get("transition_a", "")))
		var transition_b := _transition_by_id(map_b, StringName(bridge.get("transition_b", "")))
		if transition_a.is_empty() or transition_b.is_empty():
			errors.append("%s bridge %s names a map or transition that does not exist" % [DIAG_BRIDGE_ENDPOINT_UNKNOWN, label])
			continue
		if (
			String(transition_a.get("destination_scene_id", "")) != String(scene_ids.get(map_b.map_id, ""))
			or String(transition_b.get("destination_scene_id", "")) != String(scene_ids.get(map_a.map_id, ""))
		):
			errors.append("%s bridge %s: the far side does not lead back" % [DIAG_BRIDGE_NOT_RECIPROCAL, label])
			continue
		var side_a := MapAlignmentMath.transition_side(map_a, transition_a)
		var side_b := MapAlignmentMath.transition_side(map_b, transition_b)
		var quarters := int((bridge.get("transform", {}) as Dictionary).get("rotate_quarters", 0))
		if OPPOSITE_SIDES.get(side_a, &"") != rotate_side(side_b, quarters):
			errors.append("%s bridge %s: sides %s and %s are not opposite after rotation" % [DIAG_BRIDGE_SIDES_NOT_OPPOSITE, label, side_a, side_b])
		var span_a := MapAlignmentMath.seam_span_cells(map_a, transition_a, side_a)
		var span_b := MapAlignmentMath.seam_span_cells(map_b, transition_b, side_b)
		if not is_equal_approx(span_a, span_b):
			errors.append("%s bridge %s: spans %s and %s differ" % [DIAG_BRIDGE_WIDTH_MISMATCH, label, span_a, span_b])
	errors.sort()
	return errors


## Every non-travel transition that leaves its group for another group's member.
## Each one must be an allowlisted bridge endpoint or it is an undeclared seam.
static func validate_cross_group_seams(
	definitions: Array[MapDefinition],
	groups: Array = WORLD_GROUPS,
	bridges: Array = GATE_BRIDGES
) -> Array[String]:
	var errors: Array[String] = []
	var group_of_scene: Dictionary = {}
	var group_of_map: Dictionary = {}
	for group_value in groups:
		var group: Dictionary = group_value as Dictionary
		for member_value in group["members"]:
			var member: Dictionary = member_value as Dictionary
			group_of_scene[String(member["scene_id"])] = String(group["id"])
			group_of_map[String(member["location_id"])] = String(group["id"])
	var allowed: Dictionary = {}
	for bridge_value in bridges:
		var bridge: Dictionary = bridge_value as Dictionary
		allowed["%s/%s" % [bridge.get("map_a", ""), bridge.get("transition_a", "")]] = true
		allowed["%s/%s" % [bridge.get("map_b", ""), bridge.get("transition_b", "")]] = true
	for definition in definitions:
		var own_group: String = group_of_map.get(String(definition.map_id), "")
		for transition in definition.transitions:
			var destination := String(transition.get("destination_scene_id", ""))
			var far_group: String = group_of_scene.get(destination, "")
			if own_group.is_empty() or far_group.is_empty() or far_group == own_group:
				continue
			if String(transition.get("alignment", "edge")) == String(LOCATION_KIND_TRAVEL):
				continue
			var key := "%s/%s" % [definition.map_id, transition.get("id", "")]
			if not allowed.has(key):
				errors.append(
					"%s %s (%s) reaches %s (%s) without an allowlisted bridge"
					% [DIAG_CROSS_GROUP_UNDECLARED, key, own_group, destination, far_group]
				)
	errors.sort()
	return errors


static func _bridge_label(bridge: Dictionary) -> String:
	return "%s/%s<->%s/%s" % [
		bridge.get("map_a", ""), bridge.get("transition_a", ""),
		bridge.get("map_b", ""), bridge.get("transition_b", ""),
	]


static func _transition_by_id(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	if definition == null:
		return {}
	for transition in definition.transitions:
		if StringName(transition.get("id", "")) == transition_id:
			return transition
	return {}


static func build(
	definitions: Array[MapDefinition],
	root_map_id: StringName = &"",
	world_group_id: StringName = DEFAULT_WORLD_GROUP_ID
) -> Dictionary:
	var layout := MapAlignmentMath.layout_connected_maps(definitions, root_map_id)
	var by_id := _definitions_by_id(definitions)
	var errors: Array[String] = []
	var locations: Array[Dictionary] = []
	var seen_map_ids: Dictionary = {}

	if by_id.is_empty():
		errors.append("world layout requires at least one map")
	if world_group_id.is_empty():
		errors.append("world_group_id is required")
	for definition in definitions:
		if definition == null:
			errors.append("world layout cannot contain a null map")
			continue
		var declared_map_id: StringName = definition.map_id
		if declared_map_id.is_empty():
			errors.append("world layout map_id is required")
		elif seen_map_ids.has(declared_map_id):
			errors.append("duplicate world layout map_id: %s" % String(declared_map_id))
		else:
			seen_map_ids[declared_map_id] = true

	for map_id_value in by_id.keys():
		var map_id := StringName(map_id_value)
		var definition: MapDefinition = by_id[map_id]
		if definition.cell_size != MapTypes.DEFAULT_CELL_SIZE:
			errors.append(
				"location %s has cell_size %d; contiguous groups require the default cell_size %d"
				% [String(map_id), definition.cell_size, MapTypes.DEFAULT_CELL_SIZE]
			)
		if not layout["offsets"].has(map_id):
			errors.append("location %s has no deterministic global origin" % String(map_id))
			continue
		var origin_px := Vector2(layout["offsets"][map_id])
		locations.append({
			"world_group_id": StringName(world_group_id),
			"location_id": map_id,
			"origin_cell": _pixel_to_cell(origin_px, definition.cell_size),
			"cell_size": definition.cell_size,
			"size_cells": definition.size_cells,
			"global_bounds": Rect2(origin_px, definition.world_size()),
			"map_fingerprint": definition.fingerprint,
		})

	locations.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["location_id"]) < String(right["location_id"])
	)

	var seams: Array[Dictionary] = []
	var blocking_seam_errors: Array[String] = []
	for seam in layout["seams"]:
		var seam_result := _validate_seam(seam, by_id, layout["offsets"], world_group_id)
		errors.append_array(seam_result["errors"])
		var codes: Array = seam_result["record"].get("diagnostics", [])
		if not codes.is_empty() and not codes.has(DIAG_SEAM_ORIGIN_CONFLICT):
			# Placement is still consistent; only this aperture is unfit to stream.
			blocking_seam_errors.append_array(seam_result["errors"])
		if seam_result["record"].is_empty():
			continue
		seams.append(seam_result["record"])
	seams.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["id"]) < String(right["id"])
	)

	errors.append_array(_validate_overlaps(locations, seams))
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"world_group_id": StringName(world_group_id),
		"locations": locations,
		"seams": seams,
		"unplaced": layout["unplaced"].duplicate(),
		"parents": (layout.get("parents", {}) as Dictionary).duplicate(),
		"blocking_seam_errors": blocking_seam_errors,
	}


static func location(result: Dictionary, map_id: StringName) -> Dictionary:
	for candidate in result.get("locations", []):
		if candidate.get("location_id", &"") == map_id:
			return (candidate as Dictionary).duplicate(true)
	return {}


static func global_cell(result: Dictionary, map_id: StringName, local_cell: Vector2i) -> Vector2i:
	var entry := location(result, map_id)
	if entry.is_empty():
		return local_cell
	return Vector2i(entry["origin_cell"]) + local_cell


static func location_at_global_cell(result: Dictionary, global_cell: Vector2i) -> StringName:
	for entry in result.get("locations", []):
		var origin_cell := Vector2i(entry["origin_cell"])
		var size_cells := Vector2i(entry["size_cells"])
		var local := global_cell - origin_cell
		if (
			local.x >= 0
			and local.y >= 0
			and local.x < size_cells.x
			and local.y < size_cells.y
		):
			return StringName(entry["location_id"])
	return &""


## Endpoints for a host NavigationLink2D that bridges the agent-radius inset
## at a physical seam. Start sits inside the base bake, end inside the
## neighbor bake. Empty when the walkable interiors do not overlap.
## `aperture_center` (global px along the seam, WB-08b) places the link in the
## transition's street opening; NAN keeps the middle of the shared edge, which
## on real districts usually lands on a building and never connects.
static func seam_navigation_link_points(
	result: Dictionary,
	seam: Dictionary,
	agent_radius: float = 16.0,
	aperture_center: float = NAN
) -> PackedVector2Array:
	var base := location(result, StringName(seam.get("base_map_id", &"")))
	var neighbor := location(result, StringName(seam.get("neighbor_map_id", &"")))
	if base.is_empty() or neighbor.is_empty():
		return PackedVector2Array()
	var base_bounds: Rect2 = base["global_bounds"]
	var neighbor_bounds: Rect2 = neighbor["global_bounds"]
	# Walkable interiors do not touch (that is the inset gap). Use the
	# overlapping span along the seam, then step inward on each side.
	var inset := agent_radius + 1.0
	var side := StringName(seam.get("base_side", &""))
	var start := Vector2.ZERO
	var end := Vector2.ZERO
	match side:
		&"east", &"west":
			var y0 := maxf(
				base_bounds.position.y + agent_radius, neighbor_bounds.position.y + agent_radius
			)
			var y1 := minf(
				base_bounds.end.y - agent_radius, neighbor_bounds.end.y - agent_radius
			)
			if y1 <= y0:
				return PackedVector2Array()
			var y := (y0 + y1) * 0.5 if is_nan(aperture_center) else clampf(aperture_center, y0, y1)
			var seam_x := (
				base_bounds.end.x if side == &"east" else base_bounds.position.x
			)
			var inward := -inset if side == &"east" else inset
			start = Vector2(seam_x + inward, y)
			end = Vector2(seam_x - inward, y)
		&"south", &"north":
			var x0 := maxf(
				base_bounds.position.x + agent_radius, neighbor_bounds.position.x + agent_radius
			)
			var x1 := minf(
				base_bounds.end.x - agent_radius, neighbor_bounds.end.x - agent_radius
			)
			if x1 <= x0:
				return PackedVector2Array()
			var x := (x0 + x1) * 0.5 if is_nan(aperture_center) else clampf(aperture_center, x0, x1)
			var seam_y := (
				base_bounds.end.y if side == &"south" else base_bounds.position.y
			)
			var inward := -inset if side == &"south" else inset
			start = Vector2(x, seam_y + inward)
			end = Vector2(x, seam_y - inward)
		_:
			return PackedVector2Array()
	return PackedVector2Array([start, end])


## WB-08: the checked-in world-layout manifest for one group. JSON-safe (ints and
## strings only) and fingerprinted, so review and CI see placement changes instead
## of the runtime deriving them in load order. `sources` maps location_id to
## {package_path, source_sha256}; the build tool fills it from the registry.
static func build_manifest(
	definitions: Array[MapDefinition],
	members: Array = REVAL_OUTDOOR_MEMBERS,
	root_location_id: StringName = &"lower_town_slice",
	world_group_id: StringName = DEFAULT_WORLD_GROUP_ID,
	sources: Dictionary = {}
) -> Dictionary:
	var scene_to_location: Dictionary = {}
	var member_scene: Dictionary = {}
	var member_kind: Dictionary = {}
	var seen_members: Dictionary = {}
	var duplicate_errors: Array[String] = []
	for member_value in members:
		var member: Dictionary = member_value as Dictionary
		if seen_members.has(StringName(member["location_id"])):
			duplicate_errors.append(
				"%s %s is listed twice in %s"
				% [DIAG_MEMBER_DUPLICATE, member["location_id"], world_group_id]
			)
		seen_members[StringName(member["location_id"])] = true
		# Only streamed outdoor members are expected; a member may declare another
		# kind (travel, interior) so the seam rule below can reject it.
		member_kind[StringName(member["location_id"])] = String(
			member.get("location_kind", LOCATION_KIND_OUTDOOR)
		)
		member_scene[StringName(member["location_id"])] = String(member["scene_id"])
		scene_to_location[String(member["scene_id"])] = String(member["location_id"])

	var layout := build(definitions, root_location_id, world_group_id)
	var errors: Array[String] = []
	var blocking: Array = layout.get("blocking_seam_errors", [])
	for error in layout["errors"]:
		if not blocking.has(error):
			errors.append(String(error))
	errors.append_array(duplicate_errors)
	var by_id := _definitions_by_id(definitions)
	for map_id_value in by_id.keys():
		if not member_scene.has(StringName(map_id_value)):
			errors.append(
				"%s location %s is not a member of %s"
				% [DIAG_NOT_A_MEMBER, String(map_id_value), String(world_group_id)]
			)
	for member_id_value in member_scene.keys():
		if not by_id.has(StringName(member_id_value)):
			errors.append("%s member %s has no definition" % [DIAG_MEMBER_MISSING, member_id_value])

	var parents: Dictionary = layout.get("parents", {})
	var locations: Array = []
	for entry in layout["locations"]:
		var location_id := StringName(entry["location_id"])
		var origin := Vector2i(entry["origin_cell"])
		var size := Vector2i(entry["size_cells"])
		var source: Dictionary = sources.get(location_id, {})
		locations.append({
			"location_id": String(location_id),
			"scene_id": String(member_scene.get(location_id, "")),
			"location_kind": String(member_kind.get(location_id, LOCATION_KIND_OUTDOOR)),
			"package_path": String(source.get("package_path", "")),
			"source_sha256": String(source.get("source_sha256", "")),
			"map_fingerprint": String(entry["map_fingerprint"]),
			"cell_size": int(entry["cell_size"]),
			"origin_cell": [origin.x, origin.y],
			"size_cells": [size.x, size.y],
			# Half-open [x0, y0, x1, y1) in global cells.
			"global_bounds_cells": [origin.x, origin.y, origin.x + size.x, origin.y + size.y],
			"placement_parent": String(parents.get(location_id, "")),
		})

	var seam_transitions: Dictionary = {}
	var seams: Array = []
	for seam in layout["seams"]:
		var codes: Array = (seam.get("diagnostics", []) as Array).duplicate()
		for endpoint in [seam["base_map_id"], seam["neighbor_map_id"]]:
			if not member_scene.has(StringName(endpoint)):
				# Travel boundary: a seam to a map outside the group is an authoring
				# error, never a silently streamed edge.
				codes.append(DIAG_SEAM_OUTSIDE_GROUP)
				errors.append(
					"%s seam %s reaches %s outside %s"
					% [DIAG_SEAM_OUTSIDE_GROUP, seam["id"], endpoint, world_group_id]
				)
		for endpoint in [seam["base_map_id"], seam["neighbor_map_id"]]:
			var kind := String(member_kind.get(StringName(endpoint), LOCATION_KIND_OUTDOOR))
			if kind != String(LOCATION_KIND_OUTDOOR):
				codes.append(DIAG_KIND_PHYSICAL_SEAM)
				errors.append(
					"%s seam %s touches %s member %s"
					% [DIAG_KIND_PHYSICAL_SEAM, seam["id"], kind, endpoint]
				)
		seam_transitions["%s/%s" % [seam["base_map_id"], seam["base_transition_id"]]] = true
		seam_transitions["%s/%s" % [seam["neighbor_map_id"], seam["neighbor_transition_id"]]] = true
		seams.append({
			"id": String(seam["id"]),
			"base_map_id": String(seam["base_map_id"]),
			"neighbor_map_id": String(seam["neighbor_map_id"]),
			"base_transition_id": String(seam["base_transition_id"]),
			"neighbor_transition_id": String(seam["neighbor_transition_id"]),
			"base_side": String(seam["base_side"]),
			"neighbor_side": String(seam["neighbor_side"]),
			"base_span_cells": roundi(float(seam["base_span_cells"])),
			"neighbor_span_cells": roundi(float(seam["neighbor_span_cells"])),
			"alignment": String(seam["alignment"]),
			"status": SEAM_STATUS_STREAMABLE if codes.is_empty() else SEAM_STATUS_BLOCKED,
			"diagnostics": codes,
		})

	var explicit: Array = []
	var warnings: Array[String] = []
	for map_id_value in by_id.keys():
		var definition: MapDefinition = by_id[map_id_value]
		for transition in definition.transitions:
			var destination := String(transition.get("destination_scene_id", ""))
			var transition_id := String(transition.get("id", ""))
			if destination.is_empty():
				continue
			if seam_transitions.has("%s/%s" % [definition.map_id, transition_id]):
				continue
			var alignment := String(transition.get("alignment", "edge"))
			var destination_location := String(scene_to_location.get(destination, ""))
			var reason := EXPLICIT_REASON_UNPAIRED
			if alignment == String(LOCATION_KIND_TRAVEL):
				reason = EXPLICIT_REASON_TRAVEL
			elif destination_location.is_empty():
				reason = EXPLICIT_REASON_OUTSIDE
			if destination.begins_with("world_") and alignment != String(LOCATION_KIND_TRAVEL):
				warnings.append(
					"%s %s/%s -> %s"
					% [DIAG_TRAVEL_ALIGNMENT_MISSING, definition.map_id, transition_id, destination]
				)
			explicit.append({
				"location_id": String(definition.map_id),
				"transition_id": transition_id,
				"destination_scene_id": destination,
				"destination_location_id": destination_location,
				"alignment": alignment,
				"reason": reason,
			})
	explicit.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return "%s/%s" % [left["location_id"], left["transition_id"]] \
			< "%s/%s" % [right["location_id"], right["transition_id"]]
	)
	for seam in seams:
		if seam["status"] == SEAM_STATUS_BLOCKED:
			warnings.append("%s %s" % [",".join(seam["diagnostics"]), seam["id"]])
	errors.sort()
	warnings.sort()

	var unplaced: Array = []
	for map_id in layout["unplaced"]:
		unplaced.append(String(map_id))
	var manifest := {
		"schema": MANIFEST_SCHEMA,
		"world_group_id": String(world_group_id),
		"root_location_id": String(root_location_id),
		"cell_size": MapTypes.DEFAULT_CELL_SIZE,
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"locations": locations,
		"seams": seams,
		"explicit_transitions": explicit,
		"unplaced": unplaced,
	}
	manifest["fingerprint"] = manifest_fingerprint(manifest)
	return manifest


## sha256 over the canonical JSON of every field except `fingerprint`. The python
## verifier recomputes it with json.dumps(sort_keys=True, separators=(",", ":")).
static func manifest_fingerprint(manifest: Dictionary) -> String:
	var body := (manifest as Dictionary).duplicate(true)
	body.erase("fingerprint")
	return canonical_json(body).sha256_text()


static func canonical_json(value: Variant) -> String:
	return JSON.stringify(_canonical_value(value), "", true)


## Runtime layout (the shape build() returns) from a checked-in manifest. Only
## streamable seams are kept; blocked seams and explicit transitions stay on
## today's scene-swap path.
static func layout_from_manifest(manifest: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if String(manifest.get("schema", "")) != MANIFEST_SCHEMA:
		errors.append("manifest schema must be %s" % MANIFEST_SCHEMA)
	if String(manifest.get("fingerprint", "")) != manifest_fingerprint(manifest):
		errors.append("manifest fingerprint does not match its content")
	if not bool(manifest.get("valid", false)):
		errors.append("manifest was built with errors")
	var world_group_id := StringName(manifest.get("world_group_id", ""))
	var locations: Array[Dictionary] = []
	for entry_value in manifest.get("locations", []):
		var entry: Dictionary = entry_value as Dictionary
		var cell_size := int(entry.get("cell_size", 0))
		var origin_values: Array = entry.get("origin_cell", [0, 0])
		var size_values: Array = entry.get("size_cells", [0, 0])
		var origin := Vector2i(int(origin_values[0]), int(origin_values[1]))
		var size := Vector2i(int(size_values[0]), int(size_values[1]))
		locations.append({
			"world_group_id": world_group_id,
			"location_id": StringName(entry.get("location_id", "")),
			"scene_id": StringName(entry.get("scene_id", "")),
			"location_kind": StringName(entry.get("location_kind", "")),
			"origin_cell": origin,
			"cell_size": cell_size,
			"size_cells": size,
			"global_bounds": Rect2(Vector2(origin * cell_size), Vector2(size * cell_size)),
			"map_fingerprint": String(entry.get("map_fingerprint", "")),
		})
	var seams: Array[Dictionary] = []
	var blocked: Array[Dictionary] = []
	for seam_value in manifest.get("seams", []):
		var seam: Dictionary = seam_value as Dictionary
		var record := {
			"id": String(seam.get("id", "")),
			"world_group_id": world_group_id,
			"base_map_id": StringName(seam.get("base_map_id", "")),
			"neighbor_map_id": StringName(seam.get("neighbor_map_id", "")),
			"base_transition_id": StringName(seam.get("base_transition_id", "")),
			"neighbor_transition_id": StringName(seam.get("neighbor_transition_id", "")),
			"base_side": StringName(seam.get("base_side", "")),
			"neighbor_side": StringName(seam.get("neighbor_side", "")),
			"span_cells": float(seam.get("base_span_cells", 0)),
			"alignment": StringName(seam.get("alignment", "")),
			"diagnostics": (seam.get("diagnostics", []) as Array).duplicate(),
		}
		if String(seam.get("status", "")) == SEAM_STATUS_STREAMABLE:
			seams.append(record)
		else:
			blocked.append(record)
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"world_group_id": world_group_id,
		"locations": locations,
		"seams": seams,
		"blocked_seams": blocked,
		"explicit_transitions": (manifest.get("explicit_transitions", []) as Array).duplicate(true),
		"unplaced": [],
		"fingerprint": String(manifest.get("fingerprint", "")),
	}


## Compile each member from its explicitly registered blueprint (no filesystem
## discovery). Returns {definitions: Array[MapDefinition], sources, errors}.
static func compile_members(members: Array = REVAL_OUTDOOR_MEMBERS) -> Dictionary:
	var definitions: Array[MapDefinition] = []
	var sources: Dictionary = {}
	var errors: Array[String] = []
	var entries: Dictionary = {}
	for entry in MapBlueprintRegistry.entries():
		entries[StringName(entry["id"])] = entry
	for member_value in members:
		var location_id := StringName((member_value as Dictionary)["location_id"])
		var entry: Dictionary = entries.get(location_id, {})
		var blueprint := MapBlueprintRegistry.create_blueprint(entry) if not entry.is_empty() else null
		var definition := MapBlueprintCompiler.compile(blueprint) if blueprint != null else null
		if definition == null:
			errors.append("%s member %s did not compile" % [DIAG_MEMBER_MISSING, location_id])
			continue
		definitions.append(definition)
		var source := String(entry.get("source", ""))
		sources[location_id] = {
			"package_path": source,
			"source_sha256": FileAccess.get_sha256(source) if not source.is_empty() else "",
		}
	return {"definitions": definitions, "sources": sources, "errors": errors}


## Pretty, stable file text for the manifest (sorted keys, trailing newline).
static func manifest_file_text(manifest: Dictionary) -> String:
	return JSON.stringify(_canonical_value(manifest), "  ", true) + "\n"


static func load_manifest(path: String = REVAL_OUTDOOR_MANIFEST_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


## JSON numbers load as floats; fold integral floats back to ints so a parsed
## manifest hashes exactly like the one that was written.
static func _canonical_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key in (value as Dictionary).keys():
				result[String(key)] = _canonical_value(value[key])
			return result
		TYPE_ARRAY:
			var items: Array = []
			for item in value:
				items.append(_canonical_value(item))
			return items
		TYPE_FLOAT:
			var number := float(value)
			return int(number) if is_equal_approx(number, roundf(number)) else number
		TYPE_STRING_NAME:
			return String(value)
		TYPE_VECTOR2I:
			return [value.x, value.y]
	return value


static func _definitions_by_id(definitions: Array[MapDefinition]) -> Dictionary:
	var by_id: Dictionary = {}
	for definition in definitions:
		if definition == null:
			continue
		var map_id: StringName = definition.map_id
		if by_id.has(map_id):
			# Keep the first deterministic input and surface the duplicate as an error
			# through the normal map-id validation below rather than overwriting it.
			continue
		by_id[map_id] = definition
	return by_id


static func _pixel_to_cell(position: Vector2, cell_size: int) -> Vector2i:
	return Vector2i(
		roundi(position.x / float(cell_size)),
		roundi(position.y / float(cell_size))
	)


static func _validate_seam(
	seam: Dictionary,
	by_id: Dictionary,
	offsets: Dictionary,
	world_group_id: StringName
) -> Dictionary:
	var errors: Array[String] = []
	var codes: Array[String] = []
	var base_id: StringName = seam["base_map_id"]
	var neighbor_id: StringName = seam["neighbor_map_id"]
	var base: MapDefinition = by_id[base_id]
	var neighbor: MapDefinition = by_id[neighbor_id]
	var base_side: StringName = seam["base_side"]
	var neighbor_side: StringName = seam["neighbor_side"]
	var seam_id := "%s/%s|%s/%s" % [base_id, seam["base"]["id"], neighbor_id, seam["neighbor"]["id"]]

	if base_side.is_empty() or neighbor_side.is_empty():
		errors.append("seam %s has no boundary side" % seam_id)
		codes.append(DIAG_SEAM_NO_SIDE)
	elif OPPOSITE_SIDES.get(base_side, &"") != neighbor_side:
		errors.append("seam %s must use opposite boundary sides" % seam_id)
		codes.append(DIAG_SEAM_SIDES_NOT_OPPOSITE)
	if base.cell_size != neighbor.cell_size:
		errors.append("seam %s has mismatched cell sizes" % seam_id)
		codes.append(DIAG_SEAM_CELL_SIZE_MISMATCH)
	if not is_equal_approx(float(seam["base_span_cells"]), float(seam["neighbor_span_cells"])):
		errors.append("seam %s has mismatched transition spans" % seam_id)
		codes.append(DIAG_SEAM_SPAN_MISMATCH)

	var expected_offset := Vector2(offsets[base_id]) + MapAlignmentMath.aligned_neighbor_offset(
		base, neighbor, seam["base"], seam["neighbor"]
	)
	var actual_offset := Vector2(offsets[neighbor_id])
	if not (
		is_equal_approx(actual_offset.x, expected_offset.x)
		and is_equal_approx(actual_offset.y, expected_offset.y)
	):
		errors.append("seam %s has a conflicting global origin" % seam_id)
		codes.append(DIAG_SEAM_ORIGIN_CONFLICT)

	var record := {
		"id": seam_id,
		"world_group_id": world_group_id,
		"base_map_id": base_id,
		"neighbor_map_id": neighbor_id,
		"base_transition_id": seam["base"]["id"],
		"neighbor_transition_id": seam["neighbor"]["id"],
		"base_side": base_side,
		"neighbor_side": neighbor_side,
		"span_cells": float(seam["base_span_cells"]),
		"base_span_cells": float(seam["base_span_cells"]),
		"neighbor_span_cells": float(seam["neighbor_span_cells"]),
		"alignment": &"physical",
		# Stable DIAG_SEAM_* codes; build_manifest() uses them to block one seam
		# from streaming without discarding the whole group placement.
		"diagnostics": codes,
	}
	return {"errors": errors, "record": record}


static func _validate_overlaps(
	locations: Array[Dictionary], seams: Array[Dictionary]
) -> Array[String]:
	var errors: Array[String] = []
	for first_index in locations.size():
		var first: Dictionary = locations[first_index]
		var first_bounds: Rect2 = first["global_bounds"]
		for second_index in range(first_index + 1, locations.size()):
			var second: Dictionary = locations[second_index]
			var second_bounds: Rect2 = second["global_bounds"]
			if not first_bounds.intersects(second_bounds, false):
				continue
			if _locations_share_seam(first["location_id"], second["location_id"], seams):
				# A physical seam may touch at one edge, but never overlap by area.
				var overlap := first_bounds.intersection(second_bounds)
				if overlap.size.x <= EPSILON or overlap.size.y <= EPSILON:
					continue
			errors.append(
				"locations %s and %s overlap in global bounds"
				% [first["location_id"], second["location_id"]]
			)
	return errors


static func _locations_share_seam(
	first_id: StringName, second_id: StringName, seams: Array[Dictionary]
) -> bool:
	for seam in seams:
		if (
			(seam["base_map_id"] == first_id and seam["neighbor_map_id"] == second_id)
			or (seam["base_map_id"] == second_id and seam["neighbor_map_id"] == first_id)
		):
			return true
	return false
